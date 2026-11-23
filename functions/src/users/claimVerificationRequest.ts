import {assertCurrentAdminSession} from "../security/adminAuthorization";
import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  FieldValue,
} from "firebase-admin/firestore";

import {firestore} from "../config/firebaseAdmin";
import {writeAuditLog} from "../audit/writeAuditLog";
import {
  assertAdminPermission,
  getAdminRole,
} from "../security/adminAuthorization";

interface ClaimVerificationRequest {
  requestId?: unknown;
}

export const claimVerificationRequest =
  onCall(
    {
      region: "europe-west1",
      enforceAppCheck: true,
    },
    async (request) => {
      assertAdminPermission(request, "verification.review");
      await assertCurrentAdminSession(request);

      const data =
        request.data as
          ClaimVerificationRequest;

      const requestId =
        typeof data.requestId ===
        "string" ?
          data.requestId.trim() :
          "";

      if (!requestId) {
        throw new HttpsError(
          "invalid-argument",
          "Başvuru kimliği gerekli.",
        );
      }

      const reference =
        firestore
          .collection(
            "verification_requests",
          )
          .doc(requestId);

      const result =
        await firestore.runTransaction(
          async (transaction) => {
            const snapshot =
              await transaction.get(
                reference,
              );

            if (!snapshot.exists) {
              throw new HttpsError(
                "not-found",
                "Doğrulama başvurusu bulunamadı.",
              );
            }

            const verificationData =
              snapshot.data() ?? {};

            const status =
              verificationData.status
                ?.toString()
                .trim() ?? "pending";

            if (
              status === "approved" ||
              status === "expired"
            ) {
              throw new HttpsError(
                "failed-precondition",
                "Bu başvuru artık incelemeye açık değil.",
              );
            }

            const previousVerifierUid =
              verificationData
                .assignedVerifierUid
                ?.toString()
                .trim() ?? "";

            const isSuperAdmin =
              getAdminRole(request) ===
                "super_admin";

            if (
              previousVerifierUid &&
              previousVerifierUid !==
                request.auth.uid &&
              !isSuperAdmin
            ) {
              throw new HttpsError(
                "permission-denied",
                "Bu başvuru başka bir admine atanmış.",
              );
            }

            transaction.update(
              reference,
              {
                assignedVerifierUid:
                  request.auth.uid,
                assignedVerifierAt:
                  FieldValue.serverTimestamp(),
                assignedVerifierBy:
                  request.auth.uid,
                updatedAt:
                  FieldValue.serverTimestamp(),
              },
            );

            return {
              previousVerifierUid,
              takeover:
                previousVerifierUid.length > 0 &&
                previousVerifierUid !==
                  request.auth.uid,
            };
          },
        );

      await writeAuditLog({
        action:
          "claimVerificationRequest",
        performedBy:
          request.auth.uid,
        metadata: {
          requestId,
          previousVerifierUid:
            result.previousVerifierUid,
          takeover:
            result.takeover,
          performedByRole:
            getAdminRole(request),
        },
      });

      return {
        success: true,
        requestId,
        assignedVerifierUid:
          request.auth.uid,
        takeover:
          result.takeover,
      };
    },
  );
