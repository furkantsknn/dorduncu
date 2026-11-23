const test = require("node:test");
const assert = require("node:assert/strict");
const {getApps, initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

process.env.GCLOUD_PROJECT = "demo-reported-content";
process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";

for (const app of getApps()) deleteApp(app);
const app = initializeApp({
  projectId: "demo-reported-content",
  storageBucket: "demo-reported-content.appspot.com",
});
const db = getFirestore(app);
const {
  authorizeReportedContentRequest,
  removeReportedContent,
  sanitizeProfileImageSnapshots,
} = require("../lib/support/adminRemoveReportedContent.js");

test.beforeEach(async () => {
  if (!/^127\.0\.0\.1:\d+$/.test(process.env.FIREBASE_AUTH_EMULATOR_HOST || "")) throw new Error("Local Auth emulator required");
  const auth = require("firebase-admin/auth").getAuth(app);
  try { await auth.getUser("admin"); } catch { await auth.createUser({uid: "admin"}); }
  await auth.setCustomUserClaims("admin", {role: "admin"});
  const collections = await db.listCollections();
  for (const collection of collections) await db.recursiveDelete(collection);
});

test.after(async () => deleteApp(app));

async function messageTicket(id) {
  const ticket = db.collection("support_requests").doc(id);
  await ticket.set({
    category: "message_report",
    relatedEventId: "event-1",
    relatedMessageId: "message-1",
  });
  return ticket;
}

test("authentication and baseline access run before ticket and category checks", async () => {
  await assert.rejects(
    authorizeReportedContentRequest({auth: undefined}, db, "missing-secret-ticket"),
    (error) => error.code === "unauthenticated",
  );
  await messageTicket("permission-ticket");
  await assert.rejects(
    authorizeReportedContentRequest({
      auth: {uid: "support", token: {role: "support_officer"}},
    }, db, "permission-ticket"),
    (error) => error.code === "permission-denied",
  );
  const authorized = await authorizeReportedContentRequest({
    auth: {uid: "admin", token: {role: "admin", auth_time: Math.floor(Date.now() / 1000) + 5}},
  }, db, "permission-ticket");
  assert.equal(authorized.category, "message_report");
  assert.equal(authorized.uid, "admin");
});

test("retries and different reports preserve the first message evidence", async () => {
  const firstTicket = await messageTicket("report-1");
  const event = db.collection("events").doc("event-1");
  await event.set({
    lastMessageId: "message-1",
    lastMessage: "offending text",
    lastMessageSenderName: "Visible Name",
    lastMessageSenderPhotoUrl: "old-photo",
  });
  const message = event.collection("messages").doc("message-1");
  await message.set({
    senderUid: "offender",
    senderName: "Visible Name",
    text: "offending text",
    attachments: ["private-image"],
    deleted: false,
  });

  const first = await removeReportedContent(db, firstTicket.id, "moderator-1");
  const retry = await removeReportedContent(db, firstTicket.id, "moderator-2");
  const secondTicket = await messageTicket("report-2");
  const second = await removeReportedContent(db, secondTicket.id, "moderator-3");

  assert.equal(first.evidenceId, retry.evidenceId);
  assert.equal(first.evidenceId, second.evidenceId);
  assert.equal(first.alreadyRemoved, false);
  assert.equal(retry.alreadyRemoved, true);
  assert.equal(second.alreadyRemoved, true);
  const evidence = (await db.collection("moderation_evidence")
    .doc(first.evidenceId).get()).data();
  assert.equal(evidence.original.text, "offending text");
  assert.deepEqual(evidence.original.attachments, ["private-image"]);
  assert.equal(evidence.removedBy, "moderator-1");
  const publicMessage = (await message.get()).data();
  assert.equal(publicMessage.text, "");
  assert.equal(publicMessage.message, "");
  assert.deepEqual(publicMessage.attachments, []);
  assert.equal(publicMessage.deleted, true);
  const publicEvent = (await event.get()).data();
  assert.equal(publicEvent.lastMessage, "Yeni mesaj");
  assert.equal(publicEvent.lastMessageSenderName, undefined);
  assert.equal(publicEvent.lastMessageSenderPhotoUrl, undefined);
});

test("message removal preserves the private report-time snapshot", async () => {
  const ticket = await messageTicket("private-message-report");
  const event = db.collection("events").doc("event-1");
  await event.set({lastMessageId: "message-1"});
  await event.collection("messages").doc("message-1").set({
    eventId: "event-1",
    senderUid: "offender",
    text: "edited after report",
  });
  await db.collection("moderation_report_evidence").doc(ticket.id).set({
    evidence: {message: {
      eventId: "event-1",
      messageId: "message-1",
      senderId: "offender",
      text: "text at report time",
    }},
  });
  const result = await removeReportedContent(db, ticket.id, "moderator");
  const evidence = (await db.collection("moderation_evidence")
    .doc(result.evidenceId).get()).data();
  assert.equal(evidence.original.text, "text at report time");
  assert.equal(evidence.targetUid, "offender");
});

function storageTarget(reference, evidenceId, overrides = {}) {
  return {
    bucket: "demo-reported-content.appspot.com",
    path: "profile_photos/offender/old.jpg",
    generation: "17",
    contentType: "image/jpeg",
    profileReference: reference,
    evidencePath: `moderation_evidence/profile_images/${evidenceId}`,
    ...overrides,
  };
}

async function profileTicket(id, target = storageTarget("profile_photos/offender/old.jpg", "pending")) {
  const ticket = db.collection("support_requests").doc(id);
  await ticket.set({category: "inappropriate_image", relatedUserId: "offender"});
  await db.collection("moderation_report_evidence").doc(id).set({
    evidence: {profileImage: target},
  });
  return ticket;
}

test("profile removal pins one generation and preserves a concurrent new photo", async () => {
  const oldReference = "profile_photos/offender/old.jpg";
  const ticket = await profileTicket("profile-report");
  await db.collection("users").doc("offender").set({profilFotografi: oldReference});
  await db.collection("public_profiles").doc("offender").set({profilFotografi: oldReference});
  const event = db.collection("events").doc("owned-event");
  await event.set({
    olusturanUid: "offender",
    olusturanProfilFotografi: oldReference,
  });
  const application = event.collection("applications").doc("offender");
  await application.set({playerId: "offender", playerProfilePhoto: oldReference});
  const message = event.collection("messages").doc("old-message");
  await message.set({senderUid: "offender", senderPhotoUrl: oldReference});
  const notification = db.collection("users").doc("viewer")
    .collection("notifications").doc("old-notification");
  await notification.set({senderUid: "offender", senderPhotoUrl: oldReference});
  const actions = [];
  const storage = {
    resolve: async (reference, evidenceId) => storageTarget(reference, evidenceId),
    preserve: async (target) => {
      actions.push(`preserve:${target.path}:${target.generation}`);
      await db.collection("users").doc("offender").update({
        profilFotografi: "profile_photos/offender/new.jpg",
      });
      await db.collection("public_profiles").doc("offender").update({
        profilFotografi: "profile_photos/offender/new.jpg",
      });
      return true;
    },
    deleteOriginal: async (target) => {
      actions.push(`delete:${target.path}:${target.generation}`);
    },
  };

  const result = await removeReportedContent(db, ticket.id, "moderator", storage);
  assert.equal(result.filePreserved, true);
  assert.deepEqual(actions, [
    "preserve:profile_photos/offender/old.jpg:17",
    "delete:profile_photos/offender/old.jpg:17",
  ]);
  assert.equal(
    (await db.collection("users").doc("offender").get()).data().profilFotografi,
    "profile_photos/offender/new.jpg",
  );
  assert.equal(
    (await db.collection("public_profiles").doc("offender").get()).data().profilFotografi,
    "profile_photos/offender/new.jpg",
  );
  assert.equal((await event.get()).data().olusturanProfilFotografi, "");
  assert.equal((await application.get()).data().playerProfilePhoto, "");
  assert.equal((await message.get()).data().senderPhotoUrl, "");
  assert.equal((await notification.get()).data().senderPhotoUrl, "");
  const evidence = (await db.collection("moderation_evidence").doc(result.evidenceId).get()).data();
  assert.equal(evidence.filePreserved, true);
  assert.equal(evidence.sourceGeneration, "17");
  assert.equal(evidence.evidenceObjectPath, storageTarget(oldReference, result.evidenceId).evidencePath);
});

test("profile storage partial failure retries the pinned target safely", async () => {
  const oldReference = "profile_photos/offender/old.jpg";
  const ticket = await profileTicket("profile-retry");
  await db.collection("users").doc("offender").set({profilFotografi: oldReference});
  await db.collection("public_profiles").doc("offender").set({profilFotografi: oldReference});
  let deleteCalls = 0;
  const storage = {
    resolve: async (reference, evidenceId) => storageTarget(reference, evidenceId),
    preserve: async () => true,
    deleteOriginal: async () => {
      deleteCalls += 1;
      if (deleteCalls === 1) throw new Error("controlled-storage-delete-failure");
    },
  };

  await assert.rejects(removeReportedContent(db, ticket.id, "moderator", storage));
  assert.equal((await db.collection("users").doc("offender").get()).data().profilFotografi, oldReference);
  const result = await removeReportedContent(db, ticket.id, "moderator", storage);
  assert.equal(deleteCalls, 2);
  assert.equal((await db.collection("users").doc("offender").get()).data().profilFotografi, undefined);
  assert.equal((await db.collection("public_profiles").doc("offender").get()).data().profilFotografi, "");
  assert.equal((await db.collection("moderation_evidence").doc(result.evidenceId).get()).data().filePreserved, true);
});

test("legacy reports require revalidation instead of guessing the current photo", async () => {
  const ticket = db.collection("support_requests").doc("legacy-profile");
  await ticket.set({category: "inappropriate_image", relatedUserId: "offender"});
  await db.collection("users").doc("offender").set({
    profilFotografi: "profile_photos/offender/current.jpg",
  });
  await assert.rejects(
    removeReportedContent(db, ticket.id, "moderator", {
      resolve: async () => { throw new Error("must not resolve current photo"); },
      preserve: async () => true,
      deleteOriginal: async () => {},
    }),
    (error) => error.code === "failed-precondition" && /yeniden doğrulama/.test(error.message),
  );
});

test("wrong bucket, uid path, and a changed generation cannot share evidence", async () => {
  for (const [id, overrides] of [
    ["wrong-bucket", {bucket: "other.appspot.com"}],
    ["wrong-user", {path: "profile_photos/another/old.jpg"}],
  ]) {
    const ticket = await profileTicket(id, storageTarget("profile_photos/offender/old.jpg", "pending", overrides));
    await assert.rejects(
      removeReportedContent(db, ticket.id, "moderator", {
        resolve: async () => null, preserve: async () => true, deleteOriginal: async () => {},
      }),
      (error) => error.code === "failed-precondition",
    );
  }
  const first = await profileTicket("generation-1", storageTarget("profile_photos/offender/old.jpg", "pending", {generation: "17"}));
  const second = await profileTicket("generation-2", storageTarget("profile_photos/offender/old.jpg", "pending", {generation: "18"}));
  const storage = {resolve: async () => null, preserve: async () => true, deleteOriginal: async () => {}};
  const firstResult = await removeReportedContent(db, first.id, "moderator", storage);
  const secondResult = await removeReportedContent(db, second.id, "moderator", storage);
  assert.notEqual(firstResult.evidenceId, secondResult.evidenceId);
});

test("concurrent moderators converge on the transaction's canonical target", async () => {
  const ticket = await profileTicket("concurrent-profile");
  const calls = [];
  const storage = {
    resolve: async () => null,
    preserve: async (target) => { calls.push(`${target.path}:${target.generation}`); return true; },
    deleteOriginal: async () => {},
  };
  const [first, second] = await Promise.all([
    removeReportedContent(db, ticket.id, "moderator-1", storage),
    removeReportedContent(db, ticket.id, "moderator-2", storage),
  ]);
  assert.equal(first.evidenceId, second.evidenceId);
  assert.deepEqual(new Set(calls), new Set(["profile_photos/offender/old.jpg:17"]));
  assert.equal((await ticket.get()).data().moderationProfileTarget.evidenceId, first.evidenceId);
});

test("snapshot cleanup does not erase a photo changed after its query", async () => {
  const oldReference = "profile_photos/offender/old.jpg";
  const event = db.collection("events").doc("snapshot-race");
  await event.set({
    olusturanUid: "offender",
    olusturanProfilFotografi: oldReference,
  });
  const originalRunTransaction = db.runTransaction.bind(db);
  let injected = false;
  db.runTransaction = async (callback, options) => {
    if (!injected) {
      injected = true;
      await event.update({
        olusturanProfilFotografi: "profile_photos/offender/new.jpg",
      });
    }
    return originalRunTransaction(callback, options);
  };
  try {
    await sanitizeProfileImageSnapshots(db, "offender", oldReference);
  } finally {
    db.runTransaction = originalRunTransaction;
  }
  assert.equal(
    (await event.get()).data().olusturanProfilFotografi,
    "profile_photos/offender/new.jpg",
  );
});
