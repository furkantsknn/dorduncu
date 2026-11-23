import assert from "node:assert/strict";
import test from "node:test";

import {
  evaluateEventSchedule,
  eventStartIsUnchanged,
} from "../src/events/eventSchedulePolicy";
import {soughtPlayerCountIsUnchanged} from "../src/events/plusPlayerLimit";
import {isPlusMembershipActive} from "../src/users/plusMembership";

const now = Date.parse("2026-10-08T21:05:00.000Z");
const laterToday = Date.parse("2026-10-08T21:30:00.000Z");
const tomorrow = Date.parse("2026-10-09T21:30:00.000Z");
const plusSeven = Date.parse("2026-10-16T09:00:00.000Z");
const plusEight = Date.parse("2026-10-17T09:00:00.000Z");

test("ücretsiz üyelik yarını reddeder", () => {
  assert.equal(
    evaluateEventSchedule(tomorrow, now, false),
    "free_not_today",
  );
});

test("aktif Plus bugünden 7 gün sonrasını kabul eder", () => {
  assert.equal(evaluateEventSchedule(plusSeven, now, true), "ok");
});

test("aktif Plus 7 ve 365 günden ileri tarihleri kabul eder", () => {
  assert.equal(evaluateEventSchedule(plusEight, now, true), "ok");
  assert.equal(
    evaluateEventSchedule(now + 500 * 24 * 60 * 60 * 1000, now, true),
    "ok",
  );
});

test("İstanbul gece yarısı yeni günü bugün sayar", () => {
  const beforeMidnight = Date.parse("2026-10-08T20:50:00.000Z");
  const afterMidnight = Date.parse("2026-10-08T21:20:00.000Z");

  assert.equal(
    evaluateEventSchedule(laterToday, now, false),
    "ok",
  );
  assert.equal(
    evaluateEventSchedule(afterMidnight, beforeMidnight, false),
    "free_not_today",
  );
});

test("süresi dolmuş Plus yarını ve 7 günü reddeder", () => {
  const plusActive = isPlusMembershipActive({
    plus: true,
    plusExpiresAt: new Date(now - 60 * 60 * 1000),
    plusSubscriptionExpiresAt: new Date(now - 60 * 60 * 1000),
    plusSubscriptionState: "SUBSCRIPTION_STATE_EXPIRED",
  }, now);

  assert.equal(plusActive, false);
  assert.equal(
    evaluateEventSchedule(tomorrow, now, plusActive),
    "free_not_today",
  );
  assert.equal(
    evaluateEventSchedule(plusSeven, now, plusActive),
    "free_not_today",
  );
});

test("tarih veya oyuncu değişmediyse yeni sınır uygulanmaz", () => {
  assert.equal(eventStartIsUnchanged(plusEight, plusEight), true);
  assert.equal(eventStartIsUnchanged(tomorrow, plusEight), false);
  assert.equal(soughtPlayerCountIsUnchanged(4, 4), true);
  assert.equal(soughtPlayerCountIsUnchanged(2, 1), false);
});
