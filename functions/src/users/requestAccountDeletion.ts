/* eslint-disable valid-jsdoc, max-len */
import {createHash, randomUUID} from "crypto";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, Firestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {firestore} from "../config/firebaseAdmin";
import {writeAuditLog} from "../audit/writeAuditLog";

interface DeletionRequestResult {
  success: true;
  status: string;
  alreadyRequested: boolean;
}

export const requestAccountDeletion = onCall(
  {region: "europe-west1", enforceAppCheck: true},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Bu işlem için giriş yapmalısınız.");
    }
    const uid = request.auth.uid;
    const authUser = await getAuth().getUser(uid);
    const result = await requestAccountDeletionForUser({
      db: firestore,
      uid,
      accountInstanceId: authUser.metadata.creationTime,
      tokenPhone: request.auth.token.phone_number?.toString(),
    });
    if (!result.alreadyRequested) {
      await writeAuditLog({
        action: "requestAccountDeletion",
        performedBy: uid,
        targetUid: uid,
        metadata: {source: "mobile_app"},
      });
    }
    return result;
  },
);

/** Real callable transaction, exported for concurrent emulator tests. */
export async function requestAccountDeletionForUser(input: {
  db: Firestore;
  uid: string;
  accountInstanceId: string;
  tokenPhone?: string;
}): Promise<DeletionRequestResult> {
  const operationId = randomUUID();
  const userReference = input.db.collection("users").doc(input.uid);
  const requestReference = input.db.collection("accountDeletionRequests")
    .doc(input.uid);

  return input.db.runTransaction(async (transaction) => {
    const [userSnapshot, requestSnapshot] = await Promise.all([
      transaction.get(userReference),
      transaction.get(requestReference),
    ]);
    if (!userSnapshot.exists) {
      throw new HttpsError("not-found", "Kullanıcı profili bulunamadı.");
    }
    const userData = userSnapshot.data() ?? {};
    const existing = requestSnapshot.data() ?? {};
    const sameInstance = String(existing.accountInstanceId ?? "") ===
      input.accountInstanceId;
    const existingStatus = String(existing.status ?? "");
    if (sameInstance &&
      ["pending", "processing", "completed"].includes(existingStatus)) {
      return {success: true, status: existingStatus, alreadyRequested: true};
    }

    transaction.set(userReference, {
      accountStatus: "deletionRequested",
      deletionRequestedAt: FieldValue.serverTimestamp(),
      deletionRequestStatus: "pending",
      activeSessionId: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
      guncellemeTarihi: FieldValue.serverTimestamp(),
    }, {merge: true});

    const resetForNewInstance = !sameInstance;
    const deletionRequest = {
      uid: input.uid,
      accountInstanceId: input.accountInstanceId,
      operationId: resetForNewInstance ? operationId :
        String(existing.operationId || operationId),
      deletedUidHash: createHash("sha256").update(input.uid).digest("hex"),
      phoneNumber: input.tokenPhone ?? String(userData.telefon ?? ""),
      status: "pending",
      requestedAt: resetForNewInstance ? FieldValue.serverTimestamp() :
        existing.requestedAt ?? FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      source: "mobile_app",
      voluntaryDeletion: true,
      ...(resetForNewInstance ? {} : {
        completedAt: existing.completedAt ?? FieldValue.delete(),
        steps: existing.steps ?? {},
        stepCompletedAt: existing.stepCompletedAt ?? {},
        authDeletionStarted: existing.authDeletionStarted ??
          FieldValue.delete(),
        leaseId: FieldValue.delete(),
        leaseExpiresAt: FieldValue.delete(),
        nextRetryAt: FieldValue.delete(),
        failureReason: FieldValue.delete(),
      }),
      attemptCount: resetForNewInstance ? 0 : existing.attemptCount ?? 0,
    };
    // A replacement account gets a fresh document, which also removes legacy
    // literal dotted fields such as "steps.authDeleted" from older workers.
    if (resetForNewInstance) {
      transaction.set(requestReference, deletionRequest);
    } else {
      transaction.set(requestReference, deletionRequest, {merge: true});
    }
    return {success: true, status: "pending", alreadyRequested: false};
  });
}
