/* eslint-disable max-len */
import {
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";
import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  hasFreeMembershipAccess,
  isFreeAccessEvent,
} from "../events/eventLifecycle";

const REGION = "europe-west1";
const MAX_MESSAGE_LENGTH = 2000;

interface EventChatContext {
  eventId: string;
  eventReference: FirebaseFirestore.DocumentReference;
  eventData: FirebaseFirestore.DocumentData;
}

/**
 * Creates an event-chat message through server-authoritative state.
 */
export const sendEventMessage = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const eventId = readRequiredString(
      request.data,
      "eventId",
      "Etkinlik kimliği gereklidir.",
    );
    const text = readMessageText(request.data);

    const firestore = getFirestore();
    const context = await requireChatAccess(
      uid,
      eventId,
    );

    await assertOrganizerBlockPolicy(
      uid,
      context.eventData,
    );

    const senderProfile = await loadSenderProfile(uid);
    const messageReference = context.eventReference
      .collection("messages")
      .doc();

    await firestore.runTransaction(async (transaction) => {
      const freshEvent = await transaction.get(
        context.eventReference,
      );

      if (!freshEvent.exists) {
        throw new HttpsError(
          "not-found",
          "Etkinlik bulunamadı.",
        );
      }

      const freshData = freshEvent.data() ?? {};

      const applicationData =
        await readApplicationInTransaction(
          transaction,
          context.eventReference,
          uid,
          freshData,
        );

      if (!isChatMember(uid, freshData, applicationData)) {
        throw new HttpsError(
          "permission-denied",
          "Sohbet ödeme tamamlandıktan sonra açılır.",
        );
      }

      transaction.set(
        messageReference,
        {
          messageId: messageReference.id,
          eventId,
          type: "text",
          text,
          senderUid: uid,
          senderName: senderProfile.displayName,
          senderPhotoUrl: senderProfile.photoUrl,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: null,
          edited: false,
          deleted: false,
          readBy: [uid],
          source: "server",
          messageVersion: 2,
        },
      );

      transaction.update(
        context.eventReference,
        {
          lastMessage: "Yeni mesaj",
          lastMessageId: messageReference.id,
          lastMessageType: "text",
          lastMessageAt: FieldValue.serverTimestamp(),
          lastMessageSenderUid: uid,
          lastMessageSenderName: FieldValue.delete(),
          lastMessageSenderPhotoUrl: FieldValue.delete(),
          lastMessageReadBy: [uid],
          [`typingUsers.${uid}`]: FieldValue.delete(),
        },
      );
    });

    return {
      success: true,
      messageId: messageReference.id,
    };
  },
);

/**
 * Edits the authenticated user's own event-chat message.
 */
export const editEventMessage = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const eventId = readRequiredString(
      request.data,
      "eventId",
      "Etkinlik kimliği gereklidir.",
    );
    const messageId = readRequiredString(
      request.data,
      "messageId",
      "Mesaj kimliği gereklidir.",
    );
    const text = readMessageText(request.data);
    const context = await requireChatAccess(uid, eventId);

    await assertOrganizerBlockPolicy(
      uid,
      context.eventData,
    );

    const messageReference = context.eventReference
      .collection("messages")
      .doc(messageId);

    await getFirestore().runTransaction(async (transaction) => {
      const [eventSnapshot, messageSnapshot] = await Promise.all([
        transaction.get(context.eventReference),
        transaction.get(messageReference),
      ]);

      if (!eventSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "Etkinlik bulunamadı.",
        );
      }

      const eventData = eventSnapshot.data() ?? {};
      const applicationData =
        await readApplicationInTransaction(
          transaction,
          context.eventReference,
          uid,
          eventData,
        );

      if (!isChatMember(uid, eventData, applicationData)) {
        throw new HttpsError(
          "permission-denied",
          "Sohbet ödeme tamamlandıktan sonra açılır.",
        );
      }

      if (!messageSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "Mesaj bulunamadı.",
        );
      }

      const messageData = messageSnapshot.data() ?? {};

      if (String(messageData.senderUid ?? "") !== uid) {
        throw new HttpsError(
          "permission-denied",
          "Yalnızca kendi mesajını düzenleyebilirsin.",
        );
      }

      if (messageData.deleted === true) {
        throw new HttpsError(
          "failed-precondition",
          "Silinmiş mesaj düzenlenemez.",
        );
      }

      transaction.update(
        messageReference,
        {
          text,
          updatedAt: FieldValue.serverTimestamp(),
          edited: true,
        },
      );

      if (
        String(eventData.lastMessageId ?? "") === messageId
      ) {
        transaction.update(
          context.eventReference,
          {
            lastMessage: "Yeni mesaj",
          },
        );
      }
    });

    return {
      success: true,
    };
  },
);

/**
 * Soft-deletes the authenticated user's own event-chat message.
 */
export const deleteEventMessage = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const eventId = readRequiredString(
      request.data,
      "eventId",
      "Etkinlik kimliği gereklidir.",
    );
    const messageId = readRequiredString(
      request.data,
      "messageId",
      "Mesaj kimliği gereklidir.",
    );
    const context = await requireChatAccess(uid, eventId);

    await assertOrganizerBlockPolicy(
      uid,
      context.eventData,
    );

    const messageReference = context.eventReference
      .collection("messages")
      .doc(messageId);

    await getFirestore().runTransaction(async (transaction) => {
      const [eventSnapshot, messageSnapshot] = await Promise.all([
        transaction.get(context.eventReference),
        transaction.get(messageReference),
      ]);

      if (!eventSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "Etkinlik bulunamadı.",
        );
      }

      const eventData = eventSnapshot.data() ?? {};
      const applicationData =
        await readApplicationInTransaction(
          transaction,
          context.eventReference,
          uid,
          eventData,
        );

      if (!isChatMember(uid, eventData, applicationData)) {
        throw new HttpsError(
          "permission-denied",
          "Sohbet ödeme tamamlandıktan sonra açılır.",
        );
      }

      if (!messageSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "Mesaj bulunamadı.",
        );
      }

      const messageData = messageSnapshot.data() ?? {};

      if (String(messageData.senderUid ?? "") !== uid) {
        throw new HttpsError(
          "permission-denied",
          "Yalnızca kendi mesajını silebilirsin.",
        );
      }

      transaction.update(
        messageReference,
        {
          text: "",
          deleted: true,
          deletedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
      );
    });

    await refreshLastMessage(eventId);

    return {
      success: true,
    };
  },
);

/**
 * Resolves an event and verifies chat membership.
 *
 * @param {string} uid Authenticated user id.
 * @param {string} eventId Event id.
 * @return {Promise<EventChatContext>} Verified chat context.
 */
async function requireChatAccess(
  uid: string,
  eventId: string,
): Promise<EventChatContext> {
  const eventReference = getFirestore()
    .collection("events")
    .doc(eventId);

  const eventSnapshot = await eventReference.get();

  if (!eventSnapshot.exists) {
    throw new HttpsError(
      "not-found",
      "Etkinlik bulunamadı.",
    );
  }

  const eventData = eventSnapshot.data() ?? {};
  let applicationData:
    FirebaseFirestore.DocumentData | undefined;

  if (!isOrganizer(uid, eventData)) {
    const applicationSnapshot = await eventReference
      .collection("applications")
      .doc(uid)
      .get();

    applicationData = applicationSnapshot.exists ?
      applicationSnapshot.data() :
      undefined;
  }

  if (!isChatMember(uid, eventData, applicationData)) {
    throw new HttpsError(
      "permission-denied",
      "Sohbet ödeme tamamlandıktan sonra açılır.",
    );
  }

  return {
    eventId,
    eventReference,
    eventData,
  };
}

/**
 * Enforces the existing organizer block rule on the server.
 *
 * @param {string} uid Current user id.
 * @param {FirebaseFirestore.DocumentData} eventData Event data.
 * @return {Promise<void>} Completes when allowed.
 */
async function assertOrganizerBlockPolicy(
  uid: string,
  eventData: FirebaseFirestore.DocumentData,
): Promise<void> {
  const organizerId = firstString(
    eventData,
    [
      "olusturanUid",
      "creatorUid",
      "ownerUid",
      "hostUid",
    ],
  );

  if (!organizerId || organizerId === uid) {
    return;
  }

  const firestore = getFirestore();
  const [firstBlock, secondBlock] = await Promise.all([
    firestore
      .collection("users")
      .doc(uid)
      .collection("blockedUsers")
      .doc(organizerId)
      .get(),
    firestore
      .collection("users")
      .doc(organizerId)
      .collection("blockedUsers")
      .doc(uid)
      .get(),
  ]);

  if (firstBlock.exists || secondBlock.exists) {
    throw new HttpsError(
      "permission-denied",
      "Engelleme ilişkisi bulunan kullanıcılarla bu sohbet kullanılamaz.",
    );
  }
}

/**
 * Loads trusted sender identity from the user document.
 *
 * @param {string} uid User id.
 * @return {Promise<{displayName: string, photoUrl: string}>} Sender profile.
 */
async function loadSenderProfile(
  uid: string,
): Promise<{
  displayName: string;
  photoUrl: string;
}> {
  const userSnapshot = await getFirestore()
    .collection("users")
    .doc(uid)
    .get();

  const data = userSnapshot.data() ?? {};

  return {
    displayName:
      firstString(
        data,
        [
          "displayName",
          "profilAdi",
          "name",
          "adSoyad",
        ],
      ) || "Üye",
    photoUrl: firstString(
      data,
      [
        "photoUrl",
        "profilFotografi",
        "profilePhotoUrl",
        "avatarUrl",
      ],
    ),
  };
}

/**
 * Rebuilds the event's last-message projection after a deletion.
 *
 * @param {string} eventId Event id.
 * @return {Promise<void>} Completes after projection update.
 */
async function refreshLastMessage(
  eventId: string,
): Promise<void> {
  const firestore = getFirestore();
  const eventReference = firestore
    .collection("events")
    .doc(eventId);

  const snapshot = await eventReference
    .collection("messages")
    .orderBy("createdAt", "desc")
    .limit(20)
    .get();

  const latest = snapshot.docs.find(
    (document) => document.data().deleted !== true,
  );

  if (!latest) {
    await eventReference.update({
      lastMessage: "",
      lastMessageId: FieldValue.delete(),
      lastMessageType: FieldValue.delete(),
      lastMessageAt: FieldValue.delete(),
      lastMessageSenderUid: FieldValue.delete(),
      lastMessageSenderName: FieldValue.delete(),
      lastMessageSenderPhotoUrl: FieldValue.delete(),
      lastMessageReadBy: [],
    });
    return;
  }

  const data = latest.data();

  await eventReference.update({
    lastMessage: "Yeni mesaj",
    lastMessageId: latest.id,
    lastMessageType: String(data.type ?? "text"),
    lastMessageAt:
      data.createdAt ?? FieldValue.serverTimestamp(),
    lastMessageSenderUid: String(data.senderUid ?? ""),
    lastMessageSenderName: FieldValue.delete(),
    lastMessageSenderPhotoUrl: FieldValue.delete(),
    lastMessageReadBy: Array.isArray(data.readBy) ?
      data.readBy :
      [],
  });
}

/**
 * Checks whether a user belongs to the event chat.
 *
 * Every participant requires their own application to be paid and
 * address-unlocked before private chat access is granted.
 *
 * @param {string} uid User id.
 * @param {FirebaseFirestore.DocumentData} eventData Event data.
 * @param {FirebaseFirestore.DocumentData|undefined} applicationData
 * Canonical application data.
 * @return {boolean} True when the user belongs to the chat.
 */
function isChatMember(
  uid: string,
  eventData: FirebaseFirestore.DocumentData,
  applicationData?: FirebaseFirestore.DocumentData,
): boolean {
  if (isFreeAccessEvent(eventData)) {
    if (isOrganizer(uid, eventData)) {
      return true;
    }

    return stringList(eventData.selectedPlayerIds).includes(uid) &&
      hasFreeMembershipAccess(applicationData);
  }

  if (!hasCompletedEventPayment(eventData)) {
    return false;
  }

  if (isOrganizer(uid, eventData)) {
    return true;
  }

  const memberIds = new Set<string>([
    ...stringList(eventData.selectedPlayerIds),
    ...stringList(eventData.katilanlar),
    ...stringList(eventData.participantIds),
    ...stringList(eventData.participantUids),
    ...stringList(eventData.acceptedUserUids),
    ...stringList(eventData.chatMemberUids),
    ...stringList(eventData.memberUids),
  ]);

  if (!memberIds.has(uid)) {
    return false;
  }

  return hasPaidCanonicalChatAccess(applicationData);
}

/**
 * Reads the participant application inside an event transaction.
 *
 * @param {FirebaseFirestore.Transaction} transaction Firestore transaction.
 * @param {FirebaseFirestore.DocumentReference} eventReference Event ref.
 * @param {string} uid User id.
 * @param {FirebaseFirestore.DocumentData} eventData Event data.
 * @return {Promise<FirebaseFirestore.DocumentData|undefined>} App data.
 */
async function readApplicationInTransaction(
  transaction: FirebaseFirestore.Transaction,
  eventReference: FirebaseFirestore.DocumentReference,
  uid: string,
  eventData: FirebaseFirestore.DocumentData,
): Promise<FirebaseFirestore.DocumentData | undefined> {
  if (isOrganizer(uid, eventData)) {
    return undefined;
  }

  const applicationSnapshot = await transaction.get(
    eventReference.collection("applications").doc(uid),
  );

  return applicationSnapshot.exists ?
    applicationSnapshot.data() :
    undefined;
}

/**
 * Requires the organizer-owned event payment to be completed before chat.
 *
 * @param {FirebaseFirestore.DocumentData} eventData Event data.
 * @return {boolean} True when the event payment is complete.
 */
function hasCompletedEventPayment(
  eventData: FirebaseFirestore.DocumentData,
): boolean {
  const paymentStatus = String(
    eventData.paymentStatus ?? "",
  )
    .trim()
    .toLowerCase();

  return new Set([
    "paid",
    "completed",
    "success",
    "succeeded",
    "escrowheld",
    "escrow_held",
  ]).has(paymentStatus);
}

/**
 * Checks canonical paid chat access.
 *
 * @param {FirebaseFirestore.DocumentData|undefined} applicationData App data.
 * @return {boolean} True when payment and address state allow chat.
 */
function hasPaidCanonicalChatAccess(
  applicationData?: FirebaseFirestore.DocumentData,
): boolean {
  if (!applicationData) {
    return false;
  }

  const paymentStatus = String(
    applicationData.paymentStatus ?? "",
  )
    .trim()
    .toLowerCase();

  const addressStatus = String(
    applicationData.addressAccessStatus ?? "",
  )
    .trim()
    .toLowerCase();

  return (
    addressStatus === "unlocked" &&
    (
      paymentStatus === "paid" ||
      paymentStatus === "completed"
    )
  );
}

/**
 * Checks lifecycle version.
 *
 * @param {FirebaseFirestore.DocumentData} eventData Event data.
 * @return {boolean} True for canonical lifecycle v2.
 */
/**
 * Checks whether a user is the event organizer.
 *
 * @param {string} uid User id.
 * @param {FirebaseFirestore.DocumentData} eventData Event data.
 * @return {boolean} True for organizer.
 */
function isOrganizer(
  uid: string,
  eventData: FirebaseFirestore.DocumentData,
): boolean {
  return firstString(
    eventData,
    [
      "olusturanUid",
      "creatorUid",
      "ownerUid",
      "hostUid",
    ],
  ) === uid;
}

/**
 * Reads a required string from callable data.
 *
 * @param {unknown} data Callable payload.
 * @param {string} field Field name.
 * @param {string} message Error message.
 * @return {string} Normalized string.
 */
function readRequiredString(
  data: unknown,
  field: string,
  message: string,
): string {
  if (
    data === null ||
    typeof data !== "object" ||
    Array.isArray(data)
  ) {
    throw new HttpsError(
      "invalid-argument",
      message,
    );
  }

  const value = String(
    (data as Record<string, unknown>)[field] ?? "",
  ).trim();

  if (!value) {
    throw new HttpsError(
      "invalid-argument",
      message,
    );
  }

  return value;
}

/**
 * Reads and validates message text.
 *
 * @param {unknown} data Callable payload.
 * @return {string} Normalized text.
 */
function readMessageText(data: unknown): string {
  const text = readRequiredString(
    data,
    "text",
    "Mesaj metni gereklidir.",
  );

  if (text.length > MAX_MESSAGE_LENGTH) {
    throw new HttpsError(
      "invalid-argument",
      `Mesaj en fazla ${MAX_MESSAGE_LENGTH} karakter olabilir.`,
    );
  }

  return text;
}

/**
 * Requires authentication.
 *
 * @param {string|undefined} uid Optional auth uid.
 * @return {string} Authenticated uid.
 */
function requireUid(uid: string | undefined): string {
  const normalized = String(uid ?? "").trim();

  if (!normalized) {
    throw new HttpsError(
      "unauthenticated",
      "Mesajlaşmak için giriş yapmalısın.",
    );
  }

  return normalized;
}

/**
 * Returns the first non-empty string from candidate fields.
 *
 * @param {FirebaseFirestore.DocumentData} data Source data.
 * @param {string[]} keys Candidate keys.
 * @return {string} First value.
 */
function firstString(
  data: FirebaseFirestore.DocumentData,
  keys: string[],
): string {
  for (const key of keys) {
    const value = String(data[key] ?? "").trim();

    if (value) {
      return value;
    }
  }

  return "";
}

/**
 * Reads a safe string list.
 *
 * @param {unknown} value Raw value.
 * @return {string[]} String list.
 */
function stringList(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((item) => String(item).trim())
    .filter((item) => item.length > 0);
}
