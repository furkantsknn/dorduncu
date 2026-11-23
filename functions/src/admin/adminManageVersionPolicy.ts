import {assertCurrentAdminSession} from "../security/adminAuthorization";
/* eslint-disable max-len, require-jsdoc */
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {writeAuditLog} from "../audit/writeAuditLog";
import {assertAdminPermission, getAdminRole} from "../security/adminAuthorization";
import {parseVersionPolicy, versionPolicyId} from "../versioning/versionPolicy";

export const adminManageVersionPolicy = onCall(
  {region: "europe-west1", enforceAppCheck: true},
  async (request) => {
    assertAdminPermission(request, "settings.manage");
    await assertCurrentAdminSession(request);
    const input = request.data as Record<string, unknown>;
    const action = String(input.action ?? "save").trim().toLowerCase();
    const adminId = request.auth.uid;
    const db = getFirestore();

    if (action === "rollback") {
      const policyId = versionPolicyId(String(input.platform ?? ""), String(input.target ?? ""));
      const revisionId = String(input.revisionId ?? "").trim();
      if (!/^(android|ios)_(test|production)$/.test(policyId) || !revisionId) {
        throw new HttpsError("invalid-argument", "Geri alma hedefi geçersiz.");
      }
      const historyRef = db.collection("app_version_policy_history").doc(revisionId);
      const policyRef = db.collection("app_version_policies").doc(policyId);
      const publicRef = db.collection("public_app_versions").doc(policyId);
      await db.runTransaction(async (transaction) => {
        const history = await transaction.get(historyRef);
        const previous = history.data()?.previous;
        if (!history.exists || !previous || history.data()?.policyId !== policyId) {
          throw new HttpsError("not-found", "Geri alınacak sürüm bulunamadı.");
        }
        const restored = {...previous, updatedBy: adminId, updatedAt: FieldValue.serverTimestamp()};
        transaction.set(policyRef, restored, {merge: false});
        transaction.set(publicRef, publicProjection(restored), {merge: false});
      });
      await audit(request, "admin_version_policy_rolled_back", {policyId, revisionId});
      return {success: true, policyId};
    }

    if (action !== "save") throw new HttpsError("invalid-argument", "İşlem geçersiz.");
    const policy = parseVersionPolicy(input);
    const policyId = versionPolicyId(policy.platform, policy.target);
    const policyRef = db.collection("app_version_policies").doc(policyId);
    const publicRef = db.collection("public_app_versions").doc(policyId);
    const historyRef = db.collection("app_version_policy_history").doc();
    await db.runTransaction(async (transaction) => {
      const current = await transaction.get(policyRef);
      transaction.set(historyRef, {
        policyId,
        previous: current.exists ? current.data() : null,
        next: policy,
        changedBy: adminId,
        changedAt: FieldValue.serverTimestamp(),
      });
      const stored = {...policy, revisionId: historyRef.id, updatedBy: adminId, updatedAt: FieldValue.serverTimestamp()};
      transaction.set(policyRef, stored, {merge: false});
      transaction.set(publicRef, publicProjection(stored), {merge: false});
    });
    await audit(request, "admin_version_policy_updated", {
      policyId,
      revisionId: historyRef.id,
      latestBuild: policy.latestBuild,
      minimumBuild: policy.minimumBuild,
      storeVersionAvailable: policy.storeVersionAvailable,
    });
    return {success: true, policyId, revisionId: historyRef.id};
  },
);

function publicProjection(data: Record<string, unknown>): Record<string, unknown> {
  const allowed = ["platform", "target", "active", "latestBuild", "minimumBuild", "latestVersion", "minimumVersion", "messageTr", "messageEn", "messageDe", "storeUrl", "storeVersionAvailable", "revisionId", "updatedAt"];
  return Object.fromEntries(allowed.filter((key) => data[key] !== undefined).map((key) => [key, data[key]]));
}

async function audit(request: Parameters<typeof getAdminRole>[0], action: string, metadata: Record<string, unknown>): Promise<void> {
  await writeAuditLog({action, performedBy: request.auth!.uid, metadata: {...metadata, performedByRole: getAdminRole(request)}});
}
