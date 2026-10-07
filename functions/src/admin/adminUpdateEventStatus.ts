/* eslint-disable max-len */
/* eslint-disable require-jsdoc */
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {
  assertAdminPermission,
  getAdminRole,
} from "../security/adminAuthorization";
import {writeAuditLog} from "../audit/writeAuditLog";

export const adminUpdateEventStatus = onCall(
  {region: "europe-west1", enforceAppCheck: true},
  async (request) => {
    assertAdminPermission(request, "events.moderate");
    const adminId = request.auth.uid;
    const adminRole = getAdminRole(request);
    const data = request.data as Record<string, unknown>;
    const eventId = read(data.eventId, "Etkinlik kimliği gerekli.");
    const status = read(data.status, "Durum gerekli.").toLowerCase();
    const reason = typeof data.reason === "string" ? data.reason.trim() : "";
    if (!["active", "completed", "cancelled", "hidden"].includes(status)) {
      throw new HttpsError("invalid-argument", "Geçersiz etkinlik durumu.");
    }
    if (status !== "active" && reason.length < 3) {
      throw new HttpsError("invalid-argument", "İşlem açıklaması gerekli.");
    }
    if (reason.length > 500) throw new HttpsError("invalid-argument", "Açıklama çok uzun.");

    const ref = getFirestore().collection("events").doc(eventId);
    const snap = await ref.get();
    if (!snap.exists) throw new HttpsError("not-found", "Etkinlik bulunamadı.");
    await ref.update({
      status, durum: status, adminStatusReason: reason,
      adminStatusUpdatedAt: FieldValue.serverTimestamp(),
      adminStatusUpdatedBy: adminId, updatedAt: FieldValue.serverTimestamp(),
    });
    await writeAuditLog({action: "admin_update_event_status", performedBy: adminId, metadata: {eventId, status, reason, performedByRole: adminRole}});
    return {success: true};
  },
);

function read(value: unknown, message: string): string {
  if (typeof value !== "string") throw new HttpsError("invalid-argument", message);
  const v = value.trim();
  if (!v || v.length > 128) throw new HttpsError("invalid-argument", message);
  return v;
}
