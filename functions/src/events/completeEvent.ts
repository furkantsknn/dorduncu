import {
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";
import {
  APPLICATION_LIFECYCLE_VERSION,
  applicationStatus,
  eventHasEnded,
  reservationStatus,
} from "./eventLifecycle";
import {writeUserNotification} from "../notifications/writeUserNotification";
import {writeAuditLog} from "../audit/writeAuditLog";
import {
  markEventPayoutEligibleInTransaction,
} from "../payments/eventPayoutLifecycle";
import {isPlusMembershipActive} from "../users/plusMembership";
import {syncEventQuotaInTransaction} from "./eventOpenQuotaPolicy";

export type CompleteEventResult =
  | "completed"
  | "already_completed"
  | "not_due"
  | "not_active"
  | "forbidden"
  | "missing";

/**
 * Marks an event completed after its end time.
 *
 * Paid legacy events keep the payout path. Free events do not write paid.
 * The completion is idempotent, so the scheduler and a member open cannot
 * increment completedEventCount twice.
 *
 * @param {object} params Completion input.
 * @param {string} params.eventId Event id.
 * @param {string|null} params.actorUid Member uid, or null for the scheduler.
 * @return {Promise<CompleteEventResult>} Completion outcome.
 */
export async function completeEventIfDue({
  eventId,
  actorUid,
  adminConfirmed = false,
}: {
  eventId: string;
  actorUid: string | null;
  adminConfirmed?: boolean;
}): Promise<CompleteEventResult> {
  const firestore = getFirestore();
  const automatic = actorUid === null;
  const eventReference = firestore.collection("events").doc(eventId);
  const paymentSessionReference = firestore
    .collection("paymentSessions")
    .doc(eventId);

  let organizerId = "";
  let notifyIds: string[] = [];

  const result = await firestore.runTransaction(
    async (transaction): Promise<CompleteEventResult> => {
      const [snapshot, paymentSessionSnapshot] = await Promise.all([
        transaction.get(eventReference),
        transaction.get(paymentSessionReference),
      ]);

      if (!snapshot.exists) {
        return "missing";
      }

      const data = snapshot.data() ?? {};
      organizerId = String(data.olusturanUid ?? "").trim();
      const status = normalizeStatus(data.durum ?? data.status);

      if (isCompletedStatus(status)) {
        return "already_completed";
      }

      if (isCancelledStatus(status)) {
        return "not_active";
      }

      if (!isCompletableStatus(status) &&
          !(status === "expired" && !automatic)) {
        return "not_active";
      }

      if (!eventHasEnded(data)) {
        return "not_due";
      }

      const selectedPlayerIds = readStringList(data.selectedPlayerIds);

      if (
        actorUid && !adminConfirmed &&
      actorUid !== organizerId &&
      !selectedPlayerIds.includes(actorUid) &&
      !readStringList(data.katilanlar).includes(actorUid)
      ) {
        return "forbidden";
      }

      const countIds = [
        ...new Set([
          organizerId,
          ...selectedPlayerIds,
        ].filter((userId) => userId.length > 0)),
      ];
      const userReferences = countIds.map((userId) =>
        firestore.collection("users").doc(userId),
      );
      const userSnapshots = await Promise.all(
        userReferences.map((reference) => transaction.get(reference)),
      );

      const organizerIndex = countIds.indexOf(organizerId);
      await syncEventQuotaInTransaction(
        transaction,
        firestore,
        organizerId,
        Date.now(),
        isPlusMembershipActive(
          organizerIndex >= 0 ? userSnapshots[organizerIndex].data() ?? {} : {},
        ),
        undefined,
        eventId,
      );

      const paymentStatus = normalizeStatus(data.paymentStatus);
      const hasPaidEvent = !automatic && isPaidStatus(paymentStatus);

      if (hasPaidEvent) {
        await markEventPayoutEligibleInTransaction(
          firestore,
          transaction,
          {
            eventId,
            organizerUid: organizerId,
            paymentStatus,
            sourcePaymentOperationId: readOptionalString(
              data.commercialOperationId ??
            paymentSessionSnapshot.data()?.commercialOperationId,
            ),
            eventReference,
            paymentSessionReference,
            paymentSessionExists: paymentSessionSnapshot.exists,
          },
        );
      }

      transaction.update(eventReference, {
        lifecycleVersion: APPLICATION_LIFECYCLE_VERSION,
        durum: automatic ? "expired" : "tamamlandi",
        status: automatic ? "expired" : "completed",
        rosterStatus: automatic ? "expired" : "completed",
        closureReason: automatic ? "time_elapsed" : "occurred_confirmed",
        closureSource: automatic ? "scheduler" :
          adminConfirmed ? "admin" : "member",
        closedAt: FieldValue.serverTimestamp(),
        ...(!automatic ? {completedAt: FieldValue.serverTimestamp()} : {}),
        updatedAt: FieldValue.serverTimestamp(),
        ...(hasPaidEvent ?
          {
            settlementStatus: "held",
            payoutEligibleAt: FieldValue.serverTimestamp(),
          } :
          {}),
      });

      if (hasPaidEvent && paymentSessionSnapshot.exists) {
        transaction.set(
          paymentSessionReference,
          {
            status: "completed",
            settlementStatus: "held",
            payoutEligibleAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
      }

      for (const playerId of selectedPlayerIds) {
        transaction.set(
          eventReference.collection("applications").doc(playerId),
          {
            lifecycleVersion: APPLICATION_LIFECYCLE_VERSION,
            status: automatic ? "expired" : applicationStatus.completed,
            reservationStatus: reservationStatus.released,
            closedAt: FieldValue.serverTimestamp(),
            ...(!automatic ? {completedAt: FieldValue.serverTimestamp()} : {}),
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
      }

      userSnapshots.forEach((userSnapshot, index) => {
        if (!userSnapshot.exists || automatic) {
          return;
        }

        transaction.update(userReferences[index], {
          completedEventCount: FieldValue.increment(1),
          updatedAt: FieldValue.serverTimestamp(),
        });
      });

      notifyIds = countIds;
      return "completed";
    });

  if (result !== "completed") {
    return result;
  }

  await Promise.all(
    notifyIds.map((userId) => writeUserNotification(
      firestore,
      {
        userId,
        actorId: actorUid ?? organizerId,
        eventId,
        type: automatic ? "event_expired" : "event_completed",
        title: automatic ? "Etkinliğin süresi doldu" : "Etkinlik tamamlandı",
        message:
          automatic ?
            "Etkinliğin tarihi geçti. Bu, gerçekleştiği anlamına gelmez." :
            "Katıldığın etkinlik tamamlandı. Değerlendirme yapabilirsin.",
        route: "event_detail",
        data: {
          eventId,
        },
      },
    )),
  );

  await writeAuditLog({
    action: automatic ? "event_expired" : "event_completed",
    performedBy: actorUid ?? "system",
    metadata: {
      eventId,
      participantIds: notifyIds,
      lifecycleVersion: APPLICATION_LIFECYCLE_VERSION,
    },
  });

  return result;
}

/**
 * Normalizes a status string.
 *
 * @param {unknown} value Raw status.
 * @return {string} Normalized status.
 */
function normalizeStatus(value: unknown): string {
  return String(value ?? "").trim().toLowerCase();
}

/**
 * Statuses that the scheduler or a member may complete.
 *
 * @param {string} value Event status.
 * @return {boolean} True when completion is allowed.
 */
function isCompletableStatus(value: string): boolean {
  return value === "aktif" ||
    value === "active" ||
    value === "odeme_bekliyor" ||
    value === "payment_pending" ||
    value === "paymentpending";
}

/**
 * Completed statuses.
 *
 * @param {string} value Event status.
 * @return {boolean} True when already completed.
 */
function isCompletedStatus(value: string): boolean {
  return value === "completed" ||
    value === "tamamlandi" ||
    value === "tamamlandı";
}

/**
 * Cancelled statuses.
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
 * Paid statuses that still use the legacy payout path.
 *
 * @param {string} value Payment status.
 * @return {boolean} True when the event was actually paid.
 */
function isPaidStatus(value: string): boolean {
  return value === "paid" ||
    value === "completed" ||
    value === "escrowheld" ||
    value === "escrow_held";
}

/**
 * Reads a string list.
 *
 * @param {unknown} value Raw list.
 * @return {string[]} Cleaned ids.
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
 * Reads an optional string.
 *
 * @param {unknown} value Raw value.
 * @return {string|null} Normalized value.
 */
function readOptionalString(value: unknown): string | null {
  const normalized = String(value ?? "").trim();
  return normalized || null;
}
