/* eslint-disable max-len, require-jsdoc */
import {Firestore} from "firebase-admin/firestore";
import {hasFreeMembershipAccess, isFreeAccessEvent} from "../events/eventLifecycle";

export interface EventChatAccessContext {
  eventReference: FirebaseFirestore.DocumentReference;
  eventData: FirebaseFirestore.DocumentData;
}

export async function hasEventChatAccess(
  db: Firestore, uid: string, eventId: string,
): Promise<EventChatAccessContext | null> {
  const eventReference = db.collection("events").doc(eventId);
  const eventSnapshot = await eventReference.get();
  if (!eventSnapshot.exists) return null;
  const eventData = eventSnapshot.data() ?? {};
  let applicationData: FirebaseFirestore.DocumentData | undefined;
  if (!isEventOrganizer(uid, eventData)) {
    const application = await eventReference.collection("applications").doc(uid).get();
    applicationData = application.exists ? application.data() : undefined;
  }
  return isEventChatMember(uid, eventData, applicationData) ?
    {eventReference, eventData} : null;
}

export function isEventChatMember(
  uid: string, eventData: FirebaseFirestore.DocumentData,
  applicationData?: FirebaseFirestore.DocumentData,
): boolean {
  if (isFreeAccessEvent(eventData)) {
    return isEventOrganizer(uid, eventData) ||
      readStringList(eventData.selectedPlayerIds).includes(uid) &&
      hasFreeMembershipAccess(applicationData);
  }
  if (!hasCompletedEventPayment(eventData)) return false;
  if (isEventOrganizer(uid, eventData)) return true;
  const members = new Set([
    ...readStringList(eventData.selectedPlayerIds),
    ...readStringList(eventData.katilanlar),
    ...readStringList(eventData.participantIds),
    ...readStringList(eventData.participantUids),
    ...readStringList(eventData.acceptedUserUids),
    ...readStringList(eventData.chatMemberUids),
    ...readStringList(eventData.memberUids),
  ]);
  if (!members.has(uid) || !applicationData) return false;
  const payment = String(applicationData.paymentStatus ?? "").trim().toLowerCase();
  const address = String(applicationData.addressAccessStatus ?? "").trim().toLowerCase();
  return address === "unlocked" && (payment === "paid" || payment === "completed");
}

export function isEventOrganizer(
  uid: string, eventData: FirebaseFirestore.DocumentData,
): boolean {
  return ["olusturanUid", "creatorUid", "ownerUid", "hostUid"]
    .some((key) => String(eventData[key] ?? "").trim() === uid);
}

function hasCompletedEventPayment(eventData: FirebaseFirestore.DocumentData): boolean {
  return new Set(["paid", "completed", "success", "succeeded", "escrowheld", "escrow_held"])
    .has(String(eventData.paymentStatus ?? "").trim().toLowerCase());
}

function readStringList(value: unknown): string[] {
  return Array.isArray(value) ? value.map(String).map((item) => item.trim()).filter(Boolean) : [];
}
