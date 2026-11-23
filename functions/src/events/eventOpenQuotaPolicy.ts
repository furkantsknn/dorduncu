/* eslint-disable require-jsdoc */
/* eslint-disable max-len */
import {
  DocumentData,
  FieldValue,
  Firestore,
  Transaction,
} from "firebase-admin/firestore";

import {eventHasEnded} from "./eventLifecycle";

export const FREE_OPEN_EVENT_LIMIT = 2;
export const OPEN_EVENT_QUOTA_CODE = "free_open_event_quota_reached";

const CLOSED_STATUSES = new Set([
  "cancelled", "canceled", "iptal", "iptal_edildi",
  "completed", "finished", "tamamlandi", "tamamlandı",
  "hidden", "removed", "deleted",
  "expired",
]);

export function eventCountsTowardOpenQuota(
  data: DocumentData,
  nowMs: number = Date.now(),
): boolean {
  const status = String(data.durum ?? data.status ?? "aktif")
    .trim()
    .toLowerCase();
  return !CLOSED_STATUSES.has(status) && !eventHasEnded(data, nowMs);
}

export interface EventQuotaState {
  openEventIds: string[];
  openEventCount: number;
  plusActive: boolean;
  limit: number | null;
  canCreate: boolean;
}

export async function readOpenEventIds(
  firestore: Firestore,
  ownerUid: string,
  nowMs: number,
  transaction?: Transaction,
): Promise<string[]> {
  const query = firestore.collection("events")
    .where("olusturanUid", "==", ownerUid);
  const snapshot = transaction ?
    await transaction.get(query) :
    await query.get();
  return snapshot.docs
    .filter((document) => eventCountsTowardOpenQuota(document.data(), nowMs))
    .map((document) => document.id)
    .sort();
}

export function buildEventQuotaState(
  openEventIds: string[],
  plusActive: boolean,
): EventQuotaState {
  return {
    openEventIds,
    openEventCount: openEventIds.length,
    plusActive,
    limit: plusActive ? null : FREE_OPEN_EVENT_LIMIT,
    canCreate: plusActive || openEventIds.length < FREE_OPEN_EVENT_LIMIT,
  };
}

export async function syncEventQuotaInTransaction(
  transaction: Transaction,
  firestore: Firestore,
  ownerUid: string,
  nowMs: number,
  plusActive: boolean,
  addEventId?: string,
  removeEventId?: string,
): Promise<EventQuotaState> {
  const quotaReference = firestore.collection("event_owner_quotas").doc(ownerUid);
  await transaction.get(quotaReference);
  const ids = await readOpenEventIds(firestore, ownerUid, nowMs, transaction);
  if (removeEventId) {
    const index = ids.indexOf(removeEventId);
    if (index >= 0) ids.splice(index, 1);
  }
  if (addEventId && !ids.includes(addEventId)) ids.push(addEventId);
  ids.sort();
  const state = buildEventQuotaState(ids, plusActive);
  transaction.set(quotaReference, {
    ownerUid,
    openEventIds: state.openEventIds,
    openEventCount: state.openEventCount,
    policyVersion: 1,
    reconciledAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  return state;
}
