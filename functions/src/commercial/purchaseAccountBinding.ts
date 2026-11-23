import {HttpsError} from "firebase-functions/v2/https";

/**
 * True when Play's obfuscated account id allows this user to claim the token.
 *
 * Personal purchases started by this app carry the buyer's uid. Older
 * purchases have no account id and stay claimable by the token registry rule.
 *
 * @param {string | null} obfuscatedAccountId Value returned by Play.
 * @param {string} uid Caller uid.
 * @return {boolean} Whether the purchase may be bound to the caller.
 */
export function purchaseAccountMatches(
  obfuscatedAccountId: string | null,
  uid: string,
): boolean {
  const accountId = obfuscatedAccountId?.trim() ?? "";
  return accountId.length === 0 || accountId === uid;
}

/**
 * Rejects a personal purchase that Play bound to another app account.
 *
 * @param {string | null} obfuscatedAccountId Value returned by Play.
 * @param {string} uid Caller uid.
 */
export function assertPurchaseAccount(
  obfuscatedAccountId: string | null,
  uid: string,
): void {
  if (!purchaseAccountMatches(obfuscatedAccountId, uid)) {
    throw new HttpsError(
      "permission-denied",
      "Bu Google Play satın alması başka bir Dört. hesabına ait.",
    );
  }
}
