import {FieldValue} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/https";
import {adminAuth, firestore} from "../config/firebaseAdmin";
import {assertAdmin} from "../security/assertAdmin";
import {writeAuditLog} from "../audit/writeAuditLog";

interface UpdateUserStatusRequest {
  uid: string;
  disabled: boolean;
}

/**
 * Enables or disables a user account.
 */
export const updateUserStatus = onCall(async (request) => {
  assertAdmin(request);

  const data = request.data as Partial<UpdateUserStatusRequest>;
  const targetUid =
    typeof data.uid === "string" ? data.uid.trim() : "";

  if (!targetUid) {
    throw new HttpsError(
      "invalid-argument",
      "uid is required."
    );
  }

  if (typeof data.disabled !== "boolean") {
    throw new HttpsError(
      "invalid-argument",
      "disabled must be a boolean."
    );
  }

  if (targetUid === request.auth.uid && data.disabled) {
    throw new HttpsError(
      "failed-precondition",
      "Administrators cannot disable their own account."
    );
  }

  try {
    await adminAuth.getUser(targetUid);
  } catch {
    throw new HttpsError(
      "not-found",
      "The requested user does not exist."
    );
  }

  await adminAuth.updateUser(targetUid, {
    disabled: data.disabled,
  });

  if (data.disabled) {
    await adminAuth.revokeRefreshTokens(targetUid);
  }

  await firestore.collection("users").doc(targetUid).set(
    {
      disabled: data.disabled,
      statusUpdatedAt: FieldValue.serverTimestamp(),
      statusUpdatedBy: request.auth.uid,
    },
    {
      merge: true,
    }
  );

  await writeAuditLog({
    action: data.disabled ? "disableUser" : "enableUser",
    performedBy: request.auth.uid,
    targetUid,
    metadata: {
      disabled: data.disabled,
      refreshTokensRevoked: data.disabled,
    },
  });

  return {
    success: true,
    uid: targetUid,
    disabled: data.disabled,
  };
});
