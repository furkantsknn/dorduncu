import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  FieldValue,
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

interface PurchaseBadgeRequest {
  badgeId?: unknown;
  paymentSource?: unknown;
  requestId?: unknown;
}

type PaymentSource = "market" | "available";

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

  if (
    normalizedValue !== "market" &&
    normalizedValue !== "available"
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Geçersiz ödeme kaynağı."
    );
  }

  return normalizedValue;
}

/**
 * Cüzdan bakiyesini güvenli şekilde okur.
 *
 * @param {Record<string, unknown>} data Cüzdan verisi.
 * @param {string} field Alan adı.
 * @return {number} Bakiye değeri.
 */
function readBalance(
  data: Record<string, unknown>,
  field: string
): number {
  const rawValue = data[field];

  if (typeof rawValue !== "number" || !Number.isFinite(rawValue)) {
    return 0;
  }

  return Math.max(0, Math.trunc(rawValue));
}

export const purchaseBadge = onCall(
  {
    region: "europe-west1",
    enforceAppCheck: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Rozet satın almak için giriş yapmalısınız."
      );
    }

    await assertLegacyDigitalWalletPurchaseAllowed();

    const uid = request.auth.uid;
    const data = request.data as PurchaseBadgeRequest;

    const badgeId = requireString(
      data.badgeId,
      "badgeId",
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
        `legacy_badge_wallet:${uid}`,
        requestId
      );

    const productReference = firestore
      .collection("badge_products")
      .doc(badgeId);

    const walletReference = firestore
      .collection("wallets")
      .doc(uid);

    const ownedBadgeReference = firestore
      .collection("users")
      .doc(uid)
      .collection("owned_badges")
      .doc(badgeId);

    const walletTransactionReference = walletReference
      .collection("transactions")
      .doc(
        `badge_purchase_${commercialIdentity.operationId}`
      );

    const saleReference = firestore
      .collection("market_sales")
      .doc(commercialIdentity.operationId);

    return firestore.runTransaction(async (transaction) => {
      const [
        productSnapshot,
        walletSnapshot,
        ownedBadgeSnapshot,
      ] = await Promise.all([
        transaction.get(productReference),
        transaction.get(walletReference),
        transaction.get(ownedBadgeReference),
      ]);

      if (!productSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "Rozet ürünü bulunamadı."
        );
      }

      const productData =
        productSnapshot.data() ?? {};

      if (productData.active === false) {
        throw new HttpsError(
          "failed-precondition",
          "Bu rozet şu anda satışta değil."
        );
      }

      const priceKurus =
        typeof productData.priceKurus === "number" ?
          Math.trunc(productData.priceKurus) :
          0;

      if (priceKurus <= 0) {
        throw new HttpsError(
          "failed-precondition",
          "Rozet fiyatı geçerli değil."
        );
      }

      const reservation =
        await reserveCommercialOperation(
          firestore,
          transaction,
          {
            userUid: uid,
            type: "digital_badge_purchase",
            provider: "internal_legacy",
            idempotencyScope:
              `legacy_badge_wallet:${uid}`,
            idempotencyKey: requestId,
            money: {
              currency: "TRY",
              grossAmountMinor: priceKurus,
              feeAmountMinor: 0,
              netAmountMinor: priceKurus,
            },
            relatedProductId: badgeId,
            metadata: {
              paymentSource,
              legacyWalletPurchase: true,
            },
          },
          {
            actorUid: uid,
            source: "purchaseBadge",
          }
        );

      if (!reservation.created) {
        return {
          success: true,
          idempotentReplay: true,
          operationId: reservation.operationId,
          badgeId,
          title:
            productData.title?.toString().trim() ||
            "Oyun Rozeti",
          priceKurus,
        };
      }

      if (ownedBadgeSnapshot.exists) {
        throw new HttpsError(
          "already-exists",
          "Bu rozete zaten sahipsiniz."
        );
      }

      const walletData =
        walletSnapshot.data() ?? {};

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

      if (
        paymentSource === "market" &&
        marketBalance < priceKurus
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Market bakiyesi yetersiz."
        );
      }

      if (
        paymentSource === "available" &&
        availableBalance < priceKurus
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Kullanılabilir bakiye yetersiz."
        );
      }

      const marketUsed =
        paymentSource === "market" ?
          priceKurus :
          0;

      const availableUsed =
        paymentSource === "available" ?
          priceKurus :
          0;

      const newMarketBalance =
        marketBalance - marketUsed;

      const newAvailableBalance =
        availableBalance - availableUsed;

      const title =
        productData.title?.toString().trim() ||
        "Oyun Rozeti";

      const gameId =
        productData.gameId?.toString().trim() ||
        "";

      const gameName =
        productData.gameName?.toString().trim() ||
        "";

      const emoji =
        productData.emoji?.toString().trim() ||
        "🏅";

      const imageUrl =
        productData.imageUrl?.toString().trim() ||
        "";

      transaction.set(
        walletReference,
        {
          marketBalanceKurus:
            newMarketBalance,
          availableBalanceKurus:
            newAvailableBalance,
          updatedAt:
            FieldValue.serverTimestamp(),
        },
        {
          merge: true,
        }
      );

      transaction.create(
        ownedBadgeReference,
        {
          badgeId,
          productId: badgeId,
          commercialOperationId:
            reservation.operationId,
          gameId,
          gameName,
          title,
          emoji,
          imageUrl,
          priceKurus,
          paymentMethod: "wallet",
          marketBalanceUsedKurus:
            marketUsed,
          availableBalanceUsedKurus:
            availableUsed,
          equipped: true,
          source: "purchase",
          purchasedAt:
            FieldValue.serverTimestamp(),
          createdAt:
            FieldValue.serverTimestamp(),
          updatedAt:
            FieldValue.serverTimestamp(),
        }
      );

      transaction.create(
        walletTransactionReference,
        {
          type: "badge_purchase",
          amountKurus: -priceKurus,
          status: "completed",
          title: `${title} satın alındı`,
          description:
            `${title} marketten satın alındı.`,
          productId: badgeId,
          badgeId,
          commercialOperationId:
            reservation.operationId,
          metadata: {
            gameId,
            gameName,
            marketBalanceUsedKurus:
              marketUsed,
            availableBalanceUsedKurus:
              availableUsed,
          },
          createdAt:
            FieldValue.serverTimestamp(),
          updatedAt:
            FieldValue.serverTimestamp(),
        }
      );

      transaction.create(
        saleReference,
        {
          saleId: saleReference.id,
          commercialOperationId:
            reservation.operationId,
          uid,
          productId: badgeId,
          badgeId,
          productType: "game_badge",
          gameId,
          gameName,
          title,
          amountKurus: priceKurus,
          paymentMethod: "wallet",
          marketBalanceUsedKurus:
            marketUsed,
          availableBalanceUsedKurus:
            availableUsed,
          status: "completed",
          createdAt:
            FieldValue.serverTimestamp(),
          updatedAt:
            FieldValue.serverTimestamp(),
        }
      );

      transitionCommercialOperation(
        firestore,
        transaction,
        reservation.operationId,
        "paid",
        {
          actorUid: uid,
          source: "purchaseBadge",
        },
        {
          badgeId,
          paymentSource,
          entitlement: "badge",
        }
      );

      return {
        success: true,
        idempotentReplay: false,
        operationId: reservation.operationId,
        badgeId,
        title,
        priceKurus,
        marketBalanceKurus:
          newMarketBalance,
        availableBalanceKurus:
          newAvailableBalance,
      };
    });
  }
);
