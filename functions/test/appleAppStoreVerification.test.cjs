const test = require("node:test");
const assert = require("node:assert/strict");

const {
  appleAppAccountTokenForUid,
  parseAppleTransaction,
  resolveAppleSubscriptionState,
  verifyAppleJws,
} = require("../lib/commercial/appleAppStoreVerification");
const {
  afterAppleRevocation,
  afterPlayRevocation,
  badgeIsEntitled,
} = require("../lib/market/badgeEntitlementPolicy");

test("appleAppAccountTokenForUid produces deterministic RFC-4122 v5 UUID", () => {
  const tokenA = appleAppAccountTokenForUid("dort-test-uid-001");
  const tokenB = appleAppAccountTokenForUid("  dort-test-uid-001  ");
  assert.equal(tokenA, tokenB);
  assert.match(
    tokenA,
    /^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
  );
  // Cross-language golden value shared with Dart test.
  assert.equal(tokenA, "13c87cae-df84-5304-82a3-be93b0c1148b");
});

test("verifyAppleJws rejects malformed or unsigned tokens", () => {
  assert.throws(() => verifyAppleJws("not-a-jws"));
  const fakeHeader = Buffer.from(
    JSON.stringify({alg: "HS256", x5c: []}),
  ).toString("base64url");
  const fakePayload = Buffer.from(
    JSON.stringify({bundleId: "com.dortapp.dort"}),
  ).toString("base64url");
  assert.throws(() => verifyAppleJws(`${fakeHeader}.${fakePayload}.sig`));
});

test("parseAppleTransaction validates required fields and parses timestamps", () => {
  const tx = parseAppleTransaction({
    transactionId: "2000000123456789",
    originalTransactionId: "2000000123450000",
    bundleId: "com.dortapp.dort",
    productId: "com.dortapp.dort.plus.monthly",
    environment: "Sandbox",
    purchaseDate: 1760000000000,
    expiresDate: 1762592000000,
    appAccountToken: "cf0d157d-a505-5267-b152-75b78bc85b4c",
  });
  assert.equal(tx.transactionId, "2000000123456789");
  assert.equal(tx.originalTransactionId, "2000000123450000");
  assert.equal(tx.bundleId, "com.dortapp.dort");
  assert.equal(tx.expiresDateMs, 1762592000000);
  assert.equal(tx.revocationDateMs, null);
});

test("resolveAppleSubscriptionState maps lifecycle states to canonical Plus states", () => {
  const nowMs = 1_800_000_000_000;
  const futureMs = nowMs + 86_400_000 * 15;
  const pastMs = nowMs - 86_400_000;

  const baseTx = {
    transactionId: "t1",
    originalTransactionId: "o1",
    bundleId: "com.dortapp.dort",
    productId: "dort_plus_monthly",
    type: "Auto-Renewable Subscription",
    environment: "Production",
    purchaseDateMs: nowMs - 86_400_000,
    originalPurchaseDateMs: nowMs - 86_400_000,
    expiresDateMs: futureMs,
    revocationDateMs: null,
    revocationReason: null,
    appAccountToken: null,
    price: 79900,
    currency: "TRY",
    inAppOwnershipType: "PURCHASED",
    quantity: 1,
  };

  const active = resolveAppleSubscriptionState({
    notificationType: "DID_RENEW",
    transaction: baseTx,
    nowMs,
  });
  assert.equal(active.subscriptionState, "SUBSCRIPTION_STATE_ACTIVE");
  assert.equal(active.hasEntitlement, true);

  const canceled = resolveAppleSubscriptionState({
    notificationType: "DID_CHANGE_RENEWAL_STATUS",
    subtype: "AUTO_RENEW_DISABLED",
    transaction: baseTx,
    nowMs,
  });
  assert.equal(canceled.subscriptionState, "SUBSCRIPTION_STATE_CANCELED");
  assert.equal(canceled.hasEntitlement, true);

  const grace = resolveAppleSubscriptionState({
    notificationType: "DID_FAIL_TO_RENEW",
    subtype: "GRACE_PERIOD",
    transaction: {...baseTx, expiresDateMs: pastMs},
    renewalInfo: {
      originalTransactionId: "o1",
      autoRenewProductId: "dort_plus_monthly",
      productId: "dort_plus_monthly",
      autoRenewStatus: 1,
      expirationIntent: null,
      gracePeriodExpiresDateMs: futureMs,
      isInBillingRetryPeriod: true,
      environment: "Production",
    },
    nowMs,
  });
  assert.equal(grace.subscriptionState, "SUBSCRIPTION_STATE_IN_GRACE_PERIOD");
  assert.equal(grace.hasEntitlement, true);

  const expired = resolveAppleSubscriptionState({
    notificationType: "EXPIRED",
    transaction: {...baseTx, expiresDateMs: pastMs},
    nowMs,
  });
  assert.equal(expired.subscriptionState, "SUBSCRIPTION_STATE_EXPIRED");
  assert.equal(expired.hasEntitlement, false);

  const revoked = resolveAppleSubscriptionState({
    notificationType: "REFUND",
    transaction: {...baseTx, revocationDateMs: nowMs},
    nowMs,
  });
  assert.equal(revoked.subscriptionState, "SUBSCRIPTION_STATE_REVOKED");
  assert.equal(revoked.hasEntitlement, false);
});

test("badgeEntitlementPolicy handles Play, Apple, legacy and admin grants symmetrically", () => {
  assert.equal(badgeIsEntitled({}), true);
  assert.equal(badgeIsEntitled({appleEntitled: true}), true);
  assert.equal(badgeIsEntitled({appleEntitled: false}), false);
  assert.equal(
    badgeIsEntitled({appleEntitled: false, googlePlayEntitled: true}),
    true,
  );
  assert.equal(
    badgeIsEntitled({appleEntitled: true, googlePlayEntitled: false}),
    true,
  );
  assert.equal(
    badgeIsEntitled({appleEntitled: true, adminBlocked: true}),
    false,
  );
  assert.equal(
    badgeIsEntitled({appleEntitled: false, adminGranted: true}),
    true,
  );

  const afterApple = afterAppleRevocation({
    appleEntitled: true,
    googlePlayEntitled: true,
  });
  assert.equal(afterApple.appleEntitled, false);
  assert.equal(afterApple.googlePlayEntitled, true);

  const afterPlay = afterPlayRevocation({
    appleEntitled: true,
    googlePlayEntitled: true,
  });
  assert.equal(afterPlay.googlePlayEntitled, false);
  assert.equal(afterPlay.appleEntitled, true);
});
