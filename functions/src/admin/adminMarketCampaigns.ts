import {assertCurrentAdminSession} from "../security/adminAuthorization";
/* eslint-disable max-len */
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {defineString} from "firebase-functions/params";

import {writeAuditLog} from "../audit/writeAuditLog";
import {
  CampaignProductTarget,
  CampaignStatus,
  assertCampaignDraft,
  campaignClockAction,
  campaignOfferId,
  findCampaignConflict,
  previewCampaign,
  statusAfterSync,
} from "../commercial/marketCampaignPolicy";
import {canonicalListPriceKurus, playPaidFraction} from "../commercial/marketCatalog";
import {callAndroidPublisher} from "../commercial/googlePlayVerification";
import {
  oneTimeDiscountBatchBody,
  oneTimeOfferBatchPath,
  subscriptionDiscountOfferBody,
  subscriptionOfferCreatePath,
  subscriptionOfferStatePath,
} from "../commercial/playOfferPayloads";
import {firestore} from "../config/firebaseAdmin";
import {assertAdminPermission} from "../security/adminAuthorization";

const packageName = defineString("ANDROID_PACKAGE_NAME", {default: "com.dortapp.dort"});
const regionsVersionParam = defineString("PLAY_REGIONS_VERSION", {default: ""});

/**
 * Saves a campaign draft and returns the price preview.
 */
export const adminSaveMarketCampaign = onCall(
  {region: "europe-west1", enforceAppCheck: true},
  async (request) => {
    assertAdminPermission(request, "finance.manage");
    await assertCurrentAdminSession(request);
    const draft = readDraft(request.data, request.auth?.uid ?? "");
    try {
      assertCampaignDraft(draft);
    } catch (error) {
      throw new HttpsError(
        "invalid-argument",
        error instanceof Error ? error.message : "Kampanya taslağı geçersiz.",
      );
    }
    const targets = await loadTargets(draft.scope, draft.selectedProductKeys);
    const preview = previewCampaign(draft, targets);
    const reference = firestore.collection("market_campaigns").doc(draft.campaignId);
    const existing = await reference.get();

    if (existing.exists && existing.data()?.idempotencyKey === draft.idempotencyKey) {
      return {campaignId: draft.campaignId, unchanged: true, preview};
    }

    await reference.set({
      ...storedCampaign(draft, targets, preview),
      status: "draft",
      createdAt: existing.exists ? existing.data()?.createdAt ?? FieldValue.serverTimestamp() : FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: request.auth?.uid,
    }, {merge: true});
    await writeAuditLog({
      action: "market_campaign_saved",
      performedBy: request.auth?.uid ?? "",
      metadata: {campaignId: draft.campaignId, scope: draft.scope, percent: draft.percent},
    });
    return {campaignId: draft.campaignId, status: "draft", preview};
  },
);

/**
 * Publishes a campaign. Play sync is per product and may be partial.
 */
export const adminPublishMarketCampaign = onCall(
  {region: "europe-west1", enforceAppCheck: true},
  async (request) => {
    assertAdminPermission(request, "finance.manage");
    await assertCurrentAdminSession(request);
    return runCampaignSync(String(request.data?.campaignId ?? ""), request.auth.uid, "publish");
  },
);

/**
 * Stops a campaign by deactivating its Play offers.
 */
export const adminStopMarketCampaign = onCall(
  {region: "europe-west1", enforceAppCheck: true},
  async (request) => {
    assertAdminPermission(request, "finance.manage");
    await assertCurrentAdminSession(request);
    return runCampaignSync(String(request.data?.campaignId ?? ""), request.auth.uid, "stop");
  },
);

/**
 * Retries one product that failed during Play sync.
 */
export const adminRetryMarketCampaignProduct = onCall(
  {region: "europe-west1", enforceAppCheck: true},
  async (request) => {
    assertAdminPermission(request, "finance.manage");
    await assertCurrentAdminSession(request);
    return runCampaignSync(
      String(request.data?.campaignId ?? ""),
      request.auth.uid,
      "retry",
      String(request.data?.productKey ?? ""),
    );
  },
);

/**
 * Moves due campaigns. Gift consume is retried by purchase replay.
 */
export const processMarketCampaigns = onSchedule(
  {
    region: "europe-west1",
    schedule: "every 15 minutes",
    timeZone: "Europe/Istanbul",
    retryCount: 2,
  },
  async () => {
    const now = Date.now();
    const snapshot = await firestore.collection("market_campaigns")
      .where("status", "in", ["scheduled", "sync_pending", "active", "partial_error"])
      .limit(20)
      .get();

    for (const document of snapshot.docs) {
      const data = document.data();
      const action = campaignClockAction({
        status: data.status,
        nowMs: now,
        startsAtMs: data.startsAt?.toMillis?.() ?? 0,
        endsAtMs: data.endsAt?.toMillis?.() ?? 0,
      });

      if (action === "wait") {
        continue;
      }

      await runCampaignSync(document.id, "system:scheduler", action === "expire" ? "stop" : "publish");
    }
  },
);

/**
 * Syncs or stops one campaign without treating partial Play errors as success.
 * @param {string} campaignId Campaign id.
 * @param {string} actorUid Actor.
 * @param {"publish"|"stop"|"retry"} mode Action.
 * @param {string=} onlyProductKey Optional product key.
 * @return {Promise<Record<string, unknown>>} Result.
 */
async function runCampaignSync(
  campaignId: string,
  actorUid: string,
  mode: "publish" | "stop" | "retry",
  onlyProductKey = "",
): Promise<Record<string, unknown>> {
  const reference = firestore.collection("market_campaigns").doc(campaignId);
  const snapshot = await reference.get();

  if (!snapshot.exists) {
    throw new HttpsError("not-found", "Kampanya bulunamadı.");
  }

  const data = snapshot.data() ?? {};
  const products = {...(data.products as Record<string, Record<string, unknown>> ?? {})};
  const keys = Object.keys(products).filter((key) => !onlyProductKey || key === onlyProductKey);
  const now = Date.now();
  const startsAtMs = data.startsAt?.toMillis?.() ?? 0;
  const endsAtMs = data.endsAt?.toMillis?.() ?? 0;

  if (mode === "publish") {
    const conflict = findCampaignConflict({
      campaignId,
      startsAtMs,
      endsAtMs,
      productKeys: Object.keys(products),
      existing: await openCampaigns(),
    });

    if (conflict) {
      throw new HttpsError("already-exists", "Aynı üründe çakışan bir kampanya var.");
    }

    if (now < startsAtMs) {
      await reference.set({status: "scheduled", updatedAt: FieldValue.serverTimestamp()}, {merge: true});
      return {campaignId, status: "scheduled"};
    }
  }

  const results: Array<{ok: boolean}> = [];

  for (const key of keys) {
    const line = products[key];

    if (mode === "retry" && line.syncStatus === "synced") {
      results.push({ok: true});
      continue;
    }

    try {
      await pushOffer(line, mode === "stop" ? "deactivate" : "activate", {
        percent: Number(data.percent),
        startsAtMs,
        endsAtMs,
        periods: Number(data.plusDiscountedPeriods ?? 0),
      });
      products[key] = {
        ...line,
        syncStatus: "synced",
        syncError: "",
        updatedAt: new Date().toISOString(),
      };
      results.push({ok: true});
    } catch (error) {
      products[key] = {
        ...line,
        syncStatus: "failed",
        syncError: error instanceof Error ? error.message : "play_sync_failed",
      };
      results.push({ok: false});
    }
  }

  const status: CampaignStatus = mode === "stop" && results.every((result) => result.ok) ?
    "ended" :
    statusAfterSync({nowMs: now, startsAtMs, endsAtMs, results});

  await reference.set({
    products,
    status,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  if (status === "active" || status === "ended") {
    await rememberOffers(products, status === "active");
  }

  await writeAuditLog({
    action: mode === "stop" ? "market_campaign_stopped" : "market_campaign_published",
    performedBy: actorUid,
    metadata: {campaignId, status, failed: results.filter((result) => !result.ok).length},
  });

  return {campaignId, status, failed: results.filter((result) => !result.ok).length};
}

/**
 * Sends one offer to Play or deactivates it.
 * @param {Record<string, unknown>} line Product line.
 * @param {"activate"|"deactivate"} action Action.
 * @param {object} campaign Campaign pricing.
 * @return {Promise<void>} Completion.
 */
async function pushOffer(
  line: Record<string, unknown>,
  action: "activate" | "deactivate",
  campaign: {percent: number; startsAtMs: number; endsAtMs: number; periods: number},
): Promise<void> {
  const playId = String(line.googlePlayProductId ?? "").trim();
  const kind = String(line.kind ?? "");

  if (!playId) {
    throw new Error("Play ürün eşlemesi yok.");
  }

  const regionsVersion = await readRegionsVersion(playId, kind === "plus");
  const offerId = String(line.offerId ?? "");
  const input = {
    packageName: packageName.value(),
    productId: playId,
    purchaseOptionId: String(line.purchaseOptionId ?? ""),
    basePlanId: String(line.basePlanId ?? ""),
    offerId,
    paidFraction: playPaidFraction(campaign.percent),
    discountedPeriods: campaign.periods,
    regionsVersion,
    startsAtIso: new Date(campaign.startsAtMs).toISOString(),
    endsAtIso: new Date(campaign.endsAtMs).toISOString(),
    active: action === "activate",
  };

  if (kind === "plus") {
    if (!input.basePlanId) {
      throw new Error("Plus base plan eşlemesi yok.");
    }
    if (action === "activate") {
      await callAndroidPublisher(
        subscriptionOfferCreatePath(input),
        "POST",
        subscriptionDiscountOfferBody(input),
        [409],
      );
      await callAndroidPublisher(subscriptionOfferStatePath(input, "activate"), "POST", {});
      return;
    }
    await callAndroidPublisher(subscriptionOfferStatePath(input, "deactivate"), "POST", {});
    return;
  }

  if (!input.purchaseOptionId) {
    throw new Error("Tek seferlik ürün satın alma seçeneği eşlenmemiş.");
  }

  await callAndroidPublisher(
    oneTimeOfferBatchPath(input.packageName, input.productId, input.purchaseOptionId),
    "POST",
    oneTimeDiscountBatchBody(input),
  );
}

/**
 * Reads the Play regions version. Missing configuration is an error.
 * @param {string} productId Play product id.
 * @param {boolean} subscription Whether the product is a subscription.
 * @return {Promise<string>} Regions version.
 */
async function readRegionsVersion(productId: string, subscription: boolean): Promise<string> {
  const configured = regionsVersionParam.value().trim();

  if (configured) {
    return configured;
  }

  const path = subscription ?
    `applications/${packageName.value()}/subscriptions/${productId}` :
    `applications/${packageName.value()}/oneTimeProducts/${productId}`;
  const response = await callAndroidPublisher<{regionsVersion?: {version?: string}}>(path, "GET");
  const version = response.regionsVersion?.version?.trim() ?? "";

  if (!version) {
    throw new Error("Play regionsVersion okunamadı. PLAY_REGIONS_VERSION gerekli.");
  }

  return version;
}

/**
 * Keeps accepted offer ids so in-flight purchases still verify after the campaign ends.
 * @param {Record<string, Record<string, unknown>>} products Product lines.
 * @param {boolean} active Whether the offer should be shown as active.
 * @return {Promise<void>} Completion.
 */
async function rememberOffers(
  products: Record<string, Record<string, unknown>>,
  active: boolean,
): Promise<void> {
  for (const line of Object.values(products)) {
    if (line.syncStatus !== "synced") {
      continue;
    }
    const collection = String(line.kind).includes("badge") ? "badge_products" : "plus_products";
    const reference = firestore.collection(collection).doc(String(line.internalProductId));
    const current = await reference.get();
    const accepted = new Set<string>(
      Array.isArray(current.data()?.acceptedGooglePlayOfferIds) ?
        current.data()?.acceptedGooglePlayOfferIds.map((value: unknown) => String(value)) :
        [],
    );
    const offerId = String(line.offerId ?? "");

    if (offerId) {
      accepted.add(offerId);
    }

    const payload: Record<string, unknown> = {
      acceptedGooglePlayOfferIds: [...accepted],
      updatedAt: FieldValue.serverTimestamp(),
    };

    if (String(line.kind) === "plus") {
      payload.activeGooglePlayOfferId = active ? offerId : "";
      payload.activePlusDiscountedPeriods = active ?
        Number(line.plusDiscountedPeriods ?? 0) :
        0;
    }

    await reference.set(payload, {merge: true});
  }
}

/**
 * Loads catalog targets, including gift products, without inventing Play ids.
 * @param {string} scope Campaign scope.
 * @param {string[]} selected Selected keys.
 * @return {Promise<CampaignProductTarget[]>} Targets.
 */
async function loadTargets(scope: string, selected: string[]): Promise<CampaignProductTarget[]> {
  const [badges, plus] = await Promise.all([
    firestore.collection("badge_products").where("active", "==", true).get(),
    firestore.collection("plus_products").where("active", "==", true).get(),
  ]);
  const targets: CampaignProductTarget[] = [];

  for (const document of badges.docs) {
    const data = document.data();
    targets.push(target(`badge:${document.id}`, "badge", document.id, data.googlePlayProductId, data.googlePlayPurchaseOptionId, ""));
    targets.push(target(`badge_gift:${document.id}`, "badge_gift", document.id, data.giftGooglePlayProductId, data.giftGooglePlayPurchaseOptionId, ""));
  }

  for (const document of plus.docs) {
    const data = document.data();
    targets.push(target(`plus:${document.id}`, "plus", document.id, data.googlePlayProductId, "", data.googlePlayBasePlanId));
    targets.push(target(`plus_gift:${document.id}`, "plus_gift", document.id, data.giftGooglePlayProductId, data.giftGooglePlayPurchaseOptionId, ""));
  }

  return targets.filter((item) => {
    if (scope === "all_market") return true;
    if (scope === "badges") return item.kind === "badge" || item.kind === "badge_gift";
    if (scope === "plus") return item.kind === "plus" || item.kind === "plus_gift";
    return selected.includes(item.productKey);
  });
}

/**
 * Builds one target. Empty Play ids stay empty so sync can report them.
 * @param {string} productKey Key.
 * @param {string} kind Kind.
 * @param {string} internalProductId Internal id.
 * @param {unknown} playId Play id.
 * @param {unknown} purchaseOptionId Purchase option.
 * @param {unknown} basePlanId Base plan.
 * @return {CampaignProductTarget} Target.
 */
function target(
  productKey: string,
  kind: CampaignProductTarget["kind"],
  internalProductId: string,
  playId: unknown,
  purchaseOptionId: unknown,
  basePlanId: unknown,
): CampaignProductTarget {
  return {
    productKey,
    kind,
    internalProductId,
    googlePlayProductId: String(playId ?? "").trim(),
    purchaseOptionId: String(purchaseOptionId ?? "").trim(),
    basePlanId: String(basePlanId ?? "").trim(),
  };
}

/**
 * Reads open campaigns for the conflict check.
 * @return {Promise<Array<object>>} Open campaigns.
 */
async function openCampaigns(): Promise<Array<{
  campaignId: string;
  status: CampaignStatus;
  startsAtMs: number;
  endsAtMs: number;
  productKeys: string[];
}>> {
  const snapshot = await firestore.collection("market_campaigns")
    .where("status", "in", ["scheduled", "sync_pending", "active", "partial_error"])
    .get();

  return snapshot.docs.map((document) => ({
    campaignId: document.id,
    status: document.data().status,
    startsAtMs: document.data().startsAt?.toMillis?.() ?? 0,
    endsAtMs: document.data().endsAt?.toMillis?.() ?? 0,
    productKeys: Object.keys(document.data().products ?? {}),
  }));
}

/**
 * Builds the stored campaign body from canonical prices.
 * @param {object} draft Draft.
 * @param {object[]} targets Targets.
 * @param {object[]} preview Preview.
 * @return {Record<string, unknown>} Document.
 */
function storedCampaign(
  draft: ReturnType<typeof readDraft>,
  targets: CampaignProductTarget[],
  preview: ReturnType<typeof previewCampaign>,
): Record<string, unknown> {
  const products: Record<string, unknown> = {};

  for (const item of targets) {
    const line = preview.find((entry) => entry.productKey === item.productKey);
    products[item.productKey] = {
      ...item,
      offerId: campaignOfferId(draft.campaignId, item.productKey),
      plusDiscountedPeriods: item.kind === "plus" ? draft.plusDiscountedPeriods : null,
      normalPriceKurus: line?.normalPriceKurus ?? canonicalListPriceKurus(item.kind),
      discountedPriceKurus: line?.discountedPriceKurus ?? 0,
      syncStatus: "pending",
      syncError: item.googlePlayProductId ? "" : "Play ürün eşlemesi yok.",
    };
  }

  return {
    scope: draft.scope,
    percent: draft.percent,
    startsAt: Timestamp.fromMillis(draft.startsAtMs),
    endsAt: Timestamp.fromMillis(draft.endsAtMs),
    plusDiscountedPeriods: draft.plusDiscountedPeriods,
    idempotencyKey: draft.idempotencyKey,
    products,
    preview,
  };
}

/**
 * Reads a campaign draft from a callable payload.
 * @param {unknown} value Raw payload.
 * @param {string} uid Caller.
 * @return {object} Draft.
 */
function readDraft(value: unknown, uid: string): {
  campaignId: string;
  scope: "all_market" | "badges" | "plus" | "selected";
  percent: number;
  startsAtMs: number;
  endsAtMs: number;
  plusDiscountedPeriods: number | null;
  selectedProductKeys: string[];
  idempotencyKey: string;
} {
  const data = value as Record<string, unknown>;
  const scope = String(data.scope ?? "");

  if (scope !== "all_market" && scope !== "badges" && scope !== "plus" && scope !== "selected") {
    throw new HttpsError("invalid-argument", "Kampanya kapsamı geçersiz.");
  }

  const campaignId = String(data.campaignId ?? "").trim() || firestore.collection("market_campaigns").doc().id;

  return {
    campaignId,
    scope,
    percent: Number(data.percent),
    startsAtMs: Date.parse(String(data.startsAt ?? "")),
    endsAtMs: Date.parse(String(data.endsAt ?? "")),
    plusDiscountedPeriods: data.plusDiscountedPeriods == null ? null : Number(data.plusDiscountedPeriods),
    selectedProductKeys: Array.isArray(data.selectedProductKeys) ? data.selectedProductKeys.map((item) => String(item)) : [],
    idempotencyKey: String(data.idempotencyKey ?? `${uid}:${campaignId}`),
  };
}
