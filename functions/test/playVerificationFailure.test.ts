import assert from "node:assert/strict";
import test from "node:test";

import {describePlayFailure} from "../src/commercial/googlePlayVerification.ts";

test("401 kapsam hatası kullanıcıya aynı mesajı verir ve gövdeyi loglamaz", () => {
  const failure = describePlayFailure(
    401,
    JSON.stringify({
      error: {
        status: "UNAUTHENTICATED",
        message: "Request had insufficient authentication scopes.",
      },
      purchaseToken: "raw-play-token-should-not-appear",
    }),
  );

  assert.equal(
    failure.userMessage,
    "Satın alma doğrulanamadı. Tekrar kontrol et.",
  );
  assert.match(failure.logSummary, /401 UNAUTHENTICATED/);
  assert.match(failure.logSummary, /insufficient authentication scopes/);
  assert.equal(failure.logSummary.includes("raw-play-token"), false);
});

test("yetki reddi kullanıcıya teknik nedeni göstermez", () => {
  const failure = describePlayFailure(
    401,
    JSON.stringify({
      error: {
        message: "The current user has insufficient permissions " +
          "to perform the requested operation.",
      },
    }),
  );

  assert.equal(
    failure.userMessage,
    "Satın alma doğrulanamadı. Tekrar kontrol et.",
  );
  assert.match(failure.logSummary, /insufficient permissions/);
  assert.equal(failure.userMessage.includes("insufficient"), false);
});

test("okunamayan Play gövdesinde yalnız durum kodu kalır", () => {
  const failure = describePlayFailure(
    401,
    "token=abcdefghijklmnopqrstuvwxyz012345",
  );

  assert.equal(failure.logSummary, "401");
});

test("404 satın alma kaydı mesajına düşer", () => {
  const failure = describePlayFailure(
    404,
    JSON.stringify({
      error: {status: "NOT_FOUND", message: "not found"},
    }),
  );

  assert.equal(
    failure.userMessage,
    "Google Play satın alma kaydı doğrulanamadı.",
  );
});
