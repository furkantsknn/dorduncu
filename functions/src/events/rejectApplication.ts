import {onCall, HttpsError} from "firebase-functions/v2/https";
import {
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";

const REGION = "europe-west1";

export const rejectApplication = onCall(
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

    const playerId = readRequiredString(
      request.data,
      "playerId",
      "Oyuncu kimliği gereklidir.",
    );

    const reason = readOptionalString(
      request.data,
      "reason",
    );

    if (organizerId === playerId) {
      throw new HttpsError(
        "invalid-argument",
        "Etkinlik sahibi kendi başvurusunu reddedemez.",
      );
    }

    const firestore = getFirestore();

    const eventReference = firestore
      .collection("events")
      .doc(eventId);

    const applicationReference = eventReference
      .collection("applications")
      .doc(playerId);

    await firestore.runTransaction(
      async (transaction) => {
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
        const applicationData =
          applicationSnapshot.data() ?? {};

        const eventOrganizerId = String(
          eventData.olusturanUid ?? "",
        ).trim();

        if (eventOrganizerId !== organizerId) {
          throw new HttpsError(
            "permission-denied",
            "Bu başvuruyu reddetme yetkiniz bulunmuyor.",
          );
        }

        const applicationStatus = String(
          applicationData.status ?? "",
        )
          .trim()
          .toLowerCase();

        if (applicationStatus !== "pending") {
          throw new HttpsError(
            "failed-precondition",
            "Yalnızca bekleyen başvurular reddedilebilir.",
          );
        }

        const pendingApplicantIds = readStringList(
          eventData.basvuranOyuncuIds,
        ).filter((id) => id !== playerId);

        transaction.update(
          applicationReference,
          {
            status: "rejected",
            rejectionReason: reason,
            rejectedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          },
        );

        transaction.update(
          eventReference,
          {
            basvuranOyuncuIds: pendingApplicantIds,
            basvuruSayisi: pendingApplicantIds.length,
            updatedAt: FieldValue.serverTimestamp(),
          },
        );
      },
    );

    await createNotification({
      firestore,
      userId: playerId,
      actorId: organizerId,
      eventId,
      reason,
    });

    return {
      success: true,
      eventId,
      playerId,
    };
  },
);

/**
 * Gerekli metin alanını okur.
 *
 * @param {unknown} data İstek verisi.
 * @param {string} key Okunacak alan adı.
 * @param {string} errorMessage Hata mesajı.
 * @return {string} Temizlenmiş metin.
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
 * İsteğe bağlı metin alanını okur.
 *
 * @param {unknown} data İstek verisi.
 * @param {string} key Okunacak alan adı.
 * @return {string} Temizlenmiş metin.
 */
function readOptionalString(
  data: unknown,
  key: string,
): string {
  if (
    data === null ||
    typeof data !== "object"
  ) {
    return "";
  }

  return String(
    (data as Record<string, unknown>)[key] ?? "",
  ).trim();
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

/**
 * Oyuncuya başvuru sonucu bildirimi gönderir.
 *
 * @param {object} params Bildirim parametreleri.
 * @param {FirebaseFirestore.Firestore} params.firestore Firestore örneği.
 * @param {string} params.userId Bildirim alacak kullanıcı.
 * @param {string} params.actorId İşlemi yapan kullanıcı.
 * @param {string} params.eventId Etkinlik kimliği.
 * @param {string} params.reason Reddetme sebebi.
 * @return {Promise<void>} İşlem tamamlandığında sonuçlanır.
 */
async function createNotification({
  firestore,
  userId,
  actorId,
  eventId,
  reason,
}: {
  firestore: FirebaseFirestore.Firestore;
  userId: string;
  actorId: string;
  eventId: string;
  reason: string;
}): Promise<void> {
  const reference = firestore
    .collection("users")
    .doc(userId)
    .collection("notifications")
    .doc();

  const message = reason.length > 0 ?
    `Etkinlik başvurun kabul edilmedi: ${reason}` :
    "Etkinlik başvurun kabul edilmedi.";

  await reference.set({
    notificationId: reference.id,
    userId,
    actorId,
    eventId,
    type: "applicationRejected",
    title: "Başvuru sonucu",
    message,
    isRead: false,
    read: false,
    okundu: false,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
}
