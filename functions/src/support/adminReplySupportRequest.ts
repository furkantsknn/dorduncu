import {assertCurrentAdminSession} from "../security/adminAuthorization";
/* eslint-disable require-jsdoc */
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {
  assertAdminPermission,
  getAdminRole,
} from "../security/adminAuthorization";
import {writeAuditLog} from "../audit/writeAuditLog";
import {writeUserNotification} from "../notifications/writeUserNotification";

const REGION = "europe-west1";

export const adminReplySupportRequest = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    assertAdminPermission(request, "support.manage");
    await assertCurrentAdminSession(request);

    const adminId = request.auth.uid;
    const adminRole = getAdminRole(request);
    const data = request.data as Record<string, unknown>;
    const requestId = readRequiredString(data.requestId, 128);
    const response = readOptionalString(data.response, 4000);
    const adminNotes = readOptionalString(data.adminNotes, 4000);

    if (!response && !adminNotes) {
      throw new HttpsError(
        "invalid-argument",
        "Cevap veya admin notu gereklidir.",
      );
    }

    const firestore = getFirestore();
    const supportReference = firestore
      .collection("support_requests")
      .doc(requestId);
    const privateReference = supportReference
      .collection("private")
      .doc("admin");

    let ticketId = "";
    let userId = "";

    await firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(supportReference);

      if (!snapshot.exists) {
        throw new HttpsError("not-found", "Destek talebi bulunamadı.");
      }

      const privateSnapshot = await transaction.get(privateReference);
      const current = snapshot.data() ?? {};
      const privateData = privateSnapshot.data() ?? {};
      const currentStatus = String(current.status ?? "new");
      const currentPrivateNotes = String(
        privateData.adminNotes ?? current.adminNotes ?? "",
      );

      ticketId = String(current.ticketId ?? "");
      userId = String(current.userId ?? "");

      if (currentStatus === "closed" && response) {
        throw new HttpsError(
          "failed-precondition",
          "Kapatılmış talebe cevap gönderilemez.",
        );
      }

      const updateData: Record<string, unknown> = {
        adminNotes: FieldValue.delete(),
        isReadByAdmin: true,
        updatedAt: FieldValue.serverTimestamp(),
      };

      if (response) {
        updateData.adminResponse = response;
        updateData.lastMessage = response;
        updateData.lastMessageSenderId = adminId;
        updateData.lastReplyAt = FieldValue.serverTimestamp();
        updateData.isReadByUser = false;
        updateData.status = "answered";
        updateData.replyCount = FieldValue.increment(1);

        if (!current.firstResponseAt) {
          updateData.firstResponseAt = FieldValue.serverTimestamp();
        }
      }

      transaction.set(supportReference, updateData, {merge: true});

      if (adminNotes !== currentPrivateNotes) {
        transaction.set(
          privateReference,
          {
            adminNotes,
            updatedAt: FieldValue.serverTimestamp(),
            updatedBy: adminId,
          },
          {merge: true},
        );

        transaction.set(
          supportReference.collection("history").doc(),
          {
            action: "admin_notes_updated",
            oldStatus: null,
            newStatus: null,
            performedByUid: adminId,
            performedByRole: adminRole,
            note: "Admin internal note updated.",
            ticketId,
            visibleToUser: false,
            createdAt: FieldValue.serverTimestamp(),
          },
        );
      }

      if (response) {
        transaction.set(
          supportReference.collection("messages").doc(),
          {
            senderId: adminId,
            senderRole: "admin",
            message: response,
            attachments: [],
            status: "sent",
            edited: false,
            editedAt: null,
            deleted: false,
            deletedAt: null,
            readBy: [adminId],
            createdAt: FieldValue.serverTimestamp(),
          },
        );

        transaction.set(
          supportReference.collection("history").doc(),
          {
            action: "admin_response_added",
            oldStatus: currentStatus,
            newStatus: "answered",
            performedByUid: adminId,
            performedByRole: adminRole,
            note: "",
            ticketId,
            visibleToUser: true,
            createdAt: FieldValue.serverTimestamp(),
          },
        );
      }
    });

    await writeAuditLog({
      action: response ? "admin_reply_support" : "admin_note_support",
      performedBy: adminId,
      targetUid: userId || undefined,
      metadata: {
        requestId,
        ticketId,
        hasResponse: Boolean(response),
        hasAdminNotes: Boolean(adminNotes),
        performedByRole: adminRole,
      },
    });

    if (response && userId) {
      await writeUserNotification(firestore, {
        notificationId: `support_${requestId}_answered`,
        userId,
        type: "support",
        title: ticketId ? `Destek talebi ${ticketId}` :
          "Destek talebin yanıtlandı",
        message: ticketId ? `${ticketId} numaralı talebin yanıtlandı.` :
          "Destek talebin yanıtlandı.",
        route: "support_request",
        data: {requestId, ticketId},
      });
    }

    return {success: true};
  },
);

function readRequiredString(value: unknown, maxLength: number): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "Eksik veya geçersiz veri.");
  }

  const normalized = value.trim();

  if (!normalized || normalized.length > maxLength) {
    throw new HttpsError("invalid-argument", "Eksik veya geçersiz veri.");
  }

  return normalized;
}

function readOptionalString(value: unknown, maxLength: number): string {
  if (value == null) {
    return "";
  }

  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "Geçersiz metin alanı.");
  }

  const normalized = value.trim();

  if (normalized.length > maxLength) {
    throw new HttpsError("invalid-argument", "Metin alanı çok uzun.");
  }

  return normalized;
}
