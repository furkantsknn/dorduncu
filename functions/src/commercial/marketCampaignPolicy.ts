import {createHash} from "crypto";

import {
  canonicalListPriceKurus,
  discountedKurus,
  MarketProductKind,
  playPaidFraction,
} from "./marketCatalog";

export const CAMPAIGN_STATUSES = [
  "draft",
  "scheduled",
  "sync_pending",
  "active",
  "partial_error",
  "ended",
] as const;

export type CampaignStatus = typeof CAMPAIGN_STATUSES[number];

export type CampaignScope =
  | "all_market"
  | "badges"
  | "plus"
  | "selected";

export interface CampaignProductTarget {
  productKey: string;
  kind: MarketProductKind;
  internalProductId: string;
  googlePlayProductId: string;
  purchaseOptionId: string;
  basePlanId: string;
}

export interface CampaignDraft {
  campaignId: string;
  scope: CampaignScope;
  percent: number;
  startsAtMs: number;
  endsAtMs: number;
  plusDiscountedPeriods: number | null;
  selectedProductKeys: string[];
}

export interface CampaignPreviewLine {
  productKey: string;
  kind: MarketProductKind;
  normalPriceKurus: number;
  discountedPriceKurus: number;
  playPaidFraction: number;
  plusDiscountedPeriods: number | null;
  renewalPriceKurus: number | null;
  eligibility: string;
}

const OPEN_STATUSES = new Set<CampaignStatus>([
  "scheduled",
  "sync_pending",
  "active",
  "partial_error",
]);

const PLUS_ELIGIBILITY =
  "Yalnızca bu aboneliği hiç satın almamış yeni aboneler. " +
  "Mevcut abonelerin fiyatı değişmez ve kampanyaya taşınmaz. " +
  "İndirimli dönem bitince aylık plan normal fiyatıyla yenilenir.";

const ONE_TIME_ELIGIBILITY =
  "Teklif yalnızca Türkiye mağazasında ve kampanya " +
  "tarihleri arasında geçerlidir. Diğer ülkelerin fiyatı değişmez.";

/**
 * Builds a stable Play offer id for one campaign product.
 * @param {string} campaignId Campaign id.
 * @param {string} productKey Product key.
 * @return {string} Offer id.
 */
export function campaignOfferId(
  campaignId: string,
  productKey: string,
): string {
  const digest = createHash("sha256")
    .update(`${campaignId}:${productKey}`, "utf8")
    .digest("hex")
    .slice(0, 20);

  return `c${digest}`;
}

/**
 * Validates a campaign draft before it is stored.
 * @param {CampaignDraft} draft Draft.
 * @return {void}
 */
export function assertCampaignDraft(draft: CampaignDraft): void {
  if (draft.scope === "selected" &&
    draft.selectedProductKeys.length === 0) {
    throw new Error("selected_products_required");
  }

  if (!Number.isInteger(draft.percent) ||
    draft.percent < 1 ||
    draft.percent > 99) {
    throw new Error("percent_invalid");
  }

  if (!(draft.endsAtMs > draft.startsAtMs)) {
    throw new Error("window_invalid");
  }

  const includesPlus = draftIncludesPlus(draft);

  if (includesPlus) {
    const periods = draft.plusDiscountedPeriods;

    if (periods == null ||
      !Number.isInteger(periods) ||
      periods < 1 ||
      periods > 12) {
      throw new Error("plus_periods_required");
    }
  }
}

/**
 * Returns whether the draft discounts the personal Plus subscription.
 * @param {CampaignDraft} draft Draft.
 * @return {boolean} True when Plus is in scope.
 */
export function draftIncludesPlus(draft: CampaignDraft): boolean {
  if (draft.scope === "all_market" || draft.scope === "plus") {
    return true;
  }

  return draft.selectedProductKeys.some(
    (key) => key.startsWith("plus:"),
  );
}

/**
 * Builds the preview from canonical list prices.
 * @param {CampaignDraft} draft Draft.
 * @param {CampaignProductTarget[]} targets Resolved products.
 * @return {CampaignPreviewLine[]} Preview lines.
 */
export function previewCampaign(
  draft: CampaignDraft,
  targets: CampaignProductTarget[],
): CampaignPreviewLine[] {
  assertCampaignDraft(draft);

  return targets.map((target) => {
    const normalPriceKurus = canonicalListPriceKurus(target.kind);
    const discountedPriceKurus = discountedKurus(
      normalPriceKurus,
      draft.percent,
    );
    const plus = target.kind === "plus";

    return {
      productKey: target.productKey,
      kind: target.kind,
      normalPriceKurus,
      discountedPriceKurus,
      playPaidFraction: playPaidFraction(draft.percent),
      plusDiscountedPeriods: plus ?
        draft.plusDiscountedPeriods :
        null,
      renewalPriceKurus: plus ? normalPriceKurus : null,
      eligibility: plus ? PLUS_ELIGIBILITY : ONE_TIME_ELIGIBILITY,
    };
  });
}

/**
 * Finds an overlapping open campaign that shares a product.
 * @param {object} input Comparison input.
 * @return {string|null} Conflicting campaign id.
 */
export function findCampaignConflict(input: {
  campaignId: string;
  startsAtMs: number;
  endsAtMs: number;
  productKeys: string[];
  existing: Array<{
    campaignId: string;
    status: CampaignStatus;
    startsAtMs: number;
    endsAtMs: number;
    productKeys: string[];
  }>;
}): string | null {
  const keys = new Set(input.productKeys);

  for (const campaign of input.existing) {
    if (campaign.campaignId === input.campaignId) {
      continue;
    }

    if (!OPEN_STATUSES.has(campaign.status)) {
      continue;
    }

    const overlaps =
      input.startsAtMs < campaign.endsAtMs &&
      campaign.startsAtMs < input.endsAtMs;
    const sharesProduct = campaign.productKeys.some(
      (key) => keys.has(key),
    );

    if (overlaps && sharesProduct) {
      return campaign.campaignId;
    }
  }

  return null;
}

/**
 * Resolves the status after a per-product sync attempt.
 * @param {object} input Sync outcome.
 * @return {CampaignStatus} Next status.
 */
export function statusAfterSync(input: {
  nowMs: number;
  startsAtMs: number;
  endsAtMs: number;
  results: Array<{ok: boolean}>;
}): CampaignStatus {
  if (input.nowMs >= input.endsAtMs) {
    return "ended";
  }

  if (input.results.length === 0) {
    return input.nowMs < input.startsAtMs ?
      "scheduled" :
      "sync_pending";
  }

  const failed = input.results.some((result) => !result.ok);

  if (failed) {
    return "partial_error";
  }

  if (input.nowMs < input.startsAtMs) {
    return "scheduled";
  }

  return "active";
}

/**
 * Selects the Play sync action for one campaign.
 * @param {object} input Timing input.
 * @return {"wait"|"sync"|"expire"} Action.
 */
export function campaignClockAction(input: {
  status: CampaignStatus;
  nowMs: number;
  startsAtMs: number;
  endsAtMs: number;
}): "wait" | "sync" | "expire" {
  if (input.status === "ended" || input.status === "draft") {
    return "wait";
  }

  if (input.nowMs >= input.endsAtMs) {
    return "expire";
  }

  if (input.status === "scheduled" &&
    input.nowMs < input.startsAtMs) {
    return "wait";
  }

  if (
    input.status === "scheduled" ||
    input.status === "sync_pending" ||
    input.status === "partial_error"
  ) {
    return "sync";
  }

  return "wait";
}
