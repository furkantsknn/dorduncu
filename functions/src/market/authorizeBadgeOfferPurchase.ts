import {FieldValue} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {firestore} from "../config/firebaseAdmin";
import {isPlusMembershipActive} from "../users/plusMembership";

const idPattern = /^[A-Za-z0-9._-]{1,100}$/;

/** Authorizes opening the Play UI for the exact Plus badge offer. */
export const authorizeBadgeOfferPurchase = onCall(
  {region: "europe-west1", enforceAppCheck: true},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Oturum gerekli.");
    }
    const data = request.data as Record<string, unknown>;
    const productId = requiredId(data.productId, "productId");
    const googlePlayProductId = requiredId(
      data.googlePlayProductId,
      "googlePlayProductId",
    );
    const purchaseOptionId = requiredId(
      data.purchaseOptionId,
      "purchaseOptionId",
    );
    const offerId = requiredId(data.offerId, "offerId");
    const [user, product] = await Promise.all([
      firestore.collection("users").doc(request.auth.uid).get(),
      firestore.collection("badge_products").doc(productId).get(),
    ]);
    if (!user.exists || !isPlusMembershipActive(user.data() ?? {})) {
      throw new HttpsError(
        "permission-denied",
        "Plus rozet teklifi için aktif Plus üyeliği gerekir.",
      );
    }
    const catalog = product.data() ?? {};
    if (!product.exists ||
        catalog.active === false ||
        String(catalog.googlePlayProductId ?? "").trim() !==
          googlePlayProductId ||
        String(catalog.googlePlayPurchaseOptionId ?? "").trim() !==
          purchaseOptionId ||
        String(catalog.plusGooglePlayOfferId ?? "").trim() !== offerId) {
      throw new HttpsError(
        "failed-precondition",
        "Plus rozet teklifi katalogla eşleşmedi.",
      );
    }
    await firestore.collection("badge_offer_authorizations")
      .doc(`${request.auth.uid}_${productId}`)
      .set({
        uid: request.auth.uid,
        productId,
        googlePlayProductId,
        purchaseOptionId,
        offerId,
        authorizedAt: FieldValue.serverTimestamp(),
        launchExpiresAt: new Date(Date.now() + 15 * 60 * 1000),
      });
    return {authorized: true};
  },
);

/**
 * Reads one short Play/catalog identifier.
 * @param {unknown} value Raw value.
 * @param {string} field Field name.
 * @return {string} Normalized identifier.
 */
function requiredId(value: unknown, field: string): string {
  const normalized = typeof value === "string" ? value.trim() : "";
  if (!idPattern.test(normalized)) {
    throw new HttpsError("invalid-argument", `${field} geçersiz.`);
  }
  return normalized;
}
