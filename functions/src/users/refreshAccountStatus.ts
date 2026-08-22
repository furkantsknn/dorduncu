import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";

import {
  FieldValue,
  Timestamp,
} from "firebase-admin/firestore";

import {firestore} from "../config/firebaseAdmin";

export const refreshAccountStatus = onCall(
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

    const uid = request.auth.uid;

    const userReference =
      firestore.collection("users").doc(uid);

    await firestore.runTransaction(
      async (transaction) => {
        const snapshot =
          await transaction.get(userReference);

        if (!snapshot.exists) {
          throw new HttpsError(
            "not-found",
            "Kullanıcı profili bulunamadı."
          );
        }

        const data = snapshot.data() ?? {};

        const status =
          data.accountStatus?.toString().trim() ||
          data.hesapDurumu?.toString().trim() ||
          "active";

        if (status !== "suspended") {
          return;
        }

        const suspensionEndsAt =
          data.suspensionEndsAt;

        if (!(suspensionEndsAt instanceof Timestamp)) {
          return;
        }

        if (suspensionEndsAt.toMillis() > Date.now()) {
          return;
        }

        transaction.set(
          userReference,
          {
            hesapDurumu: "active",
            accountStatus: "active",
            accountStatusReason: "",
            suspensionDays: null,
            suspensionEndsAt: null,
            accountStatusUpdatedAt:
              FieldValue.serverTimestamp(),
            accountStatusUpdatedBy: "system",
            updatedAt:
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
    };
  }
);
