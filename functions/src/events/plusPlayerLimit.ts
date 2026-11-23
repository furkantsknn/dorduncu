/**
 * Sought-player limit for event creation and updates.
 *
 * `oyuncuSayisi` is the number of players the host is looking for.
 * The host is stored in `katilanlar` and is not part of this count.
 * `selectedPlayerIds` fills up to this number and also excludes the host.
 */

export const PLUS_PLAYER_LIMIT_CODE =
  "plus_required_for_multiple_players";

export const FREE_SOUGHT_PLAYER_COUNT = 1;

export type SoughtPlayerCountDecision =
  | "ok"
  | "invalid_range"
  | "plus_required";

/**
 * Decides whether a sought-player count is allowed.
 *
 * Free accounts may seek 1 player. Active Plus may seek any positive,
 * safely representable integer number of players.
 * The host is not added to the count.
 *
 * @param {number} soughtPlayerCount Players sought, excluding the host.
 * @param {boolean} plusActive Server entitlement, including expiry.
 * @return {SoughtPlayerCountDecision} Allowance.
 */
export function evaluateSoughtPlayerCount(
  soughtPlayerCount: number,
  plusActive: boolean,
): SoughtPlayerCountDecision {
  if (
    !Number.isSafeInteger(soughtPlayerCount) ||
    soughtPlayerCount < FREE_SOUGHT_PLAYER_COUNT
  ) {
    return "invalid_range";
  }

  if (!plusActive && soughtPlayerCount > FREE_SOUGHT_PLAYER_COUNT) {
    return "plus_required";
  }

  return "ok";
}

/**
 * True when the submitted sought-player count matches the stored count.
 *
 * An unchanged count must not be rejected by a newer membership limit.
 *
 * @param {number} nextCount Submitted sought-player count.
 * @param {unknown} storedCount Stored `oyuncuSayisi`.
 * @return {boolean} Whether the count is unchanged.
 */
export function soughtPlayerCountIsUnchanged(
  nextCount: number,
  storedCount: unknown,
): boolean {
  const stored = typeof storedCount === "number" ?
    storedCount :
    Number(storedCount);

  return Number.isFinite(nextCount) &&
    Number.isFinite(stored) &&
    nextCount === stored;
}
