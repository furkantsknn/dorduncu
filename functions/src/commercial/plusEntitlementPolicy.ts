export interface PlusClock {
  plusFlag: boolean;
  subscriptionExpiresAtMs: number | null;
  giftExpiresAtMs: number | null;
  subscriptionState: string;
  nowMs: number;
}

export interface PlusAccess {
  active: boolean;
  expiresAtMs: number | null;
  subscriptionActive: boolean;
  giftActive: boolean;
}

const ENTITLED_STATES = new Set([
  "SUBSCRIPTION_STATE_ACTIVE",
  "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
  "SUBSCRIPTION_STATE_CANCELED",
  "",
]);

/**
 * Combines Play subscription time and gift time.
 * An ended subscription does not remove an unexpired gift.
 * @param {PlusClock} clock Entitlement inputs.
 * @return {PlusAccess} Effective access.
 */
export function evaluatePlusAccess(clock: PlusClock): PlusAccess {
  const subscriptionActive =
    clock.plusFlag &&
    clock.subscriptionExpiresAtMs != null &&
    clock.subscriptionExpiresAtMs > clock.nowMs &&
    ENTITLED_STATES.has(clock.subscriptionState.trim());
  const giftActive =
    clock.giftExpiresAtMs != null &&
    clock.giftExpiresAtMs > clock.nowMs;
  const expires = [
    subscriptionActive ? clock.subscriptionExpiresAtMs : null,
    giftActive ? clock.giftExpiresAtMs : null,
  ].filter((value): value is number => value != null);
  const expiresAtMs = expires.length === 0 ?
    null :
    Math.max(...expires);

  return {
    active: expiresAtMs != null,
    expiresAtMs,
    subscriptionActive,
    giftActive,
  };
}

export interface GiftPlusGrant {
  id: string;
  durationMs: number;
  revoked: boolean;
}

/**
 * Appends one gift duration after the current gift end.
 * @param {object} input Stack input.
 * @return {number} New gift expiry in milliseconds.
 */
export function appendGiftDuration(input: {
  giftExpiresAtMs: number | null;
  nowMs: number;
  durationMs: number;
}): number {
  const base = input.giftExpiresAtMs != null &&
    input.giftExpiresAtMs > input.nowMs ?
    input.giftExpiresAtMs :
    input.nowMs;

  return base + input.durationMs;
}

/**
 * Removes one gift's duration and keeps every other gift.
 * @param {object} input Revoke input.
 * @return {number|null} Remaining gift expiry.
 */
export function revokeGiftDuration(input: {
  grants: GiftPlusGrant[];
  revokeId: string;
  originMs: number;
  nowMs: number;
}): number | null {
  let cursor = input.originMs;
  let expiry: number | null = null;

  for (const grant of input.grants) {
    const revoked = grant.revoked || grant.id === input.revokeId;

    if (!revoked) {
      cursor += grant.durationMs;
      expiry = cursor;
    }
  }

  if (expiry == null || expiry <= input.nowMs) {
    return expiry != null && expiry > input.nowMs ? expiry : null;
  }

  return expiry;
}
