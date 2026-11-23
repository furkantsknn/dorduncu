export type ApplicationNotificationType =
  "application_received" | "application_accepted" | "application_rejected";

/**
 * Returns one stable notification document id per application event/type.
 * Callable retries therefore update the same record instead of producing a
 * second FCM trigger.
 * @param {ApplicationNotificationType} type Notification type.
 * @param {string} eventId Event id.
 * @param {string} playerId Applicant id.
 * @param {string} applicationAttemptId Application lifecycle attempt id.
 * @return {string} Stable notification id.
 */
export function applicationNotificationId(
  type: ApplicationNotificationType,
  eventId: string,
  playerId: string,
  applicationAttemptId: string,
): string {
  const event = eventId.trim();
  const player = playerId.trim();
  const attempt = applicationAttemptId.trim();
  if (!event || !player || !attempt) {
    throw new Error("Application notification identity is incomplete.");
  }
  return `${type}_${event}_${player}_${attempt}`;
}
