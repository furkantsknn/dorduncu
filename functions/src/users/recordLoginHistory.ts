import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";

import {
  FieldValue,
  Timestamp,
} from "firebase-admin/firestore";

import {firestore} from "../config/firebaseAdmin";

interface RecordLoginHistoryRequest {
  sessionId?: unknown;
  deviceId?: unknown;
  platform?: unknown;
  appVersion?: unknown;
}

const MIN_INTERVAL_MS = 10 * 1000;

export const recordLoginHistory = onCall(
  {
    region: "europe-west1",
    enforceAppCheck: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Bu işlem için giriş yapmalısınız."
      );
    }

    const data =
      request.data as RecordLoginHistoryRequest;

    const sessionId =
      typeof data.sessionId === "string" ?
        data.sessionId.trim() :
        "";

    const deviceId =
      typeof data.deviceId === "string" ?
        data.deviceId.trim() :
        "";

    const platform =
      typeof data.platform === "string" ?
        data.platform.trim() :
        "";

    const appVersion =
      typeof data.appVersion === "string" ?
        data.appVersion.trim() :
        "";

    if (!sessionId || !deviceId || !platform) {
      throw new HttpsError(
        "invalid-argument",
        "Oturum bilgileri eksik."
      );
    }

    if (
      sessionId.length > 200 ||
      deviceId.length > 200 ||
      platform.length > 50 ||
      appVersion.length > 50
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Oturum bilgileri geçersiz."
      );
    }

    const uid = request.auth.uid;

    const userReference =
      firestore.collection("users").doc(uid);

    const logReference =
      firestore.collection("login_history").doc();

    let skipped = false;

    await firestore.runTransaction(
      async (transaction) => {
        const userSnapshot =
          await transaction.get(userReference);

        if (!userSnapshot.exists) {
          throw new HttpsError(
            "not-found",
            "Kullanıcı profili bulunamadı."
          );
        }

        const userData = userSnapshot.data() ?? {};
        const lastLoginHistoryAt =
          userData.lastLoginHistoryAt;

        if (lastLoginHistoryAt instanceof Timestamp) {
          const elapsed =
            Date.now() - lastLoginHistoryAt.toMillis();

          if (elapsed >= 0 && elapsed < MIN_INTERVAL_MS) {
            skipped = true;
            return;
          }
        }

        transaction.set(
          logReference,
          {
            uid,
            phoneNumber:
              request.auth?.token.phone_number ??
              userData.telefon?.toString() ??
              "",
            sessionId,
            deviceId,
            platform,
            appVersion,
            createdAt:
              FieldValue.serverTimestamp(),
          }
        );

        transaction.set(
          userReference,
          {
            lastLoginHistoryAt:
              FieldValue.serverTimestamp(),
          },
          {
            merge: true,
          }
        );
      }
    );

    return {
      success: true,
      skipped,
    };
  }
);
