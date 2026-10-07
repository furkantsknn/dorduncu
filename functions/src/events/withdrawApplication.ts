import {onCall, HttpsError} from "firebase-functions/v2/https";
import {
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";
import {
  APPLICATION_LIFECYCLE_VERSION,
  addressAccessStatus,
  applicationDecisionStatus,
  applicationPaymentStatus,
  applicationStatus,
  assertEventNotPast,
  reservationStatus,
} from "./eventLifecycle";

const REGION = "europe-west1";

export const withdrawApplication = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const playerId = request.auth?.uid;

    if (!playerId) {
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

    const eventReference = firestore
      .collection("events")
      .doc(eventId);

    const applicationReference = eventReference
      .collection("applications")
      .doc(playerId);

    await firestore.runTransaction(async (transaction) => {
      const eventSnapshot = await transaction.get(
        eventReference,
      );

      const applicationSnapshot = await transaction.get(
        applicationReference,
      );

      if (!eventSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "Etkinlik bulunamadı.",
        );
      }

      if (!applicationSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "Başvuru kaydı bulunamadı.",
        );
      }

      const eventData = eventSnapshot.data() ?? {};
      assertEventNotPast(eventData);
      const applicationData =
        applicationSnapshot.data() ?? {};

      const applicationPlayerId = String(
        applicationData.playerId ??
        applicationSnapshot.id,
      ).trim();

      if (applicationPlayerId !== playerId) {
        throw new HttpsError(
          "permission-denied",
          "Bu başvuruyu geri çekme yetkiniz bulunmuyor.",
        );
      }

      const currentApplicationStatus = String(
        applicationData.status ?? "",
      )
        .trim()
        .toLowerCase();

      if (
        currentApplicationStatus !==
        applicationStatus.pending
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Yalnızca bekleyen başvuru geri çekilebilir.",
        );
      }

      const pendingApplicantIds = readStringList(
        eventData.basvuranOyuncuIds,
      ).filter((id) => id !== playerId);

      transaction.update(
        applicationReference,
        {
          lifecycleVersion:
            APPLICATION_LIFECYCLE_VERSION,
          status: applicationStatus.withdrawn,
          decisionStatus:
            applicationDecisionStatus.withdrawn,
          paymentStatus:
            applicationPaymentStatus.notRequired,
          addressAccessStatus:
            addressAccessStatus.locked,
          reservationStatus:
            reservationStatus.released,
          withdrawnAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
      );

      transaction.update(
        eventReference,
        {
          basvuranOyuncuIds: pendingApplicantIds,
          basvuruSayisi: pendingApplicantIds.length,
          lifecycleVersion:
            APPLICATION_LIFECYCLE_VERSION,
          updatedAt: FieldValue.serverTimestamp(),
        },
      );
    });

    return {
      success: true,
      eventId,
      playerId,
      applicationStatus:
        applicationStatus.withdrawn,
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
 * Bilinmeyen değeri güvenli metin listesine dönüştürür.
 *
 * @param {unknown} value Dönüştürülecek değer.
 * @return {string[]} Temizlenmiş metin listesi.
 */
function readStringList(
  value: unknown,
): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((item) => String(item).trim())
    .filter((item) => item.length > 0);
}
