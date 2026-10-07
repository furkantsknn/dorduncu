# CANONICAL PAYMENT STATE SYNC — BATCH 10

Verified provider financial truth
→ deterministic provider-event idempotency
→ read all event/session/application state before transaction writes
→ commercial ledger
→ event_payment_intents
→ paymentSessions
→ events
→ selected canonical applications
→ addressAccessStatus / payment-gated chat
→ canonical notifications / FCM trigger
→ canonical audit log
→ finance review queue for risky states

Access rule:
Only provider-verified PAID may unlock application address access.
Refund/dispute/chargeback states immediately lock private access again.

Safety rules:
- Client callback is never payment proof.
- Paid amount and currency must match the trusted payment intent.
- Provider event ids use deterministic SHA-256 document ids to avoid
  normalization collisions.
- Duplicate provider events are ignored idempotently.
- Stale/backward provider-state transitions are recorded but never projected
  back into event/application state.
- Obvious secret/PII provider metadata keys are not persisted.
- All transaction reads happen before lifecycle writes.

Canonical lifecycle source of truth:
functions/src/payments/eventPaymentLifecycle.ts

Compatibility file:
functions/src/payments/eventPaymentStateProjection.ts only re-exports the
canonical lifecycle helper; it no longer contains a competing state machine.

Refund/dispute/chargeback:
refund_pending, partially_refunded, dispute_review and chargeback create a
server-only commercial_review_queue item. Refunded state is projected and
recorded without automatically creating a second review item.

Payout:
Payout provider states do not rewrite participant access. Actual payout
eligibility/commission/tax/net settlement policy remains the next commercial
state-machine step and must not be faked before the real provider is selected.
