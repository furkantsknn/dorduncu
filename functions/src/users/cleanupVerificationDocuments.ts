import {
  onSchedule,
} from "firebase-functions/v2/scheduler";
import {
  FieldValue,
  Timestamp,
} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

import {firestore} from "../config/firebaseAdmin";
import {
  deleteVerificationObjects,
  verificationObjectPath,
} from "./verificationDocumentStorage";

const RETENTION_DAYS = 30;
const BATCH_LIMIT = 100;

const DOCUMENT_FIELDS = [
  ["identityFrontPath", "identityFrontUrl"],
  ["identityBackPath", "identityBackUrl"],
  ["criminalRecordPath", "criminalRecordUrl"],
  ["selfiePath", "selfieUrl"],
] as const;

/**
 * Returns a Date from a Firestore timestamp-like value.
 * @param {unknown} value Timestamp-like value.
 * @return {Date|null} Parsed date or null.
 */
function asDate(value: unknown): Date | null {
  if (value instanceof Timestamp) {
    return value.toDate();
  }

  return null;
}

/**
 * Returns private document paths owned by the request user.
 * @param {FirebaseFirestore.DocumentData} data Request data.
 * @param {string} uid Owner user id.
 * @return {string[]} Private object paths.
 */
function documentPaths(
  data: FirebaseFirestore.DocumentData,
  uid: string,
): string[] {
  const paths: string[] = [];

  for (const [pathField, legacyField] of DOCUMENT_FIELDS) {
    const path = verificationObjectPath(
      data[pathField] ?? data[legacyField],
      uid,
    );

    if (path) {
      paths.push(path);
    }
  }

  return paths;
}

/**
 * Removes document-reference fields while preserving verification metadata.
 * @return {Record<string, unknown>} Firestore update payload.
 */
function deletedDocumentFields():
Record<string, unknown> {
  const update: Record<string, unknown> = {};

  for (const [pathField, legacyField] of DOCUMENT_FIELDS) {
    update[pathField] = FieldValue.delete();
    update[legacyField] = FieldValue.delete();
  }

  return update;
}

export const cleanupVerificationDocuments =
  onSchedule(
    {
      region: "europe-west1",
      schedule: "every day 03:30",
      timeZone: "Europe/Istanbul",
    },
    async () => {
      const cutoff =
        new Date(
          Date.now() -
          RETENTION_DAYS *
          24 *
          60 *
          60 *
          1000,
        );

      const snapshot =
        await firestore
          .collection("verification_requests")
          .limit(BATCH_LIMIT)
          .get();

      let expired = 0;
      let cleaned = 0;

      for (const document of snapshot.docs) {
        const data = document.data();
        const status =
          data.status?.toString().trim() ?? "pending";

        const submittedAt =
          asDate(data.submittedAt) ??
          asDate(data.createdAt);

        if (
          (status === "pending" ||
            status === "revision") &&
          submittedAt &&
          submittedAt <= cutoff
        ) {
          await document.ref.update({
            status: "expired",
            expiredAt:
              FieldValue.serverTimestamp(),
            updatedAt:
              FieldValue.serverTimestamp(),
          });
          expired += 1;
          continue;
        }

        if (
          status !== "approved" &&
          status !== "rejected" &&
          status !== "expired"
        ) {
          continue;
        }

        if (data.documentsDeletedAt) {
          continue;
        }

        const finalAt =
          asDate(data.processedAt) ??
          asDate(data.updatedAt) ??
          asDate(data.expiredAt);

        if (!finalAt || finalAt > cutoff) {
          continue;
        }

        const paths =
          documentPaths(data, document.id);

        await deleteVerificationObjects(paths);

        await document.ref.update({
          ...deletedDocumentFields(),
          documentsDeletedAt:
            FieldValue.serverTimestamp(),
          deletionStatus: "retention_cleanup",
          documentRetentionPolicy:
            "final_decision_30_days",
          updatedAt:
            FieldValue.serverTimestamp(),
        });

        await firestore
          .collection(
            "verification_document_deletion_logs",
          )
          .add({
            requestId: document.id,
            userId: document.id,
            deletedCount: paths.length,
            reason: "retention_cleanup",
            completedAt:
              FieldValue.serverTimestamp(),
          });

        cleaned += 1;
      }

      logger.info(
        "verification_retention_cleanup_complete",
        {
          expired,
          cleaned,
          retentionDays: RETENTION_DAYS,
        },
      );
    },
  );
