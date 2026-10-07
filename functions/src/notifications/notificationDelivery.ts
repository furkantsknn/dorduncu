/* eslint-disable max-len */
import {
  FieldValue,
  Firestore,
  Timestamp,
} from "firebase-admin/firestore";
import {
  getMessaging,
} from "firebase-admin/messaging";

const MAX_RETRY_ATTEMPTS = 5;
const RETRY_DELAYS_MINUTES = [5, 15, 60, 180, 360];

export interface NotificationDeliveryInput {
  notificationId: string;
  userId: string;
  type: string;
  title: string;
  message: string;
  route?: string;
  eventId?: string;
  eventTitle?: string;
  data?: Record<string, unknown>;
}

export interface NotificationPreferenceDecision {
  enabled: boolean;
  quietUntil: Date | null;
}

/**
 * Evaluates category and quiet-hour preferences.
 *
 * @param {Record<string, unknown>} userData User document data.
 * @param {string} type Notification type.
 * @param {Date} now Current time.
 * @return {NotificationPreferenceDecision} Delivery decision.
 */
export function evaluateNotificationPreferences(
  userData: Record<string, unknown>,
  type: string,
  now: Date,
): NotificationPreferenceDecision {
  const rawPreferences = userData.bildirimAyarlari;
  const preferences = isRecord(rawPreferences) ? rawPreferences : {};

  const preferenceKey = preferenceKeyForType(type);
  const defaultEnabled = preferenceKey === "kampanyalar" ? false : true;
  const enabledValue = preferences[preferenceKey];
  const enabled = typeof enabledValue === "boolean" ?
    enabledValue :
    defaultEnabled;

  if (!enabled) {
    return {
      enabled: false,
      quietUntil: null,
    };
  }

  if (isCriticalType(type)) {
    return {
      enabled: true,
      quietUntil: null,
    };
  }

  if (preferences.sessizSaatlerAktif !== true) {
    return {
      enabled: true,
      quietUntil: null,
    };
  }

  const start = parseClock(
    preferences.sessizBaslangic,
    22,
    0,
  );
  const end = parseClock(
    preferences.sessizBitis,
    8,
    0,
  );

  return {
    enabled: true,
    quietUntil: quietPeriodEnd(now, start, end),
  };
}

/**
 * Delivers a notification to registered device tokens.
 *
 * @param {Firestore} firestore Firestore instance.
 * @param {NotificationDeliveryInput} input Notification payload.
 * @param {string[]|null} targetTokenHashes Optional retry token hashes.
 * @return {Promise<{delivered: number, retryTokenHashes: string[]}>} Result.
 */
export async function deliverPushNotification(
  firestore: Firestore,
  input: NotificationDeliveryInput,
  targetTokenHashes: string[] | null = null,
): Promise<{
  delivered: number;
  retryTokenHashes: string[];
}> {
  const devicesSnapshot = await firestore
    .collection("users")
    .doc(input.userId)
    .collection("notification_devices")
    .where("enabled", "==", true)
    .get();

  const targetHashSet = targetTokenHashes ?
    new Set(targetTokenHashes) :
    null;

  const devices = devicesSnapshot.docs
    .map((document) => {
      const data = document.data();

      return {
        reference: document.ref,
        token: String(data.token ?? "").trim(),
        tokenHash: String(data.tokenHash ?? document.id).trim(),
      };
    })
    .filter((device) => {
      if (!device.token || !device.tokenHash) {
        return false;
      }

      return targetHashSet === null || targetHashSet.has(device.tokenHash);
    });

  if (devices.length === 0) {
    return {
      delivered: 0,
      retryTokenHashes: [],
    };
  }

  let delivered = 0;
  const retryTokenHashes: string[] = [];

  for (let offset = 0; offset < devices.length; offset += 500) {
    const slice = devices.slice(offset, offset + 500);
    const response = await getMessaging().sendEachForMulticast({
      tokens: slice.map((device) => device.token),
      notification: {
        title: input.title,
        body: input.message,
      },
      data: stringifyData({
        notificationId: input.notificationId,
        type: input.type,
        route: input.route ?? "",
        eventId: input.eventId ?? "",
        eventTitle: input.eventTitle ?? "",
        ...(input.data ?? {}),
      }),
      android: {
        priority: "high",
      },
    });

    delivered += response.successCount;

    for (let index = 0; index < response.responses.length; index += 1) {
      const sendResponse = response.responses[index];

      if (sendResponse.success) {
        continue;
      }

      const device = slice[index];
      const errorCode = String(sendResponse.error?.code ?? "");

      if (isInvalidTokenError(errorCode)) {
        await device.reference.delete();
        continue;
      }

      retryTokenHashes.push(device.tokenHash);
    }
  }

  return {
    delivered,
    retryTokenHashes,
  };
}

/**
 * Queues a notification for delayed/retry delivery.
 *
 * @param {Firestore} firestore Firestore instance.
 * @param {NotificationDeliveryInput} input Notification payload.
 * @param {Date} deliverAfter Earliest delivery time.
 * @param {number} attemptCount Existing retry count.
 * @param {string[]} targetTokenHashes Optional failed-token hashes.
 * @return {Promise<void>} Completes after queue write.
 */
export async function queuePushDelivery(
  firestore: Firestore,
  input: NotificationDeliveryInput,
  deliverAfter: Date,
  attemptCount = 0,
  targetTokenHashes: string[] = [],
): Promise<void> {
  await firestore
    .collection("notification_delivery_queue")
    .doc(input.notificationId)
    .set(
      {
        notificationId: input.notificationId,
        userId: input.userId,
        type: input.type,
        title: input.title,
        message: input.message,
        route: input.route ?? null,
        eventId: input.eventId ?? null,
        eventTitle: input.eventTitle ?? null,
        data: input.data ?? {},
        targetTokenHashes,
        status: "pending",
        attemptCount,
        deliverAfter: Timestamp.fromDate(deliverAfter),
        updatedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
}

/**
 * Returns the next retry date.
 *
 * @param {number} attemptCount Completed attempt count.
 * @param {Date} now Current time.
 * @return {Date|null} Next retry time or null.
 */
export function nextRetryDate(
  attemptCount: number,
  now: Date,
): Date | null {
  if (attemptCount >= MAX_RETRY_ATTEMPTS) {
    return null;
  }

  const delayIndex = Math.min(
    attemptCount,
    RETRY_DELAYS_MINUTES.length - 1,
  );

  return new Date(
    now.getTime() + RETRY_DELAYS_MINUTES[delayIndex] * 60 * 1000,
  );
}

/**
 * Maps notification types to existing user preference keys.
 *
 * @param {string} type Notification type.
 * @return {string} Preference field.
 */
function preferenceKeyForType(type: string): string {
  const normalized = type.trim().toLowerCase();

  if (
    normalized.includes("message") ||
    normalized.includes("chat")
  ) {
    return "mesajlar";
  }

  if (
    normalized.includes("application") ||
    normalized.includes("applicant")
  ) {
    return "basvurular";
  }

  if (
    normalized.includes("campaign") ||
    normalized.includes("promotion") ||
    normalized.includes("marketing")
  ) {
    return "kampanyalar";
  }

  return "etkinlikler";
}

/**
 * Checks whether quiet hours should be bypassed.
 *
 * @param {string} type Notification type.
 * @return {boolean} True for security-critical notifications.
 */
function isCriticalType(type: string): boolean {
  const normalized = type.trim().toLowerCase();

  return normalized.includes("security") ||
    normalized.includes("account_banned") ||
    normalized.includes("account_suspended");
}

/**
 * Parses HH:mm safely.
 *
 * @param {unknown} value Raw setting.
 * @param {number} fallbackHour Fallback hour.
 * @param {number} fallbackMinute Fallback minute.
 * @return {{hour: number, minute: number}} Parsed clock.
 */
function parseClock(
  value: unknown,
  fallbackHour: number,
  fallbackMinute: number,
): {hour: number; minute: number} {
  const match = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(
    String(value ?? "").trim(),
  );

  if (!match) {
    return {
      hour: fallbackHour,
      minute: fallbackMinute,
    };
  }

  return {
    hour: Number(match[1]),
    minute: Number(match[2]),
  };
}

/**
 * Calculates the end of the active quiet period.
 * Europe/Istanbul is UTC+03:00 year-round.
 *
 * @param {Date} now Current UTC date.
 * @param {{hour: number, minute: number}} start Start clock.
 * @param {{hour: number, minute: number}} end End clock.
 * @return {Date|null} Quiet end instant when currently quiet.
 */
function quietPeriodEnd(
  now: Date,
  start: {hour: number; minute: number},
  end: {hour: number; minute: number},
): Date | null {
  const turkeyOffsetMs = 3 * 60 * 60 * 1000;
  const local = new Date(now.getTime() + turkeyOffsetMs);
  const currentMinutes = local.getUTCHours() * 60 + local.getUTCMinutes();
  const startMinutes = start.hour * 60 + start.minute;
  const endMinutes = end.hour * 60 + end.minute;

  if (startMinutes === endMinutes) {
    return null;
  }

  let isQuiet = false;
  let endDayOffset = 0;

  if (startMinutes < endMinutes) {
    isQuiet = currentMinutes >= startMinutes && currentMinutes < endMinutes;
  } else {
    isQuiet = currentMinutes >= startMinutes || currentMinutes < endMinutes;

    if (currentMinutes >= startMinutes) {
      endDayOffset = 1;
    }
  }

  if (!isQuiet) {
    return null;
  }

  const localEnd = Date.UTC(
    local.getUTCFullYear(),
    local.getUTCMonth(),
    local.getUTCDate() + endDayOffset,
    end.hour,
    end.minute,
    0,
    0,
  );

  return new Date(localEnd - turkeyOffsetMs);
}

/**
 * Converts arbitrary payload values to FCM string data.
 *
 * @param {Record<string, unknown>} data Raw data.
 * @return {Record<string, string>} FCM data.
 */
function stringifyData(
  data: Record<string, unknown>,
): Record<string, string> {
  const result: Record<string, string> = {};

  for (const [key, value] of Object.entries(data)) {
    if (value === null || value === undefined) {
      continue;
    }

    if (
      typeof value === "string" ||
      typeof value === "number" ||
      typeof value === "boolean"
    ) {
      result[key] = String(value);
      continue;
    }

    result[key] = JSON.stringify(value);
  }

  return result;
}

/**
 * Detects FCM token errors that should permanently remove a device.
 *
 * @param {string} code Messaging error code.
 * @return {boolean} True when token is invalid.
 */
function isInvalidTokenError(code: string): boolean {
  return code === "messaging/registration-token-not-registered" ||
    code === "messaging/invalid-registration-token" ||
    code === "messaging/invalid-argument";
}

/**
 * Checks whether a value is a plain record.
 *
 * @param {unknown} value Raw value.
 * @return {boolean} True for records.
 */
function isRecord(
  value: unknown,
): value is Record<string, unknown> {
  return value !== null &&
    typeof value === "object" &&
    !Array.isArray(value);
}
