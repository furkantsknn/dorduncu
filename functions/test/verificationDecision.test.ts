import assert from "node:assert/strict";
import test from "node:test";

import {
  classifyIdentityTerms,
  decideVerification,
} from "../src/users/verificationDecision.ts";

test("API or OCR uncertainty stays pending", () => {
  const decision = decideVerification([
    {status: "unavailable", reasonCode: "tckn_unreadable"},
    {status: "passed", reasonCode: "selfie_single_face"},
    {status: "passed", reasonCode: "identity_unique"},
  ]);

  assert.equal(decision.status, "pending");
  assert.equal(decision.userStatus, "pending");
  assert.equal(decision.automaticCheckStatus, "needs_review");
  assert.equal(decision.reasonCode, "tckn_unreadable");
});

test("unreadable identity text stays unavailable", () => {
  const check = classifyIdentityTerms({
    readable: false,
    termsMatched: false,
  });

  assert.equal(check.status, "unavailable");
  assert.equal(check.reasonCode, "identity_text_unreadable");
});

test("missing identity phrases stay pending review", () => {
  const check = classifyIdentityTerms({
    readable: true,
    termsMatched: false,
  });
  const decision = decideVerification([
    check,
    {status: "passed", reasonCode: "selfie_single_face"},
    {status: "passed", reasonCode: "identity_unique"},
  ]);

  assert.equal(check.status, "unavailable");
  assert.equal(check.reasonCode, "identity_terms_unmatched");
  assert.equal(decision.status, "pending");
  assert.equal(decision.userStatus, "pending");
  assert.equal(decision.automaticCheckStatus, "needs_review");
});

test("an unsuitable selfie rejects without approving", () => {
  const decision = decideVerification([
    {status: "passed", reasonCode: "identity_type_match"},
    {status: "failed", reasonCode: "selfie_no_face"},
  ]);

  assert.equal(decision.status, "rejected");
  assert.equal(decision.reasonCode, "selfie_no_face");
  assert.equal(decision.decisionSource, "automatic");
});

test("passed checks do not approve", () => {
  const decision = decideVerification([
    {status: "passed", reasonCode: "identity_type_match"},
    {status: "passed", reasonCode: "selfie_single_face"},
    {status: "passed", reasonCode: "identity_unique"},
  ]);

  assert.equal(decision.status, "pending");
  assert.equal(decision.automaticCheckStatus, "passed");
  assert.equal(decision.reasonCode, "");
});

test("a real failure wins over an unavailable check", () => {
  const decision = decideVerification([
    {status: "unavailable", reasonCode: "selfie_analysis_unavailable"},
    {status: "failed", reasonCode: "identity_already_used"},
  ]);

  assert.equal(decision.status, "rejected");
  assert.equal(decision.reasonCode, "identity_already_used");
});
