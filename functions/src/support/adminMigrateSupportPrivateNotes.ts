/* eslint-disable require-jsdoc */
import {onCall} from "firebase-functions/v2/https";
import {
  FieldPath,
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";
import {assertSuperAdmin} from "../security/adminAuthorization";
import {writeAuditLog} from "../audit/writeAuditLog";

const REGION = "europe-west1";
const PAGE_SIZE = 200;

export const adminMigrateSupportPrivateNotes = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
    timeoutSeconds: 120,
  },
  async (request) => {
    assertSuperAdmin(request);

    const adminId = request.auth.uid;
    const firestore = getFirestore();
    const markerReference = firestore
      .collection("system_settings")
      .doc("supportPrivateNotesMigrationV1");
    const markerSnapshot = await markerReference.get();

    if (markerSnapshot.data()?.completed === true) {
      return {
        success: true,
        alreadyCompleted: true,
        migrated: 0,
        cleaned: 0,
      };
    }

    let lastDocumentId: string | null = null;
    let migrated = 0;
    let cleaned = 0;

    let hasMore = true;

    while (hasMore) {
      let query = firestore
        .collection("support_requests")
        .orderBy(FieldPath.documentId())
        .limit(PAGE_SIZE);

      if (lastDocumentId) {
        query = query.startAfter(lastDocumentId);
      }

      const snapshot = await query.get();

      if (snapshot.empty) {
        hasMore = false;
        continue;
      }

      const batch = firestore.batch();

      for (const document of snapshot.docs) {
        const data = document.data();

        if (!Object.prototype.hasOwnProperty.call(data, "adminNotes")) {
          continue;
        }

        const note = typeof data.adminNotes === "string" ?
          data.adminNotes.trim() :
          "";

        if (note) {
          batch.set(
            document.ref.collection("private").doc("admin"),
            {
              adminNotes: note,
              updatedAt: FieldValue.serverTimestamp(),
              updatedBy: adminId,
              migratedFromLegacy: true,
            },
            {merge: true},
          );
          migrated += 1;
        }

        batch.update(document.ref, {
          adminNotes: FieldValue.delete(),
        });
        cleaned += 1;
      }

      await batch.commit();
      lastDocumentId = snapshot.docs[snapshot.docs.length - 1].id;
      hasMore = snapshot.size == PAGE_SIZE;
    }

    await markerReference.set(
      {
        completed: true,
        completedAt: FieldValue.serverTimestamp(),
        completedBy: adminId,
        migrated,
        cleaned,
      },
      {merge: true},
    );

    await writeAuditLog({
      action: "admin_migrate_support_private_notes",
      performedBy: adminId,
      metadata: {
        migrated,
        cleaned,
      },
    });

    return {
      success: true,
      alreadyCompleted: false,
      migrated,
      cleaned,
    };
  },
);
