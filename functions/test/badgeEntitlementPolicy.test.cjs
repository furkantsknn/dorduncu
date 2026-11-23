const assert = require("node:assert/strict");
const test = require("node:test");

const {
  applyAdminBadgeDecision,
  afterPlayRevocation,
  badgeIsEntitled,
} = require("../lib/market/badgeEntitlementPolicy.js");

test("grant and remove preserve the independent Play source", () => {
  const removed = applyAdminBadgeDecision({googlePlayEntitled: true}, "remove");
  assert.deepEqual(removed, {
    adminGranted: false,
    adminBlocked: true,
    googlePlayEntitled: true,
  });
  const granted = applyAdminBadgeDecision(removed, "grant");
  assert.deepEqual(granted, {
    adminGranted: true,
    adminBlocked: false,
    googlePlayEntitled: true,
  });
  assert.deepEqual(applyAdminBadgeDecision(granted, "grant"), granted);
});

test("legacy and Play ownership remain backward compatible", () => {
  assert.equal(badgeIsEntitled({}), true);
  assert.equal(badgeIsEntitled({googlePlayEntitled: true}), true);
  assert.equal(badgeIsEntitled({googlePlayEntitled: false}), false);
});

test("admin block wins over Play restore and fulfillment", () => {
  assert.equal(badgeIsEntitled({adminBlocked: true, googlePlayEntitled: true}), false);
});

test("independent admin grant survives Play refund", () => {
  const state = afterPlayRevocation({adminGranted: true, googlePlayEntitled: true});
  assert.equal(state.googlePlayEntitled, false);
  assert.equal(badgeIsEntitled(state), true);
});

test("admin regrant is explicit and does not revive refunded Play source", () => {
  assert.equal(badgeIsEntitled({
    adminGranted: true,
    adminBlocked: false,
    googlePlayEntitled: false,
  }), true);
});
