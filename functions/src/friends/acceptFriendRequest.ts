/* eslint-disable require-jsdoc */
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";

const REGION = "europe-west1";

export const acceptFriendRequest = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const currentUserId = request.auth?.uid;

    if (!currentUserId) {
      throw new HttpsError(
        "unauthenticated",
        "Bu işlem için kullanıcı girişi gereklidir.",
      );
    }

    const requestId = readRequiredString(
      request.data,
      "requestId",
      "Arkadaşlık isteği kimliği gereklidir.",
    );

    const firestore = getFirestore();

    const requestReference =
      firestore.collection("friend_requests").doc(requestId);

    await firestore.runTransaction(
      async (transaction) => {
        const requestSnapshot =
          await transaction.get(requestReference);

        if (!requestSnapshot.exists) {
          throw new HttpsError(
            "not-found",
            "Arkadaşlık isteği bulunamadı.",
          );
        }

        const requestData = requestSnapshot.data() ?? {};

        const senderId =
          String(requestData.senderId ?? "").trim();

        const receiverId =
          String(requestData.receiverId ?? "").trim();

        const status =
          String(requestData.status ?? "").trim().toLowerCase();

        if (receiverId !== currentUserId) {
          throw new HttpsError(
            "permission-denied",
            "Bu arkadaşlık isteğini kabul etme yetkiniz yok.",
          );
        }

        if (!senderId) {
          throw new HttpsError(
            "failed-precondition",
            "Arkadaşlık isteği geçersiz.",
          );
        }

        if (status !== "pending") {
          throw new HttpsError(
            "failed-precondition",
            "Bu arkadaşlık isteği artık beklemede değil.",
          );
        }

        const senderReference =
          firestore.collection("users").doc(senderId);

        const receiverReference =
          firestore.collection("users").doc(receiverId);

        const senderFriendReference =
          senderReference.collection("friends").doc(receiverId);

        const receiverFriendReference =
          receiverReference.collection("friends").doc(senderId);

        transaction.set(
          senderFriendReference,
          {
            userId: receiverId,
            friendUid: receiverId,
            createdAt: FieldValue.serverTimestamp(),
          },
        );

        transaction.set(
          receiverFriendReference,
          {
            userId: senderId,
            friendUid: senderId,
            createdAt: FieldValue.serverTimestamp(),
          },
        );

        transaction.delete(requestReference);

        const notificationReference =
          senderReference.collection("notifications").doc();

        transaction.set(
          notificationReference,
          {
            notificationId: notificationReference.id,
            userId: senderId,
            type: "friendAccepted",
            notificationType: "friendAccepted",
            category: "friendAccepted",
            title: "Arkadaşlık İsteği Kabul Edildi",
            message: "Arkadaşlık isteğin kabul edildi.",
            body: "Arkadaşlık isteğin kabul edildi.",
            description: "Arkadaşlık isteğin kabul edildi.",
            senderUid: receiverId,
            route: "publicProfile",
            read: false,
            isRead: false,
            okundu: false,
            data: {
              userId: receiverId,
            },
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          },
        );
      },
    );

    return {
      success: true,
      requestId,
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
