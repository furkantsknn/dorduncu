/* eslint-disable max-len */
import {createHash} from "crypto";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";
import {logger} from "firebase-functions";

const REGION = "europe-west1";
const TOKEN_MAX_LENGTH = 4096;

/**
 * Registers the current device FCM token for the authenticated user.
 */
export const registerNotificationDevice = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const uid = request.auth?.uid;

    if (!uid) {
      throw new HttpsError(
        "unauthenticated",
        "Bu işlem için kullanıcı girişi gereklidir.",
      );
    }

    const token = readToken(request.data);
    const platform = readPlatform(request.data);
    const tokenHash = hashToken(token);
    const firestore = getFirestore();

    const duplicateSnapshot = await firestore
      .collectionGroup("notification_devices")
      .where("tokenHash", "==", tokenHash)
      .get();

    const batch = firestore.batch();

    for (const document of duplicateSnapshot.docs) {
      if (document.ref.parent.parent?.id !== uid) {
        batch.delete(document.ref);
      }
    }

    const deviceReference = firestore
      .collection("users")
      .doc(uid)
      .collection("notification_devices")
      .doc(tokenHash);

    batch.set(
      deviceReference,
      {
        token,
        tokenHash,
        platform,
        enabled: true,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        lastRegisteredAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    await batch.commit();

    logger.info("Notification device registered", {
      duplicateOwnerCount: duplicateSnapshot.docs.filter(
        (document) => document.ref.parent.parent?.id !== uid,
      ).length,
      platform,
    });

    return {
      success: true,
      tokenHash,
    };
  },
);

/**
 * Removes the current FCM token from the authenticated user.
 */
export const unregisterNotificationDevice = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const uid = request.auth?.uid;

    if (!uid) {
      throw new HttpsError(
        "unauthenticated",
        "Bu işlem için kullanıcı girişi gereklidir.",
      );
    }

    const token = readToken(request.data);
    const tokenHash = hashToken(token);

    await getFirestore()
      .collection("users")
      .doc(uid)
      .collection("notification_devices")
      .doc(tokenHash)
      .delete();

    return {
      success: true,
    };
  },
);

/**
 * Reads and validates the FCM token.
 *
 * @param {unknown} data Callable payload.
 * @return {string} Valid token.
 */
function readToken(data: unknown): string {
  if (data === null || typeof data !== "object") {
    throw new HttpsError(
      "invalid-argument",
      "Bildirim cihaz anahtarı gereklidir.",
    );
  }

  const token = String(
    (data as Record<string, unknown>).token ?? "",
  ).trim();

  if (!token || token.length > TOKEN_MAX_LENGTH) {
    throw new HttpsError(
      "invalid-argument",
      "Geçerli bir bildirim cihaz anahtarı gereklidir.",
    );
  }

  return token;
}

/**
 * Reads a conservative platform identifier.
 *
 * @param {unknown} data Callable payload.
 * @return {string} Platform name.
 */
function readPlatform(data: unknown): string {
  if (data === null || typeof data !== "object") {
    return "unknown";
  }

  const value = String(
    (data as Record<string, unknown>).platform ?? "unknown",
  ).trim().toLowerCase();

  const allowed = new Set([
    "android",
    "ios",
    "macos",
    "windows",
    "linux",
    "fuchsia",
    "web",
    "unknown",
  ]);

  return allowed.has(value) ? value : "unknown";
}

/**
 * Hashes a token for safe deterministic document ids.
 *
 * @param {string} token FCM token.
 * @return {string} SHA-256 token hash.
 */
function hashToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}
