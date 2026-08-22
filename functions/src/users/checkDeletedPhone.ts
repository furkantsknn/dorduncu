import {createHash} from "crypto";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {getAuth} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";

export const checkDeletedPhone = onCall(
  {
    region: "europe-west1",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Bu işlem için giriş yapılmış olmalıdır.",
      );
    }

    const phoneNumber =
      request.auth.token.phone_number?.toString().trim() ?? "";

    if (!phoneNumber) {
      throw new HttpsError(
        "failed-precondition",
        "Telefon numarası doğrulanamadı.",
      );
    }

    const phoneHash = createHash("sha256")
      .update(phoneNumber)
      .digest("hex");

    const document = await getFirestore()
      .collection("deletedAccountPhones")
      .doc(phoneHash)
      .get();

    const blocked =
      document.exists &&
      document.data()?.blockedFromRegistration === true;

    if (blocked) {
      await getAuth().deleteUser(request.auth.uid);
    }

    return {
      blocked: blocked,
    };
  },
);
