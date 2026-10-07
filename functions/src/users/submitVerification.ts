import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  FieldValue,
} from "firebase-admin/firestore";

import {firestore} from "../config/firebaseAdmin";
import {
  assertVerificationObject,
  rotateDownloadToken,
  verificationObjectPath,
} from "./verificationDocumentStorage";

interface SubmitVerificationRequest {
  identityFrontPath?: unknown;
  identityBackPath?: unknown;
  criminalRecordPath?: unknown;
  selfiePath?: unknown;
  identityFrontUrl?: unknown;
  identityBackUrl?: unknown;
  criminalRecordUrl?: unknown;
  selfieUrl?: unknown;
}

/**
 * Prefers a private path and falls back to a validated legacy URL.
 * @param {unknown} pathValue Private Storage path.
 * @param {unknown} legacyUrl Previous Firebase download URL.
 * @param {string} uid Authenticated user id.
 * @return {string} Valid object path or an empty string.
 */
function readDocumentPath(
  pathValue: unknown,
  legacyUrl: unknown,
  uid: string,
): string {
  const preferred =
    verificationObjectPath(
      pathValue,
      uid,
    );

  if (preferred) {
    return preferred;
  }

  return verificationObjectPath(
    legacyUrl,
    uid,
  );
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
      request.data as
        SubmitVerificationRequest;

    const identityFrontPath =
      readDocumentPath(
        data.identityFrontPath,
        data.identityFrontUrl,
        uid,
      );

    const selfiePath =
      readDocumentPath(
        data.selfiePath,
        data.selfieUrl,
        uid,
      );

    const documentPaths = [
      identityFrontPath,
      selfiePath,
    ];

    if (
      documentPaths.some(
        (path) => !path,
      )
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Doğrulama belgeleri eksik " +
          "veya geçersiz.",
      );
    }

    try {
      await Promise.all(
        documentPaths.map(
          (path) =>
            assertVerificationObject(path),
        ),
      );

      await Promise.all(
        documentPaths.map(
          (path) =>
            rotateDownloadToken(path),
        ),
      );
    } catch (error) {
      console.error(
        "Verification Storage doğrulaması başarısız.",
        error,
      );

      throw new HttpsError(
        "failed-precondition",
        "Doğrulama belgelerine güvenli " +
          "şekilde erişilemedi.",
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

        identityFrontPath,
        selfiePath,

        identityFrontUrl:
          FieldValue.delete(),
        identityBackPath:
          FieldValue.delete(),
        criminalRecordPath:
          FieldValue.delete(),
        identityBackUrl:
          FieldValue.delete(),
        criminalRecordUrl:
          FieldValue.delete(),
        selfieUrl:
          FieldValue.delete(),
        identityBackCheck:
          FieldValue.delete(),
        criminalRecordCheck:
          FieldValue.delete(),

        status: "pending",

        automaticCheckStatus:
          "pending",

        identityFrontCheck: {
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

        documentRetentionPolicy:
          "final_decision_30_days",
        deletionRequestedAt:
          FieldValue.delete(),
        deletionStatus:
          FieldValue.delete(),
        documentsDeletedAt:
          FieldValue.delete(),

        createdAt:
          FieldValue.serverTimestamp(),

        updatedAt:
          FieldValue.serverTimestamp(),
      },
      {
        merge: true,
      },
    );

    batch.set(
      userReference,
      {
        verified: false,
        verificationStatus:
          "pending",
        verificationRejectionReason:
          "",
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
      requestId: uid,
    };
  },
);
