import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  FieldValue,
  Timestamp,
} from "firebase-admin/firestore";

import {firestore} from "../config/firebaseAdmin";
import {
  assertLegacyDigitalWalletPurchaseAllowed,
} from "../commercial/digitalCommercePolicy";
import {
  buildCommercialOperationIdentity,
  reserveCommercialOperation,
  transitionCommercialOperation,
} from "../commercial/commercialLedger";

interface PurchasePlusRequest {
  productId?: unknown;
  paymentSource?: unknown;
  requestId?: unknown;
}

type PaymentSource = "available";

/**
 * Zorunlu metin alanını doğrular.
 *
 * @param {unknown} value Gelen değer.
 * @param {string} fieldName Alan adı.
 * @param {number} maxLength En fazla karakter sayısı.
 * @return {string} Temizlenmiş metin değeri.
 */
function requireString(
  value: unknown,
  fieldName: string,
  maxLength: number
): string {
  if (typeof value !== "string") {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} geçerli bir metin olmalıdır.`
    );
  }

  const normalizedValue = value.trim();

  if (normalizedValue.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} zorunludur.`
    );
  }

  if (normalizedValue.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} en fazla ${maxLength} karakter olabilir.`
    );
  }

  return normalizedValue;
}

/**
 * Ödeme kaynağını doğrular.
 *
 * @param {unknown} value Gelen ödeme kaynağı.
 * @return {PaymentSource} Doğrulanmış ödeme kaynağı.
 */
function requirePaymentSource(value: unknown): PaymentSource {
  const normalizedValue = requireString(
    value,
    "paymentSource",
    30
  );

  if (normalizedValue !== "available") {
    throw new HttpsError(
      "invalid-argument",
      "Geçersiz ödeme kaynağı."
    );
  }

  return normalizedValue;
}

/**
 * Cüzdan bakiye alanını güvenli şekilde okur.
 *
 * @param {Record<string, unknown>} data Cüzdan verisi.
 * @param {string} field Okunacak alan.
 * @return {number} Negatif olmayan bakiye değeri.
 */
function readBalance(
  data: Record<string, unknown>,
  field: string
): number {
  const rawValue = data[field];

  if (
    typeof rawValue !== "number" ||
    !Number.isFinite(rawValue)
  ) {
    return 0;
  }

  return Math.max(0, Math.trunc(rawValue));
}

/**
 * Firestore tarih alanını Date nesnesine dönüştürür.
 *
 * @param {unknown} value Tarih alanı.
 * @return {Date | null} Dönüştürülmüş tarih.
 */
function readDate(value: unknown): Date | null {
  if (value instanceof Timestamp) {
    return value.toDate();
  }

  if (value instanceof Date) {
    return value;
  }

  return null;
}

/**
 * Tarihe gün ekler.
 *
 * @param {Date} date Başlangıç tarihi.
 * @param {number} days Eklenecek gün.
 * @return {Date} Yeni tarih.
 */
function addDays(date: Date, days: number): Date {
  const result = new Date(date.getTime());
  result.setUTCDate(result.getUTCDate() + days);
  return result;
}

export const purchasePlus = onCall(
  {
    region: "europe-west1",
    enforceAppCheck: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Plus satın almak için giriş yapmalısınız."
      );
    }

    await assertLegacyDigitalWalletPurchaseAllowed();

    const uid = request.auth.uid;
    const data = request.data as PurchasePlusRequest;

    const productId = requireString(
      data.productId,
      "productId",
      120
    );

    const paymentSource = requirePaymentSource(
      data.paymentSource
    );

    const requestId = requireString(
      data.requestId,
      "requestId",
      160
    );

    const commercialIdentity =
      buildCommercialOperationIdentity(
        `legacy_plus_wallet:${uid}`,
        requestId
      );

    const productReference = firestore
      .collection("plus_products")
      .doc(productId);

    const userReference = firestore
      .collection("users")
      .doc(uid);

    const walletReference = firestore
      .collection("wallets")
      .doc(uid);

    const purchaseReference = userReference
      .collection("plus_purchases")
      .doc(commercialIdentity.operationId);

    const walletTransactionReference = walletReference
      .collection("transactions")
      .doc(
        `plus_purchase_${commercialIdentity.operationId}`
      );

    const saleReference = firestore
      .collection("market_sales")
      .doc(commercialIdentity.operationId);

    return firestore.runTransaction(async (transaction) => {
      const [
        productSnapshot,
        userSnapshot,
        walletSnapshot,
        purchaseSnapshot,
      ] = await Promise.all([
        transaction.get(productReference),
        transaction.get(userReference),
        transaction.get(walletReference),
        transaction.get(purchaseReference),
      ]);

      if (!productSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "Plus ürünü bulunamadı."
        );
      }

      const productData = productSnapshot.data() ?? {};

      if (productData.active !== true) {
        throw new HttpsError(
          "failed-precondition",
          "Bu Plus paketi şu anda satışta değil."
        );
      }

      const priceKurus =
        typeof productData.priceKurus === "number" ?
          Math.trunc(productData.priceKurus) :
          0;

      const durationDays =
        typeof productData.durationDays === "number" ?
          Math.trunc(productData.durationDays) :
          0;

      if (priceKurus <= 0 || durationDays <= 0) {
        throw new HttpsError(
          "failed-precondition",
          "Plus ürün bilgileri geçerli değil."
        );
      }

      const reservation =
        await reserveCommercialOperation(
          firestore,
          transaction,
          {
            userUid: uid,
            type: "digital_plus_purchase",
            provider: "internal_legacy",
            idempotencyScope:
              `legacy_plus_wallet:${uid}`,
            idempotencyKey: requestId,
            money: {
              currency: "TRY",
              grossAmountMinor: priceKurus,
              feeAmountMinor: 0,
              netAmountMinor: priceKurus,
            },
            relatedProductId: productId,
            metadata: {
              paymentSource,
              legacyWalletPurchase: true,
            },
          },
          {
            actorUid: uid,
            source: "purchasePlus",
          }
        );

      if (!reservation.created) {
        const existingPurchase =
          purchaseSnapshot.data() ?? {};
        const existingExpiry = readDate(
          existingPurchase.expiresAt
        );

        if (existingExpiry == null) {
          throw new HttpsError(
            "failed-precondition",
            "Önceki Plus satın alma kaydı tamamlanamadı."
          );
        }

        return {
          success: true,
          idempotentReplay: true,
          operationId: reservation.operationId,
          productId,
          plan:
            existingPurchase.plan?.toString() ?? productId,
          durationDays:
            typeof existingPurchase.durationDays === "number" ?
              Math.trunc(existingPurchase.durationDays) :
              durationDays,
          priceKurus:
            typeof existingPurchase.priceKurus === "number" ?
              Math.trunc(existingPurchase.priceKurus) :
              priceKurus,
          paymentSource,
          plusExpiresAt: existingExpiry.toISOString(),
        };
      }

      const walletData = walletSnapshot.data() ?? {};

      if (walletData.isFrozen === true) {
        throw new HttpsError(
          "failed-precondition",
          "Cüzdanınız geçici olarak dondurulmuş."
        );
      }

      const marketBalance = readBalance(
        walletData,
        "marketBalanceKurus"
      );

      const availableBalance = readBalance(
        walletData,
        "availableBalanceKurus"
      );

      if (availableBalance < priceKurus) {
        throw new HttpsError(
          "failed-precondition",
          "Kullanılabilir bakiye yetersiz."
        );
      }

      const newMarketBalance = marketBalance;

      const newAvailableBalance =
              availableBalance - priceKurus;

      const now = new Date();
      const userData = userSnapshot.data() ?? {};
      const existingExpiry = readDate(
        userData.plusExpiresAt
      );

      const extensionBase =
        existingExpiry != null &&
        existingExpiry.getTime() > now.getTime() ?
          existingExpiry :
          now;

      const newExpiry = addDays(
        extensionBase,
        durationDays
      );

      const title =
        productData.title?.toString().trim() ||
        "Dört. Plus";

      const plan =
        productData.plan?.toString().trim() ||
        productId;

      transaction.set(
        walletReference,
        {
          marketBalanceKurus: newMarketBalance,
          availableBalanceKurus: newAvailableBalance,
          updatedAt: FieldValue.serverTimestamp(),
        },
        {
          merge: true,
        }
      );

      console.log("PLUS USER UPDATE", {
        uid,
        plus: true,
        isPlus: true,
        plan,
        newExpiry,
      });
      transaction.set(
        userReference,
        {
          plus: true,
          isPlus: true,
          plusPlan: plan,
          plusExpiresAt: Timestamp.fromDate(newExpiry),
          plusUpdatedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        {
          merge: true,
        }
      );

      transaction.create(
        purchaseReference,
        {
          purchaseId: purchaseReference.id,
          commercialOperationId:
            reservation.operationId,
          uid,
          productId,
          productType: "plus_subscription",
          title,
          plan,
          durationDays,
          priceKurus,
          paymentSource,
          startsFrom: Timestamp.fromDate(extensionBase),
          expiresAt: Timestamp.fromDate(newExpiry),
          status: "completed",
          purchasedAt: FieldValue.serverTimestamp(),
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }
      );

      transaction.create(
        walletTransactionReference,
        {
          type: "plus_purchase",
          amountKurus: -priceKurus,
          status: "completed",
          title: `${title} satın alındı`,
          description:
            `${durationDays} günlük Plus üyeliği satın alındı.`,
          productId,
          purchaseId: purchaseReference.id,
          commercialOperationId:
            reservation.operationId,
          paymentSource,
          metadata: {
            plan,
            durationDays,
            expiresAt: Timestamp.fromDate(newExpiry),
          },
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }
      );

      transaction.create(
        saleReference,
        {
          saleId: saleReference.id,
          commercialOperationId:
            reservation.operationId,
          uid,
          productId,
          purchaseId: purchaseReference.id,
          productType: "plus_subscription",
          title,
          plan,
          durationDays,
          amountKurus: priceKurus,
          paymentMethod: "wallet",
          paymentSource,
          status: "completed",
          expiresAt: Timestamp.fromDate(newExpiry),
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }
      );

      transitionCommercialOperation(
        firestore,
        transaction,
        reservation.operationId,
        "paid",
        {
          actorUid: uid,
          source: "purchasePlus",
        },
        {
          productId,
          paymentSource,
          entitlement: "plus",
        }
      );

      return {
        success: true,
        idempotentReplay: false,
        operationId: reservation.operationId,
        productId,
        plan,
        durationDays,
        priceKurus,
        paymentSource,
        plusExpiresAt: newExpiry.toISOString(),
      };
    });
  }
);
