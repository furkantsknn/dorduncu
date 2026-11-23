import assert from "node:assert/strict";
import test from "node:test";

import {
  planIdentityReservationRelease,
} from "../src/users/identityReservationPolicy.ts";
import type {
  IdentityReservationKey,
  IdentityReservationRequest,
} from "../src/users/identityReservationPolicy.ts";

const owner = "owner-uid";
const submission = "submission-a";

/**
 * Builds a reserved key for the fixture owner.
 * @param {Partial<IdentityReservationKey>} overrides Changed fields.
 * @return {IdentityReservationKey} Key state.
 */
function reservedKey(
  overrides: Partial<IdentityReservationKey> = {},
): IdentityReservationKey {
  return {
    exists: true,
    uid: owner,
    status: "reserved",
    hasApprovedAt: false,
    submissionId: submission,
    ...overrides,
  };
}

/**
 * Builds the matching terminal request.
 * @param {Partial<IdentityReservationRequest>} overrides Changed fields.
 * @return {IdentityReservationRequest} Request state.
 */
function requestFor(
  overrides: Partial<IdentityReservationRequest> = {},
): IdentityReservationRequest {
  return {
    uid: owner,
    status: "expired",
    submissionId: submission,
    ...overrides,
  };
}

test("an expired reserved identity is released", () => {
  const plan = planIdentityReservationRelease({
    key: reservedKey(),
    request: requestFor(),
    ownerApproved: false,
  });

  assert.equal(plan.release, true);
  assert.equal(plan.reason, "released");
});

test("a rejected reserved identity is released", () => {
  const plan = planIdentityReservationRelease({
    key: reservedKey(),
    request: requestFor({status: "rejected"}),
    ownerApproved: false,
  });

  assert.equal(plan.release, true);
});

test("an approved key is kept when cleanup races approval", () => {
  const approvedStatus = planIdentityReservationRelease({
    key: reservedKey({status: "approved"}),
    request: requestFor(),
    ownerApproved: false,
  });
  const approvedAt = planIdentityReservationRelease({
    key: reservedKey({hasApprovedAt: true}),
    request: requestFor({status: "rejected"}),
    ownerApproved: false,
  });

  assert.equal(approvedStatus.release, false);
  assert.equal(approvedStatus.reason, "approved");
  assert.equal(approvedAt.release, false);
  assert.equal(approvedAt.reason, "approved");
});

test("a newer submission keeps its reservation", () => {
  const plan = planIdentityReservationRelease({
    key: reservedKey({submissionId: "submission-b"}),
    request: requestFor({
      status: "expired",
      submissionId: submission,
    }),
    ownerApproved: false,
  });

  assert.equal(plan.release, false);
  assert.equal(plan.reason, "newer_submission");
});

test("repeating the release is a no-op", () => {
  const plan = planIdentityReservationRelease({
    key: reservedKey({exists: false}),
    request: requestFor(),
    ownerApproved: false,
  });

  assert.equal(plan.release, false);
  assert.equal(plan.reason, "already_absent");
});

test("pending review and revision stay reserved", () => {
  const pending = planIdentityReservationRelease({
    key: reservedKey(),
    request: requestFor({status: "pending"}),
    ownerApproved: false,
  });
  const revision = planIdentityReservationRelease({
    key: reservedKey(),
    request: requestFor({status: "revision"}),
    ownerApproved: false,
  });

  assert.equal(pending.reason, "request_not_terminal");
  assert.equal(revision.reason, "request_not_terminal");
});

test("a deletion block is not released", () => {
  const plan = planIdentityReservationRelease({
    key: reservedKey({status: "blocked_after_deletion"}),
    request: requestFor({status: "rejected"}),
    ownerApproved: false,
  });

  assert.equal(plan.release, false);
  assert.equal(plan.reason, "blocked_after_deletion");
});

test("an approved owner keeps the reservation", () => {
  const plan = planIdentityReservationRelease({
    key: reservedKey(),
    request: requestFor({status: "rejected"}),
    ownerApproved: true,
  });

  assert.equal(plan.release, false);
  assert.equal(plan.reason, "owner_approved");
});

test("another account's reservation is not released", () => {
  const plan = planIdentityReservationRelease({
    key: reservedKey({uid: "other-uid"}),
    request: requestFor({status: "rejected"}),
    ownerApproved: false,
  });

  assert.equal(plan.release, false);
  assert.equal(plan.reason, "owner_mismatch");
});

test("a legacy reserved key can be released once", () => {
  const plan = planIdentityReservationRelease({
    key: reservedKey({submissionId: ""}),
    request: requestFor({
      status: "expired",
      submissionId: "",
    }),
    ownerApproved: false,
  });

  assert.equal(plan.release, true);
});
