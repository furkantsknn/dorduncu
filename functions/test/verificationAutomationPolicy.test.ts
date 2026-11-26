import assert from "node:assert/strict";
import test from "node:test";

import type {
  IdentityAutomationEvidence,
} from "../src/users/verificationAutomationPolicy.ts";
import {
  routeIdentityEvidence,
} from "../src/users/verificationAutomationPolicy.ts";

const passed = {status: "passed", reasonCode: "passed"} as const;

function completeEvidence(): IdentityAutomationEvidence {
  return {
    providerResultVerified: true,
    submissionBound: true,
    biometricProcessingAuthorized: true,
    automaticApprovalEnabled: false,
    identityData: passed,
    identityUniqueness: passed,
    documentAuthenticity: passed,
    selfieLiveness: passed,
    faceMatch: passed,
  };
}

test("all positive checks still require manual review while disabled", () => {
  const result = routeIdentityEvidence(completeEvidence());
  assert.equal(result.route, "manual_review");
  assert.equal(result.reasonCode, "automatic_approval_disabled");
});

test("single-face selfie and valid OCR never substitute for face match", () => {
  const evidence = completeEvidence();
  evidence.automaticApprovalEnabled = true;
  evidence.faceMatch = {
    status: "unavailable",
    reasonCode: "not_integrated",
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

test("another submission's face match cannot approve", () => {
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
  assert.equal(
    routeIdentityEvidence(evidence).reasonCode,
    "face_mismatch_requires_review",
  );
});

test("suspected document forgery requires human review", () => {
  const evidence = completeEvidence();
  evidence.documentAuthenticity = {
    status: "failed",
    reasonCode: "suspected_forgery",
  };
  assert.equal(routeIdentityEvidence(evidence).route, "manual_review");
});

test("duplicate identity requires human review before final rejection", () => {
  const evidence = completeEvidence();
  evidence.identityUniqueness = {
    status: "failed",
    reasonCode: "identity_already_used",
  };
  assert.equal(
    routeIdentityEvidence(evidence).reasonCode,
    "identity_duplicate_requires_review",
  );
});

test("failed liveness requires selfie recapture", () => {
  const evidence = completeEvidence();
  evidence.selfieLiveness = {
    status: "failed",
    reasonCode: "liveness_failed",
  };
  assert.equal(routeIdentityEvidence(evidence).route, "recapture_required");
});

test("complete, server-verified evidence is only eligible when enabled", () => {
  const evidence = completeEvidence();
  evidence.automaticApprovalEnabled = true;
  const result = routeIdentityEvidence(evidence);
  assert.equal(result.route, "eligible_for_auto_approval");
  assert.equal(result.reasonCode, "trusted_identity_checks_passed");
});
