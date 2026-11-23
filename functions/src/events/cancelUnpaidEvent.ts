import {onCall, HttpsError} from "firebase-functions/v2/https";
import {
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";
import {
  APPLICATION_LIFECYCLE_VERSION,
  addressAccessStatus,
  applicationPaymentStatus,
  applicationStatus,
  assertEventNotPast,
  reservationStatus,
} from "./eventLifecycle";
import {
  writeUserNotification,
} from "../notifications/writeUserNotification";
import {writeAuditLog} from "../audit/writeAuditLog";
import {isPlusMembershipActive} from "../users/plusMembership";
import {syncEventQuotaInTransaction} from "./eventOpenQuotaPolicy";

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
    const eventReference = firestore.collection("events").doc(eventId);
    const paymentSessionReference = firestore
      .collection("paymentSessions")
      .doc(eventId);

    let affectedUserIds: string[] = [];

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
          "Bu etkinliği iptal etme yetkiniz bulunmuyor.",
        );
      }

      const eventStatus = normalizeStatus(
        eventData.durum ?? eventData.status,
      );

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

      assertEventNotPast(eventData);

      const paymentStatus = normalizeStatus(
        eventData.paymentStatus ?? "not_required",
      );

      if (isPaidStatus(paymentStatus)) {
        throw new HttpsError(
          "failed-precondition",
          "Ödeme alınmış etkinlik bu yöntemle iptal edilemez.",
        );
      }

      const organizerSnapshot = await transaction.get(
        firestore.collection("users").doc(organizerId),
      );
      await syncEventQuotaInTransaction(
        transaction,
        firestore,
        organizerId,
        Date.now(),
        isPlusMembershipActive(organizerSnapshot.data() ?? {}),
        undefined,
        eventId,
      );

      affectedUserIds = [
        ...new Set([
          ...readStringList(eventData.selectedPlayerIds),
          ...readStringList(eventData.katilanlar),
          ...readStringList(eventData.basvuranOyuncuIds),
        ]),
      ].filter((userId) => userId && userId !== organizerId);

      transaction.update(eventReference, {
        lifecycleVersion: APPLICATION_LIFECYCLE_VERSION,
        durum: "cancelled",
        status: "cancelled",
        rosterStatus: "cancelled",
        selectedPlayerIds: [],
        katilanlar: [organizerId],
        chatMemberUids: [organizerId],
        paymentRequired: false,
        paymentStatus: "cancelled",
        paymentDueAt: FieldValue.delete(),
        paymentWindowMinutes: FieldValue.delete(),
        cancellationReason: reason,
        cancelledBy: organizerId,
        cancelledAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      for (const userId of affectedUserIds) {
        const applicationReference = eventReference
          .collection("applications")
          .doc(userId);

        transaction.set(
          applicationReference,
          {
            lifecycleVersion: APPLICATION_LIFECYCLE_VERSION,
            status: applicationStatus.cancelled,
            paymentStatus: applicationPaymentStatus.notRequired,
            addressAccessStatus: addressAccessStatus.locked,
            reservationStatus: reservationStatus.released,
            paymentDueAt: FieldValue.delete(),
            reservationExpiresAt: FieldValue.delete(),
            cancellationReason: reason,
            cancelledBy: organizerId,
            cancelledAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
      }

      transaction.set(
        paymentSessionReference,
        {
          lifecycleVersion: APPLICATION_LIFECYCLE_VERSION,
          eventId,
          organizerId,
          status: "cancelled",
          gatewayStatus: "not_started",
          paymentRequired: false,
          paymentDueAt: FieldValue.delete(),
          cancellationReason: reason,
          cancelledBy: organizerId,
          cancelledAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    });

    await Promise.all(
      affectedUserIds.map(
        async (userId) => writeUserNotification(
          firestore,
          {
            userId,
            actorId: organizerId,
            eventId,
            type: "event_cancelled",
            title: "Etkinlik iptal edildi",
            message: `Katılacağın etkinlik iptal edildi. ${reason}`,
            route: "event_detail",
            data: {
              eventId,
              reason,
            },
          },
        ),
      ),
    );

    await writeAuditLog({
      action: "event_cancelled_unpaid",
      performedBy: organizerId,
      metadata: {
        eventId,
        reason,
        affectedUserIds,
        lifecycleVersion: APPLICATION_LIFECYCLE_VERSION,
      },
    });

    return {
      success: true,
      eventId,
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
 * Normalizes status text.
 *
 * @param {unknown} value Raw status.
 * @return {string} Normalized status.
 */
function normalizeStatus(value: unknown): string {
  return String(value ?? "").trim().toLowerCase();
}

/**
 * Checks final paid states.
 *
 * @param {string} value Payment status.
 * @return {boolean} True when paid.
 */
function isPaidStatus(value: string): boolean {
  return value === "escrowheld" ||
    value === "escrow_held" ||
    value === "paid" ||
    value === "completed";
}

/**
 * Checks cancelled status.
 *
 * @param {string} value Event status.
 * @return {boolean} True when cancelled.
 */
function isCancelledStatus(value: string): boolean {
  return value === "cancelled" ||
    value === "iptal" ||
    value === "iptal_edildi";
}

/**
 * Checks completed status.
 *
 * @param {string} value Event status.
 * @return {boolean} True when completed.
 */
function isCompletedStatus(value: string): boolean {
  return value === "completed" ||
    value === "tamamlandi" ||
    value === "tamamlandı";
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
