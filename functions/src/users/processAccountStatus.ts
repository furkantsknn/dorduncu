import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  FieldValue,
  Timestamp,
} from "firebase-admin/firestore";

import {firestore} from "../config/firebaseAdmin";
import {assertAdmin} from "../security/assertAdmin";
import {writeAuditLog} from "../audit/writeAuditLog";

interface ProcessAccountStatusRequest {
  uid?: unknown;
  status?: unknown;
  reason?: unknown;
  suspensionDays?: unknown;
}

const ALLOWED_STATUSES = [
  "active",
  "suspended",
  "disabled",
  "blocked",
];

export const processAccountStatus = onCall(
  {
    region: "europe-west1",
    enforceAppCheck: false,
  },
  async (request) => {
    assertAdmin(request);

    const data =
      request.data as ProcessAccountStatusRequest;

    const uid =
      typeof data.uid === "string" ?
        data.uid.trim() :
        "";

    const status =
      typeof data.status === "string" ?
        data.status.trim().toLowerCase() :
        "";

    const reason =
      typeof data.reason === "string" ?
        data.reason.trim() :
        "";

    const suspensionDays =
      typeof data.suspensionDays === "number" &&
      Number.isInteger(data.suspensionDays) ?
        data.suspensionDays :
        null;

    if (!uid) {
      throw new HttpsError(
        "invalid-argument",
        "Kullanıcı kimliği gerekli."
      );
    }

    if (!ALLOWED_STATUSES.includes(status)) {
      throw new HttpsError(
        "invalid-argument",
        "Geçersiz hesap durumu."
      );
    }

    if (status !== "active" && reason.length < 3) {
      throw new HttpsError(
        "invalid-argument",
        "Hesabı kısıtlamak için açıklama gerekli."
      );
    }

    if (
      status === "suspended" &&
      ![3, 7, 15].includes(suspensionDays ?? 0)
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Geçersiz askıya alma süresi."
      );
    }

    if (uid === request.auth.uid && status !== "active") {
      throw new HttpsError(
        "failed-precondition",
        "Yönetici kendi hesabını kısıtlayamaz."
      );
    }

    const userReference =
      firestore.collection("users").doc(uid);

    const userSnapshot =
      await userReference.get();

    if (!userSnapshot.exists) {
      throw new HttpsError(
        "not-found",
        "Kullanıcı bulunamadı."
      );
    }

    const userData = userSnapshot.data() ?? {};
    const oldStatus =
      userData.accountStatus?.toString().trim() ||
      userData.hesapDurumu?.toString().trim() ||
      "active";

    const suspensionEndsAt =
      status === "suspended" &&
      suspensionDays !== null ?
        Timestamp.fromDate(
          new Date(
            Date.now() +
            suspensionDays * 24 * 60 * 60 * 1000
          )
        ) :
        null;

    let notificationTitle: string;
    let notificationMessage: string;

    switch (status) {
    case "suspended":
      notificationTitle = "Hesabın askıya alındı";
      notificationMessage =
        `Hesabın ${suspensionDays} gün süreyle askıya alındı. ` +
        `Neden: ${reason}`;
      break;

    case "disabled":
      notificationTitle =
        "Hesabın pasif duruma getirildi";
      notificationMessage =
        "Hesabın yönetim tarafından pasif duruma getirildi. " +
        `Neden: ${reason}`;
      break;

    case "blocked":
      notificationTitle = "Hesabın engellendi";
      notificationMessage =
        "Hesabın yönetim kararıyla engellendi. " +
        `Neden: ${reason}`;
      break;

    default:
      notificationTitle =
        "Hesabın tekrar aktif edildi";
      notificationMessage =
        reason.length === 0 ?
          "Hesabın tekrar kullanıma açıldı." :
          "Hesabın tekrar kullanıma açıldı. " +
          `Açıklama: ${reason}`;
    }

    const logReference =
      userReference
        .collection("admin_actions")
        .doc();

    const notificationReference =
      userReference
        .collection("notifications")
        .doc();

    const decisionReference =
      userReference
        .collection("management_decisions")
        .doc();

    const batch = firestore.batch();

    batch.set(
      userReference,
      {
        hesapDurumu: status,
        accountStatus: status,
        accountStatusReason: reason,
        accountStatusUpdatedAt:
          FieldValue.serverTimestamp(),
        suspensionDays:
          status === "suspended" ?
            suspensionDays :
            null,
        suspensionEndsAt,
        accountStatusUpdatedBy:
          request.auth.uid,
        updatedAt:
          FieldValue.serverTimestamp(),
      },
      {
        merge: true,
      }
    );

    batch.set(
      logReference,
      {
        action: "account_status_changed",
        oldStatus,
        newStatus: status,
        reason,
        suspensionDays:
          status === "suspended" ?
            suspensionDays :
            null,
        suspensionEndsAt,
        adminId: request.auth.uid,
        performedByUid: request.auth.uid,
        targetUserId: uid,
        createdAt:
          FieldValue.serverTimestamp(),
      }
    );

    batch.set(
      notificationReference,
      {
        notificationId:
          notificationReference.id,
        userId: uid,
        actorId: request.auth.uid,
        type: "accountStatusChanged",
        title: notificationTitle,
        message: notificationMessage,
        accountStatus: status,
        reason,
        isRead: false,
        read: false,
        okundu: false,
        createdAt:
          FieldValue.serverTimestamp(),
        updatedAt:
          FieldValue.serverTimestamp(),
      }
    );

    batch.set(
      decisionReference,
      {
        decisionId: decisionReference.id,
        userId: uid,
        adminId: request.auth.uid,
        type: "account_status",
        oldStatus,
        newStatus: status,
        title: notificationTitle,
        message: notificationMessage,
        reason,
        suspensionDays:
          status === "suspended" ?
            suspensionDays :
            null,
        suspensionEndsAt,
        status: "completed",
        canAppeal: status !== "active",
        createdAt:
          FieldValue.serverTimestamp(),
        updatedAt:
          FieldValue.serverTimestamp(),
      }
    );

    await batch.commit();

    await writeAuditLog({
      action: "processAccountStatus",
      performedBy: request.auth.uid,
      targetUid: uid,
      metadata: {
        oldStatus,
        newStatus: status,
        reason,
        suspensionDays,
      },
    });

    return {
      success: true,
      uid,
      oldStatus,
      newStatus: status,
    };
  }
);
