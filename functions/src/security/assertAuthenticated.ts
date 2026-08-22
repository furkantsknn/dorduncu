import {HttpsError} from "firebase-functions/https";

interface AuthenticatedRequest {
  auth?: {
    uid: string;
  };
}

/**
 * Ensures that the caller is authenticated.
 * @param {AuthenticatedRequest} request Callable request.
 */
export function assertAuthenticated(
  request: AuthenticatedRequest
): asserts request is AuthenticatedRequest & {
  auth: {
    uid: string;
  };
} {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication is required."
    );
  }
}
