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

const REFUNDS_COLLECTION = "event_refunds";

export interface VerifiedEventRefundRequest {
  refundId: string;
  eventId: string;
  organizerUid: string;
  sourcePaymentOperationId: string;
  providerPaymentId: string;
  amountMinor: number;
  currency: string;
  reason: string;
  idempotencyKey: string;
}

/**
 * Reserves a provider-neutral event refund exactly once.
 *
 * This helper never marks money refunded. A verified provider event must
 * project the final refund state through the canonical payment lifecycle.
 *
 * @param {Firestore} firestore Firestore.
 * @param {Transaction} transaction Existing transaction.
 * @param {VerifiedEventRefundRequest} input Trusted refund request.
 * @return {Promise<{operationId:string,created:boolean}>} Reservation.
 */
export async function reserveVerifiedEventRefund(
  firestore: Firestore,
  transaction: Transaction,
  input: VerifiedEventRefundRequest,
): Promise<{
  operationId: string;
  created: boolean;
}> {
  const normalized = normalizeRefundRequest(input);
  const sourceOperationReference = firestore
    .collection("commercial_operations")
    .doc(normalized.sourcePaymentOperationId);
  const refundReference = firestore
    .collection(REFUNDS_COLLECTION)
    .doc(normalized.refundId);

  const [
    sourceOperationSnapshot,
    refundSnapshot,
  ] = await Promise.all([
    transaction.get(sourceOperationReference),
    transaction.get(refundReference),
  ]);

  if (!sourceOperationSnapshot.exists) {
    throw new Error(
      "Source payment operation was not found.",
    );
  }

  const sourceOperation =
    sourceOperationSnapshot.data() ?? {};

  assertRefundSource(
    sourceOperation,
    normalized,
  );

  if (refundSnapshot.exists) {
    const existing = refundSnapshot.data() ?? {};
    assertRefundReplay(existing, normalized);

    const existingOperationId =
      requiredString(
        existing.refundOperationId,
        "refundOperationId",
      );

    return {
      operationId: existingOperationId,
      created: false,
    };
  }

  const reservation =
    await reserveCommercialOperation(
      firestore,
      transaction,
      {
        userUid: normalized.organizerUid,
        type: "event_refund",
        provider: "external_payment_provider",
        idempotencyScope:
          `event_refund:${normalized.refundId}`,
        idempotencyKey:
          normalized.idempotencyKey,
        money: {
          currency: normalized.currency,
          grossAmountMinor:
            normalized.amountMinor,
          feeAmountMinor: 0,
          netAmountMinor:
            normalized.amountMinor,
        },
        relatedEventId:
          normalized.eventId,
        metadata: {
          refundId: normalized.refundId,
          sourcePaymentOperationId:
            normalized.sourcePaymentOperationId,
          providerPaymentId:
            normalized.providerPaymentId,
          reason: normalized.reason,
        },
      },
      {
        actorUid:
          "system:event_refund",
        source:
          "reserveVerifiedEventRefund",
      },
    );

  if (!reservation.created) {
    throw new Error(
      "Refund idempotency operation exists without refund record.",
    );
  }

  transaction.create(
    refundReference,
    {
      refundId: normalized.refundId,
      eventId: normalized.eventId,
      organizerUid:
        normalized.organizerUid,
      sourcePaymentOperationId:
        normalized.sourcePaymentOperationId,
      refundOperationId:
        reservation.operationId,
      provider:
        "external_payment_provider",
      providerPaymentId:
        normalized.providerPaymentId,
      providerRefundId: null,
      amountMinor:
        normalized.amountMinor,
      currency:
        normalized.currency,
      reason:
        normalized.reason,
      status: "refund_pending",
      createdAt:
        FieldValue.serverTimestamp(),
      updatedAt:
        FieldValue.serverTimestamp(),
    },
  );

  transitionCommercialOperation(
    firestore,
    transaction,
    reservation.operationId,
    "refund_pending",
    {
      actorUid:
        "system:event_refund",
      source:
        "reserveVerifiedEventRefund",
    },
    {
      refundId: normalized.refundId,
      sourcePaymentOperationId:
        normalized.sourcePaymentOperationId,
    },
  );

  writeAuditLogInTransaction(
    firestore,
    transaction,
    {
      action: "event_refund_reserved",
      performedBy:
        "system:event_refund",
      targetUid:
        normalized.organizerUid,
      metadata: {
        refundId:
          normalized.refundId,
        eventId:
          normalized.eventId,
        refundOperationId:
          reservation.operationId,
        sourcePaymentOperationId:
          normalized.sourcePaymentOperationId,
        amountMinor:
          normalized.amountMinor,
        currency:
          normalized.currency,
      },
    },
  );

  return {
    operationId: reservation.operationId,
    created: true,
  };
}

/**
 * Validates the source payment operation.
 *
 * @param {Record<string, unknown>} source Source operation.
 * @param {VerifiedEventRefundRequest} input Refund request.
 * @return {void}
 */
function assertRefundSource(
  source: Record<string, unknown>,
  input: VerifiedEventRefundRequest,
): void {
  if (
    requiredString(source.type, "sourceType") !==
      "event_payment" ||
    requiredString(
      source.relatedEventId,
      "sourceEventId",
    ) !== input.eventId ||
    requiredString(
      source.userUid,
      "sourceUserUid",
    ) !== input.organizerUid
  ) {
    throw new Error(
      "Refund source payment binding mismatch.",
    );
  }

  const state =
    requiredString(
      source.state,
      "sourceState",
    ).toLowerCase();

  if (
    state !== "paid" &&
    state !== "refund_pending" &&
    state !== "partially_refunded"
  ) {
    throw new Error(
      "Source payment is not refundable.",
    );
  }

  const currency =
    requiredString(
      source.currency,
      "sourceCurrency",
    ).toUpperCase();

  if (currency !== input.currency) {
    throw new Error(
      "Refund currency does not match source payment.",
    );
  }

  const grossAmountMinor =
    requiredMinor(
      source.grossAmountMinor,
      "sourceGrossAmountMinor",
    );

  if (input.amountMinor > grossAmountMinor) {
    throw new Error(
      "Refund amount exceeds source payment.",
    );
  }
}

/**
 * Validates idempotent refund replay.
 *
 * @param {Record<string, unknown>} existing Existing refund.
 * @param {VerifiedEventRefundRequest} input Refund request.
 * @return {void}
 */
function assertRefundReplay(
  existing: Record<string, unknown>,
  input: VerifiedEventRefundRequest,
): void {
  if (
    requiredString(
      existing.eventId,
      "eventId",
    ) !== input.eventId ||
    requiredString(
      existing.organizerUid,
      "organizerUid",
    ) !== input.organizerUid ||
    requiredString(
      existing.sourcePaymentOperationId,
      "sourcePaymentOperationId",
    ) !== input.sourcePaymentOperationId ||
    requiredString(
      existing.providerPaymentId,
      "providerPaymentId",
    ) !== input.providerPaymentId ||
    requiredMinor(
      existing.amountMinor,
      "amountMinor",
    ) !== input.amountMinor ||
    requiredString(
      existing.currency,
      "currency",
    ).toUpperCase() !== input.currency
  ) {
    throw new Error(
      "Refund replay does not match the existing request.",
    );
  }
}

/**
 * Normalizes a trusted refund request.
 *
 * @param {VerifiedEventRefundRequest} input Raw request.
 * @return {VerifiedEventRefundRequest} Normalized request.
 */
function normalizeRefundRequest(
  input: VerifiedEventRefundRequest,
): VerifiedEventRefundRequest {
  const currency =
    requiredString(
      input.currency,
      "currency",
    ).toUpperCase();

  if (!/^[A-Z]{3}$/.test(currency)) {
    throw new Error(
      "Refund currency must be a 3-letter ISO code.",
    );
  }

  const reason =
    requiredString(
      input.reason,
      "reason",
    );

  if (reason.length > 500) {
    throw new Error(
      "Refund reason is too long.",
    );
  }

  return {
    refundId:
      requiredString(
        input.refundId,
        "refundId",
      ),
    eventId:
      requiredString(
        input.eventId,
        "eventId",
      ),
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
    providerPaymentId:
      requiredString(
        input.providerPaymentId,
        "providerPaymentId",
      ),
    amountMinor:
      requiredPositiveMinor(
        input.amountMinor,
        "amountMinor",
      ),
    currency,
    reason,
    idempotencyKey:
      requiredString(
        input.idempotencyKey,
        "idempotencyKey",
      ),
  };
}

/**
 * Reads one required string.
 *
 * @param {unknown} value Raw value.
 * @param {string} field Field name.
 * @return {string} Normalized value.
 */
function requiredString(
  value: unknown,
  field: string,
): string {
  const normalized =
    String(value ?? "").trim();

  if (!normalized || normalized.length > 500) {
    throw new Error(`${field} is invalid.`);
  }

  return normalized;
}

/**
 * Reads one non-negative minor-unit amount.
 *
 * @param {unknown} value Raw value.
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
 * Reads one positive minor-unit amount.
 *
 * @param {unknown} value Raw value.
 * @param {string} field Field name.
 * @return {number} Amount.
 */
function requiredPositiveMinor(
  value: unknown,
  field: string,
): number {
  const amount =
    requiredMinor(value, field);

  if (amount <= 0) {
    throw new Error(`${field} must be positive.`);
  }

  return amount;
}
