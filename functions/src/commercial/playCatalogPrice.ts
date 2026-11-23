export interface NormalizedPlayMoney {
  currencyCode: string;
  units: string;
  nanos: number;
  amount: string;
}

/**
 * Validates and normalizes a Google Money value without treating missing
 * units as zero. Integer units may arrive as either a JSON string or number.
 * Protobuf JSON omits the scalar `nanos` field when its value is zero, so an
 * absent nanos field is normalized to zero only after currency and units pass.
 * @param {unknown} value Raw Google Money value.
 * @return {NormalizedPlayMoney|null} Normalized money, or null when invalid.
 */
export function normalizePlayMoney(
  value: unknown,
): NormalizedPlayMoney | null {
  if (value == null || typeof value !== "object") return null;
  const money = value as Record<string, unknown>;
  const currencyCode = typeof money.currencyCode === "string" ?
    money.currencyCode.trim() : "";
  if (!/^[A-Z]{3}$/.test(currencyCode)) return null;

  const rawUnits = money.units;
  let units: string;
  if (typeof rawUnits === "string" && /^-?(0|[1-9]\d*)$/.test(rawUnits)) {
    units = BigInt(rawUnits).toString();
  } else if (
    typeof rawUnits === "number" &&
    Number.isSafeInteger(rawUnits)
  ) {
    units = String(rawUnits);
  } else {
    return null;
  }

  const rawNanos = money.nanos;
  const nanos = rawNanos === undefined ? 0 :
    typeof rawNanos === "number" ? rawNanos :
      typeof rawNanos === "string" && /^\d+$/.test(rawNanos) ?
        Number(rawNanos) : Number.NaN;
  if (
    !Number.isSafeInteger(nanos) ||
    nanos < 0 ||
    nanos > 999999999
  ) {
    return null;
  }

  const fraction = String(nanos).padStart(9, "0").replace(/0+$/, "");
  return {
    currencyCode,
    units,
    nanos,
    amount: fraction ? `${units}.${fraction} ${currencyCode}` :
      `${units}.00 ${currencyCode}`,
  };
}

/**
 * Returns true only for an exact, valid 499.00 TRY value.
 * @param {unknown} value Raw Google Money value.
 * @return {boolean} Whether the value is the target price.
 */
export function isTargetBadgePrice(value: unknown): boolean {
  const money = normalizePlayMoney(value);
  return money?.currencyCode === "TRY" &&
    money.units === "499" && money.nanos === 0;
}

/**
 * Converts Play Money directly to two-decimal kuruş without inventing tax.
 * @param {unknown} value Raw Google Money value.
 * @return {number|null} Tax-inclusive amount in kuruş, or null when invalid.
 */
export function playMoneyKurus(value: unknown): number | null {
  const money = normalizePlayMoney(value);
  if (money == null || money.currencyCode !== "TRY") return null;
  const units = BigInt(money.units);
  const nanos = BigInt(money.nanos);
  const totalNanos = units * BigInt("1000000000") + nanos;
  return Number(
    (totalNanos + BigInt("5000000")) / BigInt("10000000"),
  );
}

export interface BadgeRecordedPrice {
  amountKurus: number;
  listPriceKurus: number;
  amountSource: "catalog_nominal" | "catalog_plus_offer_nominal";
}

/**
 * Selects the catalog amount used for bookkeeping. It is deliberately not
 * described as the amount charged by Play because verification has no paid
 * amount field that can be trusted here.
 * @param {object} input Catalog prices and verified offer selection.
 * @return {BadgeRecordedPrice} Consistent bookkeeping projection.
 */
export function badgeRecordedPrice(input: {
  usedPlusOffer: boolean;
  listPriceKurus: number;
  plusPriceKurus: unknown;
}): BadgeRecordedPrice {
  const listPriceKurus = validPositiveKurus(
    input.listPriceKurus,
    "listPriceKurus",
  );
  if (!input.usedPlusOffer) {
    return {
      amountKurus: listPriceKurus,
      listPriceKurus,
      amountSource: "catalog_nominal",
    };
  }
  return {
    amountKurus: validPositiveKurus(
      input.plusPriceKurus,
      "plusPriceKurus",
    ),
    listPriceKurus,
    amountSource: "catalog_plus_offer_nominal",
  };
}

/**
 * Validates one positive minor-unit catalog amount.
 * @param {unknown} value Candidate value.
 * @param {string} field Diagnostic field name.
 * @return {number} Validated integer amount.
 */
function validPositiveKurus(value: unknown, field: string): number {
  if (!Number.isSafeInteger(value) || Number(value) < 1) {
    throw new Error(`${field} must be a positive safe integer.`);
  }
  return Number(value);
}
