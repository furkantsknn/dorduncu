import {FieldValue} from "firebase-admin/firestore";
import {firestore} from "../config/firebaseAdmin";

interface AuditLogData {
  action: string;
  performedBy: string;
  targetUid?: string;
  metadata?: Record<string, unknown>;
}

/**
 * Writes a security-sensitive action to the audit log.
 * @param {AuditLogData} data Audit log details.
 * @return {Promise<void>} Completes after the log is written.
 */
export async function writeAuditLog(
  data: AuditLogData
): Promise<void> {
  await firestore.collection("auditLogs").add({
    action: data.action,
    performedBy: data.performedBy,
    targetUid: data.targetUid ?? null,
    metadata: data.metadata ?? {},
    createdAt: FieldValue.serverTimestamp(),
  });
}
