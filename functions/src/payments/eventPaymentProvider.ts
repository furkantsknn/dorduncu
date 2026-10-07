import {
  EventPaymentIntentInput,
  EventPaymentIntentResult,
  EventPaymentWebhookEvent,
  EventPayoutInput,
  EventPayoutResult,
  EventRefundInput,
  EventRefundResult,
} from "./eventPaymentTypes";

/**
 * Provider-neutral contract for real-world event/service payments.
 *
 * Digital Plus/Badge purchases must never use this interface.
 */
export interface EventPaymentProvider {
  readonly providerId: string;

  createPaymentIntent(
    input: EventPaymentIntentInput,
  ): Promise<EventPaymentIntentResult>;

  parseAndVerifyWebhook(
    headers: Record<string, string | string[] | undefined>,
    rawBody: Buffer,
  ): Promise<EventPaymentWebhookEvent>;

  createRefund(
    input: EventRefundInput,
  ): Promise<EventRefundResult>;

  createPayout(
    input: EventPayoutInput,
  ): Promise<EventPayoutResult>;
}

/**
 * Provider selection is intentionally disabled until a real commercial
 * provider and credentials are chosen.
 *
 * This prevents accidental fake/local "paid" state in production.
 *
 */
export function getEventPaymentProvider(): EventPaymentProvider {
  throw new Error(
    "Real-world event payment provider is not configured.",
  );
}
