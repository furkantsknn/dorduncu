import {assertCurrentAdminSession} from "../security/adminAuthorization";
/* eslint-disable max-len */
/* eslint-disable require-jsdoc */
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {
  assertAdminPermission,
  getAdminRole,
} from "../security/adminAuthorization";
import {writeAuditLog} from "../audit/writeAuditLog";
import {assertV1WalletMutationAllowed} from "../policy/v1WalletPolicy";

const REGION = "europe-west1";

export const adminAdjustWallet = onCall(
  {region: REGION, enforceAppCheck: true},
  async (request) => {
    assertAdminPermission(request, "finance.manage");
    await assertCurrentAdminSession(request);
    const adminId = request.auth.uid;
    const adminRole = getAdminRole(request);
    assertV1WalletMutationAllowed();
    const data = request.data as Record<string, unknown>;
    const userId = readString(data.userId, "Kullanıcı kimliği gerekli.", 128);
    const operation = readString(data.operation, "İşlem türü gerekli.", 32);
    const balanceType = readString(data.balanceType ?? "withdrawable", "Bakiye türü gerekli.", 32);
    const reason = readString(data.reason, "Açıklama gerekli.", 500);
    const amount = Number(data.amount);

    if (!Number.isFinite(amount) || amount <= 0) {
      throw new HttpsError("invalid-argument", "Geçerli bir tutar girilmelidir.");
    }
    if (reason.length < 3) {
      throw new HttpsError("invalid-argument", "İşlem açıklaması çok kısa.");
    }

    const isBalance = operation === "balance_add" || operation === "balance_remove";
    const isPoints = operation === "point_add" || operation === "point_remove";
    if (!isBalance && !isPoints) {
      throw new HttpsError("invalid-argument", "Geçersiz işlem türü.");
    }
    if (isBalance && !["withdrawable", "market"].includes(balanceType)) {
      throw new HttpsError("invalid-argument", "Geçersiz bakiye türü.");
    }

    const firestore = getFirestore();
    const userRef = firestore.collection("users").doc(userId);
    const walletRef = firestore.collection("wallets").doc(userId);
    const notificationRef = userRef.collection("notifications").doc();
    const decisionRef = userRef.collection("management_decisions").doc();

    if (isBalance) {
      const amountKurus = Math.round(amount * 100);
      const delta = operation === "balance_add" ? amountKurus : -amountKurus;
      const field = balanceType === "market" ? "marketBalanceKurus" : "availableBalanceKurus";
      const ledgerRef = walletRef.collection("transactions").doc();

      await firestore.runTransaction(async (tx) => {
        const [userSnap, walletSnap] = await Promise.all([tx.get(userRef), tx.get(walletRef)]);
        if (!userSnap.exists) throw new HttpsError("not-found", "Kullanıcı bulunamadı.");
        const wallet = walletSnap.data() ?? {};
        const current = Number(wallet[field] ?? 0);
        const next = current + delta;
        if (!Number.isFinite(current) || next < 0) {
          throw new HttpsError("failed-precondition", "Kullanıcının bakiyesi yetersiz.");
        }

        tx.set(walletRef, {
          [field]: next,
          createdAt: walletSnap.exists ? wallet.createdAt ?? FieldValue.serverTimestamp() : FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        tx.set(ledgerRef, {
          type: delta > 0 ? "admin_credit" : "admin_debit",
          amountKurus: delta,
          status: "completed",
          description: reason,
          adminId,
          performedByUid: adminId,
          targetUserId: userId,
          metadata: {previousBalanceKurus: current, newBalanceKurus: next, balanceType, balanceField: field},
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        tx.set(notificationRef, {
          notificationId: notificationRef.id, userId, actorId: adminId,
          type: "walletAdjustment",
          title: delta > 0 ? "Hesabına bakiye eklendi" : "Hesabından bakiye düşüldü",
          message: `${amount.toFixed(2)} TL\n\n${reason}`,
          isRead: false, read: false, okundu: false,
          createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
        });
        tx.set(decisionRef, {
          decisionId: decisionRef.id, userId, adminId, type: "walletAdjustment",
          title: delta > 0 ? "Bakiye Düzenlemesi" : "Cezai Bakiye Kesintisi",
          reason, amount, status: "completed",
          createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
        });
      });
    } else {
      const normalized = Math.round(amount);
      const delta = operation === "point_add" ? normalized : -normalized;
      const logRef = userRef.collection("point_transactions").doc();

      await firestore.runTransaction(async (tx) => {
        const userSnap = await tx.get(userRef);
        if (!userSnap.exists) throw new HttpsError("not-found", "Kullanıcı bulunamadı.");
        const user = userSnap.data() ?? {};
        const current = Number(user.puan ?? 0);
        const next = current + delta;
        if (!Number.isFinite(current) || next < 0) {
          throw new HttpsError("failed-precondition", "Kullanıcının puanı yetersiz.");
        }
        tx.update(userRef, {puan: next, updatedAt: FieldValue.serverTimestamp()});
        tx.set(logRef, {
          type: delta > 0 ? "admin_point_credit" : "admin_point_debit",
          amount: delta, status: "completed", description: reason,
          adminId, performedByUid: adminId, targetUserId: userId,
          previousPoints: current, newPoints: next, createdAt: FieldValue.serverTimestamp(),
        });
        tx.set(notificationRef, {
          notificationId: notificationRef.id, userId, actorId: adminId,
          type: "pointAdjustment",
          title: delta > 0 ? "Puanın güncellendi" : "Puanından kesinti yapıldı",
          message: `${normalized} puan\n\n${reason}`,
          isRead: false, read: false, okundu: false,
          createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
        });
        tx.set(decisionRef, {
          decisionId: decisionRef.id, userId, adminId, type: "pointAdjustment",
          title: delta > 0 ? "Puan Düzenlemesi" : "Cezai Puan Kesintisi",
          reason, amount: normalized, status: "completed",
          createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
        });
      });
    }

    await writeAuditLog({action: "admin_adjust_wallet", performedBy: adminId, targetUid: userId, metadata: {operation, balanceType, amount, reason, performedByRole: adminRole}});
    return {success: true};
  },
);

function readString(value: unknown, message: string, max: number): string {
  if (typeof value !== "string") throw new HttpsError("invalid-argument", message);
  const result = value.trim();
  if (!result || result.length > max) throw new HttpsError("invalid-argument", message);
  return result;
}
