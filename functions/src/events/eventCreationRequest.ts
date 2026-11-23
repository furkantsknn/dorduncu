import {createHash} from "crypto";
import {HttpsError} from "firebase-functions/v2/https";

/**
 * Builds a user-scoped id; legacy callers keep random document ids.
 * @param {string} uid Authenticated owner.
 * @param {unknown} value Caller request id.
 * @return {string|null} Scoped document id.
 */
export function eventCreationRequestId(
  uid: string, value: unknown,
): string|null {
  if (value == null) return null;
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]{16,80}$/.test(value)) {
    throw new HttpsError("invalid-argument", "Invalid event request id.");
  }
  return "req_" + createHash("sha256").update(uid + ":" + value).digest("hex");
}

/**
 * Hashes normalized create fields without logging private data.
 * @param {unknown[]} fields Validated create fields in canonical order.
 * @return {string} Fingerprint.
 */
export function eventCreationFingerprint(fields: unknown[]): string {
  return createHash("sha256").update(JSON.stringify(fields)).digest("hex");
}
