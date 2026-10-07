import {createHash} from "crypto";
import {
  FieldValue,
  Firestore,
  Transaction,
} from "firebase-admin/firestore";

import {
  writeAuditLogInTransaction,
} from "../audit/writeAuditLog";

const PAYOUTS_COLLECTION = "event_payouts";
const REVIEW_COLLECTION = "commercial_review_queue";
const PAYOUT_LIFECYCLE_VERSION = 1;

export interface EventPayoutEligibilityInput {
  eventId: string;
  organizerUid: string;
  paymentStatus: string;
  sourcePaymentOperationId: string | null;
  eventReference:
    FirebaseFirestore.DocumentReference;
  paymentSessionReference:
    FirebaseFirestore.DocumentReference;
  paymentSessionExists: boolean;
}

export interface EventPayoutEligibilityResult {
  status: "eligible" | "review_required";
  payoutId: string;
  sourcePaymentOperationId: string | null;
}

/**
 * Creates or refreshes the canonical payout eligibility projection.
 *
 * No payout amount is finalized here. The external provider settlement must
 * become authoritative before an actual payout operation is reserved.
 *
 * @param {Firestore} firestore Firestore.
 * @param {Transaction} transaction Existing transaction.
 * @param {EventPayoutEligibilityInput} input Eligibility input.
 * @return {Promise<EventPayoutEligibilityResult>} Eligibility result.
 */
export async function markEventPayoutEligibleInTransaction(
  firestore: Firestore,
  transaction: Transaction,
  input: EventPayoutEligibilityInput,
): Promise<EventPayoutEligibilityResult> {
  const eventId = requireString(
    input.eventId,
    "eventId",
  );
  const organizerUid = requireString(
    input.organizerUid,
    "organizerUid",
  );
  const paymentStatus = normalizeState(
    input.paymentStatus,
  );
  const sourcePaymentOperationId =
    normalizeOptionalString(
      input.sourcePaymentOperationId,
    );

  if (!isPaidPaymentState(paymentStatus)) {
    throw new Error(
      "Payout eligibility requires a paid event payment.",
    );
  }

  const payoutId = buildEventPayoutId(
    eventId,
    sourcePaymentOperationId,
  );
  const payoutReference = firestore
    .collection(PAYOUTS_COLLECTION)
    .doc(payoutId);

  const reads: Array<Promise<
    FirebaseFirestore.DocumentSnapshot
  >> = [
    transaction.get(payoutReference),
  ];

  let paymentOperationReference:
    FirebaseFirestore.DocumentReference | null = null;

  if (sourcePaymentOperationId != null) {
    paymentOperationReference = firestore
      .collection("commercial_operations")
      .doc(sourcePaymentOperationId);
    reads.push(
      transaction.get(paymentOperationReference),
    );
  }

  const snapshots = await Promise.all(reads);
  const payoutSnapshot = snapshots[0];
  const operationSnapshot =
    snapshots.length > 1 ?
      snapshots[1] :
      null;

  const validation = validatePaymentOperation(
    operationSnapshot,
    eventId,
    organizerUid,
    sourcePaymentOperationId,
  );

  const status = validation.valid ?
    "eligible" :
    "review_required";
  const existingStatus =
    payoutSnapshot.exists ?
      normalizeOptionalString(
        payoutSnapshot.data()?.status,
      ) :
      null;
  const transitionChanged =
    existingStatus !== status;

  if (payoutSnapshot.exists) {
    assertExistingPayoutCompatibility(
      payoutSnapshot.data() ?? {},
      eventId,
      organizerUid,
      sourcePaymentOperationId,
    );
  }

  transaction.set(
    payoutReference,
    {
      payoutId,
      lifecycleVersion:
        PAYOUT_LIFECYCLE_VERSION,
      eventId,
      organizerUid,
      sourcePaymentOperationId,
      sourcePaymentState:
        validation.sourceState,
      status,
      eligibilityStatus: status,
      amountStatus:
        "pending_provider_settlement",
      currency:
        validation.currency,
      paymentGrossAmountMinor:
        validation.grossAmountMinor,
      payoutAmountMinor: null,
      provider: null,
      providerPayoutId: null,
      blockedReason:
        validation.reason,
      ...(
        status === "eligible" &&
        transitionChanged ?
          {
            eligibleAt:
              FieldValue.serverTimestamp(),
          } :
          {}
      ),
      ...(
        status === "review_required" &&
        transitionChanged ?
          {
            reviewRequiredAt:
              FieldValue.serverTimestamp(),
          } :
          {}
      ),
      updatedAt:
        FieldValue.serverTimestamp(),
      ...(payoutSnapshot.exists ? {} : {
        createdAt:
          FieldValue.serverTimestamp(),
      }),
    },
    {
      merge: true,
    },
  );

  const projection = {
    payoutStatus: status,
    payoutId,
    payoutAmountStatus:
      "pending_provider_settlement",
    payoutSourcePaymentOperationId:
      sourcePaymentOperationId,
    payoutEligibilityUpdatedAt:
      FieldValue.serverTimestamp(),
  };

  transaction.set(
    input.eventReference,
    projection,
    {
      merge: true,
    },
  );

  if (input.paymentSessionExists) {
    transaction.set(
      input.paymentSessionReference,
      projection,
      {
        merge: true,
      },
    );
  }

  if (
    status === "review_required" &&
    transitionChanged
  ) {
    queuePayoutReview(
      firestore,
      transaction,
      payoutId,
      eventId,
      organizerUid,
      sourcePaymentOperationId,
      validation.reason,
    );
  }

  if (transitionChanged) {
    writeAuditLogInTransaction(
      firestore,
      transaction,
      {
        action:
          status === "eligible" ?
            "event_payout_marked_eligible" :
            "event_payout_requires_review",
        performedBy:
          "system:event_payout_lifecycle",
        targetUid:
          organizerUid,
        metadata: {
          eventId,
          payoutId,
          sourcePaymentOperationId,
          sourcePaymentState:
            validation.sourceState,
          amountStatus:
            "pending_provider_settlement",
          blockedReason:
            validation.reason,
        },
      },
    );
  }

  return {
    status,
    payoutId,
    sourcePaymentOperationId,
  };
}


/**
 * Keeps an existing payout eligibility record aligned with later financial
 * provider states. This never creates payout eligibility before completion.
 *
 * @param {Firestore} firestore Firestore.
 * @param {Transaction} transaction Existing transaction.
 * @param {Record<string, unknown>} eventData Event snapshot data.
 * @param {string} financialState Verified payment/provider state.
 * @return {void}
 */
export function applyEventPayoutFinancialStateInTransaction(
  firestore: Firestore,
  transaction: Transaction,
  eventData: Record<string, unknown>,
  financialState: string,
): void {
  const payoutId = normalizeOptionalString(
    eventData.payoutId,
  );

  if (payoutId == null) {
    return;
  }

  const payoutReference = firestore
    .collection(PAYOUTS_COLLECTION)
    .doc(payoutId);
  const state = normalizeState(financialState);

  if (
    state === "refund_pending" ||
    state === "refunded" ||
    state === "partially_refunded" ||
    state === "dispute_review" ||
    state === "chargeback"
  ) {
    transaction.set(
      payoutReference,
      {
        status: "blocked",
        eligibilityStatus: "blocked",
        blockedReason:
          `payment_${state}`,
        blockedAt:
          FieldValue.serverTimestamp(),
        updatedAt:
          FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    return;
  }

  if (
    state === "paid" &&
    isCompletedEvent(eventData)
  ) {
    transaction.set(
      payoutReference,
      {
        status: "eligible",
        eligibilityStatus: "eligible",
        blockedReason: null,
        blockedAt: null,
        revalidatedAt:
          FieldValue.serverTimestamp(),
        updatedAt:
          FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  }
}

/**
 * Detects canonical/legacy completed event states.
 *
 * @param {Record<string, unknown>} eventData Event data.
 * @return {boolean} Whether event is completed.
 */
function isCompletedEvent(
  eventData: Record<string, unknown>,
): boolean {
  const status = normalizeState(
    eventData.status ?? eventData.durum,
  );
  return status === "completed" ||
    status === "tamamlandi";
}

interface PaymentOperationValidation {
  valid: boolean;
  sourceState: string | null;
  currency: string | null;
  grossAmountMinor: number | null;
  reason: string | null;
}

/**
 * Validates that the payout is bound to one canonical paid event payment.
 *
 * @param {FirebaseFirestore.DocumentSnapshot|null} snapshot Operation.
 * @param {string} eventId Event id.
 * @param {string} organizerUid Organizer uid.
 * @param {string|null} operationId Source payment operation id.
 * @return {PaymentOperationValidation} Validation result.
 */
function validatePaymentOperation(
  snapshot: FirebaseFirestore.DocumentSnapshot | null,
  eventId: string,
  organizerUid: string,
  operationId: string | null,
): PaymentOperationValidation {
  if (operationId == null) {
    return invalidValidation(
      "missing_source_payment_operation",
    );
  }

  if (snapshot == null || !snapshot.exists) {
    return invalidValidation(
      "source_payment_operation_not_found",
    );
  }

  const data = snapshot.data() ?? {};
  const state = normalizeOptionalString(
    data.state,
  );
  const type = normalizeOptionalString(
    data.type,
  );
  const userUid = normalizeOptionalString(
    data.userUid,
  );
  const relatedEventId = normalizeOptionalString(
    data.relatedEventId,
  );
  const provider = normalizeOptionalString(
    data.provider,
  );
  const currency = normalizeCurrencyOrNull(
    data.currency,
  );
  const grossAmountMinor = normalizeMinorOrNull(
    data.grossAmountMinor,
  );

  const base = {
    sourceState: state,
    currency,
    grossAmountMinor,
  };

  if (type !== "event_payment") {
    return {
      ...base,
      valid: false,
      reason: "source_operation_type_mismatch",
    };
  }

  if (relatedEventId !== eventId) {
    return {
      ...base,
      valid: false,
      reason: "source_event_binding_mismatch",
    };
  }

  if (userUid !== organizerUid) {
    return {
      ...base,
      valid: false,
      reason: "source_payer_binding_mismatch",
    };
  }

  if (provider !== "external_payment_provider") {
    return {
      ...base,
      valid: false,
      reason: "source_provider_mismatch",
    };
  }

  if (state !== "paid") {
    return {
      ...base,
      valid: false,
      reason: "source_payment_not_paid",
    };
  }

  if (currency == null || grossAmountMinor == null) {
    return {
      ...base,
      valid: false,
      reason: "source_money_invalid",
    };
  }

  return {
    ...base,
    valid: true,
    reason: null,
  };
}

/**
 * Creates a deterministic finance review item for legacy/incomplete payouts.
 *
 * @param {Firestore} firestore Firestore.
 * @param {Transaction} transaction Transaction.
 * @param {string} payoutId Payout id.
 * @param {string} eventId Event id.
 * @param {string} organizerUid Organizer uid.
 * @param {string|null} operationId Payment operation id.
 * @param {string|null} reason Review reason.
 * @return {void}
 */
function queuePayoutReview(
  firestore: Firestore,
  transaction: Transaction,
  payoutId: string,
  eventId: string,
  organizerUid: string,
  operationId: string | null,
  reason: string | null,
): void {
  const reference = firestore
    .collection(REVIEW_COLLECTION)
    .doc(`event_payout_${payoutId}`);

  transaction.set(
    reference,
    {
      reviewType: "event_payout",
      reviewState: "pending",
      financialState: "review_required",
      payoutId,
      eventId,
      organizerUid,
      sourcePaymentOperationId:
        operationId,
      reason,
      source:
        "event_payout_lifecycle",
      createdAt:
        FieldValue.serverTimestamp(),
      updatedAt:
        FieldValue.serverTimestamp(),
    },
    {
      merge: true,
    },
  );
}

/**
 * Ensures retry cannot rebind an existing payout to another event or payer.
 *
 * @param {Record<string, unknown>} data Existing payout.
 * @param {string} eventId Event id.
 * @param {string} organizerUid Organizer uid.
 * @param {string|null} operationId Source payment operation id.
 * @return {void}
 */
function assertExistingPayoutCompatibility(
  data: Record<string, unknown>,
  eventId: string,
  organizerUid: string,
  operationId: string | null,
): void {
  const existingEventId = normalizeOptionalString(
    data.eventId,
  );
  const existingOrganizerUid = normalizeOptionalString(
    data.organizerUid,
  );
  const existingOperationId = normalizeOptionalString(
    data.sourcePaymentOperationId,
  );

  if (
    existingEventId !== eventId ||
    existingOrganizerUid !== organizerUid ||
    existingOperationId !== operationId
  ) {
    throw new Error(
      "Existing payout eligibility binding mismatch.",
    );
  }
}

/**
 * Builds a deterministic payout eligibility identity.
 *
 * @param {string} eventId Event id.
 * @param {string|null} operationId Source payment operation id.
 * @return {string} SHA-256 payout id.
 */
function buildEventPayoutId(
  eventId: string,
  operationId: string | null,
): string {
  return createHash("sha256")
    .update(
      [
        "event_payout:v1",
        eventId,
        operationId ?? "legacy",
      ].join(":"),
      "utf8",
    )
    .digest("hex");
}

/**
 * Creates an invalid payment operation result.
 *
 * @param {string} reason Reason.
 * @return {PaymentOperationValidation} Invalid result.
 */
function invalidValidation(
  reason: string,
): PaymentOperationValidation {
  return {
    valid: false,
    sourceState: null,
    currency: null,
    grossAmountMinor: null,
    reason,
  };
}

/**
 * Checks accepted paid aliases used by current and legacy event documents.
 *
 * @param {string} state Payment state.
 * @return {boolean} Whether payment is paid.
 */
function isPaidPaymentState(
  state: string,
): boolean {
  return state === "paid" ||
    state === "completed" ||
    state === "escrowheld" ||
    state === "escrow_held";
}

/**
 * Normalizes a state string.
 *
 * @param {unknown} value Value.
 * @return {string} Normalized state.
 */
function normalizeState(value: unknown): string {
  return String(value ?? "")
    .trim()
    .toLowerCase();
}

/**
 * Reads a required string.
 *
 * @param {unknown} value Value.
 * @param {string} fieldName Field name.
 * @return {string} Required string.
 */
function requireString(
  value: unknown,
  fieldName: string,
): string {
  const normalized = String(value ?? "").trim();

  if (!normalized) {
    throw new Error(`${fieldName} is required.`);
  }

  return normalized;
}

/**
 * Reads an optional string.
 *
 * @param {unknown} value Value.
 * @return {string|null} Optional string.
 */
function normalizeOptionalString(
  value: unknown,
): string | null {
  const normalized = String(value ?? "").trim();
  return normalized || null;
}

/**
 * Reads a currency value when structurally valid.
 *
 * @param {unknown} value Value.
 * @return {string|null} Currency.
 */
function normalizeCurrencyOrNull(
  value: unknown,
): string | null {
  const currency = String(value ?? "")
    .trim()
    .toUpperCase();

  return /^[A-Z]{3}$/.test(currency) ?
    currency :
    null;
}

/**
 * Reads a positive integer minor-unit amount.
 *
 * @param {unknown} value Value.
 * @return {number|null} Minor amount.
 */
function normalizeMinorOrNull(
  value: unknown,
): number | null {
  const amount = Number(value);

  if (
    !Number.isSafeInteger(amount) ||
    amount <= 0
  ) {
    return null;
  }

  return amount;
}
