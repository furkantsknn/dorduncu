import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  FieldPath,
  FieldValue,
} from "firebase-admin/firestore";

import {firestore} from "../config/firebaseAdmin";
import {assertSuperAdmin} from "../security/adminAuthorization";
import {
  rotateDownloadToken,
  verificationObjectPath,
} from "./verificationDocumentStorage";

const pageSize = 100;

const fieldPairs = [
  ["identityFrontPath", "identityFrontUrl"],
  ["identityBackPath", "identityBackUrl"],
  ["criminalRecordPath", "criminalRecordUrl"],
  ["selfiePath", "selfieUrl"],
] as const;

export const adminMigrateVerificationDocumentPaths =
  onCall(
    {
      region: "europe-west1",
      enforceAppCheck: true,
      timeoutSeconds: 540,
      memory: "512MiB",
    },
    async (request) => {
      assertSuperAdmin(request);

      const marker =
        firestore
          .collection("system_settings")
          .doc(
            "verificationPrivatePathsMigrationV1",
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

        for (
          const document
          of snapshot.docs
        ) {
          const data =
            document.data();

          const uid =
            data.uid
              ?.toString()
              .trim() ?? document.id;

          const update:
            Record<string, unknown> = {};

          const pathsToRotate:
            string[] = [];

          for (
            const [pathField, urlField]
            of fieldPairs
          ) {
            const path =
              verificationObjectPath(
                data[pathField] ??
                  data[urlField],
                uid,
              );

            if (path) {
              update[pathField] = path;
              pathsToRotate.push(path);
            }

            if (
              Object.prototype
                .hasOwnProperty.call(
                  data,
                  urlField,
                )
            ) {
              update[urlField] =
                FieldValue.delete();
            }
          }

          if (
            Object.keys(update).length > 0
          ) {
            for (
              const path
              of pathsToRotate
            ) {
              try {
                await rotateDownloadToken(
                  path,
                );
              } catch (error) {
                console.error(
                  "Download token rotation failed.",
                  document.id,
                  path,
                  error,
                );

                throw new HttpsError(
                  "internal",
                  "Belge gizlilik dönüşümü " +
                    "tamamlanamadı.",
                );
              }
            }

            update.updatedAt =
              FieldValue.serverTimestamp();

            await document.ref.update(
              update,
            );

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

      await marker.set({
        completed: true,
        migrated,
        completedAt:
          FieldValue.serverTimestamp(),
        completedBy:
          request.auth?.uid ?? "",
      });

      return {
        success: true,
        migrated,
      };
    },
  );
