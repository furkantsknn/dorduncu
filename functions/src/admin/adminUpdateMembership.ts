/* eslint-disable max-len */
/* eslint-disable require-jsdoc */
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {
  assertAdminPermission,
  assertAdminPanelAccess,
  assertSuperAdmin,
  getAdminRole,
} from "../security/adminAuthorization";
import {writeAuditLog} from "../audit/writeAuditLog";

export const adminUpdateMembership = onCall(
  {region: "europe-west1", enforceAppCheck: true},
  async (request) => {
    assertAdminPanelAccess(request);
    const data = request.data as Record<string, unknown>;
    const userId = text(data.userId, "Kullanıcı kimliği gerekli.");
    const action = text(data.action, "İşlem türü gerekli.");

    if (action === "plus") {
      assertAdminPermission(request, "finance.manage");
    } else if (action === "playerBadge") {
      // Verification officers must use the A6 assigned-request workflow.
      // This legacy manual badge override is reserved for super admins.
      assertSuperAdmin(request);
    } else {
      throw new HttpsError("invalid-argument", "Geçersiz işlem türü.");
    }

    const adminId = request.auth.uid;
    const adminRole = getAdminRole(request);
    const reason = text(data.reason, "Açıklama gerekli.");
    const enabled = data.enabled === true;
    if (reason.length < 3) throw new HttpsError("invalid-argument", "İşlem açıklaması çok kısa.");

    const db = getFirestore();
    const userRef = db.collection("users").doc(userId);
    const logRef = userRef.collection("admin_actions").doc();
    const userSnap = await userRef.get();
    if (!userSnap.exists) throw new HttpsError("not-found", "Kullanıcı bulunamadı.");

    const batch = db.batch();
    if (action === "plus") {
      batch.set(userRef, {
        plus: enabled,
        plusUpdatedAt: FieldValue.serverTimestamp(),
        plusUpdatedBy: adminId,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      batch.set(logRef, {
        action: enabled ? "plus_membership_granted" : "plus_membership_removed",
        reason, adminId, performedByUid: adminId, targetUserId: userId,
        createdAt: FieldValue.serverTimestamp(),
      });
    } else {
      batch.set(userRef, enabled ? {
        verified: true,
        oyuncuRozeti: true,
        verifiedAt: FieldValue.serverTimestamp(),
        verifiedBy: adminId,
        updatedAt: FieldValue.serverTimestamp(),
      } : {
        verified: false,
        oyuncuRozeti: false,
        badgeRemovedAt: FieldValue.serverTimestamp(),
        badgeRemovedBy: adminId,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      batch.set(logRef, {
        action: enabled ? "player_badge_approved" : "player_badge_removed",
        reason, adminId, performedByUid: adminId, targetUserId: userId,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    await writeAuditLog({action: `admin_membership_${action}`, performedBy: adminId, targetUid: userId, metadata: {enabled, reason, performedByRole: adminRole}});
    return {success: true};
  },
);

function text(value: unknown, message: string): string {
  if (typeof value !== "string") throw new HttpsError("invalid-argument", message);
  const v = value.trim();
  if (!v || v.length > 500) throw new HttpsError("invalid-argument", message);
  return v;
}
