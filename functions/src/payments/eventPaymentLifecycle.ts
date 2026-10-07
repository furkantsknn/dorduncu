import {
  FieldValue,
  Firestore,
  Transaction,
} from "firebase-admin/firestore";

import {
  APPLICATION_LIFECYCLE_VERSION,
  addressAccessStatus,
  applicationPaymentStatus,
  applicationStatus,
  reservationStatus,
} from "../events/eventLifecycle";
import {
  EventPaymentProviderState,
  EventPaymentWebhookEvent,
} from "./eventPaymentTypes";

export interface PaymentLifecycleContext {
  eventId: string;
  payerUid: string;
  organizerUid: string;
  currency: string;
  grossAmountMinor: number;
  selectedPlayerIds: string[];
  eventReference:
    FirebaseFirestore.DocumentReference;
  paymentSessionReference:
    FirebaseFirestore.DocumentReference;
  applicationReferences:
    FirebaseFirestore.DocumentReference[];
  eventData: Record<string, unknown>;
  paymentSessionData: Record<string, unknown>;
}

/**
 * Reads all documents required before a verified payment projection writes.
 *
 * @param {Firestore} firestore Firestore.
 * @param {Transaction} transaction Transaction.
 * @param {string} operationId Commercial operation id.
 * @return {Promise<PaymentLifecycleContext>} Projection context.
 */
export async function readEventPaymentLifecycleContext(
  firestore: Firestore,
  transaction: Transaction,
  operationId: string,
): Promise<PaymentLifecycleContext> {
  const intentReference = firestore
    .collection("event_payment_intents")
    .doc(operationId);
  const intentSnapshot =
    await transaction.get(intentReference);

  if (!intentSnapshot.exists) {
    throw new Error(
      "Event payment intent does not exist.",
    );
  }

  const intentData =
    intentSnapshot.data() ?? {};
  const eventId =
    requireString(
      intentData.eventId,
      "eventId",
    );
  const payerUid =
    requireString(
      intentData.payerUid,
      "payerUid",
    );
  const organizerUid =
    requireString(
      intentData.organizerUid,
      "organizerUid",
    );
  const currency =
    normalizeCurrency(
      intentData.currency,
    );
  const grossAmountMinor =
    requirePositiveMinorAmount(
      intentData.grossAmountMinor,
    );

  const eventReference = firestore
    .collection("events")
    .doc(eventId);
  const paymentSessionReference = firestore
    .collection("paymentSessions")
    .doc(eventId);

  const [
    eventSnapshot,
    paymentSessionSnapshot,
  ] = await Promise.all([
    transaction.get(eventReference),
    transaction.get(paymentSessionReference),
  ]);

  if (!eventSnapshot.exists) {
    throw new Error(
      "Event does not exist for payment projection.",
    );
  }

  if (!paymentSessionSnapshot.exists) {
    throw new Error(
      "Payment session does not exist for payment projection.",
    );
  }

  const eventData =
    eventSnapshot.data() ?? {};
  const paymentSessionData =
    paymentSessionSnapshot.data() ?? {};

  assertOperationBinding(
    eventData,
    paymentSessionData,
    operationId,
    organizerUid,
    payerUid,
  );

  const selectedPlayerIds =
    readStringList(
      eventData.selectedPlayerIds,
    );

  const applicationReferences =
    selectedPlayerIds.map(
      (playerUid) =>
        eventReference
          .collection("applications")
          .doc(playerUid),
    );

  if (applicationReferences.length > 0) {
    await Promise.all(
      applicationReferences.map(
        (reference) =>
          transaction.get(reference),
      ),
    );
  }

  return {
    eventId,
    payerUid,
    organizerUid,
    currency,
    grossAmountMinor,
    selectedPlayerIds,
    eventReference,
    paymentSessionReference,
    applicationReferences,
    eventData,
    paymentSessionData,
  };
}

/**
 * Applies one verified provider state to canonical event projections.
 *
 * @param {Transaction} transaction Transaction.
 * @param {PaymentLifecycleContext} context Projection context.
 * @param {EventPaymentWebhookEvent} event Verified provider event.
 * @return {void}
 */
export function applyEventPaymentLifecycleProjection(
  transaction: Transaction,
  context: PaymentLifecycleContext,
  event: EventPaymentWebhookEvent,
): void {
  validatePaidMoney(
    context,
    event,
  );

  const state = event.state;

  if (
    state === "payout_pending" ||
    state === "paid_out"
  ) {
    applyPayoutProjection(
      transaction,
      context,
      state,
    );
    return;
  }

  const projection =
    buildApplicationProjection(state);

  transaction.set(
    context.paymentSessionReference,
    {
      lifecycleVersion:
        APPLICATION_LIFECYCLE_VERSION,
      status:
        projection.sessionStatus,
      gatewayStatus: state,
      providerState: state,
      providerPaymentId:
        event.providerPaymentId,
      lastProviderEventId:
        event.providerEventId,
      lastProviderEventAt:
        event.occurredAt,
      settlementStatus:
        projection.settlementStatus,
      payoutStatus:
        projection.payoutStatus,
      updatedAt:
        FieldValue.serverTimestamp(),
    },
    {
      merge: true,
    },
  );

  transaction.set(
    context.eventReference,
    {
      lifecycleVersion:
        APPLICATION_LIFECYCLE_VERSION,
      durum:
        projection.eventDurum,
      status:
        projection.eventStatus,
      paymentStatus:
        projection.eventPaymentStatus,
      paymentRequired:
        projection.paymentRequired,
      settlementStatus:
        projection.settlementStatus,
      payoutStatus:
        projection.payoutStatus,
      updatedAt:
        FieldValue.serverTimestamp(),
      ...(state === "paid" ?
        {
          paidAt:
            FieldValue.serverTimestamp(),
        } :
        {}),
      ...(state === "refund_pending" ?
        {
          refundPendingAt:
            FieldValue.serverTimestamp(),
        } :
        {}),
      ...(state === "refunded" ?
        {
          refundedAt:
            FieldValue.serverTimestamp(),
        } :
        {}),
      ...(
        state === "dispute_review" ||
        state === "chargeback" ?
          {
            disputeReviewAt:
              FieldValue.serverTimestamp(),
          } :
          {}
      ),
    },
    {
      merge: true,
    },
  );

  for (
    const applicationReference of
    context.applicationReferences
  ) {
    transaction.set(
      applicationReference,
      {
        lifecycleVersion:
          APPLICATION_LIFECYCLE_VERSION,
        status:
          projection.applicationStatus,
        paymentStatus:
          projection.applicationPaymentStatus,
        addressAccessStatus:
          projection.addressAccessStatus,
        reservationStatus:
          projection.reservationStatus,
        updatedAt:
          FieldValue.serverTimestamp(),
        ...(state === "paid" ?
          {
            paidAt:
              FieldValue.serverTimestamp(),
            addressUnlockedAt:
              FieldValue.serverTimestamp(),
            reservationExpiresAt:
              FieldValue.delete(),
          } :
          {}),
        ...(
          state === "refund_pending" ?
            {
              refundPendingAt:
                FieldValue.serverTimestamp(),
            } :
            {}
        ),
        ...(state === "refunded" ?
          {
            refundedAt:
              FieldValue.serverTimestamp(),
          } :
          {}),
        ...(
          state === "dispute_review" ||
          state === "chargeback" ?
            {
              disputeReviewAt:
                FieldValue.serverTimestamp(),
            } :
            {}
        ),
      },
      {
        merge: true,
      },
    );
  }
}

interface ApplicationProjection {
  applicationStatus: string;
  applicationPaymentStatus: string;
  addressAccessStatus: string;
  reservationStatus: string;
  sessionStatus: string;
  eventDurum: string;
  eventStatus: string;
  eventPaymentStatus: string;
  paymentRequired: boolean;
  settlementStatus: string;
  payoutStatus: string;
}

/**
 * Maps provider financial states to application/event states.
 *
 * @param {EventPaymentProviderState} state Provider state.
 * @return {ApplicationProjection} Canonical projection.
 */
function buildApplicationProjection(
  state: EventPaymentProviderState,
): ApplicationProjection {
  switch (state) {
  case "created":
  case "pending":
  case "failed":
  case "cancelled":
    return {
      applicationStatus:
        applicationStatus.acceptedPaymentPending,
      applicationPaymentStatus:
        applicationPaymentStatus.pending,
      addressAccessStatus:
        addressAccessStatus.locked,
      reservationStatus:
        reservationStatus.held,
      sessionStatus: "payment_pending",
      eventDurum: "odeme_bekliyor",
      eventStatus: "payment_pending",
      eventPaymentStatus: "payment_pending",
      paymentRequired: true,
      settlementStatus: "not_paid",
      payoutStatus: "not_eligible",
    };

  case "processing":
  case "authorized":
    return {
      applicationStatus:
        applicationStatus.paymentProcessing,
      applicationPaymentStatus:
        applicationPaymentStatus.processing,
      addressAccessStatus:
        addressAccessStatus.locked,
      reservationStatus:
        reservationStatus.held,
      sessionStatus: "payment_processing",
      eventDurum: "odeme_isleniyor",
      eventStatus: "payment_processing",
      eventPaymentStatus: "payment_processing",
      paymentRequired: true,
      settlementStatus: "not_paid",
      payoutStatus: "not_eligible",
    };

  case "paid":
    return {
      applicationStatus:
        applicationStatus.addressUnlocked,
      applicationPaymentStatus:
        applicationPaymentStatus.paid,
      addressAccessStatus:
        addressAccessStatus.unlocked,
      reservationStatus:
        reservationStatus.held,
      sessionStatus: "paid",
      eventDurum: "odeme_tamamlandi",
      eventStatus: "payment_completed",
      eventPaymentStatus: "paid",
      paymentRequired: false,
      settlementStatus: "held",
      payoutStatus: "not_eligible",
    };

  case "refund_pending":
    return {
      applicationStatus:
        applicationStatus.refundPending,
      applicationPaymentStatus:
        applicationPaymentStatus.refundPending,
      addressAccessStatus:
        addressAccessStatus.locked,
      reservationStatus:
        reservationStatus.held,
      sessionStatus: "refund_pending",
      eventDurum: "iade_bekliyor",
      eventStatus: "refund_pending",
      eventPaymentStatus: "refund_pending",
      paymentRequired: false,
      settlementStatus: "refund_pending",
      payoutStatus: "blocked",
    };

  case "refunded":
  case "partially_refunded":
    return {
      applicationStatus:
        applicationStatus.refunded,
      applicationPaymentStatus:
        applicationPaymentStatus.refunded,
      addressAccessStatus:
        addressAccessStatus.locked,
      reservationStatus:
        reservationStatus.released,
      sessionStatus:
        state === "refunded" ?
          "refunded" :
          "partially_refunded",
      eventDurum:
        state === "refunded" ?
          "iade_tamamlandi" :
          "kismi_iade",
      eventStatus:
        state === "refunded" ?
          "refunded" :
          "partially_refunded",
      eventPaymentStatus:
        state === "refunded" ?
          "refunded" :
          "partially_refunded",
      paymentRequired: false,
      settlementStatus:
        state === "refunded" ?
          "refunded" :
          "partially_refunded",
      payoutStatus: "blocked",
    };

  case "dispute_review":
  case "chargeback":
    return {
      applicationStatus:
        applicationStatus.disputeReview,
      applicationPaymentStatus:
        state,
      addressAccessStatus:
        addressAccessStatus.locked,
      reservationStatus:
        reservationStatus.held,
      sessionStatus: state,
      eventDurum: "anlasmazlik_incelemede",
      eventStatus: "dispute_review",
      eventPaymentStatus: state,
      paymentRequired: false,
      settlementStatus: state,
      payoutStatus: "blocked",
    };

  case "payout_pending":
  case "paid_out":
    throw new Error(
      "Payout states use a separate projection.",
    );
  }
}

/**
 * Applies settlement-only payout states without changing participant access.
 *
 * @param {Transaction} transaction Transaction.
 * @param {PaymentLifecycleContext} context Projection context.
 * @param {EventPaymentProviderState} state Provider state.
 * @return {void}
 */
function applyPayoutProjection(
  transaction: Transaction,
  context: PaymentLifecycleContext,
  state: EventPaymentProviderState,
): void {
  const payoutStatus =
    state === "paid_out" ?
      "paid_out" :
      "payout_pending";

  transaction.set(
    context.paymentSessionReference,
    {
      payoutStatus,
      settlementStatus:
        payoutStatus,
      updatedAt:
        FieldValue.serverTimestamp(),
    },
    {
      merge: true,
    },
  );

  transaction.set(
    context.eventReference,
    {
      payoutStatus,
      settlementStatus:
        payoutStatus,
      updatedAt:
        FieldValue.serverTimestamp(),
    },
    {
      merge: true,
    },
  );
}

/**
 * Enforces exact paid amount/currency match.
 *
 * @param {PaymentLifecycleContext} context Projection context.
 * @param {EventPaymentWebhookEvent} event Verified provider event.
 * @return {void}
 */
function validatePaidMoney(
  context: PaymentLifecycleContext,
  event: EventPaymentWebhookEvent,
): void {
  if (event.state !== "paid") {
    return;
  }

  if (
    event.grossAmountMinor !==
    context.grossAmountMinor
  ) {
    throw new Error(
      "Verified paid amount does not match payment intent.",
    );
  }

  if (
    normalizeCurrency(event.currency) !==
    context.currency
  ) {
    throw new Error(
      "Verified paid currency does not match payment intent.",
    );
  }
}

/**
 * Verifies operation/event/session ownership binding.
 *
 * @param {Record<string, unknown>} eventData Event data.
 * @param {Record<string, unknown>} sessionData Payment session data.
 * @param {string} operationId Operation id.
 * @param {string} organizerUid Organizer uid.
 * @param {string} payerUid Payer uid.
 * @return {void}
 */
function assertOperationBinding(
  eventData: Record<string, unknown>,
  sessionData: Record<string, unknown>,
  operationId: string,
  organizerUid: string,
  payerUid: string,
): void {
  const eventOrganizerUid =
    String(
      eventData.olusturanUid ??
      eventData.creatorUid ??
      "",
    ).trim();

  if (
    eventOrganizerUid !== organizerUid ||
    payerUid !== organizerUid
  ) {
    throw new Error(
      "Payment intent ownership binding is invalid.",
    );
  }

  const eventOperationId =
    String(
      eventData.commercialOperationId ?? "",
    ).trim();
  const sessionOperationId =
    String(
      sessionData.commercialOperationId ?? "",
    ).trim();

  if (
    eventOperationId !== operationId ||
    sessionOperationId !== operationId
  ) {
    throw new Error(
      "Payment operation binding does not match event/session.",
    );
  }
}

/**
 * Reads required string.
 *
 * @param {unknown} value Raw value.
 * @param {string} field Field name.
 * @return {string} String.
 */
function requireString(
  value: unknown,
  field: string,
): string {
  const normalized =
    String(value ?? "").trim();

  if (!normalized) {
    throw new Error(
      `${field} is required.`,
    );
  }

  return normalized;
}

/**
 * Reads positive integer minor amount.
 *
 * @param {unknown} value Raw value.
 * @return {number} Positive safe integer.
 */
function requirePositiveMinorAmount(
  value: unknown,
): number {
  const amount =
    Number(value);

  if (
    !Number.isSafeInteger(amount) ||
    amount <= 0
  ) {
    throw new Error(
      "Payment intent amount is invalid.",
    );
  }

  return amount;
}

/**
 * Normalizes currency.
 *
 * @param {unknown} value Raw currency.
 * @return {string} Currency.
 */
function normalizeCurrency(
  value: unknown,
): string {
  const currency =
    String(value ?? "")
      .trim()
      .toUpperCase();

  if (!/^[A-Z]{3}$/.test(currency)) {
    throw new Error(
      "Payment currency is invalid.",
    );
  }

  return currency;
}

/**
 * Reads safe unique string list.
 *
 * @param {unknown} value Raw list.
 * @return {string[]} Unique list.
 */
function readStringList(
  value: unknown,
): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return [
    ...new Set(
      value
        .map(
          (item) =>
            String(item).trim(),
        )
        .filter(
          (item) =>
            item.length > 0,
        ),
    ),
  ];
}
