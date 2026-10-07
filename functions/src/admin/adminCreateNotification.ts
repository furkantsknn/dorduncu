/* eslint-disable max-len */
/* eslint-disable require-jsdoc */
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {
  assertAdminPermission,
  getAdminRole,
} from "../security/adminAuthorization";
import {writeAuditLog} from "../audit/writeAuditLog";

export const adminCreateNotification = onCall(
  {region: "europe-west1", enforceAppCheck: true},
  async (request) => {
    assertAdminPermission(request, "notifications.manage");
    const adminId = request.auth.uid;
    const adminRole = getAdminRole(request);
    const data = request.data as Record<string, unknown>;
    const title = read(data.title, "Bildirim başlığı gerekli.", 120);
    const message = read(data.message, "Bildirim mesajı gerekli.", 2000);
    const targetType = read(data.targetType, "Hedef türü gerekli.", 32);
    const priority = read(data.priority ?? "normal", "Öncelik gerekli.", 32);
    const targetValue = typeof data.targetValue === "string" ? data.targetValue.trim() : "";
    if (!["all", "plus", "player", "city", "user"].includes(targetType)) throw new HttpsError("invalid-argument", "Geçersiz hedef türü.");
    if (!["normal", "high", "critical"].includes(priority)) throw new HttpsError("invalid-argument", "Geçersiz öncelik.");
    if ((targetType === "city" || targetType === "user") && !targetValue) throw new HttpsError("invalid-argument", "Hedef değeri gerekli.");
    if (targetValue.length > 200) throw new HttpsError("invalid-argument", "Hedef değeri çok uzun.");

    const ref = getFirestore().collection("admin_notifications").doc();
    await ref.set({
      title, message, targetType,
      targetValue: targetType === "city" || targetType === "user" ? targetValue : null,
      priority, status: "pending", createdBy: adminId,
      createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
      sentAt: null, recipientCount: 0, successCount: 0, failureCount: 0,
    });
    await writeAuditLog({action: "admin_create_notification", performedBy: adminId, metadata: {notificationId: ref.id, targetType, targetValue, priority, performedByRole: adminRole}});
    return {success: true, notificationId: ref.id};
  },
);

function read(value: unknown, message: string, max: number): string {
  if (typeof value !== "string") throw new HttpsError("invalid-argument", message);
  const v = value.trim();
  if (!v || v.length > max) throw new HttpsError("invalid-argument", message);
  return v;
}
