import {
  onCall,
} from "firebase-functions/v2/https";
import {
  FieldPath,
  FieldValue,
} from "firebase-admin/firestore";

import {firestore} from "../config/firebaseAdmin";
import {assertSuperAdmin} from "../security/adminAuthorization";

const pageSize = 100;

export const adminMigrateVerificationDecisionReasons =
  onCall(
    {
      region: "europe-west1",
      enforceAppCheck: true,
      timeoutSeconds: 540,
      memory: "256MiB",
    },
    async (request) => {
      assertSuperAdmin(request);

      const marker =
        firestore
          .collection("system_settings")
          .doc(
            "verificationDecisionReasonMigrationV1",
          );

      const markerSnapshot =
        await marker.get();

      if (
        markerSnapshot.data()?.completed ===
        true
      ) {
        return {
          success: true,
          alreadyCompleted: true,
        };
      }

      let lastDocumentId = "";
      let migrated = 0;
      let hasMore = true;

      while (hasMore) {
        let query =
          firestore
            .collection(
              "verification_requests",
            )
            .orderBy(
              FieldPath.documentId(),
            )
            .limit(pageSize);

        if (lastDocumentId) {
          query =
            query.startAfter(
              lastDocumentId,
            );
        }

        const snapshot =
          await query.get();

        if (snapshot.empty) {
          hasMore = false;
          continue;
        }

        for (const document of snapshot.docs) {
          const data = document.data();

          const legacyNote =
            data.adminNote
              ?.toString()
              .trim() ?? "";

          const currentReason =
            data.decisionReason
              ?.toString()
              .trim() ?? "";

          if (legacyNote || data.adminNote != null) {
            const update:
              Record<string, unknown> = {
                adminNote:
                  FieldValue.delete(),
                updatedAt:
                  FieldValue.serverTimestamp(),
              };

            if (
              !currentReason &&
              legacyNote
            ) {
              update.decisionReason =
                legacyNote;
            }

            await document.ref.update(update);
            migrated += 1;
          }
        }

        lastDocumentId =
          snapshot.docs[
            snapshot.docs.length - 1
          ].id;

        hasMore =
          snapshot.size === pageSize;
      }

      await marker.set(
        {
          completed: true,
          migrated,
          completedAt:
            FieldValue.serverTimestamp(),
        },
        {
          merge: true,
        },
      );

      return {
        success: true,
        migrated,
      };
    },
  );
