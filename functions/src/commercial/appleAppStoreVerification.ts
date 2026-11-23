/* eslint-disable max-len */
import {createHash, verify as cryptoVerify, X509Certificate} from "crypto";
import {HttpsError} from "firebase-functions/v2/https";

/**
 * Official Apple Root CA SHA-256 fingerprints used by App Store StoreKit 2 JWS
 * and App Store Server Notifications V2 certificate chains.
 *
 * - Apple Root CA - G3 (primary for StoreKit 2 / ASSN V2)
 * - Apple Root CA - G2 (fallback root)
 */
export const APPLE_ROOT_CA_FINGERPRINTS = new Set<string>([
  "63343ABFB89A6A03EBB57E9B3F5FA7BE7C4F5C756F3017B3A8C488C3653E9179",
  "C2B9B042DD57830E7D117DAC55AC8AE19407D38E41D88F3215BC3A890444A050",
]);

export const DEFAULT_APPLE_BUNDLE_ID = "com.dortapp.dort";

export interface AppleJwsVerifyOptions {
  trustedRootFingerprints?: Set<string>;
  nowMs?: number;
}

export interface AppleTransactionPayload {
  transactionId: string;
  originalTransactionId: string;
  bundleId: string;
  productId: string;
  type: string;
  environment: string;
  purchaseDateMs: number;
  originalPurchaseDateMs: number | null;
  expiresDateMs: number | null;
  revocationDateMs: number | null;
  revocationReason: number | null;
  appAccountToken: string | null;
  price: number | null;
  currency: string | null;
  inAppOwnershipType: string;
  quantity: number;
}

export interface AppleRenewalInfoPayload {
  originalTransactionId: string;
  autoRenewProductId: string;
  productId: string;
  autoRenewStatus: number;
  expirationIntent: number | null;
  gracePeriodExpiresDateMs: number | null;
  isInBillingRetryPeriod: boolean;
  environment: string;
}

export interface VerifiedAppleNotification {
  notificationType: string;
  subtype: string;
  notificationUUID: string;
  version: string;
  signedDateMs: number | null;
  environment: string;
  bundleId: string;
  transaction: AppleTransactionPayload | null;
  renewalInfo: AppleRenewalInfoPayload | null;
}

/**
 * Deterministically maps a Firebase UID to an RFC-4122 UUID v5 formatted
 * StoreKit 2 appAccountToken. Matches Dart `appleAppAccountTokenForUid`.
 * @param {string} uid Firebase user uid.
 * @return {string} Lowercase canonical UUID.
 */
export function appleAppAccountTokenForUid(uid: string): string {
  const normalized = uid.trim();
  if (!normalized) {
    throw new Error("uid_required_for_app_account_token");
  }

  const digest = createHash("sha256")
    .update(`dort:apple_app_account_token:${normalized}`)
    .digest();

  const bytes = Buffer.from(digest.subarray(0, 16));
  bytes[6] = (bytes[6] & 0x0f) | 0x50; // Version 5
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant

  const hex = bytes.toString("hex");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-` +
    `${hex.slice(16, 20)}-${hex.slice(20, 32)}`;
}

/**
 * Cryptographically verifies an Apple JWS (ES256 + x5c certificate chain)
 * and returns its decoded JSON payload.
 * @param {string} jws Compact JWS string.
 * @param {AppleJwsVerifyOptions} options Verification overrides for tests.
 * @return {Record<string, unknown>} Verified JSON payload.
 */
export function verifyAppleJws(
  jws: string,
  options: AppleJwsVerifyOptions = {},
): Record<string, unknown> {
  const trimmed = jws.trim();
  const parts = trimmed.split(".");
  if (parts.length !== 3 || parts.some((part) => part.length === 0)) {
    throw new HttpsError(
      "invalid-argument",
      "Apple doğrulama imzası geçersiz biçimde.",
    );
  }

  const [headerB64, payloadB64, signatureB64] = parts;
  const header = decodeBase64UrlJson(headerB64, "header");
  const alg = String(header.alg ?? "").trim();
  if (alg !== "ES256") {
    throw new HttpsError(
      "invalid-argument",
      "Desteklenmeyen Apple imza algoritması.",
    );
  }

  const rawChain = header.x5c;
  if (!Array.isArray(rawChain) || rawChain.length < 2) {
    throw new HttpsError(
      "invalid-argument",
      "Apple sertifika zinciri eksik.",
    );
  }

  const nowMs = options.nowMs ?? Date.now();
  const trustedRoots = options.trustedRootFingerprints ??
    APPLE_ROOT_CA_FINGERPRINTS;

  let certs: X509Certificate[];
  try {
    certs = rawChain.map((item) => {
      if (typeof item !== "string" || !item.trim()) {
        throw new Error("empty_cert");
      }
      return new X509Certificate(Buffer.from(item.trim(), "base64"));
    });
  } catch {
    throw new HttpsError(
      "invalid-argument",
      "Apple sertifika zinciri okunamadı.",
    );
  }

  for (const cert of certs) {
    const validFrom = Date.parse(cert.validFrom);
    const validTo = Date.parse(cert.validTo);
    if (
      !Number.isFinite(validFrom) ||
      !Number.isFinite(validTo) ||
      nowMs < validFrom ||
      nowMs > validTo
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Apple sertifikasının geçerlilik süresi dolmuş.",
      );
    }
  }

  for (let i = 0; i < certs.length - 1; i += 1) {
    if (!certs[i].verify(certs[i + 1].publicKey)) {
      throw new HttpsError(
        "permission-denied",
        "Apple sertifika zinciri doğrulanamadı.",
      );
    }
  }

  const rootCert = certs[certs.length - 1];
  const rootFingerprint = rootCert.fingerprint256
    .replace(/:/g, "")
    .toUpperCase();
  if (!trustedRoots.has(rootFingerprint)) {
    throw new HttpsError(
      "permission-denied",
      "Apple kök sertifikası güvenilir değil.",
    );
  }

  const signingInput = Buffer.from(`${headerB64}.${payloadB64}`, "utf8");
  const signature = decodeBase64UrlBuffer(signatureB64);

  const signatureValid = cryptoVerify(
    "sha256",
    signingInput,
    {
      key: certs[0].publicKey,
      dsaEncoding: "ieee-p1363",
    },
    signature,
  );

  if (!signatureValid) {
    throw new HttpsError(
      "permission-denied",
      "Apple JWS imzası doğrulanamadı.",
    );
  }

  return decodeBase64UrlJson(payloadB64, "payload");
}

/**
 * Verifies a StoreKit 2 signed transaction JWS and validates business rules.
 * @param {string} signedTransactionInfo JWS from StoreKit 2.
 * @param {object} params Expected constraints.
 * @return {AppleTransactionPayload} Verified transaction fields.
 */
export function verifyAppleSignedTransaction(
  signedTransactionInfo: string,
  params: {
    expectedBundleId?: string;
    expectedProductId?: string;
    expectedUid?: string;
    requireActiveSubscription?: boolean;
    allowXcodeEnvironment?: boolean;
    options?: AppleJwsVerifyOptions;
  } = {},
): AppleTransactionPayload {
  const payload = verifyAppleJws(signedTransactionInfo, params.options);
  const tx = parseAppleTransaction(payload);

  const expectedBundleId = (
    params.expectedBundleId ?? DEFAULT_APPLE_BUNDLE_ID
  ).trim();
  if (tx.bundleId !== expectedBundleId) {
    throw new HttpsError(
      "permission-denied",
      "Apple işlem paket kimliği bu uygulama ile eşleşmiyor.",
    );
  }

  const allowedEnvs = params.allowXcodeEnvironment === true ?
    new Set(["Production", "Sandbox", "Xcode"]) :
    new Set(["Production", "Sandbox"]);
  if (!allowedEnvs.has(tx.environment)) {
    throw new HttpsError(
      "failed-precondition",
      "Yerel test ortamı (Xcode) işlemi sunucuda kabul edilmez.",
    );
  }

  if (params.expectedProductId && tx.productId !== params.expectedProductId) {
    throw new HttpsError(
      "invalid-argument",
      "Apple ürün kimliği beklenen katalog ürünü ile eşleşmiyor.",
    );
  }

  if (tx.revocationDateMs != null) {
    throw new HttpsError(
      "failed-precondition",
      "Bu Apple satın alması iade edilmiş veya iptal edilmiş.",
    );
  }

  if (params.expectedUid && tx.appAccountToken) {
    const expectedToken = appleAppAccountTokenForUid(params.expectedUid);
    if (tx.appAccountToken.toLowerCase() !== expectedToken.toLowerCase()) {
      throw new HttpsError(
        "permission-denied",
        "Bu Apple satın alması başka bir Dört. hesabına bağlı.",
      );
    }
  }

  const nowMs = params.options?.nowMs ?? Date.now();
  if (params.requireActiveSubscription) {
    if (tx.expiresDateMs == null || tx.expiresDateMs <= nowMs) {
      throw new HttpsError(
        "failed-precondition",
        "Apple Plus aboneliğinin süresi dolmuş.",
      );
    }
  }

  return tx;
}

/**
 * Verifies an App Store Server Notifications V2 signedPayload and its nested
 * signedTransactionInfo / signedRenewalInfo JWS payloads.
 * @param {string} signedPayload Outer ASSN V2 JWS.
 * @param {object} params Verification constraints.
 * @return {VerifiedAppleNotification} Verified notification object.
 */
export function verifyAppleServerNotification(
  signedPayload: string,
  params: {
    expectedBundleId?: string;
    options?: AppleJwsVerifyOptions;
  } = {},
): VerifiedAppleNotification {
  const outer = verifyAppleJws(signedPayload, params.options);
  const notificationType = readText(outer.notificationType);
  const subtype = readText(outer.subtype);
  const notificationUUID = readText(outer.notificationUUID);
  const version = readText(outer.version);
  const signedDateMs = readOptionalMillis(outer.signedDate);

  if (!notificationType || !notificationUUID) {
    throw new HttpsError(
      "invalid-argument",
      "Apple bildirim kimliği veya türü eksik.",
    );
  }

  const data = isRecord(outer.data) ? outer.data : {};
  const bundleId = readText(data.bundleId);
  const environment = readText(data.environment);

  const expectedBundleId = (
    params.expectedBundleId ?? DEFAULT_APPLE_BUNDLE_ID
  ).trim();
  if (bundleId && bundleId !== expectedBundleId) {
    throw new HttpsError(
      "permission-denied",
      "Apple bildirim paket kimliği eşleşmiyor.",
    );
  }

  const rawSignedTx = readText(data.signedTransactionInfo);
  const rawSignedRenewal = readText(data.signedRenewalInfo);

  const transaction = rawSignedTx ?
    parseAppleTransaction(verifyAppleJws(rawSignedTx, params.options)) :
    null;
  const renewalInfo = rawSignedRenewal ?
    parseAppleRenewalInfo(verifyAppleJws(rawSignedRenewal, params.options)) :
    null;

  if (transaction && transaction.bundleId !== expectedBundleId) {
    throw new HttpsError(
      "permission-denied",
      "Apple işlem paket kimliği eşleşmiyor.",
    );
  }

  return {
    notificationType,
    subtype,
    notificationUUID,
    version,
    signedDateMs,
    environment: environment || transaction?.environment || "",
    bundleId: bundleId || transaction?.bundleId || "",
    transaction,
    renewalInfo,
  };
}

/**
 * Maps an Apple subscription lifecycle event + transaction/renewal state to
 * the canonical Dört. Plus subscription state shared with Google Play.
 * @param {object} input Lifecycle inputs.
 * @return {object} Mapped state.
 */
export function resolveAppleSubscriptionState(input: {
  notificationType?: string;
  subtype?: string;
  transaction: AppleTransactionPayload;
  renewalInfo?: AppleRenewalInfoPayload | null;
  nowMs?: number;
}): {
  subscriptionState: string;
  hasEntitlement: boolean;
  expiryTime: Date | null;
} {
  const nowMs = input.nowMs ?? Date.now();
  const type = (input.notificationType ?? "").trim().toUpperCase();
  const subtype = (input.subtype ?? "").trim().toUpperCase();
  const tx = input.transaction;
  const renewal = input.renewalInfo ?? null;

  if (
    tx.revocationDateMs != null ||
    type === "REVOKE" ||
    type === "REFUND"
  ) {
    return {
      subscriptionState: "SUBSCRIPTION_STATE_REVOKED",
      hasEntitlement: false,
      expiryTime: null,
    };
  }

  const graceMs = renewal?.gracePeriodExpiresDateMs ?? null;
  if (
    (type === "DID_FAIL_TO_RENEW" && subtype === "GRACE_PERIOD") ||
    (graceMs != null && graceMs > nowMs)
  ) {
    const effectiveMs = Math.max(tx.expiresDateMs ?? 0, graceMs ?? 0);
    return {
      subscriptionState: "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
      hasEntitlement: effectiveMs > nowMs,
      expiryTime: effectiveMs > 0 ? new Date(effectiveMs) : null,
    };
  }

  if (
    type === "EXPIRED" ||
    type === "GRACE_PERIOD_EXPIRED" ||
    tx.expiresDateMs == null ||
    tx.expiresDateMs <= nowMs
  ) {
    return {
      subscriptionState: "SUBSCRIPTION_STATE_EXPIRED",
      hasEntitlement: false,
      expiryTime: tx.expiresDateMs != null ? new Date(tx.expiresDateMs) : null,
    };
  }

  if (
    (type === "DID_CHANGE_RENEWAL_STATUS" &&
      subtype === "AUTO_RENEW_DISABLED") ||
    renewal?.autoRenewStatus === 0
  ) {
    return {
      subscriptionState: "SUBSCRIPTION_STATE_CANCELED",
      hasEntitlement: true,
      expiryTime: new Date(tx.expiresDateMs),
    };
  }

  return {
    subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
    hasEntitlement: true,
    expiryTime: new Date(tx.expiresDateMs),
  };
}

/**
 * Parses a verified Apple StoreKit 2 transaction payload.
 * @param {Record<string, unknown>} payload Verified JWS payload.
 * @return {AppleTransactionPayload} Parsed transaction.
 */
export function parseAppleTransaction(
  payload: Record<string, unknown>,
): AppleTransactionPayload {
  const transactionId = readText(payload.transactionId);
  const originalTransactionId = readText(payload.originalTransactionId);
  const bundleId = readText(payload.bundleId);
  const productId = readText(payload.productId);
  const environment = readText(payload.environment);

  if (
    !transactionId ||
    !originalTransactionId ||
    !bundleId ||
    !productId
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Apple işlem verisinde zorunlu alanlar eksik.",
    );
  }

  const purchaseDateMs = readOptionalMillis(payload.purchaseDate) ?? Date.now();
  const quantityRaw = Number(payload.quantity ?? 1);

  return {
    transactionId,
    originalTransactionId,
    bundleId,
    productId,
    type: readText(payload.type),
    environment,
    purchaseDateMs,
    originalPurchaseDateMs: readOptionalMillis(payload.originalPurchaseDate),
    expiresDateMs: readOptionalMillis(payload.expiresDate),
    revocationDateMs: readOptionalMillis(payload.revocationDate),
    revocationReason: readOptionalInt(payload.revocationReason),
    appAccountToken: readOptionalString(payload.appAccountToken),
    price: readOptionalInt(payload.price),
    currency: readOptionalString(payload.currency),
    inAppOwnershipType: readText(payload.inAppOwnershipType) || "PURCHASED",
    quantity: Number.isInteger(quantityRaw) && quantityRaw > 0 ?
      quantityRaw :
      1,
  };
}

/**
 * Parses a verified Apple StoreKit 2 renewal info payload.
 * @param {Record<string, unknown>} payload Verified JWS payload.
 * @return {AppleRenewalInfoPayload} Parsed renewal info.
 */
function parseAppleRenewalInfo(
  payload: Record<string, unknown>,
): AppleRenewalInfoPayload {
  return {
    originalTransactionId: readText(payload.originalTransactionId),
    autoRenewProductId: readText(payload.autoRenewProductId),
    productId: readText(payload.productId),
    autoRenewStatus: readOptionalInt(payload.autoRenewStatus) ?? 1,
    expirationIntent: readOptionalInt(payload.expirationIntent),
    gracePeriodExpiresDateMs: readOptionalMillis(
      payload.gracePeriodExpiresDate,
    ),
    isInBillingRetryPeriod: payload.isInBillingRetryPeriod === true,
    environment: readText(payload.environment),
  };
}

/**
 * Decodes a base64url JSON segment safely.
 * @param {string} segment Encoded segment.
 * @param {string} label Field name for error context.
 * @return {Record<string, unknown>} Decoded JSON object.
 */
function decodeBase64UrlJson(
  segment: string,
  label: string,
): Record<string, unknown> {
  try {
    const raw = decodeBase64UrlBuffer(segment).toString("utf8");
    const parsed: unknown = JSON.parse(raw);
    if (!isRecord(parsed)) {
      throw new Error("not_object");
    }
    return parsed;
  } catch {
    throw new HttpsError(
      "invalid-argument",
      `Apple JWS ${label} çözümlenemedi.`,
    );
  }
}

/**
 * Decodes a base64url string into a Buffer.
 * @param {string} value Base64url string.
 * @return {Buffer} Decoded bytes.
 */
function decodeBase64UrlBuffer(value: string): Buffer {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padding = (4 - (normalized.length % 4)) % 4;
  return Buffer.from(normalized + "=".repeat(padding), "base64");
}

/**
 * Reads a trimmed string.
 * @param {unknown} value Raw value.
 * @return {string} Trimmed text.
 */
function readText(value: unknown): string {
  return value == null ? "" : String(value).trim();
}

/**
 * Reads an optional trimmed string.
 * @param {unknown} value Raw value.
 * @return {string|null} Trimmed string or null.
 */
function readOptionalString(value: unknown): string | null {
  const normalized = readText(value);
  return normalized.length > 0 ? normalized : null;
}

/**
 * Reads an optional epoch millisecond timestamp.
 * @param {unknown} value Raw value.
 * @return {number|null} Milliseconds or null.
 */
function readOptionalMillis(value: unknown): number | null {
  if (value == null) {
    return null;
  }
  const num = Number(value);
  return Number.isFinite(num) && num > 0 ? Math.trunc(num) : null;
}

/**
 * Reads an optional integer.
 * @param {unknown} value Raw value.
 * @return {number|null} Integer or null.
 */
function readOptionalInt(value: unknown): number | null {
  if (value == null) {
    return null;
  }
  const num = Number(value);
  return Number.isInteger(num) ? num : null;
}

/**
 * Checks whether a value is a plain object.
 * @param {unknown} value Raw value.
 * @return {boolean} True for plain records.
 */
function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
