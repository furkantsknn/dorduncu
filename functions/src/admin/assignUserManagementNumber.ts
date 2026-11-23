import {getFirestore} from "firebase-admin/firestore";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {ensureUserManagementNumber} from "./managementNumberPolicy";

const REGION = "europe-west1";

export const assignUserManagementNumber = onDocumentCreated(
  {document: "users/{uid}", region: REGION},
  async (event) => {
    const uid = String(event.params.uid ?? "").trim();
    if (!uid) return;
    const db = getFirestore();
    await db.runTransaction((transaction) =>
      ensureUserManagementNumber(db, transaction, uid));
  },
);
