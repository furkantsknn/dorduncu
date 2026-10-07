# GRUP 2 HANDOFF — A9 + A10 + A11

## Başlangıç noktası

Group 1 şu guarantee'leri sağlar:
- canonical event/application state machine
- payment_pending / processing / paid / refund_pending / refunded state vocabulary
- payment timeout reservation infrastructure
- payment-gated exact location
- payment-gated private event chat
- server notifications + FCM queue
- block-aware recipient filtering
- audit integration

## Group 2'nin yapması gerekenler

### A9 Payment / commercial
Önce mevcut payment/wallet/market/plus kodu inventory edilecek.
İki ödeme hattı kesin ayrılacak:

1. Digital goods
- Plus
- Badge / market digital entitlements
- Google Play Billing

2. Real-world event/service payment
- External payment provider
- payment intent/session
- provider callback/webhook
- verified success only server-side
- commission
- refund
- dispute
- chargeback
- payout
- ledger
- idempotency
- reconciliation
- audit

Client hiçbir zaman paid/refunded authoritative state yazamaz.

### A10 Plus
- Existing Plus system reuse.
- Entitlement source server/billing verified.
- Expiry / renewal / restore.
- Feature checks centralized.

### A11 Badge / Market
- Existing market_products / badge purchase flow reuse.
- Digital purchase validation must align with Play Billing.
- No duplicate entitlement.
- Idempotent order fulfillment.
- Audit + admin visibility.

## İlk iş
Group 2 Batch 1:
Payment / Plus / Market mevcut kaynak kodunun read-only inventory'si ve
commercial boundary haritası.
Kod değişikliğine inventory sonrası başlanacak.
