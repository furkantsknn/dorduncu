import {assertCurrentAdminSession} from "../security/adminAuthorization";
import {
  HttpsError,
  onCall,
} from "firebase-functions/https";

import {
  adminAuth,
  firestore,
} from "../config/firebaseAdmin";
import {
  adminRoles,
  assertSuperAdmin,
  getAdminRole,
  UserRole,
} from "../security/adminAuthorization";
import {writeAuditLog} from "../audit/writeAuditLog";

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
    assertSuperAdmin(request);
    await assertCurrentAdminSession(request);

    const data =
      request.data as SetUserRoleRequest;

    if (!data.uid || typeof data.uid !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "uid is required.",
      );
    }

    const allowedRoles: UserRole[] = [
      "user",
      ...adminRoles,
    ];

    if (!allowedRoles.includes(data.role)) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid role.",
      );
    }

    const reason =
      typeof data.reason === "string" ?
        data.reason.trim() :
        "";

    if (reason.length < 3) {
      throw new HttpsError(
        "invalid-argument",
        "A reason is required.",
      );
    }

    const targetUser =
      await adminAuth.getUser(data.uid);

    const targetDocument = await firestore
      .collection("users")
      .doc(data.uid)
      .get();

    const targetData = targetDocument.data() ?? {};
    const existingClaims =
      targetUser.customClaims ?? {};

    const previousRole = normalizeRole(
      existingClaims.role,
      targetData.role,
      existingClaims.admin === true,
      existingClaims.moderator === true,
    );

    if (previousRole === data.role) {
      throw new HttpsError(
        "failed-precondition",
        "The selected role is already active.",
      );
    }

    if (
      request.auth.uid === data.uid &&
      data.role !== "super_admin"
    ) {
      throw new HttpsError(
        "failed-precondition",
        "You cannot remove your own super administrator role.",
      );
    }

    if (
      previousRole === "super_admin" &&
      data.role !== "super_admin"
    ) {
      const superAdmins = await firestore
        .collection("users")
        .where("role", "==", "super_admin")
        .get();

      const hasAnotherSuperAdmin =
        superAdmins.docs.some(
          (document) => document.id !== data.uid,
        );

      if (!hasAnotherSuperAdmin) {
        throw new HttpsError(
          "failed-precondition",
          "The last super administrator cannot be demoted.",
        );
      }
    }

    const isPanelRole =
      data.role !== "user";

    if (isPanelRole) {
      const hasPasswordProvider =
        targetUser.providerData.some(
          (provider) =>
            provider.providerId === "password",
        );

      if (
        !targetUser.email ||
        !targetUser.emailVerified ||
        !hasPasswordProvider
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Admin panel roles require a verified email/password account.",
        );
      }
    }

    const claims = {
      ...existingClaims,
      admin:
        data.role === "admin" ||
        data.role === "super_admin",
      adminPanel: isPanelRole,
      moderator:
        data.role === "moderator",
      role: data.role,
    };

    await adminAuth.setCustomUserClaims(
      data.uid,
      claims,
    );

    try {
      await firestore
        .collection("users")
        .doc(data.uid)
        .set(
          {
            role: data.role,
            admin:
              data.role === "admin" ||
              data.role === "super_admin",
            adminPanel: isPanelRole,
            roleUpdatedAt: new Date(),
            roleUpdatedBy: request.auth.uid,
            updatedAt: new Date(),
          },
          {
            merge: true,
          },
        );
    } catch (error) {
      await adminAuth.setCustomUserClaims(
        data.uid,
        existingClaims,
      );

      throw error;
    }

    await adminAuth.revokeRefreshTokens(
      data.uid,
    );

    await writeAuditLog({
      action: "setUserRole",
      targetUid: data.uid,
      performedBy: request.auth.uid,
      metadata: {
        previousRole,
        role: data.role,
        reason,
        performedByRole: getAdminRole(request),
        targetSessionsRevoked: true,
      },
    });

    return {
      success: true,
      uid: data.uid,
      previousRole,
      role: data.role,
      sessionsRevoked: true,
    };
  },
);

/**
 * Resolves a safe role from existing Auth/Firestore state.
 * @param {unknown} claimRole Role stored in custom claims.
 * @param {unknown} documentRole Role mirrored in Firestore.
 * @param {boolean} adminClaim Legacy admin claim.
 * @param {boolean} moderatorClaim Legacy moderator claim.
 * @return {UserRole} Normalized role.
 */
function normalizeRole(
  claimRole: unknown,
  documentRole: unknown,
  adminClaim: boolean,
  moderatorClaim: boolean,
): UserRole {
  const allowedRoles: UserRole[] = [
    "user",
    ...adminRoles,
  ];

  if (
    typeof claimRole === "string" &&
    allowedRoles.includes(claimRole as UserRole)
  ) {
    return claimRole as UserRole;
  }

  if (
    typeof documentRole === "string" &&
    allowedRoles.includes(documentRole as UserRole)
  ) {
    return documentRole as UserRole;
  }

  if (adminClaim) {
    return "admin";
  }

  if (moderatorClaim) {
    return "moderator";
  }

  return "user";
}
