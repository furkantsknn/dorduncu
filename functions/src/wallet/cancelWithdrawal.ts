import {FieldValue} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/https";
import {firestore} from "../config/firebaseAdmin";

interface CancelWithdrawalData {
  withdrawalId: string;
}

export const cancelWithdrawal = onCall(
  {
    region: "europe-west1",
    enforceAppCheck: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication is required."
      );
    }

    const data = request.data as CancelWithdrawalData;

    if (
      !data.withdrawalId ||
      typeof data.withdrawalId !== "string"
    ) {
      throw new HttpsError(
        "invalid-argument",
        "withdrawalId is required."
      );
    }

    const uid = request.auth.uid;
    const withdrawalId = data.withdrawalId.trim();

    if (withdrawalId.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "withdrawalId is required."
      );
    }

    const walletRef = firestore
      .collection("wallets")
      .doc(uid);

    const withdrawalRef = walletRef
      .collection("withdrawals")
      .doc(withdrawalId);

    const transactionRef = walletRef
      .collection("transactions")
      .doc(`withdrawal_cancel_${withdrawalId}`);

    await firestore.runTransaction(
      async (transaction) => {
        const existingTransaction =
          await transaction.get(transactionRef);

        if (existingTransaction.exists) {
          return;
        }

        const withdrawalSnapshot =
          await transaction.get(withdrawalRef);

        if (!withdrawalSnapshot.exists) {
          throw new HttpsError(
            "not-found",
            "Withdrawal not found."
          );
        }

        const withdrawalData =
          withdrawalSnapshot.data() ?? {};

        if (withdrawalData.status !== "pending") {
          throw new HttpsError(
            "failed-precondition",
            "This withdrawal cannot be cancelled."
          );
        }

        const amountKurus =
          typeof withdrawalData.amountKurus ===
          "number" ?
            withdrawalData.amountKurus :
            0;

        if (amountKurus <= 0) {
          throw new HttpsError(
            "failed-precondition",
            "Invalid withdrawal amount."
          );
        }

        const walletSnapshot =
          await transaction.get(walletRef);

        if (!walletSnapshot.exists) {
          throw new HttpsError(
            "failed-precondition",
            "Wallet not found."
          );
        }

        const walletData =
          walletSnapshot.data() ?? {};

        const availableBalanceKurus =
          typeof walletData.availableBalanceKurus ===
          "number" ?
            walletData.availableBalanceKurus :
            0;

        const withdrawalPendingKurus =
          typeof walletData.withdrawalPendingKurus ===
          "number" ?
            walletData.withdrawalPendingKurus :
            0;

        if (withdrawalPendingKurus < amountKurus) {
          throw new HttpsError(
            "failed-precondition",
            "Invalid pending withdrawal balance."
          );
        }

        transaction.update(walletRef, {
          availableBalanceKurus:
            availableBalanceKurus + amountKurus,
          withdrawalPendingKurus:
            withdrawalPendingKurus - amountKurus,
          updatedAt:
            FieldValue.serverTimestamp(),
        });

        transaction.update(withdrawalRef, {
          status: "cancelled",
          cancelledAt:
            FieldValue.serverTimestamp(),
          updatedAt:
            FieldValue.serverTimestamp(),
        });

        transaction.set(transactionRef, {
          type: "withdrawal_cancelled",
          amountKurus,
          status: "completed",
          withdrawalId,
          description:
            "Para çekme talebi iptal edildi.",
          metadata: {},
          createdAt:
            FieldValue.serverTimestamp(),
          updatedAt:
            FieldValue.serverTimestamp(),
        });
      }
    );

    return {
      success: true,
      withdrawalId,
    };
  }
);
