import {FieldValue} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/https";
import {firestore} from "../config/firebaseAdmin";

interface RequestWithdrawalData {
  amountKurus: number;
  iban: string;
  accountHolderName: string;
}

export const requestWithdrawal = onCall(
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

    const data = request.data as RequestWithdrawalData;

    if (
      typeof data.amountKurus !== "number" ||
      !Number.isInteger(data.amountKurus) ||
      data.amountKurus <= 0
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid withdrawal amount."
      );
    }

    if (typeof data.iban !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "Invalid IBAN."
      );
    }

    if (typeof data.accountHolderName !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "Invalid account holder name."
      );
    }

    const uid = request.auth.uid;

    const iban = data.iban
      .replace(/\s/g, "")
      .toUpperCase();

    const accountHolderName =
      data.accountHolderName.trim();

    if (!/^TR\d{24}$/.test(iban)) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid Turkish IBAN."
      );
    }

    if (accountHolderName.length < 3) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid account holder name."
      );
    }

    const walletRef = firestore
      .collection("wallets")
      .doc(uid);

    const withdrawalRef = walletRef
      .collection("withdrawals")
      .doc();

    const transactionRef = walletRef
      .collection("transactions")
      .doc(`withdrawal_request_${withdrawalRef.id}`);

    await firestore.runTransaction(
      async (transaction) => {
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

        if (walletData.isFrozen === true) {
          throw new HttpsError(
            "failed-precondition",
            "Wallet is frozen."
          );
        }

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

        if (
          availableBalanceKurus <
          data.amountKurus
        ) {
          throw new HttpsError(
            "failed-precondition",
            "Insufficient balance."
          );
        }

        transaction.update(walletRef, {
          availableBalanceKurus:
            availableBalanceKurus -
            data.amountKurus,
          withdrawalPendingKurus:
            withdrawalPendingKurus +
            data.amountKurus,
          updatedAt:
            FieldValue.serverTimestamp(),
        });

        transaction.set(withdrawalRef, {
          amountKurus: data.amountKurus,
          iban,
          accountHolderName,
          status: "pending",
          createdAt:
            FieldValue.serverTimestamp(),
          updatedAt:
            FieldValue.serverTimestamp(),
        });

        transaction.set(transactionRef, {
          type: "withdrawal_requested",
          amountKurus: data.amountKurus,
          status: "pending",
          withdrawalId: withdrawalRef.id,
          description:
            "Para çekme talebi oluşturuldu.",
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
      withdrawalId: withdrawalRef.id,
    };
  }
);
