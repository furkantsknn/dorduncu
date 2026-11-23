/* eslint-disable max-len, require-jsdoc */
import {eventCategories} from "../events/eventCatalog";
import {callAndroidPublisher} from "./googlePlayVerification";

/** Fixed canonical IDs only. No caller URL, product, region, or option is accepted. */
export async function readCanonicalGiftCatalog(): Promise<unknown[]> {
  const rows: unknown[] = [];
  const ids = eventCategories.flatMap((category) => category.games.map((game) => `dort_gift_badge_${game.id}`));
  for (let offset = 0; offset < ids.length; offset += 5) {
    rows.push(...await Promise.all(ids.slice(offset, offset + 5).map(async (product) => {
      try {
        const data = await callAndroidPublisher<{purchaseOptions?: Array<{purchaseOptionId?: string; state?: string; regionalPricingAndAvailabilityConfigs?: Array<{regionCode?: string; availability?: string; price?: {currencyCode?: string; units?: string; nanos?: number}}>}>}>(`applications/com.dortapp.dort/oneTimeProducts/${product}`, "GET");
        const option = data.purchaseOptions?.find((item) => item.purchaseOptionId === "buy");
        const region = option?.regionalPricingAndAvailabilityConfigs?.find((item) => item.regionCode === "TR");
        const price = region?.price;
        const validMoney = price && /^[A-Z]{3}$/.test(String(price.currencyCode ?? "")) && /^\d+$/.test(String(price.units ?? "0")) && Number.isInteger(price.nanos ?? 0) && Number(price.nanos ?? 0) >= 0 && Number(price.nanos ?? 0) < 1000000000;
        return {product, option: option?.purchaseOptionId ?? null, region: "TR", active: option?.state === "ACTIVE" && region?.availability === "AVAILABLE", money: validMoney ? {currencyCode: price.currencyCode, units: String(price.units ?? "0"), nanos: price.nanos ?? 0} : null};
      } catch {
        // Do not expose upstream errors/tokens; failure is unknown, never absence.
        return {product, option: "buy", region: "TR", active: null, money: null};
      }
    })));
  }
  return rows;
}
