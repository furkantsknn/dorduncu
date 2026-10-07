/* eslint-disable require-jsdoc */
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {getFirestore} from "firebase-admin/firestore";

const REGION = "europe-west1";

export const removeFriend = onCall(
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

    const targetUserId = readRequiredString(
      request.data,
      "targetUserId",
      "Arkadaş kullanıcı kimliği gereklidir.",
    );

    if (targetUserId === currentUserId) {
      throw new HttpsError(
        "failed-precondition",
        "Kendinizi arkadaş listenizden çıkaramazsınız.",
      );
    }

    const firestore = getFirestore();

    const currentFriendReference =
      firestore
        .collection("users")
        .doc(currentUserId)
        .collection("friends")
        .doc(targetUserId);

    const targetFriendReference =
      firestore
        .collection("users")
        .doc(targetUserId)
        .collection("friends")
        .doc(currentUserId);

    await firestore.runTransaction(
      async (transaction) => {
        const currentFriendSnapshot =
          await transaction.get(currentFriendReference);

        const targetFriendSnapshot =
          await transaction.get(targetFriendReference);

        if (
          !currentFriendSnapshot.exists &&
          !targetFriendSnapshot.exists
        ) {
          throw new HttpsError(
            "not-found",
            "Arkadaşlık kaydı bulunamadı.",
          );
        }

        transaction.delete(currentFriendReference);
        transaction.delete(targetFriendReference);
      },
    );

    return {
      success: true,
      targetUserId,
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
