import {createHash} from "crypto";

import {GoogleAuth} from "google-auth-library";
import {defineString} from "firebase-functions/params";
import {HttpsError} from "firebase-functions/v2/https";

import {
  normalizePlayMoney,
  playMoneyKurus,
} from "./playCatalogPrice";

const androidPackageName = defineString(
  "ANDROID_PACKAGE_NAME",
  {
    default: "com.dortapp.dort",
  },
);

const ANDROID_PUBLISHER_BASE =
  "https://androidpublisher.googleapis.com/androidpublisher/v3";
const PLAY_PUBLISHER_SCOPE =
  "https://www.googleapis.com/auth/androidpublisher";

const playAuth = new GoogleAuth({
  scopes: [PLAY_PUBLISHER_SCOPE],
});

export interface VerifiedGooglePlayProduct {
  kind: "product";
  googlePlayProductId: string;
  orderId: string | null;
  acknowledged: boolean;
  consumed: boolean;
  obfuscatedExternalAccountId: string | null;
  purchaseTokenHash: string;
  testPurchase: boolean;
  purchaseState: number;
  offerId: string;
  purchaseOptionId: string;
  offerToken: string;
  purchaseTime: Date | null;
}

export interface VerifiedGooglePlaySubscription {
  kind: "subscription";
  googlePlayProductId: string;
  orderId: string | null;
  acknowledged: boolean;
  purchaseTokenHash: string;
  expiryTime: Date;
  subscriptionState: string;
  testPurchase: boolean;
  offerId: string;
  basePlanId: string;
  obfuscatedExternalAccountId: string | null;
}

export interface GooglePlaySubscriptionStatus {
  googlePlayProductId: string;
  orderId: string | null;
  acknowledged: boolean;
  purchaseTokenHash: string;
  expiryTime: Date | null;
  subscriptionState: string;
  testPurchase: boolean;
  hasEntitlement: boolean;
  offerId: string;
  basePlanId: string;
  obfuscatedExternalAccountId: string | null;
}

interface ProductPurchaseV2Response {
  purchaseCompletionTime?: string;
  purchaseStateContext?: {purchaseState?: string};
  acknowledgementState?: string;
  orderId?: string;
  obfuscatedExternalAccountId?: string;
  testPurchaseContext?: Record<string, unknown>;
  productLineItem?: Array<{
    productId?: string;
    productOfferDetails?: {
      offerId?: string;
      purchaseOptionId?: string;
      offerToken?: string;
      quantity?: number;
      consumptionState?: string;
    };
  }>;
}

interface ProductPurchaseResponse {
  purchaseState?: number;
  acknowledgementState?: number;
  consumptionState?: number;
  orderId?: string;
  purchaseType?: number;
  obfuscatedExternalAccountId?: string;
  purchaseTimeMillis?: string;
}

interface SubscriptionLineItem {
  productId?: string;
  expiryTime?: string;
  latestSuccessfulOrderId?: string;
  offerDetails?: {
    basePlanId?: string;
    offerId?: string;
  };
}

interface SubscriptionPurchaseV2Response {
  subscriptionState?: string;
  acknowledgementState?: string;
  lineItems?: SubscriptionLineItem[];
  testPurchase?: Record<string, unknown>;
  externalAccountIdentifiers?: {
    obfuscatedExternalAccountId?: string;
  };
}

/**
 * Verifies one Google Play non-consumable product purchase.
 *
 * @param {string} googlePlayProductId Expected Play product id.
 * @param {string} purchaseToken Raw token supplied by Google Play Billing.
 * @return {Promise<VerifiedGooglePlayProduct>} Verified purchase.
 */
export async function verifyGooglePlayProduct(
  googlePlayProductId: string,
  purchaseToken: string,
): Promise<VerifiedGooglePlayProduct> {
  const productId = requireString(
    googlePlayProductId,
    "googlePlayProductId",
    300,
  );
  const token = requireString(
    purchaseToken,
    "purchaseToken",
    5000,
  );
  const packageName = requirePackageName();

  const url = `${ANDROID_PUBLISHER_BASE}/applications/` +
    `${encodeURIComponent(packageName)}/purchases/productsv2/tokens/` +
    `${encodeURIComponent(token)}`;

  const data = await googlePlayRequest<ProductPurchaseV2Response>(
    url,
    "GET",
  );

  if (data.purchaseStateContext?.purchaseState !== "PURCHASED") {
    throw new HttpsError(
      "failed-precondition",
      "Google Play satın alma işlemi tamamlanmış değil.",
    );
  }

  const matchingItems = (data.productLineItem ?? []).filter(
    (item) => String(item.productId ?? "").trim() === productId,
  );
  if (matchingItems.length !== 1) {
    throw new HttpsError(
      "failed-precondition",
      "Google Play ürün satırı eşleşmedi.",
    );
  }
  const details = matchingItems[0].productOfferDetails ?? {};
  if ((details.quantity ?? 1) !== 1) {
    throw new HttpsError(
      "failed-precondition",
      "Google Play ürün miktarı geçersiz.",
    );
  }

  return {
    kind: "product",
    googlePlayProductId: productId,
    orderId: normalizeOptionalString(data.orderId),
    acknowledged:
      data.acknowledgementState === "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
    consumed: details.consumptionState === "CONSUMPTION_STATE_CONSUMED",
    obfuscatedExternalAccountId: normalizeOptionalString(
      data.obfuscatedExternalAccountId,
    ),
    purchaseTokenHash: hashPurchaseToken(token),
    testPurchase: data.testPurchaseContext != null,
    purchaseState: 0,
    offerId: String(details.offerId ?? "").trim(),
    purchaseOptionId: String(details.purchaseOptionId ?? "").trim(),
    offerToken: String(details.offerToken ?? "").trim(),
    purchaseTime: optionalDate(data.purchaseCompletionTime),
  };
}

/**
 * Reads the latest Google Play subscription lifecycle state.
 *
 * This function does not assume that every non-ACTIVE state has lost
 * entitlement. Google Play cancellations can remain entitled until expiry.
 *
 * @param {string} googlePlayProductId Expected subscription product id.
 * @param {string} purchaseToken Raw token supplied by Google Play Billing.
 * @param {string=} expectedBasePlanId Standard base plan required for a
 * new purchase. Lifecycle reads omit this and do not reject other plans.
 * @param {ReadonlySet<string>=} acceptedOfferIds Catalog campaign offers.
 * @return {Promise<GooglePlaySubscriptionStatus>} Latest provider state.
 */
export async function getGooglePlaySubscriptionStatus(
  googlePlayProductId: string,
  purchaseToken: string,
  expectedBasePlanId?: string,
  acceptedOfferIds?: ReadonlySet<string>,
): Promise<GooglePlaySubscriptionStatus> {
  const productId = requireString(
    googlePlayProductId,
    "googlePlayProductId",
    300,
  );
  const token = requireString(
    purchaseToken,
    "purchaseToken",
    5000,
  );
  const packageName = requirePackageName();

  const url =
    `${ANDROID_PUBLISHER_BASE}/applications/` +
    `${encodeURIComponent(packageName)}/purchases/` +
    `subscriptionsv2/tokens/${encodeURIComponent(token)}`;

  const data =
    await googlePlayRequest<SubscriptionPurchaseV2Response>(
      url,
      "GET",
    );

  const state = String(
    data.subscriptionState ?? "",
  ).trim();

  const matchingLineItems = (data.lineItems ?? [])
    .filter(
      (item) =>
        String(item.productId ?? "").trim() === productId,
    );

  if (matchingLineItems.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      "Google Play abonelik ürünü eşleşmedi.",
    );
  }

  let latestItem: SubscriptionLineItem | null = null;
  let latestExpiry: Date | null = null;
  let orderId: string | null = null;

  for (const item of matchingLineItems) {
    const expiry = parseGoogleDate(item.expiryTime);

    if (
      expiry != null &&
      (
        latestExpiry == null ||
        expiry.getTime() > latestExpiry.getTime()
      )
    ) {
      latestItem = item;
      latestExpiry = expiry;
      orderId = normalizeOptionalString(
        item.latestSuccessfulOrderId,
      );
    }
  }

  const offerCheck = expectedBasePlanId == null ?
    {offerId: "", basePlanId: ""} :
    assertSubscriptionOffer(
      latestItem,
      expectedBasePlanId,
      acceptedOfferIds,
    );

  const futureExpiry =
    latestExpiry != null &&
    latestExpiry.getTime() > Date.now();

  const entitlementStates = new Set<string>([
    "SUBSCRIPTION_STATE_ACTIVE",
    "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
    "SUBSCRIPTION_STATE_CANCELED",
  ]);

  return {
    googlePlayProductId: productId,
    orderId,
    acknowledged:
      data.acknowledgementState ===
      "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
    purchaseTokenHash: hashPurchaseToken(token),
    expiryTime: latestExpiry,
    subscriptionState: state,
    testPurchase: data.testPurchase != null,
    hasEntitlement:
      futureExpiry &&
      entitlementStates.has(state),
    offerId: offerCheck.offerId,
    basePlanId: offerCheck.basePlanId,
    obfuscatedExternalAccountId: normalizeOptionalString(
      data.externalAccountIdentifiers?.obfuscatedExternalAccountId,
    ),
  };
}

/**
 * Verifies one Google Play subscription purchase for entitlement.
 *
 * @param {string} googlePlayProductId Expected subscription product id.
 * @param {string} purchaseToken Raw token supplied by Google Play Billing.
 * @param {string} expectedBasePlanId Catalog standard base plan id.
 * @param {ReadonlySet<string>=} acceptedOfferIds Catalog campaign offers.
 * @return {Promise<VerifiedGooglePlaySubscription>} Verified subscription.
 */
export async function verifyGooglePlaySubscription(
  googlePlayProductId: string,
  purchaseToken: string,
  expectedBasePlanId: string,
  acceptedOfferIds?: ReadonlySet<string>,
): Promise<VerifiedGooglePlaySubscription> {
  const status = await getGooglePlaySubscriptionStatus(
    googlePlayProductId,
    purchaseToken,
    expectedBasePlanId,
    acceptedOfferIds,
  );

  if (
    !status.hasEntitlement ||
    status.expiryTime == null
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Google Play Plus aboneliği aktif değil.",
    );
  }

  return {
    kind: "subscription",
    googlePlayProductId:
      status.googlePlayProductId,
    orderId: status.orderId,
    acknowledged: status.acknowledged,
    purchaseTokenHash:
      status.purchaseTokenHash,
    expiryTime: status.expiryTime,
    subscriptionState:
      status.subscriptionState,
    testPurchase: status.testPurchase,
    offerId: status.offerId,
    basePlanId: status.basePlanId,
    obfuscatedExternalAccountId:
      status.obfuscatedExternalAccountId,
  };
}

/**
 * Requires the entitled line item to be the configured standard base plan.
 *
 * A promotional offer id is rejected. Another base plan is not accepted.
 * @param {SubscriptionLineItem|null} item Latest entitled line item.
 * @param {string} expectedBasePlanId Catalog base plan id.
 * @param {ReadonlySet<string>=} acceptedOfferIds Catalog campaign offers.
 * @return {object} Checked offer.
 */
function assertSubscriptionOffer(
  item: SubscriptionLineItem | null,
  expectedBasePlanId: string,
  acceptedOfferIds?: ReadonlySet<string>,
): {offerId: string; basePlanId: string} {
  const expected = expectedBasePlanId.trim();
  const basePlanId = String(
    item?.offerDetails?.basePlanId ?? "",
  ).trim();
  const offerId = String(
    item?.offerDetails?.offerId ?? "",
  ).trim();
  const knownOffer = offerId !== "" &&
    acceptedOfferIds?.has(offerId) === true;

  if (!expected || basePlanId !== expected ||
    (offerId !== "" && !knownOffer)) {
    throw new HttpsError(
      "failed-precondition",
      "Google Play aboneliği katalogdaki teklifle eşleşmiyor.",
    );
  }

  return {offerId, basePlanId};
}

/**
 * Acknowledges a verified non-consumable Google Play product purchase.
 *
 * @param {string} googlePlayProductId Play product id.
 * @param {string} purchaseToken Raw Play token.
 * @return {Promise<void>} Completion promise.
 */
export async function acknowledgeGooglePlayProduct(
  googlePlayProductId: string,
  purchaseToken: string,
): Promise<void> {
  const productId = requireString(
    googlePlayProductId,
    "googlePlayProductId",
    300,
  );
  const token = requireString(
    purchaseToken,
    "purchaseToken",
    5000,
  );
  const packageName = requirePackageName();

  const url =
    `${ANDROID_PUBLISHER_BASE}/applications/` +
    `${encodeURIComponent(packageName)}/purchases/products/` +
    `${encodeURIComponent(productId)}/tokens/` +
    `${encodeURIComponent(token)}:acknowledge`;

  await googlePlayRequest<Record<string, never>>(
    url,
    "POST",
    {},
  );
}

/**
 * Reads a one-time purchase without treating pending as success.
 *
 * @param {string} googlePlayProductId Play product id.
 * @param {string} purchaseToken Raw Play token.
 * @return {Promise<VerifiedGooglePlayProduct>} Purchase snapshot.
 */
export async function inspectGooglePlayProduct(
  googlePlayProductId: string,
  purchaseToken: string,
): Promise<VerifiedGooglePlayProduct> {
  const productId = requireString(
    googlePlayProductId,
    "googlePlayProductId",
    300,
  );
  const token = requireString(purchaseToken, "purchaseToken", 5000);
  const packageName = requirePackageName();
  const url =
    `${ANDROID_PUBLISHER_BASE}/applications/` +
    `${encodeURIComponent(packageName)}/purchases/products/` +
    `${encodeURIComponent(productId)}/tokens/` +
    `${encodeURIComponent(token)}`;
  const data = await googlePlayRequest<ProductPurchaseResponse>(url, "GET");

  return {
    kind: "product",
    googlePlayProductId: productId,
    orderId: normalizeOptionalString(data.orderId),
    acknowledged: data.acknowledgementState === 1,
    consumed: data.consumptionState === 1,
    obfuscatedExternalAccountId: normalizeOptionalString(
      data.obfuscatedExternalAccountId,
    ),
    purchaseTokenHash: hashPurchaseToken(token),
    testPurchase: data.purchaseType === 0,
    purchaseState: data.purchaseState ?? -1,
    offerId: "",
    purchaseOptionId: "",
    offerToken: "",
    purchaseTime: epochDate(data.purchaseTimeMillis),
  };
}

/**
 * Parses an optional RFC3339 timestamp returned by Play.
 * @param {unknown} value Raw timestamp.
 * @return {Date|null} Parsed timestamp.
 */
function optionalDate(value: unknown): Date | null {
  const parsed = new Date(String(value ?? ""));
  return Number.isFinite(parsed.getTime()) ? parsed : null;
}

/**
 * Parses an optional epoch-millisecond timestamp returned by Play.
 * @param {unknown} value Raw timestamp.
 * @return {Date|null} Parsed timestamp.
 */
function epochDate(value: unknown): Date | null {
  const millis = Number(value);
  return Number.isFinite(millis) && millis > 0 ? new Date(millis) : null;
}

/**
 * Consumes a fulfilled one-time gift purchase.
 *
 * @param {string} googlePlayProductId Play product id.
 * @param {string} purchaseToken Raw Play token.
 * @return {Promise<void>} Completion promise.
 */
export async function consumeGooglePlayProduct(
  googlePlayProductId: string,
  purchaseToken: string,
): Promise<void> {
  const productId = requireString(
    googlePlayProductId,
    "googlePlayProductId",
    300,
  );
  const token = requireString(purchaseToken, "purchaseToken", 5000);
  const packageName = requirePackageName();
  const url =
    `${ANDROID_PUBLISHER_BASE}/applications/` +
    `${encodeURIComponent(packageName)}/purchases/products/` +
    `${encodeURIComponent(productId)}/tokens/` +
    `${encodeURIComponent(token)}:consume`;

  await googlePlayRequest<Record<string, never>>(url, "POST", {});
}

/**
 * Calls an Android Publisher monetization endpoint with the
 * Functions service account. No client secret is used.
 *
 * @param {string} path Path under the v3 API.
 * @param {"GET"|"POST"|"PATCH"} method HTTP method.
 * @param {Record<string, unknown>=} body JSON body.
 * @param {number[]} acceptedStatuses Statuses that are not failures.
 * @return {Promise<T>} Parsed response.
 */
export async function callAndroidPublisher<T>(
  path: string,
  method: "GET" | "POST" | "PATCH",
  body?: Record<string, unknown>,
  acceptedStatuses: readonly number[] = [],
): Promise<T> {
  const url = path.startsWith("https://") ?
    path :
    `${ANDROID_PUBLISHER_BASE}/${path.replace(/^\/+/, "")}`;

  return googlePlayRequest<T>(url, method, body, acceptedStatuses);
}

/**
 * Acknowledges a verified Google Play subscription.
 *
 * @param {string} googlePlayProductId Subscription product id.
 * @param {string} purchaseToken Raw Play token.
 * @return {Promise<void>} Completion promise.
 */
export async function acknowledgeGooglePlaySubscription(
  googlePlayProductId: string,
  purchaseToken: string,
): Promise<void> {
  const productId = requireString(
    googlePlayProductId,
    "googlePlayProductId",
    300,
  );
  const token = requireString(
    purchaseToken,
    "purchaseToken",
    5000,
  );
  const packageName = requirePackageName();

  const url =
    `${ANDROID_PUBLISHER_BASE}/applications/` +
    `${encodeURIComponent(packageName)}/purchases/subscriptions/` +
    `${encodeURIComponent(productId)}/tokens/` +
    `${encodeURIComponent(token)}:acknowledge`;

  await googlePlayRequest<Record<string, never>>(
    url,
    "POST",
    {},
  );
}

export interface PlayAccessProbe {
  label: string;
  manualStatus: number;
  manualReason: string;
  libraryStatus: number;
  libraryReason: string;
  summary: string;
}

export interface PlayAccessDiagnosis {
  packageName: string;
  credentialType: string;
  serviceAccountEmail: string;
  tokenEmail: string;
  tokenHasPlayScope: boolean;
  probes: PlayAccessProbe[];
}

export interface BadgePriceDiagnosis {
  product: string;
  option: string;
  region: string;
  active: boolean;
  currencyCode: string | null;
  units: string | null;
  nanos: number | null;
  amount: string | null;
}

export interface BadgeCatalogLineDiagnosis extends BadgePriceDiagnosis {
  finalPriceKurus: number | null;
  pricePath: string;
  offerId: string;
  offerActive: boolean;
  offerFinalPriceKurus: number | null;
}

/**
 * Reads exactly one catalog product and returns only its safe TR price fields.
 * No purchase, order, or token data is requested or returned.
 * @return {Promise<BadgePriceDiagnosis>} Safe catalog price diagnosis.
 */
export async function diagnoseOkey101Price(): Promise<BadgePriceDiagnosis> {
  return diagnoseOneTimeProductPrice(
    "dort_badge_okey_101",
    "buy",
    "TR",
  );
}

/**
 * Reads only the Okey gift product configured in Play Console.
 * @return {Promise<BadgePriceDiagnosis>} Safe catalog price diagnosis.
 */
export async function diagnoseOkeyGiftPrice(): Promise<BadgePriceDiagnosis> {
  return diagnoseOneTimeProductPrice(
    "dort_gift_badge_okey",
    "buy",
    "TR",
  );
}

/**
 * Reads one fixed one-time product and returns its requested regional price.
 * @param {string} productId Play product id.
 * @param {string} optionId Purchase option id.
 * @param {string} regionCode Region code.
 * @return {Promise<BadgePriceDiagnosis>} Safe catalog price diagnosis.
 */
async function diagnoseOneTimeProductPrice(
  productId: string,
  optionId: string,
  regionCode: string,
): Promise<BadgePriceDiagnosis> {
  const packageName = requirePackageName();
  const path = `applications/${encodeURIComponent(packageName)}/` +
    `oneTimeProducts/${encodeURIComponent(productId)}`;
  const product = await callAndroidPublisher<{
    productId?: unknown;
    purchaseOptions?: Array<{
      purchaseOptionId?: unknown;
      state?: unknown;
      regionalPricingAndAvailabilityConfigs?: Array<{
        regionCode?: unknown;
        availability?: unknown;
        price?: unknown;
      }>;
    }>;
  }>(path, "GET");
  const option = (product.purchaseOptions ?? []).find(
    (item) => String(item.purchaseOptionId ?? "") === optionId,
  );
  const region = (option?.regionalPricingAndAvailabilityConfigs ?? []).find(
    (item) => String(item.regionCode ?? "") === regionCode,
  );
  const money = normalizePlayMoney(region?.price);

  return {
    product: String(product.productId ?? ""),
    option: String(option?.purchaseOptionId ?? ""),
    region: String(region?.regionCode ?? ""),
    active: option?.state === "ACTIVE" && region?.availability === "AVAILABLE",
    currencyCode: money?.currencyCode ?? null,
    units: money?.units ?? null,
    nanos: money?.nanos ?? null,
    amount: money?.amount ?? null,
  };
}

/**
 * Reads the badge index, then each product individually because Play's list
 * response may omit regional Money fields. Offers are read once.
 * Only safe catalog identity, state, region, and price fields are returned.
 * @return {Promise<BadgeCatalogLineDiagnosis[]>} Safe catalog inventory.
 */
export async function diagnoseBadgeCatalog():
  Promise<BadgeCatalogLineDiagnosis[]> {
  const packageName = requirePackageName();
  const app = `applications/${encodeURIComponent(packageName)}`;
  const productIndex = await callAndroidPublisher<{
    oneTimeProducts?: Array<{
      productId?: unknown;
      purchaseOptions?: Array<{
        purchaseOptionId?: unknown;
        state?: unknown;
        regionalPricingAndAvailabilityConfigs?: Array<{
          regionCode?: unknown;
          availability?: unknown;
          price?: unknown;
        }>;
      }>;
    }>;
  }>(`${app}/oneTimeProducts?pageSize=100`, "GET");
  const productIds = (productIndex.oneTimeProducts ?? [])
    .map((product) => String(product.productId ?? ""))
    .filter((productId) => productId.startsWith("dort_badge_"));
  const products = await Promise.all(productIds.map((productId) =>
    callAndroidPublisher<{
      productId?: unknown;
      purchaseOptions?: Array<{
        purchaseOptionId?: unknown;
        state?: unknown;
        regionalPricingAndAvailabilityConfigs?: Array<{
          regionCode?: unknown;
          availability?: unknown;
          price?: unknown;
        }>;
      }>;
    }>(`${app}/oneTimeProducts/${encodeURIComponent(productId)}`, "GET"),
  ));
  const offers = await callAndroidPublisher<{
    oneTimeProductOffers?: Array<{
      productId?: unknown;
      purchaseOptionId?: unknown;
      offerId?: unknown;
      state?: unknown;
      startTime?: unknown;
      regionalPricingAndAvailabilityConfigs?: Array<{
        regionCode?: unknown;
        availability?: unknown;
        relativeDiscount?: unknown;
        absoluteDiscount?: unknown;
      }>;
    }>;
  }>(`${app}/oneTimeProducts/-/purchaseOptions/-/offers?pageSize=100`, "GET");

  return Promise.all(products
    .map(async (product) => {
      const productId = String(product.productId ?? "");
      const option = (product.purchaseOptions ?? []).find(
        (item) => String(item.purchaseOptionId ?? "") === "buy" ||
          String(item.purchaseOptionId ?? "") === "standard",
      );
      const region = (option?.regionalPricingAndAvailabilityConfigs ?? [])
        .find((item) => String(item.regionCode ?? "") === "TR");
      const priceValue = region?.price;
      const money = normalizePlayMoney(priceValue);
      const pricePath = money == null ? "" :
        "purchaseOptions.regionalPricingAndAvailabilityConfigs.price";
      const offer = (offers.oneTimeProductOffers ?? []).find((item) =>
        String(item.productId ?? "") === productId &&
        String(item.purchaseOptionId ?? "") ===
          String(option?.purchaseOptionId ?? "") &&
        String(item.offerId ?? "") === "plus-price",
      );
      const offerRegion = (offer?.regionalPricingAndAvailabilityConfigs ?? [])
        .find((item) => String(item.regionCode ?? "") === "TR");
      const paidFraction = Number(offerRegion?.relativeDiscount);
      const baseKurus = playMoneyKurus(priceValue);
      const absoluteDiscountKurus = playMoneyKurus(
        offerRegion?.absoluteDiscount,
      );
      const relativeOfferKurus = baseKurus != null &&
        Number.isFinite(paidFraction) && paidFraction > 0 && paidFraction < 1 ?
        Math.round(baseKurus * paidFraction) : null;
      const offerKurus = baseKurus != null && absoluteDiscountKurus != null ?
        baseKurus - absoluteDiscountKurus : relativeOfferKurus;

      return {
        product: productId,
        option: String(option?.purchaseOptionId ?? ""),
        region: String(region?.regionCode ?? ""),
        active: option?.state === "ACTIVE" &&
          region?.availability === "AVAILABLE",
        currencyCode: money?.currencyCode ?? null,
        units: money?.units ?? null,
        nanos: money?.nanos ?? null,
        amount: money?.amount ?? null,
        finalPriceKurus: baseKurus,
        pricePath,
        offerId: String(offer?.offerId ?? ""),
        offerActive: offer?.state === "ACTIVE" &&
          offerRegion?.availability === "AVAILABLE",
        offerStartTime: String(offer?.startTime ?? ""),
        offerRegion: String(offerRegion?.regionCode ?? ""),
        offerFinalPriceKurus: offerKurus,
      };
    }));
}

/**
 * Runs one read-only permission probe against voided purchases.
 *
 * This deliberately performs exactly one Android Publisher request and never
 * returns response data, purchase tokens, or order identifiers.
 * @return {Promise<PlayAccessDiagnosis>} Safe single-probe diagnosis.
 */
export async function diagnosePlayVoidedAccess(): Promise<PlayAccessDiagnosis> {
  const packageName = requirePackageName();
  const client = await playAuth.getClient();
  const credentials = await playAuth.getCredentials();
  const accessToken = await getPlayAccessToken();
  const url = `${ANDROID_PUBLISHER_BASE}/applications/` +
    `${encodeURIComponent(packageName)}/purchases/voidedpurchases`;
  const response = await fetch(url, {
    headers: {
      "Authorization": `Bearer ${accessToken}`,
      "Accept": "application/json",
    },
  });
  const responseText = await response.text();

  return {
    packageName,
    credentialType: client.constructor.name,
    serviceAccountEmail: String(credentials.client_email ?? ""),
    tokenEmail: "",
    tokenHasPlayScope: true,
    probes: [{
      label: "purchases.voidedpurchases.list",
      manualStatus: response.status,
      manualReason: response.ok ? "" : readPlayErrorReason(responseText),
      libraryStatus: 0,
      libraryReason: "not-run-single-probe",
      summary: "",
    }],
  };
}

/**
 * Calls Android Publisher with the same runtime credential as purchase
 * verification. Each URL is sent twice: the manual Bearer request used in
 * production and the official auth library request. Only statuses, Google
 * error text and product ids are returned. A fake purchase token is used, so
 * no purchase is read or changed.
 * @return {Promise<PlayAccessDiagnosis>} Safe diagnosis.
 */
export async function diagnosePlayAccess(): Promise<PlayAccessDiagnosis> {
  const packageName = requirePackageName();
  const client = await playAuth.getClient();
  const credentials = await playAuth.getCredentials();
  const accessToken = await getPlayAccessToken();

  const tokenInfoResponse = await fetch(
    "https://oauth2.googleapis.com/tokeninfo",
    {
      method: "POST",
      headers: {"Content-Type": "application/x-www-form-urlencoded"},
      body: new URLSearchParams({access_token: accessToken}).toString(),
    },
  );
  const tokenInfo = await tokenInfoResponse.json() as {
    email?: string;
    scope?: string;
  };

  const app = `${ANDROID_PUBLISHER_BASE}/applications/` +
    encodeURIComponent(packageName);
  const fakeToken = "dort-diagnostic-invalid-token";
  const targets: Array<[string, string]> = [
    [
      "purchases.products.get dort_badge_okey (fake token)",
      `${app}/purchases/products/dort_badge_okey/tokens/${fakeToken}`,
    ],
    [
      "purchases.subscriptionsv2.get (fake token)",
      `${app}/purchases/subscriptionsv2/tokens/${fakeToken}`,
    ],
    ["purchases.voidedpurchases.list", `${app}/purchases/voidedpurchases`],
    [
      "monetization.subscriptions.get dort_plus",
      `${app}/subscriptions/dort_plus`,
    ],
    ["monetization.onetimeproducts.list", `${app}/oneTimeProducts`],
    ["inappproducts.list", `${app}/inappproducts`],
  ];

  const probes: PlayAccessProbe[] = [];
  for (const [label, url] of targets) {
    const manual = await fetch(url, {
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Accept": "application/json",
      },
    });
    const manualText = await manual.text();
    const library = await client.request<unknown>({
      url,
      validateStatus: () => true,
      responseType: "text",
    });
    const libraryText = String(library.data ?? "");
    probes.push({
      label,
      manualStatus: manual.status,
      manualReason: readPlayErrorReason(manualText),
      libraryStatus: library.status,
      libraryReason: readPlayErrorReason(libraryText),
      summary: manual.ok ? summarizeCatalog(manualText) : "",
    });
  }

  return {
    packageName,
    credentialType: client.constructor.name,
    serviceAccountEmail: String(credentials.client_email ?? ""),
    tokenEmail: String(tokenInfo.email ?? ""),
    tokenHasPlayScope: String(tokenInfo.scope ?? "")
      .split(" ")
      .includes(PLAY_PUBLISHER_SCOPE),
    probes,
  };
}

/**
 * Lists product ids and states from a catalog response.
 * @param {string} text Response body.
 * @return {string} Ids only.
 */
function summarizeCatalog(text: string): string {
  try {
    const data = JSON.parse(text) as {
      oneTimeProducts?: Array<{productId?: string}>;
      inappproduct?: Array<{sku?: string; status?: string}>;
      basePlans?: Array<{basePlanId?: string; state?: string}>;
    };
    if (data.oneTimeProducts) {
      return data.oneTimeProducts.map((item) => item.productId).join(",");
    }
    if (data.inappproduct) {
      return data.inappproduct
        .map((item) => `${item.sku}(${item.status})`)
        .join(",");
    }
    if (data.basePlans) {
      return data.basePlans
        .map((item) => `${item.basePlanId}(${item.state})`)
        .join(",");
    }
    return "";
  } catch {
    return "";
  }
}

/**
 * Mints an Android Publisher token for the runtime service account.
 *
 * The token requests only the Play scope. The Admin SDK default token is
 * not used, and the token value is not logged.
 * @return {Promise<string>} Access token.
 */
async function getPlayAccessToken(): Promise<string> {
  if (process.env.FUNCTIONS_EMULATOR === "true" ||
      process.env.FIRESTORE_EMULATOR_HOST) {
    throw new HttpsError(
      "failed-precondition", "Dev cannot contact Google Play.",
    );
  }
  try {
    const client = await playAuth.getClient();
    const token = await client.getAccessToken();
    const value = String(token.token ?? "").trim();

    if (!value) {
      throw new Error("empty token");
    }

    return value;
  } catch {
    console.error("Google Play access token could not be created.");
    throw new HttpsError(
      "unavailable",
      "Google Play doğrulama servisine erişilemiyor.",
    );
  }
}

/**
 * Turns a Play HTTP failure into a user message and a token-free log line.
 * @param {number} status HTTP status.
 * @param {string} responseText Response body.
 * @return {object} User message and log summary.
 */
export function describePlayFailure(
  status: number,
  responseText: string,
): {userMessage: string; logSummary: string} {
  const reason = readPlayErrorReason(responseText);
  const logSummary = reason.length === 0 ?
    String(status) :
    `${status} ${reason}`;

  if (status === 401 || status === 403) {
    return {
      userMessage: "Satın alma doğrulanamadı. Tekrar kontrol et.",
      logSummary,
    };
  }

  if (status === 404) {
    return {
      userMessage: "Google Play satın alma kaydı doğrulanamadı.",
      logSummary,
    };
  }

  return {
    userMessage:
      "Google Play doğrulama servisi geçici olarak kullanılamıyor.",
    logSummary,
  };
}

/**
 * Reads Play's error status and message. Any other body is ignored.
 * @param {string} responseText Response body.
 * @return {string} Short reason, or empty.
 */
function readPlayErrorReason(responseText: string): string {
  try {
    const parsed = JSON.parse(responseText) as {
      error?: {status?: unknown; message?: unknown};
    };
    const status = String(parsed.error?.status ?? "").trim();
    const message = String(parsed.error?.message ?? "").trim();

    if (!status && !message) {
      return "";
    }

    return `${status}: ${message}`.slice(0, 240);
  } catch {
    return "";
  }
}

/**
 * Executes an authenticated Android Publisher API request.
 *
 * @param {string} url Request URL.
 * @param {"GET"|"POST"} method HTTP method.
 * @param {Record<string, unknown>|undefined} body Optional JSON body.
 * @param {number[]} acceptedStatuses Statuses that are not failures.
 * @return {Promise<T>} Parsed response.
 */
async function googlePlayRequest<T>(
  url: string,
  method: "GET" | "POST" | "PATCH",
  body?: Record<string, unknown>,
  acceptedStatuses: readonly number[] = [],
): Promise<T> {
  if (process.env.FUNCTIONS_EMULATOR === "true" ||
      process.env.FIRESTORE_EMULATOR_HOST) {
    // Local fixtures are never accepted in production. No ADC fallback.
    const {getFirestore} = await import("firebase-admin/firestore");
    const key = createHash("sha256").update(`${method}:${url}`).digest("hex");
    const fixture = await getFirestore()
      .collection("dev_external_adapters").doc(key).get();
    if (!fixture.exists || fixture.get("service") !== "google_play") {
      throw new HttpsError(
        "unavailable", "Dev Play adapter: no configured response.",
      );
    }
    if (fixture.get("failure") === true) {
      throw new HttpsError(
        "unavailable", "Dev Play adapter: simulated provider failure.",
      );
    }
    return fixture.get("response") as T;
  }
  const accessToken = await getPlayAccessToken();

  const response = await fetch(
    url,
    {
      method,
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: body == null ? undefined : JSON.stringify(body),
    },
  );

  const responseText = await response.text();

  const accepted = acceptedStatuses.includes(response.status);

  if (!response.ok && !accepted) {
    const failure = describePlayFailure(
      response.status,
      responseText,
    );
    console.error(
      "Google Play verification request failed.",
      failure.logSummary,
    );

    throw new HttpsError(
      response.status === 401 || response.status === 403 ||
        response.status === 404 ?
        "failed-precondition" :
        "unavailable",
      failure.userMessage,
    );
  }

  if (responseText.trim().length === 0) {
    return {} as T;
  }

  try {
    return JSON.parse(responseText) as T;
  } catch (error) {
    console.error(
      "Google Play response could not be parsed.",
      error,
    );

    throw new HttpsError(
      "internal",
      "Google Play doğrulama yanıtı işlenemedi.",
    );
  }
}

/**
 * Reads the configured Android package name.
 *
 * @return {string} Android package name.
 */
function requirePackageName(): string {
  return requireString(
    androidPackageName.value(),
    "ANDROID_PACKAGE_NAME",
    300,
  );
}

/**
 * Hashes a raw Google Play purchase token for safe storage.
 *
 * @param {string} token Raw token.
 * @return {string} SHA-256 token hash.
 */
export function hashPurchaseToken(
  token: string,
): string {
  return createHash("sha256")
    .update(token, "utf8")
    .digest("hex");
}

/**
 * Parses one Google RFC3339 timestamp.
 *
 * @param {unknown} value Raw date.
 * @return {Date|null} Parsed date.
 */
function parseGoogleDate(
  value: unknown,
): Date | null {
  const normalized = String(value ?? "").trim();

  if (!normalized) {
    return null;
  }

  const parsed = new Date(normalized);

  if (!Number.isFinite(parsed.getTime())) {
    return null;
  }

  return parsed;
}

/**
 * Normalizes one optional string.
 *
 * @param {unknown} value Raw value.
 * @return {string|null} Normalized value.
 */
function normalizeOptionalString(
  value: unknown,
): string | null {
  const normalized = String(value ?? "").trim();
  return normalized.length > 0 ? normalized : null;
}

/**
 * Reads one required string.
 *
 * @param {unknown} value Raw value.
 * @param {string} field Field name.
 * @param {number} maxLength Max length.
 * @return {string} Normalized string.
 */
function requireString(
  value: unknown,
  field: string,
  maxLength: number,
): string {
  if (typeof value !== "string") {
    throw new HttpsError(
      "invalid-argument",
      `${field} geçerli bir metin olmalıdır.`,
    );
  }

  const normalized = value.trim();

  if (!normalized) {
    throw new HttpsError(
      "invalid-argument",
      `${field} zorunludur.`,
    );
  }

  if (normalized.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `${field} çok uzun.`,
    );
  }

  return normalized;
}
