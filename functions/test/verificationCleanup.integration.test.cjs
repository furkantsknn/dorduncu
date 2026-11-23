const assert = require("node:assert/strict");
const test = require("node:test");

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  test("Firestore integration suite requires the emulator", {skip: true}, () => {});
  return;
}

const {Timestamp} = require("firebase-admin/firestore");
const {firestore} = require("../lib/config/firebaseAdmin.js");
const {
  completeCleanup,
  prepareCleanup,
  processDocument,
} = require("../lib/users/cleanupVerificationDocuments.js");
const {
  commitVerificationSubmission,
} = require("../lib/users/submitVerification.js");
const {processVerification} = require("../lib/users/processVerification.js");
const {
  scanVerificationCleanupPages,
} = require("../lib/users/verificationCleanupPolicy.js");

const old = Timestamp.fromDate(new Date("2026-01-01T00:00:00Z"));
const cutoff = new Date("2026-02-01T00:00:00Z");

async function clearFirestore() {
  const base = `http://${process.env.FIRESTORE_EMULATOR_HOST}` +
    `/emulator/v1/projects/${process.env.GCLOUD_PROJECT}/databases/(default)/documents`;
  await fetch(base, {method: "DELETE"});
}

function storage(initial = {}) {
  const objects = new Map(Object.entries(initial));
  const failures = new Map();
  return {
    objects,
    failures,
    read: async (path) => {
      const failure = failures.get(`read:${path}`);
      if (failure) throw Object.assign(new Error("metadata"), {code: failure});
      if (!objects.has(path)) return {field: "", path, generation: "", missing: true};
      return {field: "", path, generation: objects.get(path)};
    },
    remove: async (versions) => {
      for (const item of versions) {
        const failure = failures.get(`delete:${item.path}`);
        if (failure) throw Object.assign(new Error("delete"), {code: failure});
        if (item.missing) continue;
        if (!objects.has(item.path)) continue;
        if (objects.get(item.path) !== item.generation) continue;
        objects.delete(item.path);
      }
      return versions.length;
    },
  };
}

async function seed(uid, overrides = {}) {
  const path = `verification_documents/${uid}/front.jpg`;
  const data = {
    uid,
    status: "rejected",
    submissionId: `submission-${uid}`,
    decisionVersion: `decision-${uid}`,
    retentionStartedAt: old,
    decidedAt: old,
    identityFrontPath: path,
    verificationDocumentObjects: {
      identityFrontPath: {path, generation: "1"},
    },
    ...overrides,
  };
  for (const key of Object.keys(data)) {
    if (data[key] === undefined) delete data[key];
  }
  const ref = firestore.collection("verification_requests").doc(uid);
  await ref.set(data);
  return {ref, path};
}

test.beforeEach(clearFirestore);

test("real prepare/complete rejects rejected-to-approved decision drift", async () => {
  const {ref} = await seed("decision-race");
  const observed = (await ref.get()).data();
  const plan = await prepareCleanup(ref, observed, cutoff);
  assert.ok(plan);
  await ref.update({status: "approved", decidedAt: Timestamp.now()});
  assert.equal(await completeCleanup(ref, plan), false);
  const final = (await ref.get()).data();
  assert.equal(final.identityFrontPath.endsWith("front.jpg"), true);
  assert.equal(final.documentsDeletedAt, undefined);
});

test("real admin decision path is locked after prepare", async () => {
  if (!/^127\.0\.0\.1:\d+$/.test(process.env.FIREBASE_AUTH_EMULATOR_HOST || "")) throw new Error("Local Auth emulator required");
  const auth = require("firebase-admin/auth").getAuth();
  try { await auth.getUser("admin"); } catch { await auth.createUser({uid: "admin"}); }
  await auth.setCustomUserClaims("admin", {role: "super_admin"});
  const {ref} = await seed("admin-race", {
    identityFingerprint: "fingerprint-admin-race",
    identityUniquenessCheck: {status: "passed"},
  });
  await firestore.collection("users").doc("admin-race").set({verified: false});
  const plan = await prepareCleanup(ref, (await ref.get()).data(), cutoff);
  assert.ok(plan);
  await assert.rejects(() => processVerification.run({
    data: {requestId: "admin-race", status: "approved"},
    auth: {uid: "admin", token: {role: "super_admin", auth_time: Math.floor(Date.now() / 1000) + 5}},
    rawRequest: {},
  }), (error) => error.code === "failed-precondition");
});

test("real submit path replaces cleanup identity without losing new fields", async () => {
  const {ref} = await seed("new-submit");
  const plan = await prepareCleanup(ref, (await ref.get()).data(), cutoff);
  assert.ok(plan);
  await firestore.collection("users").doc("new-submit").set({
    verified: false,
    accountStatus: "active",
  });
  await commitVerificationSubmission({
    uid: "new-submit",
    submissionId: "submission-new",
    identityFrontPath: "verification_documents/new-submit/new-front.jpg",
    selfiePath: "verification_documents/new-submit/new-selfie.jpg",
    versions: [
      {field: "", path: "verification_documents/new-submit/new-front.jpg", generation: "7"},
      {field: "", path: "verification_documents/new-submit/new-selfie.jpg", generation: "8"},
    ],
  });
  await commitVerificationSubmission({
    uid: "new-submit",
    submissionId: "response-loss-retry-must-not-replace",
    identityFrontPath: "verification_documents/new-submit/new-front.jpg",
    selfiePath: "verification_documents/new-submit/new-selfie.jpg",
    versions: [
      {field: "", path: "verification_documents/new-submit/new-front.jpg", generation: "7"},
      {field: "", path: "verification_documents/new-submit/new-selfie.jpg", generation: "8"},
    ],
  });
  assert.equal(await completeCleanup(ref, plan), false);
  const final = (await ref.get()).data();
  assert.equal(final.submissionId, "submission-new");
  assert.equal(final.identityFrontPath.endsWith("new-front.jpg"), true);
  assert.equal(final.documentsDeletedAt, undefined);
});

test("legacy assignment is idempotent and never overwrites a new submission", async () => {
  const {ref, path} = await seed("legacy", {submissionId: undefined,
    decisionVersion: undefined, retentionStartedAt: undefined,
    verificationDocumentObjects: undefined});
  const fake = storage({[path]: "3"});
  const observed = (await ref.get()).data();
  const first = await prepareCleanup(ref, observed, cutoff, fake.read);
  assert.ok(first.submissionId.startsWith("legacy:legacy:"));
  const retry = await prepareCleanup(ref, (await ref.get()).data(), cutoff, fake.read);
  assert.equal(retry.operationId, first.operationId);
  await ref.update({submissionId: "brand-new", status: "pending",
    identityFrontPath: "verification_documents/legacy/new.jpg"});
  assert.equal(await completeCleanup(ref, first), false);
  assert.equal((await ref.get()).data().submissionId, "brand-new");
});

test("metadata 404 is completed; 403 and transient errors remain retryable", async () => {
  const missing = await seed("missing", {verificationDocumentObjects: undefined});
  const absent = storage();
  assert.equal(await processDocument(await missing.ref.get(), cutoff,
    absent.remove, absent.read), true);
  assert.ok((await missing.ref.get()).data().documentsDeletedAt);

  for (const [uid, code] of [["forbidden", 403], ["temporary", 503]]) {
    const item = await seed(uid, {verificationDocumentObjects: undefined});
    const fake = storage({[item.path]: "1"});
    fake.failures.set(`read:${item.path}`, code);
    await assert.rejects(async () => processDocument(await item.ref.get(), cutoff,
      fake.remove, fake.read), (error) => error.code === code);
    assert.equal((await item.ref.get()).data().documentsDeletedAt, undefined);
  }
});

test("partial deletion retries deterministically and preserves newer generation", async () => {
  const uid = "partial";
  const front = `verification_documents/${uid}/front.jpg`;
  const selfie = `verification_documents/${uid}/selfie.jpg`;
  const {ref} = await seed(uid, {
    selfiePath: selfie,
    verificationDocumentObjects: {
      identityFrontPath: {path: front, generation: "1"},
      selfiePath: {path: selfie, generation: "2"},
    },
  });
  const fake = storage({[front]: "1", [selfie]: "2"});
  fake.failures.set(`delete:${selfie}`, 503);
  assert.equal(await processDocument(await ref.get(), cutoff,
    fake.remove, fake.read), false);
  assert.equal(fake.objects.has(front), false);
  fake.failures.delete(`delete:${selfie}`);
  fake.objects.set(front, "9");
  assert.equal(await processDocument(await ref.get(), cutoff,
    fake.remove, fake.read), true);
  assert.equal(fake.objects.get(front), "9");
  assert.equal(fake.objects.has(selfie), false);
  assert.equal(await processDocument(await ref.get(), cutoff,
    fake.remove, fake.read), false);
});

test("real Firestore document-id cursor scans 250 records", async () => {
  const batchSize = 100;
  for (let start = 0; start < 250; start += 100) {
    const batch = firestore.batch();
    for (let index = start; index < Math.min(start + 100, 250); index += 1) {
      batch.set(firestore.collection("verification_requests")
        .doc(String(index).padStart(4, "0")), {status: "pending"});
    }
    await batch.commit();
  }
  const result = await scanVerificationCleanupPages(async (cursor) => {
    let query = firestore.collection("verification_requests")
      .orderBy("__name__").limit(batchSize);
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    return {records: snapshot.docs,
      lastId: snapshot.empty ? null : snapshot.docs.at(-1).id};
  }, async () => true);
  assert.deepEqual(result, {scanned: 250, succeeded: 250, failed: 0});
});
