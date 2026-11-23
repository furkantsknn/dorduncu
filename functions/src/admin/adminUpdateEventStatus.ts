import {assertCurrentAdminSession} from "../security/adminAuthorization";
/* eslint-disable max-len */
/* eslint-disable require-jsdoc */
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {assertAdminPermission, getAdminRole} from "../security/adminAuthorization";
import {writeAuditLog} from "../audit/writeAuditLog";
import {isPlusMembershipActive} from "../users/plusMembership";
import {OPEN_EVENT_QUOTA_CODE, syncEventQuotaInTransaction} from "../events/eventOpenQuotaPolicy";
import {eventHasEnded} from "../events/eventLifecycle";
import {completeEventIfDue} from "../events/completeEvent";

export const adminUpdateEventStatus = onCall(
  {region: "europe-west1", enforceAppCheck: true},
  async (request) => {
    assertAdminPermission(request, "events.moderate");
    await assertCurrentAdminSession(request);
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

    const firestore = getFirestore();
    const ref = firestore.collection("events").doc(eventId);
    if (status === "completed") {
      if (data.confirmedOccurred !== true) throw new HttpsError("failed-precondition", "Gerçekleşme onayı gerekli.");
      const result = await completeEventIfDue({eventId, actorUid: adminId, adminConfirmed: true});
      if (!["completed", "already_completed"].includes(result)) throw new HttpsError("failed-precondition", "Etkinlik tamamlanamaz.");
      return {success: true};
    }
    await firestore.runTransaction(async (transaction) => {
      const snap = await transaction.get(ref);
      if (!snap.exists) throw new HttpsError("not-found", "Etkinlik bulunamadı.");
      const eventData = snap.data() ?? {};
      if (status === "active" && eventHasEnded(eventData)) throw new HttpsError("failed-precondition", "Tarihi geçmiş etkinlik yeniden açılamaz.");
      const ownerUid = String(eventData.olusturanUid ?? "").trim();
      const user = await transaction.get(firestore.collection("users").doc(ownerUid));
      const reopening = status === "active" && !eventHasEnded(eventData);
      const state = await syncEventQuotaInTransaction(
        transaction, firestore, ownerUid, Date.now(),
        isPlusMembershipActive(user.data() ?? {}),
        reopening ? eventId : undefined,
        reopening ? undefined : eventId,
      );
      if (reopening && !state.plusActive && state.openEventCount > 2) {
        throw new HttpsError(
          "resource-exhausted",
          "Ücretsiz kullanıcının açık etkinlik kotası dolu.",
          {code: OPEN_EVENT_QUOTA_CODE},
        );
      }
      transaction.update(ref, {
        status,
        durum: status,
        closureReason: status === "cancelled" ? "cancelled" : null,
        closureSource: status === "cancelled" ? "admin" : null,
        adminStatusReason: reason,
        adminStatusUpdatedAt: FieldValue.serverTimestamp(),
        adminStatusUpdatedBy: adminId,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    await writeAuditLog({
      action: "admin_update_event_status",
      performedBy: adminId,
      metadata: {eventId, status, reason, performedByRole: adminRole},
    });
    return {success: true};
  },
);

function read(value: unknown, message: string): string {
  if (typeof value !== "string") throw new HttpsError("invalid-argument", message);
  const normalized = value.trim();
  if (!normalized || normalized.length > 128) {
    throw new HttpsError("invalid-argument", message);
  }
  return normalized;
}
