/**
 * Event planning window for TR V1.
 *
 * Calendar days use Europe/Istanbul. The server clock is the authority.
 * Free accounts may open an event only on today's Istanbul date.
 * Active Plus may open an event for any valid future instant. A start time
 * that is not still in the future is past.
 */

export const EVENT_FREE_TODAY_CODE = "event_free_today_only";

export const FREE_EVENT_DAY_OFFSET = 0;
export const ISTANBUL_TIME_ZONE = "Europe/Istanbul";

export type EventScheduleDecision =
  | "ok"
  | "past"
  | "free_not_today";

/**
 * Istanbul calendar day as a UTC day index.
 *
 * @param {number} instantMs Absolute time.
 * @return {number} Day index in Europe/Istanbul.
 */
export function istanbulCalendarDay(instantMs: number): number {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: ISTANBUL_TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date(instantMs));
  const read = (type: Intl.DateTimeFormatPartTypes): number => {
    return Number(parts.find((part) => part.type === type)?.value);
  };
  return Math.floor(
    Date.UTC(read("year"), read("month") - 1, read("day")) / 86400000,
  );
}

/**
 * Decides whether a start time is inside the membership planning window.
 *
 * @param {number} startAtMs Event start, absolute.
 * @param {number} nowMs Server clock.
 * @param {boolean} plusActive Expiry-aware Plus entitlement.
 * @return {EventScheduleDecision} Allowance.
 */
export function evaluateEventSchedule(
  startAtMs: number,
  nowMs: number,
  plusActive: boolean,
): EventScheduleDecision {
  if (!Number.isFinite(startAtMs) || !Number.isFinite(nowMs)) {
    return "past";
  }

  if (startAtMs <= nowMs) {
    return "past";
  }

  const dayOffset = istanbulCalendarDay(startAtMs) -
    istanbulCalendarDay(nowMs);

  if (dayOffset < 0) {
    return "past";
  }

  if (!plusActive && dayOffset > FREE_EVENT_DAY_OFFSET) {
    return "free_not_today";
  }

  return "ok";
}

/**
 * True when the submitted start is the stored start.
 *
 * An unchanged date must not be rejected by a newer planning window.
 *
 * @param {number} nextStartMs Submitted start.
 * @param {number | null} storedStartMs Stored start, if any.
 * @return {boolean} Whether the instant is unchanged.
 */
export function eventStartIsUnchanged(
  nextStartMs: number,
  storedStartMs: number | null,
): boolean {
  return storedStartMs !== null && nextStartMs === storedStartMs;
}
