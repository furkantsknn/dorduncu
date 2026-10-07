# GOOGLE PLAY LIFECYCLE AUTHORITY

Authoritative lifecycle:

Google Play
→ Cloud Pub/Sub RTDN
→ processGooglePlayRtdn
→ Android Publisher subscriptionsv2.get when subscription state changes
→ server-only token registry
→ entitlement sync
→ commercial audit/reconciliation queue

Important entitlement rules:
- ACTIVE: access
- IN_GRACE_PERIOD: access
- CANCELED with future expiry: access until expiry
- ON_HOLD: no access
- PAUSED: no access
- EXPIRED: no access

Voided Badge:
- full refund: revoke matching Google Play entitlement
- partial refund: commercial state records partial refund; entitlement is not
  blindly removed

No client can write RTDN events, token registry, provider secrets, or
reconciliation state.
