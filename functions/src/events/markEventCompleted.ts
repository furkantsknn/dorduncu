import {onCall, HttpsError} from "firebase-functions/v2/https";
import {
  FieldValue,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";

const REGION = "europe-west1";

export const markEventCompleted = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const uid = request.auth?.uid;

    if (!uid) {
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

    const firestore = getFirestore();
    const eventRef = firestore.collection("events").doc(eventId);

    await firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(eventRef);

      if (!snapshot.exists) {
        throw new HttpsError(
          "not-found",
          "Etkinlik bulunamadı.",
        );
      }

      const data = snapshot.data() ?? {};

      if ((data.olusturanUid ?? "") !== uid) {
        throw new HttpsError(
          "permission-denied",
          "Etkinliği tamamlama yetkiniz bulunmuyor.",
        );
      }

      const eventDate = data.tarih;

      if (eventDate instanceof Timestamp) {
        if (eventDate.toDate().getTime() > Date.now()) {
          throw new HttpsError(
            "failed-precondition",
            "Etkinlik zamanı gelmeden tamamlanamaz.",
          );
        }
      }

      transaction.update(eventRef, {
        durum: "tamamlandi",
        status: "completed",
        paymentRequired: false,
        completedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

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
  if (data === null || typeof data !== "object") {
    throw new HttpsError("invalid-argument", errorMessage);
  }

  const value = String(
    (data as Record<string, unknown>)[key] ?? "",
  ).trim();

  if (!value) {
    throw new HttpsError("invalid-argument", errorMessage);
  }

  return value;
}
