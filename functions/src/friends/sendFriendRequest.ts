/* eslint-disable require-jsdoc */
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";

const REGION = "europe-west1";

export const sendFriendRequest = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const senderId = request.auth?.uid;

    if (!senderId) {
      throw new HttpsError(
        "unauthenticated",
        "Bu işlem için kullanıcı girişi gereklidir.",
      );
    }

    const targetUserId = readRequiredString(
      request.data,
      "targetUserId",
      "Hedef kullanıcı kimliği gereklidir.",
    );

    if (targetUserId === senderId) {
      throw new HttpsError(
        "failed-precondition",
        "Kendinize arkadaşlık isteği gönderemezsiniz.",
      );
    }

    const firestore = getFirestore();

    const senderReference =
      firestore.collection("users").doc(senderId);

    const targetReference =
      firestore.collection("users").doc(targetUserId);

    const senderFriendReference =
      senderReference
        .collection("friends")
        .doc(targetUserId);

    const requestCollection =
      firestore.collection("friend_requests");

    const existingQuery = requestCollection.where(
      "users",
      "array-contains",
      senderId,
    );

    await firestore.runTransaction(
      async (transaction) => {
        const senderSnapshot =
          await transaction.get(senderReference);

        const targetSnapshot =
          await transaction.get(targetReference);

        const friendSnapshot =
          await transaction.get(senderFriendReference);

        const senderBlockedTarget =
          await transaction.get(
            senderReference.collection("blockedUsers").doc(targetUserId),
          );

        const targetBlockedSender =
          await transaction.get(
            targetReference.collection("blockedUsers").doc(senderId),
          );

        const existingSnapshot =
          await transaction.get(existingQuery);

        if (
          senderBlockedTarget.exists ||
          targetBlockedSender.exists
        ) {
          throw new HttpsError(
            "permission-denied",
            "Engellenmiş kullanıcılar arasında arkadaşlık isteği gönderilemez.",
          );
        }

        if (!senderSnapshot.exists) {
          throw new HttpsError(
            "not-found",
            "Kullanıcı profili bulunamadı.",
          );
        }

        if (!targetSnapshot.exists) {
          throw new HttpsError(
            "not-found",
            "Hedef kullanıcı bulunamadı.",
          );
        }

        if (friendSnapshot.exists) {
          throw new HttpsError(
            "already-exists",
            "Bu kullanıcı zaten arkadaşınız.",
          );
        }

        for (const document of existingSnapshot.docs) {
          const data = document.data();

          const existingSenderId =
            String(data.senderId ?? "").trim();

          const existingReceiverId =
            String(data.receiverId ?? "").trim();

          const status =
            String(data.status ?? "").trim().toLowerCase();

          const sameUsers =
            (
              existingSenderId === senderId &&
              existingReceiverId === targetUserId
            ) ||
            (
              existingSenderId === targetUserId &&
              existingReceiverId === senderId
            );

          if (sameUsers && status === "pending") {
            throw new HttpsError(
              "already-exists",
              "Bu kullanıcıyla bekleyen bir arkadaşlık isteği zaten var.",
            );
          }
        }

        const requestReference =
          requestCollection.doc();

        transaction.set(
          requestReference,
          {
            senderId,
            receiverId: targetUserId,
            status: "pending",
            users: [
              senderId,
              targetUserId,
            ],
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          },
        );

        const notificationReference =
          targetReference
            .collection("notifications")
            .doc();

        transaction.set(
          notificationReference,
          {
            notificationId: notificationReference.id,
            userId: targetUserId,
            type: "friendRequest",
            notificationType: "friendRequest",
            category: "friendRequest",
            title: "Arkadaşlık İsteği",
            message:
              "Sana yeni bir arkadaşlık isteği gönderildi.",
            body:
              "Sana yeni bir arkadaşlık isteği gönderildi.",
            description:
              "Sana yeni bir arkadaşlık isteği gönderildi.",
            senderUid: senderId,
            route: "publicProfile",
            read: false,
            isRead: false,
            okundu: false,
            data: {
              userId: senderId,
            },
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          },
        );
      },
    );

    return {
      success: true,
      targetUserId,
    };
  },
);

function readRequiredString(
  data: unknown,
  key: string,
  errorMessage: string,
): string {
  if (data === null || typeof data !== "object") {
    throw new HttpsError(
      "invalid-argument",
      errorMessage,
    );
  }

  const value = String(
    (data as Record<string, unknown>)[key] ?? "",
  ).trim();

  if (!value) {
    throw new HttpsError(
      "invalid-argument",
      errorMessage,
    );
  }

  return value;
}
