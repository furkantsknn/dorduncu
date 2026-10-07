# GOOGLE PLAY PURCHASE SECURITY BOUNDARY

Authoritative flow:

Google Play Billing UI
→ purchaseToken
→ fulfillGooglePlayPurchase
→ Google Android Publisher API
→ verified provider state
→ Firestore transaction
→ commercial ledger
→ Plus/Badge entitlement
→ Google Play acknowledge

Rules:
- Client purchase status is never trusted.
- Raw purchase token is not stored in Firestore.
- Same token cannot be claimed by another user/product.
- Entitlement is granted before acknowledge.
- If acknowledge fails, retry remains safe because fulfillment is idempotent.
- Wallet is not charged for Google Play digital purchases.
- Event/service payments remain a separate provider domain.
