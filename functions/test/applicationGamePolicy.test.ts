import {strict as assert} from "node:assert";
import {describe, it} from "node:test";
import {applicationGameSnapshot, normalizeSkillLevel} from "../src/events/applicationGamePolicy";

describe("application game policy", () => {
  it("requires the exact game id", () => {
    const profile = {gameSkills: {okey_101: {gameId: "okey_101", level: 60}}};
    assert.equal(applicationGameSnapshot(profile, "okey"), null);
    assert.deepEqual(applicationGameSnapshot(profile, "okey_101"), {
      gameId: "okey_101", level: 60, levelKey: "intermediate",
    });
  });

  it("does not promote unknown legacy values", () => {
    assert.equal(normalizeSkillLevel(30), 30);
    assert.equal(normalizeSkillLevel("60"), 60);
    assert.equal(normalizeSkillLevel("%90"), 90);
    assert.equal(normalizeSkillLevel(100), null);
    assert.equal(normalizeSkillLevel("İleri"), null);
  });

  it("keeps a selected game with unspecified experience", () => {
    assert.deepEqual(applicationGameSnapshot({gameSkills: {okey: {gameId: "okey"}}}, "okey"), {
      gameId: "okey", level: null, levelKey: null,
    });
  });

  it("supports legacy selections without confusing Okey and 101", () => {
    assert.deepEqual(applicationGameSnapshot({oyunlar: ["Okey"]}, "okey"), {
      gameId: "okey", level: null, levelKey: null,
    });
    assert.equal(applicationGameSnapshot({oyunlar: ["101"]}, "okey"), null);
    assert.deepEqual(applicationGameSnapshot({gameIds: ["okey_101"]}, "okey_101"), {
      gameId: "okey_101", level: null, levelKey: null,
    });
  });

  it("requires an exact Paintball selection and snapshots its level", () => {
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
