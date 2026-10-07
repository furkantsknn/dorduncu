/* eslint-disable require-jsdoc */
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {getFirestore} from "firebase-admin/firestore";

const REGION = "europe-west1";

export const cancelFriendRequest = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const currentUserId = request.auth?.uid;

    if (!currentUserId) {
      throw new HttpsError(
        "unauthenticated",
        "Bu işlem için kullanıcı girişi gereklidir.",
      );
    }

    const requestId = readRequiredString(
      request.data,
      "requestId",
      "Arkadaşlık isteği kimliği gereklidir.",
    );

    const firestore = getFirestore();

    const requestReference =
      firestore.collection("friend_requests").doc(requestId);

    await firestore.runTransaction(
      async (transaction) => {
        const requestSnapshot =
          await transaction.get(requestReference);

        if (!requestSnapshot.exists) {
          throw new HttpsError(
            "not-found",
            "Arkadaşlık isteği bulunamadı.",
          );
        }

        const data = requestSnapshot.data() ?? {};

        const senderId =
          String(data.senderId ?? "").trim();

        const status =
          String(data.status ?? "").trim().toLowerCase();

        if (senderId !== currentUserId) {
          throw new HttpsError(
            "permission-denied",
            "Bu arkadaşlık isteğini iptal etme yetkiniz yok.",
          );
        }

        if (status !== "pending") {
          throw new HttpsError(
            "failed-precondition",
            "Bu arkadaşlık isteği artık beklemede değil.",
          );
        }

        transaction.delete(requestReference);
      },
    );

    return {
      success: true,
      requestId,
    };
  },
);

function readRequiredString(
  data: unknown,
  key: string,
  errorMessage: string,
): string {
  if (data === null || typeof data !== "object") {
    throw new HttpsError(
      "invalid-argument",
      errorMessage,
    );
  }

  const value = String(
    (data as Record<string, unknown>)[key] ?? "",
  ).trim();

  if (!value) {
    throw new HttpsError(
      "invalid-argument",
      errorMessage,
    );
  }

  return value;
}
