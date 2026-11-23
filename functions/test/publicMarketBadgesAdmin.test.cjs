const assert = require("node:assert/strict");
const test = require("node:test");

const {
  projectPublicMarketBadges,
} = require("../lib/users/publicMarketBadges.js");

const load = async () => ({
  title: "Okey Badge",
  gameId: "okey",
  gameName: "Okey",
  emoji: "badge",
  imageUrl: "https://example.test/okey.png",
});

test("admin block suppresses the public badge after Play restore", async () => {
  const result = await projectPublicMarketBadges([{
    id: "okey",
    data: {googlePlayEntitled: true, adminBlocked: true},
  }], load);
  assert.deepEqual(result, []);
});

test("independent admin grant remains after Play refund", async () => {
  const result = await projectPublicMarketBadges([{
    id: "okey",
    data: {googlePlayEntitled: false, adminGranted: true},
  }], load);
  assert.equal(result.length, 1);
});
