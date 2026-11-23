const assert = require("node:assert/strict");
const test = require("node:test");

const {
  assertAdminPermission,
} = require("../lib/security/adminAuthorization.js");

test("normal user cannot manage badges", () => {
  assert.throws(
    () => assertAdminPermission({
      auth: {uid: "user", token: {role: "user"}},
    }, "content.manage"),
    (error) => error.code === "permission-denied",
  );
});

test("admin without content permission cannot manage badges", () => {
  assert.throws(
    () => assertAdminPermission({
      auth: {uid: "moderator", token: {role: "moderator"}},
    }, "content.manage"),
    (error) => error.code === "permission-denied",
  );
});

test("content manager is authorized by the existing claim policy", () => {
  assert.doesNotThrow(() => assertAdminPermission({
    auth: {uid: "manager", token: {role: "content_manager"}},
  }, "content.manage"));
});
