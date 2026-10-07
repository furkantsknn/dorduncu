# GOOGLE PLAY BILLING CLIENT BOUNDARY

Flutter client responsibilities:
1. Query Google Play product metadata.
2. Launch the Play purchase UI.
3. Receive PurchaseDetails.
4. Send serverVerificationData / purchase token to backend.
5. Wait for backend verification + entitlement result.
6. Only then complete/acknowledge the purchase as instructed by the backend
   integration.

Flutter client MUST NOT:
- write Plus entitlement
- write owned badge
- mark commercial operation paid
- trust a local "success" screen as payment proof
- use wallet balance as Android production authority for digital goods

Backend verification comes in the next package.
