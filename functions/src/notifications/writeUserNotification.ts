import {
  FieldValue,
  Firestore,
  Transaction,
} from "firebase-admin/firestore";

export interface UserNotificationInput {
  userId: string;
  type: string;
  title: string;
  message: string;
  actorId?: string;
  actorName?: string;
  eventId?: string;
  eventTitle?: string;
  route?: string;
  data?: Record<string, unknown>;
}


/**
 * Writes a canonical server-generated notification inside an existing
 * Firestore transaction. The regular notification trigger will deliver FCM
 * only after the transaction commits.
 *
 * @param {Firestore} firestore Firestore instance.
 * @param {Transaction} transaction Existing transaction.
 * @param {UserNotificationInput} input Notification payload.
 * @return {string} Created notification id.
 */
export function writeUserNotificationInTransaction(
  firestore: Firestore,
  transaction: Transaction,
  input: UserNotificationInput,
): string {
  const normalized = normalizeNotificationInput(input);
  const reference = firestore
    .collection("users")
    .doc(normalized.userId)
    .collection("notifications")
    .doc();

  transaction.set(
    reference,
    buildNotificationDocument(reference.id, normalized),
  );

  return reference.id;
}

/**
 * Writes a canonical server-generated user notification.
 *
 * @param {Firestore} firestore Firestore instance.
 * @param {UserNotificationInput} input Notification payload.
 * @return {Promise<string>} Created notification id.
 */
export async function writeUserNotification(
  firestore: Firestore,
  input: UserNotificationInput,
): Promise<string> {
  const normalized = normalizeNotificationInput(input);
  const reference = firestore
    .collection("users")
    .doc(normalized.userId)
    .collection("notifications")
    .doc();

  await reference.set(
    buildNotificationDocument(reference.id, normalized),
  );

  return reference.id;
}

/**
 * Validates and normalizes one notification payload.
 *
 * @param {UserNotificationInput} input Notification payload.
 * @return {UserNotificationInput} Normalized payload.
 */
function normalizeNotificationInput(
  input: UserNotificationInput,
): UserNotificationInput {
  const userId = input.userId.trim();
  const type = input.type.trim();
  const title = input.title.trim();
  const message = input.message.trim();

  if (!userId || !type || !title || !message) {
    throw new Error("Invalid notification payload.");
  }

  return {
    ...input,
    userId,
    type,
    title,
    message,
  };
}

/**
 * Builds the canonical notification document.
 *
 * @param {string} notificationId Notification id.
 * @param {UserNotificationInput} input Normalized payload.
 * @return {Record<string, unknown>} Firestore document.
 */
function buildNotificationDocument(
  notificationId: string,
  input: UserNotificationInput,
): Record<string, unknown> {
  return {
    notificationId,
    notificationVersion: 2,
    userId: input.userId,
    type: input.type,
    notificationType: input.type,
    category: input.type,
    title: input.title,
    message: input.message,
    body: input.message,
    actorId: input.actorId?.trim() || null,
    senderUid: input.actorId?.trim() || null,
    senderName: input.actorName?.trim() || null,
    eventId: input.eventId?.trim() || null,
    relatedEventId: input.eventId?.trim() || null,
    eventTitle: input.eventTitle?.trim() || null,
    route: input.route?.trim() || null,
    data: input.data ?? {},
    source: "server",
    isRead: false,
    read: false,
    okundu: false,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
}
