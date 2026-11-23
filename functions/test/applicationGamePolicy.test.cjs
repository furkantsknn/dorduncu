const assert = require("node:assert/strict");
const {describe, it} = require("node:test");
const {
  applicationGameSnapshot,
  normalizeSkillLevel,
} = require("../lib/events/applicationGamePolicy.js");

describe("application game policy", () => {
  it("requires exact okey ids", () => {
    const profile = {gameSkills: {okey_101: {gameId: "okey_101", level: 60}}};
    assert.equal(applicationGameSnapshot(profile, "okey"), null);
    assert.equal(applicationGameSnapshot(profile, "okey_101").level, 60);
  });
  it("supports legacy exact selections and safe unknown levels", () => {
    assert.equal(applicationGameSnapshot({oyunlar: ["Okey"]}, "okey").level, null);
    assert.equal(applicationGameSnapshot({oyunlar: ["101"]}, "okey"), null);
    assert.equal(normalizeSkillLevel(90), 90);
    assert.equal(normalizeSkillLevel(100), null);
  });
  it("requires an exact Paintball selection", () => {
    assert.deepEqual(
      applicationGameSnapshot(
        {gameSkills: {paintball: {gameId: "paintball", level: 90}}},
        "paintball",
      ),
      {gameId: "paintball", level: 90, levelKey: "expert"},
    );
    assert.equal(
      applicationGameSnapshot(
        {gameSkills: {paint_ball: {gameId: "paint_ball", level: 90}}},
        "paintball",
      ),
      null,
    );
  });
});
