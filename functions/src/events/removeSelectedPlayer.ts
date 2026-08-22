import {onCall, HttpsError} from "firebase-functions/v2/https";
import {
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";

const REGION = "europe-west1";

export const removeSelectedPlayer = onCall(
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
        "Etkinlik sahibi kadrodan çıkarılamaz.",
      );
    }

    const firestore = getFirestore();

    const eventReference = firestore
      .collection("events")
      .doc(eventId);

    const applicationReference = eventReference
      .collection("applications")
      .doc(playerId);

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
            "Oyuncuyu kaldırma yetkiniz bulunmuyor.",
          );
        }

        const paymentStatus = String(
          eventData.paymentStatus ?? "not_created",
        )
          .trim()
          .toLowerCase();

        if (isPaidStatus(paymentStatus)) {
          throw new HttpsError(
            "failed-precondition",
            "Ödeme alındıktan sonra oyuncu doğrudan kaldırılamaz.",
          );
        }

        const selectedPlayerIds = readStringList(
          eventData.selectedPlayerIds,
        );

        if (!selectedPlayerIds.includes(playerId)) {
          throw new HttpsError(
            "failed-precondition",
            "Bu oyuncu etkinlik kadrosunda bulunmuyor.",
          );
        }

        const updatedSelectedPlayerIds =
          selectedPlayerIds.filter(
            (id) => id !== playerId,
          );

        const requiredPlayerCount = readPlayerCount(
          eventData,
        );

        const rosterIncomplete =
          updatedSelectedPlayerIds.length <
          requiredPlayerCount;

        transaction.update(
          eventReference,
          {
            selectedPlayerIds: updatedSelectedPlayerIds,
            katilanlar: FieldValue.arrayRemove(playerId),
            chatMemberUids: FieldValue.arrayRemove(playerId),
            ...(rosterIncomplete ?
              {
                durum: "aktif",
                status: "active",
                paymentRequired: false,
                paymentStatus: "not_created",
                rosterCompletedAt: FieldValue.delete(),
              } :
              {}),
            updatedAt: FieldValue.serverTimestamp(),
          },
        );

        transaction.set(
          applicationReference,
          {
            status: "removed",
            removalReason: reason,
            removedBy: organizerId,
            removedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          {
            merge: true,
          },
        );

        if (rosterIncomplete) {
          transaction.set(
            paymentSessionReference,
            {
              status: "cancelled",
              gatewayStatus: "not_started",
              paymentRequired: false,
              cancellationReason: "roster_incomplete",
              cancelledAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            },
            {
              merge: true,
            },
          );
        }
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
 * Etkinlik için gerekli oyuncu sayısını okur.
 *
 * @param {Record<string, unknown>} data Etkinlik verisi.
 * @return {number} Gerekli oyuncu sayısı.
 */
function readPlayerCount(
  data: Record<string, unknown>,
): number {
  const rawValue =
    data.oyuncuSayisi ??
    data.playerCount ??
    1;

  const value = Number(rawValue);

  if (
    !Number.isInteger(value) ||
    value < 1 ||
    value > 4
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Etkinliğin oyuncu sayısı geçersiz.",
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

/**
 * Ödeme alınmış durumları kontrol eder.
 *
 * @param {string} value Ödeme durum değeri.
 * @return {boolean} Ödeme alınmışsa true.
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
 * Kadrodan çıkarılan oyuncuya bildirim oluşturur.
 *
 * @param {object} params Bildirim parametreleri.
 * @param {FirebaseFirestore.Firestore} params.firestore Firestore örneği.
 * @param {string} params.userId Bildirim alacak kullanıcı.
 * @param {string} params.actorId İşlemi yapan kullanıcı.
 * @param {string} params.eventId Etkinlik kimliği.
 * @param {string} params.reason Kadrodan çıkarma sebebi.
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
    `Etkinlik oyuncu listesinden çıkarıldın: ${reason}` :
    "Etkinlik oyuncu listesinden çıkarıldın.";

  await reference.set({
    notificationId: reference.id,
    userId,
    actorId,
    eventId,
    type: "removedFromEvent",
    title: "Etkinlik oyuncu seçimi",
    message,
    isRead: false,
    read: false,
    okundu: false,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
}
