import assert from "node:assert/strict";
import test from "node:test";

import {isPlusMembershipActive} from "../src/users/plusMembership";
import {evaluateSoughtPlayerCount} from "../src/events/plusPlayerLimit";

const hour = 60 * 60 * 1000;

test("ücretsiz hesap 1 aranan oyuncuyu kabul eder", () => {
  const plusActive = isPlusMembershipActive({});

  assert.equal(plusActive, false);
  assert.equal(evaluateSoughtPlayerCount(1, plusActive), "ok");
});

test("ücretsiz hesap 2, 3 ve 4 aranan oyuncuyu reddeder", () => {
  const plusActive = isPlusMembershipActive({plus: false});

  for (const count of [2, 3, 4]) {
    assert.equal(
      evaluateSoughtPlayerCount(count, plusActive),
      "plus_required",
    );
  }
});

test("aktif Plus pozitif tam sayı oyuncuları üst sınır olmadan kabul eder", () => {
  const plusActive = isPlusMembershipActive({
    plus: true,
    plusSubscriptionExpiresAt: new Date(Date.now() + 24 * hour),
    plusSubscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
  });

  assert.equal(plusActive, true);
  for (const count of [1, 2, 3, 4, 5, 50, 5000]) {
    assert.equal(evaluateSoughtPlayerCount(count, plusActive), "ok");
  }
});

test("geçersiz oyuncu sayıları reddedilir", () => {
  for (const count of [0, -1, 1.5, Number.POSITIVE_INFINITY]) {
    assert.equal(evaluateSoughtPlayerCount(count, true), "invalid_range");
  }
});

test("süresi dolmuş Plus ek oyuncu hakkını kaybeder", () => {
  const plusActive = isPlusMembershipActive({
    plus: true,
    isPlus: true,
    plusExpiresAt: new Date(Date.now() - hour),
    plusSubscriptionExpiresAt: new Date(Date.now() - hour),
    plusSubscriptionState: "SUBSCRIPTION_STATE_EXPIRED",
  });

  assert.equal(plusActive, false);
  assert.equal(evaluateSoughtPlayerCount(1, plusActive), "ok");
  assert.equal(evaluateSoughtPlayerCount(2, plusActive), "plus_required");
});

test("explicit admin grant is active without a fake expiry", () => {
  assert.equal(isPlusMembershipActive({plusAdminGranted: true}), true);
});

test("admin role alone does not grant Plus", () => {
  assert.equal(isPlusMembershipActive({role: "super_admin", admin: true}), false);
});

test("admin grant removal preserves a valid Play subscription", () => {
  assert.equal(isPlusMembershipActive({
    plusAdminGranted: false,
    plus: true,
    plusSubscriptionExpiresAt: new Date(Date.now() + 24 * hour),
    plusSubscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
  }), true);
});

test("admin Plus'ı kapattığında gelecek tarih ek hak vermez", () => {
  const plusActive = isPlusMembershipActive({
    plus: false,
    isPlus: false,
    plusExpiresAt: new Date(Date.now() + 24 * hour),
    plusSubscriptionExpiresAt: new Date(Date.now() + 24 * hour),
    plusSubscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
  });

  assert.equal(plusActive, false);
  assert.equal(evaluateSoughtPlayerCount(2, plusActive), "plus_required");
});
