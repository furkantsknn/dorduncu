import {randomUUID} from "node:crypto";

import {FieldValue, Timestamp} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {writeAuditLogInTransaction} from "../audit/writeAuditLog";
import {firestore} from "../config/firebaseAdmin";
import {
  identityKeyFromData,
  ownerApprovedFromUser,
  planIdentityReservationRelease,
} from "./identityReservationPolicy";
import {
  deleteVerificationObjectVersions,
  verificationObjectPath,
  verificationObjectVersion,
} from "./verificationDocumentStorage";
import {
  runVerificationCleanupAttempt,
  scanVerificationCleanupPages,
  VerificationCleanupPlan,
  VerificationObjectVersion,
} from "./verificationCleanupPolicy";
import {
  FINAL_VERIFICATION_STATUSES,
  VERIFICATION_RETENTION_DAYS,
  verificationRetentionStart,
  verificationText,
} from "./verificationRetentionPolicy";

const BATCH_LIMIT = 100;
const DOCUMENT_FIELDS = [
  ["identityFrontPath", "identityFrontUrl"],
  ["identityBackPath", "identityBackUrl"],
  ["criminalRecordPath", "criminalRecordUrl"],
  ["selfiePath", "selfieUrl"],
] as const;

/**
 * Returns a Date for Firestore timestamps.
 * @param {unknown} value Timestamp-like value.
 * @return {Date|null} Parsed date.
 */
function asDate(value: unknown): Date | null {
  return value instanceof Timestamp ? value.toDate() : null;
}

/**
 * Returns normalized text.
 * @param {unknown} value Candidate value.
 * @return {string} Normalized text.
 */
function text(value: unknown): string {
  return verificationText(value);
}

/**
 * Returns the final-decision timestamp.
 * @param {FirebaseFirestore.DocumentData} data Request data.
 * @return {Date|null} Final timestamp.
 */
function finalAt(data: FirebaseFirestore.DocumentData): Date | null {
  return verificationRetentionStart(data);
}

/**
 * Returns the immutable submission identifier.
 * @param {FirebaseFirestore.DocumentData} data Request data.
 * @return {string} Submission identifier.
 */
function submissionId(data: FirebaseFirestore.DocumentData): string {
  return text(data.submissionId);
}

/**
 * Returns validated request object paths and their fields.
 * @param {FirebaseFirestore.DocumentData} data Request data.
 * @param {string} uid Request owner.
 * @param {Function} readVersion Storage metadata reader.
 * @return {Array<{field: string, path: string}>} Object paths.
 */
function documentPaths(
  data: FirebaseFirestore.DocumentData,
  uid: string,
): Array<{field: string; path: string}> {
  const paths: Array<{field: string; path: string}> = [];
  for (const [pathField, legacyField] of DOCUMENT_FIELDS) {
    const path = verificationObjectPath(
      data[pathField] ?? data[legacyField],
      uid,
    );
    if (path) {
      paths.push({field: pathField, path});
    }
  }
  return paths;
}

/**
 * Returns the generation stored for a matching object path.
 * @param {FirebaseFirestore.DocumentData} data Request data.
 * @param {string} field Document field.
 * @param {string} path Object path.
 * @return {string} Stored generation.
 */
function storedGeneration(
  data: FirebaseFirestore.DocumentData,
  field: string,
  path: string,
): string {
  const stored = data.verificationDocumentObjects;
  if (!stored || typeof stored !== "object") {
    return "";
  }
  const item = (stored as Record<string, unknown>)[field];
  if (!item || typeof item !== "object") {
    return "";
  }
  const values = item as Record<string, unknown>;
  return text(values.path) === path ? text(values.generation) : "";
}

/**
 * Resolves exact object generations for a request snapshot.
 * @param {FirebaseFirestore.DocumentData} data Request data.
 * @param {string} uid Request owner.
 * @param {Function} readVersion Storage metadata reader.
 * @return {Promise<VerificationObjectVersion[]>} Exact object versions.
 */
async function objectVersions(
  data: FirebaseFirestore.DocumentData,
  uid: string,
  readVersion: typeof verificationObjectVersion = verificationObjectVersion,
): Promise<VerificationObjectVersion[]> {
  const versions: VerificationObjectVersion[] = [];
  for (const object of documentPaths(data, uid)) {
    const generation = storedGeneration(data, object.field, object.path);
    if (generation) {
      versions.push({...object, generation});
      continue;
    }
    const version = await readVersion(object.path);
    versions.push({...version, field: object.field});
  }
  return versions;
}

/**
 * Uses the canonical verification cleanup inventory for account deletion.
 * Stored immutable generations ensure a replacement at the same path survives.
 * @param {FirebaseFirestore.DocumentData} data Verification request data.
 * @param {string} uid Owner UID.
 * @param {Function} readVersion Storage metadata reader.
 * @return {Promise<VerificationObjectVersion[]>} Exact stored versions.
 */
export async function verificationObjectVersionsForRequest(
  data: FirebaseFirestore.DocumentData,
  uid: string,
  readVersion: typeof verificationObjectVersion = verificationObjectVersion,
): Promise<VerificationObjectVersion[]> {
  return objectVersions(data, uid, readVersion);
}

/**
 * Restores an earlier immutable operation for a safe partial-delete retry.
 * @param {FirebaseFirestore.DocumentData} data Request data.
 * @param {string} expectedSubmission Expected submission ID.
 * @return {VerificationObjectVersion[]} Stored operation objects.
 */
function retryObjects(
  data: FirebaseFirestore.DocumentData,
  expectedSubmission: string,
): VerificationObjectVersion[] {
  const operation = data.documentDeletionOperation;
  if (!operation || typeof operation !== "object") return [];
  const values = operation as Record<string, unknown>;
  if (text(values.submissionId) !== expectedSubmission) return [];
  if (!Array.isArray(values.objects)) return [];

  const objects: VerificationObjectVersion[] = [];
  for (const candidate of values.objects) {
    if (!candidate || typeof candidate !== "object") return [];
    const object = candidate as Record<string, unknown>;
    const field = text(object.field);
    const path = text(object.path);
    const generation = text(object.generation);
    const missing = object.missing === true;
    if (!field || !path || (!generation && !missing)) return [];
    objects.push({field, path, generation, ...(missing ? {missing} : {})});
  }
  return objects;
}

/**
 * Checks that document fields still refer to the prepared objects.
 * @param {FirebaseFirestore.DocumentData} data Request data.
 * @param {VerificationObjectVersion[]} objects Prepared objects.
 * @param {string} uid Request owner.
 * @return {boolean} Whether every object still matches.
 */
function sameObjects(
  data: FirebaseFirestore.DocumentData,
  objects: VerificationObjectVersion[],
  uid: string,
): boolean {
  const current = new Map(
    documentPaths(data, uid).map((item) => [item.field, item.path]),
  );
  return objects.length === current.size && objects.every(
    (object) => current.get(object.field) === object.path,
  );
}

/**
 * Builds the document-field deletion update.
 * @return {Record<string, unknown>} Firestore update.
 */
function deletedDocumentFields(): Record<string, unknown> {
  const update: Record<string, unknown> = {
    verificationDocumentObjects: FieldValue.delete(),
  };
  for (const [pathField, legacyField] of DOCUMENT_FIELDS) {
    update[pathField] = FieldValue.delete();
    update[legacyField] = FieldValue.delete();
  }
  return update;
}

/**
 * Expires the same stale submission and releases only its reservation.
 * @param {FirebaseFirestore.DocumentReference} reference Request reference.
 * @param {string} observedSubmission Observed submission ID.
 * @param {Date} cutoff Retention cutoff.
 * @return {Promise<boolean>} Whether the request expired.
 */
async function expireAndReleaseReservation(
  reference: FirebaseFirestore.DocumentReference,
  observedSubmission: string,
  cutoff: Date,
): Promise<boolean> {
  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    if (!snapshot.exists) return false;
    const data = snapshot.data() ?? {};
    const status = text(data.status) || "pending";
    const submittedAt = asDate(data.submittedAt) ?? asDate(data.createdAt);
    if (
      (status !== "pending" && status !== "revision") ||
      submissionId(data) !== observedSubmission ||
      !submittedAt ||
      submittedAt > cutoff
    ) {
      return false;
    }

    const uid = text(data.uid) || reference.id;
    const userSnapshot = await transaction.get(
      firestore.collection("users").doc(uid),
    );
    const fingerprint = text(data.identityFingerprint);
    const identityReference = fingerprint ? firestore
      .collection("verification_identity_keys")
      .doc(fingerprint) : null;
    const identitySnapshot = identityReference ?
      await transaction.get(identityReference) : null;

    transaction.update(reference, {
      status: "expired",
      expiredAt: FieldValue.serverTimestamp(),
      retentionStartedAt: FieldValue.serverTimestamp(),
      decisionVersion: randomUUID(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    const plan = planIdentityReservationRelease({
      key: identityKeyFromData(
        identitySnapshot?.data(),
        identitySnapshot?.exists === true,
      ),
      request: {uid, status: "expired", submissionId: observedSubmission},
      ownerApproved: ownerApprovedFromUser(userSnapshot.data()),
    });
    if (plan.release && identityReference) {
      transaction.delete(identityReference);
      writeAuditLogInTransaction(firestore, transaction, {
        action: "verification_identity_reservation_released",
        performedBy: "system:verification_retention",
        targetUid: uid,
        metadata: {requestStatus: "expired", outcome: "released"},
      });
    }
    return true;
  });
}

/**
 * Atomically reserves cleanup for one immutable submission.
 * @param {FirebaseFirestore.DocumentReference} reference Request reference.
 * @param {FirebaseFirestore.DocumentData} observedData Observed request.
 * @param {Date} cutoff Retention cutoff.
 * @param {Function} readVersion Storage metadata reader.
 * @return {Promise<VerificationCleanupPlan|null>} Prepared operation.
 */
export async function prepareCleanup(
  reference: FirebaseFirestore.DocumentReference,
  observedData: FirebaseFirestore.DocumentData,
  cutoff: Date,
  readVersion: typeof verificationObjectVersion = verificationObjectVersion,
): Promise<VerificationCleanupPlan | null> {
  const uid = text(observedData.uid) || reference.id;
  const observedRetentionStart = finalAt(observedData);
  if (!observedRetentionStart) {
    logger.warn("verification_legacy_cleanup_ambiguous", {
      requestId: reference.id,
      reason: "missing_retention_start",
    });
    return null;
  }
  const observedPaths = documentPaths(observedData, uid);
  const hasRawDocumentReference = DOCUMENT_FIELDS.some(
    ([pathField, legacyField]) =>
      text(observedData[pathField] ?? observedData[legacyField]).length > 0,
  );
  if (hasRawDocumentReference && observedPaths.length === 0) {
    logger.warn("verification_legacy_cleanup_ambiguous", {
      requestId: reference.id,
      reason: "invalid_document_reference",
    });
    return null;
  }
  const observedSubmission = submissionId(observedData) ||
    `legacy:${reference.id}:${observedRetentionStart.getTime()}`;
  const retry = retryObjects(observedData, observedSubmission);
  const objects = retry.length > 0 ? retry :
    await objectVersions(observedData, uid, readVersion);
  const operationId = randomUUID();

  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    if (!snapshot.exists) return null;
    const data = snapshot.data() ?? {};
    const previousOperation = data.documentDeletionOperation;
    const previous = previousOperation &&
      typeof previousOperation === "object" ?
      previousOperation as Record<string, unknown> : {};
    const isRetry =
      text(previous.submissionId) === observedSubmission &&
      text(previous.operationId).length > 0;
    if (
      (submissionId(data) && submissionId(data) !== observedSubmission) ||
      !FINAL_VERIFICATION_STATUSES.has(text(data.status)) ||
      data.documentsDeletedAt ||
      (!isRetry && (!finalAt(data) ||
        finalAt(data)!.getTime() !== observedRetentionStart.getTime() ||
        finalAt(data)! > cutoff)) ||
      !sameObjects(data, objects, uid)
    ) {
      return null;
    }

    const reusableOperationId =
      text(previous.submissionId) === observedSubmission ?
        text(previous.operationId) : "";
    const selectedOperationId = reusableOperationId || operationId;
    const selectedDecisionVersion = text(data.decisionVersion) ||
      `legacy:${reference.id}:${observedRetentionStart.getTime()}`;
    transaction.update(reference, {
      ...(submissionId(data) ? {} : {submissionId: observedSubmission}),
      ...(text(data.decisionVersion) ? {} : {
        decisionVersion: selectedDecisionVersion,
      }),
      ...(asDate(data.retentionStartedAt) ? {} : {
        retentionStartedAt: Timestamp.fromDate(observedRetentionStart),
      }),
      legacyCleanupStatus: FieldValue.delete(),
      deletionStatus: "processing",
      documentDeletionOperation: {
        operationId: selectedOperationId,
        submissionId: observedSubmission,
        decisionVersion: selectedDecisionVersion,
        decisionStatus: text(data.status),
        retentionStartedAtMillis: observedRetentionStart.getTime(),
        objects,
        attemptedAt: FieldValue.serverTimestamp(),
      },
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {
      requestId: reference.id,
      submissionId: observedSubmission,
      operationId: selectedOperationId,
      decisionVersion: selectedDecisionVersion,
      decisionStatus: text(data.status),
      retentionStartedAtMillis: observedRetentionStart.getTime(),
      objects,
    };
  });
}

/**
 * Finalizes field deletion only if the prepared submission still matches.
 * @param {FirebaseFirestore.DocumentReference} reference Request reference.
 * @param {VerificationCleanupPlan} plan Prepared operation.
 * @return {Promise<boolean>} Whether completion committed.
 */
export async function completeCleanup(
  reference: FirebaseFirestore.DocumentReference,
  plan: VerificationCleanupPlan,
): Promise<boolean> {
  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    if (!snapshot.exists) return false;
    const data = snapshot.data() ?? {};
    const operation = data.documentDeletionOperation;
    const values = operation && typeof operation === "object" ?
      operation as Record<string, unknown> : {};
    const uid = text(data.uid) || reference.id;
    if (
      submissionId(data) !== plan.submissionId ||
      text(values.submissionId) !== plan.submissionId ||
      text(values.operationId) !== plan.operationId ||
      text(values.decisionVersion) !== plan.decisionVersion ||
      text(values.decisionStatus) !== plan.decisionStatus ||
      Number(values.retentionStartedAtMillis) !==
        plan.retentionStartedAtMillis ||
      text(data.decisionVersion) !== plan.decisionVersion ||
      text(data.status) !== plan.decisionStatus ||
      finalAt(data)?.getTime() !== plan.retentionStartedAtMillis ||
      !FINAL_VERIFICATION_STATUSES.has(text(data.status)) ||
      !sameObjects(data, plan.objects, uid)
    ) {
      return false;
    }

    transaction.update(reference, {
      ...deletedDocumentFields(),
      documentsDeletedAt: FieldValue.serverTimestamp(),
      deletionStatus: "retention_cleanup",
      documentRetentionPolicy: "final_decision_30_days",
      documentDeletionOperation: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(
      firestore.collection("verification_document_deletion_logs").doc(
        `${reference.id}_${plan.submissionId}`,
      ),
      {
        requestId: reference.id,
        userId: uid,
        submissionId: plan.submissionId,
        deletedCount: plan.objects.length,
        reason: "retention_cleanup",
        completedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    return true;
  });
}

/**
 * Marks a matching operation for a safe later retry.
 * @param {FirebaseFirestore.DocumentReference} reference Request reference.
 * @param {VerificationCleanupPlan} plan Prepared operation.
 * @return {Promise<void>} Completion promise.
 */
export async function markCleanupFailure(
  reference: FirebaseFirestore.DocumentReference,
  plan: VerificationCleanupPlan,
): Promise<void> {
  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const data = snapshot.data() ?? {};
    const operation = data.documentDeletionOperation;
    const values = operation && typeof operation === "object" ?
      operation as Record<string, unknown> : {};
    if (
      submissionId(data) === plan.submissionId &&
      text(values.operationId) === plan.operationId
    ) {
      const update: Record<string, unknown> = {
        deletionStatus: "retry_pending",
        updatedAt: FieldValue.serverTimestamp(),
      };
      update["documentDeletionOperation.failedAt"] =
        FieldValue.serverTimestamp();
      transaction.update(reference, update);
    }
  });
}

/**
 * Processes one request without blocking later records on failure.
 * @param {FirebaseFirestore.QueryDocumentSnapshot} document Request snapshot.
 * @param {Date} cutoff Retention cutoff.
 * @param {Function} deleteVersions Conditional Storage deleter.
 * @param {Function} readVersion Storage metadata reader.
 * @return {Promise<boolean>} Whether a state transition completed.
 */
export async function processDocument(
  document: FirebaseFirestore.QueryDocumentSnapshot,
  cutoff: Date,
  deleteVersions: typeof deleteVerificationObjectVersions =
  deleteVerificationObjectVersions,
  readVersion: typeof verificationObjectVersion = verificationObjectVersion,
): Promise<boolean> {
  const data = document.data();
  const status = text(data.status) || "pending";
  const submittedAt = asDate(data.submittedAt) ?? asDate(data.createdAt);
  if (
    (status === "pending" || status === "revision") &&
    submittedAt &&
    submittedAt <= cutoff
  ) {
    return expireAndReleaseReservation(
      document.ref,
      submissionId(data),
      cutoff,
    );
  }
  if (
    !FINAL_VERIFICATION_STATUSES.has(status) ||
    data.documentsDeletedAt ||
    (retryObjects(data, submissionId(data)).length === 0 &&
      (!finalAt(data) || finalAt(data)! > cutoff))
  ) {
    return false;
  }
  return runVerificationCleanupAttempt({
    prepare: () => prepareCleanup(document.ref, data, cutoff, readVersion),
    deleteObject: async (object) => {
      await deleteVersions([object]);
    },
    complete: (plan) => completeCleanup(document.ref, plan),
    failed: (plan) => markCleanupFailure(document.ref, plan),
  });
}

export const cleanupVerificationDocuments = onSchedule(
  {
    region: "europe-west1",
    schedule: "every day 03:30",
    timeZone: "Europe/Istanbul",
    timeoutSeconds: 540,
  },
  async () => {
    const cutoff = new Date(
      Date.now() - VERIFICATION_RETENTION_DAYS * 24 * 60 * 60 * 1000,
    );
    const result = await scanVerificationCleanupPages(
      async (cursor) => {
        let query = firestore.collection("verification_requests")
          .orderBy("__name__")
          .limit(BATCH_LIMIT);
        if (cursor) {
          query = query.startAfter(cursor);
        }
        const snapshot = await query.get();
        return {
          records: snapshot.docs,
          lastId: snapshot.empty ? null :
            snapshot.docs[snapshot.docs.length - 1].id,
        };
      },
      async (document) => {
        try {
          return await processDocument(document, cutoff);
        } catch (error) {
          logger.error("verification_retention_record_failed", {
            requestId: document.id,
            error,
          });
          throw error;
        }
      },
    );
    logger.info("verification_retention_cleanup_complete", {
      ...result,
      retentionDays: VERIFICATION_RETENTION_DAYS,
    });
  },
);
