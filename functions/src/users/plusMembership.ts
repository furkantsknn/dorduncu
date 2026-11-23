import {Timestamp} from "firebase-admin/firestore";

import {evaluatePlusAccess} from "../commercial/plusEntitlementPolicy";

/**
 * Reads a Firestore timestamp as epoch milliseconds.
 * @param {unknown} value Raw value.
 * @return {number|null} Milliseconds.
 */
function millis(value: unknown): number | null {
  if (value instanceof Timestamp) {
    return value.toMillis();
  }

  if (value instanceof Date) {
    return value.getTime();
  }

  return null;
}

/**
 * Plus is active while a Play subscription or a gift period remains.
 *
 * A raw plus flag without a future expiry does not grant Plus.
 * Subscription expiry does not erase a later gift expiry.
 *
 * @param {FirebaseFirestore.DocumentData} data User data.
 * @param {number} nowMs Comparison clock.
 * @return {boolean} Whether Plus is currently active.
 */
export function isPlusMembershipActive(
  data: FirebaseFirestore.DocumentData,
  nowMs: number = Date.now(),
): boolean {
  if (data.plusAdminGranted === true) {
    return true;
  }

  const giftExpiresAtMs = millis(data.plusGiftExpiresAt);
  const explicitSubscription = millis(data.plusSubscriptionExpiresAt);
  const legacyExpiry = millis(
    data.plusExpiresAt ?? data.subscriptionExpiresAt,
  );
  const subscriptionExpiresAtMs = explicitSubscription ??
    (giftExpiresAtMs == null ? legacyExpiry : null);

  return evaluatePlusAccess({
    plusFlag: data.plus === true || data.isPlus === true,
    subscriptionExpiresAtMs,
    giftExpiresAtMs,
    subscriptionState: String(data.plusSubscriptionState ?? ""),
    nowMs,
  }).active;
}
