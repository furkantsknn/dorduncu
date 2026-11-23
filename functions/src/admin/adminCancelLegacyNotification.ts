/* eslint-disable max-len, require-jsdoc */
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {assertAdminPermission, assertCurrentAdminSession} from "../security/adminAuthorization";
import {writeAuditLogInTransaction} from "../audit/writeAuditLog";

export const adminCancelLegacyNotification = onCall({region: "europe-west1", enforceAppCheck: true}, async (request) => {
  assertAdminPermission(request, "notifications.manage");
  await assertCurrentAdminSession(request);
  const id = String(request.data?.notificationId ?? ""); const reason = String(request.data?.reason ?? "").trim();
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(id) || reason.length < 3 || reason.length > 500) throw new HttpsError("invalid-argument", "Bildirim ve iptal gerekçesi gerekli.");
  const db = getFirestore(); const ref = db.doc(`admin_notifications/${id}`);
  return db.runTransaction(async (tx) => {
    const [snapshot, receipts, notifications, queued] = await Promise.all([
      tx.get(ref), tx.get(ref.collection("recipients").limit(1)),
      tx.get(db.collectionGroup("notifications").where("data.adminNotificationId", "==", id).limit(1)),
      tx.get(db.collection("notification_delivery_queue").where("data.adminNotificationId", "==", id).limit(1)),
    ]);
    const data = snapshot.data();
    if (!data) throw new HttpsError("not-found", "Bildirim bulunamadı.");
    if (data.status === "cancelled" && data.cancellationKind === "legacy_unsent") return {success: true, idempotentReplay: true};
    const zero = ["recipientCount", "inAppCount", "sentCount", "successCount", "failureCount", "resultCount", "fcmAcceptedCount", "simulatedCount", "attemptCount", "skippedCount"].every((key) => data[key] == null || data[key] === 0);
    const knownLegacyCounters = ["recipientCount", "successCount", "failureCount"].every((key) => data[key] === 0);
    const timestampEvidence = ["sentAt", "startedAt", "dispatchStartedAt", "leaseUntil", "completedAt", "deliveredAt", "pushAttemptStartedAt"].some((key) => data[key] != null);
    if (![undefined, null, 0].includes(data.dispatchVersion) || data.status !== "pending" || !knownLegacyCounters || !zero || timestampEvidence || data.leaseOwner || data.cursor || data.distributionComplete || !receipts.empty || !notifications.empty || !queued.empty) throw new HttpsError("failed-precondition", "Gönderilmediği kanıtlanamayan veya aktif bildirim bu yoldan iptal edilemez.");
    tx.update(ref, {status: "cancelled", cancellationKind: "legacy_unsent", cancellationReason: reason, cancelledBy: request.auth.uid, cancelledAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()});
    writeAuditLogInTransaction(db, tx, {action: "admin_cancel_legacy_notification", performedBy: request.auth.uid, metadata: {notificationId: id, reason, previousStatus: "pending", cancellationKind: "legacy_unsent"}});
    return {success: true, idempotentReplay: false};
  });
});
