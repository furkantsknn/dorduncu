import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import {completeEventIfDue} from "./completeEvent";

const REGION = "europe-west1";

/**
 * Completes an event after its end time.
 *
 * Organizer and roster members may call it. The scheduler uses the same
 * transaction, so a second call does not count the event twice.
 */
export const markEventCompleted = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const uid = request.auth?.uid;

    if (!uid) {
      throw new HttpsError(
        "unauthenticated",
        "Bu işlem için kullanıcı girişi gereklidir.",
      );
    }

    const eventId = readRequiredString(
      request.data,
      "eventId",
      "Etkinlik kimliği gereklidir.",
    );

    const result = await completeEventIfDue({
      eventId,
      actorUid: uid,
    });

    if (result === "missing") {
      throw new HttpsError("not-found", "Etkinlik bulunamadı.");
    }

    if (result === "forbidden") {
      throw new HttpsError(
        "permission-denied",
        "Etkinliği tamamlama yetkiniz bulunmuyor.",
      );
    }

    if (result === "not_due") {
      throw new HttpsError(
        "failed-precondition",
        "Etkinlik bitmeden tamamlanamaz.",
      );
    }

    if (result === "not_active") {
      throw new HttpsError(
        "failed-precondition",
        "Bu etkinlik tamamlanamaz.",
      );
    }

    return {
      success: true,
      eventId,
      alreadyCompleted: result === "already_completed",
    };
  },
);

/**
 * Moves events whose end time has passed out of the active state.
 */
export const completePastEvents = onSchedule(
  {
    region: REGION,
    schedule: "every 5 minutes",
    timeZone: "Europe/Istanbul",
    retryCount: 3,
  },
  async () => {
    const firestore = getFirestore();
    const now = Timestamp.now();
    const [activeEvents, paymentPendingEvents] = await Promise.all([
      firestore
        .collection("events")
        .where("durum", "==", "aktif")
        .where("endAt", "<=", now)
        .limit(100)
        .get(),
      firestore
        .collection("events")
        .where("durum", "==", "odeme_bekliyor")
        .where("endAt", "<=", now)
        .limit(100)
        .get(),
    ]);

    const eventIds = new Set<string>([
      ...activeEvents.docs.map((document) => document.id),
      ...paymentPendingEvents.docs.map((document) => document.id),
    ]);

    for (const eventId of eventIds) {
      await completeEventIfDue({
        eventId,
        actorUid: null,
      });
    }
  },
);

/**
 * Reads a required string.
 *
 * @param {unknown} data Callable payload.
 * @param {string} key Field name.
 * @param {string} errorMessage Validation message.
 * @return {string} Normalized string.
 */
function readRequiredString(
  data: unknown,
  key: string,
  errorMessage: string,
): string {
  if (data === null || typeof data !== "object") {
    throw new HttpsError("invalid-argument", errorMessage);
  }

  const value = String(
    (data as Record<string, unknown>)[key] ?? "",
  ).trim();

  if (!value) {
    throw new HttpsError("invalid-argument", errorMessage);
  }

  return value;
}
