import {assertCurrentAdminSession} from "../security/adminAuthorization";
import {FieldValue} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {writeAuditLogInTransaction} from "../audit/writeAuditLog";
import {firestore} from "../config/firebaseAdmin";
import {
  applyAdminBadgeDecision,
  badgeIsEntitled,
  readBadgeEntitlementState,
} from "../market/badgeEntitlementPolicy";
import {assertAdminPermission} from "../security/adminAuthorization";

const idPattern = /^[a-z0-9_]{1,80}$/;

export const adminManageUserBadge = onCall(
  {region: "europe-west1", enforceAppCheck: true},
  async (request) => {
    assertAdminPermission(request, "content.manage");
    await assertCurrentAdminSession(request);
    const input = request.data as Record<string, unknown>;
    const targetUid = requiredText(input.targetUid, 128);
    const badgeId = requiredText(input.badgeId, 80);
    const action = requiredText(input.action, 16);
    const reason = requiredText(input.reason, 500);
    if (
      !idPattern.test(badgeId) ||
      (action !== "grant" && action !== "remove")
    ) {
      throw new HttpsError("invalid-argument", "Invalid badge operation.");
    }

    return firestore.runTransaction(async (transaction) => {
      const userRef = firestore.collection("users").doc(targetUid);
      const productRef = firestore.collection("badge_products").doc(badgeId);
      const ownedRef = userRef.collection("owned_badges").doc(badgeId);
      const [user, product, owned] = await Promise.all([
        transaction.get(userRef),
        transaction.get(productRef),
        transaction.get(ownedRef),
      ]);
      if (!user.exists) throw new HttpsError("not-found", "User not found.");
      if (!product.exists && !owned.exists) {
        throw new HttpsError("not-found", "Badge not found.");
      }

      const beforeData = owned.data() ?? {};
      const before = badgeIsEntitled(beforeData);
      const previousState = readBadgeEntitlementState(beforeData);
      const catalog = product.data() ?? beforeData;
      const grant = action === "grant";
      if (
        beforeData.adminGranted === grant &&
        beforeData.adminBlocked === !grant
      ) {
        return {success: true, unchanged: true, before, after: before};
      }
      const payload: Record<string, unknown> = {
        badgeId,
        productId: badgeId,
        adminGranted: grant,
        adminBlocked: !grant,
        adminGrantSource: grant ? "admin_manual" : FieldValue.delete(),
        adminGrantedAt: grant ?
          FieldValue.serverTimestamp() : FieldValue.delete(),
        adminGrantedBy: grant ? request.auth.uid : FieldValue.delete(),
        adminDecisionReason: reason,
        adminDecisionBy: request.auth.uid,
        adminDecisionAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (!owned.exists) {
        Object.assign(payload, {
          gameId: String(catalog.gameId ?? badgeId),
          gameName: String(catalog.gameName ?? ""),
          title: String(catalog.title ?? ""),
          emoji: String(catalog.emoji ?? ""),
          imageUrl: String(catalog.imageUrl ?? ""),
          source: "admin_grant",
          equipped: grant,
          createdAt: FieldValue.serverTimestamp(),
        });
      } else if (!grant) {
        payload.equipped = false;
      }
      transaction.set(ownedRef, payload, {merge: true});
      const nextDecision = applyAdminBadgeDecision(beforeData, action);
      const afterData = {...beforeData, ...nextDecision};
      const after = badgeIsEntitled(afterData);
      const nextState = readBadgeEntitlementState(afterData);
      writeAuditLogInTransaction(firestore, transaction, {
        action: grant ? "user_badge_admin_granted" : "user_badge_admin_removed",
        performedBy: request.auth.uid,
        targetUid,
        metadata: {
          badgeId,
          operation: action,
          reason,
          before,
          after,
          previousState,
          nextState,
        },
      });
      return {success: true, unchanged: before === after, before, after};
    });
  },
);

/**
 * Reads a required bounded string.
 * @param {unknown} value Raw value.
 * @param {number} max Maximum length.
 * @return {string} Normalized text.
 */
function requiredText(value: unknown, max: number): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "Required text is missing.");
  }
  const text = value.trim();
  if (!text || text.length > max) {
    throw new HttpsError("invalid-argument", "Required text is invalid.");
  }
  return text;
}
