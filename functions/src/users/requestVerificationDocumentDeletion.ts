import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  FieldValue,
} from "firebase-admin/firestore";

import {firestore} from "../config/firebaseAdmin";
import {
  deleteVerificationObjects,
  verificationObjectPath,
} from "./verificationDocumentStorage";

interface RequestVerificationDocumentDeletionData {
  requestId?: unknown;
}

const DOCUMENT_FIELDS = [
  ["identityFrontPath", "identityFrontUrl"],
  ["identityBackPath", "identityBackUrl"],
  ["criminalRecordPath", "criminalRecordUrl"],
  ["selfiePath", "selfieUrl"],
] as const;

/**
 * Collects owned verification object paths from request data.
 * @param {FirebaseFirestore.DocumentData} data Verification request data.
 * @param {string} uid Owner user id.
 * @return {string[]} Private object paths.
 */
function collectDocumentPaths(
  data: FirebaseFirestore.DocumentData,
  uid: string,
): string[] {
  const result: string[] = [];

  for (const [pathField, legacyField] of DOCUMENT_FIELDS) {
    const path = verificationObjectPath(
      data[pathField] ?? data[legacyField],
      uid,
    );

    if (path) {
      result.push(path);
    }
  }

  return result;
}

export const requestVerificationDocumentDeletion =
  onCall(
    {
      region: "europe-west1",
      enforceAppCheck: true,
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
          "unauthenticated",
          "Oturum açmanız gerekiyor.",
        );
      }

      const input =
        request.data as
          RequestVerificationDocumentDeletionData;

      const requestId =
        typeof input.requestId === "string" ?
          input.requestId.trim() :
          request.auth.uid;

      if (requestId !== request.auth.uid) {
        throw new HttpsError(
          "permission-denied",
          "Yalnızca kendi belgelerinizi silebilirsiniz.",
        );
      }

      const reference =
        firestore
          .collection("verification_requests")
          .doc(requestId);

      const snapshot = await reference.get();

      if (!snapshot.exists) {
        throw new HttpsError(
          "not-found",
          "Doğrulama başvurusu bulunamadı.",
        );
      }

      const data = snapshot.data() ?? {};
      const status =
        data.status?.toString().trim() ?? "pending";

      if (
        status === "pending" ||
        status === "revision"
      ) {
        throw new HttpsError(
          "failed-precondition",
          "İnceleme sürerken belgeler silinemez.",
        );
      }

      const paths = collectDocumentPaths(
        data,
        request.auth.uid,
      );

      await reference.update({
        deletionRequestedAt:
          FieldValue.serverTimestamp(),
        deletionStatus: "processing",
        updatedAt:
          FieldValue.serverTimestamp(),
      });

      const deletedCount =
        await deleteVerificationObjects(paths);

      const deleteFields:
        Record<string, unknown> = {
          deletionStatus: "completed",
          documentsDeletedAt:
            FieldValue.serverTimestamp(),
          documentRetentionPolicy:
            "final_decision_30_days",
          updatedAt:
            FieldValue.serverTimestamp(),
        };

      for (const [pathField, legacyField] of DOCUMENT_FIELDS) {
        deleteFields[pathField] =
          FieldValue.delete();
        deleteFields[legacyField] =
          FieldValue.delete();
      }

      await reference.update(deleteFields);

      await firestore
        .collection("verification_document_deletion_logs")
        .add({
          requestId,
          userId: request.auth.uid,
          deletedCount,
          requestedBy: request.auth.uid,
          completedAt:
            FieldValue.serverTimestamp(),
        });

      return {
        success: true,
        deletedCount,
      };
    },
  );
