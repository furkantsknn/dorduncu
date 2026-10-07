import {HttpsError} from "firebase-functions/v2/https";

import {firestore} from "../config/firebaseAdmin";

/**
 * Allows the pre-Google-Play digital-wallet purchase path only when an
 * explicit server-side migration flag is enabled.
 *
 * Missing setting = disabled.
 *
 * @return {Promise<void>} Completion promise.
 */
export async function assertLegacyDigitalWalletPurchaseAllowed():
Promise<void> {
  const settingsSnapshot = await firestore
    .collection("system_settings")
    .doc("global")
    .get();

  const enabled =
    settingsSnapshot.data()
      ?.legacyDigitalWalletPurchasesEnabled === true;

  if (!enabled) {
    throw new HttpsError(
      "failed-precondition",
      "Dijital ürün satın alımları Google Play üzerinden yapılır.",
    );
  }
}
