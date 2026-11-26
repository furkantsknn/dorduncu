import {createHmac, timingSafeEqual} from "node:crypto";

import {
  IdentityAutomationRouting,
  IdentityEvidenceCheck,
  IdentityEvidenceStatus,
  routeIdentityEvidence,
} from "./verificationAutomationPolicy";

export type KycProviderMode = "disabled" | "shadow" | "live";

export interface KycWebhookSignatureInput {
  rawBody: string;
  signatureHeader: string;
  timestampHeader: string;
  secret: string;
  nowMs?: number;
  maxSkewMs?: number;
}

export interface KycWebhookSignatureResult {
  valid: boolean;
  reasonCode: string;
}

export interface KycProviderCallbackPayload {
  provider: string;
  eventId: string;
  uid: string;
  submissionId: string;
  identityData: IdentityEvidenceCheck;
  documentAuthenticity: IdentityEvidenceCheck;
  selfieLiveness: IdentityEvidenceCheck;
  faceMatch: IdentityEvidenceCheck;
  photoQuality?: IdentityEvidenceCheck;
  nfcVerification?: IdentityEvidenceCheck;
}

export interface KycCallbackEvaluationInput {
  mode: KycProviderMode;
  automaticApprovalFlag: boolean;
  signatureValid: boolean;
  eventAlreadyProcessed: boolean;
  expectedUid: string;
  expectedSubmissionId: string;
  biometricConsentValid: boolean;
  identityUniqueness: IdentityEvidenceCheck;
  payload: KycProviderCallbackPayload;
}

export interface KycCallbackEvaluationResult {
  accepted: boolean;
  idempotentReplay: boolean;
  rejectionReason: string;
  routing: IdentityAutomationRouting;
  sanitizedSummary: {
    provider: string;
    eventId: string;
    mode: KycProviderMode;
    identityDataStatus: IdentityEvidenceStatus;
    documentAuthenticityStatus: IdentityEvidenceStatus;
    selfieLivenessStatus: IdentityEvidenceStatus;
    faceMatchStatus: IdentityEvidenceStatus;
    nfcStatus: IdentityEvidenceStatus | "not_used";
  };
}

/**
 * Contract for future biometric/KYC verification provider adapters.
 * Implementations must never fabricate passing results or store raw
 * biometric templates/TCKN in Firestore or logs.
 */
export interface KycVerificationProviderAdapter {
  readonly providerName: string;
  readonly supportsLiveness: boolean;
  readonly supportsFaceMatch: boolean;
  readonly supportsDocumentAuthenticity: boolean;
  readonly supportsOptionalNfc: boolean;
}

export const DEFAULT_WEBHOOK_MAX_SKEW_MS = 5 * 60 * 1000;

/**
 * Resolves KYC provider operating mode strictly failing closed to "disabled".
 * @param {string|undefined} raw Environment or config mode string.
 * @return {KycProviderMode} Validated provider mode.
 */
export function resolveKycProviderMode(raw?: string): KycProviderMode {
  const normalized = (raw ?? "").trim().toLowerCase();
  if (normalized === "shadow") {
    return "shadow";
  }
  if (normalized === "live") {
    return "live";
  }
  return "disabled";
}

/**
 * Verifies an HMAC-SHA256 signed webhook payload with replay timestamp window.
 * @param {KycWebhookSignatureInput} input Raw body, headers, and shared secret.
 * @return {KycWebhookSignatureResult} Verification result.
 */
export function verifyKycWebhookSignature(
  input: KycWebhookSignatureInput,
): KycWebhookSignatureResult {
  const secret = input.secret.trim();
  if (!secret) {
    return {valid: false, reasonCode: "webhook_secret_missing"};
  }

  const tsRaw = input.timestampHeader.trim();
  const parsedTs = Number(tsRaw);
  if (!tsRaw || !Number.isFinite(parsedTs) || parsedTs <= 0) {
    return {valid: false, reasonCode: "webhook_timestamp_invalid"};
  }

  const timestampMs = parsedTs < 1e12 ? parsedTs * 1000 : parsedTs;
  const nowMs = input.nowMs ?? Date.now();
  const maxSkewMs = input.maxSkewMs ?? DEFAULT_WEBHOOK_MAX_SKEW_MS;
  if (Math.abs(nowMs - timestampMs) > maxSkewMs) {
    return {valid: false, reasonCode: "webhook_timestamp_expired"};
  }

  const rawSig = input.signatureHeader.trim();
  const normalizedSig = rawSig.toLowerCase().startsWith("sha256=") ?
    rawSig.slice(7).trim().toLowerCase() :
    rawSig.toLowerCase();
  if (!/^[a-f0-9]{64}$/.test(normalizedSig)) {
    return {valid: false, reasonCode: "webhook_signature_malformed"};
  }

  const expectedHex = createHmac("sha256", secret)
    .update(`${tsRaw}.${input.rawBody}`)
    .digest("hex");

  const actualBuf = Buffer.from(normalizedSig, "hex");
  const expectedBuf = Buffer.from(expectedHex, "hex");
  if (
    actualBuf.length !== expectedBuf.length ||
    !timingSafeEqual(actualBuf, expectedBuf)
  ) {
    return {valid: false, reasonCode: "webhook_signature_mismatch"};
  }

  return {valid: true, reasonCode: "ok"};
}

/**
 * Validates provider callback trust boundaries and computes safe routing.
 * In "disabled" mode callbacks are rejected; in "shadow" mode automatic
 * approval is always forced off so real users stay in manual review.
 * @param {KycCallbackEvaluationInput} input Verified context and payload.
 * @return {KycCallbackEvaluationResult} Safe decision and non-PII summary.
 */
export function evaluateSignedProviderCallback(
  input: KycCallbackEvaluationInput,
): KycCallbackEvaluationResult {
  const sanitizedSummary = {
    provider: sanitizeIdentifier(input.payload.provider),
    eventId: sanitizeIdentifier(input.payload.eventId),
    mode: input.mode,
    identityDataStatus: input.payload.identityData.status,
    documentAuthenticityStatus: input.payload.documentAuthenticity.status,
    selfieLivenessStatus: input.payload.selfieLiveness.status,
    faceMatchStatus: input.payload.faceMatch.status,
    nfcStatus: input.payload.nfcVerification?.status ?? "not_used" as const,
  };

  const manualFallback = (
    reasonCode: string,
    idempotentReplay = false,
  ): KycCallbackEvaluationResult => ({
    accepted: false,
    idempotentReplay,
    rejectionReason: reasonCode,
    routing: {
      route: "manual_review",
      reasonCode,
    },
    sanitizedSummary,
  });

  if (input.mode === "disabled") {
    return manualFallback("kyc_provider_disabled");
  }

  if (!input.signatureValid) {
    return manualFallback("webhook_signature_invalid");
  }

  if (!sanitizedSummary.eventId) {
    return manualFallback("webhook_event_id_missing");
  }

  if (input.eventAlreadyProcessed) {
    return manualFallback("duplicate_webhook_event", true);
  }

  const expectedUid = input.expectedUid.trim();
  const expectedSubmission = input.expectedSubmissionId.trim();
  const payloadUid = input.payload.uid.trim();
  const payloadSubmission = input.payload.submissionId.trim();
  const submissionBound =
    Boolean(expectedUid) &&
    Boolean(expectedSubmission) &&
    payloadUid === expectedUid &&
    payloadSubmission === expectedSubmission;

  if (!submissionBound) {
    return manualFallback("submission_binding_mismatch");
  }

  // Automatic approval is strictly disabled in shadow mode.
  const effectiveAutoApproval =
    input.mode === "live" && input.automaticApprovalFlag === true;

  const routing = routeIdentityEvidence({
    providerResultVerified: true,
    submissionBound: true,
    biometricProcessingAuthorized: input.biometricConsentValid,
    automaticApprovalEnabled: effectiveAutoApproval,
    identityData: input.payload.identityData,
    identityUniqueness: input.identityUniqueness,
    documentAuthenticity: input.payload.documentAuthenticity,
    selfieLiveness: input.payload.selfieLiveness,
    faceMatch: input.payload.faceMatch,
    photoQuality: input.payload.photoQuality,
    nfcVerification: input.payload.nfcVerification,
  });

  return {
    accepted: true,
    idempotentReplay: false,
    rejectionReason: "",
    routing,
    sanitizedSummary,
  };
}

/**
 * Strips whitespace and non-identifier characters so event/provider ids cannot
 * smuggle sensitive text into logs or records.
 * @param {string} value Raw identifier.
 * @return {string} Safe bounded identifier.
 */
function sanitizeIdentifier(value: string): string {
  return value.trim().replace(/[^a-zA-Z0-9._:-]/g, "").slice(0, 128);
}
