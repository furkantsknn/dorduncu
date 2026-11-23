/* eslint-disable max-len */
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import {defineString} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {writeAuditLogInTransaction} from "../audit/writeAuditLog";
import {
  DEFAULT_APPLE_BUNDLE_ID,
  verifyAppleSignedTransaction,
} from "../commercial/appleAppStoreVerification";
import {
  reserveCommercialOperation,
  transitionCommercialOperation,
} from "../commercial/commercialLedger";
import {firestore} from "../config/firebaseAdmin";
import {
  writeUserNotificationInTransaction,
} from "../notifications/writeUserNotification";

const appleBundleId = defineString("APPLE_BUNDLE_ID", {
  default: DEFAULT_APPLE_BUNDLE_ID,
});

interface FulfillApplePurchaseRequest {
  appleProductId?: unknown;
  signedTransactionInfo?: unknown;
  transactionId?: unknown;
}

type ApplePurchaseKind = "plus_subscription" | "badge_non_consumable";

interface ResolvedAppleCatalog {
  kind: ApplePurchaseKind;
  collection: "plus_products" | "badge_products";
  productId: string;
  appleProductId: string;
  priceKurus: number;
  data: Record<string, unknown>;
}

/**
 * Verifies a StoreKit 2 JWS transaction and idempotently fulfills a Plus
 * subscription or non-consumable badge purchase on iOS.
 */
export const fulfillApplePurchase = onCall(
  {
    region: "europe-west1",
    enforceAppCheck: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Satın alma doğrulaması için giriş yapmalısınız.",
      );
    }

    const uid = request.auth.uid;
    const data = (request.data ?? {}) as FulfillApplePurchaseRequest;

    const requestedProductId = requireString(
      data.appleProductId,
      "appleProductId",
      300,
    );
    const signedTransactionInfo = requireString(
      data.signedTransactionInfo,
      "signedTransactionInfo",
      20000,
    );

    const resolved = await resolveCatalogByAppleProductId(requestedProductId);

    const verified = verifyAppleSignedTransaction(signedTransactionInfo, {
      expectedBundleId: appleBundleId.value(),
      expectedProductId: resolved.appleProductId,
      expectedUid: uid,
      requireActiveSubscription: resolved.kind === "plus_subscription",
    });

    const requestedTxId = String(data.transactionId ?? "").trim();
    if (requestedTxId && requestedTxId !== verified.transactionId) {
      throw new HttpsError(
        "invalid-argument",
        "Apple işlem kimliği imzalı veri ile eşleşmiyor.",
      );
    }

    if (resolved.kind === "plus_subscription") {
      return fulfillApplePlusSubscription(uid, resolved, verified);
    }

    return fulfillAppleBadgePurchase(uid, resolved, verified);
  },
);

/**
 * Fulfills one verified Apple Plus auto-renewable subscription transaction.
 * @param {string} uid Authenticated Firebase user uid.
 * @param {ResolvedAppleCatalog} catalog Resolved catalog product.
 * @param {object} verified Verified transaction.
 * @return {Promise<Record<string, unknown>>} Fulfillment response.
 */
async function fulfillApplePlusSubscription(
  uid: string,
  catalog: ResolvedAppleCatalog,
  verified: ReturnType<typeof verifyAppleSignedTransaction>,
): Promise<Record<string, unknown>> {
  const verifiedExpiry = new Date(verified.expiresDateMs!);
  const idempotencyKey =
    `${verified.originalTransactionId}:${verified.transactionId}`;
  const isSandbox = verified.environment === "Sandbox";

  return firestore.runTransaction(async (transaction) => {
    const productReference = firestore
      .collection("plus_products")
      .doc(catalog.productId);
    const userReference = firestore.collection("users").doc(uid);
    const registryReference = firestore
      .collection("apple_purchase_transactions")
      .doc(verified.originalTransactionId);

    const [productSnapshot, userSnapshot, registrySnapshot] = await Promise.all(
      [
        transaction.get(productReference),
        transaction.get(userReference),
        transaction.get(registryReference),
      ],
    );

    if (!productSnapshot.exists) {
      throw new HttpsError("not-found", "Plus ürünü bulunamadı.");
    }

    const currentAppleId = String(
      productSnapshot.data()?.appleProductId ?? "",
    ).trim();
    if (currentAppleId !== catalog.appleProductId) {
      throw new HttpsError(
        "failed-precondition",
        "Plus Apple ürün eşlemesi değişti.",
      );
    }

    assertAppleRegistryOwnership(
      registrySnapshot.data() ?? null,
      uid,
      catalog.productId,
      "plus_subscription",
    );

    const reservation = await reserveCommercialOperation(
      firestore,
      transaction,
      {
        userUid: uid,
        type: "digital_plus_purchase",
        provider: "apple_app_store",
        idempotencyScope: "apple_app_store_subscription_transaction",
        idempotencyKey,
        providerTransactionId: verified.transactionId,
        providerReference: verified.originalTransactionId,
        money: {
          currency: verified.currency ?? "TRY",
          grossAmountMinor: catalog.priceKurus,
          feeAmountMinor: 0,
          netAmountMinor: catalog.priceKurus,
        },
        relatedProductId: catalog.productId,
        metadata: {
          appleProductId: verified.productId,
          originalTransactionId: verified.originalTransactionId,
          transactionId: verified.transactionId,
          environment: verified.environment,
          testPurchase: isSandbox,
          amountSource: "catalog_nominal",
        },
      },
      {
        actorUid: uid,
        source: "fulfillApplePurchase",
      },
    );

    if (!reservation.created) {
      return {
        success: true,
        idempotentReplay: true,
        operationId: reservation.operationId,
        productId: catalog.productId,
        kind: "plus_subscription",
        plusExpiresAt: verifiedExpiry.toISOString(),
        acknowledged: true,
      };
    }

    const productData = productSnapshot.data() ?? {};
    const userData = userSnapshot.data() ?? {};
    const title = String(productData.title ?? "").trim() || "Dört. Plus";
    const plan = String(productData.plan ?? "").trim() || catalog.productId;

    const currentExpiry = readTimestampDate(userData.plusExpiresAt);
    const finalExpiry = currentExpiry != null &&
      currentExpiry.getTime() > verifiedExpiry.getTime() ?
      currentExpiry :
      verifiedExpiry;

    const purchaseReference = userReference
      .collection("plus_purchases")
      .doc(reservation.operationId);
    const saleReference = firestore
      .collection("market_sales")
      .doc(reservation.operationId);

    transaction.set(
      userReference,
      {
        plus: true,
        isPlus: true,
        plusPlan: plan,
        plusProvider: "apple_app_store",
        plusAppleOriginalTransactionId: verified.originalTransactionId,
        plusAppleProductId: verified.productId,
        plusSubscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
        plusSubscriptionExpiresAt: Timestamp.fromDate(verifiedExpiry),
        plusExpiresAt: Timestamp.fromDate(finalExpiry),
        plusUpdatedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    transaction.create(purchaseReference, {
      purchaseId: reservation.operationId,
      commercialOperationId: reservation.operationId,
      uid,
      productId: catalog.productId,
      appleProductId: verified.productId,
      appleOriginalTransactionId: verified.originalTransactionId,
      providerOrderId: verified.transactionId,
      productType: "plus_subscription",
      title,
      plan,
      priceKurus: catalog.priceKurus,
      paymentMethod: "apple_app_store",
      status: "completed",
      subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
      testPurchase: isSandbox,
      expiresAt: Timestamp.fromDate(finalExpiry),
      purchasedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    transaction.set(
      registryReference,
      {
        originalTransactionId: verified.originalTransactionId,
        uid,
        productId: catalog.productId,
        appleProductId: verified.productId,
        kind: "plus_subscription",
        latestOperationId: reservation.operationId,
        latestTransactionId: verified.transactionId,
        latestExpiryAt: Timestamp.fromDate(finalExpiry),
        environment: verified.environment,
        active: true,
        createdAt: registrySnapshot.exists ?
          registrySnapshot.data()?.createdAt ?? FieldValue.serverTimestamp() :
          FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    transaction.create(saleReference, {
      saleId: reservation.operationId,
      commercialOperationId: reservation.operationId,
      uid,
      productId: catalog.productId,
      appleProductId: verified.productId,
      appleOriginalTransactionId: verified.originalTransactionId,
      productType: "plus_subscription",
      title,
      plan,
      amountKurus: catalog.priceKurus,
      amountSource: "catalog_nominal",
      paymentMethod: "apple_app_store",
      status: "completed",
      testPurchase: isSandbox,
      expiresAt: Timestamp.fromDate(finalExpiry),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    transitionCommercialOperation(
      firestore,
      transaction,
      reservation.operationId,
      "paid",
      {
        actorUid: uid,
        source: "fulfillApplePurchase",
      },
      {
        productId: catalog.productId,
        appleProductId: verified.productId,
        originalTransactionId: verified.originalTransactionId,
        entitlement: "plus",
        expiresAt: finalExpiry.toISOString(),
      },
    );

    writeUserNotificationInTransaction(firestore, transaction, {
      userId: uid,
      type: "plus_activated",
      title: "Dört. Plus aktif",
      message:
        "App Store aboneliğin doğrulandı ve Plus hesabında aktif edildi.",
      route: "profile",
      data: {
        productId: catalog.productId,
        operationId: reservation.operationId,
        expiresAt: finalExpiry.toISOString(),
      },
    });

    writeAuditLogInTransaction(firestore, transaction, {
      action: "apple_plus_activated",
      performedBy: "system:apple_app_store",
      targetUid: uid,
      metadata: {
        productId: catalog.productId,
        appleProductId: verified.productId,
        originalTransactionId: verified.originalTransactionId,
        transactionId: verified.transactionId,
        operationId: reservation.operationId,
        expiresAt: finalExpiry.toISOString(),
        environment: verified.environment,
      },
    });

    return {
      success: true,
      idempotentReplay: false,
      operationId: reservation.operationId,
      productId: catalog.productId,
      kind: "plus_subscription",
      plusExpiresAt: finalExpiry.toISOString(),
      acknowledged: true,
    };
  });
}

/**
 * Fulfills one verified Apple non-consumable badge purchase transaction.
 * @param {string} uid Authenticated Firebase user uid.
 * @param {ResolvedAppleCatalog} catalog Resolved catalog product.
 * @param {object} verified Verified transaction.
 * @return {Promise<Record<string, unknown>>} Fulfillment response.
 */
async function fulfillAppleBadgePurchase(
  uid: string,
  catalog: ResolvedAppleCatalog,
  verified: ReturnType<typeof verifyAppleSignedTransaction>,
): Promise<Record<string, unknown>> {
  const isSandbox = verified.environment === "Sandbox";

  return firestore.runTransaction(async (transaction) => {
    const productReference = firestore
      .collection("badge_products")
      .doc(catalog.productId);
    const userReference = firestore.collection("users").doc(uid);
    const ownedBadgeReference = userReference
      .collection("owned_badges")
      .doc(catalog.productId);
    const registryReference = firestore
      .collection("apple_purchase_transactions")
      .doc(verified.originalTransactionId);

    const [productSnapshot, ownedBadgeSnapshot, registrySnapshot] =
      await Promise.all([
        transaction.get(productReference),
        transaction.get(ownedBadgeReference),
        transaction.get(registryReference),
      ]);

    if (!productSnapshot.exists) {
      throw new HttpsError("not-found", "Rozet ürünü bulunamadı.");
    }

    const currentAppleId = String(
      productSnapshot.data()?.appleProductId ?? "",
    ).trim();
    if (currentAppleId !== catalog.appleProductId) {
      throw new HttpsError(
        "failed-precondition",
        "Rozet Apple ürün eşlemesi değişti.",
      );
    }

    assertAppleRegistryOwnership(
      registrySnapshot.data() ?? null,
      uid,
      catalog.productId,
      "badge_non_consumable",
    );

    if (ownedBadgeSnapshot.data()?.adminBlocked === true) {
      throw new HttpsError(
        "permission-denied",
        "This badge is blocked by an administrator.",
      );
    }

    const reservation = await reserveCommercialOperation(
      firestore,
      transaction,
      {
        userUid: uid,
        type: "digital_badge_purchase",
        provider: "apple_app_store",
        idempotencyScope: "apple_app_store_badge_transaction",
        idempotencyKey: verified.originalTransactionId,
        providerTransactionId: verified.transactionId,
        providerReference: verified.originalTransactionId,
        money: {
          currency: verified.currency ?? "TRY",
          grossAmountMinor: catalog.priceKurus,
          feeAmountMinor: 0,
          netAmountMinor: catalog.priceKurus,
        },
        relatedProductId: catalog.productId,
        metadata: {
          appleProductId: verified.productId,
          originalTransactionId: verified.originalTransactionId,
          transactionId: verified.transactionId,
          environment: verified.environment,
          testPurchase: isSandbox,
          amountSource: "catalog_nominal",
        },
      },
      {
        actorUid: uid,
        source: "fulfillApplePurchase",
      },
    );

    if (!reservation.created) {
      if (registrySnapshot.data()?.active === false) {
        throw new HttpsError(
          "failed-precondition",
          "Bu App Store satın alması iade edilmiş.",
        );
      }
      return {
        success: true,
        idempotentReplay: true,
        operationId: reservation.operationId,
        productId: catalog.productId,
        kind: "badge_non_consumable",
        acknowledged: true,
        recipientUid: uid,
      };
    }

    const productData = productSnapshot.data() ?? {};
    const title = String(productData.title ?? "").trim() || "Oyun Rozeti";
    const gameId = String(productData.gameId ?? "").trim();
    const gameName = String(productData.gameName ?? "").trim();
    const emoji = String(productData.emoji ?? "").trim() || "🏅";
    const imageUrl = String(productData.imageUrl ?? "").trim();

    if (ownedBadgeSnapshot.exists) {
      transaction.set(
        ownedBadgeReference,
        {
          appleEntitled: true,
          appleProductId: verified.productId,
          appleOriginalTransactionId: verified.originalTransactionId,
          appleTransactionId: verified.transactionId,
          appleOperationId: reservation.operationId,
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    } else {
      transaction.create(ownedBadgeReference, {
        badgeId: catalog.productId,
        productId: catalog.productId,
        title,
        gameId,
        gameName,
        emoji,
        imageUrl,
        source: "apple_app_store_purchase",
        appleEntitled: true,
        appleProductId: verified.productId,
        appleOriginalTransactionId: verified.originalTransactionId,
        appleTransactionId: verified.transactionId,
        appleOperationId: reservation.operationId,
        priceKurus: catalog.priceKurus,
        purchasedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    transaction.set(
      registryReference,
      {
        originalTransactionId: verified.originalTransactionId,
        uid,
        recipientUid: uid,
        productId: catalog.productId,
        appleProductId: verified.productId,
        kind: "badge_non_consumable",
        latestOperationId: reservation.operationId,
        latestTransactionId: verified.transactionId,
        environment: verified.environment,
        active: true,
        createdAt: registrySnapshot.exists ?
          registrySnapshot.data()?.createdAt ?? FieldValue.serverTimestamp() :
          FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    const saleReference = firestore
      .collection("market_sales")
      .doc(reservation.operationId);
    transaction.create(saleReference, {
      saleId: reservation.operationId,
      commercialOperationId: reservation.operationId,
      uid,
      productId: catalog.productId,
      appleProductId: verified.productId,
      appleOriginalTransactionId: verified.originalTransactionId,
      productType: "badge_non_consumable",
      title,
      amountKurus: catalog.priceKurus,
      amountSource: "catalog_nominal",
      paymentMethod: "apple_app_store",
      status: "completed",
      testPurchase: isSandbox,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    transitionCommercialOperation(
      firestore,
      transaction,
      reservation.operationId,
      "paid",
      {
        actorUid: uid,
        source: "fulfillApplePurchase",
      },
      {
        productId: catalog.productId,
        appleProductId: verified.productId,
        originalTransactionId: verified.originalTransactionId,
        entitlement: "badge",
      },
    );

    writeUserNotificationInTransaction(firestore, transaction, {
      userId: uid,
      type: "badge_purchased",
      title: "Rozet hesabına eklendi",
      message: `${title} App Store satın alman doğrulandı.`,
      route: "profile",
      data: {
        productId: catalog.productId,
        operationId: reservation.operationId,
      },
    });

    writeAuditLogInTransaction(firestore, transaction, {
      action: "apple_badge_activated",
      performedBy: "system:apple_app_store",
      targetUid: uid,
      metadata: {
        productId: catalog.productId,
        appleProductId: verified.productId,
        originalTransactionId: verified.originalTransactionId,
        transactionId: verified.transactionId,
        operationId: reservation.operationId,
        environment: verified.environment,
      },
    });

    return {
      success: true,
      idempotentReplay: false,
      operationId: reservation.operationId,
      productId: catalog.productId,
      kind: "badge_non_consumable",
      acknowledged: true,
      recipientUid: uid,
    };
  });
}

/**
 * Resolves a catalog product across plus_products and badge_products by its
 * explicit `appleProductId` mapping.
 * @param {string} appleProductId App Store product identifier.
 * @return {Promise<ResolvedAppleCatalog>} Matched catalog product.
 */
async function resolveCatalogByAppleProductId(
  appleProductId: string,
): Promise<ResolvedAppleCatalog> {
  const [plusSnapshot, badgeSnapshot] = await Promise.all([
    firestore
      .collection("plus_products")
      .where("appleProductId", "==", appleProductId)
      .limit(2)
      .get(),
    firestore
      .collection("badge_products")
      .where("appleProductId", "==", appleProductId)
      .limit(2)
      .get(),
  ]);

  const totalMatches = plusSnapshot.size + badgeSnapshot.size;
  if (totalMatches === 0) {
    throw new HttpsError(
      "not-found",
      "Bu Apple ürün kimliği katalogda tanımlı değil.",
    );
  }
  if (totalMatches > 1) {
    throw new HttpsError(
      "failed-precondition",
      "Apple ürün kimliği birden fazla katalog kaydına eşlenmiş.",
    );
  }

  if (!plusSnapshot.empty) {
    const doc = plusSnapshot.docs[0];
    const data = doc.data() ?? {};
    return {
      kind: "plus_subscription",
      collection: "plus_products",
      productId: doc.id,
      appleProductId,
      priceKurus: readPositiveInt(data.priceKurus),
      data,
    };
  }

  const doc = badgeSnapshot.docs[0];
  const data = doc.data() ?? {};
  return {
    kind: "badge_non_consumable",
    collection: "badge_products",
    productId: doc.id,
    appleProductId,
    priceKurus: readPositiveInt(data.priceKurus),
    data,
  };
}

/**
 * Ensures an Apple originalTransactionId cannot be claimed by another user.
 * @param {Record<string, unknown>|null} existing Existing registry record.
 * @param {string} uid Authenticated user uid.
 * @param {string} productId Internal catalog product id.
 * @param {ApplePurchaseKind} kind Expected product kind.
 */
function assertAppleRegistryOwnership(
  existing: Record<string, unknown> | null,
  uid: string,
  productId: string,
  kind: ApplePurchaseKind,
): void {
  if (!existing) {
    return;
  }

  const ownerUid = String(existing.uid ?? "").trim();
  if (ownerUid && ownerUid !== uid) {
    throw new HttpsError(
      "permission-denied",
      "Bu App Store satın alması başka bir hesaba tanımlı.",
    );
  }

  const existingKind = String(existing.kind ?? "").trim();
  if (existingKind && existingKind !== kind) {
    throw new HttpsError(
      "failed-precondition",
      "Apple işlem türü mevcut kayıt ile uyuşmuyor.",
    );
  }

  const existingProductId = String(existing.productId ?? "").trim();
  if (existingProductId && existingProductId !== productId) {
    throw new HttpsError(
      "failed-precondition",
      "Apple işlem ürünü mevcut kayıt ile uyuşmuyor.",
    );
  }
}

/**
 * Reads a required trimmed string within length bounds.
 * @param {unknown} value Raw input.
 * @param {string} field Field name.
 * @param {number} maxLength Maximum allowed length.
 * @return {string} Validated string.
 */
function requireString(
  value: unknown,
  field: string,
  maxLength: number,
): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} metin olmalıdır.`);
  }
  const trimmed = value.trim();
  if (!trimmed || trimmed.length > maxLength) {
    throw new HttpsError("invalid-argument", `${field} geçersiz.`);
  }
  return trimmed;
}

/**
 * Reads a positive integer kurus price.
 * @param {unknown} value Raw value.
 * @return {number} Non-negative integer.
 */
function readPositiveInt(value: unknown): number {
  const num = Number(value ?? 0);
  return Number.isFinite(num) && num > 0 ? Math.trunc(num) : 0;
}

/**
 * Reads a Firestore Timestamp or Date safely.
 * @param {unknown} value Raw field.
 * @return {Date|null} Parsed date or null.
 */
function readTimestampDate(value: unknown): Date | null {
  if (value instanceof Timestamp) {
    return value.toDate();
  }
  if (value instanceof Date) {
    return value;
  }
  return null;
}
