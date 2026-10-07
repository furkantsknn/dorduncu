/* eslint-disable require-jsdoc */
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";

const REGION = "europe-west1";

export const replySupportRequest = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Bu işlem için giriş yapmalısınız.",
      );
    }

    const uid = request.auth.uid;
    const data = request.data as Record<string, unknown>;
    const requestId = readRequiredString(data.requestId, 128);
    const message = readRequiredString(data.message, 4000);

    const firestore = getFirestore();
    const supportReference = firestore
      .collection("support_requests")
      .doc(requestId);

    await firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(supportReference);

      if (!snapshot.exists) {
        throw new HttpsError(
          "not-found",
          "Destek talebi bulunamadı.",
        );
      }

      const current = snapshot.data() ?? {};
      const ownerId = String(current.userId ?? "");
      const currentStatus = String(current.status ?? "new");

      if (ownerId !== uid) {
        throw new HttpsError(
          "permission-denied",
          "Bu destek talebine erişim yetkiniz yok.",
        );
      }

      if (currentStatus === "closed") {
        throw new HttpsError(
          "failed-precondition",
          "Kapatılmış destek talebine mesaj gönderilemez.",
        );
      }

      transaction.set(
        supportReference.collection("messages").doc(),
        {
          senderId: uid,
          senderRole: "user",
          message,
          attachments: [],
          status: "sent",
          edited: false,
          editedAt: null,
          deleted: false,
          deletedAt: null,
          readBy: [uid],
          createdAt: FieldValue.serverTimestamp(),
        },
      );

      transaction.set(
        supportReference.collection("history").doc(),
        {
          action: "message_sent",
          oldStatus: currentStatus,
          newStatus: "reviewing",
          performedByUid: uid,
          performedByRole: "user",
          note: "",
          visibleToUser: true,
          createdAt: FieldValue.serverTimestamp(),
        },
      );

      transaction.set(
        supportReference,
        {
          lastMessage: message,
          lastMessageSenderId: uid,
          lastReplyAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          replyCount: FieldValue.increment(1),
          isReadByAdmin: false,
          isReadByUser: true,
          status: "reviewing",
          closedAt: null,
        },
        {merge: true},
      );
    });

    return {success: true};
  },
);

function readRequiredString(
  value: unknown,
  maxLength: number,
): string {
  if (typeof value !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "Eksik veya geçersiz veri.",
    );
  }

  const normalized = value.trim();

  if (!normalized || normalized.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      "Eksik veya geçersiz veri.",
    );
  }

  return normalized;
}
