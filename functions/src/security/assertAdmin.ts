import {
  CallableRequest,
  HttpsError,
} from "firebase-functions/https";

/**
 * Ensures that the caller is an authenticated administrator.
 * @param {CallableRequest<T>} request Callable request.
 */
export function assertAdmin<T>(
  request: CallableRequest<T>
): asserts request is CallableRequest<T> & {
  auth: NonNullable<CallableRequest<T>["auth"]>;
} {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication is required."
    );
  }

  if (request.auth.token.admin !== true) {
    throw new HttpsError(
      "permission-denied",
      "Administrator permission is required."
    );
  }
}
