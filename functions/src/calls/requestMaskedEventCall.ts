import {HttpsError, onCall} from "firebase-functions/v2/https";
import {
  FieldValue,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import {writeAuditLog} from "../audit/writeAuditLog";
import {
  hasFreeMembershipAccess,
  isFreeAccessEvent,
} from "../events/eventLifecycle";

const REGION = "europe-west1";
const REQUEST_TTL_MINUTES = 5;
const MIN_REQUEST_INTERVAL_SECONDS = 30;
const MAX_REQUESTS_PER_HOUR = 10;

/**
 * Creates a provider-neutral masked-call request for one paid event.
 *
 * No phone number is ever returned to the client or stored in this request.
 * A future telephony-provider adapter may resolve both phone numbers only on
 * the server and bridge them through the configured 0850 number.
 */
export const requestMaskedEventCall = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const callerUid = request.auth?.uid;

    if (!callerUid) {
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
    const targetUid = readRequiredString(
      request.data,
      "targetUid",
      "Aranacak kullanıcı kimliği gereklidir.",
    );

    if (callerUid === targetUid) {
      throw new HttpsError(
        "invalid-argument",
        "Kullanıcı kendisini arayamaz.",
      );
    }

    const firestore = getFirestore();
    const eventReference = firestore.collection("events").doc(eventId);
    const paymentSessionReference = firestore
      .collection("paymentSessions")
      .doc(eventId);

    const [eventSnapshot, paymentSessionSnapshot] = await Promise.all([
      eventReference.get(),
      paymentSessionReference.get(),
    ]);

    if (!eventSnapshot.exists) {
      throw new HttpsError("not-found", "Etkinlik bulunamadı.");
    }

    const eventData = eventSnapshot.data() ?? {};
    const organizerUid = firstString(eventData, [
      "olusturanUid",
      "creatorUid",
      "ownerUid",
      "hostUid",
    ]);
    const selectedPlayerIds = readStringList(eventData.selectedPlayerIds);

    if (!organizerUid) {
      throw new HttpsError(
        "failed-precondition",
        "Etkinlik sahibi bilgisi eksik.",
      );
    }

    const selectedPlayerIdSet = new Set<string>(selectedPlayerIds);
    const callerIsOrganizer = callerUid === organizerUid;
    const targetIsOrganizer = targetUid === organizerUid;
    const organizerCallsSelected =
      callerIsOrganizer && selectedPlayerIdSet.has(targetUid);
    const selectedCallsOrganizer =
      targetIsOrganizer && selectedPlayerIdSet.has(callerUid);

    if (!organizerCallsSelected && !selectedCallsOrganizer) {
      throw new HttpsError(
        "permission-denied",
        "Maskeli arama yalnızca etkinlik sahibi ile " +
          "seçilen oyuncu arasında kullanılabilir.",
      );
    }

    assertEventAllowsMaskedCall(eventData);

    if (isFreeAccessEvent(eventData)) {
      const memberUid = callerIsOrganizer ? targetUid : callerUid;
      const applicationSnapshot = await eventReference
        .collection("applications")
        .doc(memberUid)
        .get();

      if (!hasFreeMembershipAccess(applicationSnapshot.data())) {
        throw new HttpsError(
          "permission-denied",
          "Maskeli arama yalnızca kadrodaki oyuncularla kullanılabilir.",
        );
      }
    } else if (!isPaidEvent(eventData, paymentSessionSnapshot.data() ?? {})) {
      throw new HttpsError(
        "failed-precondition",
        "Maskeli arama yalnızca ödeme tamamlandıktan sonra kullanılabilir.",
      );
    }

    const requestReference = firestore.collection("masked_call_requests").doc();
    const rateLimitReference = firestore
      .collection("masked_call_rate_limits")
      .doc(buildRateLimitId(eventId, callerUid, targetUid));
    const nowMillis = Date.now();
    const expiresAt = Timestamp.fromMillis(
      nowMillis + REQUEST_TTL_MINUTES * 60 * 1000,
    );

    await firestore.runTransaction(async (transaction) => {
      const rateLimitSnapshot = await transaction.get(rateLimitReference);
      const rateLimitData = rateLimitSnapshot.data() ?? {};
      const lastRequestedAtMillis = timestampMillis(
        rateLimitData.lastRequestedAt,
      );
      const currentWindowStartedAtMillis = timestampMillis(
        rateLimitData.windowStartedAt,
      );
      const withinCurrentWindow =
        currentWindowStartedAtMillis > 0 &&
        nowMillis - currentWindowStartedAtMillis < 60 * 60 * 1000;
      const requestCount = withinCurrentWindow ?
        normalizeNonNegativeInteger(rateLimitData.requestCount) :
        0;

      if (
        lastRequestedAtMillis > 0 &&
        nowMillis - lastRequestedAtMillis <
          MIN_REQUEST_INTERVAL_SECONDS * 1000
      ) {
        throw new HttpsError(
          "resource-exhausted",
          "Yeni bir arama talebi göndermeden önce kısa bir süre bekleyin.",
        );
      }

      if (requestCount >= MAX_REQUESTS_PER_HOUR) {
        throw new HttpsError(
          "resource-exhausted",
          "Saatlik maskeli arama talebi sınırına ulaşıldı.",
        );
      }

      transaction.set(requestReference, {
        eventId,
        callerUid,
        targetUid,
        organizerUid,
        status: "provider_not_configured",
        provider: null,
        providerCallId: null,
        maskedNumber: null,
        createdAt: FieldValue.serverTimestamp(),
        expiresAt,
        updatedAt: FieldValue.serverTimestamp(),
      });

      transaction.set(
        rateLimitReference,
        {
          eventId,
          callerUid,
          targetUid,
          lastRequestedAt: Timestamp.fromMillis(nowMillis),
          windowStartedAt: Timestamp.fromMillis(
            withinCurrentWindow ? currentWindowStartedAtMillis : nowMillis,
          ),
          requestCount: requestCount + 1,
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    });

    await writeAuditLog({
      action: "masked_event_call_requested",
      performedBy: callerUid,
      targetUid,
      metadata: {
        eventId,
        requestId: requestReference.id,
        providerConfigured: false,
      },
    });

    return {
      success: true,
      requestId: requestReference.id,
      available: false,
      status: "provider_not_configured",
      expiresAt: expiresAt.toMillis(),
    };
  },
);


/**
 * Rejects calls for events that are no longer active for participant contact.
 * @param {FirebaseFirestore.DocumentData} eventData Event document data.
 */
function assertEventAllowsMaskedCall(
  eventData: FirebaseFirestore.DocumentData,
): void {
  const status = String(
    eventData.durum ?? eventData.status ?? "",
  ).trim().toLowerCase();

  if (
    status === "cancelled" ||
    status === "iptal" ||
    status === "completed" ||
    status === "tamamlandi"
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Bu etkinlik için maskeli arama artık kullanılamaz.",
    );
  }
}

/**
 * Builds a server-only deterministic rate-limit document id.
 * @param {string} eventId Event id.
 * @param {string} callerUid Caller uid.
 * @param {string} targetUid Target uid.
 * @return {string} Deterministic rate-limit id.
 */
function buildRateLimitId(
  eventId: string,
  callerUid: string,
  targetUid: string,
): string {
  return `${eventId}_${callerUid}_${targetUid}`;
}

/**
 * Reads milliseconds from a Firestore timestamp-like value.
 * @param {unknown} value Timestamp-like value.
 * @return {number} Epoch milliseconds or zero.
 */
function timestampMillis(value: unknown): number {
  if (value instanceof Timestamp) {
    return value.toMillis();
  }

  return 0;
}

/**
 * Normalizes an unknown value to a non-negative integer.
 * @param {unknown} value Value to normalize.
 * @return {number} Non-negative integer.
 */
function normalizeNonNegativeInteger(value: unknown): number {
  const numeric = Number(value);

  if (!Number.isFinite(numeric) || numeric < 0) {
    return 0;
  }

  return Math.floor(numeric);
}

/**
 * Checks whether the event has canonical paid access.
 * @param {FirebaseFirestore.DocumentData} eventData Event document data.
 * @param {FirebaseFirestore.DocumentData} paymentSessionData
 * Payment session data.
 * @return {boolean} True when payment grants masked-call access.
 */
function isPaidEvent(
  eventData: FirebaseFirestore.DocumentData,
  paymentSessionData: FirebaseFirestore.DocumentData,
): boolean {
  const statuses = [
    eventData.paymentStatus,
    paymentSessionData.status,
    paymentSessionData.gatewayStatus,
    paymentSessionData.providerState,
  ].map((value) => String(value ?? "").trim().toLowerCase());

  return statuses.some((value) =>
    value === "paid" ||
    value === "completed" ||
    value === "success" ||
    value === "succeeded" ||
    value === "escrowheld" ||
    value === "escrow_held"
  );
}

/**
 * Reads a required callable string field.
 * @param {unknown} data Callable payload.
 * @param {string} field Field name.
 * @param {string} message Validation message.
 * @return {string} Normalized field value.
 */
function readRequiredString(
  data: unknown,
  field: string,
  message: string,
): string {
  if (!data || typeof data !== "object") {
    throw new HttpsError("invalid-argument", message);
  }

  const value = (data as Record<string, unknown>)[field];
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", message);
  }

  return value.trim();
}

/**
 * Reads the first non-empty string field.
 * @param {FirebaseFirestore.DocumentData} data Firestore document data.
 * @param {string[]} fields Candidate field names.
 * @return {string} First non-empty string or an empty string.
 */
function firstString(
  data: FirebaseFirestore.DocumentData,
  fields: string[],
): string {
  for (const field of fields) {
    const value = String(data[field] ?? "").trim();
    if (value) {
      return value;
    }
  }

  return "";
}

/**
 * Normalizes a string array from Firestore.
 * @param {unknown} value Firestore field value.
 * @return {string[]} Normalized non-empty string values.
 */
function readStringList(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((item) => String(item ?? "").trim())
    .filter((item) => item.length > 0);
}
