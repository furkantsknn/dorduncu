import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {getAuth} from "firebase-admin/auth";
import {getFirestore, FieldValue} from "firebase-admin/firestore";

export const processAccountDeletion = onDocumentCreated(
  "accountDeletionRequests/{uid}",
  async (event) => {
    const uid = event.params.uid;
    const db = getFirestore();

    await db.collection("users").doc(uid).set(
      {
        accountStatus: "deleted",
        deletedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    try {
      await getAuth().deleteUser(uid);
    } catch (error) {
      console.error("Firebase Auth user deletion failed:", uid, error);
      throw error;
    }

    await event.data?.ref.set(
      {
        status: "completed",
        completedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  },
);
