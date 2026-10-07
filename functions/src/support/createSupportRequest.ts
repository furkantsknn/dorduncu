/* eslint-disable require-jsdoc */
import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";

import {
  FieldValue,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";

const REGION = "europe-west1";
const COOLDOWN_MS = 30 * 1000;
const HOURLY_LIMIT = 12;

const CATEGORIES = new Set([
  "suggestion",
  "bug_report",
  "general_support",
  "payment_issue",
  "account_appeal",
  "user_report",
  "event_report",
  "message_report",
  "inappropriate_image",
  "security_emergency",
]);

const URGENCIES = new Set([
  "low",
  "normal",
  "high",
  "critical",
]);

interface CreateSupportRequestData {
  category?: unknown;
  subject?: unknown;
  description?: unknown;
  urgency?: unknown;
  relatedUserId?: unknown;
  relatedEventId?: unknown;
  relatedMessageId?: unknown;
  attachmentUrls?: unknown;
}

export const createSupportRequest = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Bu işlem için giriş yapmalısınız.",
      );
    }

    const data = request.data as CreateSupportRequestData;
    const uid = request.auth.uid;

    const category = readRequiredString(
      data.category,
      "Destek kategorisi gereklidir.",
      50,
    );

    if (!CATEGORIES.has(category)) {
      throw new HttpsError(
        "invalid-argument",
        "Geçersiz destek kategorisi.",
      );
    }

    const subject = readRequiredString(
      data.subject,
      "Konu gereklidir.",
      120,
    );

    if (subject.length < 3) {
      throw new HttpsError(
        "invalid-argument",
        "Konu en az 3 karakter olmalıdır.",
      );
    }

    const description = readRequiredString(
      data.description,
      "Açıklama gereklidir.",
      3000,
    );

    if (description.length < 10) {
      throw new HttpsError(
        "invalid-argument",
        "Açıklama en az 10 karakter olmalıdır.",
      );
    }

    let urgency = readOptionalString(data.urgency, 20) || "normal";

    if (!URGENCIES.has(urgency)) {
      throw new HttpsError(
        "invalid-argument",
        "Geçersiz aciliyet seviyesi.",
      );
    }

    if (category === "security_emergency") {
      urgency = "critical";
    }

    const relatedUserId = readOptionalString(
      data.relatedUserId,
      128,
    );
    const relatedEventId = readOptionalString(
      data.relatedEventId,
      128,
    );
    const relatedMessageId = readOptionalString(
      data.relatedMessageId,
      128,
    );

    validateRequiredReferences({
      category,
      relatedUserId,
      relatedEventId,
      relatedMessageId,
      uid,
    });

    const attachmentUrls = readStringArray(
      data.attachmentUrls,
      3,
      512,
    );

    for (const attachmentPath of attachmentUrls) {
      const requiredPrefix = `support_attachments/${uid}/`;

      if (!attachmentPath.startsWith(requiredPrefix)) {
        throw new HttpsError(
          "permission-denied",
          "Geçersiz destek eki.",
        );
      }
    }

    const firestore = getFirestore();
    const evidenceSnapshot: Record<string, unknown> = {};

    if (relatedUserId) {
      const userSnapshot = await firestore
        .collection("public_profiles")
        .doc(relatedUserId)
        .get();

      if (!userSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "İlgili kullanıcı bulunamadı.",
        );
      }

      const userData = userSnapshot.data() ?? {};

      evidenceSnapshot.user = {
        uid: relatedUserId,
        profileName: String(userData.profilAdi ?? ""),
        profilePhoto: String(
          userData.profilFotografi ??
          userData.avatarUrl ??
          "",
        ),
      };
    }

    let eventSnapshotData: Record<string, unknown> | null = null;

    if (relatedEventId) {
      const eventSnapshot = await firestore
        .collection("events")
        .doc(relatedEventId)
        .get();

      if (!eventSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "İlgili etkinlik bulunamadı.",
        );
      }

      eventSnapshotData =
        eventSnapshot.data() as Record<string, unknown>;

      evidenceSnapshot.event = {
        eventId: relatedEventId,
        title: String(
          eventSnapshotData.baslik ??
          eventSnapshotData.title ??
          "",
        ),
        ownerUid: String(
          eventSnapshotData.olusturanUid ??
          eventSnapshotData.ownerUid ??
          "",
        ),
        status: String(
          eventSnapshotData.durum ??
          eventSnapshotData.status ??
          "",
        ),
      };
    }

    if (category === "message_report") {
      if (!relatedEventId) {
        throw new HttpsError(
          "invalid-argument",
          "Mesaj şikâyeti için ilgili etkinlik gereklidir.",
        );
      }

      const messageSnapshot = await firestore
        .collection("events")
        .doc(relatedEventId)
        .collection("messages")
        .doc(relatedMessageId)
        .get();

      if (!messageSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "İlgili mesaj bulunamadı.",
        );
      }

      const messageData = messageSnapshot.data() ?? {};

      evidenceSnapshot.message = {
        messageId: relatedMessageId,
        senderId: String(messageData.senderId ?? ""),
        text: String(
          messageData.text ??
          messageData.message ??
          "",
        ).slice(0, 2000),
        createdAt: messageData.createdAt ?? null,
      };
    }

    const requestReference = firestore
      .collection("support_requests")
      .doc();

    const rateReference = firestore
      .collection("support_rate_limits")
      .doc(uid);

    const nowMs = Date.now();
    const currentHour = Math.floor(nowMs / (60 * 60 * 1000));

    await firestore.runTransaction(async (transaction) => {
      const rateSnapshot = await transaction.get(rateReference);
      const rateData = rateSnapshot.data() ?? {};

      const lastCreatedAt = rateData.lastCreatedAt;

      if (lastCreatedAt instanceof Timestamp) {
        const elapsed = nowMs - lastCreatedAt.toMillis();

        if (elapsed >= 0 && elapsed < COOLDOWN_MS) {
          throw new HttpsError(
            "resource-exhausted",
            "Yeni talep oluşturmadan önce kısa bir süre bekleyin.",
          );
        }
      }

      const storedHour = Number(rateData.hourBucket ?? -1);
      const storedCount = Number(rateData.hourCount ?? 0);
      const hourCount = storedHour === currentHour ? storedCount : 0;

      if (hourCount >= HOURLY_LIMIT) {
        throw new HttpsError(
          "resource-exhausted",
          "Saatlik destek talebi sınırına ulaştınız.",
        );
      }

      const ticketId = buildTicketId(requestReference.id);
      const priorityScore = calculatePriority(category, urgency);

      transaction.set(
        requestReference,
        {
          schemaVersion: 1,
          source: "mobile_app",
          userId: uid,
          category,
          subject,
          description,
          relatedUserId: relatedUserId || null,
          relatedEventId: relatedEventId || null,
          relatedMessageId: relatedMessageId || null,
          attachmentUrls,
          evidenceSnapshot,
          urgency,
          status: "new",
          adminResponse: "",
          lastMessage: description,
          lastMessageSenderId: uid,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          closedAt: null,
          ticketId,
          replyCount: 0,
          isReadByUser: true,
          isReadByAdmin: false,
          isDeleted: false,
          tags: [],
          assignedAdminId: null,
          firstResponseAt: null,
          lastReplyAt: FieldValue.serverTimestamp(),
          priorityScore,
          satisfactionScore: null,
        },
      );

      transaction.set(
        requestReference.collection("history").doc(),
        {
          action: "created",
          oldStatus: null,
          newStatus: "new",
          performedByUid: uid,
          performedByRole: "user",
          note: "",
          ticketId,
          visibleToUser: true,
          createdAt: FieldValue.serverTimestamp(),
        },
      );

      transaction.set(
        requestReference.collection("messages").doc(),
        {
          senderId: uid,
          senderRole: "user",
          message: description,
          attachments: attachmentUrls,
          status: "sent",
          edited: false,
          editedAt: null,
          deleted: false,
          deletedAt: null,
          readBy: [uid],
          createdAt: FieldValue.serverTimestamp(),
        },
      );

      transaction.set(
        rateReference,
        {
          uid,
          hourBucket: currentHour,
          hourCount: hourCount + 1,
          lastCreatedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        {
          merge: true,
        },
      );
    });

    const created = await requestReference.get();
    const createdData = created.data() ?? {};

    return {
      success: true,
      requestId: requestReference.id,
      ticketId: String(createdData.ticketId ?? ""),
    };
  },
);

function validateRequiredReferences(params: {
  category: string;
  relatedUserId: string;
  relatedEventId: string;
  relatedMessageId: string;
  uid: string;
}): void {
  if (params.category === "user_report") {
    if (!params.relatedUserId) {
      throw new HttpsError(
        "invalid-argument",
        "Kullanıcı şikâyeti için ilgili kullanıcı gereklidir.",
      );
    }

    if (params.relatedUserId === params.uid) {
      throw new HttpsError(
        "invalid-argument",
        "Kendi hesabınızı şikâyet edemezsiniz.",
      );
    }
  }

  if (params.category === "event_report" && !params.relatedEventId) {
    throw new HttpsError(
      "invalid-argument",
      "Etkinlik şikâyeti için ilgili etkinlik gereklidir.",
    );
  }

  if (params.category === "message_report") {
    if (!params.relatedMessageId || !params.relatedEventId) {
      throw new HttpsError(
        "invalid-argument",
        "Mesaj şikâyeti için mesaj ve etkinlik bilgisi gereklidir.",
      );
    }
  }
}

function calculatePriority(
  category: string,
  urgency: string,
): number {
  const categoryPriority: Record<string, number> = {
    security_emergency: 100,
    user_report: 80,
    event_report: 70,
    message_report: 70,
    payment_issue: 60,
    inappropriate_image: 60,
    bug_report: 40,
    general_support: 20,
    account_appeal: 20,
    suggestion: 10,
  };

  const urgencyBoost: Record<string, number> = {
    low: 0,
    normal: 5,
    high: 15,
    critical: 30,
  };

  return Math.min(
    130,
    (categoryPriority[category] ?? 20) +
      (urgencyBoost[urgency] ?? 0),
  );
}

function buildTicketId(documentId: string): string {
  const year = new Date().getUTCFullYear();
  const shortId = documentId.substring(0, 8).toUpperCase();
  return `SUP-${year}-${shortId}`;
}

function readRequiredString(
  value: unknown,
  message: string,
  maximumLength: number,
): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", message);
  }

  const normalized = value.trim();

  if (!normalized || normalized.length > maximumLength) {
    throw new HttpsError("invalid-argument", message);
  }

  return normalized;
}

function readOptionalString(
  value: unknown,
  maximumLength: number,
): string {
  if (typeof value !== "string") {
    return "";
  }

  const normalized = value.trim();

  if (normalized.length > maximumLength) {
    throw new HttpsError(
      "invalid-argument",
      "Gönderilen referans bilgisi geçersiz.",
    );
  }

  return normalized;
}

function readStringArray(
  value: unknown,
  maximumItems: number,
  maximumItemLength: number,
): string[] {
  if (value == null) {
    return [];
  }

  if (!Array.isArray(value) || value.length > maximumItems) {
    throw new HttpsError(
      "invalid-argument",
      "Ek dosya listesi geçersiz.",
    );
  }

  return value.map((item) => {
    if (typeof item !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "Ek dosya bilgisi geçersiz.",
      );
    }

    const normalized = item.trim();

    if (!normalized || normalized.length > maximumItemLength) {
      throw new HttpsError(
        "invalid-argument",
        "Ek dosya bilgisi geçersiz.",
      );
    }

    return normalized;
  });
}
