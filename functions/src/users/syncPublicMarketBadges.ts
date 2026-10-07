import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {FieldValue} from "firebase-admin/firestore";

import {firestore} from "../config/firebaseAdmin";

const GENERIC_BADGE_TITLES = new Set([
  "oyun rozeti",
  "oyun rozet",
]);

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
    const owned = await firestore
      .collection("users")
      .doc(uid)
      .collection("owned_badges")
      .get();

    const marketBadges = [];

    for (const document of owned.docs) {
      const data = document.data();
      if (data.googlePlayEntitled === false) {
        continue;
      }

      const badgeId = readText(data.badgeId) ||
        readText(data.productId) ||
        document.id;
      const productId = readText(data.productId) || badgeId;
      let title = readText(data.title);
      let gameId = readText(data.gameId);
      let gameName = readText(data.gameName);
      let emoji = readText(data.emoji);
      let imageUrl = readText(data.imageUrl);

      if (
        isGenericTitle(title) ||
        emoji.length === 0 ||
        imageUrl.length === 0
      ) {
        const product = await firestore
          .collection("badge_products")
          .doc(productId || badgeId)
          .get();
        const productData = product.data() ?? {};
        const productTitle = readText(productData.title);
        if (!isGenericTitle(productTitle)) {
          title = productTitle;
        }
        if (gameId.length === 0) {
          gameId = readText(productData.gameId);
        }
        if (gameName.length === 0) {
          gameName = readText(productData.gameName);
        }
        if (emoji.length === 0) {
          emoji = readText(productData.emoji);
        }
        if (imageUrl.length === 0) {
          imageUrl = readText(productData.imageUrl);
        }
      }

      if (isGenericTitle(title) && gameName.length > 0) {
        title = gameName;
      }

      marketBadges.push({
        badgeId,
        productId: productId || badgeId,
        title,
        gameId,
        gameName,
        emoji,
        imageUrl,
      });
    }

    await firestore.collection("public_profiles").doc(uid).set(
      {
        marketBadges,
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  },
);

/**
 * Reads a trimmed string.
 * @param {unknown} value Raw value.
 * @return {string} Trimmed text.
 */
function readText(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/**
 * True for the placeholder badge title.
 * @param {string} value Title.
 * @return {boolean} Whether the title is generic.
 */
function isGenericTitle(value: string): boolean {
  return GENERIC_BADGE_TITLES.has(value.trim().toLowerCase());
}
