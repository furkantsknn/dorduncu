const test = require("node:test");
const assert = require("node:assert/strict");
const {Timestamp} = require("firebase-admin/firestore");
const {
  canClaimDeletionLease,
  deletionStepDone,
  sameAccountInstance,
} = require("../lib/users/accountDeletionPolicy.js");

test("an active lease prevents a concurrent worker", () => {
  const now = 1_000_000;
  assert.equal(canClaimDeletionLease({
    status: "pending",
    leaseExpiresAt: Timestamp.fromMillis(now + 1),
  }, now), false);
  assert.equal(canClaimDeletionLease({
    status: "processing",
    leaseExpiresAt: Timestamp.fromMillis(now - 1),
  }, now), true);
});

test("failed work waits for retry time then becomes claimable", () => {
  const now = 1_000_000;
  assert.equal(canClaimDeletionLease({
    status: "failed",
    nextRetryAt: Timestamp.fromMillis(now + 1),
  }, now), false);
  assert.equal(canClaimDeletionLease({
    status: "failed",
    nextRetryAt: Timestamp.fromMillis(now),
  }, now), true);
});

test("completed work and old account instances cannot continue", () => {
  assert.equal(canClaimDeletionLease({status: "completed"}, 1), false);
  assert.equal(sameAccountInstance("old", "new"), false);
  assert.equal(sameAccountInstance("same", "same"), true);
});

test("persisted steps make partial retries idempotent", () => {
  assert.equal(deletionStepDone({storageDeleted: true}, "storageDeleted"), true);
  assert.equal(deletionStepDone({storageDeleted: false}, "storageDeleted"), false);
  assert.equal(deletionStepDone(undefined, "storageDeleted"), false);
});
