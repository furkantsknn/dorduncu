import {assertCurrentAdminSession} from "../security/adminAuthorization";
/* eslint-disable max-len, require-jsdoc */
import {createHash} from "crypto";
import {getStorage} from "firebase-admin/storage";
import {FieldValue, Firestore, getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {assertAdminPermission, getAdminRole} from "../security/adminAuthorization";

const REGION = "europe-west1";

interface ProfileObjectTarget {
  bucket: string;
  path: string;
  generation: string;
  contentType: string;
  profileReference: string;
  evidencePath: string;
}

export interface ModerationStorage {
  resolve(reference: string, evidenceId: string): Promise<ProfileObjectTarget | null>;
  preserve(target: ProfileObjectTarget): Promise<boolean>;
  deleteOriginal(target: ProfileObjectTarget): Promise<void>;
}

export interface ModerationResult {
  kind: string;
  requestId: string;
  targetUid: string;
  evidenceId: string;
  alreadyRemoved: boolean;
  filePreserved?: boolean;
}

export const adminRemoveReportedContent = onCall(
  {region: REGION, enforceAppCheck: true},
  async (request) => {
    const requestId = readId(request.data, "requestId");
    const db = getFirestore();
    const authorization = await authorizeReportedContentRequest(request, db, requestId);

    const result = await removeReportedContent(db, requestId, authorization.uid);
    await writeModerationAuditOnce(db, result, authorization.uid, authorization.role);
    return {success: true, ...result};
  },
);

export async function authorizeReportedContentRequest(
  request: Parameters<typeof assertAdminPermission>[0],
  db: Firestore,
  requestId: string,
): Promise<{category: string; uid: string; role: string}> {
  // Authentication and baseline support access are checked before ticket data is read.
  assertAdminPermission(request, "support.manage");
  await assertCurrentAdminSession(request);
  const ticket = await db.collection("support_requests").doc(requestId).get();
  if (!ticket.exists) throw new HttpsError("not-found", "Destek talebi bulunamadı.");
  const category = String(ticket.data()?.category ?? "");
  if (category === "message_report") {
    assertAdminPermission(request, "events.moderate");
    await assertCurrentAdminSession(request);
  } else if (category === "inappropriate_image") {
    assertAdminPermission(request, "users.moderate");
    await assertCurrentAdminSession(request);
  } else {
    throw new HttpsError(
      "failed-precondition",
      "Bu talep türü için hedefli içerik kaldırma desteklenmiyor.",
    );
  }
  return {category, uid: request.auth.uid, role: getAdminRole(request)};
}

export async function removeReportedContent(
  db: Firestore,
  requestId: string,
  adminUid: string,
  storage?: ModerationStorage,
): Promise<ModerationResult> {
  const ticketReference = db.collection("support_requests").doc(requestId);
  const ticket = await ticketReference.get();
  if (!ticket.exists) throw new HttpsError("not-found", "Destek talebi bulunamadı.");
  const data = ticket.data() ?? {};
  const category = String(data.category ?? "");

  if (category === "message_report") {
    const eventId = requiredStoredId(data.relatedEventId, "Etkinlik kimliği eksik.");
    const messageId = requiredStoredId(data.relatedMessageId, "Mesaj kimliği eksik.");
    const evidenceId = evidenceDocumentId("event_message", `${eventId}:${messageId}`);
    const eventReference = db.collection("events").doc(eventId);
    const messageReference = eventReference.collection("messages").doc(messageId);
    const evidenceReference = db.collection("moderation_evidence").doc(evidenceId);
    const reportEvidenceReference = db.collection("moderation_report_evidence").doc(requestId);
    let targetUid = "";
    let alreadyRemoved = false;
    await db.runTransaction(async (transaction) => {
      const [message, event, evidence, reportEvidence] = await Promise.all([
        transaction.get(messageReference),
        transaction.get(eventReference),
        transaction.get(evidenceReference),
        transaction.get(reportEvidenceReference),
      ]);
      if (!message.exists && !evidence.exists) {
        throw new HttpsError("not-found", "Bildirilen mesaj bulunamadı.");
      }
      const messageData = message.data() ?? {};
      const evidenceData = evidence.data() ?? {};
      const reportMessage = (
        reportEvidence.data()?.evidence as Record<string, unknown> | undefined
      )?.message as Record<string, unknown> | undefined;
      if (reportMessage && (
        String(reportMessage.eventId ?? "") !== eventId ||
        String(reportMessage.messageId ?? "") !== messageId
      )) {
        throw new HttpsError(
          "failed-precondition",
          "Şikâyet mesajı delili hedefle eşleşmiyor.",
        );
      }
      targetUid = String(
        evidenceData.targetUid ??
        (evidenceData.original as Record<string, unknown> | undefined)?.senderUid ??
        reportMessage?.senderId ??
        messageData.senderUid ??
        messageData.senderId ??
        "",
      );
      alreadyRemoved = evidence.exists;
      if (!evidence.exists) {
        transaction.create(evidenceReference, {
          kind: "event_message",
          eventId,
          messageId,
          targetUid,
          original: reportMessage ?? messageData,
          firstRequestId: requestId,
          removedBy: adminUid,
          removedAt: FieldValue.serverTimestamp(),
        });
      }
      if (message.exists && String(messageData.moderationStatus ?? "") !== "removed") {
        transaction.update(messageReference, {
          text: "",
          message: "",
          attachments: [],
          deleted: true,
          deletedAt: FieldValue.serverTimestamp(),
          moderationStatus: "removed",
          moderatedBy: adminUid,
          moderatedAt: FieldValue.serverTimestamp(),
        });
      }
      if (event.exists && String(event.data()?.lastMessageId ?? "") === messageId) {
        transaction.update(eventReference, {
          lastMessage: "Yeni mesaj",
          lastMessageSenderName: FieldValue.delete(),
          lastMessageSenderPhotoUrl: FieldValue.delete(),
          lastMessageModeratedAt: FieldValue.serverTimestamp(),
        });
      }
      transaction.set(ticketReference, {
        moderatedContentStatus: "removed",
        moderatedContentEvidenceId: evidenceId,
        moderatedContentAt: FieldValue.serverTimestamp(),
        moderatedContentBy: adminUid,
      }, {merge: true});
    });
    return {kind: "event_message", requestId, targetUid, evidenceId, alreadyRemoved};
  }

  if (category === "inappropriate_image") {
    const targetUid = requiredStoredId(data.relatedUserId, "Kullanıcı kimliği eksik.");
    return removeReportedProfileImage(
      db,
      ticketReference,
      requestId,
      targetUid,
      adminUid,
      storage ?? firebaseModerationStorage(),
    );
  }

  throw new HttpsError(
    "failed-precondition",
    "Bu talep türü için hedefli içerik kaldırma desteklenmiyor.",
  );
}

async function removeReportedProfileImage(
  db: Firestore,
  ticketReference: FirebaseFirestore.DocumentReference,
  requestId: string,
  targetUid: string,
  adminUid: string,
  storage: ModerationStorage,
): Promise<ModerationResult> {
  const userReference = db.collection("users").doc(targetUid);
  const publicReference = db.collection("public_profiles").doc(targetUid);
  const reportEvidence = await db.collection("moderation_report_evidence").doc(requestId).get();
  const verifiedTarget = readProfileTarget(
    (reportEvidence.data()?.evidence as Record<string, unknown> | undefined)?.profileImage,
  );
  const targetValues = await db.runTransaction(async (transaction) => {
    const currentTicket = await transaction.get(ticketReference);
    const existing = readProfileTarget(currentTicket.data()?.moderationProfileTarget);
    if (existing) return requireTrustedProfileTarget(existing, targetUid);
    if (!verifiedTarget) {
      throw new HttpsError(
        "failed-precondition",
        "Eski şikâyetin görsel nesnesi doğrulanamıyor; yeniden doğrulama gereklidir.",
      );
    }
    const trusted = requireTrustedProfileTarget(verifiedTarget, targetUid);
    const evidenceId = evidenceDocumentId(
      "profile_image",
      `${trusted.bucket}:${trusted.path}:${trusted.generation}`,
    );
    const canonical = {
      ...trusted,
      evidenceId,
      evidencePath: `moderation_evidence/profile_images/${evidenceId}`,
    };
    transaction.set(ticketReference, {
      moderationProfileTarget: canonical,
      moderationProfileTargetedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return canonical;
  });
  const evidenceId = targetValues.evidenceId ?? evidenceDocumentId(
    "profile_image",
    `${targetValues.bucket}:${targetValues.path}:${targetValues.generation}`,
  );
  let filePreserved = false;
  if (targetValues.path && targetValues.generation) {
    filePreserved = await storage.preserve(targetValues);
    if (!filePreserved) {
      throw new HttpsError("internal", "Profil görseli delili korunamadı.");
    }
    await storage.deleteOriginal(targetValues);
  }
  await sanitizeProfileImageSnapshots(
    db,
    targetUid,
    targetValues.profileReference,
  );

  const evidenceReference = db.collection("moderation_evidence").doc(evidenceId);
  let alreadyRemoved = false;
  await db.runTransaction(async (transaction) => {
    const [user, publicProfile, evidence] = await Promise.all([
      transaction.get(userReference),
      transaction.get(publicReference),
      transaction.get(evidenceReference),
    ]);
    alreadyRemoved = evidence.exists;
    if (!evidence.exists) {
      transaction.create(evidenceReference, {
        kind: "profile_image",
        targetUid,
        sourceBucket: targetValues.bucket,
        sourceObjectPath: targetValues.path || null,
        sourceGeneration: targetValues.generation || null,
        evidenceObjectPath: filePreserved ? targetValues.evidencePath : null,
        filePreserved,
        firstRequestId: requestId,
        removedBy: adminUid,
        removedAt: FieldValue.serverTimestamp(),
      });
    }
    if (user.exists) {
      const userData = user.data() ?? {};
      const updates: Record<string, unknown> = {
        profileImageModeratedAt: FieldValue.serverTimestamp(),
        profileImageModeratedBy: adminUid,
      };
      if (String(userData.profilFotografi ?? "") === targetValues.profileReference) {
        updates.profilFotografi = FieldValue.delete();
      }
      if (String(userData.avatarUrl ?? "") === targetValues.profileReference) {
        updates.avatarUrl = FieldValue.delete();
      }
      transaction.update(userReference, updates);
    }
    if (publicProfile.exists) {
      const publicData = publicProfile.data() ?? {};
      const updates: Record<string, unknown> = {
        profileImageModeratedAt: FieldValue.serverTimestamp(),
      };
      if (String(publicData.profilFotografi ?? "") === targetValues.profileReference) {
        updates.profilFotografi = "";
      }
      if (String(publicData.avatarUrl ?? "") === targetValues.profileReference) {
        updates.avatarUrl = "";
      }
      transaction.update(publicReference, updates);
    }
    transaction.set(ticketReference, {
      moderatedContentStatus: "removed",
      moderatedContentEvidenceId: evidenceId,
      moderatedContentFilePreserved: filePreserved,
      moderatedContentAt: FieldValue.serverTimestamp(),
      moderatedContentBy: adminUid,
    }, {merge: true});
  });
  return {kind: "profile_image", requestId, targetUid, evidenceId, alreadyRemoved, filePreserved};
}

export async function sanitizeProfileImageSnapshots(
  db: Firestore,
  targetUid: string,
  profileReference: string,
): Promise<void> {
  if (!profileReference) return;
  const [events, applications, messages, notifications] = await Promise.all([
    db.collection("events").where("olusturanUid", "==", targetUid).get(),
    db.collectionGroup("applications").where("playerId", "==", targetUid).get(),
    db.collectionGroup("messages").where("senderUid", "==", targetUid).get(),
    db.collectionGroup("notifications").where("senderUid", "==", targetUid).get(),
  ]);
  const updates: Array<{
    reference: FirebaseFirestore.DocumentReference;
    values: Record<string, unknown>;
  }> = [];
  for (const document of events.docs) {
    if (String(document.data().olusturanProfilFotografi ?? "") === profileReference) {
      updates.push({
        reference: document.ref,
        values: {olusturanProfilFotografi: ""},
      });
    }
  }
  for (const document of applications.docs) {
    if (String(document.data().playerProfilePhoto ?? "") === profileReference) {
      updates.push({reference: document.ref, values: {playerProfilePhoto: ""}});
    }
  }
  for (const document of messages.docs) {
    if (String(document.data().senderPhotoUrl ?? "") === profileReference) {
      updates.push({reference: document.ref, values: {senderPhotoUrl: ""}});
    }
  }
  for (const document of notifications.docs) {
    if (String(document.data().senderPhotoUrl ?? "") === profileReference) {
      updates.push({reference: document.ref, values: {senderPhotoUrl: ""}});
    }
  }
  for (let offset = 0; offset < updates.length; offset += 100) {
    const chunk = updates.slice(offset, offset + 100);
    await db.runTransaction(async (transaction) => {
      const current = await Promise.all(
        chunk.map((item) => transaction.get(item.reference)),
      );
      current.forEach((snapshot, index) => {
        if (!snapshot.exists) return;
        const values = chunk[index].values;
        const field = Object.keys(values)[0];
        if (String(snapshot.data()?.[field] ?? "") === profileReference) {
          transaction.update(chunk[index].reference, values);
        }
      });
    });
  }
}

function firebaseModerationStorage(): ModerationStorage {
  const bucket = getStorage().bucket();
  return {
    async resolve(reference, evidenceId) {
      const path = storagePath(reference);
      if (!path || !path.startsWith("profile_photos/")) return null;
      const [metadata] = await bucket.file(path).getMetadata();
      const generation = String(metadata.generation ?? "");
      if (!generation) throw new HttpsError("failed-precondition", "Profil görseli sürümü bulunamadı.");
      return {
        bucket: bucket.name,
        path,
        generation,
        contentType: String(metadata.contentType ?? "application/octet-stream"),
        profileReference: reference,
        evidencePath: `moderation_evidence/profile_images/${evidenceId}`,
      };
    },
    async preserve(target) {
      if (target.bucket !== bucket.name) {
        throw new HttpsError("failed-precondition", "Profil görseli bucket bilgisi uyuşmuyor.");
      }
      const destination = bucket.file(target.evidencePath);
      const [exists] = await destination.exists();
      if (exists) return true;
      const versionedSource = bucket.file(target.path, {generation: target.generation});
      const [bytes] = await versionedSource.download({validation: "crc32c"});
      try {
        await destination.save(bytes, {
          resumable: false,
          contentType: target.contentType,
          metadata: {cacheControl: "private,no-store", metadata: {}},
          preconditionOpts: {ifGenerationMatch: 0},
        });
      } catch (error: unknown) {
        if (readErrorCode(error) !== 412 && readErrorCode(error) !== "412") throw error;
      }
      return (await destination.exists())[0];
    },
    async deleteOriginal(target) {
      if (target.bucket !== bucket.name) {
        throw new HttpsError("failed-precondition", "Profil görseli bucket bilgisi uyuşmuyor.");
      }
      try {
        await bucket.file(target.path).delete({ifGenerationMatch: Number(target.generation)});
      } catch (error: unknown) {
        const code = readErrorCode(error);
        if (code !== 404 && code !== "404") throw error;
      }
    },
  };
}

async function writeModerationAuditOnce(
  db: Firestore,
  result: ModerationResult,
  adminUid: string,
  role: string,
): Promise<void> {
  const reference = db.collection("audit_logs").doc(
    evidenceDocumentId("moderation_audit", result.requestId),
  );
  await db.runTransaction(async (transaction) => {
    if ((await transaction.get(reference)).exists) return;
    transaction.create(reference, {
      action: "admin_remove_reported_content",
      performedBy: adminUid,
      targetUid: result.targetUid || null,
      metadata: {...result, performedByRole: role},
      createdAt: FieldValue.serverTimestamp(),
    });
  });
}

function readProfileTarget(value: unknown): (ProfileObjectTarget & {evidenceId?: string}) | null {
  if (!value || typeof value !== "object") return null;
  const data = value as Record<string, unknown>;
  const profileReference = String(data.profileReference ?? "");
  if (!profileReference) return null;
  return {
    bucket: String(data.bucket ?? ""),
    path: String(data.path ?? ""),
    generation: String(data.generation ?? ""),
    contentType: String(data.contentType ?? ""),
    profileReference,
    evidencePath: String(data.evidencePath ?? ""),
    evidenceId: String(data.evidenceId ?? "") || undefined,
  };
}

function requireTrustedProfileTarget(
  target: ProfileObjectTarget & {evidenceId?: string},
  targetUid: string,
): ProfileObjectTarget & {evidenceId?: string} {
  const expectedBucket = getStorage().bucket().name;
  if (target.bucket !== expectedBucket ||
      !target.path.startsWith(`profile_photos/${targetUid}/`) ||
      !target.generation || !/^\d+$/.test(target.generation) ||
      !target.profileReference) {
    throw new HttpsError(
      "failed-precondition",
      "Şikâyet edilen profil görseli güvenilir biçimde doğrulanamadı.",
    );
  }
  return target;
}

function storagePath(reference: string): string {
  const value = reference.trim();
  if (value.startsWith("profile_photos/")) return value;
  if (value.startsWith("gs://")) return value.split("/").slice(3).join("/");
  try {
    const url = new URL(value);
    const marker = "/o/";
    const index = url.pathname.indexOf(marker);
    return index >= 0 ? decodeURIComponent(url.pathname.slice(index + marker.length)) : "";
  } catch {
    return "";
  }
}

function evidenceDocumentId(kind: string, target: string): string {
  return `${kind}_${createHash("sha256").update(target).digest("hex")}`;
}

function readErrorCode(error: unknown): string | number {
  if (!error || typeof error !== "object") return "";
  const values = error as {code?: unknown};
  return typeof values.code === "number" ? values.code : String(values.code ?? "");
}

function readId(data: unknown, key: string): string {
  const values = data && typeof data === "object" ? data as Record<string, unknown> : {};
  return requiredStoredId(values[key], `${key} gerekli.`);
}

function requiredStoredId(value: unknown, message: string): string {
  const result = typeof value === "string" ? value.trim() : "";
  if (!result || result.length > 1500 || result.includes("/")) {
    throw new HttpsError("invalid-argument", message);
  }
  return result;
}
