import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";

import {
  FieldValue,
} from "firebase-admin/firestore";

import {firestore} from "../config/firebaseAdmin";

interface RecordLoginHistoryRequest {
  sessionId?: unknown;
  deviceId?: unknown;
  platform?: unknown;
  appVersion?: unknown;
}

export const recordLoginHistory = onCall(
  {
    region: "europe-west1",
    enforceAppCheck: false,
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

    const uid = request.auth.uid;

    const userSnapshot =
      await firestore.collection("users").doc(uid).get();

    if (!userSnapshot.exists) {
      throw new HttpsError(
        "not-found",
        "Kullanıcı profili bulunamadı."
      );
    }

    const userData = userSnapshot.data() ?? {};

    await firestore.collection("login_history").add({
      uid,
      phoneNumber:
        userData.telefon?.toString() ?? "",
      sessionId,
      deviceId,
      platform,
      appVersion,
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      success: true,
    };
  }
);
