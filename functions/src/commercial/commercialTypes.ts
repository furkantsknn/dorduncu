/* eslint-disable max-len */

export const commercialOperationTypes = [
  "digital_plus_purchase",
  "digital_badge_purchase",
  "event_payment",
  "event_refund",
  "event_payout",
  "wallet_adjustment",
] as const;

export type CommercialOperationType =
  typeof commercialOperationTypes[number];

export const commercialProviders = [
  "google_play",
  "external_payment_provider",
  "internal_legacy",
  "manual_admin",
] as const;

export type CommercialProvider =
  typeof commercialProviders[number];

export const commercialStates = [
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

export type CommercialState =
  typeof commercialStates[number];

export interface CommercialMoney {
  currency: string;
  grossAmountMinor: number;
  feeAmountMinor: number;
  netAmountMinor: number;
}

export interface CommercialActorContext {
  actorUid: string;
  source: string;
}

export interface CommercialOperationInput {
  userUid: string;
  type: CommercialOperationType;
  provider: CommercialProvider;
  idempotencyScope: string;
  idempotencyKey: string;
  providerTransactionId?: string | null;
  providerReference?: string | null;
  money: CommercialMoney;
  relatedEventId?: string | null;
  relatedProductId?: string | null;
  metadata?: Record<string, unknown>;
}

export interface CommercialOperationIdentity {
  operationId: string;
  idempotencyHash: string;
}

export interface CommercialOperationReservation {
  operationId: string;
  created: boolean;
  existingState?: CommercialState;
}
