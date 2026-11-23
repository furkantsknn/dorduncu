import {
  CallableRequest,
  HttpsError,
} from "firebase-functions/https";
import {getAuth, UserRecord} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";

/** Rejects disabled, revoked or stale-role sessions before privileged I/O.
 * @param {CallableRequest<unknown>} request Authenticated callable request.
 * @return {Promise<void>} Resolves for the current Auth identity only.
 */
export async function assertCurrentAdminSession(
  request: CallableRequest<unknown>,
): Promise<void> {
  assertAdminPanelAccess(request);
  let user: UserRecord;
  try {
    user = await getAuth().getUser(request.auth.uid);
  } catch {
    throw new HttpsError("permission-denied", "Admin session unavailable.");
  }
  const profile = await getFirestore().collection("users")
    .doc(request.auth.uid).get();
  const blocked = !profile.exists || profile.get("disabled") === true ||
    ["suspended", "disabled", "blocked", "banned", "deleted",
      "deletionRequested", "deleting"]
      .includes(String(profile.get("accountStatus") ?? "")) ||
    ["pending", "processing", "failed", "completed"].includes(
      String(profile.get("deletionRequestStatus") ?? ""),
    );
  const roleChanged = profile.exists && profile.get("role") != null &&
    profile.get("role") !== getAdminRole(request);
  const current = {
    ...request,
    auth: {...request.auth, token: user.customClaims ?? {}},
  } as CallableRequest<unknown>;
  const validAfter = Date.parse(user.tokensValidAfterTime ?? "") / 1000;
  if (user.disabled || blocked || roleChanged ||
      getAdminRole(current) !== getAdminRole(request) ||
      (Number.isFinite(validAfter) &&
       Number(request.auth.token.auth_time ?? 0) < validAfter)) {
    throw new HttpsError(
      "permission-denied", "Admin session changed. Sign in again.",
    );
  }
}

export const adminRoles = [
  "moderator",
  "verification_officer",
  "support_officer",
  "finance_officer",
  "content_manager",
  "analyst",
  "admin",
  "super_admin",
] as const;

export type AdminRole =
  typeof adminRoles[number];

export type UserRole =
  | "user"
  | AdminRole;

export const adminPermissions = [
  "users.read",
  "users.moderate",
  "verification.review",
  "support.manage",
  "finance.manage",
  "events.moderate",
  "content.manage",
  "notifications.manage",
  "settings.manage",
  "audit.read",
  "reports.read",
  "roles.manage",
] as const;

export type AdminPermission =
  typeof adminPermissions[number];

const allPermissions =
  new Set<AdminPermission>(
    adminPermissions,
  );

const rolePermissions:
  Record<AdminRole, ReadonlySet<AdminPermission>> = {
    super_admin: allPermissions,

    // Legacy role. It stays operational during the A7 migration.
    // New staff assignments should use a scoped role.
    // Role assignment remains exclusive to super_admin.
    admin: new Set<AdminPermission>([
      "users.read",
      "users.moderate",
      "verification.review",
      "support.manage",
      "finance.manage",
      "events.moderate",
      "content.manage",
      "notifications.manage",
      "settings.manage",
      "audit.read",
      "reports.read",
    ]),

    moderator: new Set<AdminPermission>([
      "users.read",
      "users.moderate",
      "events.moderate",
      "reports.read",
    ]),

    verification_officer:
      new Set<AdminPermission>([
        "users.read",
        "verification.review",
      ]),

    support_officer:
      new Set<AdminPermission>([
        "users.read",
        "support.manage",
      ]),

    finance_officer:
      new Set<AdminPermission>([
        "users.read",
        "finance.manage",
        "reports.read",
      ]),

    content_manager:
      new Set<AdminPermission>([
        "content.manage",
        "notifications.manage",
      ]),

    analyst:
      new Set<AdminPermission>([
        "reports.read",
      ]),
  };

/**
 * Resolves the normalized application role from callable auth claims.
 * @param {CallableRequest<unknown>} request Callable request.
 * @return {UserRole} Normalized user role.
 */
function normalizeRole(
  request: CallableRequest<unknown>,
): UserRole {
  const token = request.auth?.token;

  const rawRole =
    token?.role?.toString().toLowerCase() ?? "";

  if (
    rawRole === "user" ||
    adminRoles.includes(rawRole as AdminRole)
  ) {
    return rawRole as UserRole;
  }

  // Compatibility for old tokens until every admin is migrated.
  if (token?.admin === true) {
    return "admin";
  }

  if (token?.moderator === true) {
    return "moderator";
  }

  return "user";
}

/**
 * Returns the normalized role for an authenticated callable request.
 * @param {CallableRequest<T>} request Callable request.
 * @return {UserRole} Normalized user role.
 */
export function getAdminRole<T>(
  request: CallableRequest<T>,
): UserRole {
  return normalizeRole(
    request as CallableRequest<unknown>,
  );
}

/**
 * Checks whether the caller has the requested admin permission.
 * @param {CallableRequest<T>} request Callable request.
 * @param {AdminPermission} permission Permission to check.
 * @return {boolean} True when the caller has the permission.
 */
export function hasAdminPermission<T>(
  request: CallableRequest<T>,
  permission: AdminPermission,
): boolean {
  if (!request.auth) {
    return false;
  }

  const role = getAdminRole(request);

  if (role === "user") {
    return false;
  }

  return rolePermissions[role].has(permission);
}

/**
 * Requires the caller to have access to the admin panel.
 * @param {CallableRequest<T>} request Callable request.
 * @return {void} Completes when access is allowed.
 */
export function assertAdminPanelAccess<T>(
  request: CallableRequest<T>,
): asserts request is CallableRequest<T> & {
  auth: NonNullable<CallableRequest<T>["auth"]>;
} {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication is required.",
    );
  }

  if (getAdminRole(request) === "user") {
    throw new HttpsError(
      "permission-denied",
      "Admin panel permission is required.",
    );
  }
}

/**
 * Requires the caller to have a specific admin permission.
 * @param {CallableRequest<T>} request Callable request.
 * @param {AdminPermission} permission Required permission.
 * @return {void} Completes when permission is allowed.
 */
export function assertAdminPermission<T>(
  request: CallableRequest<T>,
  permission: AdminPermission,
): asserts request is CallableRequest<T> & {
  auth: NonNullable<CallableRequest<T>["auth"]>;
} {
  assertAdminPanelAccess(request);

  if (!hasAdminPermission(request, permission)) {
    throw new HttpsError(
      "permission-denied",
      "You do not have permission for this operation.",
    );
  }
}

/**
 * Requires the caller to be a super administrator.
 * @param {CallableRequest<T>} request Callable request.
 * @return {void} Completes when the caller is a super administrator.
 */
export function assertSuperAdmin<T>(
  request: CallableRequest<T>,
): asserts request is CallableRequest<T> & {
  auth: NonNullable<CallableRequest<T>["auth"]>;
} {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication is required.",
    );
  }

  if (getAdminRole(request) !== "super_admin") {
    throw new HttpsError(
      "permission-denied",
      "Super administrator permission is required.",
    );
  }
}
