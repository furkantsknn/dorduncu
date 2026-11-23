/* eslint-disable max-len */
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

import {writeAuditLogInTransaction} from "../audit/writeAuditLog";
import {
  reserveCommercialOperation,
  transitionCommercialOperation,
} from "../commercial/commercialLedger";
import {
  giftIntentBindingMatches,
  giftRecipientIsAvailable,
  giftReplayMatchesToken,
  resolveGiftFulfillment,
} from "../commercial/giftPurchasePolicy";
import {
  consumeGooglePlayProduct,
  inspectGooglePlayProduct,
  verifyGooglePlayProduct,
} from "../commercial/googlePlayVerification";
import {
  appendGiftDuration,
  evaluatePlusAccess,
} from "../commercial/plusEntitlementPolicy";
import {PLUS_GIFT_DAYS} from "../commercial/marketCatalog";
import {firestore} from "../config/firebaseAdmin";
import {writeUserNotificationInTransaction} from "../notifications/writeUserNotification";
import {badgeIsEntitled} from "./badgeEntitlementPolicy";

const GIFT_MS = PLUS_GIFT_DAYS * 24 * 60 * 60 * 1000;

interface GiftFulfillInput {
  buyerUid: string;
  googlePlayProductId: string;
  purchaseToken: string;
  giftIntentId: string;
  clientRecipientUid: string;
  internalProductId: string;
  kind: "badge_gift" | "plus_gift";
}

/**
 * Verifies a gift purchase and delivers it to the intent recipient.
 * @param {GiftFulfillInput} input Purchase input.
 * @return {Promise<Record<string, unknown>>} Delivery result.
 */
export async function fulfillGiftPurchase(
  input: GiftFulfillInput,
): Promise<Record<string, unknown>> {
  if (!input.giftIntentId) {
    throw new HttpsError(
      "failed-precondition",
      "Hediye kaydı olmadan teslimat yapılmaz.",
    );
  }

  const intentReference = firestore
    .collection("gift_purchase_intents")
    .doc(input.giftIntentId);
  const intentSnapshot = await intentReference.get();

  if (!intentSnapshot.exists) {
    throw new HttpsError("not-found", "Hediye kaydı bulunamadı.");
  }

  const intent = intentSnapshot.data() ?? {};
  if (intent.status === "refunded_verified") throw new HttpsError("failed-precondition", "İadesi doğrulanan hediye tekrar teslim edilemez.");
  const verified = await inspectGooglePlayProduct(
    input.googlePlayProductId,
    input.purchaseToken,
  );
  // v1 inspection preserves pending/cancelled states; purchased items must also
  // prove the actual product/option from Play's v2 line item.
  if (verified.purchaseState === 0) {
    Object.assign(verified, await verifyGooglePlayProduct(input.googlePlayProductId, input.purchaseToken));
  }

  if (!giftIntentBindingMatches({
    requestedProductId: input.internalProductId,
    requestedKind: input.kind,
    requestedGooglePlayProductId: input.googlePlayProductId,
    verifiedPurchaseOptionId: verified.purchaseOptionId,
    intentProductId: intent.productId,
    intentKind: intent.kind,
    intentGooglePlayProductId: intent.googlePlayProductId,
    intentPurchaseOptionId: intent.purchaseOptionId,
  })) {
    throw new HttpsError(
      "failed-precondition",
      "Play ürünü hediye kaydıyla eşleşmiyor.",
    );
  }

  const recipientUid = String(intent.recipientUid ?? "");
  const [recipient, friend, buyerBlock, recipientBlock, ownedBadge] = await Promise.all([
    firestore.collection("users").doc(recipientUid).get(),
    firestore.collection("users").doc(input.buyerUid).collection("friends").doc(recipientUid).get(),
    firestore.collection("users").doc(input.buyerUid).collection("blockedUsers").doc(recipientUid).get(),
    firestore.collection("users").doc(recipientUid).collection("blockedUsers").doc(input.buyerUid).get(),
    input.kind === "badge_gift" ?
      firestore.collection("users").doc(recipientUid)
        .collection("owned_badges").doc(input.internalProductId).get() : Promise.resolve(null),
  ]);
  const ownsBadge = ownedBadge?.exists === true &&
    badgeIsEntitled(ownedBadge.data());
  const subscriptionExpiry = recipient.data()?.plusSubscriptionExpiresAt;
  const hasSubscription = subscriptionExpiry instanceof Timestamp &&
    subscriptionExpiry.toMillis() > Date.now();
  const decision = resolveGiftFulfillment({
    callerUid: input.buyerUid,
    clientRecipientUid: input.clientRecipientUid,
    intentId: input.giftIntentId,
    intentBuyerUid: String(intent.buyerUid ?? ""),
    intentRecipientUid: recipientUid,
    playAccountId: verified.obfuscatedExternalAccountId ?? "",
    purchaseState: verified.purchaseState,
    alreadyDelivered: intent.status === "delivered",
    friends: friend.exists,
    blocked: buyerBlock.exists || recipientBlock.exists,
    recipientAvailable: giftRecipientIsAvailable(recipient.data()),
    recipientOwnsBadge: ownsBadge && intent.status !== "delivered",
    recipientAdminBlocked:
      ownedBadge?.data()?.adminBlocked === true && intent.status !== "delivered",
    recipientHasPaidSubscription: hasSubscription,
    kind: input.kind,
  });

  if (decision.type === "pending") {
    await intentReference.set({
      status: "pending",
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return {success: false, status: "pending", giftIntentId: input.giftIntentId};
  }

  if (decision.type === "cancelled") {
    await intentReference.set({
      status: "cancelled",
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return {success: false, status: "cancelled", giftIntentId: input.giftIntentId};
  }

  if (decision.type === "reject") {
    throw new HttpsError("permission-denied", "Hediye satın alması doğrulanamadı.");
  }

  if (decision.type === "review") {
    await firestore.collection("gift_reviews").doc(verified.purchaseTokenHash).set({
      giftIntentId: input.giftIntentId,
      buyerUid: input.buyerUid,
      recipientUid,
      productId: input.internalProductId,
      kind: input.kind,
      reason: decision.code,
      status: "refund_review",
      purchaseTokenHash: verified.purchaseTokenHash,
      providerOrderId: verified.orderId,
      providerVerified: true,
      googlePlayProductId: input.googlePlayProductId,
      consumed: verified.consumed,
      createdAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    await intentReference.set({
      status: "review",
      reviewReason: decision.code,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return {
      success: false,
      status: "review",
      reason: decision.code,
      giftIntentId: input.giftIntentId,
    };
  }

  const delivered = await deliverGift(input, decision.recipientUid, verified);
  if (delivered.success !== true) return delivered;
  let consumed = verified.consumed;

  if (!consumed) {
    try {
      await consumeGooglePlayProduct(
        input.googlePlayProductId,
        input.purchaseToken,
      );
      consumed = true;
      await intentReference.set({
        consumePending: false,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    } catch (error) {
      console.error("Gift consume will be retried.", error);
      await intentReference.set({
        consumePending: true,
        purchaseTokenHash: verified.purchaseTokenHash,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
  }

  return {...delivered, consumed, status: "delivered"};
}

/**
 * Writes one idempotent gift delivery.
 * @param {GiftFulfillInput} input Purchase input.
 * @param {string} recipientUid Intent recipient.
 * @param {object} verified Verified purchase.
 * @return {Promise<Record<string, unknown>>} Delivery summary.
 */
async function deliverGift(
  input: GiftFulfillInput,
  recipientUid: string,
  verified: Awaited<ReturnType<typeof inspectGooglePlayProduct>>,
): Promise<Record<string, unknown>> {
  return firestore.runTransaction(async (transaction) => {
    const intentReference = firestore
      .collection("gift_purchase_intents")
      .doc(input.giftIntentId);
    const badgeReference = firestore.collection("users").doc(recipientUid)
      .collection("owned_badges").doc(input.internalProductId);
    const userReference = firestore.collection("users").doc(recipientUid);
    const [intentSnapshot, badgeSnapshot, userSnapshot, registrySnapshot, friendSnapshot, buyerBlockSnapshot, recipientBlockSnapshot] = await Promise.all([
      transaction.get(intentReference),
      transaction.get(badgeReference),
      transaction.get(userReference),
      transaction.get(firestore.collection("google_play_purchase_tokens").doc(verified.purchaseTokenHash)),
      transaction.get(firestore.collection("users").doc(input.buyerUid).collection("friends").doc(recipientUid)),
      transaction.get(firestore.collection("users").doc(input.buyerUid).collection("blockedUsers").doc(recipientUid)),
      transaction.get(userReference.collection("blockedUsers").doc(input.buyerUid)),
    ]);
    const intent = intentSnapshot.data() ?? {};
    if (intent.status === "refunded_verified" || intent.buyerUid !== input.buyerUid || intent.recipientUid !== recipientUid) throw new HttpsError("failed-precondition", "Hediye bağlantısı değişti veya iade edildi.");
    if (registrySnapshot.exists && (registrySnapshot.get("giftIntentId") !== input.giftIntentId || registrySnapshot.get("uid") !== input.buyerUid || registrySnapshot.get("recipientUid") !== recipientUid)) {
      throw new HttpsError("failed-precondition", "Satın alma başka bir hediye kaydına bağlı.");
    }

    if (!giftIntentBindingMatches({
      requestedProductId: input.internalProductId,
      requestedKind: input.kind,
      requestedGooglePlayProductId: input.googlePlayProductId,
      verifiedPurchaseOptionId: verified.purchaseOptionId,
      intentProductId: intent.productId,
      intentKind: intent.kind,
      intentGooglePlayProductId: intent.googlePlayProductId,
      intentPurchaseOptionId: intent.purchaseOptionId,
    })) {
      throw new HttpsError(
        "aborted",
        "Hediye eşlemesi değişti. Satın alma tekrar doğrulanmalı.",
      );
    }

    if (!giftReplayMatchesToken(
      intent.status,
      intent.purchaseTokenHash,
      verified.purchaseTokenHash,
    )) {
      throw new HttpsError(
        "failed-precondition",
        "Hediye kaydı farklı bir Play satın almasıyla teslim edilmiş.",
      );
    }

    if (intent.status === "delivered") {
      return {
        success: true,
        idempotentReplay: true,
        recipientUid: String(intent.recipientUid ?? ""),
        giftIntentId: input.giftIntentId,
        productId: input.internalProductId,
        kind: input.kind,
        operationId: String(intent.operationId ?? "replay"),
      };
    }

    const currentSubscription = userSnapshot.get("plusSubscriptionExpiresAt");
    const currentDecision = resolveGiftFulfillment({
      callerUid: input.buyerUid,
      clientRecipientUid: input.clientRecipientUid,
      intentId: input.giftIntentId,
      intentBuyerUid: intent.buyerUid,
      intentRecipientUid: recipientUid,
      playAccountId: verified.obfuscatedExternalAccountId ?? "",
      purchaseState: verified.purchaseState,
      alreadyDelivered: false,
      friends: friendSnapshot.exists,
      blocked: buyerBlockSnapshot.exists || recipientBlockSnapshot.exists,
      recipientAvailable: giftRecipientIsAvailable(userSnapshot.data()),
      recipientOwnsBadge: badgeSnapshot.exists && badgeIsEntitled(badgeSnapshot.data()),
      recipientAdminBlocked: badgeSnapshot.get("adminBlocked") === true,
      recipientHasPaidSubscription: currentSubscription instanceof Timestamp && currentSubscription.toMillis() > Date.now(),
      kind: input.kind,
    });
    if (currentDecision.type !== "deliver") {
      const reason = currentDecision.type === "review" || currentDecision.type === "reject" ? currentDecision.code : "purchase_state";
      transaction.set(firestore.collection("gift_reviews").doc(verified.purchaseTokenHash), {giftIntentId: input.giftIntentId, buyerUid: input.buyerUid, recipientUid, productId: input.internalProductId, kind: input.kind, reason, status: "refund_review", purchaseTokenHash: verified.purchaseTokenHash, providerOrderId: verified.orderId, providerVerified: true, googlePlayProductId: input.googlePlayProductId, consumed: verified.consumed, createdAt: FieldValue.serverTimestamp()}, {merge: true});
      transaction.update(intentReference, {status: "review", reviewReason: reason, updatedAt: FieldValue.serverTimestamp()});
      return {success: false, status: "review", reason, giftIntentId: input.giftIntentId};
    }

    const reservation = await reserveCommercialOperation(
      firestore,
      transaction,
      {
        userUid: input.buyerUid,
        type: input.kind === "plus_gift" ?
          "digital_plus_gift" :
          "digital_badge_gift",
        provider: "google_play",
        idempotencyScope: "google_play_gift_token",
        idempotencyKey: input.purchaseToken,
        providerTransactionId: verified.orderId,
        providerReference: verified.purchaseTokenHash,
        money: {
          currency: "TRY",
          grossAmountMinor: Number(intent.normalPriceKurus ?? 0),
          feeAmountMinor: 0,
          netAmountMinor: Number(intent.normalPriceKurus ?? 0),
        },
        relatedProductId: input.internalProductId,
        metadata: {
          buyerUid: input.buyerUid,
          beneficiaryUid: recipientUid,
          giftIntentId: input.giftIntentId,
          purchaseTokenHash: verified.purchaseTokenHash,
          amountSource: "catalog_nominal",
          providerAmountVerified: false,
          kind: input.kind,
        },
      },
      {actorUid: input.buyerUid, source: "fulfillGiftPurchase"},
    );

    if (!reservation.created) {
      throw new HttpsError("failed-precondition", "Satın alma kaydı mevcut; teslimat doğrulanmadan başarı bildirilemez.");
    }

    if (input.kind === "badge_gift") {
      const currentHashes = Array.isArray(badgeSnapshot.data()?.giftTokenHashes) ?
        badgeSnapshot.data()?.giftTokenHashes :
        [];

      transaction.set(badgeReference, {
        badgeId: input.internalProductId,
        productId: input.internalProductId,
        source: badgeSnapshot.exists ? badgeSnapshot.data()?.source : "google_play_gift",
        giftTokenHashes: [...currentHashes, verified.purchaseTokenHash],
        giftedByUid: input.buyerUid,
        updatedAt: FieldValue.serverTimestamp(),
        createdAt: badgeSnapshot.exists ?
          badgeSnapshot.data()?.createdAt ?? FieldValue.serverTimestamp() :
          FieldValue.serverTimestamp(),
      }, {merge: true});
    } else {
      const userData = userSnapshot.data() ?? {};
      const currentGift = userData.plusGiftExpiresAt instanceof Timestamp ?
        userData.plusGiftExpiresAt.toMillis() :
        null;
      const now = Date.now();
      const giftExpiresAtMs = appendGiftDuration({
        giftExpiresAtMs: currentGift,
        nowMs: now,
        durationMs: GIFT_MS,
      });
      const subscription = userData.plusSubscriptionExpiresAt instanceof Timestamp ?
        userData.plusSubscriptionExpiresAt.toMillis() :
        null;
      const access = evaluatePlusAccess({
        plusFlag: true,
        subscriptionExpiresAtMs: subscription,
        giftExpiresAtMs,
        subscriptionState: String(userData.plusSubscriptionState ?? ""),
        nowMs: now,
      });
      const grants = Array.isArray(userData.plusGiftGrants) ?
        userData.plusGiftGrants :
        [];
      const grantId = reservation.operationId;

      transaction.set(userReference, {
        plus: access.active,
        isPlus: access.active,
        plusGiftExpiresAt: Timestamp.fromMillis(giftExpiresAtMs),
        plusExpiresAt: Timestamp.fromMillis(access.expiresAtMs ?? giftExpiresAtMs),
        plusGiftOriginAt: userData.plusGiftOriginAt ?? Timestamp.fromMillis(now),
        plusGiftGrants: [
          ...grants,
          {id: grantId, durationMs: GIFT_MS, revoked: false},
        ],
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      transaction.set(
        firestore.collection("google_play_purchase_tokens")
          .doc(verified.purchaseTokenHash),
        {giftGrantId: grantId},
        {merge: true},
      );
    }

    transaction.set(
      firestore.collection("google_play_purchase_tokens")
        .doc(verified.purchaseTokenHash),
      {
        purchaseTokenHash: verified.purchaseTokenHash,
        uid: input.buyerUid,
        recipientUid,
        productId: input.internalProductId,
        googlePlayProductId: input.googlePlayProductId,
        kind: input.kind,
        giftIntentId: input.giftIntentId,
        active: true,
        providerOrderId: verified.orderId,
        providerVerified: true,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    transaction.set(intentReference, {
      status: "delivered",
      purchaseTokenHash: verified.purchaseTokenHash,
      operationId: reservation.operationId,
      providerOrderId: verified.orderId,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    transaction.create(
      firestore.collection("gift_deliveries").doc(reservation.operationId),
      {
        buyerUid: input.buyerUid,
        recipientUid,
        productId: input.internalProductId,
        kind: input.kind,
        giftIntentId: input.giftIntentId,
        purchaseTokenHash: verified.purchaseTokenHash,
        providerOrderId: verified.orderId,
        createdAt: FieldValue.serverTimestamp(),
      },
    );
    writeUserNotificationInTransaction(firestore, transaction, {
      userId: recipientUid,
      actorId: input.buyerUid,
      type: input.kind === "plus_gift" ? "plus_gift_received" : "badge_gift_received",
      title: "Hediye",
      message: "Sana bir hediye ulaştı.",
      route: "profile",
      data: {productId: input.internalProductId, giftIntentId: input.giftIntentId},
    });
    transitionCommercialOperation(
      firestore,
      transaction,
      reservation.operationId,
      "paid",
      {actorUid: input.buyerUid, source: "fulfillGiftPurchase"},
      {beneficiaryUid: recipientUid, kind: input.kind},
    );
    writeAuditLogInTransaction(firestore, transaction, {
      action: "google_play_gift_delivered",
      performedBy: "system:google_play",
      targetUid: recipientUid,
      metadata: {
        buyerUid: input.buyerUid,
        productId: input.internalProductId,
        giftIntentId: input.giftIntentId,
        purchaseTokenHash: verified.purchaseTokenHash,
      },
    });

    return {
      success: true,
      idempotentReplay: false,
      recipientUid,
      giftIntentId: input.giftIntentId,
      operationId: reservation.operationId,
      productId: input.internalProductId,
      kind: input.kind,
    };
  });
}
