/* eslint-disable max-len, require-jsdoc */
import {randomUUID} from "crypto";
import {DocumentReference, FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {deliverPushNotification, evaluateNotificationPreferences, nextRetryDate, NotificationDeliveryInput, preparePushDevices} from "./notificationDelivery";
import {recordAdminNotificationResult} from "./processAdminNotifications";

const LEASE_MS = 120000;
const UNKNOWN_MS = 600000;
const terminal = (status: unknown): boolean => ["delivered", "failed", "retry_limit_reached", "user_missing", "no_active_device", "suppressed_preference", "delivery_uncertain", "notification_missing"].includes(String(status ?? ""));
const millis = (value: unknown): number => value instanceof Timestamp ? value.toMillis() : 0;
const signature = (data: FirebaseFirestore.DocumentData): string => JSON.stringify([data.deliverAfter, data.attemptCount ?? 0, data.targetTokenHashes ?? [], data.userId, data.notificationId, data.type, data.title, data.message, data.data ?? {}]);

/** Shared initial/admin/chat/event/retry worker. Preparation is repeatable.
 * @param {DocumentReference} ref Queue record reference.
 * @return {Promise<void>} Settled delivery or retryable preparation failure.
 */
export async function processPushDelivery(ref: DocumentReference): Promise<void> {
  const db = getFirestore(); const owner = randomUUID();
  const prepared = await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref); const job = snapshot.data();
    if (!job || job.status !== "pending" || millis(job.deliverAfter) > Date.now()) return null;
    const uid = String(job.userId ?? ""); const notificationId = String(job.notificationId ?? ref.id);
    const notification = db.doc(`users/${uid || "_missing"}/notifications/${notificationId}`);
    const prior = await tx.get(notification);
    if (terminal(prior.get("pushDeliveryStatus")) || (prior.get("pushQueueId") && prior.get("pushQueueId") !== ref.id)) {
      tx.update(ref, {status: "superseded", updatedAt: FieldValue.serverTimestamp()});
      return null;
    }
    if (job.attemptStartedAt || prior.get("pushAttemptStartedAt")) {
      const started = millis(job.attemptStartedAt ?? prior.get("pushAttemptStartedAt"));
      if (Date.now() - started < UNKNOWN_MS) return null;
      tx.update(ref, {status: "delivery_uncertain", updatedAt: FieldValue.serverTimestamp()});
      if (prior.exists) tx.update(notification, {pushDeliveryStatus: "delivery_uncertain"});
      return null;
    }
    if (millis(job.preparationLeaseUntil) > Date.now()) return null;
    const user = uid ? await tx.get(db.doc(`users/${uid}`)) : null;
    const input: NotificationDeliveryInput = {notificationId, userId: uid, type: String(job.type ?? "system"), title: String(job.title ?? "Dört."), message: String(job.message ?? ""), route: job.route ?? "", eventId: job.eventId ?? "", eventTitle: job.eventTitle ?? "", data: job.data ?? {}};
    const decision = user?.exists ? evaluateNotificationPreferences(user.data() ?? {}, input.type, new Date()) : null;
    if (!prior.exists || !decision || !decision.enabled) {
      const status = !prior.exists ? "notification_missing" : !decision ? "user_missing" : "suppressed_preference";
      tx.update(ref, {status, updatedAt: FieldValue.serverTimestamp()});
      if (prior.exists) tx.update(notification, {pushDeliveryStatus: status, pushDeliveryUpdatedAt: FieldValue.serverTimestamp()});
      return null;
    }
    if (decision.quietUntil) {
      tx.update(ref, {deliverAfter: Timestamp.fromDate(decision.quietUntil), updatedAt: FieldValue.serverTimestamp()});
      tx.update(notification, {pushDeliveryStatus: "queued_quiet_hours", pushDeliverAfter: Timestamp.fromDate(decision.quietUntil)});
      return null;
    }
    const targets = Array.isArray(job.targetTokenHashes) && job.targetTokenHashes.length ? job.targetTokenHashes : null;
    const devices = await preparePushDevices(db, input.userId, targets, tx);
    tx.update(ref, {preparationOwner: owner, preparationLeaseUntil: Timestamp.fromMillis(Date.now() + LEASE_MS)});
    tx.update(notification, {pushQueueId: ref.id});
    return {input, devices, signature: signature(job), notification, attempt: Number(job.attemptCount ?? 0), targets};
  });
  if (!prepared) return;
  try {
    const result = await deliverPushNotification(db, prepared.input, prepared.targets, prepared.devices, async () => {
      await db.runTransaction(async (tx) => {
        const [fresh, notification, user] = await Promise.all([tx.get(ref), tx.get(prepared.notification), tx.get(db.doc(`users/${prepared.input.userId}`))]);
        const job = fresh.data() ?? {};
        if (terminal(notification.get("pushDeliveryStatus")) || notification.get("pushQueueId") !== ref.id) throw new Error("notification_claim_changed");
        const devices = await preparePushDevices(db, prepared.input.userId, prepared.targets, tx);
        const decision = evaluateNotificationPreferences(user.data() ?? {}, prepared.input.type, new Date());
        if (job.status !== "pending" || job.preparationOwner !== owner || job.attemptStartedAt || notification.get("pushAttemptStartedAt") || !notification.exists || !user.exists || signature(job) !== prepared.signature || millis(job.deliverAfter) > Date.now() || !decision.enabled || decision.quietUntil || JSON.stringify(devices.map((d) => [d.tokenHash, d.token])) !== JSON.stringify(prepared.devices.map((d) => [d.tokenHash, d.token]))) throw new Error("preparation_changed");
        // The payload and devices are ready. This is the external uncertainty boundary.
        tx.update(ref, {attemptStartedAt: FieldValue.serverTimestamp()});
        tx.update(prepared.notification, {pushAttemptStartedAt: FieldValue.serverTimestamp()});
      });
    });
    await db.runTransaction(async (tx) => {
      const [job, prior] = await Promise.all([tx.get(ref), tx.get(prepared.notification)]);
      if (job.get("preparationOwner") !== owner) return;
      const accepted = Number(prior.get("pushDeliveredCount") ?? 0) + result.delivered;
      const attempt = prepared.attempt + 1;
      const retry = result.retryTokenHashes.length ? nextRetryDate(attempt, new Date()) : null;
      const status = retry ? "retry_scheduled" : result.retryTokenHashes.length ? "retry_limit_reached" : result.failed ? "failed" : accepted ? "delivered" : "no_active_device";
      tx.update(ref, {status: retry ? "pending" : status, attemptCount: attempt, deliveredCount: accepted, targetTokenHashes: result.retryTokenHashes, ...(retry ? {deliverAfter: Timestamp.fromDate(retry)} : {}), attemptStartedAt: FieldValue.delete(), preparationOwner: FieldValue.delete(), preparationLeaseUntil: FieldValue.delete(), updatedAt: FieldValue.serverTimestamp()});
      if (prior.exists) tx.update(prepared.notification, {pushDeliveryStatus: status, pushDeliveredCount: accepted, pushRetryTokenCount: result.retryTokenHashes.length, pushAttemptStartedAt: FieldValue.delete(), pushMode: process.env.FUNCTIONS_EMULATOR === "true" || process.env.FIRESTORE_EMULATOR_HOST ? "simulation" : "fcm", pushDeliveryUpdatedAt: FieldValue.serverTimestamp()});
    });
  } catch (error) {
    await db.runTransaction(async (tx) => {
      const [job, notification] = await Promise.all([tx.get(ref), tx.get(prepared.notification)]);
      if (job.get("preparationOwner") !== owner) return;
      const uncertain = !!job.get("attemptStartedAt");
      tx.update(ref, {status: uncertain ? "delivery_uncertain" : "pending", preparationOwner: FieldValue.delete(), preparationLeaseUntil: FieldValue.delete(), updatedAt: FieldValue.serverTimestamp()});
      if (uncertain && notification.exists) tx.update(prepared.notification, {pushDeliveryStatus: "delivery_uncertain", pushDeliveryUpdatedAt: FieldValue.serverTimestamp()});
    });
    throw error;
  } finally {
    const notification = await prepared.notification.get();
    if (notification.exists) await recordAdminNotificationResult(prepared.input.userId, notification.data()!);
  }
}
