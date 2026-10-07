import {createHash} from "crypto";
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
  EventPaymentIntentInput,
  EventPaymentIntentResult,
  EventPaymentProviderState,
  EventPaymentWebhookEvent,
} from "./eventPaymentTypes";
import {
  applyEventPaymentLifecycleProjection,
  PaymentLifecycleContext,
  readEventPaymentLifecycleContext,
} from "./eventPaymentLifecycle";
import {
  writeUserNotificationInTransaction,
} from "../notifications/writeUserNotification";
import {
  writeAuditLogInTransaction,
} from "../audit/writeAuditLog";
import {
  applyEventPayoutFinancialStateInTransaction,
} from "./eventPayoutLifecycle";

const INTENTS_COLLECTION =
  "event_payment_intents";
const PROVIDER_EVENTS_COLLECTION =
  "event_payment_provider_events";

/**
 * Reserves a real-world event payment operation before calling a provider.
 *
 * The provider network request must happen only when created=true.
 *
 * @param {Firestore} firestore Firestore.
 * @param {Transaction} transaction Firestore transaction.
 * @param {EventPaymentIntentInput} input Payment input.
 * @return {Promise<{operationId:string,created:boolean}>} Reservation.
 */
export async function reserveEventPaymentIntent(
  firestore: Firestore,
  transaction: Transaction,
  input: EventPaymentIntentInput,
): Promise<{
  operationId: string;
  created: boolean;
}> {
  validateMoney(
    input.money.currency,
    input.money.grossAmountMinor,
  );

  const reservation =
    await reserveCommercialOperation(
      firestore,
      transaction,
      {
        userUid: input.payerUid,
        type: "event_payment",
        provider:
          "external_payment_provider",
        idempotencyScope:
          `event_payment:${input.eventId}:` +
          `${input.applicationId}`,
        idempotencyKey:
          input.idempotencyKey,
        money: {
          currency:
            normalizeCurrency(
              input.money.currency,
            ),
          grossAmountMinor:
            input.money.grossAmountMinor,
          feeAmountMinor: 0,
          netAmountMinor:
            input.money.grossAmountMinor,
        },
        relatedEventId:
          input.eventId,
        metadata: {
          applicationId:
            input.applicationId,
          organizerUid:
            input.organizerUid,
          providerConfigured:
            false,
        },
      },
      {
        actorUid:
          input.payerUid,
        source:
          "reserveEventPaymentIntent",
      },
    );

  if (!reservation.created) {
    return {
      operationId:
        reservation.operationId,
      created: false,
    };
  }

  const intentReference = firestore
    .collection(INTENTS_COLLECTION)
    .doc(reservation.operationId);

  transaction.create(
    intentReference,
    {
      operationId:
        reservation.operationId,
      eventId:
        input.eventId,
      applicationId:
        input.applicationId,
      payerUid:
        input.payerUid,
      organizerUid:
        input.organizerUid,
      provider:
        "external_payment_provider",
      state: "created",
      currency:
        normalizeCurrency(
          input.money.currency,
        ),
      grossAmountMinor:
        input.money.grossAmountMinor,
      providerPaymentId: null,
      checkoutUrl: null,
      expiresAt: null,
      createdAt:
        FieldValue.serverTimestamp(),
      updatedAt:
        FieldValue.serverTimestamp(),
    },
  );

  return {
    operationId:
      reservation.operationId,
    created: true,
  };
}

/**
 * Persists the provider payment intent result.
 *
 * @param {Firestore} firestore Firestore.
 * @param {Transaction} transaction Firestore transaction.
 * @param {string} operationId Commercial operation id.
 * @param {EventPaymentIntentResult} result Provider result.
 * @return {void}
 */
export function applyProviderIntentResult(
  firestore: Firestore,
  transaction: Transaction,
  operationId: string,
  result: EventPaymentIntentResult,
): void {
  const state =
    normalizeProviderState(
      result.providerState,
    );

  const intentReference = firestore
    .collection(INTENTS_COLLECTION)
    .doc(operationId);

  transaction.set(
    intentReference,
    {
      provider:
        result.provider,
      providerPaymentId:
        result.providerPaymentId,
      providerState:
        state,
      checkoutUrl:
        result.checkoutUrl,
      expiresAt:
        result.expiresAt,
      rawReference:
        result.rawReference ?? null,
      updatedAt:
        FieldValue.serverTimestamp(),
    },
    {
      merge: true,
    },
  );

  transitionCommercialOperation(
    firestore,
    transaction,
    operationId,
    state,
    {
      actorUid:
        "system:event_payment_provider",
      source:
        "applyProviderIntentResult",
    },
    {
      provider:
        result.provider,
      providerPaymentId:
        result.providerPaymentId,
    },
  );
}

/**
 * Marks a reserved event payment intent as failed.
 *
 * @param {Firestore} firestore Firestore.
 * @param {Transaction} transaction Firestore transaction.
 * @param {string} operationId Commercial operation id.
 * @param {string} reason Safe server-side reason.
 * @return {void}
 */
export function failEventPaymentIntent(
  firestore: Firestore,
  transaction: Transaction,
  operationId: string,
  reason: string,
): void {
  const intentReference = firestore
    .collection(INTENTS_COLLECTION)
    .doc(operationId);

  transaction.set(
    intentReference,
    {
      state: "failed",
      providerState: "failed",
      failureReason:
        reason.slice(0, 300),
      failedAt:
        FieldValue.serverTimestamp(),
      updatedAt:
        FieldValue.serverTimestamp(),
    },
    {
      merge: true,
    },
  );

  transitionCommercialOperation(
    firestore,
    transaction,
    operationId,
    "failed",
    {
      actorUid:
        "system:event_payment_provider",
      source:
        "failEventPaymentIntent",
    },
    {
      failureReason:
        reason.slice(0, 300),
    },
  );
}

/**
 * Applies a verified provider webhook exactly once.
 *
 * The caller must verify the provider signature before calling this helper.
 *
 * @param {Firestore} firestore Firestore.
 * @param {Transaction} transaction Firestore transaction.
 * @param {string} operationId Commercial operation id.
 * @param {EventPaymentWebhookEvent} event Verified provider event.
 * @return {Promise<boolean>} True when newly processed.
 */
export async function applyVerifiedPaymentWebhook(
  firestore: Firestore,
  transaction: Transaction,
  operationId: string,
  event: EventPaymentWebhookEvent,
): Promise<boolean> {
  const providerEventId =
    requireString(
      event.providerEventId,
      "providerEventId",
    );

  const providerEventReference = firestore
    .collection(
      PROVIDER_EVENTS_COLLECTION,
    )
    .doc(
      buildProviderEventDocumentId(
        event.provider,
        providerEventId,
      ),
    );

  const intentReference = firestore
    .collection(INTENTS_COLLECTION)
    .doc(operationId);

  const [
    providerEventSnapshot,
    intentSnapshot,
  ] = await Promise.all([
    transaction.get(
      providerEventReference,
    ),
    transaction.get(
      intentReference,
    ),
  ]);

  if (providerEventSnapshot.exists) {
    return false;
  }

  if (!intentSnapshot.exists) {
    throw new Error(
      "Verified provider event references a missing payment intent.",
    );
  }

  const intentData =
    intentSnapshot.data() ?? {};

  assertProviderPaymentMatches(
    intentData,
    event,
  );

  const state =
    normalizeProviderState(
      event.state,
    );

  const lifecycleContext =
    await readEventPaymentLifecycleContext(
      firestore,
      transaction,
      operationId,
    );

  const previousState =
    normalizeExistingProviderState(
      intentData.providerState ??
      intentData.state,
    );

  const transitionAllowed =
    isAllowedProviderTransition(
      previousState,
      state,
    );

  transaction.create(
    providerEventReference,
    {
      provider:
        event.provider,
      providerEventId,
      providerPaymentId:
        event.providerPaymentId,
      operationId,
      state,
      previousState:
        previousState ?? null,
      projectionApplied:
        transitionAllowed,
      currency:
        event.currency == null ?
          null :
          normalizeCurrency(
            event.currency,
          ),
      grossAmountMinor:
        normalizeOptionalMoney(
          event.grossAmountMinor,
        ),
      refundAmountMinor:
        normalizeOptionalMoney(
          event.refundAmountMinor,
        ),
      disputeReason:
        normalizeOptionalString(
          event.disputeReason,
        ),
      occurredAt:
        event.occurredAt,
      metadata:
        sanitizeProviderMetadata(
          event.metadata,
        ),
      createdAt:
        FieldValue.serverTimestamp(),
    },
  );

  if (!transitionAllowed) {
    transaction.set(
      intentReference,
      {
        lastIgnoredProviderEventId:
          providerEventId,
        lastIgnoredProviderState:
          state,
        lastIgnoredProviderEventAt:
          event.occurredAt,
        updatedAt:
          FieldValue.serverTimestamp(),
      },
      {
        merge: true,
      },
    );

    writeAuditLogInTransaction(
      firestore,
      transaction,
      {
        action:
          "event_payment_provider_transition_ignored",
        performedBy:
          "system:event_payment_provider",
        targetUid:
          lifecycleContext.organizerUid,
        metadata: {
          operationId,
          eventId:
            lifecycleContext.eventId,
          previousState:
            previousState ?? null,
          incomingState: state,
        },
      },
    );

    return true;
  }

  transaction.set(
    intentReference,
    {
      state,
      providerState:
        state,
      providerPaymentId:
        event.providerPaymentId,
      lastProviderEventId:
        providerEventId,
      lastProviderEventAt:
        event.occurredAt,
      updatedAt:
        FieldValue.serverTimestamp(),
    },
    {
      merge: true,
    },
  );

  applyEventPaymentLifecycleProjection(
    transaction,
    lifecycleContext,
    event,
  );

  applyEventPayoutFinancialStateInTransaction(
    firestore,
    transaction,
    lifecycleContext.eventData,
    state,
  );

  transitionCommercialOperation(
    firestore,
    transaction,
    operationId,
    state,
    {
      actorUid:
        "system:event_payment_provider",
      source:
        "applyVerifiedPaymentWebhook",
    },
    {
      provider:
        event.provider,
      providerEventId,
      providerPaymentId:
        event.providerPaymentId,
      refundAmountMinor:
        event.refundAmountMinor ?? null,
      disputeReason:
        event.disputeReason ?? null,
    },
  );

  writePaymentLifecycleNotifications(
    firestore,
    transaction,
    lifecycleContext,
    state,
  );

  queueFinanceReviewIfRequired(
    firestore,
    transaction,
    lifecycleContext,
    operationId,
    providerEventReference.id,
    state,
    event,
  );

  writeAuditLogInTransaction(
    firestore,
    transaction,
    {
      action:
        "event_payment_provider_state_applied",
      performedBy:
        "system:event_payment_provider",
      targetUid:
        lifecycleContext.organizerUid,
      metadata: {
        operationId,
        eventId:
          lifecycleContext.eventId,
        previousState:
          previousState ?? null,
        state,
        currency:
          lifecycleContext.currency,
        grossAmountMinor:
          lifecycleContext.grossAmountMinor,
        refundAmountMinor:
          event.refundAmountMinor ?? null,
      },
    },
  );

  return true;
}

/**
 * Writes user-facing lifecycle notifications through the canonical
 * notification collection. FCM delivery is handled by the existing trigger.
 *
 * @param {Firestore} firestore Firestore.
 * @param {Transaction} transaction Transaction.
 * @param {PaymentLifecycleContext} context Lifecycle context.
 * @param {EventPaymentProviderState} state Applied provider state.
 * @return {void}
 */
function writePaymentLifecycleNotifications(
  firestore: Firestore,
  transaction: Transaction,
  context: PaymentLifecycleContext,
  state: EventPaymentProviderState,
): void {
  const content =
    paymentNotificationContent(state);

  if (content == null) {
    return;
  }

  const recipients = [
    ...new Set([
      context.organizerUid,
      ...context.selectedPlayerIds,
    ]),
  ];

  const eventTitle =
    normalizeOptionalString(
      context.eventData.baslik ??
      context.eventData.title,
    ) ?? undefined;

  for (const userId of recipients) {
    writeUserNotificationInTransaction(
      firestore,
      transaction,
      {
        userId,
        type: content.type,
        title: content.title,
        message: content.message,
        eventId: context.eventId,
        eventTitle,
        route: "event_detail",
        data: {
          eventId: context.eventId,
          paymentStatus: state,
        },
      },
    );
  }
}

/**
 * Returns notification text only for meaningful financial transitions.
 *
 * @param {EventPaymentProviderState} state Provider state.
 * @return {{type:string,title:string,message:string}|null} Content.
 */
function paymentNotificationContent(
  state: EventPaymentProviderState,
): {
  type: string;
  title: string;
  message: string;
} | null {
  switch (state) {
  case "paid":
    return {
      type: "event_payment_paid",
      title: "Etkinlik durumu güncelleniyor",
      message:
        "Özel etkinlik bilgileri açıldı.",
    };
  case "refund_pending":
    return {
      type: "event_payment_refund_pending",
      title: "Etkinlik durumu güncelleniyor",
      message:
        "Etkinlik durumu güncelleniyor.",
    };
  case "refunded":
    return {
      type: "event_payment_refunded",
      title: "Etkinlik durumu güncelleniyor",
      message:
        "Etkinlik durumu güncelleniyor.",
    };
  case "partially_refunded":
    return {
      type: "event_payment_partially_refunded",
      title: "Etkinlik durumu güncelleniyor",
      message:
        "Etkinlik durumu güncelleniyor.",
    };
  case "dispute_review":
    return {
      type: "event_payment_dispute_review",
      title: "Etkinlik durumu güncelleniyor",
      message:
        "Etkinlik durumu güncelleniyor.",
    };
  case "chargeback":
    return {
      type: "event_payment_chargeback",
      title: "Etkinlik durumu güncelleniyor",
      message:
        "Etkinlik durumu güncelleniyor.",
    };
  default:
    return null;
  }
}

/**
 * Creates one deterministic finance-review item for risky payment states.
 *
 * @param {Firestore} firestore Firestore.
 * @param {Transaction} transaction Transaction.
 * @param {PaymentLifecycleContext} context Lifecycle context.
 * @param {string} operationId Commercial operation id.
 * @param {string} providerEventDocumentId Provider event document id.
 * @param {EventPaymentProviderState} state Provider state.
 * @param {EventPaymentWebhookEvent} event Provider event.
 * @return {void}
 */
function queueFinanceReviewIfRequired(
  firestore: Firestore,
  transaction: Transaction,
  context: PaymentLifecycleContext,
  operationId: string,
  providerEventDocumentId: string,
  state: EventPaymentProviderState,
  event: EventPaymentWebhookEvent,
): void {
  if (
    state !== "refund_pending" &&
    state !== "partially_refunded" &&
    state !== "dispute_review" &&
    state !== "chargeback"
  ) {
    return;
  }

  const reference = firestore
    .collection("commercial_review_queue")
    .doc(`event_payment_${providerEventDocumentId}`);

  transaction.create(
    reference,
    {
      reviewType: "event_payment",
      reviewState: "pending",
      financialState: state,
      operationId,
      eventId: context.eventId,
      organizerUid: context.organizerUid,
      payerUid: context.payerUid,
      currency: context.currency,
      grossAmountMinor:
        context.grossAmountMinor,
      refundAmountMinor:
        event.refundAmountMinor ?? null,
      disputeReason:
        normalizeOptionalString(
          event.disputeReason,
        ),
      source: "event_payment_provider",
      createdAt:
        FieldValue.serverTimestamp(),
      updatedAt:
        FieldValue.serverTimestamp(),
    },
  );
}

/**
 * Allows forward lifecycle movement while ignoring stale provider events.
 *
 * @param {EventPaymentProviderState|undefined} previous Previous state.
 * @param {EventPaymentProviderState} next Incoming state.
 * @return {boolean} Whether projection may be applied.
 */
function isAllowedProviderTransition(
  previous: EventPaymentProviderState | undefined,
  next: EventPaymentProviderState,
): boolean {
  if (previous == null || previous === next) {
    return true;
  }

  const allowed: Record<
    EventPaymentProviderState,
    ReadonlySet<EventPaymentProviderState>
  > = {
    created: new Set([
      "pending",
      "processing",
      "authorized",
      "paid",
      "failed",
      "cancelled",
    ]),
    pending: new Set([
      "processing",
      "authorized",
      "paid",
      "failed",
      "cancelled",
    ]),
    processing: new Set([
      "authorized",
      "paid",
      "failed",
      "cancelled",
    ]),
    authorized: new Set([
      "paid",
      "failed",
      "cancelled",
    ]),
    paid: new Set([
      "refund_pending",
      "refunded",
      "partially_refunded",
      "dispute_review",
      "chargeback",
      "payout_pending",
      "paid_out",
    ]),
    failed: new Set(),
    cancelled: new Set(),
    refund_pending: new Set([
      "refunded",
      "partially_refunded",
      "dispute_review",
      "chargeback",
    ]),
    refunded: new Set(),
    partially_refunded: new Set([
      "refund_pending",
      "refunded",
      "dispute_review",
      "chargeback",
    ]),
    dispute_review: new Set([
      "paid",
      "refunded",
      "partially_refunded",
      "chargeback",
    ]),
    chargeback: new Set(),
    payout_pending: new Set([
      "paid_out",
      "dispute_review",
      "chargeback",
    ]),
    paid_out: new Set([
      "dispute_review",
      "chargeback",
    ]),
  };

  return allowed[previous].has(next);
}

/**
 * Reads a known stored provider state without trusting arbitrary strings.
 *
 * @param {unknown} value Stored state.
 * @return {EventPaymentProviderState|undefined} Known state.
 */
function normalizeExistingProviderState(
  value: unknown,
): EventPaymentProviderState | undefined {
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

/**
 * Removes obvious secrets/PII and non-scalar values from provider metadata.
 *
 * @param {Record<string, unknown>|undefined} metadata Raw metadata.
 * @return {Record<string, string|number|boolean|null>} Safe metadata.
 */
function sanitizeProviderMetadata(
  metadata: Record<string, unknown> | undefined,
): Record<string, string | number | boolean | null> {
  if (metadata == null) {
    return {};
  }

  const safe: Record<
    string,
    string | number | boolean | null
  > = {};
  const blockedKey =
    /(token|secret|signature|authorization|password|card|pan|cvv|email|phone)/i;

  for (const [rawKey, rawValue] of Object.entries(metadata)) {
    const key = rawKey.trim().slice(0, 80);

    if (!key || blockedKey.test(key)) {
      continue;
    }

    if (
      rawValue === null ||
      typeof rawValue === "boolean"
    ) {
      safe[key] = rawValue;
      continue;
    }

    if (
      typeof rawValue === "number" &&
      Number.isFinite(rawValue)
    ) {
      safe[key] = rawValue;
      continue;
    }

    if (typeof rawValue === "string") {
      safe[key] = rawValue.slice(0, 300);
    }
  }

  return safe;
}

/**
 * Binds a verified provider event to the originally created payment intent.
 *
 * @param {Record<string, unknown>} intentData Payment intent data.
 * @param {EventPaymentWebhookEvent} event Verified provider event.
 * @return {void}
 */
function assertProviderPaymentMatches(
  intentData: Record<string, unknown>,
  event: EventPaymentWebhookEvent,
): void {
  const expectedProvider =
    requireString(
      intentData.provider,
      "provider",
    );

  const expectedPaymentId =
    requireString(
      intentData.providerPaymentId,
      "providerPaymentId",
    );

  if (
    expectedProvider !== event.provider ||
    expectedPaymentId !==
      event.providerPaymentId
  ) {
    throw new Error(
      "Verified provider event does not match payment intent.",
    );
  }

  const expectedCurrency =
    normalizeOptionalUppercaseString(
      intentData.currency,
    );

  const eventCurrency =
    normalizeOptionalUppercaseString(
      event.currency,
    );

  if (
    eventCurrency &&
    expectedCurrency &&
    eventCurrency !== expectedCurrency
  ) {
    throw new Error(
      "Verified provider event currency does not match intent.",
    );
  }

  if (
    event.grossAmountMinor != null &&
    intentData.grossAmountMinor !==
      event.grossAmountMinor
  ) {
    throw new Error(
      "Verified provider event amount does not match intent.",
    );
  }
}

/**
 * Reads an optional normalized string.
 *
 * @param {unknown} value Raw value.
 * @return {string} String.
 */
function normalizeOptionalUppercaseString(
  value: unknown,
): string {
  return String(
    value ?? "",
  )
    .trim()
    .toUpperCase();
}

/**
 * Normalizes provider states to the commercial state machine.
 *
 * @param {EventPaymentProviderState} value Provider state.
 * @return {EventPaymentProviderState} State.
 */
export function normalizeProviderState(
  value: EventPaymentProviderState,
): EventPaymentProviderState {
  switch (value) {
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
    return value;

  default: {
    const exhaustive: never = value;
    throw new Error(
      `Unsupported provider state: ${exhaustive}`,
    );
  }
  }
}

/**
 * Builds a non-secret deterministic provider event document id.
 *
 * @param {string} provider Provider id.
 * @param {string} providerEventId Provider event id.
 * @return {string} Document id.
 */
function buildProviderEventDocumentId(
  provider: string,
  providerEventId: string,
): string {
  const normalizedProvider =
    requireString(
      provider,
      "provider",
    );
  const normalizedEventId =
    requireString(
      providerEventId,
      "providerEventId",
    );

  return `v1_${createHash("sha256")
    .update(
      `${normalizedProvider}\u0000${normalizedEventId}`,
      "utf8",
    )
    .digest("hex")}`;
}

/**
 * Validates money.
 *
 * @param {string} currency Currency.
 * @param {number} amountMinor Amount in minor unit.
 * @return {void}
 */
function validateMoney(
  currency: string,
  amountMinor: number,
): void {
  normalizeCurrency(currency);

  if (
    !Number.isSafeInteger(amountMinor) ||
    amountMinor <= 0
  ) {
    throw new Error(
      "Event payment amount must be a positive integer minor unit.",
    );
  }
}

/**
 * Normalizes optional money.
 *
 * @param {number|null|undefined} value Money.
 * @return {number|null} Money.
 */
function normalizeOptionalMoney(
  value:
    number |
    null |
    undefined,
): number | null {
  if (value == null) {
    return null;
  }

  if (
    !Number.isSafeInteger(value) ||
    value < 0
  ) {
    throw new Error(
      "Provider money value is invalid.",
    );
  }

  return value;
}

/**
 * Normalizes ISO-4217-like currency.
 *
 * @param {string} value Currency.
 * @return {string} Currency.
 */
function normalizeCurrency(
  value: string,
): string {
  const normalized =
    requireString(
      value,
      "currency",
    ).toUpperCase();

  if (!/^[A-Z]{3}$/.test(normalized)) {
    throw new Error(
      "Currency must contain three uppercase letters.",
    );
  }

  return normalized;
}

/**
 * Reads required string.
 *
 * @param {unknown} value Raw.
 * @param {string} field Field.
 * @return {string} String.
 */
function requireString(
  value: unknown,
  field: string,
): string {
  if (typeof value !== "string") {
    throw new Error(
      `${field} must be a string.`,
    );
  }

  const normalized =
    value.trim();

  if (!normalized) {
    throw new Error(
      `${field} is required.`,
    );
  }

  return normalized;
}

/**
 * Reads optional string.
 *
 * @param {unknown} value Raw.
 * @return {string|null} String.
 */
function normalizeOptionalString(
  value: unknown,
): string | null {
  const normalized =
    String(value ?? "").trim();

  return normalized ?
    normalized :
    null;
}
