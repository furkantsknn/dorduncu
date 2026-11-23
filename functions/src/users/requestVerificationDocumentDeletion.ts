import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  FieldValue,
} from "firebase-admin/firestore";

import {firestore} from "../config/firebaseAdmin";
import {
  deleteVerificationObjectVersions,
} from "./verificationDocumentStorage";
import {
  completeCleanup,
  markCleanupFailure,
  prepareCleanup,
} from "./cleanupVerificationDocuments";
import {FINAL_VERIFICATION_STATUSES} from "./verificationRetentionPolicy";

interface RequestVerificationDocumentDeletionData {
  requestId?: unknown;
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

      if (!FINAL_VERIFICATION_STATUSES.has(status)) {
        throw new HttpsError(
          "failed-precondition",
          "İnceleme sürerken belgeler silinemez.",
        );
      }

      const plan = await prepareCleanup(
        reference,
        data,
        new Date(8640000000000000),
      );
      if (!plan) {
        throw new HttpsError(
          "aborted",
          "Belge durumu değişti; isteği güncel durumla yeniden deneyin.",
        );
      }
      await reference.update({
        deletionRequestedAt: FieldValue.serverTimestamp(),
      });
      try {
        await deleteVerificationObjectVersions(plan.objects);
      } catch (error) {
        await markCleanupFailure(reference, plan);
        throw error;
      }
      if (!await completeCleanup(reference, plan)) {
        throw new HttpsError(
          "aborted",
          "Belge durumu değişti; isteği güncel durumla yeniden deneyin.",
        );
      }
      const deletedCount = plan.objects.filter((item) => !item.missing).length;

      await firestore
        .collection("verification_document_deletion_logs")
        .doc(`${requestId}_${plan.submissionId}`)
        .set({
          requestId,
          userId: request.auth.uid,
          deletedCount,
          requestedBy: request.auth.uid,
          submissionId: plan.submissionId,
          operationId: plan.operationId,
          completedAt:
            FieldValue.serverTimestamp(),
        }, {merge: true});

      return {
        success: true,
        deletedCount,
      };
    },
  );
