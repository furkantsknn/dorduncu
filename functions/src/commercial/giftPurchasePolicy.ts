export type GiftKind = "badge_gift" | "plus_gift";

/**
 * Ensures catalog resolution still matches the immutable gift intent.
 * @param {object} input Resolved catalog, verified Play, and intent fields.
 * @return {boolean} Whether every immutable binding still matches.
 */
export function giftIntentBindingMatches(input: {
  requestedProductId: string;
  requestedKind: GiftKind;
  requestedGooglePlayProductId: string;
  verifiedPurchaseOptionId: string;
  intentProductId: unknown;
  intentKind: unknown;
  intentGooglePlayProductId: unknown;
  intentPurchaseOptionId: unknown;
}): boolean {
  const intentOption = String(input.intentPurchaseOptionId ?? "").trim();
  return String(input.intentProductId ?? "").trim() ===
      input.requestedProductId &&
    String(input.intentKind ?? "").trim() === input.requestedKind &&
    String(input.intentGooglePlayProductId ?? "").trim() ===
      input.requestedGooglePlayProductId &&
    (intentOption === "" || intentOption === input.verifiedPurchaseOptionId);
}

/**
 * Ensures a delivered intent is replayed only with its original Play token.
 * @param {unknown} status Current intent status.
 * @param {unknown} intentTokenHash Token hash stored on the intent.
 * @param {string} verifiedTokenHash Token hash verified for this call.
 * @return {boolean} Whether processing may continue.
 */
export function giftReplayMatchesToken(
  status: unknown,
  intentTokenHash: unknown,
  verifiedTokenHash: string,
): boolean {
  return String(status ?? "") !== "delivered" ||
    String(intentTokenHash ?? "").trim() === verifiedTokenHash;
}

/** Checks recipient account availability at intent and delivery time.
 * @param {Record<string, unknown>|undefined} data Recipient profile.
 * @return {boolean} Whether the account may receive a gift.
 */
export function giftRecipientIsAvailable(
  data: Record<string, unknown> | undefined,
): boolean {
  return data != null && data.disabled !== true &&
    !["deleted", "disabled", "blocked", "suspended"]
      .includes(String(data.accountStatus ?? ""));
}

export interface GiftIntentCheck {
  buyerUid: string;
  recipientUid: string;
  friends: boolean;
  blocked: boolean;
  recipientAvailable: boolean;
  recipientOwnsBadge: boolean;
  recipientAdminBlocked?: boolean;
  recipientHasPaidSubscription: boolean;
  senderOwnsBadge: boolean;
  kind: GiftKind;
}

export interface GiftIntentDecision {
  ok: boolean;
  code: string;
}

/**
 * Decides whether a gift purchase may start.
 * The sender owning the badge does not block a gift.
 * @param {GiftIntentCheck} input Friendship and ownership.
 * @return {GiftIntentDecision} Decision.
 */
export function planGiftIntent(
  input: GiftIntentCheck,
): GiftIntentDecision {
  if (!input.buyerUid || !input.recipientUid) {
    return {ok: false, code: "missing_user"};
  }

  if (input.buyerUid === input.recipientUid) {
    return {ok: false, code: "self_gift"};
  }

  if (!input.friends) {
    return {ok: false, code: "not_friends"};
  }

  if (input.blocked) {
    return {ok: false, code: "blocked"};
  }

  if (input.kind === "badge_gift" && input.recipientAdminBlocked) {
    return {ok: false, code: "recipient_admin_blocked"};
  }

  if (!input.recipientAvailable) {
    return {ok: false, code: "recipient_unavailable"};
  }

  if (input.kind === "badge_gift" && input.recipientOwnsBadge) {
    return {ok: false, code: "recipient_owns_badge"};
  }

  if (
    input.kind === "plus_gift" &&
    input.recipientHasPaidSubscription
  ) {
    return {ok: false, code: "recipient_has_subscription"};
  }

  return {ok: true, code: "ok"};
}

export type GiftFulfillment =
  | {type: "pending"}
  | {type: "cancelled"}
  | {type: "reject"; code: string}
  | {type: "review"; code: string}
  | {
    type: "deliver";
    recipientUid: string;
    replay: boolean;
  };

/**
 * Binds a verified Play purchase to the server gift intent.
 * The client recipient is ignored.
 * @param {object} input Purchase and intent.
 * @return {GiftFulfillment} Fulfillment decision.
 */
export function resolveGiftFulfillment(input: {
  callerUid: string;
  clientRecipientUid: string;
  intentId: string;
  intentBuyerUid: string;
  intentRecipientUid: string;
  playAccountId: string;
  purchaseState: number;
  alreadyDelivered: boolean;
  friends: boolean;
  blocked: boolean;
  recipientAvailable: boolean;
  recipientOwnsBadge: boolean;
  recipientAdminBlocked?: boolean;
  recipientHasPaidSubscription: boolean;
  kind: GiftKind;
}): GiftFulfillment {
  if (input.callerUid !== input.intentBuyerUid) {
    return {type: "reject", code: "buyer_mismatch"};
  }
  if (input.clientRecipientUid &&
      input.clientRecipientUid !== input.intentRecipientUid) {
    return {type: "reject", code: "recipient_mismatch"};
  }

  if (input.playAccountId !== input.intentId) {
    return {type: "reject", code: "intent_mismatch"};
  }

  if (input.purchaseState === 2) {
    return {type: "pending"};
  }

  if (input.purchaseState === 1) {
    return {type: "cancelled"};
  }

  if (input.purchaseState !== 0) {
    return {type: "reject", code: "purchase_state"};
  }

  if (input.alreadyDelivered) {
    return {
      type: "deliver",
      recipientUid: input.intentRecipientUid,
      replay: true,
    };
  }

  if (!input.friends) {
    return {type: "review", code: "not_friends"};
  }

  if (input.blocked) {
    return {type: "review", code: "blocked"};
  }

  if (!input.recipientAvailable) {
    return {type: "review", code: "recipient_unavailable"};
  }

  if (input.kind === "badge_gift" && input.recipientAdminBlocked) {
    return {type: "review", code: "recipient_admin_blocked"};
  }

  if (input.kind === "badge_gift" && input.recipientOwnsBadge) {
    return {type: "review", code: "recipient_owns_badge"};
  }

  if (
    input.kind === "plus_gift" &&
    input.recipientHasPaidSubscription
  ) {
    return {type: "review", code: "subscription_race"};
  }

  return {
    type: "deliver",
    recipientUid: input.intentRecipientUid,
    replay: false,
  };
}

export interface BadgeGrantState {
  personalTokenHash: string;
  giftTokenHashes: string[];
}

/**
 * Revokes only the grant created by one purchase token.
 * @param {BadgeGrantState} state Current grants.
 * @param {string} tokenHash Purchase token hash.
 * @param {boolean} fullRefund Whether Play reported a full refund.
 * @return {object} Next grants and whether the badge remains.
 */
export function revokeBadgeGrant(
  state: BadgeGrantState,
  tokenHash: string,
  fullRefund: boolean,
): {state: BadgeGrantState; revokePersonal: boolean; revokeGift: boolean} {
  if (!fullRefund || !tokenHash) {
    return {
      state,
      revokePersonal: false,
      revokeGift: false,
    };
  }

  const revokePersonal = state.personalTokenHash === tokenHash;
  const revokeGift = state.giftTokenHashes.includes(tokenHash);

  return {
    revokePersonal,
    revokeGift,
    state: {
      personalTokenHash: revokePersonal ? "" : state.personalTokenHash,
      giftTokenHashes: state.giftTokenHashes.filter(
        (hash) => hash !== tokenHash,
      ),
    },
  };
}

/**
 * A badge remains while any independent grant is left.
 * @param {BadgeGrantState} state Grants.
 * @return {boolean} Whether the badge stays.
 */
export function badgeRemains(state: BadgeGrantState): boolean {
  return state.personalTokenHash.length > 0 ||
    state.giftTokenHashes.length > 0;
}
