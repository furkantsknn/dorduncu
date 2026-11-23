/* eslint-disable require-jsdoc */
export function publicProfileWriteAllowed(
  userData: Record<string, unknown> | null,
  deletionData: Record<string, unknown> | null,
): boolean {
  if (!userData) return false;
  if (String(userData.accountStatus ?? "") !== "active") return false;
  const status = String(deletionData?.status ?? "");
  return !["pending", "processing", "failed"].includes(status);
}
