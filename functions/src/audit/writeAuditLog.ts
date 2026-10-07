/* eslint-disable max-len */
import {FieldValue, Firestore, getFirestore, Transaction} from "firebase-admin/firestore";

export interface AuditLogData {
  action: string;
  performedBy: string;
  targetUid?: string;
  metadata?: Record<string, unknown>;
}

/**
 * Writes a security-sensitive action to the canonical audit log.
 * @param {AuditLogData} data Audit log details.
 * @return {Promise<void>} Completes after the log is written.
 */
export async function writeAuditLog(
  data: AuditLogData,
): Promise<void> {
  await getFirestore().collection("audit_logs").add(
    buildAuditDocument(data),
  );
}

/**
 * Writes the canonical audit record inside an existing transaction.
 *
 * @param {Firestore} firestore Firestore instance.
 * @param {Transaction} transaction Existing transaction.
 * @param {AuditLogData} data Audit details.
 * @return {string} Audit document id.
 */
export function writeAuditLogInTransaction(
  firestore: Firestore,
  transaction: Transaction,
  data: AuditLogData,
): string {
  const reference = firestore
    .collection("audit_logs")
    .doc();

  transaction.set(
    reference,
    buildAuditDocument(data),
  );

  return reference.id;
}

/**
 * Builds one canonical audit document.
 *
 * @param {AuditLogData} data Audit details.
 * @return {Record<string, unknown>} Firestore document.
 */
function buildAuditDocument(
  data: AuditLogData,
): Record<string, unknown> {
  return {
    action: data.action,
    performedBy: data.performedBy,
    targetUid: data.targetUid ?? null,
    metadata: data.metadata ?? {},
    createdAt: FieldValue.serverTimestamp(),
  };
}
