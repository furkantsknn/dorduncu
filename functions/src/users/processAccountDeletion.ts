/* eslint-disable require-jsdoc, valid-jsdoc, max-len */
import {randomUUID} from "crypto";

import {getAuth} from "firebase-admin/auth";
import {
  DocumentReference,
  FieldValue,
  Firestore,
  Query,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {
  canClaimDeletionLease,
  deletionStepDone,
  sameAccountInstance,
} from "./accountDeletionPolicy";
import {
  verificationObjectVersionsForRequest,
} from "./cleanupVerificationDocuments";
import {
  deleteVerificationObjectVersions,
  verificationObjectVersion,
} from "./verificationDocumentStorage";

const REGION = "europe-west1";
const LEASE_MINUTES = 30;
const RETRY_MINUTES = 15;
type RequestData = Record<string, unknown>;

export interface AccountDeletionDependencies {
  db?: Firestore;
  authGetUser?: (uid: string) => Promise<{metadata: {creationTime: string}}>;
  authDeleteUser?: (uid: string) => Promise<void>;
  deleteProfilePhotos?: (uid: string) => Promise<void>;
  deleteSupportAttachments?: (uid: string) => Promise<void>;
  afterSupportBatchCommit?: (commitNumber: number) => Promise<void>;
  readVerificationVersion?: typeof verificationObjectVersion;
  deleteVerificationVersions?: typeof deleteVerificationObjectVersions;
  beforeStepCommit?: (name: string) => Promise<void>;
}

interface Ownership {
  uid: string;
  leaseId: string;
  operationId: string;
  accountInstanceId: string;
}

export const processAccountDeletion = onDocumentWritten(
  {document: "accountDeletionRequests/{uid}", region: REGION},
  async (event) => {
    const uid = String(event.params.uid ?? "").trim();
    const reference = event.data?.after.ref;
    if (uid && reference && event.data?.after.exists) {
      await processDeletionRequest(reference, uid);
    }
  },
);

export const retryAccountDeletions = onSchedule(
  {
    schedule: "every 15 minutes",
    region: REGION,
    timeZone: "Europe/Istanbul",
  },
  async () => {
    const db = getFirestore();
    const now = Timestamp.now();
    const snapshots = await Promise.all([
      db.collection("accountDeletionRequests")
        .where("status", "==", "pending").limit(25).get(),
      db.collection("accountDeletionRequests")
        .where("status", "==", "failed")
        .where("nextRetryAt", "<=", now).limit(25).get(),
      db.collection("accountDeletionRequests")
        .where("status", "==", "processing")
        .where("leaseExpiresAt", "<=", now).limit(25).get(),
    ]);
    const unique = new Map<string, DocumentReference>();
    for (const snapshot of snapshots) {
      for (const document of snapshot.docs) unique.set(document.id, document.ref);
    }
    await Promise.all([...unique.entries()].map(([uid, reference]) =>
      processDeletionRequest(reference, uid)));
  },
);

/** Production worker, exported so emulator tests execute the real path. */
export async function processDeletionRequest(
  requestReference: DocumentReference,
  uid: string,
  dependencies: AccountDeletionDependencies = {},
): Promise<void> {
  const db = dependencies.db ?? getFirestore();
  const leaseId = randomUUID();
  const ownership = await claimLease(db, requestReference, uid, leaseId);
  if (!ownership) return;

  try {
    await assertSameAccountInstance(requestReference, ownership, dependencies);
    await runStep(requestReference, ownership, "profilePhotosDeleted", async () => {
      if (dependencies.deleteProfilePhotos) {
        await dependencies.deleteProfilePhotos(uid);
      } else {
        await getStorage().bucket().deleteFiles({
          prefix: `profile_photos/${uid}/`, force: true,
        });
      }
    }, dependencies);
    await runStep(
      requestReference,
      ownership,
      "verificationDocumentsDeleted",
      async () => {
        const requestSnapshot = await db.collection("verification_requests")
          .doc(uid).get();
        if (!requestSnapshot.exists) return;
        const versions = await verificationObjectVersionsForRequest(
          requestSnapshot.data() ?? {},
          uid,
          dependencies.readVerificationVersion ?? verificationObjectVersion,
        );
        await (dependencies.deleteVerificationVersions ??
          deleteVerificationObjectVersions)(versions);
      },
      dependencies,
    );
    await runStep(requestReference, ownership, "supportAttachmentsDeleted", async () => {
      if (dependencies.deleteSupportAttachments) {
        await dependencies.deleteSupportAttachments(uid);
      } else {
        await getStorage().bucket().deleteFiles({
          prefix: `support_attachments/${uid}/`, force: true,
        });
      }
    }, dependencies);
    await runStep(requestReference, ownership, "identityAnonymized", async () => {
      const deletedUidHash = readRequiredHash(
        (await requestReference.get()).data(), "deletedUidHash");
      const snapshot = await db.collection("verification_identity_keys")
        .where("uid", "==", uid).get();
      if (snapshot.empty) return;
      const batch = db.batch();
      for (const document of snapshot.docs) {
        batch.set(document.ref, {
          uid: `deleted:${deletedUidHash}`,
          status: "review_required_after_voluntary_deletion",
          deletedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      await batch.commit();
    }, dependencies);
    await runStep(requestReference, ownership, "directDataDeleted", async () => {
      await Promise.all([
        db.collection("admin_user_metadata").doc(uid).delete(),
        db.collection("public_profiles").doc(uid).delete(),
        db.collection("sessions").doc(uid).delete(),
        db.collection("verification_requests").doc(uid).delete(),
      ]);
    }, dependencies);
    await runStep(requestReference, ownership, "historyAnonymized", async () => {
      const deletedUidHash = readRequiredHash(
        (await requestReference.get()).data(), "deletedUidHash");
      await anonymizeLoginHistory(
        db.collection("login_history").where("uid", "==", uid),
        deletedUidHash, db,
      );
      await anonymizeAuditLogs(
        db.collection("audit_logs").where("performedBy", "==", uid),
        "performedBy", deletedUidHash, db,
      );
      await anonymizeAuditLogs(
        db.collection("audit_logs").where("targetUid", "==", uid),
        "targetUid", deletedUidHash, db,
      );
    }, dependencies);
    await runStep(requestReference, ownership, "supportDataPseudonymized", async () => {
      const deletedUidHash = readRequiredHash(
        (await requestReference.get()).data(), "deletedUidHash");
      await pseudonymizeSupportData(
        db,
        uid,
        deletedUidHash,
        ownership.operationId,
        dependencies.afterSupportBatchCommit,
      );
    }, dependencies);
    await runStep(requestReference, ownership, "profileDeleted", async () => {
      await db.recursiveDelete(db.collection("users").doc(uid));
    }, dependencies);

    await markAuthDeletionStarted(requestReference, ownership);
    await runStep(requestReference, ownership, "authDeleted", async () => {
      try {
        if (dependencies.authDeleteUser) {
          await dependencies.authDeleteUser(uid);
        } else {
          await getAuth().deleteUser(uid);
        }
      } catch (error: unknown) {
        if (readErrorCode(error) !== "auth/user-not-found") throw error;
      }
    }, dependencies);
    await completeRequest(requestReference, ownership);
  } catch (error) {
    console.error("Account deletion processing failed:", uid, error);
    await failRequest(requestReference, ownership, error);
  }
}

async function claimLease(
  db: Firestore,
  reference: DocumentReference,
  uid: string,
  leaseId: string,
): Promise<Ownership | null> {
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    if (!snapshot.exists) return null;
    const data = snapshot.data() ?? {};
    if (!canClaimDeletionLease(data, Date.now())) return null;
    const operationId = String(data.operationId ?? "");
    const accountInstanceId = String(data.accountInstanceId ?? "");
    if (!operationId || !accountInstanceId || String(data.uid ?? uid) !== uid) {
      return null;
    }
    transaction.set(reference, {
      status: "processing",
      leaseId,
      leaseExpiresAt: Timestamp.fromMillis(
        Date.now() + LEASE_MINUTES * 60 * 1000),
      processingStartedAt: FieldValue.serverTimestamp(),
      attemptCount: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return {uid, leaseId, operationId, accountInstanceId};
  });
}

function owns(data: RequestData, owner: Ownership): boolean {
  const leaseExpiresAt = data.leaseExpiresAt;
  return String(data.uid ?? "") === owner.uid &&
    String(data.leaseId ?? "") === owner.leaseId &&
    String(data.operationId ?? "") === owner.operationId &&
    String(data.accountInstanceId ?? "") === owner.accountInstanceId &&
    leaseExpiresAt instanceof Timestamp &&
    leaseExpiresAt.toMillis() > Date.now();
}

async function assertOwned(
  reference: DocumentReference,
  owner: Ownership,
): Promise<RequestData> {
  const data = (await reference.get()).data() ?? {};
  if (!owns(data, owner)) throw codedError("deletion-lease-lost");
  return data;
}

async function assertSameAccountInstance(
  reference: DocumentReference,
  owner: Ownership,
  dependencies: AccountDeletionDependencies,
): Promise<void> {
  const data = await assertOwned(reference, owner);
  try {
    const user = dependencies.authGetUser ?
      await dependencies.authGetUser(owner.uid) :
      await getAuth().getUser(owner.uid);
    if (!sameAccountInstance(owner.accountInstanceId, user.metadata.creationTime)) {
      throw codedError("account-instance-mismatch");
    }
  } catch (error: unknown) {
    const started = data.authDeletionStarted;
    const values = started && typeof started === "object" ?
      started as RequestData : {};
    const recoverable = readErrorCode(error) === "auth/user-not-found" &&
      String(values.operationId ?? "") === owner.operationId &&
      String(values.accountInstanceId ?? "") === owner.accountInstanceId;
    if (!recoverable) throw error;
  }
}

async function runStep(
  reference: DocumentReference,
  owner: Ownership,
  name: string,
  action: () => Promise<void>,
  dependencies: AccountDeletionDependencies,
): Promise<void> {
  const before = await assertOwned(reference, owner);
  if (deletionStepDone(before.steps, name)) return;
  await assertSameAccountInstance(reference, owner, dependencies);
  await action();
  if (dependencies.beforeStepCommit) await dependencies.beforeStepCommit(name);
  const committed = await reference.firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const data = snapshot.data() ?? {};
    if (!owns(data, owner)) return false;
    const steps = map(data.steps);
    const completedAt = map(data.stepCompletedAt);
    transaction.set(reference, {
      steps: {...steps, [name]: true},
      stepCompletedAt: {...completedAt, [name]: FieldValue.serverTimestamp()},
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return true;
  });
  if (!committed) throw codedError("deletion-lease-lost");
}

async function markAuthDeletionStarted(
  reference: DocumentReference,
  owner: Ownership,
): Promise<void> {
  const committed = await reference.firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const data = snapshot.data() ?? {};
    if (!owns(data, owner)) return false;
    transaction.set(reference, {authDeletionStarted: {
      operationId: owner.operationId,
      accountInstanceId: owner.accountInstanceId,
      startedAt: FieldValue.serverTimestamp(),
    }}, {merge: true});
    return true;
  });
  if (!committed) throw codedError("deletion-lease-lost");
}

async function completeRequest(
  reference: DocumentReference,
  owner: Ownership,
): Promise<void> {
  const committed = await reference.firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const data = snapshot.data() ?? {};
    if (!owns(data, owner) || !deletionStepDone(data.steps, "authDeleted")) {
      return false;
    }
    transaction.set(reference, {
      status: "completed",
      phoneNumber: FieldValue.delete(),
      leaseId: FieldValue.delete(),
      leaseExpiresAt: FieldValue.delete(),
      failureReason: FieldValue.delete(),
      nextRetryAt: FieldValue.delete(),
      completedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return true;
  });
  if (!committed) throw codedError("deletion-lease-lost");
}

async function failRequest(
  reference: DocumentReference,
  owner: Ownership,
  error: unknown,
): Promise<void> {
  await reference.firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const data = snapshot.data() ?? {};
    if (!owns(data, owner)) return;
    const mismatch = readErrorCode(error) === "account-instance-mismatch";
    transaction.set(reference, {
      status: mismatch ? "superseded" : "failed",
      failureReason: readErrorCode(error) || "account_deletion_processing_failed",
      leaseId: FieldValue.delete(),
      leaseExpiresAt: FieldValue.delete(),
      failedAt: FieldValue.serverTimestamp(),
      nextRetryAt: mismatch ? FieldValue.delete() : Timestamp.fromMillis(
        Date.now() + RETRY_MINUTES * 60 * 1000),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  });
}

function map(value: unknown): RequestData {
  return value !== null && typeof value === "object" ?
    {...value as RequestData} : {};
}

function readRequiredHash(data: RequestData | undefined, key: string): string {
  const value = String(data?.[key] ?? "");
  if (!value) throw codedError(`missing-${key}`);
  return value;
}

function codedError(code: string): Error {
  const error = new Error(code) as Error & {code: string};
  error.code = code;
  return error;
}

function readErrorCode(error: unknown): string {
  return typeof error === "object" && error !== null && "code" in error ?
    String((error as {code?: unknown}).code ?? "") : "";
}

async function anonymizeLoginHistory(
  query: Query,
  deletedUidHash: string,
  db: Firestore,
): Promise<void> {
  await updateQueryInBatches(query, () => ({
    uid: `deleted:${deletedUidHash}`,
    phoneNumber: FieldValue.delete(),
    sessionId: FieldValue.delete(),
    deviceId: FieldValue.delete(),
    anonymizedAt: FieldValue.serverTimestamp(),
  }), db);
}

async function anonymizeAuditLogs(
  query: Query,
  fieldName: "performedBy" | "targetUid",
  deletedUidHash: string,
  db: Firestore,
): Promise<void> {
  await updateQueryInBatches(query, () => ({
    [fieldName]: `deleted:${deletedUidHash}`,
    anonymizedAt: FieldValue.serverTimestamp(),
  }), db);
}

/** Removes the deleting user's support content while retaining ticket/audit shape. */
export async function pseudonymizeSupportData(
  db: Firestore,
  uid: string,
  deletedUidHash: string,
  operationId: string,
  afterBatchCommit?: (commitNumber: number) => Promise<void>,
): Promise<void> {
  const pseudonym = `deleted:${deletedUidHash}`;
  const [ownedTickets, claimedTickets] = await Promise.all([
    db.collection("support_requests").where("userId", "==", uid).get(),
    db.collection("support_requests")
      .where("deletionSupportOperationId", "==", operationId).get(),
  ]);
  const tickets = new Map<string, FirebaseFirestore.QueryDocumentSnapshot>();
  for (const ticket of [...ownedTickets.docs, ...claimedTickets.docs]) {
    tickets.set(ticket.id, ticket);
  }

  for (const ticket of tickets.values()) {
    const current = await ticket.ref.get();
    const currentData = current.data() ?? {};
    if (String(currentData.deletionSupportOperationId ?? "") === operationId &&
        String(currentData.deletionSupportStatus ?? "") === "completed") {
      continue;
    }
    await ticket.ref.set({
      deletionSupportOperationId: operationId,
      deletionSupportStatus: "processing",
      deletionSupportUpdatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    const [messages, history] = await Promise.all([
      ticket.ref.collection("messages").get(),
      ticket.ref.collection("history").get(),
    ]);
    let batch = db.batch();
    let count = 0;
    let commitNumber = 0;
    const commit = async (): Promise<void> => {
      if (count === 0) return;
      await batch.commit();
      commitNumber += 1;
      if (afterBatchCommit) await afterBatchCommit(commitNumber);
      batch = db.batch();
      count = 0;
    };
    const update = async (
      reference: FirebaseFirestore.DocumentReference,
      values: Record<string, unknown>,
    ): Promise<void> => {
      batch.update(reference, values);
      count += 1;
      if (count === 400) await commit();
    };

    for (const message of messages.docs) {
      const data = message.data();
      const senderIsDeletingUser = String(data.senderId ?? "") === uid;
      const readBy = Array.isArray(data.readBy) ?
        data.readBy.filter((value) => String(value) !== uid) : [];
      await update(message.ref, {
        ...(senderIsDeletingUser ? {
          senderId: pseudonym,
          message: "",
          attachments: [],
          deleted: true,
          deletedAt: FieldValue.serverTimestamp(),
        } : {}),
        readBy,
      });
    }

    for (const item of history.docs) {
      const data = item.data();
      if (String(data.performedByUid ?? "") !== uid) continue;
      await update(item.ref, {
        performedByUid: pseudonym,
        note: "",
      });
    }
    await commit();

    const ticketData = (await ticket.ref.get()).data() ?? {};
    await ticket.ref.set({
      userId: pseudonym,
      subject: "",
      description: "",
      attachmentUrls: [],
      lastMessage: "",
      lastMessageSenderId:
        String(ticketData.lastMessageSenderId ?? "") === uid ?
          pseudonym : ticketData.lastMessageSenderId ?? null,
      deletionPseudonymizedAt: FieldValue.serverTimestamp(),
      deletionSupportOperationId: operationId,
      deletionSupportStatus: "completed",
      deletionSupportUpdatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  }

  await db.collection("support_rate_limits").doc(uid).delete();
}

async function updateQueryInBatches(
  query: Query,
  values: () => Record<string, unknown>,
  db: Firestore,
): Promise<void> {
  const snapshot = await query.get();
  let batch = db.batch();
  let count = 0;
  for (const document of snapshot.docs) {
    batch.update(document.ref, values());
    count += 1;
    if (count === 400) {
      await batch.commit();
      batch = db.batch();
      count = 0;
    }
  }
  if (count > 0) await batch.commit();
}
