/* eslint-disable max-len */
import {
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";
import {
  onDocumentCreated,
} from "firebase-functions/v2/firestore";
import {
  deliverPushNotification,
  evaluateNotificationPreferences,
  nextRetryDate,
  NotificationDeliveryInput,
  queuePushDelivery,
} from "./notificationDelivery";

const REGION = "europe-west1";

/**
 * Delivers each server-created in-app notification through FCM.
 */
export const deliverUserNotification = onDocumentCreated(
  {
    document: "users/{uid}/notifications/{notificationId}",
    region: REGION,
  },
  async (event) => {
    const snapshot = event.data;

    if (!snapshot) {
      return;
    }

    const data = snapshot.data() ?? {};

    if (String(data.source ?? "").trim() !== "server") {
      return;
    }

    const uid = String(event.params.uid ?? "").trim();
    const notificationId = String(
      event.params.notificationId ?? "",
    ).trim();

    if (!uid || !notificationId) {
      return;
    }

    const firestore = getFirestore();
    const userSnapshot = await firestore
      .collection("users")
      .doc(uid)
      .get();

    if (!userSnapshot.exists) {
      await snapshot.ref.update({
        pushDeliveryStatus: "user_missing",
        pushDeliveryUpdatedAt: FieldValue.serverTimestamp(),
      });
      return;
    }

    const input = toDeliveryInput(
      uid,
      notificationId,
      data,
    );

    const decision = evaluateNotificationPreferences(
      userSnapshot.data() ?? {},
      input.type,
      new Date(),
    );

    if (!decision.enabled) {
      await snapshot.ref.update({
        pushDeliveryStatus: "suppressed_preference",
        pushDeliveryUpdatedAt: FieldValue.serverTimestamp(),
      });
      return;
    }

    if (decision.quietUntil) {
      await queuePushDelivery(
        firestore,
        input,
        decision.quietUntil,
      );

      await snapshot.ref.update({
        pushDeliveryStatus: "queued_quiet_hours",
        pushDeliverAfter: decision.quietUntil,
        pushDeliveryUpdatedAt: FieldValue.serverTimestamp(),
      });
      return;
    }

    const result = await deliverPushNotification(
      firestore,
      input,
    );

    if (result.retryTokenHashes.length > 0) {
      const retryAt = nextRetryDate(0, new Date());

      if (retryAt) {
        await queuePushDelivery(
          firestore,
          input,
          retryAt,
          0,
          result.retryTokenHashes,
        );
      }
    }

    await snapshot.ref.update({
      pushDeliveryStatus:
        result.delivered > 0 ? "delivered" : "no_active_device",
      pushDeliveredCount: result.delivered,
      pushRetryTokenCount: result.retryTokenHashes.length,
      pushDeliveryUpdatedAt: FieldValue.serverTimestamp(),
    });
  },
);

/**
 * Converts Firestore notification data to a delivery payload.
 *
 * @param {string} uid Recipient id.
 * @param {string} notificationId Notification id.
 * @param {FirebaseFirestore.DocumentData} data Notification document data.
 * @return {NotificationDeliveryInput} Delivery payload.
 */
function toDeliveryInput(
  uid: string,
  notificationId: string,
  data: FirebaseFirestore.DocumentData,
): NotificationDeliveryInput {
  return {
    notificationId,
    userId: uid,
    type: String(
      data.type ??
      data.notificationType ??
      data.category ??
      "system",
    ).trim(),
    title: String(data.title ?? "Dördüncü").trim(),
    message: String(
      data.message ??
      data.body ??
      "Yeni bildirimin var.",
    ).trim(),
    route: optionalString(data.route),
    eventId: optionalString(
      data.eventId ?? data.relatedEventId,
    ),
    eventTitle: optionalString(data.eventTitle),
    data: isRecord(data.data) ? data.data : {},
  };
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
