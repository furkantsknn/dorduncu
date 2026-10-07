/* eslint-disable max-len */
import {createHash} from "crypto";
import {
  FieldValue,
  Firestore,
  Transaction,
} from "firebase-admin/firestore";
import {
  CommercialActorContext,
  CommercialMoney,
  CommercialOperationIdentity,
  CommercialOperationInput,
  CommercialOperationReservation,
  CommercialState,
} from "./commercialTypes";

const OPERATIONS_COLLECTION = "commercial_operations";
const IDEMPOTENCY_COLLECTION = "commercial_idempotency";
const EVENTS_SUBCOLLECTION = "events";
const IDEMPOTENCY_VERSION = 1;
const LEDGER_VERSION = 1;

/**
 * Creates a deterministic commercial operation identity.
 *
 * Raw provider tokens or raw idempotency keys are never stored as document ids.
 *
 * @param {string} scope Stable idempotency scope.
 * @param {string} key Provider/client idempotency key.
 * @return {CommercialOperationIdentity} Deterministic identity.
 */
export function buildCommercialOperationIdentity(
  scope: string,
  key: string,
): CommercialOperationIdentity {
  const normalizedScope = normalizeRequiredString(
    scope,
    "idempotencyScope",
  );
  const normalizedKey = normalizeRequiredString(
    key,
    "idempotencyKey",
  );

  const digest = createHash("sha256")
    .update(
      [
        `v${IDEMPOTENCY_VERSION}`,
        normalizedScope,
        normalizedKey,
      ].join(":"),
      "utf8",
    )
    .digest("hex");

  return {
    operationId: digest,
    idempotencyHash: digest,
  };
}

/**
 * Reserves a commercial operation exactly once inside a Firestore transaction.
 *
 * The caller must invoke this before writing entitlement, wallet, payment,
 * refund or payout side effects in the same transaction. When created=false,
 * the caller must not repeat those side effects.
 *
 * @param {Firestore} firestore Firestore instance.
 * @param {Transaction} transaction Existing transaction.
 * @param {CommercialOperationInput} input Commercial operation input.
 * @param {CommercialActorContext} actor Audit actor context.
 * @return {Promise<CommercialOperationReservation>} Reservation result.
 */
export async function reserveCommercialOperation(
  firestore: Firestore,
  transaction: Transaction,
  input: CommercialOperationInput,
  actor: CommercialActorContext,
): Promise<CommercialOperationReservation> {
  validateCommercialInput(input);

  const identity = buildCommercialOperationIdentity(
    input.idempotencyScope,
    input.idempotencyKey,
  );

  const operationReference = firestore
    .collection(OPERATIONS_COLLECTION)
    .doc(identity.operationId);
  const idempotencyReference = firestore
    .collection(IDEMPOTENCY_COLLECTION)
    .doc(identity.idempotencyHash);

  const [idempotencySnapshot, operationSnapshot] =
    await Promise.all([
      transaction.get(idempotencyReference),
      transaction.get(operationReference),
    ]);

  if (idempotencySnapshot.exists) {
    const existingOperationId = String(
      idempotencySnapshot.data()?.operationId ?? "",
    ).trim();

    if (
      existingOperationId !== identity.operationId
    ) {
      throw new Error(
        "Commercial idempotency mapping integrity violation.",
      );
    }

    if (!operationSnapshot.exists) {
      throw new Error(
        "Commercial idempotency marker has no operation.",
      );
    }

    const existingData = operationSnapshot.data() ?? {};

    assertReplayCompatibility(
      existingData,
      input,
    );

    const existingState = normalizeCommercialState(
      existingData.state,
    );

    return {
      operationId: identity.operationId,
      created: false,
      existingState,
    };
  }

  if (operationSnapshot.exists) {
    throw new Error(
      "Commercial operation exists without idempotency marker.",
    );
  }

  const money = normalizeMoney(input.money);
  const actorUid = normalizeRequiredString(
    actor.actorUid,
    "actorUid",
  );
  const actorSource = normalizeRequiredString(
    actor.source,
    "actorSource",
  );

  transaction.create(
    operationReference,
    {
      operationId: identity.operationId,
      ledgerVersion: LEDGER_VERSION,
      userUid: normalizeRequiredString(
        input.userUid,
        "userUid",
      ),
      type: input.type,
      provider: input.provider,
      state: "created",
      currency: money.currency,
      grossAmountMinor: money.grossAmountMinor,
      feeAmountMinor: money.feeAmountMinor,
      netAmountMinor: money.netAmountMinor,
      providerTransactionId:
        normalizeOptionalString(
          input.providerTransactionId,
        ),
      providerReference:
        normalizeOptionalString(
          input.providerReference,
        ),
      relatedEventId:
        normalizeOptionalString(
          input.relatedEventId,
        ),
      relatedProductId:
        normalizeOptionalString(
          input.relatedProductId,
        ),
      metadata: input.metadata ?? {},
      createdByUid: actorUid,
      createdBySource: actorSource,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
  );

  transaction.create(
    idempotencyReference,
    {
      idempotencyHash: identity.idempotencyHash,
      idempotencyVersion: IDEMPOTENCY_VERSION,
      operationId: identity.operationId,
      scope: normalizeRequiredString(
        input.idempotencyScope,
        "idempotencyScope",
      ),
      createdAt: FieldValue.serverTimestamp(),
    },
  );

  appendCommercialEvent(
    firestore,
    transaction,
    identity.operationId,
    {
      state: "created",
      actorUid,
      actorSource,
      metadata: {
        type: input.type,
        provider: input.provider,
      },
    },
  );

  return {
    operationId: identity.operationId,
    created: true,
    existingState: "created",
  };
}

interface CommercialEventInput {
  state: CommercialState;
  actorUid: string;
  actorSource: string;
  metadata?: Record<string, unknown>;
}

/**
 * Appends one immutable commercial state event.
 *
 * This helper only creates a new event document. Existing event documents
 * are never updated or deleted by the commercial layer.
 *
 * @param {Firestore} firestore Firestore instance.
 * @param {Transaction} transaction Existing transaction.
 * @param {string} operationId Commercial operation id.
 * @param {CommercialEventInput} input Event details.
 * @return {void}
 */
export function appendCommercialEvent(
  firestore: Firestore,
  transaction: Transaction,
  operationId: string,
  input: CommercialEventInput,
): void {
  const normalizedOperationId = normalizeRequiredString(
    operationId,
    "operationId",
  );

  const eventReference = firestore
    .collection(OPERATIONS_COLLECTION)
    .doc(normalizedOperationId)
    .collection(EVENTS_SUBCOLLECTION)
    .doc();

  transaction.create(
    eventReference,
    {
      operationId: normalizedOperationId,
      state: input.state,
      actorUid: normalizeRequiredString(
        input.actorUid,
        "actorUid",
      ),
      actorSource: normalizeRequiredString(
        input.actorSource,
        "actorSource",
      ),
      metadata: input.metadata ?? {},
      ledgerVersion: LEDGER_VERSION,
      createdAt: FieldValue.serverTimestamp(),
    },
  );
}

/**
 * Updates the mutable operation summary and appends an immutable state event.
 *
 * The operation summary is only a projection. The events subcollection is the
 * append-only history used for commercial traceability.
 *
 * @param {Firestore} firestore Firestore instance.
 * @param {Transaction} transaction Existing transaction.
 * @param {string} operationId Commercial operation id.
 * @param {CommercialState} nextState New commercial state.
 * @param {CommercialActorContext} actor State-change actor.
 * @param {Record<string, unknown>} metadata Optional transition metadata.
 * @return {void}
 */
export function transitionCommercialOperation(
  firestore: Firestore,
  transaction: Transaction,
  operationId: string,
  nextState: CommercialState,
  actor: CommercialActorContext,
  metadata: Record<string, unknown> = {},
): void {
  const normalizedOperationId = normalizeRequiredString(
    operationId,
    "operationId",
  );

  const operationReference = firestore
    .collection(OPERATIONS_COLLECTION)
    .doc(normalizedOperationId);

  transaction.update(
    operationReference,
    {
      state: nextState,
      updatedAt: FieldValue.serverTimestamp(),
      lastTransitionByUid: normalizeRequiredString(
        actor.actorUid,
        "actorUid",
      ),
      lastTransitionSource: normalizeRequiredString(
        actor.source,
        "actorSource",
      ),
    },
  );

  appendCommercialEvent(
    firestore,
    transaction,
    normalizedOperationId,
    {
      state: nextState,
      actorUid: actor.actorUid,
      actorSource: actor.source,
      metadata,
    },
  );
}

/**
 * Ensures an idempotent replay belongs to the same commercial operation.
 *
 * A purchase token or provider id must never be replayed by another user,
 * operation type, provider or product.
 *
 * @param {Record<string, unknown>} existing Existing operation data.
 * @param {CommercialOperationInput} input Incoming operation.
 * @return {void}
 */
function assertReplayCompatibility(
  existing: Record<string, unknown>,
  input: CommercialOperationInput,
): void {
  const existingUserUid = String(
    existing.userUid ?? "",
  ).trim();
  const existingType = String(
    existing.type ?? "",
  ).trim();
  const existingProvider = String(
    existing.provider ?? "",
  ).trim();
  const existingProductId = String(
    existing.relatedProductId ?? "",
  ).trim();

  const incomingProductId = String(
    input.relatedProductId ?? "",
  ).trim();

  if (
    existingUserUid !== input.userUid ||
    existingType !== input.type ||
    existingProvider !== input.provider ||
    existingProductId !== incomingProductId
  ) {
    throw new Error(
      "Commercial idempotency replay does not match original operation.",
    );
  }
}

/**
 * Validates commercial operation input.
 *
 * @param {CommercialOperationInput} input Commercial operation input.
 * @return {void}
 */
function validateCommercialInput(
  input: CommercialOperationInput,
): void {
  normalizeRequiredString(input.userUid, "userUid");
  normalizeRequiredString(
    input.idempotencyScope,
    "idempotencyScope",
  );
  normalizeRequiredString(
    input.idempotencyKey,
    "idempotencyKey",
  );
  normalizeMoney(input.money);
}

/**
 * Validates and normalizes monetary values.
 *
 * All monetary amounts are integer minor units, e.g. kuruş.
 *
 * @param {CommercialMoney} money Commercial money.
 * @return {CommercialMoney} Normalized money.
 */
function normalizeMoney(
  money: CommercialMoney,
): CommercialMoney {
  const currency = String(
    money.currency ?? "",
  )
    .trim()
    .toUpperCase();

  if (!/^[A-Z]{3}$/.test(currency)) {
    throw new Error(
      "Commercial currency must be a 3-letter ISO code.",
    );
  }

  const grossAmountMinor = normalizeMinorAmount(
    money.grossAmountMinor,
    "grossAmountMinor",
  );
  const feeAmountMinor = normalizeMinorAmount(
    money.feeAmountMinor,
    "feeAmountMinor",
  );
  const netAmountMinor = normalizeMinorAmount(
    money.netAmountMinor,
    "netAmountMinor",
  );

  if (feeAmountMinor > grossAmountMinor) {
    throw new Error(
      "Commercial fee cannot exceed gross amount.",
    );
  }

  if (
    grossAmountMinor - feeAmountMinor !== netAmountMinor
  ) {
    throw new Error(
      "Commercial net amount must equal gross minus fee.",
    );
  }

  return {
    currency,
    grossAmountMinor,
    feeAmountMinor,
    netAmountMinor,
  };
}

/**
 * Normalizes an integer minor-unit amount.
 *
 * @param {number} value Raw amount.
 * @param {string} field Field name.
 * @return {number} Safe minor-unit amount.
 */
function normalizeMinorAmount(
  value: number,
  field: string,
): number {
  if (
    !Number.isSafeInteger(value) ||
    value < 0
  ) {
    throw new Error(
      `${field} must be a non-negative safe integer.`,
    );
  }

  return value;
}

/**
 * Reads one required normalized string.
 *
 * @param {unknown} value Raw value.
 * @param {string} field Field name.
 * @return {string} Normalized string.
 */
function normalizeRequiredString(
  value: unknown,
  field: string,
): string {
  const normalized = String(value ?? "").trim();

  if (!normalized) {
    throw new Error(
      `${field} is required.`,
    );
  }

  if (normalized.length > 2000) {
    throw new Error(
      `${field} is too long.`,
    );
  }

  return normalized;
}

/**
 * Reads one optional normalized string.
 *
 * @param {unknown} value Raw value.
 * @return {string|null} Normalized value.
 */
function normalizeOptionalString(
  value: unknown,
): string | null {
  const normalized = String(value ?? "").trim();

  if (!normalized) {
    return null;
  }

  if (normalized.length > 2000) {
    throw new Error(
      "Commercial optional string is too long.",
    );
  }

  return normalized;
}

/**
 * Normalizes an existing commercial state.
 *
 * @param {unknown} value Raw state.
 * @return {CommercialState|undefined} Known state.
 */
function normalizeCommercialState(
  value: unknown,
): CommercialState | undefined {
  const state = String(value ?? "").trim();

  switch (state) {
  case "created":
  case "pending":
  case "processing":
  case "authorized":
  case "paid":
  case "failed":
  case "cancelled":
  case "refund_pending":
  case "refunded":
  case "partially_refunded":
  case "dispute_review":
  case "chargeback":
  case "payout_pending":
  case "paid_out":
    return state;

  default:
    return undefined;
  }
}
