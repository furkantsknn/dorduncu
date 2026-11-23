const test = require("node:test");
const assert = require("node:assert/strict");
const {getApps, initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");

process.env.GCLOUD_PROJECT = "demo-account-deletion";
process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";

for (const app of getApps()) deleteApp(app);
const app = initializeApp({projectId: "demo-account-deletion"});
const db = getFirestore(app);
const {
  processDeletionRequest,
  pseudonymizeSupportData,
} = require("../lib/users/processAccountDeletion.js");
const {
  requestAccountDeletionForUser,
} = require("../lib/users/requestAccountDeletion.js");
const {
  syncCurrentPublicProfile,
} = require("../lib/users/syncPublicProfile.js");
const {
  syncCurrentPublicMarketBadges,
} = require("../lib/users/syncPublicMarketBadges.js");

function notFound() {
  const error = new Error("missing");
  error.code = "auth/user-not-found";
  return error;
}

async function seed(uid, instance = "instance-1", extra = {}) {
  await db.collection("users").doc(uid).set({
    uid,
    accountStatus: "deletionRequested",
    profilAdi: "Old profile",
    ...extra.user,
  });
  await db.collection("accountDeletionRequests").doc(uid).set({
    uid,
    operationId: `operation-${uid}`,
    accountInstanceId: instance,
    deletedUidHash: `hash-${uid}`,
    status: "pending",
    ...extra.request,
  });
}

function dependencies(instance = "instance-1") {
  let authExists = true;
  return {
    deps: {
      db,
      authGetUser: async () => {
        if (!authExists) throw notFound();
        return {metadata: {creationTime: instance}};
      },
      authDeleteUser: async () => { authExists = false; },
      deleteProfilePhotos: async () => {},
      deleteSupportAttachments: async () => {},
      deleteVerificationVersions: async () => 0,
    },
    authExists: () => authExists,
  };
}

test.beforeEach(async () => {
  const collections = await db.listCollections();
  for (const collection of collections) await db.recursiveDelete(collection);
});

test.after(async () => deleteApp(app));

test("real worker persists nested step maps and preserves shared data", async () => {
  const uid = "nested-and-shared";
  await seed(uid);
  await db.collection("events").doc("shared-event").set({ownerUid: uid});
  await db.collection("events").doc("shared-event")
    .collection("messages").doc("shared-message").set({senderId: uid});
  const state = dependencies();
  await processDeletionRequest(
    db.collection("accountDeletionRequests").doc(uid), uid, state.deps);
  const request = (await db.collection("accountDeletionRequests").doc(uid)
    .get()).data();
  assert.equal(request.status, "completed");
  assert.equal(request.steps.profilePhotosDeleted, true);
  assert.equal(request.steps.authDeleted, true);
  assert.equal(request["steps.authDeleted"], undefined);
  assert.equal(typeof request.stepCompletedAt.authDeleted.toMillis, "function");
  assert.equal((await db.collection("events").doc("shared-event").get()).exists, true);
  assert.equal((await db.collection("events").doc("shared-event")
    .collection("messages").doc("shared-message").get()).exists, true);
});

test("account deletion removes support content and pseudonymizes retained shape", async () => {
  const uid = "support-owner";
  await seed(uid);
  const ticket = db.collection("support_requests").doc("ticket");
  await ticket.set({
    userId: uid,
    subject: "My phone",
    description: "personal description",
    attachmentUrls: [`support_attachments/${uid}/draft/file.png`],
    lastMessage: "personal description",
    lastMessageSenderId: uid,
    evidenceSnapshot: {user: {uid: "reported-user"}},
  });
  await ticket.collection("messages").doc("user-message").set({
    senderId: uid,
    message: "personal reply",
    attachments: [`support_attachments/${uid}/draft/file.png`],
    readBy: [uid, "admin"],
    deleted: false,
  });
  await ticket.collection("messages").doc("admin-message").set({
    senderId: "admin",
    message: "staff reply",
    attachments: [],
    readBy: [uid, "admin"],
  });
  await ticket.collection("history").doc("created").set({
    performedByUid: uid,
    note: "personal note",
  });
  await db.collection("support_rate_limits").doc(uid).set({uid});

  const state = dependencies();
  await processDeletionRequest(
    db.collection("accountDeletionRequests").doc(uid), uid, state.deps);

  const retained = (await ticket.get()).data();
  assert.equal(retained.userId, `deleted:hash-${uid}`);
  assert.equal(retained.subject, "");
  assert.equal(retained.description, "");
  assert.deepEqual(retained.attachmentUrls, []);
  assert.deepEqual(retained.evidenceSnapshot, {user: {uid: "reported-user"}});
  const userMessage = (await ticket.collection("messages")
    .doc("user-message").get()).data();
  assert.equal(userMessage.senderId, `deleted:hash-${uid}`);
  assert.equal(userMessage.message, "");
  assert.equal(userMessage.deleted, true);
  assert.deepEqual(userMessage.attachments, []);
  assert.deepEqual(userMessage.readBy, ["admin"]);
  const adminMessage = (await ticket.collection("messages")
    .doc("admin-message").get()).data();
  assert.equal(adminMessage.message, "staff reply");
  assert.deepEqual(adminMessage.readBy, ["admin"]);
  const history = (await ticket.collection("history").doc("created").get()).data();
  assert.equal(history.performedByUid, `deleted:hash-${uid}`);
  assert.equal(history.note, "");
  assert.equal((await db.collection("support_rate_limits").doc(uid).get()).exists, false);
});

test("support cleanup survives a 400-document commit failure and repeated retry", async () => {
  const uid = "support-batch-retry";
  await seed(uid);
  const ticket = db.collection("support_requests").doc("large-ticket");
  await ticket.set({
    userId: uid,
    subject: "private",
    description: "private",
    lastMessageSenderId: uid,
  });
  for (let index = 0; index < 405; index += 1) {
    await ticket.collection("messages").doc(`message-${String(index).padStart(3, "0")}`).set({
      senderId: uid,
      message: `private-${index}`,
      readBy: [uid],
    });
  }
  await db.collection("support_requests").doc("unrelated-ticket").set({
    userId: "someone-else",
    subject: "keep",
  });

  const state = dependencies();
  let injected = false;
  state.deps.afterSupportBatchCommit = async () => {
    if (!injected) {
      injected = true;
      throw new Error("controlled-support-progress-failure");
    }
  };
  const request = db.collection("accountDeletionRequests").doc(uid);
  await processDeletionRequest(request, uid, state.deps);
  assert.equal((await request.get()).data().status, "failed");
  assert.equal((await ticket.get()).data().userId, uid);
  assert.equal((await ticket.get()).data().deletionSupportOperationId, `operation-${uid}`);

  state.deps.afterSupportBatchCommit = undefined;
  await request.update({nextRetryAt: Timestamp.fromMillis(0)});
  await processDeletionRequest(request, uid, state.deps);
  assert.equal((await request.get()).data().status, "completed");
  assert.equal((await ticket.get()).data().userId, `deleted:hash-${uid}`);
  const messages = await ticket.collection("messages").get();
  assert.equal(messages.size, 405);
  for (const message of messages.docs) {
    assert.equal(message.data().senderId, `deleted:hash-${uid}`);
    assert.equal(message.data().message, "");
  }

  const beforeSecondRetry = (await ticket.get()).data().deletionPseudonymizedAt.toMillis();
  await pseudonymizeSupportData(db, uid, `hash-${uid}`, `operation-${uid}`);
  assert.equal(
    (await ticket.get()).data().deletionPseudonymizedAt.toMillis(),
    beforeSecondRetry,
  );
  assert.equal(
    (await db.collection("support_requests").doc("unrelated-ticket").get()).data().subject,
    "keep",
  );
});

test("partial failure retries completed steps without repeating them", async () => {
  const uid = "partial-retry";
  await seed(uid);
  let photoCalls = 0;
  const state = dependencies();
  state.deps.deleteProfilePhotos = async () => {
    photoCalls += 1;
    if (photoCalls === 1) throw new Error("controlled-storage-failure");
  };
  const ref = db.collection("accountDeletionRequests").doc(uid);
  await processDeletionRequest(ref, uid, state.deps);
  assert.equal((await ref.get()).data().status, "failed");
  await ref.update({nextRetryAt: Timestamp.fromMillis(0)});
  await processDeletionRequest(ref, uid, state.deps);
  assert.equal((await ref.get()).data().status, "completed");
  assert.equal(photoCalls, 2);
});

test("auth deletion crash window recovers idempotently", async () => {
  const uid = "auth-crash";
  await seed(uid);
  const state = dependencies();
  let failedCommit = false;
  state.deps.beforeStepCommit = async (name) => {
    if (name === "authDeleted" && !failedCommit) {
      failedCommit = true;
      throw new Error("controlled-progress-write-failure");
    }
  };
  const ref = db.collection("accountDeletionRequests").doc(uid);
  await processDeletionRequest(ref, uid, state.deps);
  assert.equal(state.authExists(), false);
  assert.equal((await ref.get()).data().status, "failed");
  state.deps.beforeStepCommit = undefined;
  await ref.update({nextRetryAt: Timestamp.fromMillis(0)});
  await processDeletionRequest(ref, uid, state.deps);
  assert.equal((await ref.get()).data().status, "completed");
});

test("late old worker cannot complete or fail after lease loss", async () => {
  const uid = "lease-loss";
  await seed(uid);
  const ref = db.collection("accountDeletionRequests").doc(uid);
  let releaseOld;
  const oldGate = new Promise((resolve) => { releaseOld = resolve; });
  let oldEntered;
  const entered = new Promise((resolve) => { oldEntered = resolve; });
  const old = dependencies();
  old.deps.deleteProfilePhotos = async () => { oldEntered(); await oldGate; };
  const oldRun = processDeletionRequest(ref, uid, old.deps);
  await entered;
  await ref.update({leaseExpiresAt: Timestamp.fromMillis(0)});
  const current = dependencies();
  await processDeletionRequest(ref, uid, current.deps);
  releaseOld();
  await oldRun;
  const data = (await ref.get()).data();
  assert.equal(data.status, "completed");
  assert.equal(data.failureReason, undefined);
});

test("concurrent callable requests share one operation and new instance resets steps", async () => {
  const uid = "callable-race";
  await db.collection("users").doc(uid).set({
    uid, telefon: "+900", accountStatus: "active",
  });
  const input = {db, uid, accountInstanceId: "instance-1", tokenPhone: "+900"};
  const results = await Promise.all([
    requestAccountDeletionForUser(input),
    requestAccountDeletionForUser(input),
  ]);
  assert.equal(results.filter((value) => !value.alreadyRequested).length, 1);
  const ref = db.collection("accountDeletionRequests").doc(uid);
  const first = (await ref.get()).data();
  await ref.set({status: "completed", steps: {authDeleted: true}}, {merge: true});
  await db.collection("users").doc(uid).set({accountStatus: "active"}, {merge: true});
  await requestAccountDeletionForUser({...input, accountInstanceId: "instance-2"});
  const second = (await ref.get()).data();
  assert.notEqual(second.operationId, first.operationId);
  assert.equal(second.steps, undefined);
  assert.equal(second.accountInstanceId, "instance-2");
});

test("old operation cannot delete a recreated same-uid account", async () => {
  const uid = "new-instance";
  await seed(uid, "old-instance");
  const ref = db.collection("accountDeletionRequests").doc(uid);
  const state = dependencies("new-instance");
  await processDeletionRequest(ref, uid, state.deps);
  assert.equal((await ref.get()).data().status, "superseded");
  assert.equal((await db.collection("users").doc(uid).get()).exists, true);
  assert.equal(state.authExists(), true);
});

test("late public-profile event reads current deletion state atomically", async () => {
  const uid = "late-profile";
  await seed(uid);
  await db.collection("public_profiles").doc(uid).set({uid, profilAdi: "stale"});
  await syncCurrentPublicProfile(uid);
  assert.equal((await db.collection("public_profiles").doc(uid).get()).exists, false);
});

test("late public badge event cannot recreate a deleting profile", async () => {
  const uid = "late-badges";
  await seed(uid);
  await db.collection("public_profiles").doc(uid).set({uid, marketBadges: []});
  await db.collection("users").doc(uid).collection("owned_badges")
    .doc("badge").set({productId: "badge", active: true});
  await syncCurrentPublicMarketBadges(uid);
  assert.equal((await db.collection("public_profiles").doc(uid).get()).exists, false);
});

test("verification cleanup uses the stored generation, not a replacement", async () => {
  const uid = "generation-change";
  await seed(uid);
  const path = `verification_documents/${uid}/front.jpg`;
  await db.collection("verification_requests").doc(uid).set({
    uid,
    identityFrontPath: path,
    verificationDocumentObjects: {
      identityFrontPath: {path, generation: "old-generation"},
    },
  });
  let received;
  const state = dependencies();
  state.deps.deleteVerificationVersions = async (versions) => {
    received = versions;
    return 0; // controlled 412/replaced-generation outcome
  };
  await processDeletionRequest(
    db.collection("accountDeletionRequests").doc(uid), uid, state.deps);
  assert.equal(received.length, 1);
  assert.equal(received[0].generation, "old-generation");
  assert.equal(received[0].path, path);
});
