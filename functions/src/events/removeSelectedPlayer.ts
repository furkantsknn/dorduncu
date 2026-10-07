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
    const reason = readOptionalString(request.data, "reason");

    if (organizerId === playerId) {
      throw new HttpsError(
        "invalid-argument",
        "Etkinlik sahibi kadrodan çıkarılamaz.",
      );
    }

    const firestore = getFirestore();
    const eventReference = firestore.collection("events").doc(eventId);
    const applicationReference = eventReference
      .collection("applications")
      .doc(playerId);
    const paymentSessionReference = firestore
      .collection("paymentSessions")
      .doc(eventId);

    let remainingPlayerIds: string[] = [];

    await firestore.runTransaction(async (transaction) => {
      const eventSnapshot = await transaction.get(eventReference);

      if (!eventSnapshot.exists) {
        throw new HttpsError("not-found", "Etkinlik bulunamadı.");
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

      assertEventNotPast(eventData);

      const paymentStatus = normalizeStatus(eventData.paymentStatus);

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

      remainingPlayerIds = selectedPlayerIds.filter(
        (id) => id !== playerId,
      );

      if (isFreeAccessEvent(eventData)) {
        const requiredPlayerCount = Number(
          eventData.oyuncuSayisi ?? eventData.playerCount ?? 1,
        );
        transaction.update(eventReference, {
          selectedPlayerIds: remainingPlayerIds,
          katilanlar: FieldValue.arrayRemove(playerId),
          participantIds: FieldValue.arrayRemove(playerId),
          chatMemberUids: FieldValue.arrayRemove(playerId),
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
            status: applicationStatus.removed,
            decisionStatus: applicationDecisionStatus.accepted,
            paymentStatus: applicationPaymentStatus.notRequired,
            addressAccessStatus: addressAccessStatus.locked,
            reservationStatus: reservationStatus.released,
            removalReason: reason,
            removedBy: organizerId,
            removedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
        return;
      }

      transaction.update(eventReference, {
        lifecycleVersion: APPLICATION_LIFECYCLE_VERSION,
        selectedPlayerIds: remainingPlayerIds,
        katilanlar: FieldValue.arrayRemove(playerId),
        participantIds: FieldValue.arrayRemove(playerId),
        chatMemberUids: FieldValue.arrayRemove(playerId),
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
          status: applicationStatus.removed,
          decisionStatus: applicationDecisionStatus.accepted,
          paymentStatus: applicationPaymentStatus.notRequired,
          addressAccessStatus: addressAccessStatus.locked,
          reservationStatus: reservationStatus.released,
          paymentDueAt: FieldValue.delete(),
          reservationExpiresAt: FieldValue.delete(),
          removalReason: reason,
          removedBy: organizerId,
          removedAt: FieldValue.serverTimestamp(),
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
          cancellationReason: "roster_incomplete",
          paymentDueAt: FieldValue.delete(),
          cancelledAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    });

    await writeUserNotification(
      firestore,
      {
        userId: playerId,
        actorId: organizerId,
        eventId,
        type: "event_participant_removed",
        title: "Etkinlik kadrosu güncellendi",
        message: reason ?
          `Etkinlik kadrosundan çıkarıldın. ${reason}` :
          "Etkinlik kadrosundan çıkarıldın.",
        route: "event_detail",
        data: {
          eventId,
          reason,
        },
      },
    );

    await writeAuditLog({
      action: "event_participant_removed",
      performedBy: organizerId,
      targetUid: playerId,
      metadata: {
        eventId,
        reason,
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
 * Reads a required string.
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
 * Reads an optional string.
 *
 * @param {unknown} data Callable payload.
 * @param {string} key Field name.
 * @return {string} Normalized string.
 */
function readOptionalString(
  data: unknown,
  key: string,
): string {
  if (data === null || typeof data !== "object") {
    return "";
  }

  return String(
    (data as Record<string, unknown>)[key] ?? "",
  ).trim();
}

/**
 * Normalizes a status.
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
 * @return {boolean} True when paid.
 */
function isPaidStatus(value: string): boolean {
  return value === "paid" ||
    value === "completed" ||
    value === "escrowheld" ||
    value === "escrow_held";
}
