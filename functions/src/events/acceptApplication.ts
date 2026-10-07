import {onCall, HttpsError} from "firebase-functions/v2/https";
import {
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";
import {
  ACCESS_MODEL_FREE,
  APPLICATION_LIFECYCLE_VERSION,
  DEFAULT_PAYMENT_WINDOW_MINUTES,
  MAX_PAYMENT_WINDOW_MINUTES,
  MIN_PAYMENT_WINDOW_MINUTES,
  addressAccessStatus,
  applicationDecisionStatus,
  applicationPaymentStatus,
  applicationStatus,
  assertEventNotPast,
  isFreeAccessEvent,
  reservationStatus,
} from "./eventLifecycle";
import {
  writeUserNotification,
} from "../notifications/writeUserNotification";

const REGION = "europe-west1";

/**
 * Bir oyuncunun etkinlik başvurusunu kabul eder.
 *
 * Kabul edilen başvuru canonical olarak ödeme bekleyen duruma geçer.
 * Mevcut event-level ödeme modeli korunur; kadro tamamlandığında ödeme oturumu
 * sunucu tarafında oluşturulur.
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

    const organizerBlockedPlayerReference = firestore
      .collection("users")
      .doc(organizerId)
      .collection("blockedUsers")
      .doc(playerId);

    const playerBlockedOrganizerReference = firestore
      .collection("users")
      .doc(playerId)
      .collection("blockedUsers")
      .doc(organizerId);

    const settingsSnapshot = await firestore
      .collection("system_settings")
      .doc("global")
      .get();

    const paymentWindowMinutes = normalizePaymentWindowMinutes(
      settingsSnapshot.data()?.paymentWindowMinutes,
    );

    const paymentDueAt = new Date(
      Date.now() + paymentWindowMinutes * 60 * 1000,
    );

    const result = await firestore.runTransaction(
      async (transaction) => {
        const eventSnapshot = await transaction.get(
          eventReference,
        );

        const applicationSnapshot = await transaction.get(
          applicationReference,
        );

        const organizerBlockedPlayer =
          await transaction.get(
            organizerBlockedPlayerReference,
          );

        const playerBlockedOrganizer =
          await transaction.get(
            playerBlockedOrganizerReference,
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

        if (
          organizerBlockedPlayer.exists ||
          playerBlockedOrganizer.exists
        ) {
          throw new HttpsError(
            "permission-denied",
            "Engellenmiş kullanıcılar arasında başvuru kabul edilemez.",
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

        assertEventNotPast(eventData);

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
        const freeEvent = isFreeAccessEvent(eventData);

        if (freeEvent) {
          transaction.update(
            applicationReference,
            {
              lifecycleVersion: APPLICATION_LIFECYCLE_VERSION,
              status: applicationStatus.addressUnlocked,
              decisionStatus: applicationDecisionStatus.accepted,
              paymentStatus: applicationPaymentStatus.notRequired,
              addressAccessStatus: addressAccessStatus.unlocked,
              reservationStatus: reservationStatus.none,
              acceptedAt: FieldValue.serverTimestamp(),
              addressUnlockedAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            },
          );

          transaction.update(
            eventReference,
            {
              lifecycleVersion: APPLICATION_LIFECYCLE_VERSION,
              accessModel: ACCESS_MODEL_FREE,
              paymentRequired: false,
              paymentStatus: applicationPaymentStatus.notRequired,
              selectedPlayerIds: updatedSelectedPlayerIds,
              katilanlar: FieldValue.arrayUnion(playerId),
              chatMemberUids: FieldValue.arrayUnion(
                organizerId,
                playerId,
              ),
              basvuranOyuncuIds: pendingApplicantIds,
              basvuruSayisi: pendingApplicantIds.length,
              durum: "aktif",
              status: "active",
              rosterStatus: rosterCompleted ? "full" : "collecting",
              ...(rosterCompleted ?
                {
                  rosterCompletedAt: FieldValue.serverTimestamp(),
                } :
                {}),
              updatedAt: FieldValue.serverTimestamp(),
            },
          );

          return {
            freeEvent: true,
            rosterCompleted,
            selectedPlayerCount: updatedSelectedPlayerIds.length,
            requiredPlayerCount,
          };
        }

        transaction.update(
          applicationReference,
          {
            lifecycleVersion:
              APPLICATION_LIFECYCLE_VERSION,
            status:
              applicationStatus.acceptedPaymentPending,
            decisionStatus:
              applicationDecisionStatus.accepted,
            paymentStatus:
              applicationPaymentStatus.pending,
            addressAccessStatus:
              addressAccessStatus.locked,
            reservationStatus:
              reservationStatus.held,
            acceptedAt: FieldValue.serverTimestamp(),
            reservationStartedAt:
              FieldValue.serverTimestamp(),
            reservationExpiresAt:
              rosterCompleted ? paymentDueAt : null,
            updatedAt: FieldValue.serverTimestamp(),
          },
        );

        transaction.update(
          eventReference,
          {
            lifecycleVersion:
              APPLICATION_LIFECYCLE_VERSION,
            selectedPlayerIds: updatedSelectedPlayerIds,
            katilanlar: FieldValue.arrayUnion(playerId),
            chatMemberUids: FieldValue.arrayUnion(
              organizerId,
              playerId,
            ),
            basvuranOyuncuIds: pendingApplicantIds,
            basvuruSayisi: pendingApplicantIds.length,
            rosterStatus:
              rosterCompleted ? "full" : "collecting",
            ...(rosterCompleted ?
              {
                durum: "odeme_bekliyor",
                status: "payment_pending",
                paymentRequired: true,
                paymentStatus: "payment_pending",
                rosterCompletedAt:
                  FieldValue.serverTimestamp(),
                paymentWindowMinutes,
                paymentDueAt,
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

          for (const acceptedPlayerId of updatedSelectedPlayerIds) {
            const acceptedApplicationReference = eventReference
              .collection("applications")
              .doc(acceptedPlayerId);

            transaction.set(
              acceptedApplicationReference,
              {
                lifecycleVersion:
                  APPLICATION_LIFECYCLE_VERSION,
                status:
                  applicationStatus.acceptedPaymentPending,
                decisionStatus:
                  applicationDecisionStatus.accepted,
                paymentStatus:
                  applicationPaymentStatus.pending,
                addressAccessStatus:
                  addressAccessStatus.locked,
                reservationStatus:
                  reservationStatus.held,
                paymentWindowMinutes,
                paymentDueAt,
                reservationExpiresAt: paymentDueAt,
                updatedAt: FieldValue.serverTimestamp(),
              },
              {
                merge: true,
              },
            );
          }

          transaction.set(
            paymentSessionReference,
            {
              paymentSessionId: eventId,
              eventId,
              organizerId,
              participantIds,
              lifecycleVersion:
                APPLICATION_LIFECYCLE_VERSION,
              status: "payment_pending",
              gatewayStatus: "not_started",
              currency: "TRY",
              paymentRequired: true,
              paymentWindowMinutes,
              paymentDueAt,
              createdAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            },
            {
              merge: false,
            },
          );
        }

        return {
          freeEvent: false,
          rosterCompleted,
          selectedPlayerCount:
            updatedSelectedPlayerIds.length,
          requiredPlayerCount,
        };
      },
    );

    await writeUserNotification(
      firestore,
      {
        userId: playerId,
        actorId: organizerId,
        eventId,
        type: "application_accepted",
        title: "Başvurun kabul edildi",
        message: result.freeEvent ?
          "Başvurun kabul edildi. Etkinlik adresi ve sohbetin açıldı." :
          "Başvurun kabul edildi. Ödeme süreci bekleniyor.",
        route: "event_detail",
        data: {
          eventId,
          applicationStatus: result.freeEvent ?
            applicationStatus.addressUnlocked :
            applicationStatus.acceptedPaymentPending,
          paymentStatus: result.freeEvent ?
            applicationPaymentStatus.notRequired :
            applicationPaymentStatus.pending,
        },
      },
    );

    if (result.rosterCompleted && result.freeEvent) {
      await createRosterCompletedNotifications({
        firestore,
        eventId,
        organizerId,
      });
    } else if (result.rosterCompleted) {
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
      applicationStatus: result.freeEvent ?
        applicationStatus.addressUnlocked :
        applicationStatus.acceptedPaymentPending,
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
 * Resolves the server-controlled payment window.
 *
 * @param {unknown} value Configured payment window.
 * @return {number} Safe payment window in minutes.
 */
function normalizePaymentWindowMinutes(
  value: unknown,
): number {
  const parsed = Number(value);

  if (
    !Number.isInteger(parsed) ||
    parsed < MIN_PAYMENT_WINDOW_MINUTES ||
    parsed > MAX_PAYMENT_WINDOW_MINUTES
  ) {
    return DEFAULT_PAYMENT_WINDOW_MINUTES;
  }

  return parsed;
}

/**
 * Kadro tamamlandığında ödeme bildirimlerini oluşturur.
 *
 * @param {object} params Bildirim parametreleri.
 * @param {FirebaseFirestore.Firestore} params.firestore Firestore örneği.
 * @param {string} params.eventId Etkinlik kimliği.
 * @param {string} params.organizerId Etkinlik sahibi.
 * @return {Promise<void>} İşlem tamamlandığında sonuçlanır.
 */
async function createRosterCompletedNotifications({
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

  const participantIds = [
    ...new Set([
      organizerId,
      ...readStringList(eventSnapshot.data()?.selectedPlayerIds),
    ]),
  ];

  await Promise.all(
    participantIds.map(async (userId) => {
      await writeUserNotification(
        firestore,
        {
          userId,
          actorId: organizerId,
          eventId,
          type: "event_roster_completed",
          title: "Kadro tamamlandı",
          message:
            "Etkinlik kadrosu tamamlandı. Adres ve sohbet açıldı.",
          route: "event_detail",
          data: {
            eventId,
          },
        },
      );
    }),
  );
}

/**
 * Kadro tamamlandığında ödeme bildirimlerini oluşturur.
 *
 * @param {object} params Bildirim parametreleri.
 * @param {FirebaseFirestore.Firestore} params.firestore Firestore örneği.
 * @param {string} params.eventId Etkinlik kimliği.
 * @param {string} params.organizerId Etkinlik sahibi.
 * @return {Promise<void>} İşlem tamamlandığında sonuçlanır.
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

  await Promise.all(
    uniqueParticipantIds.map(
      async (userId) => {
        await writeUserNotification(
          firestore,
          {
            userId,
            actorId: organizerId,
            eventId,
            type: "event_payment_required",
            title: "Etkinlik durumu güncelleniyor",
            message:
              "Etkinlik kadrosu tamamlandı.",
            route: "event_detail",
            data: {
              eventId,
              paymentStatus: "payment_pending",
            },
          },
        );
      },
    ),
  );
}
