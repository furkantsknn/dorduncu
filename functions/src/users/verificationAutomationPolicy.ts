/**
 * Automatic-verification routing policy (fail-closed).
 *
 * IMPORTANT: The evidence trust flags must only be set by trusted backend code
 * after verifying the provider signature, event idempotency, request ID, and
 * submission binding. Never populate them from user-controlled client data.
 */

export type IdentityEvidenceStatus =
  "passed" | "failed" | "unavailable";

export interface IdentityEvidenceCheck {
  status: IdentityEvidenceStatus;
  reasonCode: string;
}

export interface IdentityAutomationEvidence {
  /** Whether a signed provider result was verified by the backend. */
  providerResultVerified: boolean;
  /** Whether this result belongs to the current user and submission. */
  submissionBound: boolean;
  /** Whether a legally reviewed consent/legal-basis record exists. */
  biometricProcessingAuthorized: boolean;
  /** Server-side feature flag; defaults to disabled in deployment. */
  automaticApprovalEnabled: boolean;
  /** Valid OCR/identity attributes, not proof of document authenticity. */
  identityData: IdentityEvidenceCheck;
  /** Prevents using the same identity in multiple accounts. */
  identityUniqueness: IdentityEvidenceCheck;
  /** Genuine document determination from a qualified verification provider. */
  documentAuthenticity: IdentityEvidenceCheck;
  /** A live person present during the selfie capture. */
  selfieLiveness: IdentityEvidenceCheck;
  /** Face on identity document matches the live captured person. */
  faceMatch: IdentityEvidenceCheck;
  /** Optional photo quality assessment; failure asks user to recapture. */
  photoQuality?: IdentityEvidenceCheck;
  /**
   * Optional ICAO 9303 NFC chip verification. Absence or unavailability never
   * blocks users; an explicit failure (e.g. tampering) routes to review.
   */
  nfcVerification?: IdentityEvidenceCheck;
}

export type IdentityAutomationRoute =
  "manual_review" | "recapture_required" | "eligible_for_auto_approval";

export interface IdentityAutomationRouting {
  route: IdentityAutomationRoute;
  reasonCode: string;
}

/**
 * Classifies independently verified KYC evidence, without changing
 * verification_requests, user badges, or any account verification flag.
 *
 * Unexpected, incomplete, or contradictory signals always fail closed.
 * @param {IdentityAutomationEvidence} evidence Verified server-side evidence.
 * @return {IdentityAutomationRouting} Safe routing decision.
 */
export function routeIdentityEvidence(
  evidence: IdentityAutomationEvidence,
): IdentityAutomationRouting {
  if (!evidence.biometricProcessingAuthorized) {
    return {
      route: "manual_review",
      reasonCode: "biometric_processing_not_authorized",
    };
  }

  if (!evidence.providerResultVerified || !evidence.submissionBound) {
    return {
      route: "manual_review",
      reasonCode: "trusted_provider_evidence_missing",
    };
  }

  // Never automatically reject a person for a biometric mismatch:
  // false matches, low image quality, and stolen-document disputes
  // require a human decision and an accessible appeal route.
  if (evidence.faceMatch.status === "failed") {
    return {
      route: "manual_review",
      reasonCode: "face_mismatch_requires_review",
    };
  }

  if (evidence.documentAuthenticity.status === "failed") {
    return {
      route: "manual_review",
      reasonCode: "document_authenticity_requires_review",
    };
  }

  if (evidence.identityUniqueness.status === "failed") {
    return {
      route: "manual_review",
      reasonCode: "identity_duplicate_requires_review",
    };
  }

  if (evidence.nfcVerification?.status === "failed") {
    return {
      route: "manual_review",
      reasonCode: "nfc_mismatch_requires_review",
    };
  }

  if (evidence.selfieLiveness.status === "failed") {
    return {
      route: "recapture_required",
      reasonCode: "selfie_liveness_retry",
    };
  }

  if (evidence.photoQuality?.status === "failed") {
    return {
      route: "recapture_required",
      reasonCode: "photo_quality_retry",
    };
  }

  const requiredChecks = [
    evidence.identityData,
    evidence.identityUniqueness,
    evidence.documentAuthenticity,
    evidence.selfieLiveness,
    evidence.faceMatch,
  ];

  if (requiredChecks.some((check) => check.status !== "passed")) {
    return {
      route: "manual_review",
      reasonCode: "identity_evidence_incomplete",
    };
  }

  if (!evidence.automaticApprovalEnabled) {
    return {
      route: "manual_review",
      reasonCode: "automatic_approval_disabled",
    };
  }

  // This only establishes eligibility: a separate, audited server-side
  // transaction must check current submission/identity locks before approval.
  return {
    route: "eligible_for_auto_approval",
    reasonCode: "trusted_identity_checks_passed",
  };
}
