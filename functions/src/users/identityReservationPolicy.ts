export interface IdentityReservationKey {
  exists: boolean;
  uid: string;
  status: string;
  hasApprovedAt: boolean;
  submissionId: string;
}

export interface IdentityReservationRequest {
  uid: string;
  status: string;
  submissionId: string;
}

export interface IdentityReleasePlan {
  release: boolean;
  reason: string;
}

const TERMINAL_RELEASE_STATUSES = new Set([
  "expired",
  "rejected",
]);

/**
 * Reads a stored string field.
 * @param {unknown} value Raw field value.
 * @return {string} Trimmed string, or empty.
 */
function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/**
 * Maps a stored identity-key document into the release decision.
 * @param {Record<string, unknown>|undefined} data Stored fields.
 * @param {boolean} exists Whether the document exists.
 * @return {IdentityReservationKey} Key state.
 */
export function identityKeyFromData(
  data: Record<string, unknown> | undefined,
  exists: boolean,
): IdentityReservationKey {
  if (!exists || !data) {
    return {
      exists: false,
      uid: "",
      status: "",
      hasApprovedAt: false,
      submissionId: "",
    };
  }

  return {
    exists: true,
    uid: text(data.uid),
    status: text(data.status),
    hasApprovedAt: data.approvedAt != null,
    submissionId: text(data.submissionId),
  };
}

/**
 * A verified or approved profile still owns the identity.
 * @param {Record<string, unknown>|undefined} data User profile.
 * @return {boolean} Whether the owner is approved.
 */
export function ownerApprovedFromUser(
  data: Record<string, unknown> | undefined,
): boolean {
  if (!data) {
    return false;
  }

  return data.verified === true ||
    text(data.verificationStatus) === "approved";
}

/**
 * Decides whether an unapproved reservation may be removed.
 * Active review, revision, approval, and deletion blocks stay.
 * A newer submission on the same key is left in place.
 * @param {object} input Current key, request, and owner state.
 * @return {IdentityReleasePlan} Release or keep decision.
 */
export function planIdentityReservationRelease(input: {
  key: IdentityReservationKey | null;
  request: IdentityReservationRequest | null;
  ownerApproved: boolean;
}): IdentityReleasePlan {
  const key = input.key;

  if (!key?.exists) {
    return {release: false, reason: "already_absent"};
  }

  if (!input.request) {
    return {release: false, reason: "request_missing"};
  }

  if (key.status === "approved" || key.hasApprovedAt) {
    return {release: false, reason: "approved"};
  }

  if (key.status === "blocked_after_deletion") {
    return {
      release: false,
      reason: "blocked_after_deletion",
    };
  }

  if (key.status !== "reserved") {
    return {release: false, reason: "not_reserved"};
  }

  if (!key.uid || key.uid !== input.request.uid) {
    return {release: false, reason: "owner_mismatch"};
  }

  if (input.ownerApproved) {
    return {release: false, reason: "owner_approved"};
  }

  if (!TERMINAL_RELEASE_STATUSES.has(input.request.status)) {
    return {
      release: false,
      reason: "request_not_terminal",
    };
  }

  if (
    key.submissionId &&
    key.submissionId !== input.request.submissionId
  ) {
    return {release: false, reason: "newer_submission"};
  }

  return {release: true, reason: "released"};
}
