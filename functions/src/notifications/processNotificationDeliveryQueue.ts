/* eslint-disable max-len */
import {
  FieldValue,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import {
  onSchedule,
} from "firebase-functions/v2/scheduler";
import {
  deliverPushNotification,
  evaluateNotificationPreferences,
  nextRetryDate,
  NotificationDeliveryInput,
} from "./notificationDelivery";

const REGION = "europe-west1";
const QUEUE_BATCH_LIMIT = 100;

/**
 * Processes delayed and retry push deliveries.
 */
export const processNotificationDeliveryQueue = onSchedule(
  {
    region: REGION,
    schedule: "every 5 minutes",
    timeZone: "Europe/Istanbul",
    retryCount: 3,
  },
  async () => {
    const firestore = getFirestore();
    const now = new Date();

    const queueSnapshot = await firestore
      .collection("notification_delivery_queue")
      .where("deliverAfter", "<=", Timestamp.fromDate(now))
      .orderBy("deliverAfter", "asc")
      .limit(QUEUE_BATCH_LIMIT)
      .get();

    for (const queueDocument of queueSnapshot.docs) {
      const queueData = queueDocument.data();

      if (String(queueData.status ?? "") !== "pending") {
        continue;
      }

      const userId = String(queueData.userId ?? "").trim();

      if (!userId) {
        await queueDocument.ref.update({
          status: "failed",
          failureReason: "missing_user_id",
          updatedAt: FieldValue.serverTimestamp(),
        });
        continue;
      }

      const userSnapshot = await firestore
        .collection("users")
        .doc(userId)
        .get();

      if (!userSnapshot.exists) {
        await queueDocument.ref.update({
          status: "cancelled",
          failureReason: "user_missing",
          updatedAt: FieldValue.serverTimestamp(),
        });
        continue;
      }

      const input = queueToInput(queueDocument.id, queueData);
      const preferenceDecision = evaluateNotificationPreferences(
        userSnapshot.data() ?? {},
        input.type,
        now,
      );

      if (!preferenceDecision.enabled) {
        await queueDocument.ref.update({
          status: "suppressed_preference",
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        continue;
      }

      if (preferenceDecision.quietUntil) {
        await queueDocument.ref.update({
          deliverAfter: Timestamp.fromDate(
            preferenceDecision.quietUntil,
          ),
          updatedAt: FieldValue.serverTimestamp(),
        });
        continue;
      }

      const targetTokenHashes = readStringList(
        queueData.targetTokenHashes,
      );

      const result = await deliverPushNotification(
        firestore,
        input,
        targetTokenHashes.length > 0 ?
          targetTokenHashes :
          null,
      );

      const nextAttemptCount =
        Number(queueData.attemptCount ?? 0) + 1;

      if (result.retryTokenHashes.length === 0) {
        await queueDocument.ref.update({
          status: result.delivered > 0 ?
            "delivered" :
            "no_active_device",
          deliveredCount: result.delivered,
          attemptCount: nextAttemptCount,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        await updateNotificationDeliveryStatus(
          firestore,
          input,
          result.delivered > 0 ?
            "delivered" :
            "no_active_device",
          result.delivered,
          0,
        );
        continue;
      }

      const retryAt = nextRetryDate(
        nextAttemptCount,
        now,
      );

      if (!retryAt) {
        await queueDocument.ref.update({
          status: "failed",
          failureReason: "retry_limit_reached",
          deliveredCount: result.delivered,
          targetTokenHashes: result.retryTokenHashes,
          attemptCount: nextAttemptCount,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        await updateNotificationDeliveryStatus(
          firestore,
          input,
          "retry_limit_reached",
          result.delivered,
          result.retryTokenHashes.length,
        );
        continue;
      }

      await queueDocument.ref.update({
        status: "pending",
        deliveredCount: result.delivered,
        targetTokenHashes: result.retryTokenHashes,
        attemptCount: nextAttemptCount,
        deliverAfter: Timestamp.fromDate(retryAt),
        updatedAt: FieldValue.serverTimestamp(),
      });

      await updateNotificationDeliveryStatus(
        firestore,
        input,
        "retry_scheduled",
        result.delivered,
        result.retryTokenHashes.length,
      );
    }
  },
);

/**
 * Converts queue data back into a delivery payload.
 *
 * @param {string} notificationId Queue document id.
 * @param {FirebaseFirestore.DocumentData} data Queue data.
 * @return {NotificationDeliveryInput} Delivery payload.
 */
function queueToInput(
  notificationId: string,
  data: FirebaseFirestore.DocumentData,
): NotificationDeliveryInput {
  return {
    notificationId,
    userId: String(data.userId ?? "").trim(),
    type: String(data.type ?? "system").trim(),
    title: String(data.title ?? "Dördüncü").trim(),
    message: String(data.message ?? "Yeni bildirimin var.").trim(),
    route: optionalString(data.route),
    eventId: optionalString(data.eventId),
    eventTitle: optionalString(data.eventTitle),
    data: isRecord(data.data) ? data.data : {},
  };
}

/**
 * Mirrors push delivery state back to the in-app notification.
 *
 * @param {FirebaseFirestore.Firestore} firestore Firestore instance.
 * @param {NotificationDeliveryInput} input Delivery payload.
 * @param {string} status Delivery status.
 * @param {number} deliveredCount Successful token count.
 * @param {number} retryCount Remaining retry token count.
 * @return {Promise<void>} Completes after update.
 */
async function updateNotificationDeliveryStatus(
  firestore: FirebaseFirestore.Firestore,
  input: NotificationDeliveryInput,
  status: string,
  deliveredCount: number,
  retryCount: number,
): Promise<void> {
  await firestore
    .collection("users")
    .doc(input.userId)
    .collection("notifications")
    .doc(input.notificationId)
    .set(
      {
        pushDeliveryStatus: status,
        pushDeliveredCount: deliveredCount,
        pushRetryTokenCount: retryCount,
        pushDeliveryUpdatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
}

/**
 * Returns a trimmed optional string.
 *
 * @param {unknown} value Raw value.
 * @return {string|undefined} Normalized value.
 */
function optionalString(
  value: unknown,
): string | undefined {
  const normalized = String(value ?? "").trim();
  return normalized || undefined;
}

/**
 * Reads a safe string list.
 *
 * @param {unknown} value Raw list.
 * @return {string[]} String list.
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
 * Checks whether a value is a plain record.
 *
 * @param {unknown} value Raw value.
 * @return {boolean} True for records.
 */
function isRecord(
  value: unknown,
): value is Record<string, unknown> {
  return value !== null &&
    typeof value === "object" &&
    !Array.isArray(value);
}
