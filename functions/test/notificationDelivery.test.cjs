const assert = require("node:assert/strict");
const test = require("node:test");

const {
  initialDeliveryStatus,
} = require("../lib/notifications/deliverUserNotification.js");
const {
  nextRetryDate,
  preferenceKeyForType,
} = require("../lib/notifications/notificationDelivery.js");

test("initial delivery status preserves retry outcomes", () => {
  assert.equal(initialDeliveryStatus(0, 2), "retry_scheduled");
  assert.equal(initialDeliveryStatus(1, 2), "partial_retry_scheduled");
  assert.equal(initialDeliveryStatus(1, 0), "delivered");
  assert.equal(initialDeliveryStatus(0, 0), "no_active_device");
});

test("applicant decisions use event preferences, not incoming applications", () => {
  assert.equal(preferenceKeyForType("application_received"), "basvurular");
  assert.equal(preferenceKeyForType("application_accepted"), "etkinlikler");
  assert.equal(preferenceKeyForType("application_rejected"), "etkinlikler");
});

test("retry schedule is bounded and uses increasing delays", () => {
  const now = new Date("2026-10-25T09:00:00.000Z");
  assert.equal(
    nextRetryDate(0, now)?.toISOString(),
    "2026-10-25T09:05:00.000Z",
  );
  assert.equal(
    nextRetryDate(1, now)?.toISOString(),
    "2026-10-25T09:15:00.000Z",
  );
  assert.equal(nextRetryDate(5, now), null);
});
