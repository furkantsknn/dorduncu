import {randomUUID} from "node:crypto";

import {FieldValue, Timestamp} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

export const VERIFICATION_RETENTION_DAYS = 30;
export const FINAL_VERIFICATION_STATUSES = new Set([
  "approved",
  "rejected",
  "expired",
]);

/**
 * Returns normalized text.
 * @param {unknown} value Candidate value.
 * @return {string} Normalized text.
 */
export function verificationText(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/**
 * Returns a Firestore timestamp as a date.
 * @param {unknown} value Candidate timestamp.
 * @return {Date|null} Parsed date.
 */
export function verificationDate(value: unknown): Date | null {
  return value instanceof Timestamp ? value.toDate() : null;
}

/**
 * Returns the immutable retention anchor, including legacy fallbacks.
 * @param {FirebaseFirestore.DocumentData} data Request data.
 * @return {Date|null} Retention anchor.
 */
export function verificationRetentionStart(
  data: FirebaseFirestore.DocumentData,
): Date | null {
  return verificationDate(data.retentionStartedAt) ??
    verificationDate(data.decidedAt) ??
    verificationDate(data.processedAt) ??
    verificationDate(data.expiredAt) ??
    verificationDate(data.updatedAt);
}

/**
 * Returns whether cleanup has irreversibly started for this submission.
 * @param {FirebaseFirestore.DocumentData} data Request data.
 * @param {string} submissionId Expected submission.
 * @return {boolean} Whether cleanup owns the submission.
 */
export function cleanupOwnsSubmission(
  data: FirebaseFirestore.DocumentData,
  submissionId: string,
): boolean {
  if (data.documentsDeletedAt) return true;
  const operation = data.documentDeletionOperation;
  if (!operation || typeof operation !== "object") return false;
  return verificationText(
    (operation as Record<string, unknown>).submissionId,
  ) === submissionId;
}

/**
 * Blocks a decision that could revive a submission whose files may be gone.
 * @param {FirebaseFirestore.DocumentData} data Request data.
 * @param {string} expectedSubmission Expected submission.
 * @return {void}
 */
export function assertDecisionWriteAllowed(
  data: FirebaseFirestore.DocumentData,
  expectedSubmission: string,
): void {
  const liveSubmission = verificationText(data.submissionId);
  if (liveSubmission !== expectedSubmission) {
    throw new HttpsError(
      "aborted",
      "Başvuru karar sırasında değişti; güncel başvuruyu yeniden açın.",
    );
  }
  if (cleanupOwnsSubmission(data, expectedSubmission)) {
    throw new HttpsError(
      "failed-precondition",
      // eslint-disable-next-line max-len
      "Bu başvurunun belge temizliği başladı; yeni belgelerle yeni başvuru gerekir.",
    );
  }
}

/**
 * Fields shared by every server-side verification decision writer.
 * @param {string} status New decision status.
 * @return {Record<string, unknown>} Shared decision fields.
 */
export function verificationDecisionRetentionFields(
  status: string,
): Record<string, unknown> {
  return {
    decisionVersion: randomUUID(),
    retentionStartedAt: FINAL_VERIFICATION_STATUSES.has(status) ?
      FieldValue.serverTimestamp() : FieldValue.delete(),
  };
}
