const test = require("node:test");
const assert = require("node:assert/strict");

const {
  routeIdentityEvidence,
} = require("../lib/users/verificationAutomationPolicy");

function completeEvidence() {
  return {
    providerResultVerified: true,
    submissionBound: true,
    biometricProcessingAuthorized: true,
    automaticApprovalEnabled: false,
    identityData: {status: "passed", reasonCode: "identity_type_match"},
    identityUniqueness: {status: "passed", reasonCode: "identity_unique"},
    documentAuthenticity: {status: "passed", reasonCode: "document_genuine"},
    selfieLiveness: {status: "passed", reasonCode: "live_person"},
    faceMatch: {status: "passed", reasonCode: "same_person"},
  };
}

test("automatic approval stays off by default even with complete evidence", () => {
  const result = routeIdentityEvidence(completeEvidence());
  assert.equal(result.route, "manual_review");
  assert.equal(result.reasonCode, "automatic_approval_disabled");
});

test("basic OCR and single-face detection without face match cannot approve", () => {
  const evidence = completeEvidence();
  evidence.automaticApprovalEnabled = true;
  evidence.documentAuthenticity = {
    status: "unavailable",
    reasonCode: "provider_not_configured",
  };
  evidence.selfieLiveness = {
    status: "unavailable",
    reasonCode: "provider_not_configured",
  };
  evidence.faceMatch = {
    status: "unavailable",
    reasonCode: "provider_not_configured",
  };

  const result = routeIdentityEvidence(evidence);
  assert.equal(result.route, "manual_review");
  assert.equal(result.reasonCode, "identity_evidence_incomplete");
});

test("unverified provider result cannot approve", () => {
  const evidence = completeEvidence();
  evidence.automaticApprovalEnabled = true;
  evidence.providerResultVerified = false;
  assert.equal(routeIdentityEvidence(evidence).route, "manual_review");
});

test("another submission face match cannot approve", () => {
  const evidence = completeEvidence();
  evidence.automaticApprovalEnabled = true;
  evidence.submissionBound = false;
  assert.equal(routeIdentityEvidence(evidence).route, "manual_review");
});

test("biometric processing without authorized legal basis cannot approve", () => {
  const evidence = completeEvidence();
  evidence.automaticApprovalEnabled = true;
  evidence.biometricProcessingAuthorized = false;
  assert.equal(routeIdentityEvidence(evidence).route, "manual_review");
});

test("face mismatch always goes to human review, not automatic rejection", () => {
  const evidence = completeEvidence();
  evidence.automaticApprovalEnabled = true;
  evidence.faceMatch = {status: "failed", reasonCode: "mismatch"};
  const result = routeIdentityEvidence(evidence);
  assert.equal(result.route, "manual_review");
  assert.equal(result.reasonCode, "face_mismatch_requires_review");
});

test("suspected document forgery requires human review", () => {
  const evidence = completeEvidence();
  evidence.automaticApprovalEnabled = true;
  evidence.documentAuthenticity = {
    status: "failed",
    reasonCode: "suspected_forgery",
  };
  assert.equal(routeIdentityEvidence(evidence).route, "manual_review");
});

test("duplicate identity requires human review before final rejection", () => {
  const evidence = completeEvidence();
  evidence.automaticApprovalEnabled = true;
  evidence.identityUniqueness = {
    status: "failed",
    reasonCode: "identity_already_used",
  };
  const result = routeIdentityEvidence(evidence);
  assert.equal(result.route, "manual_review");
  assert.equal(result.reasonCode, "identity_duplicate_requires_review");
});

test("failed liveness or photo quality requires recapture", () => {
  const liveness = completeEvidence();
  liveness.automaticApprovalEnabled = true;
  liveness.selfieLiveness = {status: "failed", reasonCode: "liveness_failed"};
  assert.equal(routeIdentityEvidence(liveness).route, "recapture_required");
  assert.equal(routeIdentityEvidence(liveness).reasonCode, "selfie_liveness_retry");

  const quality = completeEvidence();
  quality.automaticApprovalEnabled = true;
  quality.photoQuality = {status: "failed", reasonCode: "blurry_document"};
  assert.equal(routeIdentityEvidence(quality).route, "recapture_required");
  assert.equal(routeIdentityEvidence(quality).reasonCode, "photo_quality_retry");
});

test("optional NFC unavailability never blocks eligibility, but NFC failure goes to review", () => {
  const unavailableNfc = completeEvidence();
  unavailableNfc.automaticApprovalEnabled = true;
  unavailableNfc.nfcVerification = {status: "unavailable", reasonCode: "device_no_nfc"};
  assert.equal(routeIdentityEvidence(unavailableNfc).route, "eligible_for_auto_approval");

  const failedNfc = completeEvidence();
  failedNfc.automaticApprovalEnabled = true;
  failedNfc.nfcVerification = {status: "failed", reasonCode: "chip_signature_invalid"};
  const result = routeIdentityEvidence(failedNfc);
  assert.equal(result.route, "manual_review");
  assert.equal(result.reasonCode, "nfc_mismatch_requires_review");
});

test("complete, server-verified evidence is only eligible when enabled", () => {
  const evidence = completeEvidence();
  evidence.automaticApprovalEnabled = true;
  const result = routeIdentityEvidence(evidence);
  assert.equal(result.route, "eligible_for_auto_approval");
  assert.equal(result.reasonCode, "trusted_identity_checks_passed");
});
