/* eslint-disable valid-jsdoc */
import {Timestamp} from "firebase-admin/firestore";

export interface DeletionLeaseState {
  status?: unknown;
  leaseExpiresAt?: unknown;
  nextRetryAt?: unknown;
}

/** Shared lease decision used by every account-deletion worker entrypoint. */
export function canClaimDeletionLease(
  data: DeletionLeaseState,
  nowMillis: number,
): boolean {
  const lease = data.leaseExpiresAt;
  if (lease instanceof Timestamp && lease.toMillis() > nowMillis) return false;
  const status = String(data.status ?? "");
  if (!["pending", "failed", "processing"].includes(status)) return false;
  if (status === "failed" && data.nextRetryAt instanceof Timestamp &&
    data.nextRetryAt.toMillis() > nowMillis) return false;
  return true;
}

/** Prevents a request created for an old Auth record moving to a new one. */
export function sameAccountInstance(
  expectedCreationTime: unknown,
  actualCreationTime: string,
): boolean {
  return typeof expectedCreationTime === "string" &&
    expectedCreationTime.length > 0 &&
    expectedCreationTime === actualCreationTime;
}

/** Completed steps survive failures and make retries idempotent. */
export function deletionStepDone(
  steps: unknown,
  name: string,
): boolean {
  return steps !== null && typeof steps === "object" &&
    (steps as Record<string, unknown>)[name] === true;
}
