import {assertCurrentAdminSession} from "../security/adminAuthorization";
/* eslint-disable max-len */
import {
  onCall,
} from "firebase-functions/v2/https";
import {
  FieldValue,
} from "firebase-admin/firestore";

import {firestore} from "../config/firebaseAdmin";
import {
  assertAdminPermission,
} from "../security/adminAuthorization";

interface BadgeSeedItem {
  id: string;
  name: string;
  emoji: string;
  categoryId: string;
  sortOrder: number;
}

/**
 * Canonical V1 badge catalog. Ids match GameCatalog exactly.
 */
const BADGE_PRODUCTS: BadgeSeedItem[] = [
  {id: "okey", name: "Okey", emoji: "🎴", categoryId: "masa_oyunlari", sortOrder: 1},
  {id: "okey_101", name: "101", emoji: "🀄", categoryId: "masa_oyunlari", sortOrder: 2},
  {id: "batak", name: "Batak", emoji: "♠️", categoryId: "masa_oyunlari", sortOrder: 3},
  {id: "tavla", name: "Tavla", emoji: "🎲", categoryId: "masa_oyunlari", sortOrder: 4},
  {id: "satranc", name: "Satranç", emoji: "♟️", categoryId: "masa_oyunlari", sortOrder: 5},
  {id: "bric", name: "Briç", emoji: "🃏", categoryId: "masa_oyunlari", sortOrder: 6},
  {id: "king", name: "King", emoji: "👑", categoryId: "masa_oyunlari", sortOrder: 7},
  {id: "monopoly", name: "Monopoly", emoji: "🏠", categoryId: "masa_oyunlari", sortOrder: 8},
  {id: "uno", name: "Uno", emoji: "🟥", categoryId: "masa_oyunlari", sortOrder: 9},
  {id: "jenga", name: "Jenga", emoji: "🧱", categoryId: "masa_oyunlari", sortOrder: 10},
  {id: "scrabble", name: "Scrabble", emoji: "🔤", categoryId: "masa_oyunlari", sortOrder: 11},
  {id: "tombala", name: "Tombala", emoji: "🔢", categoryId: "masa_oyunlari", sortOrder: 12},
  {id: "ea_fc", name: "EA FC", emoji: "⚽", categoryId: "konsol_oyunlari", sortOrder: 13},
  {id: "efootball", name: "eFootball", emoji: "🎮", categoryId: "konsol_oyunlari", sortOrder: 14},
  {id: "tekken", name: "Tekken", emoji: "🥊", categoryId: "konsol_oyunlari", sortOrder: 15},
  {id: "tenis", name: "Tenis", emoji: "🎾", categoryId: "raket_sporlari", sortOrder: 16},
  {id: "masa_tenisi", name: "Masa Tenisi", emoji: "🏓", categoryId: "raket_sporlari", sortOrder: 17},
  {id: "badminton", name: "Badminton", emoji: "🏸", categoryId: "raket_sporlari", sortOrder: 18},
  {id: "squash", name: "Squash", emoji: "🎾", categoryId: "raket_sporlari", sortOrder: 19},
  {id: "pickleball", name: "Pickleball", emoji: "🏓", categoryId: "raket_sporlari", sortOrder: 20},
  {id: "futbol", name: "Futbol", emoji: "⚽", categoryId: "takim_sporlari", sortOrder: 21},
  {id: "basketbol", name: "Basketbol", emoji: "🏀", categoryId: "takim_sporlari", sortOrder: 22},
  {id: "voleybol", name: "Voleybol", emoji: "🏐", categoryId: "takim_sporlari", sortOrder: 23},
  {id: "hentbol", name: "Hentbol", emoji: "🤾", categoryId: "takim_sporlari", sortOrder: 24},
  {id: "golf", name: "Golf", emoji: "⛳", categoryId: "premium_sporlar", sortOrder: 25},
  {id: "yelken", name: "Yelken", emoji: "⛵", categoryId: "premium_sporlar", sortOrder: 26},
  {id: "kurek", name: "Kürek", emoji: "🚣", categoryId: "premium_sporlar", sortOrder: 27},
  {id: "binicilik", name: "Binicilik", emoji: "🏇", categoryId: "premium_sporlar", sortOrder: 28},
  {id: "kayak", name: "Kayak", emoji: "⛷️", categoryId: "premium_sporlar", sortOrder: 29},
  {id: "snowboard", name: "Snowboard", emoji: "🏂", categoryId: "premium_sporlar", sortOrder: 30},
  {id: "paintball", name: "Paintball", emoji: "🎯", categoryId: "premium_sporlar", sortOrder: 31},
];

/**
 * Older seed ids that are not in the V1 game catalog.
 * Documents stay in place so purchase history remains readable.
 */
const LEGACY_BADGE_IDS = [
  "bilardo",
  "bowling",
  "dart",
  "langirt",
  "playstation",
  "kosu",
  "bisiklet",
  "yuzme",
];

export const seedBadgeProducts = onCall(
  {
    region: "europe-west1",
    enforceAppCheck: true,
  },
  async (request) => {
    assertAdminPermission(request, "content.manage");
    await assertCurrentAdminSession(request);

    const uid = request.auth.uid;
    const collection = firestore.collection("badge_products");
    const canonicalReferences = BADGE_PRODUCTS.map(
      (product) => collection.doc(product.id),
    );
    const legacyReferences = LEGACY_BADGE_IDS.map(
      (id) => collection.doc(id),
    );
    const existing = await firestore.getAll(
      ...canonicalReferences,
      ...legacyReferences,
    );
    const existingById = new Map(
      existing.map((snapshot) => [snapshot.id, snapshot]),
    );

    const batch = firestore.batch();
    let legacyDeactivatedCount = 0;

    for (const product of BADGE_PRODUCTS) {
      const snapshot = existingById.get(product.id);
      const current = snapshot?.data() ?? {};
      const payload: Record<string, unknown> = {
        gameId: product.id,
        gameName: product.name,
        categoryId: product.categoryId,
        title: `${product.name} Rozeti`,
        description: `${product.name} rozetini profilinde sergile.`,
        emoji: product.emoji,
        active: true,
        sortOrder: product.sortOrder,
        productType: "game_badge",
        label: "official",
        catalogStatus: "canonical",
        plusPriceKurus: 39900,
        plusGooglePlayOfferId: current.plusGooglePlayOfferId ?? "",
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: uid,
      };
      // googlePlayProductId and googlePlayBasePlanId stay out of this
      // payload so a seed cannot overwrite an existing Play mapping.

      if (!snapshot?.exists) {
        payload.imageUrl = "";
        payload.priceKurus = 49900;
        payload.createdAt = FieldValue.serverTimestamp();
      } else if (current.priceKurus == null) {
        payload.priceKurus = 49900;
      }

      batch.set(collection.doc(product.id), payload, {merge: true});
    }

    for (const id of LEGACY_BADGE_IDS) {
      const snapshot = existingById.get(id);

      if (!snapshot?.exists) {
        continue;
      }

      legacyDeactivatedCount += 1;
      batch.set(
        collection.doc(id),
        {
          active: false,
          catalogStatus: "legacy",
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: uid,
        },
        {merge: true},
      );
    }

    await batch.commit();

    return {
      success: true,
      createdOrUpdatedCount: BADGE_PRODUCTS.length,
      legacyDeactivatedCount,
    };
  },
);
