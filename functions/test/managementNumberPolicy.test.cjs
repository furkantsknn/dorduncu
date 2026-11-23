const test = require("node:test");
const assert = require("node:assert/strict");
const {
  formatSupportNumber,
  formatUserManagementNumber,
} = require("../lib/admin/managementNumberPolicy.js");
const {
  assertV1WalletMutationAllowed,
} = require("../lib/policy/v1WalletPolicy.js");

test("user management numbers are stable-width and non-PII", () => {
  assert.equal(formatUserManagementNumber(123), "U-000123");
});

test("support numbering isolates years", () => {
  assert.equal(formatSupportNumber(2026, 123), "DST-2026-000123");
  assert.equal(formatSupportNumber(2027, 1), "DST-2027-000001");
});

test("all legacy wallet mutations fail closed", () => {
  assert.throws(assertV1WalletMutationAllowed, (error) =>
    error.code === "failed-precondition");
});
