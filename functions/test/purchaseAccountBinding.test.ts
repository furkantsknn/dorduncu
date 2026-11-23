import assert from "node:assert/strict";
import test from "node:test";

import {
  assertPurchaseAccount,
  purchaseAccountMatches,
} from "../src/commercial/purchaseAccountBinding.ts";

test("hesap kimliği olmayan eski satın alma kabul edilir", () => {
  assert.equal(purchaseAccountMatches(null, "user-a"), true);
  assert.equal(purchaseAccountMatches("  ", "user-a"), true);
});

test("aynı kullanıcıya bağlı satın alma kabul edilir", () => {
  assert.equal(purchaseAccountMatches("user-a", "user-a"), true);
  assert.doesNotThrow(() => assertPurchaseAccount("user-a", "user-a"));
});

test("başka kullanıcıya bağlı satın alma reddedilir", () => {
  assert.equal(purchaseAccountMatches("user-a", "user-b"), false);
  assert.throws(
    () => assertPurchaseAccount("user-a", "user-b"),
    (error: unknown) =>
      (error as {code?: string}).code === "permission-denied",
  );
});
