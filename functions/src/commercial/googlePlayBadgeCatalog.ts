/* eslint-disable max-len, require-jsdoc */
import {GoogleAuth} from "google-auth-library";
import {FieldValue} from "firebase-admin/firestore";
import {onRequest} from "firebase-functions/v2/https";

import {firestore} from "../config/firebaseAdmin";

const PACKAGE_NAME = "com.dortapp.dort";
const PLAY_BASE = "https://androidpublisher.googleapis.com/androidpublisher/v3";
const PLAY_SCOPE = "https://www.googleapis.com/auth/androidpublisher";
const PURCHASE_OPTION_ID = "buy";

interface BadgeDefinition {
  id: string;
  tr: string;
  en: string;
  de: string;
  categoryId: string;
  emoji: string;
}

const BADGES: BadgeDefinition[] = [
  ["okey", "Okey", "Okey", "Okey", "masa_oyunlari", "🎴"],
  ["okey_101", "101", "101 Okey", "101 Okey", "masa_oyunlari", "🀄"],
  ["batak", "Batak", "Batak", "Batak", "masa_oyunlari", "♠️"],
  ["tavla", "Tavla", "Backgammon", "Backgammon", "masa_oyunlari", "🎲"],
  ["satranc", "Satranç", "Chess", "Schach", "masa_oyunlari", "♟️"],
  ["bric", "Briç", "Bridge", "Bridge", "masa_oyunlari", "🃏"],
  ["king", "King", "King", "King", "masa_oyunlari", "👑"],
  ["monopoly", "Monopoly", "Monopoly", "Monopoly", "masa_oyunlari", "🏠"],
  ["uno", "Uno", "Uno", "Uno", "masa_oyunlari", "🟥"],
  ["jenga", "Jenga", "Jenga", "Jenga", "masa_oyunlari", "🧱"],
  ["scrabble", "Scrabble", "Scrabble", "Scrabble", "masa_oyunlari", "🔤"],
  ["tombala", "Tombala", "Bingo", "Bingo", "masa_oyunlari", "🔢"],
  ["ea_fc", "EA FC", "EA FC", "EA FC", "konsol_oyunlari", "⚽"],
  ["efootball", "eFootball", "eFootball", "eFootball", "konsol_oyunlari", "🎮"],
  ["tekken", "Tekken", "Tekken", "Tekken", "konsol_oyunlari", "🥊"],
  ["tenis", "Tenis", "Tennis", "Tennis", "raket_sporlari", "🎾"],
  ["masa_tenisi", "Masa Tenisi", "Table Tennis", "Tischtennis", "raket_sporlari", "🏓"],
  ["badminton", "Badminton", "Badminton", "Badminton", "raket_sporlari", "🏸"],
  ["squash", "Squash", "Squash", "Squash", "raket_sporlari", "🎾"],
  ["pickleball", "Pickleball", "Pickleball", "Pickleball", "raket_sporlari", "🏓"],
  ["futbol", "Futbol", "Football", "Fußball", "takim_sporlari", "⚽"],
  ["basketbol", "Basketbol", "Basketball", "Basketball", "takim_sporlari", "🏀"],
  ["voleybol", "Voleybol", "Volleyball", "Volleyball", "takim_sporlari", "🏐"],
  ["hentbol", "Hentbol", "Handball", "Handball", "takim_sporlari", "🤾"],
  ["golf", "Golf", "Golf", "Golf", "premium_sporlar", "⛳"],
  ["yelken", "Yelken", "Sailing", "Segeln", "premium_sporlar", "⛵"],
  ["kurek", "Kürek", "Rowing", "Rudern", "premium_sporlar", "🚣"],
  ["binicilik", "Binicilik", "Horse Riding", "Reiten", "premium_sporlar", "🏇"],
  ["kayak", "Kayak", "Skiing", "Skifahren", "premium_sporlar", "⛷️"],
  ["snowboard", "Snowboard", "Snowboarding", "Snowboarden", "premium_sporlar", "🏂"],
  ["paintball", "Paintball", "Paintball", "Paintball", "premium_sporlar", "🎯"],
].map(([id, tr, en, de, categoryId, emoji]) => ({id, tr, en, de, categoryId, emoji}));

interface PlayPurchaseOption {
  purchaseOptionId?: string;
  state?: string;
  regionalPricingAndAvailabilityConfigs?: Array<{
    regionCode?: string;
    price?: {currencyCode?: string; units?: string; nanos?: number};
    availability?: string;
  }>;
}

interface PlayProduct {
  packageName?: string;
  productId?: string;
  purchaseOptions?: PlayPurchaseOption[];
  regionsVersion?: {version?: string};
  taxAndComplianceSettings?: Record<string, unknown>;
}

const playAuth = new GoogleAuth({scopes: [PLAY_SCOPE]});

export const manageGooglePlayBadgeCatalog = onRequest(
  {
    region: "europe-west1",
    invoker: "private",
    maxInstances: 1,
    timeoutSeconds: 300,
  },
  async (request, response) => {
    if (process.env.FUNCTIONS_EMULATOR === "true" || process.env.FIRESTORE_EMULATOR_HOST) {
      response.status(501).json({error: "Dev catalog provider writes disabled"});
      return;
    }
    if (request.method !== "GET" && request.method !== "POST") {
      response.status(405).end();
      return;
    }

    try {
      const existing = await listProducts();
      const targetIds = new Set(BADGES.map((badge) => playId(badge.id)));
      const targetProducts = existing.filter((item) =>
        targetIds.has(String(item.productId ?? "")),
      );

      if (request.method === "GET") {
        response.status(200).json(summarize(targetProducts));
        return;
      }

      const version = targetProducts
        .map((item) => String(item.regionsVersion?.version ?? "").trim())
        .find((value) => value.length > 0);
      if (!version) {
        throw new Error("Play regions version is unavailable.");
      }

      const byId = new Map(
        targetProducts.map((item) => [String(item.productId), item]),
      );
      const requests = BADGES.map((badge) => {
        const id = playId(badge.id);
        const current = byId.get(id);
        const optionId = String(
          current?.purchaseOptions?.[0]?.purchaseOptionId ?? PURCHASE_OPTION_ID,
        );
        return {
          oneTimeProduct: buildProduct(badge, optionId, current),
          updateMask: "listings,purchaseOptions,taxAndComplianceSettings",
          regionsVersion: {version},
          allowMissing: true,
          latencyTolerance:
            "PRODUCT_UPDATE_LATENCY_TOLERANCE_LATENCY_TOLERANT",
        };
      });

      const updated = await playRequest<{oneTimeProducts?: PlayProduct[]}>(
        `${PLAY_BASE}/applications/${PACKAGE_NAME}/oneTimeProducts:batchUpdate`,
        "POST",
        {requests},
      );
      const returned = updated.oneTimeProducts ?? [];
      const activate = returned.flatMap((product) =>
        (product.purchaseOptions ?? [])
          .filter((option) => option.state !== "ACTIVE")
          .map((option) => ({
            activatePurchaseOptionRequest: {
              packageName: PACKAGE_NAME,
              productId: product.productId,
              purchaseOptionId: option.purchaseOptionId,
              latencyTolerance:
                "PRODUCT_UPDATE_LATENCY_TOLERANCE_LATENCY_TOLERANT",
            },
          })),
      );

      if (activate.length > 0) {
        await playRequest(
          `${PLAY_BASE}/applications/${PACKAGE_NAME}/oneTimeProducts/-/` +
            "purchaseOptions:batchUpdateStates",
          "POST",
          {requests: activate},
        );
      }

      const verified = (await listProducts()).filter((item) =>
        targetIds.has(String(item.productId ?? "")),
      );
      const verification = summarize(verified);
      if (!verification.ready) {
        response.status(409).json(verification);
        return;
      }

      const batch = firestore.batch();
      BADGES.forEach((badge, index) => {
        batch.set(
          firestore.collection("badge_products").doc(badge.id),
          {
            gameId: badge.id,
            gameName: badge.tr,
            title: `${badge.tr} Rozeti`,
            description: `${badge.tr} rozetini profilinde sergile.`,
            localized: {
              tr: {gameName: badge.tr, title: `${badge.tr} Rozeti`},
              en: {gameName: badge.en, title: `${badge.en} Badge`},
              de: {gameName: badge.de, title: `${badge.de}-Abzeichen`},
            },
            emoji: badge.emoji,
            categoryId: badge.categoryId,
            sortOrder: index + 1,
            productType: "game_badge",
            googlePlayProductId: playId(badge.id),
            googlePlayPurchaseOptionId: verification.optionIds[playId(badge.id)],
            priceKurus: 49900,
            active: true,
            catalogStatus: "canonical",
            updatedAt: FieldValue.serverTimestamp(),
            updatedBy: "system:google_play_catalog",
          },
          {merge: true},
        );
      });
      await batch.commit();
      console.info("Google Play badge catalog verified and mapped.", {
        targetCount: verification.targetCount,
        found: verification.found,
        active: verification.active,
        correctPrice: verification.correctPrice,
        turkeyOnly: verification.turkeyOnly,
        firestoreMapped: BADGES.length,
      });
      response.status(200).json({
        ...verification,
        firestoreMapped: BADGES.length,
      });
    } catch (error) {
      console.error("Google Play badge catalog operation failed.", safeError(error));
      response.status(500).json({error: safeError(error)});
    }
  },
);

function buildProduct(
  badge: BadgeDefinition,
  optionId: string,
  current?: PlayProduct,
): Record<string, unknown> {
  return {
    packageName: PACKAGE_NAME,
    productId: playId(badge.id),
    listings: [
      listing("tr-TR", `${badge.tr} Rozeti`, `${badge.tr} rozetini profilinde sergile.`),
      listing("en-US", `${badge.en} Badge`, `Display your ${badge.en} badge on your profile.`),
      listing("de-DE", `${badge.de}-Abzeichen`, `Zeige dein ${badge.de}-Abzeichen in deinem Profil.`),
    ],
    taxAndComplianceSettings: current?.taxAndComplianceSettings ?? {
      isTokenizedDigitalAsset: false,
    },
    purchaseOptions: [{
      purchaseOptionId: optionId,
      buyOption: {legacyCompatible: true, multiQuantityEnabled: false},
      regionalPricingAndAvailabilityConfigs: [{
        regionCode: "TR",
        price: {currencyCode: "TRY", units: "499", nanos: 0},
        availability: "AVAILABLE",
      }],
    }],
  };
}

function listing(languageCode: string, title: string, description: string) {
  return {languageCode, title, description};
}

async function listProducts(): Promise<PlayProduct[]> {
  const products: PlayProduct[] = [];
  let pageToken = "";
  do {
    const query = new URLSearchParams({pageSize: "100"});
    if (pageToken) query.set("pageToken", pageToken);
    const data = await playRequest<{
      oneTimeProducts?: PlayProduct[];
      nextPageToken?: string;
    }>(
      `${PLAY_BASE}/applications/${PACKAGE_NAME}/oneTimeProducts?${query}`,
      "GET",
    );
    products.push(...(data.oneTimeProducts ?? []));
    pageToken = String(data.nextPageToken ?? "");
  } while (pageToken);
  return products;
}

async function playRequest<T>(
  url: string,
  method: "GET" | "POST",
  body?: unknown,
): Promise<T> {
  const client = await playAuth.getClient();
  const result = await client.request<T>({
    url,
    method,
    data: body,
    validateStatus: () => true,
  });
  if (result.status < 200 || result.status >= 300) {
    throw new Error(`Play HTTP ${result.status}: ${safePlayReason(result.data)}`);
  }
  return result.data;
}

function summarize(products: PlayProduct[]) {
  const optionIds: Record<string, string> = {};
  let active = 0;
  let correctPrice = 0;
  let turkeyOnly = 0;
  for (const product of products) {
    const id = String(product.productId ?? "");
    const option = product.purchaseOptions?.[0];
    optionIds[id] = String(option?.purchaseOptionId ?? "");
    if (option?.state === "ACTIVE") active += 1;
    const configs = option?.regionalPricingAndAvailabilityConfigs ?? [];
    const tr = configs.find((item) => item.regionCode === "TR");
    if (
      tr?.availability === "AVAILABLE" &&
      tr.price?.currencyCode === "TRY" &&
      tr.price?.units === "499" &&
      Number(tr.price?.nanos ?? 0) === 0
    ) correctPrice += 1;
    if (configs.length === 1 && configs[0].regionCode === "TR") turkeyOnly += 1;
  }
  return {
    targetCount: BADGES.length,
    found: products.length,
    active,
    correctPrice,
    turkeyOnly,
    ready: products.length === BADGES.length &&
      active === BADGES.length &&
      correctPrice === BADGES.length &&
      turkeyOnly === BADGES.length,
    optionIds,
  };
}

function playId(gameId: string): string {
  return `dort_badge_${gameId}`;
}

function safePlayReason(data: unknown): string {
  if (data && typeof data === "object") {
    const error = (data as {error?: {status?: unknown; message?: unknown}}).error;
    const status = String(error?.status ?? "").trim();
    const message = String(error?.message ?? "").trim();
    return `${status}${status && message ? ": " : ""}${message}`.slice(0, 240);
  }
  return "unknown error";
}

function safeError(error: unknown): string {
  return error instanceof Error ? error.message.slice(0, 300) : "unknown error";
}
