/* eslint-disable max-len, require-jsdoc, valid-jsdoc */
import {HttpsError} from "firebase-functions/v2/https";

export const versionPlatforms = ["android", "ios"] as const;
export const versionTargets = ["test", "production"] as const;
export type VersionPlatform = typeof versionPlatforms[number];
export type VersionTarget = typeof versionTargets[number];

export interface VersionPolicy {
  platform: VersionPlatform;
  target: VersionTarget;
  active: boolean;
  latestBuild: number;
  minimumBuild: number;
  latestVersion: string;
  minimumVersion: string;
  messageTr: string;
  messageEn: string;
  messageDe: string;
  storeUrl: string;
  storeVersionAvailable: boolean;
}

/** Parses and validates an admin supplied version policy. */
export function parseVersionPolicy(data: unknown): VersionPolicy {
  if (!isRecord(data)) {
    throw invalid("Sürüm politikası gereklidir.");
  }
  const platform = enumValue(data.platform, versionPlatforms, "Platform geçersiz.");
  const target = enumValue(data.target, versionTargets, "Dağıtım hedefi geçersiz.");
  const latestBuild = positiveInteger(data.latestBuild, "Güncel build numarası geçersiz.");
  const minimumBuild = positiveInteger(data.minimumBuild, "Minimum build numarası geçersiz.");
  if (minimumBuild > latestBuild) {
    throw invalid("Minimum build güncel build'den büyük olamaz.");
  }
  const storeVersionAvailable = bool(data.storeVersionAvailable, "Mağaza doğrulaması geçersiz.");
  const active = bool(data.active, "Etkinlik değeri geçersiz.");
  const storeUrl = safeStoreUrl(platform, target, text(data.storeUrl, 1000));
  if (active && minimumBuild > 0 && (!storeVersionAvailable || !storeUrl)) {
    throw invalid("Zorunlu sürüm için mağaza erişilebilirliği ve bağlantısı doğrulanmalıdır.");
  }
  return {
    platform,
    target,
    active,
    latestBuild,
    minimumBuild,
    latestVersion: text(data.latestVersion, 40),
    minimumVersion: text(data.minimumVersion, 40),
    messageTr: text(data.messageTr, 500),
    messageEn: text(data.messageEn, 500),
    messageDe: text(data.messageDe, 500),
    storeUrl,
    storeVersionAvailable,
  };
}

export function versionPolicyId(platform: string, target: string): string {
  return `${platform}_${target}`;
}

function safeStoreUrl(platform: VersionPlatform, target: VersionTarget, value: string): string {
  if (!value) return "";
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw invalid("Mağaza bağlantısı geçersiz.");
  }
  const host = url.hostname.toLowerCase();
  const valid = platform === "android" ?
    url.protocol === "https:" && host === "play.google.com" :
    target === "test" ?
      (url.protocol === "https:" && host === "testflight.apple.com") :
      (url.protocol === "https:" && host === "apps.apple.com");
  if (!valid) throw invalid("Mağaza bağlantısı platform ve hedefle uyuşmuyor.");
  return url.toString();
}

function positiveInteger(value: unknown, message: string): number {
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < 0) throw invalid(message);
  return parsed;
}

function bool(value: unknown, message: string): boolean {
  if (typeof value !== "boolean") throw invalid(message);
  return value;
}

function text(value: unknown, max: number): string {
  if (value == null) return "";
  if (typeof value !== "string") throw invalid("Metin değeri geçersiz.");
  const result = value.trim();
  if (result.length > max) throw invalid("Metin değeri çok uzun.");
  return result;
}

function enumValue<T extends string>(value: unknown, values: readonly T[], message: string): T {
  const normalized = String(value ?? "").trim().toLowerCase() as T;
  if (!values.includes(normalized)) throw invalid(message);
  return normalized;
}

function invalid(message: string): HttpsError {
  return new HttpsError("invalid-argument", message);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
