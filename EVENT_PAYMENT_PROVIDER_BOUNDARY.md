# REAL-WORLD EVENT PAYMENT BOUNDARY

This package creates the permanent provider-neutral boundary for payments
related to real-world events/services.

DIGITAL PRODUCTS
- Plus
- Badge / digital market entitlement
These stay on Google Play Billing on Android.

REAL-WORLD EVENT PAYMENT
- player/event participation payment
- refund
- dispute / chargeback
- organizer payout
These use EventPaymentProvider.

Canonical server flow:

accepted application
→ reserveEventPaymentIntent()
→ external provider adapter createPaymentIntent()
→ checkout URL
→ verified provider webhook
→ applyVerifiedPaymentWebhook()
→ commercial ledger state
→ event/application payment state
→ address/chat unlock only after server paid state

Important:
- Client callback is not payment proof.
- Client cannot mark payment paid.
- Provider webhook must be signature-verified.
- Provider event IDs are idempotent.
- Provider selection is intentionally disabled until a real provider is chosen.
- No fake provider or local-success shortcut was added.
