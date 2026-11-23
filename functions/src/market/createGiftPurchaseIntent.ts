/* eslint-disable max-len */
import {FieldValue} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {canonicalListPriceKurus} from "../commercial/marketCatalog";
import {planGiftIntent, GiftKind, giftRecipientIsAvailable} from "../commercial/giftPurchasePolicy";
import {firestore} from "../config/firebaseAdmin";
import {badgeIsEntitled} from "./badgeEntitlementPolicy";
import {eventCategories} from "../events/eventCatalog";

/**
 * Creates an immutable gift intent before Google Play payment.
 */
export const createGiftPurchaseIntent = onCall(
  {region: "europe-west1", enforceAppCheck: true},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Hediye için giriş yapmalısınız.");
    }

    const buyerUid = request.auth.uid;
    const data = request.data as Record<string, unknown>;
    const recipientUid = String(data.recipientUid ?? "").trim();
    const productId = String(data.productId ?? "").trim();
    const kind = String(data.kind ?? "") as GiftKind;

    if (kind !== "badge_gift" && kind !== "plus_gift") {
      throw new HttpsError("invalid-argument", "Hediye türü geçersiz.");
    }
    if (kind === "badge_gift" && !eventCategories.some((category) => category.games.some((game) => game.id === productId))) throw new HttpsError("failed-precondition", "Kanonik olmayan rozet hediye satışına kapalı.");

    const collection = kind === "badge_gift" ? "badge_products" : "plus_products";
    const product = await firestore.collection(collection).doc(productId).get();
    const productData = product.data() ?? {};
    const playProductId = String(productData.giftGooglePlayProductId ?? "").trim();

    if (!product.exists || productData.active === false || !playProductId || playProductId === String(productData.googlePlayProductId ?? "")) {
      throw new HttpsError(
        "failed-precondition",
        "Bu hediye şu anda satın alınamıyor.",
      );
    }

    const [friend, buyerBlock, recipientBlock, recipient, owned] = await Promise.all([
      firestore.collection("users").doc(buyerUid).collection("friends").doc(recipientUid).get(),
      firestore.collection("users").doc(buyerUid).collection("blockedUsers").doc(recipientUid).get(),
      firestore.collection("users").doc(recipientUid).collection("blockedUsers").doc(buyerUid).get(),
      firestore.collection("users").doc(recipientUid).get(),
      kind === "badge_gift" ?
        firestore.collection("users").doc(recipientUid).collection("owned_badges").doc(productId).get() :
        Promise.resolve(null),
    ]);
    const senderOwns = kind === "badge_gift" &&
      (await firestore.collection("users").doc(buyerUid).collection("owned_badges").doc(productId).get()).exists;
    const subscription = recipient.data()?.plusSubscriptionExpiresAt;
    const decision = planGiftIntent({
      buyerUid,
      recipientUid,
      friends: friend.exists,
      blocked: buyerBlock.exists || recipientBlock.exists,
      recipientAvailable: giftRecipientIsAvailable(recipient.data()),
      recipientOwnsBadge: owned?.exists === true &&
        badgeIsEntitled(owned.data()),
      recipientAdminBlocked: owned?.data()?.adminBlocked === true,
      recipientHasPaidSubscription: subscription != null &&
        typeof (subscription as {toMillis?: () => number}).toMillis === "function" &&
        (subscription as {toMillis: () => number}).toMillis() > Date.now(),
      senderOwnsBadge: senderOwns,
      kind,
    });

    if (!decision.ok) {
      throw new HttpsError("failed-precondition", giftIntentMessage(decision.code));
    }

    const campaign = await activeOfferFor(`${kind}:${productId}`);
    const intent = firestore.collection("gift_purchase_intents").doc();

    await intent.set({
      buyerUid,
      recipientUid,
      productId,
      kind,
      googlePlayProductId: playProductId,
      purchaseOptionId: String(productData.giftGooglePlayPurchaseOptionId ?? ""),
      campaignId: campaign?.campaignId ?? "",
      campaignOfferId: campaign?.offerId ?? "",
      normalPriceKurus: canonicalListPriceKurus(kind),
      durationDays: kind === "plus_gift" ? 30 : null,
      status: "awaiting_purchase",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    return {
      giftIntentId: intent.id,
      googlePlayProductId: playProductId,
      campaignOfferId: campaign?.offerId ?? "",
      normalPriceKurus: canonicalListPriceKurus(kind),
      durationDays: kind === "plus_gift" ? 30 : null,
    };
  },
);

/**
 * Reads a synced active offer for one product, if Play already has it.
 * @param {string} productKey Campaign product key.
 * @return {Promise<object|null>} Offer.
 */
async function activeOfferFor(
  productKey: string,
): Promise<{campaignId: string; offerId: string} | null> {
  const snapshot = await firestore.collection("market_campaigns")
    .where("status", "==", "active")
    .limit(20)
    .get();

  for (const document of snapshot.docs) {
    const line = (document.data().products ?? {})[productKey] as
      | {syncStatus?: string; offerId?: string}
      | undefined;

    if (line?.syncStatus === "synced" && line.offerId) {
      return {campaignId: document.id, offerId: line.offerId};
    }
  }

  return null;
}

/**
 * Maps a gift refusal code to a user-facing reason.
 * @param {string} code Decision code.
 * @return {string} Message.
 */
function giftIntentMessage(code: string): string {
  switch (code) {
  case "self_gift":
    return "Kendine hediye gönderemezsin.";
  case "not_friends":
    return "Hediye yalnızca arkadaş listesindeki birine gönderilebilir.";
  case "blocked":
    return "Engellenmiş kullanıcıya hediye gönderilemez.";
  case "recipient_unavailable":
    return "Alıcı hesabı şu anda kullanılamıyor.";
  case "recipient_owns_badge":
    return "Alıcı bu rozete zaten sahip.";
  case "recipient_admin_blocked":
    return "Bu rozet alıcı için yönetici tarafından engellenmiş.";
  case "recipient_has_subscription":
    return "Alıcının aktif ücretli Plus aboneliği var. Hediye Plus başlatılamaz.";
  default:
    return "Hediye başlatılamadı.";
  }
}
