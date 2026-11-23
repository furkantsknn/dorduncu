const assert = require("node:assert/strict");
const test = require("node:test");

const {
  badgeRecordedPrice,
  isTargetBadgePrice,
  normalizePlayMoney,
  playMoneyKurus,
} = require("../lib/commercial/playCatalogPrice.js");

test("badge bookkeeping uses one explicit catalog amount projection", () => {
  assert.deepEqual(badgeRecordedPrice({
    usedPlusOffer: true,
    listPriceKurus: 49900,
    plusPriceKurus: 39900,
  }), {
    amountKurus: 39900,
    listPriceKurus: 49900,
    amountSource: "catalog_plus_offer_nominal",
  });
  assert.deepEqual(badgeRecordedPrice({
    usedPlusOffer: false,
    listPriceKurus: 49900,
    plusPriceKurus: undefined,
  }), {
    amountKurus: 49900,
    listPriceKurus: 49900,
    amountSource: "catalog_nominal",
  });
});

test("plus offer bookkeeping never invents a fallback price", () => {
  assert.throws(() => badgeRecordedPrice({
    usedPlusOffer: true,
    listPriceKurus: 49900,
    plusPriceKurus: undefined,
  }), /plusPriceKurus/);
});

test("string and numeric 499 normalize to the same target price", () => {
  const stringMoney = {currencyCode: "TRY", units: "499", nanos: 0};
  const numericMoney = {currencyCode: "TRY", units: 499, nanos: 0};
  assert.deepEqual(
    normalizePlayMoney(stringMoney),
    normalizePlayMoney(numericMoney)
  );
  assert.equal(isTargetBadgePrice(stringMoney), true);
  assert.equal(isTargetBadgePrice(numericMoney), true);
});

test("499.99 is not the exact target price", () => {
  assert.equal(isTargetBadgePrice({
    currencyCode: "TRY", units: "499", nanos: 990000000,
  }), false);
});

test("numeric-string nanos normalize without changing the value", () => {
  assert.deepEqual(
    normalizePlayMoney({currencyCode: "TRY", units: "499", nanos: "0"}),
    normalizePlayMoney({currencyCode: "TRY", units: 499, nanos: 0})
  );
});

test("protobuf-omitted zero nanos is normalized after required fields", () => {
  assert.equal(isTargetBadgePrice({currencyCode: "TRY", units: "499"}), true);
  assert.equal(normalizePlayMoney({currencyCode: "TRY", nanos: 0}), null);
  assert.equal(isTargetBadgePrice(undefined), false);
});

test("a different currency is not accepted", () => {
  assert.equal(isTargetBadgePrice({
    currencyCode: "USD", units: "499", nanos: 0,
  }), false);
});

test("Play Money is not changed by an assumed tax multiplier", () => {
  assert.equal(playMoneyKurus({
    currencyCode: "TRY", units: "415", nanos: 830000000,
  }), 41583);
  assert.equal(playMoneyKurus({
    currencyCode: "TRY", units: "499", nanos: 990000000,
  }), 49999);
});
