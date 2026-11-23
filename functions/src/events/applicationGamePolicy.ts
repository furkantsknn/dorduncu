/* eslint-disable max-len, require-jsdoc, valid-jsdoc */
import {getEventGame} from "./eventCatalog";

export interface ApplicationGameSnapshot {
  gameId: string;
  level: number | null;
  levelKey: "beginner" | "intermediate" | "expert" | null;
}

/** Resolves an exact game id and a safe, self-declared level snapshot. */
export function applicationGameSnapshot(
  profile: Record<string, unknown>,
  eventGameId: unknown,
): ApplicationGameSnapshot | null {
  const gameId = String(eventGameId ?? "").trim();
  if (!gameId) return null;

  const rawSkills = profile.gameSkills;
  if (!isRecord(rawSkills) || !Object.prototype.hasOwnProperty.call(rawSkills, gameId)) {
    if (!legacyProfileHasExactGame(profile, gameId)) return null;
    return {gameId, level: null, levelKey: null};
  }

  const rawSkill = rawSkills[gameId];
  const skill = isRecord(rawSkill) ? rawSkill : {};
  const storedGameId = String(skill.gameId ?? gameId).trim();
  if (storedGameId !== gameId) return null;

  const level = normalizeSkillLevel(skill.level ?? skill.seviye ?? skill.levelPercent);
  return {
    gameId,
    level,
    levelKey: level === 30 ? "beginner" : level === 60 ? "intermediate" : level === 90 ? "expert" : null,
  };
}

function legacyProfileHasExactGame(
  profile: Record<string, unknown>,
  gameId: string,
): boolean {
  if (Array.isArray(profile.gameIds) && profile.gameIds.some((item) => String(item).trim() === gameId)) {
    return true;
  }
  const game = getEventGame(gameId);
  if (!game || !Array.isArray(profile.oyunlar)) return false;
  const expected = normalizeLegacyName(game.name);
  return profile.oyunlar.some((item) => normalizeLegacyName(String(item)) === expected);
}

function normalizeLegacyName(value: string): string {
  return value
    .toLocaleLowerCase("tr-TR")
    .replace(/^[^\p{L}\p{N}]+/gu, "")
    .trim();
}

/** Maps known legacy values without promoting unknown values to expert. */
export function normalizeSkillLevel(value: unknown): number | null {
  const numeric = typeof value === "number" ? value : Number(String(value ?? "").replace("%", "").trim());
  if (!Number.isFinite(numeric)) return null;
  if (numeric === 30) return 30;
  if (numeric === 60) return 60;
  if (numeric === 90) return 90;
  return null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
