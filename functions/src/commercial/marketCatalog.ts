/**
 * Canonical Turkey list prices. Campaigns discount these amounts.
 * A previous campaign price is never used as the next base.
 */
export const BADGE_LIST_PRICE_KURUS = 49900;
export const PLUS_LIST_PRICE_KURUS = 79900;
export const PLUS_GIFT_DAYS = 30;
export const PLANNED_PLUS_PRODUCT_ID = "dort_plus";
export const PLANNED_PLUS_BASE_PLAN_ID = "monthly";

export type MarketProductKind =
  | "badge"
  | "badge_gift"
  | "plus"
  | "plus_gift";

/**
 * Returns the stored Turkey list price for one product kind.
 * @param {MarketProductKind} kind Product kind.
 * @return {number} Price in kuruş.
 */
export function canonicalListPriceKurus(
  kind: MarketProductKind,
): number {
  if (kind === "plus" || kind === "plus_gift") {
    return PLUS_LIST_PRICE_KURUS;
  }

  return BADGE_LIST_PRICE_KURUS;
}

/**
 * Calculates a percent discount from the canonical price.
 * @param {number} normalKurus Stored normal price in kuruş.
 * @param {number} percent Discount percent from 1 to 99.
 * @return {number} Discounted price in kuruş.
 */
export function discountedKurus(
  normalKurus: number,
  percent: number,
): number {
  if (!Number.isInteger(normalKurus) || normalKurus <= 0) {
    throw new Error("normal_price_invalid");
  }

  if (!Number.isInteger(percent) || percent < 1 || percent > 99) {
    throw new Error("percent_invalid");
  }

  return Math.round(normalKurus * (100 - percent) / 100);
}

/**
 * Fraction of the Play base price the user pays.
 * Play relativeDiscount is the paid fraction, not the discount.
 * @param {number} percent Discount percent from 1 to 99.
 * @return {number} Paid fraction strictly between 0 and 1.
 */
export function playPaidFraction(percent: number): number {
  if (!Number.isInteger(percent) || percent < 1 || percent > 99) {
    throw new Error("percent_invalid");
  }

  return Number(((100 - percent) / 100).toFixed(2));
}
