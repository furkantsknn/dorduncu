import {HttpsError, onCall} from "firebase-functions/https";
import {adminAuth, firestore} from "../config/firebaseAdmin";
import {assertAdmin} from "../security/assertAdmin";
import {writeAuditLog} from "../audit/writeAuditLog";

type UserRole =
  | "user"
  | "moderator"
  | "admin"
  | "super_admin";

interface SetUserRoleRequest {
  uid: string;
  role: UserRole;
  reason?: string;
}

export const setUserRole = onCall(
  {
    region: "europe-west1",
    enforceAppCheck: true,
  },
  async (request) => {
    assertAdmin(request);

    const data = request.data as SetUserRoleRequest;

    if (!data.uid || typeof data.uid !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "uid is required."
      );
    }

    const allowedRoles: UserRole[] = [
      "user",
      "moderator",
      "admin",
      "super_admin",
    ];

    if (!allowedRoles.includes(data.role)) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid role."
      );
    }

    const reason =
      typeof data.reason === "string" ?
        data.reason.trim() :
        "";

    if (reason.length < 3) {
      throw new HttpsError(
        "invalid-argument",
        "A reason is required."
      );
    }

    if (
      request.auth.uid === data.uid &&
      data.role !== "admin" &&
      data.role !== "super_admin"
    ) {
      throw new HttpsError(
        "failed-precondition",
        "You cannot remove your own administrator permission."
      );
    }

    const targetUser = await adminAuth.getUser(data.uid);

    const existingClaims = targetUser.customClaims ?? {};

    const claims = {
      ...existingClaims,
      admin:
        data.role === "admin" ||
        data.role === "super_admin",
      moderator: data.role === "moderator",
      role: data.role,
    };

    await adminAuth.setCustomUserClaims(
      data.uid,
      claims
    );

    await firestore
      .collection("users")
      .doc(data.uid)
      .set(
        {
          role: data.role,
          admin:
            data.role === "admin" ||
            data.role === "super_admin",
          roleUpdatedAt: new Date(),
          roleUpdatedBy: request.auth.uid,
          updatedAt: new Date(),
        },
        {
          merge: true,
        }
      );

    await writeAuditLog({
      action: "setUserRole",
      targetUid: data.uid,
      performedBy: request.auth.uid,
      metadata: {
        role: data.role,
        reason,
      },
    });

    return {
      success: true,
      uid: data.uid,
      role: data.role,
    };
  }
);
