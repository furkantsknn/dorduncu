import {
  onCall,
} from "firebase-functions/v2/https";
import {
  FieldValue,
} from "firebase-admin/firestore";

import {firestore} from "../config/firebaseAdmin";
import {assertAdmin} from "../security/assertAdmin";

interface BadgeSeedItem {
  id: string;
  name: string;
  emoji: string;
  categoryId: string;
  sortOrder: number;
}

const BADGE_PRODUCTS: BadgeSeedItem[] = [
  {
    id: "okey",
    name: "Okey",
    emoji: "🎴",
    categoryId: "masa_oyunlari",
    sortOrder: 1,
  },
  {
    id: "okey_101",
    name: "101",
    emoji: "🀄",
    categoryId: "masa_oyunlari",
    sortOrder: 2,
  },
  {
    id: "batak",
    name: "Batak",
    emoji: "♠️",
    categoryId: "masa_oyunlari",
    sortOrder: 3,
  },
  {
    id: "tavla",
    name: "Tavla",
    emoji: "🎲",
    categoryId: "masa_oyunlari",
    sortOrder: 4,
  },
  {
    id: "satranc",
    name: "Satranç",
    emoji: "♟️",
    categoryId: "masa_oyunlari",
    sortOrder: 5,
  },
  {
    id: "bric",
    name: "Briç",
    emoji: "🃏",
    categoryId: "masa_oyunlari",
    sortOrder: 6,
  },
  {
    id: "king",
    name: "King",
    emoji: "👑",
    categoryId: "masa_oyunlari",
    sortOrder: 7,
  },
  {
    id: "monopoly",
    name: "Monopoly",
    emoji: "🏠",
    categoryId: "masa_oyunlari",
    sortOrder: 8,
  },
  {
    id: "bilardo",
    name: "Bilardo",
    emoji: "🎱",
    categoryId: "salon_oyunlari",
    sortOrder: 9,
  },
  {
    id: "bowling",
    name: "Bowling",
    emoji: "🎳",
    categoryId: "salon_oyunlari",
    sortOrder: 10,
  },
  {
    id: "dart",
    name: "Dart",
    emoji: "🎯",
    categoryId: "salon_oyunlari",
    sortOrder: 11,
  },
  {
    id: "langirt",
    name: "Langırt",
    emoji: "⚽",
    categoryId: "salon_oyunlari",
    sortOrder: 12,
  },
  {
    id: "playstation",
    name: "PlayStation",
    emoji: "🎮",
    categoryId: "dijital_oyunlar",
    sortOrder: 13,
  },
  {
    id: "futbol",
    name: "Futbol",
    emoji: "⚽",
    categoryId: "takim_sporlari",
    sortOrder: 14,
  },
  {
    id: "basketbol",
    name: "Basketbol",
    emoji: "🏀",
    categoryId: "takim_sporlari",
    sortOrder: 15,
  },
  {
    id: "voleybol",
    name: "Voleybol",
    emoji: "🏐",
    categoryId: "takim_sporlari",
    sortOrder: 16,
  },
  {
    id: "hentbol",
    name: "Hentbol",
    emoji: "🤾",
    categoryId: "takim_sporlari",
    sortOrder: 17,
  },
  {
    id: "tenis",
    name: "Tenis",
    emoji: "🎾",
    categoryId: "raket_sporlari",
    sortOrder: 18,
  },
  {
    id: "masa_tenisi",
    name: "Masa Tenisi",
    emoji: "🏓",
    categoryId: "raket_sporlari",
    sortOrder: 19,
  },
  {
    id: "badminton",
    name: "Badminton",
    emoji: "🏸",
    categoryId: "raket_sporlari",
    sortOrder: 20,
  },
  {
    id: "squash",
    name: "Squash",
    emoji: "🎾",
    categoryId: "raket_sporlari",
    sortOrder: 21,
  },
  {
    id: "kosu",
    name: "Koşu",
    emoji: "🏃",
    categoryId: "bireysel_sporlar",
    sortOrder: 22,
  },
  {
    id: "bisiklet",
    name: "Bisiklet",
    emoji: "🚴",
    categoryId: "bireysel_sporlar",
    sortOrder: 23,
  },
  {
    id: "yuzme",
    name: "Yüzme",
    emoji: "🏊",
    categoryId: "bireysel_sporlar",
    sortOrder: 24,
  },
  {
    id: "golf",
    name: "Golf",
    emoji: "⛳",
    categoryId: "premium_sporlar",
    sortOrder: 25,
  },
  {
    id: "yelken",
    name: "Yelken",
    emoji: "⛵",
    categoryId: "premium_sporlar",
    sortOrder: 26,
  },
  {
    id: "kurek",
    name: "Kürek",
    emoji: "🚣",
    categoryId: "premium_sporlar",
    sortOrder: 27,
  },
  {
    id: "binicilik",
    name: "Binicilik",
    emoji: "🏇",
    categoryId: "premium_sporlar",
    sortOrder: 28,
  },
  {
    id: "kayak",
    name: "Kayak",
    emoji: "⛷️",
    categoryId: "premium_sporlar",
    sortOrder: 29,
  },
  {
    id: "snowboard",
    name: "Snowboard",
    emoji: "🏂",
    categoryId: "premium_sporlar",
    sortOrder: 30,
  },
];


export const seedBadgeProducts = onCall(
  {
    region: "europe-west1",
    enforceAppCheck: false,
  },
  async (request) => {
    assertAdmin(request);

    const uid = request.auth.uid;

    const batch = firestore.batch();

    for (const product of BADGE_PRODUCTS) {
      const reference = firestore
        .collection("badge_products")
        .doc(product.id);

      batch.set(
        reference,
        {
          gameId: product.id,
          gameName: product.name,
          categoryId: product.categoryId,
          title: `${product.name} Rozeti`,
          description:
            `${product.name} rozetini profilinde sergile.`,
          emoji: product.emoji,
          imageUrl: "",
          priceKurus: 29900,
          active: true,
          sortOrder: product.sortOrder,
          productType: "game_badge",
          label: "official",
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: uid,
          createdAt: FieldValue.serverTimestamp(),
        },
        {
          merge: true,
        }
      );
    }

    await batch.commit();

    return {
      success: true,
      createdOrUpdatedCount: BADGE_PRODUCTS.length,
    };
  }
);
