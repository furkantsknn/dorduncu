import {HttpsError} from "firebase-functions/v2/https";
import {Timestamp} from "firebase-admin/firestore";

export const APPLICATION_LIFECYCLE_VERSION = 2;
export const ACCESS_MODEL_FREE = "free";

export const applicationStatus = {
  pending: "pending",
  rejected: "rejected",
  withdrawn: "withdrawn",
  acceptedWaitingRoster: "accepted_waiting_roster",
  acceptedPaymentPending: "accepted_payment_pending",
  paymentProcessing: "payment_processing",
  paid: "paid",
  addressUnlocked: "address_unlocked",
  started: "started",
  completed: "completed",
  cancelled: "cancelled",
  refundPending: "refund_pending",
  refunded: "refunded",
  disputeReview: "dispute_review",
  removed: "removed",
  left: "left",
} as const;

export const applicationDecisionStatus = {
  awaitingOrganizer: "awaiting_organizer",
  accepted: "accepted",
  rejected: "rejected",
  withdrawn: "withdrawn",
} as const;

export const applicationPaymentStatus = {
  notRequired: "not_required",
  pending: "payment_pending",
  processing: "payment_processing",
  paid: "paid",
  refundPending: "refund_pending",
  refunded: "refunded",
} as const;

export const addressAccessStatus = {
  locked: "locked",
  unlocked: "unlocked",
} as const;

export const reservationStatus = {
  none: "none",
  held: "held",
  released: "released",
  expired: "expired",
} as const;


const INACTIVE_APPLICATION_STATUSES = new Set([
  "pending",
  "rejected",
  "withdrawn",
  "removed",
  "left",
  "cancelled",
  "refund_pending",
  "refunded",
]);

/**
 * True for V1 free events created with accessModel free.
 *
 * Leave and cancel on legacy paid events also write paymentRequired false,
 * so that flag alone is not a free-event signal.
 *
 * @param {FirebaseFirestore.DocumentData} data Event data.
 * @return {boolean} Whether the event uses the free membership model.
 */
export function isFreeAccessEvent(
  data: FirebaseFirestore.DocumentData,
): boolean {
  return String(data.accessModel ?? "") === ACCESS_MODEL_FREE &&
    data.paymentRequired === false &&
    normalizeLifecycleStatus(data.paymentStatus) ===
      applicationPaymentStatus.notRequired;
}

/**
 * True when a roster application may read address and chat on a free event.
 *
 * @param {FirebaseFirestore.DocumentData|undefined} data Application data.
 * @return {boolean} Whether the application grants free membership access.
 */
export function hasFreeMembershipAccess(
  data: FirebaseFirestore.DocumentData | undefined,
): boolean {
  if (!data) {
    return false;
  }

  const status = normalizeLifecycleStatus(data.status);
  const paymentStatus = normalizeLifecycleStatus(data.paymentStatus);
  const addressStatus = normalizeLifecycleStatus(data.addressAccessStatus);

  return addressStatus === addressAccessStatus.unlocked &&
    paymentStatus === applicationPaymentStatus.notRequired &&
    !INACTIVE_APPLICATION_STATUSES.has(status);
}

/**
 * Resolves the event end instant. Missing end uses start plus duration,
 * then start plus one hour.
 *
 * @param {FirebaseFirestore.DocumentData} data Event data.
 * @return {number|null} End time in milliseconds, if it can be resolved.
 */
export function resolveEventEndMs(
  data: FirebaseFirestore.DocumentData,
): number | null {
  const explicitEnd = readTimestampMs(data.endAt) ??
    readTimestampMs(data.bitisTarihi) ??
    readTimestampMs(data.eventEndDate);

  if (explicitEnd != null) {
    return explicitEnd;
  }

  const start = readTimestampMs(data.startAt) ??
    readTimestampMs(data.tarih);

  if (start == null) {
    return null;
  }

  const duration = Number(data.durationMinutes);
  const minutes = Number.isFinite(duration) && duration > 0 ?
    duration :
    60;

  return start + minutes * 60 * 1000;
}

/**
 * True when the event end instant is at or before now.
 *
 * @param {FirebaseFirestore.DocumentData} data Event data.
 * @param {number} nowMs Comparison clock.
 * @return {boolean} Whether the event has ended.
 */
export function eventHasEnded(
  data: FirebaseFirestore.DocumentData,
  nowMs: number = Date.now(),
): boolean {
  const endMs = resolveEventEndMs(data);
  return endMs != null && endMs <= nowMs;
}

/**
 * Rejects mutations after the event end instant.
 *
 * @param {FirebaseFirestore.DocumentData} data Event data.
 * @return {void}
 */
export function assertEventNotPast(
  data: FirebaseFirestore.DocumentData,
): void {
  if (eventHasEnded(data)) {
    throw new HttpsError(
      "failed-precondition",
      "Bu etkinliğin süresi doldu.",
    );
  }
}

/**
 * Normalizes a status field.
 *
 * @param {unknown} value Raw status.
 * @return {string} Lowercase trimmed status.
 */
function normalizeLifecycleStatus(value: unknown): string {
  return String(value ?? "").trim().toLowerCase();
}

/**
 * Reads a Firestore timestamp as epoch milliseconds.
 *
 * @param {unknown} value Raw timestamp.
 * @return {number|null} Milliseconds, when the value is a timestamp.
 */
function readTimestampMs(value: unknown): number | null {
  if (value instanceof Timestamp) {
    return value.toDate().getTime();
  }

  if (value instanceof Date) {
    const millis = value.getTime();
    return Number.isFinite(millis) ? millis : null;
  }

  return null;
}

export const DEFAULT_PAYMENT_WINDOW_MINUTES = 30;
export const MIN_PAYMENT_WINDOW_MINUTES = 5;
export const MAX_PAYMENT_WINDOW_MINUTES = 120;
