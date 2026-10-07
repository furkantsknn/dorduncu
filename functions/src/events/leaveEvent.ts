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
  isFreeAccessEvent,
  reservationStatus,
} from "./eventLifecycle";
import {
  writeUserNotification,
} from "../notifications/writeUserNotification";
import {writeAuditLog} from "../audit/writeAuditLog";

const REGION = "europe-west1";

export const leaveEvent = onCall(
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
    const eventReference = firestore.collection("events").doc(eventId);
    const applicationReference = eventReference
      .collection("applications")
      .doc(playerId);
    const paymentSessionReference = firestore
      .collection("paymentSessions")
      .doc(eventId);

    let organizerId = "";
    let remainingPlayerIds: string[] = [];

    await firestore.runTransaction(async (transaction) => {
      const eventSnapshot = await transaction.get(eventReference);

      if (!eventSnapshot.exists) {
        throw new HttpsError("not-found", "Etkinlik bulunamadı.");
      }

      const eventData = eventSnapshot.data() ?? {};
      organizerId = String(eventData.olusturanUid ?? "").trim();

      if (organizerId === playerId) {
        throw new HttpsError(
          "failed-precondition",
          "Etkinlik sahibi etkinlikten ayrılamaz.",
        );
      }

      const status = normalizeStatus(
        eventData.durum ?? eventData.status,
      );

      if (isClosedStatus(status)) {
        throw new HttpsError(
          "failed-precondition",
          "Bu etkinlikten artık ayrılamazsınız.",
        );
      }

      assertEventNotPast(eventData);

      const paymentStatus = normalizeStatus(eventData.paymentStatus);

      if (isPaidStatus(paymentStatus)) {
        throw new HttpsError(
          "failed-precondition",
          "Ödeme tamamlandıktan sonra etkinlikten doğrudan ayrılamazsınız.",
        );
      }

      const selectedPlayerIds = readStringList(
        eventData.selectedPlayerIds,
      );

      if (!selectedPlayerIds.includes(playerId)) {
        throw new HttpsError(
          "failed-precondition",
          "Bu etkinliğin katılımcısı değilsiniz.",
        );
      }

      remainingPlayerIds = selectedPlayerIds.filter(
        (uid) => uid !== playerId,
      );

      const participants = readStringList(
        eventData.katilanlar ?? eventData.participantIds,
      ).filter((uid) => uid !== playerId);

      const chatMembers = readStringList(
        eventData.chatMemberUids ?? eventData.chatMembers,
      ).filter((uid) => uid !== playerId);

      if (isFreeAccessEvent(eventData)) {
        const requiredPlayerCount = Number(
          eventData.oyuncuSayisi ?? eventData.playerCount ?? 1,
        );
        transaction.update(eventReference, {
          selectedPlayerIds: remainingPlayerIds,
          katilanlar: participants,
          participantIds: participants,
          chatMemberUids: chatMembers,
          rosterStatus:
            remainingPlayerIds.length >= requiredPlayerCount ?
              "full" :
              "collecting",
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.set(
          applicationReference,
          {
            lifecycleVersion: APPLICATION_LIFECYCLE_VERSION,
            status: applicationStatus.left,
            decisionStatus: applicationDecisionStatus.accepted,
            paymentStatus: applicationPaymentStatus.notRequired,
            addressAccessStatus: addressAccessStatus.locked,
            reservationStatus: reservationStatus.released,
            leftAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
        return;
      }

      transaction.update(eventReference, {
        lifecycleVersion: APPLICATION_LIFECYCLE_VERSION,
        selectedPlayerIds: remainingPlayerIds,
        katilanlar: participants,
        participantIds: participants,
        chatMemberUids: chatMembers,
        durum: "aktif",
        status: "active",
        rosterStatus: "collecting",
        paymentRequired: false,
        paymentStatus: "not_created",
        paymentDueAt: FieldValue.delete(),
        paymentWindowMinutes: FieldValue.delete(),
        rosterCompletedAt: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      transaction.set(
        applicationReference,
        {
          lifecycleVersion: APPLICATION_LIFECYCLE_VERSION,
          status: applicationStatus.left,
          decisionStatus: applicationDecisionStatus.accepted,
          paymentStatus: applicationPaymentStatus.notRequired,
          addressAccessStatus: addressAccessStatus.locked,
          reservationStatus: reservationStatus.released,
          paymentDueAt: FieldValue.delete(),
          reservationExpiresAt: FieldValue.delete(),
          leftAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );

      for (const remainingPlayerId of remainingPlayerIds) {
        const remainingApplicationReference = eventReference
          .collection("applications")
          .doc(remainingPlayerId);

        transaction.set(
          remainingApplicationReference,
          {
            lifecycleVersion: APPLICATION_LIFECYCLE_VERSION,
            status: applicationStatus.acceptedWaitingRoster,
            decisionStatus: applicationDecisionStatus.accepted,
            paymentStatus: applicationPaymentStatus.notRequired,
            addressAccessStatus: addressAccessStatus.locked,
            reservationStatus: reservationStatus.held,
            paymentDueAt: FieldValue.delete(),
            reservationExpiresAt: FieldValue.delete(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
      }

      transaction.set(
        paymentSessionReference,
        {
          lifecycleVersion: APPLICATION_LIFECYCLE_VERSION,
          status: "cancelled",
          gatewayStatus: "not_started",
          paymentRequired: false,
          cancellationReason: "participant_left",
          paymentDueAt: FieldValue.delete(),
          cancelledAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    });

    if (organizerId) {
      await writeUserNotification(
        firestore,
        {
          userId: organizerId,
          actorId: playerId,
          eventId,
          type: "event_participant_left",
          title: "Oyuncu etkinlikten ayrıldı",
          message: "Bir oyuncu etkinlik kadrosundan ayrıldı.",
          route: "event_detail",
          data: {
            eventId,
            playerId,
          },
        },
      );
    }

    await writeAuditLog({
      action: "event_participant_left",
      performedBy: playerId,
      targetUid: organizerId || undefined,
      metadata: {
        eventId,
        remainingPlayerIds,
        lifecycleVersion: APPLICATION_LIFECYCLE_VERSION,
      },
    });

    return {
      success: true,
      eventId,
      playerId,
    };
  },
);

/**
 * Reads a required string from callable data.
 *
 * @param {unknown} data Callable payload.
 * @param {string} key Field name.
 * @param {string} errorMessage Validation message.
 * @return {string} Normalized string.
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

/**
 * Normalizes a status value.
 *
 * @param {unknown} value Status value.
 * @return {string} Normalized status.
 */
function normalizeStatus(value: unknown): string {
  return String(value ?? "").trim().toLowerCase();
}

/**
 * Reads a safe string list.
 *
 * @param {unknown} value Raw list.
 * @return {string[]} String list.
 */
function readStringList(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((item) => String(item).trim())
    .filter((item) => item.length > 0);
}

/**
 * Checks final paid states.
 *
 * @param {string} value Payment state.
 * @return {boolean} True when payment is final.
 */
function isPaidStatus(value: string): boolean {
  return value === "paid" ||
    value === "completed" ||
    value === "escrowheld" ||
    value === "escrow_held";
}

/**
 * Checks whether event no longer permits leaving.
 *
 * @param {string} value Event status.
 * @return {boolean} True for closed event.
 */
function isClosedStatus(value: string): boolean {
  return value === "tamamlandi" ||
    value === "tamamlandı" ||
    value === "completed" ||
    value === "iptal" ||
    value === "cancelled";
}
