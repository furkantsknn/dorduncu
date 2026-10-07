import {Timestamp} from "firebase-admin/firestore";

/**
 * Plus is active only while the server expiry is still in the future.
 *
 * A raw plus flag without an expiry does not grant Plus.
 *
 * @param {FirebaseFirestore.DocumentData} data User data.
 * @param {number} nowMs Comparison clock.
 * @return {boolean} Whether Plus is currently active.
 */
export function isPlusMembershipActive(
  data: FirebaseFirestore.DocumentData,
  nowMs: number = Date.now(),
): boolean {
  if (data.plus !== true) {
    return false;
  }

  const expiry = data.plusExpiresAt ?? data.subscriptionExpiresAt;

  if (expiry instanceof Timestamp) {
    return expiry.toMillis() > nowMs;
  }

  if (expiry instanceof Date) {
    return expiry.getTime() > nowMs;
  }

  return false;
}
