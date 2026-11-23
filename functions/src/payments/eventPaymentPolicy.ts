/**
 * V1 events are free to create and join. Legacy payment records remain
 * readable, but no new real-world event payment may be started.
 *
 * @return {boolean} Whether a new event payment may be started.
 */
export function isEventPaymentStartAllowed(): boolean {
  return false;
}
