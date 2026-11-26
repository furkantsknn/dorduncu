const test = require("node:test");
const assert = require("node:assert/strict");
const {createHmac} = require("node:crypto");

const {
  evaluateSignedProviderCallback,
  resolveKycProviderMode,
  verifyKycWebhookSignature,
} = require("../lib/users/kycProviderGateway");

function samplePayload() {
  return {
    provider: "sumsub_sandbox",
    eventId: "evt_01JABC123456",
    uid: "user-123",
    submissionId: "sub-456",
    identityData: {status: "passed", reasonCode: "identity_type_match"},
    documentAuthenticity: {status: "passed", reasonCode: "document_genuine"},
    selfieLiveness: {status: "passed", reasonCode: "live_person"},
    faceMatch: {status: "passed", reasonCode: "same_person"},
  };
}

test("provider mode fails closed to disabled for unknown values", () => {
  assert.equal(resolveKycProviderMode(undefined), "disabled");
  assert.equal(resolveKycProviderMode(""), "disabled");
  assert.equal(resolveKycProviderMode("production"), "disabled");
  assert.equal(resolveKycProviderMode("shadow"), "shadow");
  assert.equal(resolveKycProviderMode("live"), "live");
});

test("HMAC webhook signature verification checks secret, timestamp skew, and digest", () => {
  const secret = "super-secret-webhook-key";
  const rawBody = JSON.stringify({eventId: "evt_1"});
  const nowMs = 1_760_000_000_000;
  const tsSeconds = String(Math.floor(nowMs / 1000));
  const sig = createHmac("sha256", secret)
    .update(`${tsSeconds}.${rawBody}`)
    .digest("hex");

  assert.deepEqual(
    verifyKycWebhookSignature({
      rawBody,
      signatureHeader: `sha256=${sig}`,
      timestampHeader: tsSeconds,
      secret,
      nowMs,
    }),
    {valid: true, reasonCode: "ok"},
  );

  // Stale timestamp (10 minutes old) must fail
  assert.equal(
    verifyKycWebhookSignature({
      rawBody,
      signatureHeader: sig,
      timestampHeader: String(Math.floor((nowMs - 10 * 60 * 1000) / 1000)),
      secret,
      nowMs,
    }).reasonCode,
    "webhook_timestamp_expired",
  );

  // Tampered body must fail
  assert.equal(
    verifyKycWebhookSignature({
      rawBody: rawBody + " ",
      signatureHeader: sig,
      timestampHeader: tsSeconds,
      secret,
      nowMs,
    }).reasonCode,
    "webhook_signature_mismatch",
  );
});

test("disabled mode rejects callbacks and keeps manual review", () => {
  const result = evaluateSignedProviderCallback({
    mode: "disabled",
    automaticApprovalFlag: true,
    signatureValid: true,
    eventAlreadyProcessed: false,
    expectedUid: "user-123",
    expectedSubmissionId: "sub-456",
    biometricConsentValid: true,
    identityUniqueness: {status: "passed", reasonCode: "identity_unique"},
    payload: samplePayload(),
  });
  assert.equal(result.accepted, false);
  assert.equal(result.rejectionReason, "kyc_provider_disabled");
  assert.equal(result.routing.route, "manual_review");
});

test("shadow mode accepts verified callback but forces automatic approval off", () => {
  const result = evaluateSignedProviderCallback({
    mode: "shadow",
    automaticApprovalFlag: true,
    signatureValid: true,
    eventAlreadyProcessed: false,
    expectedUid: "user-123",
    expectedSubmissionId: "sub-456",
    biometricConsentValid: true,
    identityUniqueness: {status: "passed", reasonCode: "identity_unique"},
    payload: samplePayload(),
  });
  assert.equal(result.accepted, true);
  assert.equal(result.routing.route, "manual_review");
  assert.equal(result.routing.reasonCode, "automatic_approval_disabled");
});

test("replay event and submission mismatch are rejected", () => {
  const replay = evaluateSignedProviderCallback({
    mode: "live",
    automaticApprovalFlag: true,
    signatureValid: true,
    eventAlreadyProcessed: true,
    expectedUid: "user-123",
    expectedSubmissionId: "sub-456",
    biometricConsentValid: true,
    identityUniqueness: {status: "passed", reasonCode: "identity_unique"},
    payload: samplePayload(),
  });
  assert.equal(replay.accepted, false);
  assert.equal(replay.idempotentReplay, true);
  assert.equal(replay.rejectionReason, "duplicate_webhook_event");

  const mismatch = evaluateSignedProviderCallback({
    mode: "live",
    automaticApprovalFlag: true,
    signatureValid: true,
    eventAlreadyProcessed: false,
    expectedUid: "user-123",
    expectedSubmissionId: "sub-OTHER",
    biometricConsentValid: true,
    identityUniqueness: {status: "passed", reasonCode: "identity_unique"},
    payload: samplePayload(),
  });
  assert.equal(mismatch.accepted, false);
  assert.equal(mismatch.rejectionReason, "submission_binding_mismatch");
});

test("live mode with valid signature, consent, binding, and flag allows auto-approval eligibility", () => {
  const result = evaluateSignedProviderCallback({
    mode: "live",
    automaticApprovalFlag: true,
    signatureValid: true,
    eventAlreadyProcessed: false,
    expectedUid: "user-123",
    expectedSubmissionId: "sub-456",
    biometricConsentValid: true,
    identityUniqueness: {status: "passed", reasonCode: "identity_unique"},
    payload: samplePayload(),
  });
  assert.equal(result.accepted, true);
  assert.equal(result.routing.route, "eligible_for_auto_approval");
  assert.equal(result.routing.reasonCode, "trusted_identity_checks_passed");
});
