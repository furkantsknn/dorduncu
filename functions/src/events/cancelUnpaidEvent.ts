import {onCall, HttpsError} from "firebase-functions/v2/https";
import {
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";

const REGION = "europe-west1";

export const cancelUnpaidEvent = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const organizerId = request.auth?.uid;

    if (!organizerId) {
      throw new HttpsError(
        "unauthenticated",
        "Bu işlem için kullanıcı girişi gereklidir.",
      );
    }

    const eventId = readRequiredString(
      request.data,
      "eventId",
      "Etkinlik kimliği gereklidir.",
    );

    const reason = readRequiredString(
      request.data,
      "reason",
      "İptal nedeni gereklidir.",
    );

    const firestore = getFirestore();

    const eventReference = firestore
      .collection("events")
      .doc(eventId);

    const paymentSessionReference = firestore
      .collection("paymentSessions")
      .doc(eventId);

    await firestore.runTransaction(
      async (transaction) => {
        const eventSnapshot = await transaction.get(
          eventReference,
        );

        if (!eventSnapshot.exists) {
          throw new HttpsError(
            "not-found",
            "Etkinlik bulunamadı.",
          );
        }

        const eventData = eventSnapshot.data() ?? {};

        const eventOrganizerId = String(
          eventData.olusturanUid ?? "",
        ).trim();

        if (eventOrganizerId !== organizerId) {
          throw new HttpsError(
            "permission-denied",
            "Bu etkinliği iptal etme yetkiniz bulunmuyor.",
          );
        }

        const eventStatus = String(
          eventData.durum ??
          eventData.status ??
          "",
        )
          .trim()
          .toLowerCase();

        if (isCancelledStatus(eventStatus)) {
          throw new HttpsError(
            "failed-precondition",
            "Etkinlik zaten iptal edilmiş.",
          );
        }

        if (isCompletedStatus(eventStatus)) {
          throw new HttpsError(
            "failed-precondition",
            "Tamamlanmış etkinlik iptal edilemez.",
          );
        }

        const paymentStatus = String(
          eventData.paymentStatus ?? "notRequired",
        )
          .trim()
          .toLowerCase();

        if (isPaidStatus(paymentStatus)) {
          throw new HttpsError(
            "failed-precondition",
            "Ödeme alınmış etkinlik bu yöntemle iptal edilemez.",
          );
        }

        transaction.update(
          eventReference,
          {
            durum: "cancelled",
            status: "cancelled",
            paymentRequired: false,
            paymentStatus: "cancelled",
            cancellationReason: reason,
            cancelledBy: organizerId,
            cancelledAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          },
        );

        transaction.set(
          paymentSessionReference,
          {
            eventId,
            organizerId,
            status: "cancelled",
            gatewayStatus: "not_started",
            paymentRequired: false,
            cancellationReason: reason,
            cancelledBy: organizerId,
            cancelledAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          {
            merge: true,
          },
        );
      },
    );

    return {
      success: true,
      eventId,
    };
  },
);

/**
 * İstekten zorunlu metin alanını okur.
 *
 * @param {unknown} data İstek verisi.
 * @param {string} key Alan adı.
 * @param {string} errorMessage Hata mesajı.
 * @return {string} Temizlenmiş metin değeri.
 */
function readRequiredString(
  data: unknown,
  key: string,
  errorMessage: string,
): string {
  if (
    data === null ||
    typeof data !== "object"
  ) {
    throw new HttpsError(
      "invalid-argument",
      errorMessage,
    );
  }

  const value = String(
    (data as Record<string, unknown>)[key] ?? "",
  ).trim();

  if (!value) {
    throw new HttpsError(
      "invalid-argument",
      errorMessage,
    );
  }

  return value;
}

/**
 * Ödeme tamamlanmış durumlarını kontrol eder.
 *
 * @param {string} value Ödeme durumu.
 * @return {boolean} Ödeme tamamlandıysa true.
 */
function isPaidStatus(
  value: string,
): boolean {
  return value === "escrowheld" ||
    value === "escrow_held" ||
    value === "paid" ||
    value === "completed";
}

/**
 * Etkinliğin iptal durumunda olup olmadığını kontrol eder.
 *
 * @param {string} value Etkinlik durumu.
 * @return {boolean} İptal edilmişse true.
 */
function isCancelledStatus(
  value: string,
): boolean {
  return value === "cancelled" ||
    value === "iptal" ||
    value === "iptal_edildi";
}

/**
 * Etkinliğin tamamlanmış durumda olup olmadığını kontrol eder.
 *
 * @param {string} value Etkinlik durumu.
 * @return {boolean} Tamamlanmışsa true.
 */
function isCompletedStatus(
  value: string,
): boolean {
  return value === "completed" ||
    value === "tamamlandi" ||
    value === "tamamlandı";
}
