/**
 * Android Publisher request bodies for campaign offers.
 * Shapes follow the documented v3 monetization resources.
 */

export interface OneTimeOfferInput {
  packageName: string;
  productId: string;
  purchaseOptionId: string;
  offerId: string;
  paidFraction: number;
  startsAtIso: string;
  endsAtIso: string;
  regionsVersion: string;
  active: boolean;
}

export interface SubscriptionOfferInput {
  packageName: string;
  productId: string;
  basePlanId: string;
  offerId: string;
  paidFraction: number;
  discountedPeriods: number;
  regionsVersion: string;
}

/**
 * Builds a one-time discount offer batchUpdate body.
 * Only Türkiye is listed, so other regions keep their base price.
 * @param {OneTimeOfferInput} input Offer input.
 * @return {Record<string, unknown>} Request body.
 */
export function oneTimeDiscountBatchBody(
  input: OneTimeOfferInput,
): Record<string, unknown> {
  return {
    requests: [
      {
        oneTimeProductOffer: {
          packageName: input.packageName,
          productId: input.productId,
          purchaseOptionId: input.purchaseOptionId,
          offerId: input.offerId,
          state: input.active ? "ACTIVE" : "INACTIVE",
          discountedOffer: {
            startTime: input.startsAtIso,
            endTime: input.endsAtIso,
          },
          regionalPricingAndAvailabilityConfigs: [
            {
              regionCode: "TR",
              availability: "AVAILABLE",
              relativeDiscount: input.paidFraction,
            },
          ],
        },
        allowMissing: true,
        regionsVersion: {version: input.regionsVersion},
      },
    ],
  };
}

/**
 * Builds a subscription offer that discounts N monthly periods.
 * After those periods Play renews the unchanged monthly base plan.
 * Existing subscribers are not targeted.
 * @param {SubscriptionOfferInput} input Offer input.
 * @return {Record<string, unknown>} SubscriptionOffer body.
 */
export function subscriptionDiscountOfferBody(
  input: SubscriptionOfferInput,
): Record<string, unknown> {
  return {
    packageName: input.packageName,
    productId: input.productId,
    basePlanId: input.basePlanId,
    offerId: input.offerId,
    phases: [
      {
        recurrenceCount: input.discountedPeriods,
        duration: "P1M",
        regionalConfigs: [
          {
            regionCode: "TR",
            relativeDiscount: input.paidFraction,
          },
        ],
      },
    ],
    regionalConfigs: [
      {
        regionCode: "TR",
        newSubscriberAvailability: true,
      },
    ],
    targeting: {
      acquisitionRule: {
        scope: {
          thisSubscription: {},
        },
      },
    },
  };
}

/**
 * One-time offer batchUpdate path.
 * @param {string} packageName Package name.
 * @param {string} productId Play product id.
 * @param {string} purchaseOptionId Buy option id.
 * @return {string} Relative API path.
 */
export function oneTimeOfferBatchPath(
  packageName: string,
  productId: string,
  purchaseOptionId: string,
): string {
  return "applications/" +
    `${encodeURIComponent(packageName)}/oneTimeProducts/` +
    `${encodeURIComponent(productId)}/purchaseOptions/` +
    `${encodeURIComponent(purchaseOptionId)}/offers:batchUpdate`;
}

/**
 * Subscription offer create path, including required query params.
 * @param {SubscriptionOfferInput} input Offer input.
 * @return {string} Relative API path.
 */
export function subscriptionOfferCreatePath(
  input: SubscriptionOfferInput,
): string {
  const version = encodeURIComponent(input.regionsVersion);

  return "applications/" +
    `${encodeURIComponent(input.packageName)}/subscriptions/` +
    `${encodeURIComponent(input.productId)}/basePlans/` +
    `${encodeURIComponent(input.basePlanId)}/offers` +
    `?offerId=${encodeURIComponent(input.offerId)}` +
    `&regionsVersion.version=${version}`;
}

/**
 * Subscription offer activate or deactivate path.
 * @param {SubscriptionOfferInput} input Offer identity.
 * @param {"activate"|"deactivate"} action Offer action.
 * @return {string} Relative API path.
 */
export function subscriptionOfferStatePath(
  input: Pick<
    SubscriptionOfferInput,
    "packageName" | "productId" | "basePlanId" | "offerId"
  >,
  action: "activate" | "deactivate",
): string {
  return "applications/" +
    `${encodeURIComponent(input.packageName)}/subscriptions/` +
    `${encodeURIComponent(input.productId)}/basePlans/` +
    `${encodeURIComponent(input.basePlanId)}/offers/` +
    `${encodeURIComponent(input.offerId)}:${action}`;
}
