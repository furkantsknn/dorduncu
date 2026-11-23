const assert = require("node:assert/strict");
const test = require("node:test");
const {deleteApp, initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {
  allocateSupportNumber,
  ensureUserManagementNumber,
} = require("../lib/admin/managementNumberPolicy.js");

const app = initializeApp({projectId: "demo-management-number-policy"});
const db = getFirestore(app);

test.after(async () => deleteApp(app));

test("concurrent retries assign one immutable number to one user", async () => {
  const values = await Promise.all(Array.from({length: 12}, () =>
    db.runTransaction((transaction) =>
      ensureUserManagementNumber(db, transaction, "same-user"))));
  assert.equal(new Set(values).size, 1);
  assert.equal(values[0], "U-000001");
});

test("concurrent support allocations stay unique and years are isolated", async () => {
  const values = await Promise.all(Array.from({length: 12}, () =>
    db.runTransaction((transaction) =>
      allocateSupportNumber(db, transaction, 2026))));
  assert.equal(new Set(values).size, values.length);
  const nextYear = await db.runTransaction((transaction) =>
    allocateSupportNumber(db, transaction, 2027));
  assert.equal(nextYear, "DST-2027-000001");
});
