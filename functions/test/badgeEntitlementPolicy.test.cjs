const assert = require("node:assert/strict");
const test = require("node:test");

const {
  applyAdminBadgeDecision,
  afterPlayRevocation,
  afterAppleRevocation,
  badgeIsEntitled,
} = require("../lib/market/badgeEntitlementPolicy.js");

test("grant and remove preserve the independent Play source", () => {
  const removed = applyAdminBadgeDecision({googlePlayEntitled: true}, "remove");
  assert.deepEqual(removed, {
    adminGranted: false,
    adminBlocked: true,
    googlePlayEntitled: true,
    appleEntitled: false,
    hasExplicitStoreSource: true,
  });
  const granted = applyAdminBadgeDecision(removed, "grant");
  assert.deepEqual(granted, {
    adminGranted: true,
    adminBlocked: false,
    googlePlayEntitled: true,
    appleEntitled: false,
    hasExplicitStoreSource: true,
  });
  assert.deepEqual(applyAdminBadgeDecision(granted, "grant"), granted);
});

test("legacy, Play, and Apple ownership remain independent and compatible", () => {
  assert.equal(badgeIsEntitled({}), true);
  assert.equal(badgeIsEntitled({googlePlayEntitled: true}), true);
  assert.equal(badgeIsEntitled({googlePlayEntitled: false}), false);
  assert.equal(badgeIsEntitled({appleEntitled: true}), true);
  assert.equal(badgeIsEntitled({appleEntitled: false}), false);
  assert.equal(
    badgeIsEntitled({googlePlayEntitled: false, appleEntitled: true}),
    true,
  );
});

test("admin block wins over Play and Apple restore and fulfillment", () => {
  assert.equal(badgeIsEntitled({adminBlocked: true, googlePlayEntitled: true}), false);
  assert.equal(badgeIsEntitled({adminBlocked: true, appleEntitled: true}), false);
});

test("independent admin grant survives Play refund", () => {
  const state = afterPlayRevocation({adminGranted: true, googlePlayEntitled: true});
  assert.equal(state.googlePlayEntitled, false);
  assert.equal(badgeIsEntitled(state), true);
});

test("Apple refund removes Apple source without revoking independent Play or admin grants", () => {
  const onlyApple = afterAppleRevocation({appleEntitled: true});
  assert.equal(onlyApple.appleEntitled, false);
  assert.equal(badgeIsEntitled(onlyApple), false);

  const appleAndPlay = afterAppleRevocation({
    appleEntitled: true,
    googlePlayEntitled: true,
  });
  assert.equal(appleAndPlay.appleEntitled, false);
  assert.equal(appleAndPlay.googlePlayEntitled, true);
  assert.equal(badgeIsEntitled(appleAndPlay), true);

  const appleAndAdmin = afterAppleRevocation({
    appleEntitled: true,
    adminGranted: true,
  });
  assert.equal(appleAndAdmin.appleEntitled, false);
  assert.equal(badgeIsEntitled(appleAndAdmin), true);
});

test("admin regrant is explicit and does not revive refunded Play source", () => {
  assert.equal(badgeIsEntitled({
    adminGranted: true,
    adminBlocked: false,
    googlePlayEntitled: false,
  }), true);
});
