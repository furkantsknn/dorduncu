import {
  FieldValue,
  Firestore,
  Transaction,
} from "firebase-admin/firestore";

import {
  reserveCommercialOperation,
  transitionCommercialOperation,
} from "../commercial/commercialLedger";
import {
  writeAuditLogInTransaction,
} from "../audit/writeAuditLog";
import {
  EventPayoutResult,
  VerifiedEventPayoutSettlement,
} from "./eventPaymentTypes";

const PAYOUTS_COLLECTION = "event_payouts";

/**
 * Reserves one provider-neutral payout after trusted settlement is known.
 *
 * Provider settlement, not catalog/event price, is authoritative for payout.
 *
 * @param {Firestore} firestore Firestore.
 * @param {Transaction} transaction Existing transaction.
 * @param {VerifiedEventPayoutSettlement} input Verified settlement.
 * @return {Promise<{operationId:string,created:boolean}>} Reservation.
 */
export async function reserveVerifiedEventPayout(
  firestore: Firestore,
  transaction: Transaction,
  input: VerifiedEventPayoutSettlement,
): Promise<{
  operationId: string;
  created: boolean;
}> {
  const normalized = normalizeSettlement(input);
  const payoutReference = firestore
    .collection(PAYOUTS_COLLECTION)
    .doc(normalized.payoutId);

  const payoutSnapshot = await transaction.get(
    payoutReference,
  );

  if (!payoutSnapshot.exists) {
    throw new Error(
      "Payout eligibility record was not found.",
    );
  }

  const payoutData = payoutSnapshot.data() ?? {};
  assertEligiblePayout(
    payoutData,
    normalized,
  );

  const existingOperationId = optionalString(
    payoutData.payoutOperationId,
  );
  const existingStatus = normalizeState(
    payoutData.status,
  );

  if (existingOperationId != null) {
    if (
      existingStatus === "payout_pending" ||
      existingStatus === "paid_out"
    ) {
      return {
        operationId: existingOperationId,
        created: false,
      };
    }

    throw new Error(
      "Existing payout operation requires review before retry.",
    );
  }

  const reservation =
    await reserveCommercialOperation(
      firestore,
      transaction,
      {
        userUid: normalized.organizerUid,
        type: "event_payout",
        provider: "external_payment_provider",
        idempotencyScope:
          `event_payout:${normalized.payoutId}`,
        idempotencyKey:
          normalized.idempotencyKey,
        money: {
          currency: normalized.currency,
          grossAmountMinor:
            normalized.grossAmountMinor,
          feeAmountMinor:
            normalized.feeAmountMinor,
          netAmountMinor:
            normalized.netAmountMinor,
        },
        relatedEventId:
          normalized.eventId,
        metadata: {
          payoutId: normalized.payoutId,
          sourcePaymentOperationId:
            normalized.sourcePaymentOperationId,
          settlementReference:
            normalized.settlementReference,
        },
      },
      {
        actorUid:
          "system:event_payout_settlement",
        source:
          "reserveVerifiedEventPayout",
      },
    );

  transaction.set(
    payoutReference,
    {
      payoutOperationId:
        reservation.operationId,
      payoutAmountMinor:
        normalized.netAmountMinor,
      payoutGrossAmountMinor:
        normalized.grossAmountMinor,
      payoutFeeAmountMinor:
        normalized.feeAmountMinor,
      currency:
        normalized.currency,
      amountStatus:
        "verified_provider_settlement",
      settlementReference:
        normalized.settlementReference,
      status: "payout_pending",
      eligibilityStatus: "eligible",
      provider: "external_payment_provider",
      providerPayoutId: null,
      payoutReservedAt:
        FieldValue.serverTimestamp(),
      updatedAt:
        FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  if (reservation.created) {
    transitionCommercialOperation(
      firestore,
      transaction,
      reservation.operationId,
      "payout_pending",
      {
        actorUid:
          "system:event_payout_settlement",
        source:
          "reserveVerifiedEventPayout",
      },
      {
        payoutId: normalized.payoutId,
        settlementReference:
          normalized.settlementReference,
      },
    );

    writeAuditLogInTransaction(
      firestore,
      transaction,
      {
        action: "event_payout_reserved",
        performedBy:
          "system:event_payout_settlement",
        targetUid:
          normalized.organizerUid,
        metadata: {
          payoutId: normalized.payoutId,
          eventId: normalized.eventId,
          payoutOperationId:
            reservation.operationId,
          currency: normalized.currency,
          grossAmountMinor:
            normalized.grossAmountMinor,
          feeAmountMinor:
            normalized.feeAmountMinor,
          netAmountMinor:
            normalized.netAmountMinor,
        },
      },
    );
  }

  return {
    operationId: reservation.operationId,
    created: reservation.created,
  };
}

/**
 * Applies a verified provider payout result.
 *
 * Only provider-verified state may move a payout to paid_out.
 *
 * @param {Firestore} firestore Firestore.
 * @param {Transaction} transaction Existing transaction.
 * @param {string} payoutId Payout id.
 * @param {string} operationId Commercial payout operation id.
 * @param {EventPayoutResult} result Verified provider result.
 * @return {Promise<boolean>} Whether state changed.
 */
export async function applyVerifiedEventPayoutResult(
  firestore: Firestore,
  transaction: Transaction,
  payoutId: string,
  operationId: string,
  result: EventPayoutResult,
): Promise<boolean> {
  const normalizedPayoutId =
    requiredString(payoutId, "payoutId");
  const normalizedOperationId =
    requiredString(operationId, "operationId");
  const providerPayoutId =
    requiredString(
      result.providerPayoutId,
      "providerPayoutId",
    );
  const nextState = normalizePayoutState(
    result.providerState,
  );

  const payoutReference = firestore
    .collection(PAYOUTS_COLLECTION)
    .doc(normalizedPayoutId);
  const operationReference = firestore
    .collection("commercial_operations")
    .doc(normalizedOperationId);

  const [
    payoutSnapshot,
    operationSnapshot,
  ] = await Promise.all([
    transaction.get(payoutReference),
    transaction.get(operationReference),
  ]);

  if (
    !payoutSnapshot.exists ||
    !operationSnapshot.exists
  ) {
    throw new Error(
      "Payout or commercial operation was not found.",
    );
  }

  const payoutData = payoutSnapshot.data() ?? {};
  const operationData =
    operationSnapshot.data() ?? {};

  assertPayoutOperationBinding(
    payoutData,
    operationData,
    normalizedPayoutId,
    normalizedOperationId,
  );

  const currentState = normalizeState(
    payoutData.status,
  );

  if (currentState === "paid_out") {
    if (
      nextState === "paid_out" &&
      optionalString(
        payoutData.providerPayoutId,
      ) === providerPayoutId
    ) {
      return false;
    }

    throw new Error(
      "A paid payout cannot be moved to another state.",
    );
  }

  if (currentState === "blocked") {
    throw new Error(
      "Blocked payout cannot receive provider completion.",
    );
  }

  if (
    currentState === "failed" &&
    nextState === "payout_pending"
  ) {
    throw new Error(
      "Failed payout requires explicit retry reservation.",
    );
  }

  if (currentState === nextState) {
    const existingProviderPayoutId =
      optionalString(
        payoutData.providerPayoutId,
      );

    if (
      existingProviderPayoutId == null ||
      existingProviderPayoutId ===
        providerPayoutId
    ) {
      return false;
    }

    throw new Error(
      "Provider payout identity mismatch.",
    );
  }

  transitionCommercialOperation(
    firestore,
    transaction,
    normalizedOperationId,
    nextState,
    {
      actorUid:
        "system:event_payout_provider",
      source:
        "applyVerifiedEventPayoutResult",
    },
    {
      payoutId: normalizedPayoutId,
      providerPayoutId,
    },
  );

  transaction.set(
    payoutReference,
    {
      status: nextState,
      providerPayoutId,
      ...(
        nextState === "paid_out" ?
          {
            paidOutAt:
              FieldValue.serverTimestamp(),
          } :
          {}
      ),
      ...(
        nextState === "failed" ?
          {
            failedAt:
              FieldValue.serverTimestamp(),
          } :
          {}
      ),
      updatedAt:
        FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  writeAuditLogInTransaction(
    firestore,
    transaction,
    {
      action:
        nextState === "paid_out" ?
          "event_payout_paid_out" :
          nextState === "failed" ?
            "event_payout_failed" :
            "event_payout_provider_pending",
      performedBy:
        "system:event_payout_provider",
      targetUid:
        requiredString(
          payoutData.organizerUid,
          "organizerUid",
        ),
      metadata: {
        payoutId: normalizedPayoutId,
        payoutOperationId:
          normalizedOperationId,
        providerPayoutId,
        state: nextState,
      },
    },
  );

  return true;
}

/**
 * Validates payout eligibility and settlement binding.
 *
 * @param {Record<string, unknown>} data Payout data.
 * @param {VerifiedEventPayoutSettlement} input Settlement.
 * @return {void}
 */
function assertEligiblePayout(
  data: Record<string, unknown>,
  input: VerifiedEventPayoutSettlement,
): void {
  if (normalizeState(data.status) !== "eligible") {
    throw new Error(
      "Payout is not currently eligible.",
    );
  }

  if (
    requiredString(data.eventId, "eventId") !==
      input.eventId ||
    requiredString(
      data.organizerUid,
      "organizerUid",
    ) !== input.organizerUid ||
    requiredString(
      data.sourcePaymentOperationId,
      "sourcePaymentOperationId",
    ) !== input.sourcePaymentOperationId
  ) {
    throw new Error(
      "Payout settlement binding mismatch.",
    );
  }

  const sourceCurrency =
    optionalString(data.currency);
  if (
    sourceCurrency != null &&
    sourceCurrency.toUpperCase() !==
      input.currency
  ) {
    throw new Error(
      "Payout settlement currency mismatch.",
    );
  }

  const sourceGross =
    optionalMinor(data.paymentGrossAmountMinor);
  if (
    sourceGross != null &&
    sourceGross !== input.grossAmountMinor
  ) {
    throw new Error(
      "Payout settlement gross amount mismatch.",
    );
  }
}

/**
 * Validates payout/commercial operation identity.
 *
 * @param {Record<string, unknown>} payoutData Payout.
 * @param {Record<string, unknown>} operationData Operation.
 * @param {string} payoutId Payout id.
 * @param {string} operationId Operation id.
 * @return {void}
 */
function assertPayoutOperationBinding(
  payoutData: Record<string, unknown>,
  operationData: Record<string, unknown>,
  payoutId: string,
  operationId: string,
): void {
  if (
    requiredString(
      payoutData.payoutOperationId,
      "payoutOperationId",
    ) !== operationId ||
    requiredString(
      operationData.type,
      "operationType",
    ) !== "event_payout" ||
    requiredString(
      operationData.relatedEventId,
      "relatedEventId",
    ) !== requiredString(
      payoutData.eventId,
      "eventId",
    ) ||
    requiredString(
      operationData.userUid,
      "operationUserUid",
    ) !== requiredString(
      payoutData.organizerUid,
      "organizerUid",
    )
  ) {
    throw new Error(
      "Payout commercial operation binding mismatch.",
    );
  }

  const metadata =
    operationData.metadata as
      Record<string, unknown> | undefined;
  if (
    metadata != null &&
    optionalString(metadata.payoutId) != null &&
    optionalString(metadata.payoutId) !== payoutId
  ) {
    throw new Error(
      "Payout metadata binding mismatch.",
    );
  }
}

/**
 * Normalizes and validates trusted settlement.
 *
 * @param {VerifiedEventPayoutSettlement} input Raw settlement.
 * @return {VerifiedEventPayoutSettlement} Normalized settlement.
 */
function normalizeSettlement(
  input: VerifiedEventPayoutSettlement,
): VerifiedEventPayoutSettlement {
  const grossAmountMinor =
    requiredMinor(
      input.grossAmountMinor,
      "grossAmountMinor",
    );
  const feeAmountMinor =
    requiredMinor(
      input.feeAmountMinor,
      "feeAmountMinor",
    );
  const netAmountMinor =
    requiredMinor(
      input.netAmountMinor,
      "netAmountMinor",
    );

  if (
    feeAmountMinor > grossAmountMinor ||
    grossAmountMinor - feeAmountMinor !==
      netAmountMinor
  ) {
    throw new Error(
      "Verified payout settlement money is inconsistent.",
    );
  }

  const currency =
    requiredString(
      input.currency,
      "currency",
    ).toUpperCase();

  if (!/^[A-Z]{3}$/.test(currency)) {
    throw new Error(
      "Payout currency must be a 3-letter ISO code.",
    );
  }

  return {
    payoutId:
      requiredString(input.payoutId, "payoutId"),
    eventId:
      requiredString(input.eventId, "eventId"),
    organizerUid:
      requiredString(
        input.organizerUid,
        "organizerUid",
      ),
    sourcePaymentOperationId:
      requiredString(
        input.sourcePaymentOperationId,
        "sourcePaymentOperationId",
      ),
    grossAmountMinor,
    feeAmountMinor,
    netAmountMinor,
    currency,
    settlementReference:
      requiredString(
        input.settlementReference,
        "settlementReference",
      ),
    idempotencyKey:
      requiredString(
        input.idempotencyKey,
        "idempotencyKey",
      ),
  };
}

/**
 * Normalizes provider payout state.
 *
 * @param {unknown} value Raw state.
 * @return {"payout_pending"|"paid_out"|"failed"} State.
 */
function normalizePayoutState(
  value: unknown,
): "payout_pending" | "paid_out" | "failed" {
  const state = normalizeState(value);

  if (
    state !== "payout_pending" &&
    state !== "paid_out" &&
    state !== "failed"
  ) {
    throw new Error(
      "Unsupported payout provider state.",
    );
  }

  return state;
}

/**
 * Reads one required string.
 *
 * @param {unknown} value Raw value.
 * @param {string} field Field name.
 * @return {string} Value.
 */
function requiredString(
  value: unknown,
  field: string,
): string {
  const normalized = String(value ?? "").trim();

  if (!normalized || normalized.length > 500) {
    throw new Error(`${field} is invalid.`);
  }

  return normalized;
}

/**
 * Reads one optional string.
 *
 * @param {unknown} value Raw value.
 * @return {string|null} Value.
 */
function optionalString(
  value: unknown,
): string | null {
  const normalized = String(value ?? "").trim();
  return normalized ? normalized : null;
}

/**
 * Reads one required non-negative minor-unit amount.
 *
 * @param {unknown} value Raw amount.
 * @param {string} field Field name.
 * @return {number} Amount.
 */
function requiredMinor(
  value: unknown,
  field: string,
): number {
  if (
    typeof value !== "number" ||
    !Number.isSafeInteger(value) ||
    value < 0
  ) {
    throw new Error(`${field} is invalid.`);
  }

  return value;
}

/**
 * Reads one optional non-negative minor-unit amount.
 *
 * @param {unknown} value Raw amount.
 * @return {number|null} Amount.
 */
function optionalMinor(
  value: unknown,
): number | null {
  if (
    typeof value !== "number" ||
    !Number.isSafeInteger(value) ||
    value < 0
  ) {
    return null;
  }

  return value;
}

/**
 * Normalizes one state.
 *
 * @param {unknown} value Raw state.
 * @return {string} State.
 */
function normalizeState(
  value: unknown,
): string {
  return String(value ?? "")
    .trim()
    .toLowerCase();
}
