import {createHash} from "crypto";

import {getApp} from "firebase-admin/app";
import {defineString} from "firebase-functions/params";
import {HttpsError} from "firebase-functions/v2/https";

const androidPackageName = defineString(
  "ANDROID_PACKAGE_NAME",
  {
    default: "com.dortapp.dort",
  },
);

const ANDROID_PUBLISHER_BASE =
  "https://androidpublisher.googleapis.com/androidpublisher/v3";

export interface VerifiedGooglePlayProduct {
  kind: "product";
  googlePlayProductId: string;
  orderId: string | null;
  acknowledged: boolean;
  purchaseTokenHash: string;
  testPurchase: boolean;
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
}

interface ProductPurchaseResponse {
  purchaseState?: number;
  acknowledgementState?: number;
  orderId?: string;
  purchaseType?: number;
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

  const url =
    `${ANDROID_PUBLISHER_BASE}/applications/` +
    `${encodeURIComponent(packageName)}/purchases/products/` +
    `${encodeURIComponent(productId)}/tokens/` +
    `${encodeURIComponent(token)}`;

  const data = await googlePlayRequest<ProductPurchaseResponse>(
    url,
    "GET",
  );

  if (data.purchaseState !== 0) {
    throw new HttpsError(
      "failed-precondition",
      "Google Play satın alma işlemi tamamlanmış değil.",
    );
  }

  return {
    kind: "product",
    googlePlayProductId: productId,
    orderId: normalizeOptionalString(data.orderId),
    acknowledged: data.acknowledgementState === 1,
    purchaseTokenHash: hashPurchaseToken(token),
    testPurchase: data.purchaseType === 0,
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
 * @return {Promise<GooglePlaySubscriptionStatus>} Latest provider state.
 */
export async function getGooglePlaySubscriptionStatus(
  googlePlayProductId: string,
  purchaseToken: string,
  expectedBasePlanId?: string,
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

  if (expectedBasePlanId != null) {
    assertStandardBasePlan(latestItem, expectedBasePlanId);
  }

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
  };
}

/**
 * Verifies one Google Play subscription purchase for entitlement.
 *
 * @param {string} googlePlayProductId Expected subscription product id.
 * @param {string} purchaseToken Raw token supplied by Google Play Billing.
 * @param {string} expectedBasePlanId Catalog standard base plan id.
 * @return {Promise<VerifiedGooglePlaySubscription>} Verified subscription.
 */
export async function verifyGooglePlaySubscription(
  googlePlayProductId: string,
  purchaseToken: string,
  expectedBasePlanId: string,
): Promise<VerifiedGooglePlaySubscription> {
  const status = await getGooglePlaySubscriptionStatus(
    googlePlayProductId,
    purchaseToken,
    expectedBasePlanId,
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
  };
}

/**
 * Requires the entitled line item to be the configured standard base plan.
 *
 * A promotional offer id is rejected. Another base plan is not accepted.
 * @param {SubscriptionLineItem|null} item Latest entitled line item.
 * @param {string} expectedBasePlanId Catalog base plan id.
 * @return {void}
 */
function assertStandardBasePlan(
  item: SubscriptionLineItem | null,
  expectedBasePlanId: string,
): void {
  const expected = expectedBasePlanId.trim();
  const basePlanId = String(
    item?.offerDetails?.basePlanId ?? "",
  ).trim();
  const offerId = String(
    item?.offerDetails?.offerId ?? "",
  ).trim();

  if (!expected || basePlanId !== expected || offerId !== "") {
    throw new HttpsError(
      "failed-precondition",
      "Google Play aboneliği seçilen standart base plan ile eşleşmiyor.",
    );
  }
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

/**
 * Executes an authenticated Android Publisher API request.
 *
 * @param {string} url Request URL.
 * @param {"GET"|"POST"} method HTTP method.
 * @param {Record<string, unknown>|undefined} body Optional JSON body.
 * @return {Promise<T>} Parsed response.
 */
async function googlePlayRequest<T>(
  url: string,
  method: "GET" | "POST",
  body?: Record<string, unknown>,
): Promise<T> {
  const credential = getApp().options.credential;

  if (credential == null) {
    throw new HttpsError(
      "failed-precondition",
      "Google Play server kimliği yapılandırılmamış.",
    );
  }

  let accessToken: string;

  try {
    const token = await credential.getAccessToken();
    accessToken = token.access_token;
  } catch (error) {
    console.error(
      "Google Play access token could not be created.",
      error,
    );

    throw new HttpsError(
      "unavailable",
      "Google Play doğrulama servisine erişilemiyor.",
    );
  }

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

  if (!response.ok) {
    console.error(
      "Google Play verification request failed.",
      {
        status: response.status,
        body: responseText.slice(0, 1000),
      },
    );

    if (
      response.status === 401 ||
      response.status === 403
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Google Play API yetkisi yapılandırılmamış.",
      );
    }

    if (response.status === 404) {
      throw new HttpsError(
        "failed-precondition",
        "Google Play satın alma kaydı doğrulanamadı.",
      );
    }

    throw new HttpsError(
      "unavailable",
      "Google Play doğrulama servisi geçici olarak kullanılamıyor.",
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
