/* eslint-disable max-len */
import "../config/firebaseAdmin";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions";
import {processPushDelivery} from "./processPushDelivery";

export const processNotificationDeliveryQueue = onSchedule({region: "europe-west1", schedule: "every 5 minutes", timeZone: "Europe/Istanbul", retryCount: 3}, async () => {
  const jobs = await getFirestore().collection("notification_delivery_queue").where("status", "==", "pending").where("deliverAfter", "<=", Timestamp.now()).orderBy("deliverAfter", "asc").limit(100).get();
  for (const job of jobs.docs) {
    try {
      // Only the reference is trusted. The shared worker rereads all claim inputs.
      await processPushDelivery(job.ref);
    } catch {
      logger.warn("Push queue record deferred or uncertain; continuing batch", {queueId: job.id});
    }
  }
});
