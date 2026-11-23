export interface BadgeEntitlementState {
  adminGranted: boolean;
  adminBlocked: boolean;
  googlePlayEntitled: boolean;
  appleEntitled: boolean;
  hasExplicitStoreSource: boolean;
}

/**
 * Reads independent entitlement sources without guessing legacy provenance.
 * @param {Record<string, unknown>|undefined} data Owned badge data.
 * @return {BadgeEntitlementState} Normalized source state.
 */
export function readBadgeEntitlementState(
  data: Record<string, unknown> | undefined,
): BadgeEntitlementState {
  const hasPlayField = data != null &&
    Object.prototype.hasOwnProperty.call(data, "googlePlayEntitled");
  const hasAppleField = data != null &&
    Object.prototype.hasOwnProperty.call(data, "appleEntitled");
  const hasExplicitStoreSource = hasPlayField || hasAppleField;

  return {
    adminGranted: data?.adminGranted === true,
    adminBlocked: data?.adminBlocked === true,
    googlePlayEntitled: hasPlayField ?
      data?.googlePlayEntitled === true :
      !hasExplicitStoreSource,
    appleEntitled: hasAppleField ?
      data?.appleEntitled === true :
      false,
    hasExplicitStoreSource,
  };
}

/**
 * An admin block wins; otherwise any valid source grants access.
 * Legacy documents with no explicit store flags remain compatible.
 * @param {Record<string, unknown>|undefined} data Owned badge data.
 * @return {boolean} Whether the user currently owns the badge.
 */
export function badgeIsEntitled(
  data: Record<string, unknown> | undefined,
): boolean {
  const state = readBadgeEntitlementState(data);
  if (state.adminBlocked) {
    return false;
  }
  if (state.adminGranted) {
    return true;
  }
  if (!state.hasExplicitStoreSource) {
    return true;
  }
  return state.googlePlayEntitled || state.appleEntitled;
}

/**
 * A Play refund only removes the Play source, never an admin or Apple grant.
 * @param {Record<string, unknown>|undefined} data Owned badge data.
 * @return {BadgeEntitlementState} State after Play revocation.
 */
export function afterPlayRevocation(
  data: Record<string, unknown> | undefined,
): BadgeEntitlementState {
  const state = readBadgeEntitlementState(data);
  return {
    ...state,
    googlePlayEntitled: false,
    hasExplicitStoreSource: true,
  };
}

/**
 * An Apple refund only removes the Apple source, never an admin or Play grant.
 * @param {Record<string, unknown>|undefined} data Owned badge data.
 * @return {BadgeEntitlementState} State after Apple revocation.
 */
export function afterAppleRevocation(
  data: Record<string, unknown> | undefined,
): BadgeEntitlementState {
  const state = readBadgeEntitlementState(data);
  return {
    ...state,
    appleEntitled: false,
    hasExplicitStoreSource: true,
  };
}

/**
 * Applies an explicit admin decision without changing store sources.
 * @param {Record<string, unknown>|undefined} data Owned badge data.
 * @param {"grant"|"remove"} action Admin operation.
 * @return {BadgeEntitlementState} State after the admin decision.
 */
export function applyAdminBadgeDecision(
  data: Record<string, unknown> | undefined,
  action: "grant" | "remove",
): BadgeEntitlementState {
  const state = readBadgeEntitlementState(data);
  return {
    ...state,
    adminGranted: action === "grant",
    adminBlocked: action === "remove",
  };
}
