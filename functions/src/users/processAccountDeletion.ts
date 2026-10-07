/* eslint-disable require-jsdoc */
import {createHash} from "crypto";

import {getAuth} from "firebase-admin/auth";
import {
  FieldValue,
  Query,
  getFirestore,
} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {onDocumentCreated} from "firebase-functions/v2/firestore";

const REGION = "europe-west1";

export const processAccountDeletion = onDocumentCreated(
  {
    document: "accountDeletionRequests/{uid}",
    region: REGION,
  },
  async (event) => {
    const uid = String(event.params.uid ?? "").trim();
    const requestReference = event.data?.ref;

    if (!uid || !requestReference) {
      return;
    }

    const firestore = getFirestore();
    const auth = getAuth();
    const bucket = getStorage().bucket();

    const userReference =
      firestore.collection("users").doc(uid);

    const userSnapshot =
      await userReference.get();

    const userData = userSnapshot.data() ?? {};
    const requestData = event.data?.data() ?? {};

    const phoneNumber = String(
      requestData.phoneNumber ??
      userData.telefon ??
      "",
    ).trim();

    const phoneHash = phoneNumber ?
      sha256(phoneNumber) :
      "";

    const deletedUidHash = sha256(uid);

    await requestReference.set(
      {
        status: "processing",
        processingStartedAt:
          FieldValue.serverTimestamp(),
        updatedAt:
          FieldValue.serverTimestamp(),
      },
      {
        merge: true,
      },
    );

    try {
      if (phoneHash) {
        await firestore
          .collection("deletedAccountPhones")
          .doc(phoneHash)
          .set(
            {
              blockedFromRegistration: true,
              deletedUidHash,
              deletedAt:
                FieldValue.serverTimestamp(),
              updatedAt:
                FieldValue.serverTimestamp(),
            },
            {
              merge: true,
            },
          );
      }

      await Promise.all([
        deleteStoragePrefix(
          bucket,
          `profile_photos/${uid}/`,
        ),
        deleteStoragePrefix(
          bucket,
          `verification_documents/${uid}/`,
        ),
      ]);

      const identityKeySnapshot =
        await firestore
          .collection("verification_identity_keys")
          .where("uid", "==", uid)
          .get();

      if (!identityKeySnapshot.empty) {
        const batch = firestore.batch();

        for (const document of identityKeySnapshot.docs) {
          batch.set(
            document.ref,
            {
              uid: `deleted:${deletedUidHash}`,
              status: "blocked_after_deletion",
              deletedAt:
                FieldValue.serverTimestamp(),
              updatedAt:
                FieldValue.serverTimestamp(),
            },
            {
              merge: true,
            },
          );
        }

        await batch.commit();
      }

      await Promise.all([
        firestore
          .collection("public_profiles")
          .doc(uid)
          .delete(),
        firestore
          .collection("sessions")
          .doc(uid)
          .delete(),
        firestore
          .collection("verification_requests")
          .doc(uid)
          .delete(),
      ]);

      await anonymizeLoginHistory(
        firestore
          .collection("login_history")
          .where("uid", "==", uid),
        deletedUidHash,
      );

      await anonymizeAuditLogs(
        firestore
          .collection("audit_logs")
          .where("performedBy", "==", uid),
        "performedBy",
        deletedUidHash,
      );

      await anonymizeAuditLogs(
        firestore
          .collection("audit_logs")
          .where("targetUid", "==", uid),
        "targetUid",
        deletedUidHash,
      );

      if (userSnapshot.exists) {
        await firestore.recursiveDelete(userReference);
      }

      try {
        await auth.deleteUser(uid);
      } catch (error: unknown) {
        const code =
          typeof error === "object" &&
          error !== null &&
          "code" in error ?
            String(
              (error as {code?: unknown}).code ?? "",
            ) :
            "";

        if (code !== "auth/user-not-found") {
          throw error;
        }
      }

      await requestReference.set(
        {
          status: "completed",
          phoneNumber:
            FieldValue.delete(),
          phoneHash:
            phoneHash || FieldValue.delete(),
          deletedUidHash,
          completedAt:
            FieldValue.serverTimestamp(),
          updatedAt:
            FieldValue.serverTimestamp(),
        },
        {
          merge: true,
        },
      );
    } catch (error) {
      console.error(
        "Account deletion processing failed:",
        uid,
        error,
      );

      await requestReference.set(
        {
          status: "failed",
          failureReason:
            "account_deletion_processing_failed",
          failedAt:
            FieldValue.serverTimestamp(),
          updatedAt:
            FieldValue.serverTimestamp(),
        },
        {
          merge: true,
        },
      );

      throw error;
    }
  },
);

function sha256(value: string): string {
  return createHash("sha256")
    .update(value)
    .digest("hex");
}

async function deleteStoragePrefix(
  bucket: ReturnType<
    ReturnType<typeof getStorage>["bucket"]
  >,
  prefix: string,
): Promise<void> {
  try {
    await bucket.deleteFiles({
      prefix,
      force: true,
    });
  } catch (error) {
    console.error(
      "Storage prefix deletion failed:",
      prefix,
      error,
    );
    throw error;
  }
}

async function anonymizeLoginHistory(
  query: Query,
  deletedUidHash: string,
): Promise<void> {
  const snapshot = await query.get();

  if (snapshot.empty) {
    return;
  }

  const firestore = getFirestore();
  let batch = firestore.batch();
  let operationCount = 0;

  for (const document of snapshot.docs) {
    batch.update(
      document.ref,
      {
        uid: `deleted:${deletedUidHash}`,
        phoneNumber:
          FieldValue.delete(),
        sessionId:
          FieldValue.delete(),
        deviceId:
          FieldValue.delete(),
        anonymizedAt:
          FieldValue.serverTimestamp(),
      },
    );

    operationCount += 1;

    if (operationCount >= 400) {
      await batch.commit();
      batch = firestore.batch();
      operationCount = 0;
    }
  }

  if (operationCount > 0) {
    await batch.commit();
  }
}

async function anonymizeAuditLogs(
  query: Query,
  fieldName: "performedBy" | "targetUid",
  deletedUidHash: string,
): Promise<void> {
  const snapshot = await query.get();

  if (snapshot.empty) {
    return;
  }

  const firestore = getFirestore();
  let batch = firestore.batch();
  let operationCount = 0;

  for (const document of snapshot.docs) {
    batch.update(
      document.ref,
      {
        [fieldName]:
          `deleted:${deletedUidHash}`,
        anonymizedAt:
          FieldValue.serverTimestamp(),
      },
    );

    operationCount += 1;

    if (operationCount >= 400) {
      await batch.commit();
      batch = firestore.batch();
      operationCount = 0;
    }
  }

  if (operationCount > 0) {
    await batch.commit();
  }
}
