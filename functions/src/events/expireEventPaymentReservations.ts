/* eslint-disable max-len */
import {onSchedule} from "firebase-functions/v2/scheduler";
import {
  FieldValue,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import {
  APPLICATION_LIFECYCLE_VERSION,
  addressAccessStatus,
  applicationDecisionStatus,
  applicationPaymentStatus,
  applicationStatus,
  reservationStatus,
} from "./eventLifecycle";
import {writeAuditLog} from "../audit/writeAuditLog";
import {
  writeUserNotification,
} from "../notifications/writeUserNotification";

const REGION = "europe-west1";
const PAGE_SIZE = 100;

/**
 * Releases payment reservations whose server-controlled payment window expired.
 */
export const expireEventPaymentReservations = onSchedule(
  {
    region: REGION,
    schedule: "every 5 minutes",
    timeZone: "Europe/Istanbul",
    retryCount: 3,
  },
  async () => {
    const firestore = getFirestore();
    const now = Timestamp.now();

    const expiredEvents = await firestore
      .collection("events")
      .where("status", "==", "payment_pending")
      .where("paymentDueAt", "<=", now)
      .orderBy("paymentDueAt", "asc")
      .limit(PAGE_SIZE)
      .get();

    for (const eventSnapshot of expiredEvents.docs) {
      await expireSingleEvent(eventSnapshot.id);
    }
  },
);

/**
 * Expires one unpaid event reservation atomically.
 *
 * @param {string} eventId Event id.
 * @return {Promise<void>} Completes after processing.
 */
async function expireSingleEvent(
  eventId: string,
): Promise<void> {
  const firestore = getFirestore();
  const eventReference = firestore
    .collection("events")
    .doc(eventId);

  const paymentSessionReference = firestore
    .collection("paymentSessions")
    .doc(eventId);

  const applicationSnapshots = await eventReference
    .collection("applications")
    .where(
      "status",
      "==",
      applicationStatus.acceptedPaymentPending,
    )
    .get();

  const releasedPlayerIds: string[] = [];
  let organizerId = "";

  const expired = await firestore.runTransaction(
    async (transaction) => {
      const eventSnapshot = await transaction.get(
        eventReference,
      );

      if (!eventSnapshot.exists) {
        return false;
      }

      const eventData = eventSnapshot.data() ?? {};
      const status = String(
        eventData.status ?? eventData.durum ?? "",
      )
        .trim()
        .toLowerCase();

      const paymentStatus = String(
        eventData.paymentStatus ?? "",
      )
        .trim()
        .toLowerCase();

      const paymentDueAt =
        eventData.paymentDueAt instanceof Timestamp ?
          eventData.paymentDueAt :
          null;

      if (
        status !== "payment_pending" ||
        isPaidStatus(paymentStatus) ||
        paymentDueAt === null ||
        paymentDueAt.toMillis() > Date.now()
      ) {
        return false;
      }

      organizerId = String(
        eventData.olusturanUid ?? "",
      ).trim();

      for (const applicationSnapshot of applicationSnapshots.docs) {
        const applicationData =
          applicationSnapshot.data();

        const applicationStatusValue = String(
          applicationData.status ?? "",
        )
          .trim()
          .toLowerCase();

        if (
          applicationStatusValue !==
          applicationStatus.acceptedPaymentPending
        ) {
          continue;
        }

        releasedPlayerIds.push(
          applicationSnapshot.id,
        );

        transaction.set(
          applicationSnapshot.ref,
          {
            lifecycleVersion:
              APPLICATION_LIFECYCLE_VERSION,
            status: applicationStatus.cancelled,
            decisionStatus:
              applicationDecisionStatus.accepted,
            paymentStatus:
              applicationPaymentStatus.notRequired,
            addressAccessStatus:
              addressAccessStatus.locked,
            reservationStatus:
              reservationStatus.expired,
            cancellationReason:
              "payment_window_expired",
            reservationExpiredAt:
              FieldValue.serverTimestamp(),
            paymentDueAt: FieldValue.delete(),
            reservationExpiresAt:
              FieldValue.delete(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          {
            merge: true,
          },
        );
      }

      transaction.update(
        eventReference,
        {
          lifecycleVersion:
            APPLICATION_LIFECYCLE_VERSION,
          selectedPlayerIds: [],
          katilanlar: [],
          chatMemberUids:
            organizerId ? [organizerId] : [],
          rosterStatus: "collecting",
          durum: "aktif",
          status: "active",
          paymentRequired: false,
          paymentStatus: "not_created",
          paymentDueAt: FieldValue.delete(),
          paymentWindowMinutes:
            FieldValue.delete(),
          rosterCompletedAt:
            FieldValue.delete(),
          reservationExpiredAt:
            FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
      );

      transaction.set(
        paymentSessionReference,
        {
          lifecycleVersion:
            APPLICATION_LIFECYCLE_VERSION,
          status: "expired",
          gatewayStatus: "not_started",
          paymentRequired: false,
          expirationReason:
            "payment_window_expired",
          expiredAt: FieldValue.serverTimestamp(),
          paymentDueAt: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        {
          merge: true,
        },
      );

      return true;
    },
  );

  if (!expired) {
    return;
  }

  await Promise.all(
    releasedPlayerIds.map(
      async (playerId) => {
        await writeUserNotification(
          firestore,
          {
            userId: playerId,
            actorId: organizerId || undefined,
            eventId,
            type: "payment_window_expired",
            title: "Etkinlik durumu güncelleniyor",
            message:
              "Etkinlik rezervasyonun kaldırıldı.",
            route: "event_detail",
            data: {
              eventId,
              reason: "payment_window_expired",
            },
          },
        );
      },
    ),
  );

  await writeAuditLog({
    action: "event_payment_reservation_expired",
    performedBy: "system",
    metadata: {
      eventId,
      organizerId,
      releasedPlayerIds,
      releasedPlayerCount:
        releasedPlayerIds.length,
      lifecycleVersion:
        APPLICATION_LIFECYCLE_VERSION,
    },
  });
}

/**
 * Checks whether a payment status is final-paid.
 *
 * @param {string} value Payment status.
 * @return {boolean} True for a completed payment.
 */
function isPaidStatus(
  value: string,
): boolean {
  return value === "paid" ||
    value === "completed" ||
    value === "success" ||
    value === "succeeded" ||
    value === "escrowheld" ||
    value === "escrow_held";
}
