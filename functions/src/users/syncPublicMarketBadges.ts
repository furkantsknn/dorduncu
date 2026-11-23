/* eslint-disable valid-jsdoc, max-len */
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {FieldValue} from "firebase-admin/firestore";

import {firestore} from "../config/firebaseAdmin";
import {projectPublicMarketBadges} from "./publicMarketBadges";
import {publicProfileWriteAllowed} from "./publicProfileWritePolicy";

/**
 * Copies owned market badges onto the public profile.
 *
 * owned_badges keeps purchase tokens, hashes, prices and operation ids.
 * Those fields stay private. public_profiles.marketBadges only carries
 * the id, name and visual fields needed to draw the badge.
 */
export const syncPublicMarketBadges = onDocumentWritten(
  {
    document: "users/{uid}/owned_badges/{badgeId}",
    region: "europe-west1",
  },
  async (event) => {
    const uid = event.params.uid;
    await syncCurrentPublicMarketBadges(uid);
  },
);

/** Projects badges only while the current account may have a public profile. */
export async function syncCurrentPublicMarketBadges(uid: string): Promise<void> {
  await firestore.runTransaction(async (transaction) => {
    const userReference = firestore.collection("users").doc(uid);
    const deletionReference = firestore.collection("accountDeletionRequests")
      .doc(uid);
    const publicReference = firestore.collection("public_profiles").doc(uid);
    const ownedQuery = userReference.collection("owned_badges");
    const [user, deletion, owned] = await Promise.all([
      transaction.get(userReference),
      transaction.get(deletionReference),
      transaction.get(ownedQuery),
    ]);
    const userData = user.exists ? user.data() ?? {} : null;
    const deletionData = deletion.exists ? deletion.data() ?? {} : null;
    if (!publicProfileWriteAllowed(userData, deletionData)) {
      transaction.delete(publicReference);
      return;
    }
    const productIds = [...new Set(owned.docs.map((document) =>
      String(document.data().productId ?? document.id)))];
    const products = new Map<string, FirebaseFirestore.DocumentData>();
    for (const productId of productIds) {
      const product = await transaction.get(
        firestore.collection("badge_products").doc(productId));
      if (product.exists) products.set(productId, product.data() ?? {});
    }
    const marketBadges = await projectPublicMarketBadges(
      owned.docs.map((document) => ({id: document.id, data: document.data()})),
      async (productId) => products.get(productId),
    );
    transaction.set(publicReference, {
      marketBadges,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  });
}
