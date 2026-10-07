import {HttpsError, onCall} from "firebase-functions/v2/https";
import {
  FieldValue,
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";

import {
  applyProviderIntentResult,
  failEventPaymentIntent,
  reserveEventPaymentIntent,
} from "./eventPaymentOrchestrator";
import {
  getEventPaymentProvider,
} from "./eventPaymentProvider";

const REGION = "europe-west1";
const APPLICATION_LIFECYCLE_VERSION = 2;

/**
 * Starts the real-world event payment flow.
 *
 * The organizer remains the payer in the existing pricing model.
 * Client-side success can never mark an event paid.
 */
export const startPayment = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const uid = request.auth?.uid;

    if (!uid) {
      throw new HttpsError(
        "unauthenticated",
        "Bu işlem için kullanıcı girişi gereklidir.",
      );
    }

    const eventId = readRequiredString(
      request.data,
      "eventId",
      "Etkinlik kimliği gereklidir.",
    );

    const firestore = getFirestore();
    const eventReference =
      firestore.collection("events").doc(eventId);
    const paymentSessionReference = firestore
      .collection("paymentSessions")
      .doc(eventId);

    const settingsSnapshot = await firestore
      .collection("system_settings")
      .doc("global")
      .get();

    if (
      settingsSnapshot.exists &&
      settingsSnapshot.data()?.paymentsEnabled === false
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Ödeme sistemi şu anda geçici olarak kullanılamıyor.",
      );
    }

    const prepared = await firestore.runTransaction(
      async (transaction) => {
        const [
          eventSnapshot,
          paymentSessionSnapshot,
        ] = await Promise.all([
          transaction.get(eventReference),
          transaction.get(paymentSessionReference),
        ]);

        if (!eventSnapshot.exists) {
          throw new HttpsError(
            "not-found",
            "Etkinlik bulunamadı.",
          );
        }

        if (!paymentSessionSnapshot.exists) {
          throw new HttpsError(
            "failed-precondition",
            "Etkinlik ödeme oturumu henüz hazır değil.",
          );
        }

        const eventData =
          eventSnapshot.data() ?? {};
        const sessionData =
          paymentSessionSnapshot.data() ?? {};

        const organizerId = String(
          eventData.olusturanUid ??
          eventData.creatorUid ??
          "",
        ).trim();

        if (organizerId !== uid) {
          throw new HttpsError(
            "permission-denied",
            "Yalnızca etkinlik sahibi ödeme işlemini başlatabilir.",
          );
        }

        assertEventCanStartPayment(
          eventData,
          sessionData,
        );

        const amountMinor =
          readCustomerTotalMinor(
            eventData.customerTotal,
          );

        const currency =
          normalizeCurrency(
            sessionData.currency ?? "TRY",
          );

        const idempotencyKey =
          buildPaymentIdempotencyKey(
            eventId,
            uid,
            sessionData,
          );

        const reservation =
          await reserveEventPaymentIntent(
            firestore,
            transaction,
            {
              operationId: "",
              eventId,
              applicationId:
                `event:${eventId}`,
              payerUid: uid,
              organizerUid: uid,
              idempotencyKey,
              money: {
                currency,
                grossAmountMinor:
                  amountMinor,
              },
              metadata: {
                paymentSessionId:
                  eventId,
                lifecycleVersion:
                  String(
                    APPLICATION_LIFECYCLE_VERSION,
                  ),
              },
            },
          );

        transaction.set(
          paymentSessionReference,
          {
            lifecycleVersion:
              APPLICATION_LIFECYCLE_VERSION,
            commercialOperationId:
              reservation.operationId,
            gatewayStatus: "preparing",
            providerState: "created",
            paymentInitiatedBy: uid,
            paymentInitiatedAt:
              FieldValue.serverTimestamp(),
            updatedAt:
              FieldValue.serverTimestamp(),
          },
          {
            merge: true,
          },
        );

        transaction.set(
          eventReference,
          {
            lifecycleVersion:
              APPLICATION_LIFECYCLE_VERSION,
            commercialOperationId:
              reservation.operationId,
            paymentStatus:
              "payment_pending",
            paymentRequired: true,
            paymentInitiatedBy: uid,
            paymentInitiatedAt:
              FieldValue.serverTimestamp(),
            durum:
              "odeme_bekliyor",
            status:
              "payment_pending",
            updatedAt:
              FieldValue.serverTimestamp(),
          },
          {
            merge: true,
          },
        );

        return {
          operationId:
            reservation.operationId,
          created:
            reservation.created,
          amountMinor,
          currency,
          organizerId,
        };
      },
    );

    if (!prepared.created) {
      const existingIntent = await firestore
        .collection("event_payment_intents")
        .doc(prepared.operationId)
        .get();

      const existingData =
        existingIntent.data() ?? {};

      return {
        success: true,
        eventId,
        operationId:
          prepared.operationId,
        state:
          String(
            existingData.providerState ??
            existingData.state ??
            "pending",
          ),
        checkoutUrl:
          normalizeOptionalHttpsUrl(
            existingData.checkoutUrl,
          ),
        reused: true,
      };
    }

    let provider;

    try {
      provider =
        getEventPaymentProvider();
    } catch {
      await markProviderUnavailable(
        eventId,
        prepared.operationId,
      );

      throw new HttpsError(
        "failed-precondition",
        "Gerçek ödeme sağlayıcısı henüz aktif değil.",
      );
    }

    try {
      const providerResult =
        await provider.createPaymentIntent(
          {
            operationId:
              prepared.operationId,
            eventId,
            applicationId:
              `event:${eventId}`,
            payerUid: uid,
            organizerUid:
              prepared.organizerId,
            idempotencyKey:
              prepared.operationId,
            money: {
              currency:
                prepared.currency,
              grossAmountMinor:
                prepared.amountMinor,
            },
            metadata: {
              eventId,
              paymentSessionId:
                eventId,
            },
          },
        );

      await firestore.runTransaction(
        async (transaction) => {
          applyProviderIntentResult(
            firestore,
            transaction,
            prepared.operationId,
            providerResult,
          );

          transaction.set(
            paymentSessionReference,
            {
              commercialOperationId:
                prepared.operationId,
              gatewayStatus:
                providerResult.providerState,
              provider:
                providerResult.provider,
              providerPaymentId:
                providerResult.providerPaymentId,
              checkoutUrl:
                providerResult.checkoutUrl,
              providerExpiresAt:
                providerResult.expiresAt == null ?
                  null :
                  Timestamp.fromDate(
                    providerResult.expiresAt,
                  ),
              updatedAt:
                FieldValue.serverTimestamp(),
            },
            {
              merge: true,
            },
          );
        },
      );

      return {
        success: true,
        eventId,
        operationId:
          prepared.operationId,
        state:
          providerResult.providerState,
        checkoutUrl:
          normalizeOptionalHttpsUrl(
            providerResult.checkoutUrl,
          ),
        reused: false,
      };
    } catch (error) {
      const safeReason =
        normalizeProviderError(error);

      await firestore.runTransaction(
        async (transaction) => {
          failEventPaymentIntent(
            firestore,
            transaction,
            prepared.operationId,
            safeReason,
          );

          transaction.set(
            paymentSessionReference,
            {
              gatewayStatus: "failed",
              providerState: "failed",
              providerFailureReason:
                safeReason,
              updatedAt:
                FieldValue.serverTimestamp(),
            },
            {
              merge: true,
            },
          );
        },
      );

      throw new HttpsError(
        "unavailable",
        "Ödeme sağlayıcısına şu anda ulaşılamıyor.",
      );
    }
  },
);

/**
 * Marks provider-not-configured without creating a fake success.
 *
 * @param {string} eventId Event id.
 * @param {string} operationId Operation id.
 * @return {Promise<void>} Completion promise.
 */
async function markProviderUnavailable(
  eventId: string,
  operationId: string,
): Promise<void> {
  const firestore = getFirestore();

  await firestore.runTransaction(
    async (transaction) => {
      failEventPaymentIntent(
        firestore,
        transaction,
        operationId,
        "provider_not_configured",
      );

      transaction.set(
        firestore
          .collection("paymentSessions")
          .doc(eventId),
        {
          gatewayStatus: "not_configured",
          providerState: "failed",
          updatedAt:
            FieldValue.serverTimestamp(),
        },
        {
          merge: true,
        },
      );
    },
  );
}

/**
 * Validates canonical event and payment-session readiness.
 *
 * @param {Record<string, unknown>} eventData Event data.
 * @param {Record<string, unknown>} sessionData Session data.
 * @return {void}
 */
function assertEventCanStartPayment(
  eventData: Record<string, unknown>,
  sessionData: Record<string, unknown>,
): void {
  const paymentStatus =
    normalizeStatus(
      eventData.paymentStatus,
    );

  if (isPaidStatus(paymentStatus)) {
    throw new HttpsError(
      "failed-precondition",
      "Bu etkinliğin ödemesi zaten tamamlanmış.",
    );
  }

  const eventStatus =
    normalizeStatus(
      eventData.durum ??
      eventData.status,
    );

  if (
    eventStatus === "cancelled" ||
    eventStatus === "completed" ||
    eventStatus === "tamamlandi"
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Bu etkinlik için ödeme başlatılamaz.",
    );
  }

  const sessionStatus =
    normalizeStatus(
      sessionData.status,
    );

  if (
    sessionStatus === "expired" ||
    sessionStatus === "cancelled"
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Ödeme süresi dolmuş veya ödeme oturumu iptal edilmiş.",
    );
  }

  const participantIds =
    readStringList(
      sessionData.participantIds,
    );

  const requiredPlayerCount =
    readPositiveInteger(
      eventData.oyuncuSayisi ??
      eventData.playerCount,
      "oyuncuSayisi",
    );

  if (
    participantIds.length <
    requiredPlayerCount + 1
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Etkinlik kadrosu henüz tamamlanmadı.",
    );
  }

  const dueAt =
    readDate(
      sessionData.paymentDueAt ??
      eventData.paymentDueAt,
    );

  if (
    dueAt != null &&
    dueAt.getTime() <= Date.now()
  ) {
    throw new HttpsError(
      "deadline-exceeded",
      "Ödeme süresi dolmuş.",
    );
  }
}

/**
 * Builds one stable idempotency key per canonical payment session.
 *
 * @param {string} eventId Event id.
 * @param {string} uid Organizer uid.
 * @param {Record<string, unknown>} sessionData Session data.
 * @return {string} Stable idempotency key.
 */
function buildPaymentIdempotencyKey(
  eventId: string,
  uid: string,
  sessionData: Record<string, unknown>,
): string {
  const lifecycleVersion =
    Number(
      sessionData.lifecycleVersion ??
      APPLICATION_LIFECYCLE_VERSION,
    );

  return [
    "event_payment",
    eventId,
    uid,
    Number.isFinite(lifecycleVersion) ?
      String(lifecycleVersion) :
      String(
        APPLICATION_LIFECYCLE_VERSION,
      ),
  ].join(":");
}

/**
 * Reads trusted event total and converts units to integer kuruş.
 *
 * @param {unknown} value Event customerTotal.
 * @return {number} Amount in kuruş.
 */
function readCustomerTotalMinor(
  value: unknown,
): number {
  const amount =
    Number(value);

  if (
    !Number.isFinite(amount) ||
    amount <= 0
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Etkinlik ödeme tutarı geçersiz.",
    );
  }

  const amountMinor =
    Math.round(amount * 100);

  if (!Number.isSafeInteger(amountMinor)) {
    throw new HttpsError(
      "failed-precondition",
      "Etkinlik ödeme tutarı güvenli aralığın dışında.",
    );
  }

  return amountMinor;
}

/**
 * Reads a required string.
 *
 * @param {unknown} data Callable payload.
 * @param {string} key Field name.
 * @param {string} errorMessage Validation error.
 * @return {string} String.
 */
function readRequiredString(
  data: unknown,
  key: string,
  errorMessage: string,
): string {
  if (
    data === null ||
    typeof data !== "object"
  ) {
    throw new HttpsError(
      "invalid-argument",
      errorMessage,
    );
  }

  const value = String(
    (data as Record<string, unknown>)[key] ?? "",
  ).trim();

  if (!value) {
    throw new HttpsError(
      "invalid-argument",
      errorMessage,
    );
  }

  return value;
}

/**
 * Normalizes status.
 *
 * @param {unknown} value Raw value.
 * @return {string} Normalized status.
 */
function normalizeStatus(
  value: unknown,
): string {
  return String(
    value ?? "",
  )
    .trim()
    .toLowerCase();
}

/**
 * Checks final paid states.
 *
 * @param {string} value Payment status.
 * @return {boolean} True when paid.
 */
function isPaidStatus(
  value: string,
): boolean {
  return value === "paid" ||
    value === "completed" ||
    value === "success" ||
    value === "succeeded" ||
    value === "escrowheld" ||
    value === "escrow_held";
}

/**
 * Reads a positive integer.
 *
 * @param {unknown} value Raw.
 * @param {string} field Field.
 * @return {number} Integer.
 */
function readPositiveInteger(
  value: unknown,
  field: string,
): number {
  const parsed =
    Number(value);

  if (
    !Number.isSafeInteger(parsed) ||
    parsed <= 0
  ) {
    throw new HttpsError(
      "failed-precondition",
      `${field} geçersiz.`,
    );
  }

  return parsed;
}

/**
 * Reads an optional Firestore date.
 *
 * @param {unknown} value Raw date.
 * @return {Date|null} Date.
 */
function readDate(
  value: unknown,
): Date | null {
  if (value instanceof Timestamp) {
    return value.toDate();
  }

  if (
    value != null &&
    typeof value === "object" &&
    "toDate" in value &&
    typeof (
      value as {
        toDate?: unknown;
      }
    ).toDate === "function"
  ) {
    return (
      value as {
        toDate: () => Date;
      }
    ).toDate();
  }

  return null;
}

/**
 * Reads a string list.
 *
 * @param {unknown} value Raw list.
 * @return {string[]} Strings.
 */
function readStringList(
  value: unknown,
): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map(
      (item) =>
        String(item).trim(),
    )
    .filter(
      (item) =>
        item.length > 0,
    );
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
    String(
      value ?? "",
    )
      .trim()
      .toUpperCase();

  if (!/^[A-Z]{3}$/.test(currency)) {
    throw new HttpsError(
      "failed-precondition",
      "Ödeme para birimi geçersiz.",
    );
  }

  return currency;
}

/**
 * Returns only an HTTPS checkout URL.
 *
 * @param {unknown} value Raw URL.
 * @return {string|null} Safe URL.
 */
function normalizeOptionalHttpsUrl(
  value: unknown,
): string | null {
  const raw =
    String(value ?? "").trim();

  if (!raw) {
    return null;
  }

  try {
    const parsed =
      new URL(raw);

    return parsed.protocol === "https:" ?
      parsed.toString() :
      null;
  } catch {
    return null;
  }
}

/**
 * Converts an unknown provider exception to a safe reason.
 *
 * @param {unknown} error Provider error.
 * @return {string} Safe reason.
 */
function normalizeProviderError(
  error: unknown,
): string {
  if (error instanceof Error) {
    return error.message
      .trim()
      .slice(0, 300) ||
      "provider_error";
  }

  return "provider_error";
}
