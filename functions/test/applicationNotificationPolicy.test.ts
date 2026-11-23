import assert from "node:assert/strict";
import test from "node:test";

import {
  applicationNotificationId,
} from "../src/notifications/applicationNotificationPolicy.ts";

test("başvuru ve kabul doğru olay/oyuncu için kararlı kimlik üretir", () => {
  assert.equal(
    applicationNotificationId(
      "application_received", "event-1", "player-1", "attempt-1",
    ),
    "application_received_event-1_player-1_attempt-1",
  );
  assert.equal(
    applicationNotificationId(
      "application_accepted", "event-1", "player-1", "attempt-1",
    ),
    "application_accepted_event-1_player-1_attempt-1",
  );
});

test("aynı olay retry edildiğinde ikinci bildirim kimliği oluşmaz", () => {
  const first = applicationNotificationId(
    "application_accepted",
    "event-1",
    "player-1",
    "attempt-1",
  );
  const retry = applicationNotificationId(
    "application_accepted",
    "event-1",
    "player-1",
    "attempt-1",
  );
  assert.equal(first, retry);
  assert.notEqual(
    first,
    applicationNotificationId(
      "application_accepted",
      "event-1",
      "player-2",
      "attempt-1",
    ),
  );
});

test("reddedilip yeniden yapılan başvuru yeni bildirim kimliği üretir", () => {
  const firstAttempt = applicationNotificationId(
    "application_received", "event-1", "player-1", "attempt-1",
  );
  const secondAttempt = applicationNotificationId(
    "application_received", "event-1", "player-1", "attempt-2",
  );
  assert.notEqual(firstAttempt, secondAttempt);
});
