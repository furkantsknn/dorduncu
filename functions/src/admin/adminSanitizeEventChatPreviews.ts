import {assertCurrentAdminSession} from "../security/adminAuthorization";
/* eslint-disable max-len */
import {
  FieldPath,
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";
import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  assertAdminPermission,
  getAdminRole,
} from "../security/adminAuthorization";
import {writeAuditLog} from "../audit/writeAuditLog";

const REGION = "europe-west1";
const PAGE_SIZE = 200;

/**
 * Removes private chat preview content from public canonical event documents.
 *
 * Run repeatedly with the returned cursor until done=true.
 */
export const adminSanitizeEventChatPreviews = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    assertAdminPermission(request, "events.moderate");
    await assertCurrentAdminSession(request);

    const adminUid = request.auth.uid;
    const adminRole = getAdminRole(request);
    const cursor = readOptionalCursor(request.data);

    const firestore = getFirestore();

    let query: FirebaseFirestore.Query =
      firestore
        .collection("events")
        .where("lifecycleVersion", "==", 2)
        .orderBy(FieldPath.documentId())
        .limit(PAGE_SIZE);

    if (cursor) {
      query = query.startAfter(cursor);
    }

    const snapshot = await query.get();

    if (snapshot.empty) {
      await writeAuditLog({
        action: "admin_sanitize_event_chat_previews",
        performedBy: adminUid,
        metadata: {
          processed: 0,
          updated: 0,
          done: true,
          performedByRole: adminRole,
        },
      });

      return {
        success: true,
        processed: 0,
        updated: 0,
        cursor: null,
        done: true,
      };
    }

    const writer = firestore.bulkWriter();
    let updated = 0;

    for (const document of snapshot.docs) {
      const data = document.data();
      const hasChatProjection =
        data.lastMessageAt != null ||
        String(data.lastMessageId ?? "").trim().length > 0 ||
        String(data.lastMessage ?? "").trim().length > 0;

      const exposesPrivatePreview =
        hasChatProjection &&
        (
          String(data.lastMessage ?? "").trim() !== "Yeni mesaj" ||
          String(data.lastMessageSenderName ?? "").trim().length > 0 ||
          String(data.lastMessageSenderPhotoUrl ?? "").trim().length > 0
        );

      if (!exposesPrivatePreview) {
        continue;
      }

      writer.update(
        document.ref,
        {
          lastMessage: "Yeni mesaj",
          lastMessageSenderName: FieldValue.delete(),
          lastMessageSenderPhotoUrl: FieldValue.delete(),
          chatPreviewPrivacyVersion: 1,
          chatPreviewSanitizedAt: FieldValue.serverTimestamp(),
        },
      );

      updated += 1;
    }

    await writer.close();

    const nextCursor =
      snapshot.docs[snapshot.docs.length - 1].id;
    const done = snapshot.size < PAGE_SIZE;

    await writeAuditLog({
      action: "admin_sanitize_event_chat_previews",
      performedBy: adminUid,
      metadata: {
        processed: snapshot.size,
        updated,
        cursor: nextCursor,
        done,
        performedByRole: adminRole,
      },
    });

    return {
      success: true,
      processed: snapshot.size,
      updated,
      cursor: done ? null : nextCursor,
      done,
    };
  },
);

/**
 * Reads an optional document-id cursor.
 *
 * @param {unknown} data Callable payload.
 * @return {string} Normalized cursor.
 */
function readOptionalCursor(data: unknown): string {
  if (
    data === null ||
    typeof data !== "object" ||
    Array.isArray(data)
  ) {
    return "";
  }

  const cursor = String(
    (data as Record<string, unknown>).cursor ?? "",
  ).trim();

  if (cursor.length > 1500) {
    throw new HttpsError(
      "invalid-argument",
      "Geçersiz devam anahtarı.",
    );
  }

  return cursor;
}
