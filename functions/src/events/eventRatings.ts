import {
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";
import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  writeUserNotification,
} from "../notifications/writeUserNotification";
import {writeAuditLog} from "../audit/writeAuditLog";

const REGION = "europe-west1";
const MIN_RATING = 1;
const MAX_RATING = 5;
const MAX_COMMENT_LENGTH = 500;

/**
 * Submits one mutual event rating.
 *
 * Roster members of a completed event can rate each other.
 * Repeated identical calls are idempotent.
 */
export const submitEventRating = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const reviewerUid = requireUid(request.auth?.uid);
    const eventId = readRequiredString(
      request.data,
      "eventId",
      "Etkinlik kimliği gereklidir.",
    );
    const targetUid = readRequiredString(
      request.data,
      "targetUid",
      "Değerlendirilecek kullanıcı gereklidir.",
    );
    const rating = readRating(request.data);
    const comment = readOptionalComment(request.data);

    if (reviewerUid === targetUid) {
      throw new HttpsError(
        "invalid-argument",
        "Kullanıcı kendisini değerlendiremez.",
      );
    }

    const firestore = getFirestore();
    const eventReference = firestore
      .collection("events")
      .doc(eventId);
    const targetUserReference = firestore
      .collection("users")
      .doc(targetUid);
    const ratingId = `${reviewerUid}_${targetUid}`;
    const ratingReference = eventReference
      .collection("ratings")
      .doc(ratingId);

    let alreadySubmitted = false;

    await firestore.runTransaction(async (transaction) => {
      const reviewerBlockedTarget = firestore
        .collection("users")
        .doc(reviewerUid)
        .collection("blockedUsers")
        .doc(targetUid);
      const targetBlockedReviewer = firestore
        .collection("users")
        .doc(targetUid)
        .collection("blockedUsers")
        .doc(reviewerUid);
      const [
        eventSnapshot,
        ratingSnapshot,
        targetUserSnapshot,
        reviewerBlockedTargetSnapshot,
        targetBlockedReviewerSnapshot,
      ] = await Promise.all([
        transaction.get(eventReference),
        transaction.get(ratingReference),
        transaction.get(targetUserReference),
        transaction.get(reviewerBlockedTarget),
        transaction.get(targetBlockedReviewer),
      ]);

      if (
        reviewerBlockedTargetSnapshot.exists ||
        targetBlockedReviewerSnapshot.exists
      ) {
        throw new HttpsError(
          "permission-denied",
          "Engellenmiş kullanıcılar birbirini değerlendiremez.",
        );
      }

      if (!eventSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "Etkinlik bulunamadı.",
        );
      }

      if (!targetUserSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "Değerlendirilecek kullanıcı bulunamadı.",
        );
      }

      const eventData = eventSnapshot.data() ?? {};

      if (!isCompletedEvent(eventData)) {
        throw new HttpsError(
          "failed-precondition",
          "Değerlendirme yalnızca tamamlanan etkinliklerde yapılabilir.",
        );
      }

      const organizerUid = String(
        eventData.olusturanUid ?? "",
      ).trim();

      if (!organizerUid) {
        throw new HttpsError(
          "failed-precondition",
          "Etkinlik sahibi bilgisi bulunamadı.",
        );
      }

      const participantUids = eventParticipantUids(eventData);

      if (
        !isAllowedRatingPair(
          reviewerUid,
          targetUid,
          organizerUid,
          participantUids,
        )
      ) {
        throw new HttpsError(
          "permission-denied",
          "Bu kullanıcıyı bu etkinlik için değerlendiremezsin.",
        );
      }

      if (ratingSnapshot.exists) {
        const previous = ratingSnapshot.data() ?? {};
        const previousRating = Number(previous.rating ?? 0);
        const previousComment = String(
          previous.comment ?? "",
        ).trim();

        if (
          previousRating === rating &&
          previousComment === comment
        ) {
          alreadySubmitted = true;
          return;
        }

        throw new HttpsError(
          "already-exists",
          "Bu kullanıcı için değerlendirmeni daha önce gönderdin.",
        );
      }

      const targetData = targetUserSnapshot.data() ?? {};
      const currentCount = safeNonNegativeInt(
        targetData.ratingCount,
      );
      const currentSum = readCurrentRatingSum(
        targetData,
        currentCount,
      );
      const nextCount = currentCount + 1;
      const nextSum = currentSum + rating;
      const nextAverage = nextSum / nextCount;

      transaction.create(
        ratingReference,
        {
          eventId,
          reviewerUid,
          targetUid,
          organizerUid,
          rating,
          comment,
          ratingVersion: 1,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
      );

      transaction.update(
        targetUserReference,
        {
          puan: nextAverage,
          rating: nextAverage,
          puanOrtalamasi: nextAverage,
          ratingCount: nextCount,
          ratingSum: nextSum,
          updatedAt: FieldValue.serverTimestamp(),
        },
      );
    });

    if (!alreadySubmitted) {
      await Promise.all([
        writeUserNotification(
          firestore,
          {
            userId: targetUid,
            actorId: reviewerUid,
            eventId,
            type: "event_rating_received",
            title: "Yeni değerlendirme",
            message:
              "Tamamlanan etkinlik için yeni bir değerlendirme aldın.",
            route: "event_detail",
            data: {
              eventId,
            },
          },
        ),
        writeAuditLog({
          action: "event_rating_submitted",
          performedBy: reviewerUid,
          metadata: {
            eventId,
            targetUid,
            rating,
            ratingVersion: 1,
          },
        }),
      ]);
    }

    return {
      success: true,
      alreadySubmitted,
      eventId,
      targetUid,
      rating,
    };
  },
);

/**
 * Returns rating eligibility and already-submitted state.
 */
export const getEventRatingState = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const reviewerUid = requireUid(request.auth?.uid);
    const eventId = readRequiredString(
      request.data,
      "eventId",
      "Etkinlik kimliği gereklidir.",
    );

    const firestore = getFirestore();
    const eventSnapshot = await firestore
      .collection("events")
      .doc(eventId)
      .get();

    if (!eventSnapshot.exists) {
      throw new HttpsError(
        "not-found",
        "Etkinlik bulunamadı.",
      );
    }

    const eventData = eventSnapshot.data() ?? {};

    if (!isCompletedEvent(eventData)) {
      return {
        eventId,
        completed: false,
        targets: [],
      };
    }

    const organizerUid = String(
      eventData.olusturanUid ?? "",
    ).trim();
    const rosterUids = eventRosterUids(eventData, organizerUid);
    const targetUids = rosterUids.includes(reviewerUid) ?
      rosterUids.filter((uid) => uid !== reviewerUid) :
      [];

    if (targetUids.length === 0) {
      return {
        eventId,
        completed: true,
        targets: [],
      };
    }

    const ratingSnapshots = await Promise.all(
      targetUids.map((targetUid) => {
        const ratingId = `${reviewerUid}_${targetUid}`;

        return firestore
          .collection("events")
          .doc(eventId)
          .collection("ratings")
          .doc(ratingId)
          .get();
      }),
    );

    return {
      eventId,
      completed: true,
      targets: targetUids.map((targetUid) => {
        for (const snapshot of ratingSnapshots) {
          const data = snapshot.data();

          if (
            data != null &&
            String(data.targetUid ?? "") === targetUid
          ) {
            return {
              targetUid,
              submitted: true,
              rating: Number(data.rating ?? 0),
              comment: String(data.comment ?? ""),
            };
          }
        }

        return {
          targetUid,
          submitted: false,
        };
      }),
    };
  },
);

/**
 * Requires an authenticated user id.
 *
 * @param {string|undefined} uid Optional auth uid.
 * @return {string} Authenticated uid.
 */
function requireUid(uid: string | undefined): string {
  const normalized = String(uid ?? "").trim();

  if (!normalized) {
    throw new HttpsError(
      "unauthenticated",
      "Bu işlem için kullanıcı girişi gereklidir.",
    );
  }

  return normalized;
}

/**
 * Reads a required string field.
 *
 * @param {unknown} data Callable payload.
 * @param {string} key Field name.
 * @param {string} errorMessage Validation message.
 * @return {string} Normalized string.
 */
function readRequiredString(
  data: unknown,
  key: string,
  errorMessage: string,
): string {
  if (
    data === null ||
    typeof data !== "object" ||
    Array.isArray(data)
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
 * Reads the numeric rating.
 *
 * @param {unknown} data Callable payload.
 * @return {number} Valid rating.
 */
function readRating(data: unknown): number {
  if (
    data === null ||
    typeof data !== "object" ||
    Array.isArray(data)
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Puan gereklidir.",
    );
  }

  const value = Number(
    (data as Record<string, unknown>).rating,
  );

  if (
    !Number.isInteger(value) ||
    value < MIN_RATING ||
    value > MAX_RATING
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Puan 1 ile 5 arasında tam sayı olmalıdır.",
    );
  }

  return value;
}

/**
 * Reads an optional comment.
 *
 * @param {unknown} data Callable payload.
 * @return {string} Normalized comment.
 */
function readOptionalComment(data: unknown): string {
  if (
    data === null ||
    typeof data !== "object" ||
    Array.isArray(data)
  ) {
    return "";
  }

  const comment = String(
    (data as Record<string, unknown>).comment ?? "",
  ).trim();

  if (comment.length > MAX_COMMENT_LENGTH) {
    throw new HttpsError(
      "invalid-argument",
      `Yorum en fazla ${MAX_COMMENT_LENGTH} karakter olabilir.`,
    );
  }

  return comment;
}

/**
 * Checks whether the event is completed.
 *
 * @param {FirebaseFirestore.DocumentData} data Event data.
 * @return {boolean} True for completed events.
 */
function isCompletedEvent(
  data: FirebaseFirestore.DocumentData,
): boolean {
  const status = String(
    data.status ?? data.durum ?? "",
  )
    .trim()
    .toLowerCase();

  return status === "completed" ||
    status === "tamamlandi" ||
    status === "tamamlandı";
}

/**
 * Reads participant ids without the organizer.
 *
 * @param {FirebaseFirestore.DocumentData} data Event data.
 * @return {string[]} Unique participant ids.
 */
function eventParticipantUids(
  data: FirebaseFirestore.DocumentData,
): string[] {
  return readStringList(data.selectedPlayerIds);
}

/**
 * Organizer plus accepted roster, without duplicates.
 *
 * @param {FirebaseFirestore.DocumentData} data Event data.
 * @param {string} organizerUid Organizer uid.
 * @return {string[]} Rating roster.
 */
function eventRosterUids(
  data: FirebaseFirestore.DocumentData,
  organizerUid: string,
): string[] {
  return [
    ...new Set([
      organizerUid,
      ...readStringList(data.selectedPlayerIds),
    ].filter((uid) => uid.length > 0)),
  ];
}

/**
 * Checks organizer-to-participant mutual rating eligibility.
 *
 * @param {string} reviewerUid Reviewer uid.
 * @param {string} targetUid Target uid.
 * @param {string} organizerUid Organizer uid.
 * @param {string[]} participantUids Participant ids.
 * @return {boolean} True when the rating pair is valid.
 */
function isAllowedRatingPair(
  reviewerUid: string,
  targetUid: string,
  organizerUid: string,
  participantUids: string[],
): boolean {
  if (reviewerUid === targetUid) {
    return false;
  }

  const roster = new Set<string>([
    organizerUid,
    ...participantUids,
  ]);

  return roster.has(reviewerUid) && roster.has(targetUid);
}

/**
 * Reads a safe non-negative integer.
 *
 * @param {unknown} value Raw number.
 * @return {number} Safe integer.
 */
function safeNonNegativeInt(value: unknown): number {
  const numberValue = Number(value ?? 0);

  if (
    !Number.isFinite(numberValue) ||
    numberValue < 0
  ) {
    return 0;
  }

  return Math.floor(numberValue);
}

/**
 * Reconstructs the current aggregate rating sum.
 *
 * @param {FirebaseFirestore.DocumentData} data User data.
 * @param {number} count Current rating count.
 * @return {number} Current rating sum.
 */
function readCurrentRatingSum(
  data: FirebaseFirestore.DocumentData,
  count: number,
): number {
  const explicitSum = Number(data.ratingSum ?? Number.NaN);

  if (
    Number.isFinite(explicitSum) &&
    explicitSum >= 0
  ) {
    return explicitSum;
  }

  const average = Number(
    data.puan ??
    data.rating ??
    data.puanOrtalamasi ??
    0,
  );

  if (
    !Number.isFinite(average) ||
    average < 0
  ) {
    return 0;
  }

  return average * count;
}

/**
 * Reads a safe string list.
 *
 * @param {unknown} value Raw value.
 * @return {string[]} String list.
 */
function readStringList(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((item) => String(item).trim())
    .filter((item) => item.length > 0);
}
