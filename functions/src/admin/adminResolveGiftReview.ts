import {assertCurrentAdminSession} from "../security/adminAuthorization";
/* eslint-disable max-len, require-jsdoc */
import {createHash} from "crypto";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {assertAdminPermission} from "../security/adminAuthorization";
import {writeAuditLogInTransaction} from "../audit/writeAuditLog";
import {callAndroidPublisher} from "../commercial/googlePlayVerification";

interface ProviderOrder {
  orderId?: string;
  purchaseToken?: string;
  state?: string;
  lineItems?: Array<{productId?: string}>;
  orderHistory?: {refundEvent?: {eventTime?: string}};
}

export const adminResolveGiftReview = onCall({region: "europe-west1", enforceAppCheck: true}, async (request) => {
  assertAdminPermission(request, "finance.manage");
  await assertCurrentAdminSession(request);
  const data = request.data ?? {}; const id = String(data.reviewId ?? ""); const reason = String(data.reason ?? "").trim();
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(id) || reason.length < 3 || reason.length > 1000) throw new HttpsError("invalid-argument", "İnceleme ve gerekçe gerekli.");
  const db = getFirestore(); const ref = db.collection("gift_reviews").doc(id);
  if (data.action === "note") {
    await db.runTransaction(async (tx) => {
      const review = await tx.get(ref);
      if (!review.exists) throw new HttpsError("not-found", "İnceleme bulunamadı.");
      tx.create(ref.collection("history").doc(), {action: "note", reason, actorUid: request.auth.uid, createdAt: FieldValue.serverTimestamp()});
      writeAuditLogInTransaction(db, tx, {action: "gift_review_note", performedBy: request.auth.uid, metadata: {reviewId: id, reason}});
    });
    return {success: true, financialResolution: false};
  }
  if (data.action !== "verify_refund") throw new HttpsError("invalid-argument", "Geçersiz işlem.");
  const review = await ref.get(); const r = review.data();
  if (!r) throw new HttpsError("not-found", "İnceleme bulunamadı.");
  if (r.status === "refunded_verified") return {success: true, idempotentReplay: true};
  const boundIntent = await db.collection("gift_purchase_intents").doc(String(r.giftIntentId)).get();
  // The supplied order ID is a lookup hint, never proof. Provider token and
  // product binding independently identify the existing transaction.
  const orderId = String(r.providerOrderId ?? data.orderId ?? "").trim();
  const playProductId = String(r.googlePlayProductId ?? boundIntent.get("googlePlayProductId") ?? "");
  if (!/^GPA\.[A-Za-z0-9.-]{1,190}$/.test(orderId) || !r.purchaseTokenHash || !playProductId) throw new HttpsError("failed-precondition", "Doğrulanabilir sipariş bağlantısı eksik; inceleme açık kalır.");
  const order = await callAndroidPublisher<ProviderOrder>(`applications/com.dortapp.dort/orders/${encodeURIComponent(orderId)}`, "GET");
  const hash = createHash("sha256").update(String(order.purchaseToken ?? "")).digest("hex");
  const verified = order.orderId === orderId && hash === r.purchaseTokenHash &&
    order.lineItems?.some((item) => item.productId === playProductId) === true &&
    order.state === "REFUNDED" && Number.isFinite(Date.parse(order.orderHistory?.refundEvent?.eventTime ?? ""));
  if (!verified) throw new HttpsError("failed-precondition", "Tam iade sağlayıcı tarafından doğrulanmadı; inceleme açık kalır.");
  await db.runTransaction(async (tx) => {
    const current = await tx.get(ref); const intentRef = db.collection("gift_purchase_intents").doc(String(r.giftIntentId));
    const intent = await tx.get(intentRef);
    if (!intent.exists || intent.get("buyerUid") !== r.buyerUid || intent.get("recipientUid") !== r.recipientUid || intent.get("productId") !== r.productId) throw new HttpsError("failed-precondition", "Hediye alıcı/ürün bağlantısı doğrulanamadı.");
    if (current.get("status") === "refunded_verified") return;
    for (const key of ["providerOrderId", "purchaseTokenHash", "buyerUid", "recipientUid", "productId", "giftIntentId"]) if (current.get(key) !== r[key]) throw new HttpsError("aborted", "İnceleme değişti.");
    // This resolution is for undelivered reviews only. Delivered entitlement
    // revocation continues through the established Play lifecycle workflow.
    if (intent.get("status") === "delivered") throw new HttpsError("failed-precondition", "Teslim edilmiş hediye için hak mutabakatı gerekli.");
    tx.update(ref, {status: "refunded_verified", providerOrderId: orderId, providerVerified: true, googlePlayProductId: playProductId, resolutionReason: reason, providerState: order.state, providerRefundAt: order.orderHistory!.refundEvent!.eventTime, resolvedBy: request.auth.uid, resolvedAt: FieldValue.serverTimestamp()});
    tx.set(intentRef, {status: "refunded_verified", updatedAt: FieldValue.serverTimestamp()}, {merge: true});
    tx.create(ref.collection("history").doc(), {action: "provider_refund_verified", reason, actorUid: request.auth.uid, providerState: order.state, createdAt: FieldValue.serverTimestamp()});
    writeAuditLogInTransaction(db, tx, {action: "gift_refund_verified", performedBy: request.auth.uid, targetUid: r.buyerUid, metadata: {reviewId: id, reason, providerOrderId: orderId}});
  });
  return {success: true, providerVerified: true};
});
