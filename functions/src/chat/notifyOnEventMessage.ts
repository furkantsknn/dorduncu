/* eslint-disable valid-jsdoc, require-jsdoc */
import {
  onDocumentCreated,
} from "firebase-functions/v2/firestore";
import {
  DocumentReference,
  getFirestore,
} from "firebase-admin/firestore";
import {
  writeUserNotification,
} from "../notifications/writeUserNotification";
import {
  hasFreeMembershipAccess,
  isFreeAccessEvent,
} from "../events/eventLifecycle";

const REGION = "europe-west1";

export const notifyOnEventMessage = onDocumentCreated(
  {
    document: "events/{eventId}/messages/{messageId}",
    region: REGION,
  },
  async (event) => {
    const snapshot = event.data;

    if (!snapshot) {
      return;
    }

    const messageData = snapshot.data() ?? {};
    const eventId = String(event.params.eventId ?? "").trim();
    const senderUid = String(messageData.senderUid ?? "").trim();

    if (!eventId || !senderUid) {
      return;
    }

    const firestore = getFirestore();
    const eventSnapshot = await firestore
      .collection("events")
      .doc(eventId)
      .get();

    if (!eventSnapshot.exists) {
      return;
    }

    const eventData = eventSnapshot.data() ?? {};
    const recipientIds = new Set(chatRecipientIds(eventData, senderUid));

    if (recipientIds.size === 0) {
      return;
    }

    const recipients = await filterPaymentEligibleRecipients(
      eventId,
      eventData,
      [...recipientIds],
    );

    const blockedRecipientIds = await findBlockedRecipients(
      senderUid,
      recipients,
    );

    const allowedRecipients = recipients.filter(
      (userId) => !blockedRecipientIds.has(userId),
    );

    if (allowedRecipients.length === 0) {
      return;
    }

    const userSnapshots = await firestore.getAll(...allowedRecipients.map(
      (userId) => firestore.collection("users").doc(userId),
    ));
    const languageByUser = new Map(userSnapshots.map((userSnapshot) => [
      userSnapshot.id,
      String(userSnapshot.data()?.languageCode ??
        userSnapshot.data()?.preferredLanguage ?? "tr"),
    ]));

    await Promise.all(
      allowedRecipients.map(
        async (userId) => {
          const content = chatNotificationContent(languageByUser.get(userId));
          return writeUserNotification(firestore, {
            notificationId: chatNotificationId(eventId, snapshot.id),
            userId,
            actorId: senderUid,
            eventId,
            type: "message",
            title: content.title,
            message: content.message,
            route: "event_chat",
            data: chatNotificationData(eventId),
          });
        },
      ),
    );
  },
);

export function chatNotificationContent(language?: string): {
  title: string; message: string;
} {
  switch (String(language ?? "tr").toLowerCase().split("-")[0]) {
  case "en":
    return {title: "New message", message: "You have a new message."};
  case "de":
    return {title: "Neue Nachricht", message: "Du hast eine neue Nachricht."};
  default:
    return {title: "Yeni mesaj", message: "Yeni bir mesajın var."};
  }
}

export function chatNotificationData(eventId: string): Record<string, string> {
  return {eventId: eventId.trim()};
}

/** Returns unique chat recipients excluding the sender. */
export function chatRecipientIds(
  eventData: Record<string, unknown>,
  senderUid: string,
): string[] {
  const ids = new Set<string>([
    String(eventData.olusturanUid ?? "").trim(),
    ...readStringList(eventData.selectedPlayerIds),
    ...readStringList(eventData.katilanlar),
    ...readStringList(eventData.participantIds),
    ...readStringList(eventData.chatMemberUids),
  ]);
  ids.delete("");
  ids.delete(senderUid.trim());
  return [...ids];
}

/** Stable per-message id makes Firestore trigger retries idempotent. */
export function chatNotificationId(eventId: string, messageId: string): string {
  return `chat_${eventId.trim()}_${messageId.trim()}`;
}

/**
 * Filters notification recipients by canonical payment access.
 *
 * Organizer always remains eligible. Lifecycle v2 participants only receive
 * chat notifications after their own application is paid and unlocked.
 * Legacy events preserve previous behavior.
 *
 * @param {string} eventId Event id.
 * @param {FirebaseFirestore.DocumentData} eventData Event data.
 * @param {string[]} recipientIds Candidate recipients.
 * @return {Promise<string[]>} Payment-eligible recipients.
 */
async function filterPaymentEligibleRecipients(
  eventId: string,
  eventData: FirebaseFirestore.DocumentData,
  recipientIds: string[],
): Promise<string[]> {
  if (Number(eventData.lifecycleVersion ?? 0) !== 2) {
    return recipientIds;
  }

  const organizerUid = String(
    eventData.olusturanUid ?? "",
  ).trim();

  const firestore = getFirestore();
  const participantIds = recipientIds.filter(
    (uid) => uid !== organizerUid,
  );

  const applicationSnapshots = await Promise.all(
    participantIds.map((uid) => firestore
      .collection("events")
      .doc(eventId)
      .collection("applications")
      .doc(uid)
      .get()),
  );

  const paidParticipantIds = new Set<string>();

  for (
    let index = 0;
    index < applicationSnapshots.length;
    index += 1
  ) {
    const snapshot = applicationSnapshots[index];

    if (!snapshot.exists) {
      continue;
    }

    const data = snapshot.data() ?? {};
    const paymentStatus = String(
      data.paymentStatus ?? "",
    )
      .trim()
      .toLowerCase();
    const addressStatus = String(
      data.addressAccessStatus ?? "",
    )
      .trim()
      .toLowerCase();

    const freeMember = isFreeAccessEvent(eventData) &&
      hasFreeMembershipAccess(data);

    if (
      freeMember ||
      (
        addressStatus === "unlocked" &&
        (
          paymentStatus === "paid" ||
          paymentStatus === "completed"
        )
      )
    ) {
      paidParticipantIds.add(participantIds[index]);
    }
  }

  return recipientIds.filter(
    (uid) =>
      uid === organizerUid ||
      paidParticipantIds.has(uid),
  );
}

/**
 * Finds recipients who have a block relationship with the sender.
 *
 * @param {string} senderUid Sender user id.
 * @param {string[]} recipientIds Candidate recipients.
 * @return {Promise<Set<string>>} Blocked recipient ids.
 */
async function findBlockedRecipients(
  senderUid: string,
  recipientIds: string[],
): Promise<Set<string>> {
  const firestore = getFirestore();
  const references: DocumentReference[] = [];

  for (const recipientId of recipientIds) {
    references.push(
      firestore
        .collection("users")
        .doc(senderUid)
        .collection("blockedUsers")
        .doc(recipientId),
    );
    references.push(
      firestore
        .collection("users")
        .doc(recipientId)
        .collection("blockedUsers")
        .doc(senderUid),
    );
  }

  if (references.length === 0) {
    return new Set<string>();
  }

  const snapshots = await firestore.getAll(...references);
  const blockedRecipientIds = new Set<string>();

  for (let index = 0; index < recipientIds.length; index += 1) {
    const firstSnapshot = snapshots[index * 2];
    const secondSnapshot = snapshots[index * 2 + 1];

    if (firstSnapshot.exists || secondSnapshot.exists) {
      blockedRecipientIds.add(recipientIds[index]);
    }
  }

  return blockedRecipientIds;
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
