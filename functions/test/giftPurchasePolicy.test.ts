import assert from "node:assert/strict";
import test from "node:test";

import {
  badgeRemains,
  giftIntentBindingMatches,
  giftReplayMatchesToken,
  planGiftIntent,
  resolveGiftFulfillment,
  revokeBadgeGrant,
} from "../src/commercial/giftPurchasePolicy.ts";
import {
  appendGiftDuration,
  evaluatePlusAccess,
  revokeGiftDuration,
} from "../src/commercial/plusEntitlementPolicy.ts";

const day = 24 * 60 * 60 * 1000;

test("hediye intent ürün, tür, Play ürünü ve satın alma seçeneğine bağlıdır", () => {
  const base = {
    requestedProductId: "badge-a",
    requestedKind: "badge_gift" as const,
    requestedGooglePlayProductId: "gift.badge.a",
    verifiedPurchaseOptionId: "buy",
    intentProductId: "badge-a",
    intentKind: "badge_gift",
    intentGooglePlayProductId: "gift.badge.a",
    intentPurchaseOptionId: "buy",
  };
  assert.equal(giftIntentBindingMatches(base), true);
  assert.equal(giftIntentBindingMatches({
    ...base,
    intentProductId: "badge-b",
  }), false);
  assert.equal(giftIntentBindingMatches({
    ...base,
    intentKind: "plus_gift",
  }), false);
  assert.equal(giftIntentBindingMatches({
    ...base,
    intentGooglePlayProductId: "gift.badge.changed",
  }), false);
  assert.equal(giftIntentBindingMatches({
    ...base,
    verifiedPurchaseOptionId: "discount",
  }), false);
});

test("teslim edilmiş intent yalnız aynı Play tokenıyla tekrar işlenir", () => {
  assert.equal(giftReplayMatchesToken(
    "awaiting_purchase",
    "",
    "token-a",
  ), true);
  assert.equal(giftReplayMatchesToken(
    "delivered",
    "token-a",
    "token-a",
  ), true);
  assert.equal(giftReplayMatchesToken(
    "delivered",
    "token-a",
    "token-b",
  ), false);
});

test("kendine hediye ve sahip olunan rozet başlamaz", () => {
  assert.equal(planGiftIntent({
    buyerUid: "a",
    recipientUid: "a",
    friends: true,
    blocked: false,
    recipientAvailable: true,
    recipientOwnsBadge: false,
    recipientHasPaidSubscription: false,
    senderOwnsBadge: false,
    kind: "badge_gift",
  }).code, "self_gift");

  assert.equal(planGiftIntent({
    buyerUid: "a",
    recipientUid: "b",
    friends: true,
    blocked: false,
    recipientAvailable: true,
    recipientOwnsBadge: true,
    recipientHasPaidSubscription: false,
    senderOwnsBadge: true,
    kind: "badge_gift",
  }).code, "recipient_owns_badge");
});

test("alıcıdaki admin engeli niyeti ve teslimatı durdurur", () => {
  const intent = planGiftIntent({
    buyerUid: "a",
    recipientUid: "b",
    friends: true,
    blocked: false,
    recipientAvailable: true,
    recipientOwnsBadge: false,
    recipientAdminBlocked: true,
    recipientHasPaidSubscription: false,
    senderOwnsBadge: false,
    kind: "badge_gift",
  });
  const fulfillment = resolveGiftFulfillment({
    callerUid: "a",
    clientRecipientUid: "b",
    intentId: "intent-1",
    intentBuyerUid: "a",
    intentRecipientUid: "b",
    playAccountId: "intent-1",
    purchaseState: 0,
    alreadyDelivered: false,
    friends: true,
    blocked: false,
    recipientAvailable: true,
    recipientOwnsBadge: false,
    recipientAdminBlocked: true,
    recipientHasPaidSubscription: false,
    kind: "badge_gift",
  });

  assert.equal(intent.code, "recipient_admin_blocked");
  assert.deepEqual(fulfillment, {
    type: "review",
    code: "recipient_admin_blocked",
  });
});

test("gönderenin rozeti hediyeyi engellemez ve arkadaş değişebilir", () => {
  const first = planGiftIntent({
    buyerUid: "a",
    recipientUid: "b",
    friends: true,
    blocked: false,
    recipientAvailable: true,
    recipientOwnsBadge: false,
    recipientHasPaidSubscription: false,
    senderOwnsBadge: true,
    kind: "badge_gift",
  });
  const second = planGiftIntent({
    buyerUid: "a",
    recipientUid: "c",
    friends: true,
    blocked: false,
    recipientAvailable: true,
    recipientOwnsBadge: false,
    recipientHasPaidSubscription: false,
    senderOwnsBadge: true,
    kind: "badge_gift",
  });

  assert.equal(first.ok, true);
  assert.equal(second.ok, true);
});

test("istemci alıcıyı değiştiremez ve tekrar teslim aynı alıcıda kalır", () => {
  const changed = resolveGiftFulfillment({
    callerUid: "buyer",
    clientRecipientUid: "attacker",
    intentId: "intent-1",
    intentBuyerUid: "buyer",
    intentRecipientUid: "friend",
    playAccountId: "intent-1",
    purchaseState: 0,
    alreadyDelivered: false,
    friends: true,
    blocked: false,
    recipientAvailable: true,
    recipientOwnsBadge: false,
    recipientHasPaidSubscription: false,
    kind: "badge_gift",
  });
  const replay = resolveGiftFulfillment({
    callerUid: "buyer",
    clientRecipientUid: "friend",
    intentId: "intent-1",
    intentBuyerUid: "buyer",
    intentRecipientUid: "friend",
    playAccountId: "intent-1",
    purchaseState: 0,
    alreadyDelivered: true,
    friends: false,
    blocked: true,
    recipientAvailable: false,
    recipientOwnsBadge: true,
    recipientHasPaidSubscription: false,
    kind: "badge_gift",
  });

  assert.equal(changed.type, "reject");
  if (replay.type === "deliver") {
    assert.equal(replay.recipientUid, "friend");
    assert.equal(replay.replay, true);
  }
});

test("ödeme beklerken teslim olmaz, yarış inceleme kaydı olur", () => {
  assert.equal(resolveGiftFulfillment({
    callerUid: "buyer",
    clientRecipientUid: "friend",
    intentId: "intent-1",
    intentBuyerUid: "buyer",
    intentRecipientUid: "friend",
    playAccountId: "intent-1",
    purchaseState: 2,
    alreadyDelivered: false,
    friends: true,
    blocked: false,
    recipientAvailable: true,
    recipientOwnsBadge: false,
    recipientHasPaidSubscription: false,
    kind: "badge_gift",
  }).type, "pending");

  const race = resolveGiftFulfillment({
    callerUid: "buyer",
    clientRecipientUid: "friend",
    intentId: "intent-1",
    intentBuyerUid: "buyer",
    intentRecipientUid: "friend",
    playAccountId: "intent-1",
    purchaseState: 0,
    alreadyDelivered: false,
    friends: true,
    blocked: false,
    recipientAvailable: true,
    recipientOwnsBadge: false,
    recipientHasPaidSubscription: true,
    kind: "plus_gift",
  });

  assert.equal(race.type, "review");
});

test("arkadaşlık ve engel fulfillment anında yeniden doğrulanır", () => {
  const base = {
    callerUid: "buyer",
    clientRecipientUid: "friend",
    intentId: "intent-1",
    intentBuyerUid: "buyer",
    intentRecipientUid: "friend",
    playAccountId: "intent-1",
    purchaseState: 0,
    alreadyDelivered: false,
    recipientAvailable: true,
    recipientOwnsBadge: false,
    recipientHasPaidSubscription: false,
    kind: "badge_gift" as const,
  };
  assert.deepEqual(resolveGiftFulfillment({...base, friends: false, blocked: false}), {
    type: "review",
    code: "not_friends",
  });
  assert.deepEqual(resolveGiftFulfillment({...base, friends: true, blocked: true}), {
    type: "review",
    code: "blocked",
  });
});

test("Plus hediyesi süreye eklenir ve iade yalnız o süreyi kaldırır", () => {
  const now = 1_000_000;
  const firstEnd = appendGiftDuration({
    giftExpiresAtMs: null,
    nowMs: now,
    durationMs: 30 * day,
  });
  const secondEnd = appendGiftDuration({
    giftExpiresAtMs: firstEnd,
    nowMs: now,
    durationMs: 30 * day,
  });
  const afterRevoke = revokeGiftDuration({
    grants: [
      {id: "g1", durationMs: 30 * day, revoked: false},
      {id: "g2", durationMs: 30 * day, revoked: false},
    ],
    revokeId: "g2",
    originMs: now,
    nowMs: now,
  });
  const access = evaluatePlusAccess({
    plusFlag: true,
    subscriptionExpiresAtMs: now - day,
    giftExpiresAtMs: firstEnd,
    subscriptionState: "SUBSCRIPTION_STATE_EXPIRED",
    nowMs: now,
  });

  assert.equal(secondEnd - firstEnd, 30 * day);
  assert.equal(afterRevoke, firstEnd);
  assert.equal(access.subscriptionActive, false);
  assert.equal(access.giftActive, true);
  assert.equal(access.active, true);
});

test("rozet iadesi kişisel rozeti ve diğer hediyeyi silmez", () => {
  const next = revokeBadgeGrant({
    personalTokenHash: "personal",
    giftTokenHashes: ["gift-a", "gift-b"],
  }, "gift-a", true);

  assert.equal(next.revokeGift, true);
  assert.equal(next.revokePersonal, false);
  assert.deepEqual(next.state.giftTokenHashes, ["gift-b"]);
  assert.equal(badgeRemains(next.state), true);
  assert.equal(badgeRemains({
    personalTokenHash: "",
    giftTokenHashes: [],
  }), false);
});
