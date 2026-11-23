/* eslint-disable require-jsdoc, valid-jsdoc */
import {
  FieldValue,
  Firestore,
  Transaction,
} from "firebase-admin/firestore";

export function formatUserManagementNumber(sequence: number): string {
  return `U-${String(sequence).padStart(6, "0")}`;
}

export function formatSupportNumber(year: number, sequence: number): string {
  return `DST-${year}-${String(sequence).padStart(6, "0")}`;
}

/** Allocates once per UID in a server-only document. Gaps are intentional. */
export async function ensureUserManagementNumber(
  db: Firestore,
  transaction: Transaction,
  uid: string,
): Promise<string> {
  const metadataRef = db.collection("admin_user_metadata").doc(uid);
  const counterRef = db.collection("admin_counters").doc("users");
  const [metadataSnapshot, counterSnapshot] = await Promise.all([
    transaction.get(metadataRef),
    transaction.get(counterRef),
  ]);
  const existing = String(metadataSnapshot.data()?.managementNumber ?? "");
  if (existing) return existing;
  const sequence = Number(counterSnapshot.data()?.lastSequence ?? 0) + 1;
  const managementNumber = formatUserManagementNumber(sequence);
  transaction.set(counterRef, {
    lastSequence: sequence,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  transaction.create(metadataRef, {
    uid,
    managementNumber,
    sequence,
    createdAt: FieldValue.serverTimestamp(),
  });
  return managementNumber;
}

/** Allocates a ticket number from an independent counter for each UTC year. */
export async function allocateSupportNumber(
  db: Firestore,
  transaction: Transaction,
  year: number,
): Promise<string> {
  const counterRef = db.collection("admin_counters").doc(`support_${year}`);
  const counterSnapshot = await transaction.get(counterRef);
  const sequence = Number(counterSnapshot.data()?.lastSequence ?? 0) + 1;
  transaction.set(counterRef, {
    year,
    lastSequence: sequence,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  return formatSupportNumber(year, sequence);
}
