/* eslint-disable max-len */
import {
  getFirestore,
} from "firebase-admin/firestore";
import {
  onDocumentCreated,
} from "firebase-functions/v2/firestore";
import {processPushDelivery} from "./processPushDelivery";
import {
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
    retry: true,
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
    const input = toDeliveryInput(uid, notificationId, data);
    const ref = await queuePushDelivery(firestore, input, new Date());
    await processPushDelivery(ref);
  },
);

/**
 * Returns an accurate state for the initial FCM attempt.
 *
 * @param {number} deliveredCount Successful device count.
 * @param {number} retryTokenCount Transiently failed device count.
 * @return {string} Persisted delivery state.
 */
export function initialDeliveryStatus(
  deliveredCount: number,
  retryTokenCount: number,
): string {
  if (retryTokenCount > 0) {
    return deliveredCount > 0 ? "partial_retry_scheduled" : "retry_scheduled";
  }
  return deliveredCount > 0 ? "delivered" : "no_active_device";
}

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
