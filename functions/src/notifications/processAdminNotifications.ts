/* eslint-disable max-len, require-jsdoc */
import "../config/firebaseAdmin";
import {createHash, randomUUID} from "crypto";
import {FieldPath, FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {onDocumentCreated, onDocumentWritten} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {assertAdminPermission, assertCurrentAdminSession} from "../security/adminAuthorization";
import {isPlusMembershipActive} from "../users/plusMembership";
import {writeUserNotificationInTransaction} from "./writeUserNotification";

const options = {region: "europe-west1"};
const PAGE_SIZE = 50;
const LEASE_MS = 120000;
const eligible = (user: FirebaseFirestore.DocumentData, job: FirebaseFirestore.DocumentData): boolean => {
  if (user.disabled === true || ["deleted", "suspended", "banned", "blocked", "disabled"].includes(String(user.accountStatus ?? ""))) return false;
  switch (job.targetType) {
  case "plus": return isPlusMembershipActive(user);
  case "player": return user.verified === true || user.oyuncuRozeti === true;
  case "city": return String(user.sehir ?? user.city ?? "").trim().toLocaleLowerCase("tr") === String(job.targetValue).toLocaleLowerCase("tr");
  default: return true;
  }
};

/** One bounded, leased page. Legacy pending jobs never replay.
 * @param {string} id Versioned admin notification id.
 * @return {Promise<boolean>} Whether additional pages remain.
 */
export async function processAdminNotificationPage(id: string): Promise<boolean> {
  const db = getFirestore(); const ref = db.collection("admin_notifications").doc(id);
  const owner = randomUUID();
  const job = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref); const data = snap.data();
    if (!data || data.dispatchVersion !== 1 || !["pending", "processing"].includes(data.status) || data.distributionComplete === true) return null;
    if (data.deliverAfter instanceof Timestamp && data.deliverAfter.toMillis() > Date.now()) return null;
    if (data.leaseUntil instanceof Timestamp && data.leaseUntil.toMillis() > Date.now()) return null;
    tx.update(ref, {status: "processing", leaseOwner: owner, leaseUntil: Timestamp.fromMillis(Date.now() + LEASE_MS), updatedAt: FieldValue.serverTimestamp()});
    return data;
  });
  if (!job) return false;
  try {
    let query = db.collection("users").orderBy(FieldPath.documentId()).limit(PAGE_SIZE);
    if (job.targetType === "user") query = query.where(FieldPath.documentId(), "==", String(job.targetValue));
    if (job.cursor) query = query.startAfter(String(job.cursor));
    const users = await query.get();
    for (const user of users.docs) {
      if (!eligible(user.data(), job)) continue;
      const receipt = ref.collection("recipients").doc(user.id);
      const notificationId = "admin_" + createHash("sha256").update(id).digest("hex");
      await db.runTransaction(async (tx) => {
        const [current, sent] = await Promise.all([tx.get(ref), tx.get(receipt)]);
        if (current.get("leaseOwner") !== owner) throw new Error("lease_lost");
        if (sent.exists) return;
        writeUserNotificationInTransaction(db, tx, {notificationId, userId: user.id, type: "system", title: job.title, message: job.message, data: {adminNotificationId: id}});
        tx.create(receipt, {notificationId, outcome: "pending", createdAt: FieldValue.serverTimestamp()});
        tx.update(ref, {recipientCount: FieldValue.increment(1), inAppCount: FieldValue.increment(1)});
      });
    }
    const done = users.size < PAGE_SIZE || job.targetType === "user";
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref); const data = snap.data()!;
      if (data.leaseOwner !== owner) return;
      const settled = Number(data.resultCount ?? 0) >= Number(data.recipientCount ?? 0);
      tx.update(ref, {cursor: users.docs[users.size - 1]?.id ?? job.cursor ?? "", distributionComplete: done, leaseUntil: Timestamp.fromMillis(0), leaseOwner: "", status: done && settled ? finalStatus(data) : "processing", updatedAt: FieldValue.serverTimestamp()});
    });
    return !done;
  } catch {
    await db.runTransaction(async (tx) => {
      const current = await tx.get(ref);
      if (current.get("leaseOwner") === owner) tx.update(ref, {status: "failed", failureReason: "distribution_interrupted_retry_safe", leaseUntil: Timestamp.fromMillis(0), leaseOwner: "", updatedAt: FieldValue.serverTimestamp()});
    });
    return false;
  }
}

function finalStatus(data: FirebaseFirestore.DocumentData): string {
  return Number(data.failureCount ?? 0) > 0 ? (Number(data.inAppCount ?? 0) > 0 ? "partial" : "failed") : "completed";
}

export const dispatchAdminNotification = onDocumentCreated({...options, document: "admin_notifications/{id}"}, async (event) => {
  if (event.data?.get("dispatchVersion") !== 1) return;
  for (let page = 0; page < 5; page++) if (!await processAdminNotificationPage(event.params.id)) break;
});

export const processAdminNotifications = onSchedule({...options, schedule: "every 1 minutes", timeZone: "Europe/Istanbul"}, async () => {
  const db = getFirestore();
  // Equality status queries use single-field indexes, and legacy pending records are explicitly skipped.
  for (const status of ["pending", "processing"]) {
    const jobs = await db.collection("admin_notifications").where("status", "==", status).where("dispatchVersion", "==", 1).limit(20).get();
    for (const job of jobs.docs) {
      await processAdminNotificationPage(job.id);
      await reconcileAdminNotification(job.id);
    }
  }
});

export async function reconcileAdminNotification(id: string): Promise<void> {
  const db = getFirestore(); const ref = db.collection("admin_notifications").doc(id);
  const pending = await ref.collection("recipients").where("outcome", "==", "pending").limit(PAGE_SIZE).get();
  for (const recipient of pending.docs) {
    const notification = await db.collection("users").doc(recipient.id).collection("notifications").doc(recipient.get("notificationId")).get();
    const data = notification.data();
    if (!data) {
      if (recipient.get("createdAt") instanceof Timestamp && Date.now() - recipient.get("createdAt").toMillis() > 600000) await recordAdminNotificationResult(recipient.id, {data: {adminNotificationId: id}, pushDeliveryStatus: "notification_missing"});
      continue;
    }
    // A crash around FCM cannot prove whether the provider accepted the request.
    // Close as uncertain; never replay an unknown external send automatically.
    if (!data.pushDeliveryStatus && recipient.get("createdAt") instanceof Timestamp && Date.now() - recipient.get("createdAt").toMillis() > 600000) {
      await notification.ref.update({pushDeliveryStatus: "delivery_uncertain", pushDeliveryUpdatedAt: FieldValue.serverTimestamp()});
      data.pushDeliveryStatus = "delivery_uncertain";
    }
    await recordAdminNotificationResult(recipient.id, data);
  }
}

export const adminRetryNotification = onCall({...options, enforceAppCheck: true}, async (request) => {
  assertAdminPermission(request, "notifications.manage");
  await assertCurrentAdminSession(request);
  const id = String(request.data?.notificationId ?? "");
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(id)) throw new HttpsError("invalid-argument", "Invalid notification.");
  const ref = getFirestore().collection("admin_notifications").doc(id);
  await getFirestore().runTransaction(async (tx) => {
    const job = await tx.get(ref);
    if (job.get("dispatchVersion") !== 1 || job.get("status") !== "failed" || job.get("distributionComplete") === true) throw new HttpsError("failed-precondition", "Only interrupted distribution can be retried; old broadcasts are never replayed.");
    tx.update(ref, {status: "pending", failureReason: null, retryBy: request.auth.uid, updatedAt: FieldValue.serverTimestamp()});
  });
  await processAdminNotificationPage(id);
  return {success: true};
});

export async function recordAdminNotificationResult(uid: string, data: FirebaseFirestore.DocumentData): Promise<void> {
  const id = String(data.data?.adminNotificationId ?? "");
  if (!id) return;
  const status = String(data.pushDeliveryStatus ?? "");
  const pending = ["", "queued_quiet_hours", "retry_scheduled", "partial_retry_scheduled"].includes(status);
  if (pending) return;
  const outcome = status === "delivered" || status === "simulated" ? "success" : ["no_active_device", "suppressed_preference", "user_missing"].includes(status) ? "skipped" : "failure";
  const db = getFirestore(); const ref = db.collection("admin_notifications").doc(id); const receipt = ref.collection("recipients").doc(uid);
  await db.runTransaction(async (tx) => {
    const [job, prior] = await Promise.all([tx.get(ref), tx.get(receipt)]);
    if (!job.exists || !prior.exists || prior.get("outcome") !== "pending") return;
    const values = job.data()!;
    values.resultCount = Number(values.resultCount ?? 0) + 1;
    const key = outcome === "success" ? "successCount" : outcome === "skipped" ? "skippedCount" : "failureCount";
    values[key] = Number(values[key] ?? 0) + 1;
    const accepted = Number(data.pushDeliveredCount ?? 0);
    tx.update(receipt, {outcome, pushStatus: status, acceptedCount: accepted, updatedAt: FieldValue.serverTimestamp()});
    const simulated = data.pushMode === "simulation" || status === "simulated";
    tx.update(ref, {[key]: values[key], resultCount: values.resultCount, fcmAcceptedCount: FieldValue.increment(simulated ? 0 : accepted), simulatedCount: FieldValue.increment(simulated ? accepted : 0), status: values.distributionComplete && values.resultCount >= Number(values.recipientCount) ? finalStatus(values) : "processing", updatedAt: FieldValue.serverTimestamp()});
  });
}

export const syncAdminNotificationResult = onDocumentWritten({...options, document: "users/{uid}/notifications/{notificationId}"}, async (event) => {
  if (event.data?.after.exists) await recordAdminNotificationResult(event.params.uid, event.data.after.data()!);
});
