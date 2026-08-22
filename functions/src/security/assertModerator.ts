import {HttpsError} from "firebase-functions/https";

interface ModeratorRequest {
  auth?: {
    uid: string;
    token: {
      admin?: boolean;
      moderator?: boolean;
    };
  };
}

/**
 * Ensures that the caller is an administrator or moderator.
 * @param {ModeratorRequest} request Callable request.
 */
export function assertModerator(request: ModeratorRequest): void {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication is required."
    );
  }

  const isAdmin = request.auth.token.admin === true;
  const isModerator = request.auth.token.moderator === true;

  if (!isAdmin && !isModerator) {
    throw new HttpsError(
      "permission-denied",
      "Moderator permission is required."
    );
  }
}
