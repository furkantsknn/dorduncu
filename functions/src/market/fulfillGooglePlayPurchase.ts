import {
  FieldValue,
  Timestamp,
} from "firebase-admin/firestore";
import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";

import {firestore} from "../config/firebaseAdmin";
import {
  writeAuditLogInTransaction,
} from "../audit/writeAuditLog";
import {
  writeUserNotificationInTransaction,
} from "../notifications/writeUserNotification";
import {
  reserveCommercialOperation,
  transitionCommercialOperation,
} from "../commercial/commercialLedger";
import {
  acknowledgeGooglePlayProduct,
  acknowledgeGooglePlaySubscription,
  verifyGooglePlayProduct,
  verifyGooglePlaySubscription,
} from "../commercial/googlePlayVerification";

interface FulfillGooglePlayPurchaseRequest {
  googlePlayProductId?: unknown;
  purchaseToken?: unknown;
  recipientUid?: unknown;
}

type DigitalPurchaseKind =
  "plus_subscription" |
  "badge_non_consumable";

interface ResolvedCatalogProduct {
  kind: DigitalPurchaseKind;
  collection:
    "plus_products" |
    "badge_products";
  product: CatalogProduct;
}

interface CatalogProduct {
  productId: string;
  googlePlayProductId: string;
  googlePlayBasePlanId: string;
  priceKurus: number;
  data: Record<string, unknown>;
}

/**
 * Verifies and fulfills one Google Play digital purchase.
 */
export const fulfillGooglePlayPurchase = onCall(
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
    const data =
      request.data as FulfillGooglePlayPurchaseRequest;

    const googlePlayProductId = requireString(
      data.googlePlayProductId,
      "googlePlayProductId",
      300,
    );
    const purchaseToken = requireString(
      data.purchaseToken,
      "purchaseToken",
      5000,
    );
    const requestedRecipient = String(
      data.recipientUid ?? "",
    ).trim();
    const recipientUid = requestedRecipient || uid;

    const resolved = await resolveCatalogByGooglePlayId(
      googlePlayProductId,
    );

    if (
      resolved.kind === "plus_subscription" &&
      recipientUid !== uid
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Plus aboneliği hediye edilemez.",
      );
    }

    if (resolved.kind === "plus_subscription") {
      return fulfillPlusPurchase(
        uid,
        resolved.product.productId,
        purchaseToken,
      );
    }

    return fulfillBadgePurchase(
      uid,
      resolved.product.productId,
      purchaseToken,
      recipientUid,
    );
  },
);

/**
 * Verifies and fulfills one Plus subscription.
 *
 * @param {string} uid User uid.
 * @param {string} productId Internal product id.
 * @param {string} purchaseToken Raw Google Play token.
 * @return {Promise<Record<string, unknown>>} Fulfillment result.
 */
async function fulfillPlusPurchase(
  uid: string,
  productId: string,
  purchaseToken: string,
): Promise<Record<string, unknown>> {
  const catalog = await readCatalogProduct(
    "plus_products",
    productId,
  );

  if (!catalog.googlePlayBasePlanId) {
    throw new HttpsError(
      "failed-precondition",
      "Plus base plan eşlemesi yapılmamış.",
    );
  }

  const verified =
    await verifyGooglePlaySubscription(
      catalog.googlePlayProductId,
      purchaseToken,
      catalog.googlePlayBasePlanId,
    );

  const idempotencyKey =
    `${purchaseToken}:${verified.expiryTime.toISOString()}`;

  const result = await firestore.runTransaction(
    async (transaction) => {
      const productReference = firestore
        .collection("plus_products")
        .doc(productId);
      const userReference = firestore
        .collection("users")
        .doc(uid);
      const tokenReference = firestore
        .collection("google_play_purchase_tokens")
        .doc(verified.purchaseTokenHash);

      const [
        productSnapshot,
        userSnapshot,
        tokenSnapshot,
      ] = await Promise.all([
        transaction.get(productReference),
        transaction.get(userReference),
        transaction.get(tokenReference),
      ]);

      if (!productSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "Plus ürünü bulunamadı.",
        );
      }

      const currentProduct =
        normalizeCatalogProduct(
          productId,
          productSnapshot.data() ?? {},
        );

      assertSameGooglePlayProduct(
        catalog,
        currentProduct,
      );

      assertTokenRegistryOwnership(
        tokenSnapshot.data() ?? null,
        uid,
        productId,
        "plus_subscription",
      );

      const reservation =
        await reserveCommercialOperation(
          firestore,
          transaction,
          {
            userUid: uid,
            type: "digital_plus_purchase",
            provider: "google_play",
            idempotencyScope:
              "google_play_subscription_period",
            idempotencyKey,
            providerTransactionId:
              verified.orderId,
            providerReference:
              verified.purchaseTokenHash,
            money: {
              currency: "TRY",
              grossAmountMinor:
                currentProduct.priceKurus,
              feeAmountMinor: 0,
              netAmountMinor:
                currentProduct.priceKurus,
            },
            relatedProductId: productId,
            metadata: {
              googlePlayProductId:
                verified.googlePlayProductId,
              purchaseTokenHash:
                verified.purchaseTokenHash,
              subscriptionState:
                verified.subscriptionState,
              testPurchase:
                verified.testPurchase,
              amountSource:
                "catalog_nominal",
            },
          },
          {
            actorUid: uid,
            source: "fulfillGooglePlayPurchase",
          },
        );

      if (!reservation.created) {
        return {
          success: true,
          idempotentReplay: true,
          operationId:
            reservation.operationId,
          productId,
          kind: "plus_subscription",
          plusExpiresAt:
            verified.expiryTime.toISOString(),
          acknowledged:
            verified.acknowledged,
        };
      }

      const productData =
        productSnapshot.data() ?? {};
      const userData =
        userSnapshot.data() ?? {};

      const title =
        String(productData.title ?? "").trim() ||
        "Dört. Plus";
      const plan =
        String(productData.plan ?? "").trim() ||
        productId;

      const currentExpiry =
        readTimestampDate(userData.plusExpiresAt);
      const verifiedExpiry =
        verified.expiryTime;

      const finalExpiry =
        currentExpiry != null &&
        currentExpiry.getTime() >
          verifiedExpiry.getTime() ?
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
          plusGooglePlayTokenHash:
            verified.purchaseTokenHash,
          plusGooglePlayProductId:
            verified.googlePlayProductId,
          plusSubscriptionState:
            verified.subscriptionState,
          plusExpiresAt:
            Timestamp.fromDate(finalExpiry),
          plusUpdatedAt:
            FieldValue.serverTimestamp(),
          updatedAt:
            FieldValue.serverTimestamp(),
        },
        {
          merge: true,
        },
      );

      transaction.create(
        purchaseReference,
        {
          purchaseId:
            reservation.operationId,
          commercialOperationId:
            reservation.operationId,
          uid,
          productId,
          googlePlayProductId:
            verified.googlePlayProductId,
          purchaseTokenHash:
            verified.purchaseTokenHash,
          providerOrderId:
            verified.orderId,
          productType:
            "plus_subscription",
          title,
          plan,
          priceKurus:
            currentProduct.priceKurus,
          paymentMethod:
            "google_play",
          status: "completed",
          subscriptionState:
            verified.subscriptionState,
          testPurchase:
            verified.testPurchase,
          expiresAt:
            Timestamp.fromDate(finalExpiry),
          purchasedAt:
            FieldValue.serverTimestamp(),
          createdAt:
            FieldValue.serverTimestamp(),
          updatedAt:
            FieldValue.serverTimestamp(),
        },
      );

      transaction.set(
        tokenReference,
        {
          purchaseTokenHash:
            verified.purchaseTokenHash,
          uid,
          productId,
          googlePlayProductId:
            verified.googlePlayProductId,
          kind: "plus_subscription",
          latestOperationId:
            reservation.operationId,
          latestOrderId:
            verified.orderId,
          latestExpiryAt:
            Timestamp.fromDate(finalExpiry),
          active: true,
          createdAt:
            tokenSnapshot.exists ?
              tokenSnapshot.data()?.createdAt ??
                FieldValue.serverTimestamp() :
              FieldValue.serverTimestamp(),
          updatedAt:
            FieldValue.serverTimestamp(),
        },
        {
          merge: true,
        },
      );

      transaction.create(
        saleReference,
        {
          saleId:
            reservation.operationId,
          commercialOperationId:
            reservation.operationId,
          uid,
          productId,
          googlePlayProductId:
            verified.googlePlayProductId,
          productType:
            "plus_subscription",
          title,
          plan,
          amountKurus:
            currentProduct.priceKurus,
          amountSource:
            "catalog_nominal",
          paymentMethod:
            "google_play",
          status:
            "completed",
          testPurchase:
            verified.testPurchase,
          expiresAt:
            Timestamp.fromDate(finalExpiry),
          createdAt:
            FieldValue.serverTimestamp(),
          updatedAt:
            FieldValue.serverTimestamp(),
        },
      );

      transitionCommercialOperation(
        firestore,
        transaction,
        reservation.operationId,
        "paid",
        {
          actorUid: uid,
          source:
            "fulfillGooglePlayPurchase",
        },
        {
          productId,
          googlePlayProductId:
            verified.googlePlayProductId,
          entitlement:
            "plus",
          expiresAt:
            finalExpiry.toISOString(),
        },
      );

      writeUserNotificationInTransaction(
        firestore,
        transaction,
        {
          userId: uid,
          type: "plus_activated",
          title: "Dört. Plus aktif",
          message:
            "Google Play aboneliğin doğrulandı ve Plus hesabında aktif edildi.",
          route: "profile",
          data: {
            productId,
            operationId:
              reservation.operationId,
            expiresAt:
              finalExpiry.toISOString(),
          },
        },
      );

      writeAuditLogInTransaction(
        firestore,
        transaction,
        {
          action:
            "google_play_plus_activated",
          performedBy:
            "system:google_play",
          targetUid: uid,
          metadata: {
            productId,
            googlePlayProductId:
              verified.googlePlayProductId,
            operationId:
              reservation.operationId,
            subscriptionState:
              verified.subscriptionState,
            expiresAt:
              finalExpiry.toISOString(),
          },
        },
      );

      return {
        success: true,
        idempotentReplay: false,
        operationId:
          reservation.operationId,
        productId,
        kind: "plus_subscription",
        plusExpiresAt:
          finalExpiry.toISOString(),
        acknowledged:
          verified.acknowledged,
      };
    },
  );

  if (!verified.acknowledged) {
    await acknowledgeGooglePlaySubscription(
      verified.googlePlayProductId,
      purchaseToken,
    );
  }

  return {
    ...result,
    acknowledged: true,
  };
}

/**
 * Verifies and fulfills one Badge non-consumable purchase.
 *
 * @param {string} uid Buyer uid.
 * @param {string} productId Internal badge id.
 * @param {string} purchaseToken Raw Google Play token.
 * @param {string} recipientUid Badge recipient.
 * Same as the buyer for a normal purchase.
 * @return {Promise<Record<string, unknown>>} Fulfillment result.
 */
async function fulfillBadgePurchase(
  uid: string,
  productId: string,
  purchaseToken: string,
  recipientUid: string,
): Promise<Record<string, unknown>> {
  const catalog = await readCatalogProduct(
    "badge_products",
    productId,
  );

  const verified =
    await verifyGooglePlayProduct(
      catalog.googlePlayProductId,
      purchaseToken,
    );

  const result = await firestore.runTransaction(
    async (transaction) => {
      const productReference = firestore
        .collection("badge_products")
        .doc(productId);
      const userReference = firestore
        .collection("users")
        .doc(uid);
      const tokenReference = firestore
        .collection("google_play_purchase_tokens")
        .doc(verified.purchaseTokenHash);
      const recipientReference = firestore
        .collection("users")
        .doc(recipientUid);
      const ownedBadgeReference = recipientReference
        .collection("owned_badges")
        .doc(productId);
      const buyerBlockedRecipient = userReference
        .collection("blockedUsers")
        .doc(recipientUid);
      const recipientBlockedBuyer = recipientReference
        .collection("blockedUsers")
        .doc(uid);

      const [
        productSnapshot,
        ownedBadgeSnapshot,
        tokenSnapshot,
        recipientSnapshot,
        buyerBlockedRecipientSnapshot,
        recipientBlockedBuyerSnapshot,
      ] = await Promise.all([
        transaction.get(productReference),
        transaction.get(ownedBadgeReference),
        transaction.get(tokenReference),
        transaction.get(recipientReference),
        transaction.get(buyerBlockedRecipient),
        transaction.get(recipientBlockedBuyer),
      ]);

      if (!recipientSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "Hediye alıcısı bulunamadı.",
        );
      }

      if (
        recipientUid !== uid &&
        (
          buyerBlockedRecipientSnapshot.exists ||
          recipientBlockedBuyerSnapshot.exists
        )
      ) {
        throw new HttpsError(
          "permission-denied",
          "Engellenmiş kullanıcıya rozet hediye edilemez.",
        );
      }

      if (!productSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "Rozet ürünü bulunamadı.",
        );
      }

      const currentProduct =
        normalizeCatalogProduct(
          productId,
          productSnapshot.data() ?? {},
        );

      assertSameGooglePlayProduct(
        catalog,
        currentProduct,
      );

      assertTokenRegistryOwnership(
        tokenSnapshot.data() ?? null,
        uid,
        productId,
        "badge_non_consumable",
      );

      const reservation =
        await reserveCommercialOperation(
          firestore,
          transaction,
          {
            userUid: uid,
            type:
              "digital_badge_purchase",
            provider: "google_play",
            idempotencyScope:
              "google_play_product_token",
            idempotencyKey:
              purchaseToken,
            providerTransactionId:
              verified.orderId,
            providerReference:
              verified.purchaseTokenHash,
            money: {
              currency: "TRY",
              grossAmountMinor:
                currentProduct.priceKurus,
              feeAmountMinor: 0,
              netAmountMinor:
                currentProduct.priceKurus,
            },
            relatedProductId: productId,
            metadata: {
              googlePlayProductId:
                verified.googlePlayProductId,
              purchaseTokenHash:
                verified.purchaseTokenHash,
              testPurchase:
                verified.testPurchase,
              amountSource:
                "catalog_nominal",
            },
          },
          {
            actorUid: uid,
            source:
              "fulfillGooglePlayPurchase",
          },
        );

      if (!reservation.created) {
        return {
          success: true,
          idempotentReplay: true,
          operationId:
            reservation.operationId,
          productId,
          kind:
            "badge_non_consumable",
          acknowledged:
            verified.acknowledged,
          recipientUid: String(
            tokenSnapshot.data()?.recipientUid ?? uid,
          ),
        };
      }

      const productData =
        productSnapshot.data() ?? {};

      const title =
        String(productData.title ?? "").trim() ||
        "Oyun Rozeti";
      const gameId =
        String(productData.gameId ?? "").trim();
      const gameName =
        String(productData.gameName ?? "").trim();
      const emoji =
        String(productData.emoji ?? "").trim() ||
        "🏅";
      const imageUrl =
        String(productData.imageUrl ?? "").trim();

      if (ownedBadgeSnapshot.exists) {
        transaction.set(
          ownedBadgeReference,
          {
            googlePlayEntitled: true,
            googlePlayProductId:
              verified.googlePlayProductId,
            googlePlayOperationId:
              reservation.operationId,
            googlePlayPurchaseTokenHash:
              verified.purchaseTokenHash,
            updatedAt:
              FieldValue.serverTimestamp(),
          },
          {
            merge: true,
          },
        );
      } else {
        transaction.create(
          ownedBadgeReference,
          {
            badgeId: productId,
            productId,
            commercialOperationId:
              reservation.operationId,
            googlePlayOperationId:
              reservation.operationId,
            googlePlayProductId:
              verified.googlePlayProductId,
            googlePlayPurchaseTokenHash:
              verified.purchaseTokenHash,
            googlePlayEntitled: true,
            gameId,
            gameName,
            title,
            emoji,
            imageUrl,
            priceKurus:
              currentProduct.priceKurus,
            paymentMethod:
              "google_play",
            equipped: true,
            source: recipientUid === uid ?
              "google_play_purchase" :
              "google_play_gift",
            giftedByUid: recipientUid === uid ? "" : uid,
            purchasedAt:
              FieldValue.serverTimestamp(),
            createdAt:
              FieldValue.serverTimestamp(),
            updatedAt:
              FieldValue.serverTimestamp(),
          },
        );
      }

      const saleReference = firestore
        .collection("market_sales")
        .doc(reservation.operationId);

      transaction.set(
        tokenReference,
        {
          purchaseTokenHash:
            verified.purchaseTokenHash,
          uid,
          recipientUid,
          productId,
          googlePlayProductId:
            verified.googlePlayProductId,
          kind: "badge_non_consumable",
          latestOperationId:
            reservation.operationId,
          latestOrderId:
            verified.orderId,
          active: true,
          createdAt:
            tokenSnapshot.exists ?
              tokenSnapshot.data()?.createdAt ??
                FieldValue.serverTimestamp() :
              FieldValue.serverTimestamp(),
          updatedAt:
            FieldValue.serverTimestamp(),
        },
        {
          merge: true,
        },
      );

      if (recipientUid !== uid && !ownedBadgeSnapshot.exists) {
        writeUserNotificationInTransaction(
          firestore,
          transaction,
          {
            userId: recipientUid,
            actorId: uid,
            type: "badge_gift_received",
            title: "Rozet hediyesi",
            message: "Sana bir oyun rozeti hediye edildi.",
            route: "profile",
            data: {
              productId,
              badgeId: productId,
            },
          },
        );
      }

      transaction.create(
        saleReference,
        {
          saleId:
            reservation.operationId,
          commercialOperationId:
            reservation.operationId,
          uid,
          recipientUid,
          productId,
          badgeId: productId,
          googlePlayProductId:
            verified.googlePlayProductId,
          productType:
            "game_badge",
          gameId,
          gameName,
          title,
          amountKurus:
            currentProduct.priceKurus,
          amountSource:
            "catalog_nominal",
          paymentMethod:
            "google_play",
          status:
            "completed",
          testPurchase:
            verified.testPurchase,
          createdAt:
            FieldValue.serverTimestamp(),
          updatedAt:
            FieldValue.serverTimestamp(),
        },
      );

      transitionCommercialOperation(
        firestore,
        transaction,
        reservation.operationId,
        "paid",
        {
          actorUid: uid,
          source:
            "fulfillGooglePlayPurchase",
        },
        {
          productId,
          googlePlayProductId:
            verified.googlePlayProductId,
          entitlement:
            "badge",
        },
      );

      writeUserNotificationInTransaction(
        firestore,
        transaction,
        recipientUid === uid ?
          {
            userId: uid,
            type: "badge_purchased",
            title: "Rozetin aktif",
            message:
              `${title} Google Play tarafından doğrulandı ve hesabına eklendi.`,
            route: "profile",
            data: {
              productId,
              operationId: reservation.operationId,
            },
          } :
          {
            userId: uid,
            type: "badge_gift_sent",
            title: "Hediye gönderildi",
            message:
              `${title} seçtiğin kullanıcıya hediye edildi.`,
            route: "profile",
            data: {
              productId,
              recipientUid,
              operationId: reservation.operationId,
            },
          },
      );

      writeAuditLogInTransaction(
        firestore,
        transaction,
        {
          action:
            "google_play_badge_activated",
          performedBy:
            "system:google_play",
          targetUid: uid,
          metadata: {
            productId,
            googlePlayProductId:
              verified.googlePlayProductId,
            operationId:
              reservation.operationId,
            gameId,
            testPurchase:
              verified.testPurchase,
          },
        },
      );

      return {
        success: true,
        idempotentReplay: false,
        operationId:
          reservation.operationId,
        productId,
        kind:
          "badge_non_consumable",
        recipientUid,
        acknowledged:
          verified.acknowledged,
      };
    },
  );

  if (!verified.acknowledged) {
    await acknowledgeGooglePlayProduct(
      verified.googlePlayProductId,
      purchaseToken,
    );
  }

  return {
    ...result,
    acknowledged: true,
  };
}

/**
 * Reads and validates one digital product catalog document.
 *
 * @param {"plus_products"|"badge_products"} collection Catalog collection.
 * @param {string} productId Internal product id.
 * @return {Promise<CatalogProduct>} Validated catalog product.
 */
async function readCatalogProduct(
  collection:
    "plus_products" |
    "badge_products",
  productId: string,
): Promise<CatalogProduct> {
  const snapshot = await firestore
    .collection(collection)
    .doc(productId)
    .get();

  if (!snapshot.exists) {
    throw new HttpsError(
      "not-found",
      "Dijital ürün bulunamadı.",
    );
  }

  return normalizeCatalogProduct(
    productId,
    snapshot.data() ?? {},
  );
}

/**
 * Normalizes one catalog document.
 *
 * @param {string} productId Internal product id.
 * @param {Record<string, unknown>} data Catalog data.
 * @return {CatalogProduct} Normalized product.
 */
function normalizeCatalogProduct(
  productId: string,
  data: Record<string, unknown>,
): CatalogProduct {
  if (data.active === false) {
    throw new HttpsError(
      "failed-precondition",
      "Bu dijital ürün şu anda satışta değil.",
    );
  }

  const googlePlayProductId = requireString(
    data.googlePlayProductId,
    "googlePlayProductId",
    300,
  );

  const priceKurus =
    typeof data.priceKurus === "number" &&
    Number.isSafeInteger(data.priceKurus) ?
      Math.trunc(data.priceKurus) :
      0;

  if (priceKurus <= 0) {
    throw new HttpsError(
      "failed-precondition",
      "Dijital ürün fiyatı geçerli değil.",
    );
  }

  const googlePlayBasePlanId = String(
    data.googlePlayBasePlanId ?? "",
  ).trim();

  return {
    productId,
    googlePlayProductId,
    googlePlayBasePlanId,
    priceKurus,
    data,
  };
}

/**
 * Ensures product mapping did not change during external verification.
 *
 * @param {CatalogProduct} before Catalog before API call.
 * @param {CatalogProduct} current Catalog inside transaction.
 * @return {void}
 */
function assertSameGooglePlayProduct(
  before: CatalogProduct,
  current: CatalogProduct,
): void {
  if (
    before.productId !== current.productId ||
    before.googlePlayProductId !==
      current.googlePlayProductId ||
    before.googlePlayBasePlanId !==
      current.googlePlayBasePlanId
  ) {
    throw new HttpsError(
      "aborted",
      "Ürün eşlemesi değişti. Satın alma tekrar doğrulanmalı.",
    );
  }
}

/**
 * Reads a Firestore timestamp/date.
 *
 * @param {unknown} value Raw value.
 * @return {Date|null} Parsed date.
 */
function readTimestampDate(
  value: unknown,
): Date | null {
  if (value instanceof Timestamp) {
    return value.toDate();
  }

  if (value instanceof Date) {
    return value;
  }

  return null;
}

/**
 * Resolves one canonical internal product from a Google Play product id.
 *
 * The client does not choose internal product id or entitlement kind.
 *
 * @param {string} googlePlayProductId Google Play product id.
 * @return {Promise<ResolvedCatalogProduct>} Canonical product mapping.
 */
async function resolveCatalogByGooglePlayId(
  googlePlayProductId: string,
): Promise<ResolvedCatalogProduct> {
  const [
    plusSnapshot,
    badgeSnapshot,
  ] = await Promise.all([
    firestore
      .collection("plus_products")
      .where(
        "googlePlayProductId",
        "==",
        googlePlayProductId,
      )
      .where("active", "==", true)
      .limit(2)
      .get(),
    firestore
      .collection("badge_products")
      .where(
        "googlePlayProductId",
        "==",
        googlePlayProductId,
      )
      .where("active", "==", true)
      .limit(2)
      .get(),
  ]);

  const total =
    plusSnapshot.docs.length +
    badgeSnapshot.docs.length;

  if (total === 0) {
    throw new HttpsError(
      "not-found",
      "Google Play ürünü uygulama kataloğunda bulunamadı.",
    );
  }

  if (total !== 1) {
    throw new HttpsError(
      "failed-precondition",
      "Google Play ürün eşlemesi benzersiz değil.",
    );
  }

  if (plusSnapshot.docs.length === 1) {
    const document = plusSnapshot.docs[0];

    return {
      kind: "plus_subscription",
      collection: "plus_products",
      product: normalizeCatalogProduct(
        document.id,
        document.data(),
      ),
    };
  }

  const document = badgeSnapshot.docs[0];

  return {
    kind: "badge_non_consumable",
    collection: "badge_products",
    product: normalizeCatalogProduct(
      document.id,
      document.data(),
    ),
  };
}

/**
 * Prevents one Google Play purchase token from being claimed by another
 * user, product or entitlement type.
 *
 * @param {Record<string, unknown>|null} data Existing registry data.
 * @param {string} uid Expected user uid.
 * @param {string} productId Expected internal product id.
 * @param {DigitalPurchaseKind} kind Expected entitlement kind.
 * @return {void}
 */
function assertTokenRegistryOwnership(
  data: Record<string, unknown> | null,
  uid: string,
  productId: string,
  kind: DigitalPurchaseKind,
): void {
  if (data == null) {
    return;
  }

  const existingUid =
    String(data.uid ?? "").trim();
  const existingProductId =
    String(data.productId ?? "").trim();
  const existingKind =
    String(data.kind ?? "").trim();

  if (
    existingUid !== uid ||
    existingProductId !== productId ||
    existingKind !== kind
  ) {
    throw new HttpsError(
      "permission-denied",
      "Google Play satın alma kaydı başka bir hesaba veya ürüne bağlı.",
    );
  }
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
