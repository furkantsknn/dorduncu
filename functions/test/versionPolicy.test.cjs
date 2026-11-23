const assert = require("node:assert/strict");
const test = require("node:test");
const {parseVersionPolicy, versionPolicyId} = require("../lib/versioning/versionPolicy.js");

const base = {
  platform: "android", target: "production", active: true,
  latestBuild: 31, minimumBuild: 30, latestVersion: "1.0.0",
  minimumVersion: "1.0.0", messageTr: "Güncelle", messageEn: "Update",
  messageDe: "Aktualisieren", storeVersionAvailable: true,
  storeUrl: "https://play.google.com/store/apps/details?id=com.dortapp.dort",
};

test("build numbers, not display versions, drive policy", () => {
  assert.equal(parseVersionPolicy(base).minimumBuild, 30);
  assert.equal(versionPolicyId("ios", "test"), "ios_test");
});

test("minimum cannot exceed latest", () => {
  assert.throws(() => parseVersionPolicy({...base, minimumBuild: 32}));
});

test("mandatory policy requires verified store availability", () => {
  assert.throws(() => parseVersionPolicy({...base, storeVersionAvailable: false}));
});

test("platform and distribution reject mismatched URLs", () => {
  assert.throws(() => parseVersionPolicy({...base, platform: "ios"}));
  assert.doesNotThrow(() => parseVersionPolicy({...base, platform: "ios", target: "test", storeUrl: "https://testflight.apple.com/join/example"}));
});
