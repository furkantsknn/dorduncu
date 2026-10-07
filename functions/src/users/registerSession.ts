/* eslint-disable require-jsdoc */
import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";

import {
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";

const REGION = "europe-west1";

type SessionAction =
  "register" |
  "heartbeat" |
  "updateAppVersion";

interface SessionRequestData {
  action?: unknown;
  sessionId?: unknown;
  deviceId?: unknown;
  platform?: unknown;
  appVersion?: unknown;
}

export const registerSession = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Bu işlem için giriş yapmalısınız.",
      );
    }

    const data =
      request.data as SessionRequestData;

    const action =
      readRequiredString(
        data.action,
        "İşlem türü gereklidir.",
        40,
      ) as SessionAction;

    const sessionId =
      readRequiredString(
        data.sessionId,
        "Oturum kimliği gereklidir.",
        200,
      );

    if (
      action !== "register" &&
      action !== "heartbeat" &&
      action !== "updateAppVersion"
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Geçersiz oturum işlemi.",
      );
    }

    const uid = request.auth.uid;
    const firestore = getFirestore();

    const userReference =
      firestore.collection("users").doc(uid);

    const sessionReference =
      firestore.collection("sessions").doc(uid);

    if (action === "register") {
      const deviceId =
        readRequiredString(
          data.deviceId,
          "Cihaz kimliği gereklidir.",
          200,
        );

      const platform =
        readRequiredString(
          data.platform,
          "Platform bilgisi gereklidir.",
          50,
        );

      const appVersion =
        readRequiredString(
          data.appVersion,
          "Uygulama sürümü gereklidir.",
          50,
        );

      await firestore.runTransaction(
        async (transaction) => {
          const userSnapshot =
            await transaction.get(userReference);

          if (!userSnapshot.exists) {
            throw new HttpsError(
              "not-found",
              "Kullanıcı profili bulunamadı.",
            );
          }

          transaction.set(
            userReference,
            {
              activeSessionId: sessionId,
              lastSeenAt:
                FieldValue.serverTimestamp(),
              updatedAt:
                FieldValue.serverTimestamp(),
              guncellemeTarihi:
                FieldValue.serverTimestamp(),
            },
            {
              merge: true,
            },
          );

          transaction.set(
            sessionReference,
            {
              uid,
              sessionId,
              deviceId,
              platform,
              appVersion,
              createdAt:
                FieldValue.serverTimestamp(),
              lastSeenAt:
                FieldValue.serverTimestamp(),
            },
            {
              merge: false,
            },
          );
        },
      );

      return {
        success: true,
        action,
      };
    }

    await firestore.runTransaction(
      async (transaction) => {
        const [
          userSnapshot,
          sessionSnapshot,
        ] = await Promise.all([
          transaction.get(userReference),
          transaction.get(sessionReference),
        ]);

        if (!userSnapshot.exists) {
          throw new HttpsError(
            "not-found",
            "Kullanıcı profili bulunamadı.",
          );
        }

        if (!sessionSnapshot.exists) {
          throw new HttpsError(
            "failed-precondition",
            "Aktif oturum bulunamadı.",
          );
        }

        const userData =
          userSnapshot.data() ?? {};

        const sessionData =
          sessionSnapshot.data() ?? {};

        const activeSessionId =
          String(
            userData.activeSessionId ?? "",
          ).trim();

        const storedSessionId =
          String(
            sessionData.sessionId ?? "",
          ).trim();

        if (
          activeSessionId !== sessionId ||
          storedSessionId !== sessionId
        ) {
          throw new HttpsError(
            "failed-precondition",
            "Bu oturum artık aktif değil.",
          );
        }

        if (action === "heartbeat") {
          transaction.set(
            userReference,
            {
              lastSeenAt:
                FieldValue.serverTimestamp(),
            },
            {
              merge: true,
            },
          );

          transaction.set(
            sessionReference,
            {
              lastSeenAt:
                FieldValue.serverTimestamp(),
            },
            {
              merge: true,
            },
          );

          return;
        }

        const appVersion =
          readRequiredString(
            data.appVersion,
            "Uygulama sürümü gereklidir.",
            50,
          );

        transaction.set(
          userReference,
          {
            lastSeenAt:
              FieldValue.serverTimestamp(),
          },
          {
            merge: true,
          },
        );

        transaction.set(
          sessionReference,
          {
            appVersion,
            lastSeenAt:
              FieldValue.serverTimestamp(),
          },
          {
            merge: true,
          },
        );
      },
    );

    return {
      success: true,
      action,
    };
  },
);

function readRequiredString(
  value: unknown,
  message: string,
  maximumLength: number,
): string {
  if (typeof value !== "string") {
    throw new HttpsError(
      "invalid-argument",
      message,
    );
  }

  const normalized = value.trim();

  if (
    !normalized ||
    normalized.length > maximumLength
  ) {
    throw new HttpsError(
      "invalid-argument",
      message,
    );
  }

  return normalized;
}
