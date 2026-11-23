const assert = require("node:assert/strict");
const {describe, it} = require("node:test");

const {
  isEventPaymentStartAllowed,
} = require("../lib/payments/eventPaymentPolicy.js");

describe("V1 event payment policy", () => {
  it("rejects every new event payment start", () => {
    assert.equal(isEventPaymentStartAllowed(), false);
  });
});
