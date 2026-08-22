import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  FieldValue,
} from "firebase-admin/firestore";

import {firestore} from "../config/firebaseAdmin";
import {writeAuditLog} from "../audit/writeAuditLog";

export const requestAccountDeletion = onCall(
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

    const userSnapshot =
      await userReference.get();

    if (!userSnapshot.exists) {
      throw new HttpsError(
        "not-found",
        "Kullanıcı profili bulunamadı."
      );
    }

    const userData = userSnapshot.data() ?? {};

    if (
      userData.accountStatus === "deleted" ||
      userData.deletionRequestStatus === "completed"
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Hesap zaten silinmiş."
      );
    }

    const requestReference =
      firestore
        .collection("accountDeletionRequests")
        .doc(uid);

    const batch = firestore.batch();

    batch.set(
      userReference,
      {
        accountStatus: "deletionRequested",
        deletionRequestedAt:
          FieldValue.serverTimestamp(),
        deletionRequestStatus: "pending",
        activeSessionId:
          FieldValue.delete(),
        updatedAt:
          FieldValue.serverTimestamp(),
        guncellemeTarihi:
          FieldValue.serverTimestamp(),
      },
      {
        merge: true,
      }
    );

    batch.set(
      requestReference,
      {
        uid,
        phoneNumber:
          request.auth.token.phone_number ??
          userData.telefon ??
          "",
        status: "pending",
        requestedAt:
          FieldValue.serverTimestamp(),
        updatedAt:
          FieldValue.serverTimestamp(),
        source: "mobile_app",
      },
      {
        merge: true,
      }
    );

    await batch.commit();

    await writeAuditLog({
      action: "requestAccountDeletion",
      performedBy: uid,
      targetUid: uid,
      metadata: {
        source: "mobile_app",
      },
    });

    return {
      success: true,
      status: "pending",
    };
  }
);
