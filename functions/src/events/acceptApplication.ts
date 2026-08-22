import {onCall, HttpsError} from "firebase-functions/v2/https";
import {
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";

const REGION = "europe-west1";

/**
 * Bir oyuncunun etkinlik başvurusunu kabul eder.
 *
 * Oyuncu kadrosu tamamlandığında ödeme oturumunu
 * yalnızca sunucu tarafında oluşturur.
 */
export const acceptApplication = onCall(
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

    if (organizerId === playerId) {
      throw new HttpsError(
        "invalid-argument",
        "Etkinlik sahibi kendi başvurusunu kabul edemez.",
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

    const result = await firestore.runTransaction(
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
            "Bu başvuruyu kabul etme yetkiniz bulunmuyor.",
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
            "Yalnızca bekleyen başvurular kabul edilebilir.",
          );
        }

        const eventStatus = String(
          eventData.durum ??
          eventData.status ??
          "",
        )
          .trim()
          .toLowerCase();

        if (!isActiveStatus(eventStatus)) {
          throw new HttpsError(
            "failed-precondition",
            "Bu etkinlik artık başvuru kabul etmiyor.",
          );
        }

        const requiredPlayerCount = readPlayerCount(
          eventData,
        );

        const selectedPlayerIds = readStringList(
          eventData.selectedPlayerIds,
        );

        if (selectedPlayerIds.includes(playerId)) {
          throw new HttpsError(
            "already-exists",
            "Bu oyuncu etkinlik için zaten seçilmiş.",
          );
        }

        if (
          selectedPlayerIds.length >=
          requiredPlayerCount
        ) {
          throw new HttpsError(
            "failed-precondition",
            "Etkinlik için gerekli oyuncu sayısı tamamlandı.",
          );
        }

        const pendingApplicantIds = readStringList(
          eventData.basvuranOyuncuIds,
        ).filter((id) => id !== playerId);

        const updatedSelectedPlayerIds = [
          ...selectedPlayerIds,
          playerId,
        ];

        const rosterCompleted =
          updatedSelectedPlayerIds.length >=
          requiredPlayerCount;

        transaction.update(
          applicationReference,
          {
            status: "accepted",
            acceptedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          },
        );

        transaction.update(
          eventReference,
          {
            selectedPlayerIds: updatedSelectedPlayerIds,
            katilanlar: FieldValue.arrayUnion(playerId),
            chatMemberUids: FieldValue.arrayUnion(
              organizerId,
              playerId,
            ),
            basvuranOyuncuIds: pendingApplicantIds,
            basvuruSayisi: pendingApplicantIds.length,
            ...(rosterCompleted ?
              {
                durum: "odeme_bekliyor",
                status: "payment_pending",
                paymentRequired: true,
                paymentStatus: "payment_pending",
                rosterCompletedAt:
                  FieldValue.serverTimestamp(),
              } :
              {}),
            updatedAt: FieldValue.serverTimestamp(),
          },
        );

        if (rosterCompleted) {
          const participantIds = [
            organizerId,
            ...updatedSelectedPlayerIds,
          ];

          transaction.set(
            paymentSessionReference,
            {
              paymentSessionId: eventId,
              eventId,
              organizerId,
              participantIds,
              status: "payment_pending",
              gatewayStatus: "not_started",
              currency: "TRY",
              paymentRequired: true,
              createdAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            },
            {
              merge: false,
            },
          );
        }

        return {
          rosterCompleted,
          selectedPlayerCount:
            updatedSelectedPlayerIds.length,
          requiredPlayerCount,
        };
      },
    );

    await createNotification({
      firestore,
      userId: playerId,
      actorId: organizerId,
      eventId,
      type: "applicationAccepted",
      title: "Başvurun kabul edildi",
      message:
        "Etkinlik başvurun organizatör tarafından kabul edildi.",
    });

    if (result.rosterCompleted) {
      await createPaymentNotifications({
        firestore,
        eventId,
        organizerId,
      });
    }

    return {
      success: true,
      eventId,
      playerId,
      rosterCompleted: result.rosterCompleted,
      selectedPlayerCount: result.selectedPlayerCount,
      requiredPlayerCount: result.requiredPlayerCount,
    };
  },
);

/**
 * Gerekli metin alanını okur.
 *
 * @param {unknown} data İstek verisi.
 * @param {string} key Okunacak alan adı.
 * @param {string} errorMessage Hata mesajı.
 * @return {string} Okunan ve temizlenen metin.
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
 * Etkinlikte gerekli oyuncu sayısını okur.
 *
 * @param {Record<string, unknown>} data Etkinlik verisi.
 * @return {number} Geçerli oyuncu sayısı.
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
 * Etkinliğin aktif durumda olup olmadığını kontrol eder.
 *
 * @param {string} value Etkinlik durum değeri.
 * @return {boolean} Etkinlik aktifse true.
 */
function isActiveStatus(
  value: string,
): boolean {
  return value === "aktif" ||
    value === "active";
}

/**
 * Kullanıcı bildirimini oluşturur.
 */
async function createNotification({
  firestore,
  userId,
  actorId,
  eventId,
  type,
  title,
  message,
}: {
  firestore: FirebaseFirestore.Firestore;
  userId: string;
  actorId: string;
  eventId: string;
  type: string;
  title: string;
  message: string;
}): Promise<void> {
  const reference = firestore
    .collection("users")
    .doc(userId)
    .collection("notifications")
    .doc();

  await reference.set({
    notificationId: reference.id,
    userId,
    actorId,
    eventId,
    type,
    title,
    message,
    isRead: false,
    read: false,
    okundu: false,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
}

/**
 * Kadro tamamlandığında ödeme bildirimlerini oluşturur.
 */
async function createPaymentNotifications({
  firestore,
  eventId,
  organizerId,
}: {
  firestore: FirebaseFirestore.Firestore;
  eventId: string;
  organizerId: string;
}): Promise<void> {
  const eventSnapshot = await firestore
    .collection("events")
    .doc(eventId)
    .get();

  if (!eventSnapshot.exists) {
    return;
  }

  const eventData = eventSnapshot.data() ?? {};

  const participantIds = [
    organizerId,
    ...readStringList(
      eventData.selectedPlayerIds,
    ),
  ];

  const uniqueParticipantIds = [
    ...new Set(participantIds),
  ];

  const batch = firestore.batch();

  for (const userId of uniqueParticipantIds) {
    const notificationReference = firestore
      .collection("users")
      .doc(userId)
      .collection("notifications")
      .doc();

    batch.set(
      notificationReference,
      {
        notificationId:
          notificationReference.id,
        userId,
        actorId: organizerId,
        eventId,
        type: "eventPaymentRequired",
        title: "Ödeme bekleniyor",
        message:
          "Etkinlik kadrosu tamamlandı. Ödeme işlemi bekleniyor.",
        isRead: false,
        read: false,
        okundu: false,
        createdAt:
          FieldValue.serverTimestamp(),
        updatedAt:
          FieldValue.serverTimestamp(),
      },
    );
  }

  await batch.commit();
}
