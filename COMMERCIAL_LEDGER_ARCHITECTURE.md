# COMMERCIAL LEDGER FOUNDATION

## Collections

### commercial_operations/{operationId}
Mutable server-only summary/projection.

Core fields:
- operationId
- ledgerVersion
- userUid
- type
- provider
- state
- currency
- grossAmountMinor
- feeAmountMinor
- netAmountMinor
- providerTransactionId
- providerReference
- relatedEventId
- relatedProductId
- metadata
- createdByUid
- createdBySource
- createdAt
- updatedAt

### commercial_operations/{operationId}/events/{eventId}
Append-only immutable state history.

### commercial_idempotency/{sha256}
Server-only immutable idempotency reservation.

Raw purchase token / idempotency secret is not used as a document id.

## Required calling pattern

Future purchase/payment functions must:

1. Start one Firestore transaction.
2. Call reserveCommercialOperation first.
3. If created == false:
   - return existing operation result.
   - DO NOT apply entitlement/wallet/payment side effects again.
4. If created == true:
   - apply business side effects in same transaction.
   - transition state with transitionCommercialOperation where appropriate.
5. Provider callback/webhook uses its provider event/transaction identity as a
   stable idempotency scope+key.
6. Client success UI never marks the operation paid.

## Money rule

All amounts are integer minor units:
- TRY 10.50 = 1050
- no floating point money storage
