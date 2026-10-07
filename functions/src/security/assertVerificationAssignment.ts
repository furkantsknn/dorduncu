import {
  CallableRequest,
  HttpsError,
} from "firebase-functions/https";

import {
  assertAdminPermission,
  getAdminRole,
} from "./adminAuthorization";

/**
 * Ensures that the caller may access sensitive verification data.
 * The assigned verifier may access it, while a super admin can override.
 * @param {CallableRequest<T>} request Callable request.
 * @param {FirebaseFirestore.DocumentData} verificationData Request data.
 */
export function assertVerificationAssignment<T>(
  request: CallableRequest<T>,
  verificationData: FirebaseFirestore.DocumentData,
): asserts request is CallableRequest<T> & {
  auth: NonNullable<CallableRequest<T>["auth"]>;
} {
  assertAdminPermission(request, "verification.review");

  const assignedVerifierUid =
    verificationData.assignedVerifierUid
      ?.toString()
      .trim() ?? "";

  const isSuperAdmin =
    getAdminRole(request) ===
      "super_admin";

  if (
    !isSuperAdmin &&
    assignedVerifierUid !==
      request.auth.uid
  ) {
    throw new HttpsError(
      "permission-denied",
      assignedVerifierUid ?
        "Bu doğrulama başka bir admine atanmış." :
        "Önce doğrulama incelemesini üstlenmelisiniz.",
    );
  }
}
