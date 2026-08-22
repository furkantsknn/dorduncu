import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  FieldValue,
} from "firebase-admin/firestore";

import {firestore} from "../config/firebaseAdmin";

interface SubmitVerificationRequest {
  identityFrontUrl?: unknown;
  identityBackUrl?: unknown;
  criminalRecordUrl?: unknown;
  selfieUrl?: unknown;
}

const allowedStorageBuckets = new Set([
  "dorduncu-8e599.firebasestorage.app",
  "dorduncu-8e599.appspot.com",
]);

/**
 * Validates a Firebase Storage verification document URL.
 * @param {string} value Document URL.
 * @param {string} uid Authenticated user id.
 * @return {boolean} Whether the URL belongs to the user.
 */
function isValidVerificationDocumentUrl(
  value: string,
  uid: string,
): boolean {
  try {
    const url = new URL(value);

    if (
      url.protocol !== "https:" ||
      url.hostname !==
        "firebasestorage.googleapis.com"
    ) {
      return false;
    }

    const parts =
      url.pathname
        .split("/")
        .filter(
          (part) => part.length > 0,
        );

    if (
      parts.length < 5 ||
      parts[0] !== "v0" ||
      parts[1] !== "b" ||
      parts[3] !== "o"
    ) {
      return false;
    }

    const bucket =
      decodeURIComponent(
        parts[2],
      );

    if (
      !allowedStorageBuckets.has(
        bucket,
      )
    ) {
      return false;
    }

    const encodedObjectPath =
      parts
        .slice(4)
        .join("/");

    const objectPath =
      decodeURIComponent(
        encodedObjectPath,
      );

    const requiredPrefix =
      `verification_documents/${uid}/`;

    if (
      !objectPath.startsWith(
        requiredPrefix,
      )
    ) {
      return false;
    }

    const relativePath =
      objectPath.slice(
        requiredPrefix.length,
      );

    if (
      !relativePath ||
      relativePath.startsWith("/") ||
      relativePath.includes("../") ||
      relativePath.includes("/../") ||
      relativePath.includes("\\")
    ) {
      return false;
    }

    return true;
  } catch {
    return false;
  }
}

export const submitVerification = onCall(
  {
    region: "europe-west1",
    enforceAppCheck: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Bu işlem için giriş yapmalısınız.",
      );
    }

    const uid =
      request.auth.uid;

    const data =
      request.data as SubmitVerificationRequest;

    const identityFrontUrl =
      typeof data.identityFrontUrl ===
        "string" ?
        data.identityFrontUrl.trim() :
        "";

    const identityBackUrl =
      typeof data.identityBackUrl ===
        "string" ?
        data.identityBackUrl.trim() :
        "";

    const criminalRecordUrl =
      typeof data.criminalRecordUrl ===
        "string" ?
        data.criminalRecordUrl.trim() :
        "";

    const selfieUrl =
      typeof data.selfieUrl ===
        "string" ?
        data.selfieUrl.trim() :
        "";

    if (
      !identityFrontUrl ||
      !identityBackUrl ||
      !criminalRecordUrl ||
      !selfieUrl
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Doğrulama belgeleri eksik.",
      );
    }

    const documentUrls = [
      identityFrontUrl,
      identityBackUrl,
      criminalRecordUrl,
      selfieUrl,
    ];

    const allDocumentsValid =
      documentUrls.every(
        (url) =>
          isValidVerificationDocumentUrl(
            url,
            uid,
          ),
      );

    if (!allDocumentsValid) {
      throw new HttpsError(
        "permission-denied",
        "Doğrulama belgelerinden biri geçersiz " +
          "veya bu kullanıcıya ait değil.",
      );
    }

    const userReference =
      firestore
        .collection("users")
        .doc(uid);

    const userSnapshot =
      await userReference.get();

    if (!userSnapshot.exists) {
      throw new HttpsError(
        "failed-precondition",
        "Kullanıcı profili bulunamadı.",
      );
    }

    const userData =
      userSnapshot.data() ?? {};

    if (
      userData.verified === true ||
      userData.verificationStatus ===
        "approved"
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Kullanıcı zaten doğrulanmış.",
      );
    }

    const verificationReference =
      firestore
        .collection(
          "verification_requests",
        )
        .doc(uid);

    const batch =
      firestore.batch();

    batch.set(
      verificationReference,
      {
        uid,
        ad:
          userData.ad ?? "",
        soyad:
          userData.soyad ?? "",
        telefon:
          userData.telefon ?? "",
        dogumTarihi:
          userData.dogumTarihi ?? null,

        identityFrontUrl,
        identityBackUrl,
        criminalRecordUrl,
        selfieUrl,

        status: "pending",

        automaticCheckStatus:
          "pending",

        identityFrontCheck: {
          status: "pending",
          reason: "",
        },

        identityBackCheck: {
          status: "pending",
          reason: "",
        },

        criminalRecordCheck: {
          status: "pending",
          reason: "",
        },

        selfieCheck: {
          status: "pending",
          reason: "",
        },

        identityUniquenessCheck: {
          status: "pending",
          reason: "",
        },

        automaticCheckCompletedAt:
          null,

        createdAt:
          FieldValue.serverTimestamp(),

        updatedAt:
          FieldValue.serverTimestamp(),
      },
      {
        merge: false,
      },
    );

    batch.set(
      userReference,
      {
        verified: false,
        verificationStatus:
          "pending",
        verificationSkipped:
          false,
        guncellemeTarihi:
          FieldValue.serverTimestamp(),
      },
      {
        merge: true,
      },
    );

    await batch.commit();

    return {
      success: true,
      status: "pending",
    };
  },
);
