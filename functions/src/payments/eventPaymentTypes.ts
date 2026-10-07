export const eventPaymentProviderStates = [
  "created",
  "pending",
  "processing",
  "authorized",
  "paid",
  "failed",
  "cancelled",
  "refund_pending",
  "refunded",
  "partially_refunded",
  "dispute_review",
  "chargeback",
  "payout_pending",
  "paid_out",
] as const;

export type EventPaymentProviderState =
  typeof eventPaymentProviderStates[number];

export interface EventPaymentMoney {
  currency: string;
  grossAmountMinor: number;
}

export interface EventPaymentIntentInput {
  operationId: string;
  eventId: string;
  applicationId: string;
  payerUid: string;
  organizerUid: string;
  idempotencyKey: string;
  money: EventPaymentMoney;
  successUrl?: string;
  cancelUrl?: string;
  metadata?: Record<string, string>;
}

export interface EventPaymentIntentResult {
  provider: string;
  providerPaymentId: string;
  providerState: EventPaymentProviderState;
  checkoutUrl: string | null;
  expiresAt: Date | null;
  rawReference?: string | null;
}

export interface EventPaymentWebhookEvent {
  provider: string;
  providerEventId: string;
  providerPaymentId: string;
  state: EventPaymentProviderState;
  grossAmountMinor: number | null;
  currency: string | null;
  occurredAt: Date | null;
  refundAmountMinor?: number | null;
  disputeReason?: string | null;
  metadata?: Record<string, unknown>;
}

export interface EventRefundInput {
  operationId: string;
  providerPaymentId: string;
  amountMinor: number;
  currency: string;
  reason: string;
  idempotencyKey: string;
}

export interface EventRefundResult {
  providerRefundId: string;
  providerState:
    "refund_pending" |
    "refunded" |
    "failed";
}

export interface EventPayoutInput {
  operationId: string;
  organizerUid: string;
  amountMinor: number;
  currency: string;
  idempotencyKey: string;
}

export interface EventPayoutResult {
  providerPayoutId: string;
  providerState:
    "payout_pending" |
    "paid_out" |
    "failed";
}


export interface VerifiedEventPayoutSettlement {
  payoutId: string;
  eventId: string;
  organizerUid: string;
  sourcePaymentOperationId: string;
  grossAmountMinor: number;
  feeAmountMinor: number;
  netAmountMinor: number;
  currency: string;
  settlementReference: string;
  idempotencyKey: string;
}
