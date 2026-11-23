const test = require("node:test");
const assert = require("node:assert/strict");
const {getApps, initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

process.env.GCLOUD_PROJECT = "demo-support-request";
process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";

for (const app of getApps()) deleteApp(app);
const app = initializeApp({
  projectId: "demo-support-request",
  storageBucket: "demo-support-request.appspot.com",
});
const db = getFirestore(app);
const {createSupportRequest} = require("../lib/support/createSupportRequest.js");

test.beforeEach(async () => {
  const collections = await db.listCollections();
  for (const collection of collections) await db.recursiveDelete(collection);
});

test.after(async () => deleteApp(app));

async function seedMessageEvent() {
  await db.collection("public_profiles").doc("organizer").set({
    profilAdi: "Organizer",
  });
  const event = db.collection("events").doc("event-1");
  await event.set({
    accessModel: "free",
    paymentRequired: false,
    paymentStatus: "not_required",
    olusturanUid: "organizer",
    selectedPlayerIds: ["participant"],
  });
  await event.collection("applications").doc("participant").set({
    addressAccessStatus: "unlocked",
    paymentStatus: "not_required",
    status: "accepted",
  });
  await event.collection("messages").doc("message-1").set({
    eventId: "event-1",
    senderUid: "organizer",
    text: "private reported message",
  });
}

function request(uid) {
  return {
    auth: {uid, token: {}},
    data: {
      category: "message_report",
      subject: "Reported message",
      description: "This message violates the rules.",
      urgency: "normal",
      relatedUserId: "organizer",
      relatedEventId: "event-1",
      relatedMessageId: "message-1",
      attachmentUrls: [],
      clientRequestId: `test-${uid}`,
    },
    rawRequest: {headers: {}},
  };
}

test("knowing event and message ids does not disclose or copy message content", async () => {
  await seedMessageEvent();
  await assert.rejects(
    createSupportRequest.run(request("outsider")),
    (error) => error.code === "permission-denied" && !error.message.includes("private reported message"),
  );
  assert.equal((await db.collection("support_requests").get()).empty, true);
  assert.equal((await db.collection("moderation_report_evidence").get()).empty, true);
});

test("an authorized participant creates public metadata and private evidence", async () => {
  await seedMessageEvent();
  const result = await createSupportRequest.run(request("participant"));
  const ticket = (await db.collection("support_requests").doc(result.requestId).get()).data();
  const privateEvidence = (await db.collection("moderation_report_evidence")
    .doc(result.requestId).get()).data();
  assert.equal(ticket.evidenceSnapshot.message.messageId, "message-1");
  assert.equal(ticket.evidenceSnapshot.message.text, undefined);
  assert.equal(privateEvidence.evidence.message.text, "private reported message");
  assert.equal(privateEvidence.reporterUid, "participant");
});
