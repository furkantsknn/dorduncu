/* eslint-disable require-jsdoc, valid-jsdoc */
import {
  onDocumentWritten,
} from "firebase-functions/v2/firestore";
import {
  FieldValue,
  Timestamp,
} from "firebase-admin/firestore";

import {firestore} from "../config/firebaseAdmin";

/**
 * Reads a trimmed string value from Firestore data.
 * @param data Firestore document data.
 * @param key Field name to read.
 * @return Trimmed string value or an empty string.
 */
function readString(
  data: Record<string, unknown>,
  key: string
): string {
  const value = data[key];
  return typeof value === "string" ?
    value.trim() :
    "";
}

/**
 * Reads a boolean value from Firestore data.
 * @param data Firestore document data.
 * @param key Field name to read.
 * @return True only when the stored value is true.
 */
function readBool(
  data: Record<string, unknown>,
  key: string
): boolean {
  return data[key] === true;
}

/**
 * Reads a finite number value from Firestore data.
 * @param data Firestore document data.
 * @param key Field name to read.
 * @return Finite numeric value or zero.
 */
function readNumber(
  data: Record<string, unknown>,
  key: string
): number {
  const value = data[key];
  return typeof value === "number" &&
    Number.isFinite(value) ?
    value :
    0;
}

/**
 * Reads and normalizes a string array from Firestore data.
 * @param data Firestore document data.
 * @param key Field name to read.
 * @return Normalized string array.
 */
function readStringArray(
  data: Record<string, unknown>,
  key: string
): string[] {
  const value = data[key];

  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .filter((item): item is string =>
      typeof item === "string"
    )
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
}

/**
 * Reads a map value from Firestore data.
 * @param data Firestore document data.
 * @param key Field name to read.
 * @return Map value or an empty map.
 */
function readMap(
  data: Record<string, unknown>,
  key: string
): Record<string, unknown> {
  const value = data[key];

  if (
    value !== null &&
    typeof value === "object" &&
    !Array.isArray(value)
  ) {
    return value as Record<string, unknown>;
  }

  return {};
}

/**
 * Reads a Firestore timestamp value when present.
 * @param data Firestore document data.
 * @param key Field name to read.
 * @return Firestore Timestamp or null.
 */
function readTimestamp(
  data: Record<string, unknown>,
  key: string
): Timestamp | null {
  const value = data[key];
  return value instanceof Timestamp ?
    value :
    null;
}

export const syncPublicProfile = onDocumentWritten(
  {
    document: "users/{uid}",
    region: "europe-west1",
  },
  async (event) => {
    const uid = event.params.uid;

    const publicProfileReference =
      firestore
        .collection("public_profiles")
        .doc(uid);

    const afterSnapshot = event.data?.after;

    if (!afterSnapshot?.exists) {
      await publicProfileReference.delete();
      return;
    }

    const data =
      afterSnapshot.data() as Record<string, unknown>;

    const activeCity =
      readString(data, "aktifSehir");

    const city =
      activeCity.length > 0 ?
        activeCity :
        readString(data, "sehir");

    const profileName =
      readString(data, "profilAdi");

    const firstName =
      readString(data, "ad");

    const lastName =
      readString(data, "soyad");

    const fallbackName =
      [firstName, lastName]
        .filter((item) => item.length > 0)
        .join(" ");

    const displayName =
      profileName.length > 0 ?
        profileName :
        fallbackName;

    const existingPublic =
      await publicProfileReference.get();
    const existingMarketBadges =
      existingPublic.data()?.marketBadges;

    const plusExpiresAt =
      readTimestamp(data, "plusExpiresAt");

    const plusActive =
      readBool(data, "plus") &&
      plusExpiresAt !== null &&
      plusExpiresAt.toMillis() > Date.now();

    await publicProfileReference.set(
      {
        uid,
        profilAdi:
          displayName.length > 0 ?
            displayName :
            "Kullanıcı",
        profilFotografi:
          readString(data, "profilFotografi"),
        avatarUrl:
          readString(data, "avatarUrl"),
        sehir: city,
        hakkimda:
          readString(data, "hakkimda"),
        puan:
          readNumber(data, "puan"),
        ratingCount:
          readNumber(data, "ratingCount"),
        completedEventCount:
          readNumber(data, "completedEventCount"),
        plus: plusActive,
        isPlus: plusActive,
        plusPlan:
          readString(data, "plusPlan"),
        plusExpiresAt,
        verified:
          readBool(data, "verified"),
        oyuncuRozeti:
          readBool(data, "oyuncuRozeti"),
        gameSkills:
          readMap(data, "gameSkills"),
        gameIds:
          readStringArray(data, "gameIds"),
        oyunlar:
          readStringArray(data, "oyunlar"),
        badges:
          readStringArray(data, "badges"),
        marketBadges: Array.isArray(existingMarketBadges) ?
          existingMarketBadges :
          [],
        updatedAt:
          FieldValue.serverTimestamp(),
      },
      {
        merge: false,
      }
    );
  }
);
