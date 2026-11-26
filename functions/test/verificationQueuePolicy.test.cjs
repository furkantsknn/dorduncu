const test = require("node:test");
const assert = require("node:assert/strict");

const {
  evaluateVerificationQueueRecovery,
} = require("../lib/users/verificationQueuePolicy");

const NOW = 1_760_000_000_000;

test("already decided or completed analyses are skipped", () => {
  assert.equal(
    evaluateVerificationQueueRecovery({
      status: "approved",
      automaticCheckStatus: "pending",
      attemptCount: 0,
      processingStartedAtMs: null,
      lastAttemptAtMs: null,
      nowMs: NOW,
    }).action,
    "skip",
  );

  assert.equal(
    evaluateVerificationQueueRecovery({
      status: "pending",
      automaticCheckStatus: "needs_review",
      attemptCount: 1,
      processingStartedAtMs: null,
      lastAttemptAtMs: NOW - 600_000,
      nowMs: NOW,
    }).action,
    "skip",
  );
});

test("active processing within stale threshold is skipped; stale processing is retried", () => {
  const active = evaluateVerificationQueueRecovery({
    status: "pending",
    automaticCheckStatus: "processing",
    attemptCount: 1,
    processingStartedAtMs: NOW - 2 * 60 * 1000,
    lastAttemptAtMs: NOW - 2 * 60 * 1000,
    nowMs: NOW,
  });
  assert.equal(active.action, "skip");
  assert.equal(active.reasonCode, "processing_active");

  const stale = evaluateVerificationQueueRecovery({
    status: "pending",
    automaticCheckStatus: "processing",
    attemptCount: 1,
    processingStartedAtMs: NOW - 11 * 60 * 1000,
    lastAttemptAtMs: NOW - 11 * 60 * 1000,
    nowMs: NOW,
  });
  assert.equal(stale.action, "retry");
  assert.equal(stale.nextAttemptCount, 2);
  assert.equal(stale.reasonCode, "stale_processing_recovered");
});

test("exhausted retries escalate safely to manual review", () => {
  const decision = evaluateVerificationQueueRecovery({
    status: "pending",
    automaticCheckStatus: "processing",
    attemptCount: 3,
    processingStartedAtMs: NOW - 15 * 60 * 1000,
    lastAttemptAtMs: NOW - 15 * 60 * 1000,
    nowMs: NOW,
  });
  assert.equal(decision.action, "escalate_manual_review");
  assert.equal(decision.reasonCode, "analysis_retries_exhausted");
});

test("pending request respects exponential backoff before retry", () => {
  const cooling = evaluateVerificationQueueRecovery({
    status: "pending",
    automaticCheckStatus: "pending",
    attemptCount: 2,
    processingStartedAtMs: null,
    lastAttemptAtMs: NOW - 30 * 1000,
    nowMs: NOW,
  });
  assert.equal(cooling.action, "skip");
  assert.equal(cooling.reasonCode, "retry_backoff_active");

  const ready = evaluateVerificationQueueRecovery({
    status: "pending",
    automaticCheckStatus: "pending",
    attemptCount: 2,
    processingStartedAtMs: null,
    lastAttemptAtMs: NOW - 3 * 60 * 1000,
    nowMs: NOW,
  });
  assert.equal(ready.action, "retry");
  assert.equal(ready.nextAttemptCount, 3);
});
