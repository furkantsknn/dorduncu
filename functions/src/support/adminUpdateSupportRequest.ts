import {assertCurrentAdminSession} from "../security/adminAuthorization";
/* eslint-disable require-jsdoc */
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {
  assertAdminPermission,
  getAdminRole,
} from "../security/adminAuthorization";
import {writeAuditLog} from "../audit/writeAuditLog";

const REGION = "europe-west1";
const STATUSES = new Set(["new", "reviewing", "answered", "closed"]);

export const adminUpdateSupportRequest = onCall(
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
    const status = readRequiredString(data.status, 32);

    if (!STATUSES.has(status)) {
      throw new HttpsError("invalid-argument", "Geçersiz destek durumu.");
    }

    const firestore = getFirestore();
    const supportReference = firestore
      .collection("support_requests")
      .doc(requestId);

    let oldStatus = "";
    let ticketId = "";

    await firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(supportReference);

      if (!snapshot.exists) {
        throw new HttpsError("not-found", "Destek talebi bulunamadı.");
      }

      const current = snapshot.data() ?? {};
      oldStatus = String(current.status ?? "new");
      ticketId = String(current.ticketId ?? "");

      if (oldStatus === status) {
        return;
      }

      transaction.set(
        supportReference,
        {
          status,
          closedAt:
            status === "closed" ? FieldValue.serverTimestamp() : null,
          isReadByAdmin: true,
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );

      transaction.set(
        supportReference.collection("history").doc(),
        {
          action: "status_changed",
          oldStatus,
          newStatus: status,
          performedByUid: adminId,
          performedByRole: adminRole,
          note: "",
          ticketId,
          visibleToUser: true,
          createdAt: FieldValue.serverTimestamp(),
        },
      );
    });

    await writeAuditLog({
      action: "admin_update_support_status",
      performedBy: adminId,
      metadata: {
        requestId,
        ticketId,
        oldStatus,
        newStatus: status,
        performedByRole: adminRole,
      },
    });

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
