import {HttpsError} from "firebase-functions/v2/https";

/** V1 deliberately has no mutable wallet or withdrawal surface. */
export function assertV1WalletMutationAllowed(): never {
  throw new HttpsError(
    "failed-precondition",
    "V1'de cüzdan ve bakiye işlemleri kullanılamaz.",
  );
}
