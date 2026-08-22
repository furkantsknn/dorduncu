import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  FieldValue,
  Timestamp,
} from "firebase-admin/firestore";

import {firestore} from "../config/firebaseAdmin";

interface PurchasePlusRequest {
  productId?: unknown;
  paymentSource?: unknown;
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
      .doc();

    const walletTransactionReference = walletReference
      .collection("transactions")
      .doc(`plus_purchase_${purchaseReference.id}`);

    const saleReference = firestore
      .collection("market_sales")
      .doc(purchaseReference.id);

    return firestore.runTransaction(async (transaction) => {
      const [
        productSnapshot,
        userSnapshot,
        walletSnapshot,
      ] = await Promise.all([
        transaction.get(productReference),
        transaction.get(userReference),
        transaction.get(walletReference),
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

      return {
        success: true,
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
