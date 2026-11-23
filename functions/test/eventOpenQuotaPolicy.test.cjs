const assert = require("node:assert/strict");
const {Timestamp} = require("firebase-admin/firestore");
const {
  buildEventQuotaState,
  eventCountsTowardOpenQuota,
} = require("../lib/events/eventOpenQuotaPolicy.js");

const now = Date.parse("2026-10-13T12:00:00Z");
const future = Timestamp.fromMillis(now + 60_000);
const past = Timestamp.fromMillis(now - 60_000);

assert.equal(buildEventQuotaState([], false).canCreate, true);
assert.equal(buildEventQuotaState(["a"], false).canCreate, true);
assert.equal(buildEventQuotaState(["a", "b"], false).canCreate, false);
assert.equal(buildEventQuotaState(["a", "b"], true).canCreate, true);
assert.equal(eventCountsTowardOpenQuota({durum: "aktif", endAt: future}, now), true);
assert.equal(eventCountsTowardOpenQuota({durum: "aktif", endAt: past}, now), false);
assert.equal(eventCountsTowardOpenQuota({durum: "cancelled", endAt: future}, now), false);
assert.equal(eventCountsTowardOpenQuota({durum: "completed", endAt: future}, now), false);
assert.equal(eventCountsTowardOpenQuota({durum: "aktif", endAt: future, full: true}, now), true);
assert.equal(eventCountsTowardOpenQuota({status: "active", tarih: future}, now), true);

console.log("eventOpenQuotaPolicy tests passed");
