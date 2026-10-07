/* eslint-disable require-jsdoc */
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";

const REGION = "europe-west1";
const ACTIONS = new Set(["close", "reopen"]);

export const updateOwnSupportRequestStatus = onCall(
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

    const uid = request.auth.uid;
    const data = request.data as Record<string, unknown>;
    const requestId = readRequiredString(data.requestId, 128);
    const action = readRequiredString(data.action, 32);

    if (!ACTIONS.has(action)) {
      throw new HttpsError(
        "invalid-argument",
        "Geçersiz destek işlemi.",
      );
    }

    const firestore = getFirestore();
    const supportReference = firestore
      .collection("support_requests")
      .doc(requestId);

    await firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(supportReference);

      if (!snapshot.exists) {
        throw new HttpsError(
          "not-found",
          "Destek talebi bulunamadı.",
        );
      }

      const current = snapshot.data() ?? {};
      const ownerId = String(current.userId ?? "");
      const oldStatus = String(current.status ?? "new");

      if (ownerId !== uid) {
        throw new HttpsError(
          "permission-denied",
          "Bu destek talebine erişim yetkiniz yok.",
        );
      }

      const newStatus =
        action === "close" ? "closed" : "reviewing";

      if (oldStatus === newStatus) {
        return;
      }

      if (action === "reopen" && oldStatus !== "closed") {
        throw new HttpsError(
          "failed-precondition",
          "Yalnızca kapatılmış talepler yeniden açılabilir.",
        );
      }

      transaction.set(
        supportReference,
        {
          status: newStatus,
          closedAt:
            action === "close" ?
              FieldValue.serverTimestamp() :
              null,
          updatedAt: FieldValue.serverTimestamp(),
          isReadByAdmin:
            action === "close" ? true : false,
          isReadByUser: true,
        },
        {merge: true},
      );

      transaction.set(
        supportReference.collection("history").doc(),
        {
          action:
            action === "close" ?
              "closed_by_user" :
              "reopened_by_user",
          oldStatus,
          newStatus,
          performedByUid: uid,
          performedByRole: "user",
          note: "",
          visibleToUser: true,
          createdAt: FieldValue.serverTimestamp(),
        },
      );
    });

    return {success: true};
  },
);

function readRequiredString(
  value: unknown,
  maxLength: number,
): string {
  if (typeof value !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "Eksik veya geçersiz veri.",
    );
  }

  const normalized = value.trim();

  if (!normalized || normalized.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      "Eksik veya geçersiz veri.",
    );
  }

  return normalized;
}
