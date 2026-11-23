import {
  randomUUID,
} from "node:crypto";

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
import {
  VerificationObjectVersion,
} from "./verificationCleanupPolicy";

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
    const submissionId = randomUUID();

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
      const versions = await Promise.all(
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

      await commitVerificationSubmission({
        uid,
        submissionId,
        identityFrontPath,
        selfiePath,
        versions,
      });
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
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

    return {
      success: true,
      requestId: uid,
    };
  },
);

interface CommitSubmissionInput {
  uid: string;
  submissionId: string;
  identityFrontPath: string;
  selfiePath: string;
  versions: VerificationObjectVersion[];
}

/**
 * Commits a submission while preventing reuse of an earlier object path.
 * @param {CommitSubmissionInput} input Immutable submission input.
 * @return {Promise<void>} Completion promise.
 */
export async function commitVerificationSubmission(
  input: CommitSubmissionInput,
): Promise<void> {
  const userReference = firestore.collection("users").doc(input.uid);
  const requestReference = firestore
    .collection("verification_requests")
    .doc(input.uid);

  await firestore.runTransaction(async (transaction) => {
    const userSnapshot = await transaction.get(userReference);
    const requestSnapshot = await transaction.get(requestReference);
    if (!userSnapshot.exists) {
      throw new HttpsError(
        "failed-precondition",
        "Kullanıcı profili bulunamadı.",
      );
    }

    const userData = userSnapshot.data() ?? {};
    if (userData.accountStatus !== "active") {
      throw new HttpsError(
        "failed-precondition",
        "Hesap doğrulama başvurusu için etkin olmalıdır.",
      );
    }
    if (
      userData.verified === true ||
      userData.verificationStatus === "approved"
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Kullanıcı zaten doğrulanmış.",
      );
    }

    const previous = requestSnapshot.data() ?? {};
    const previousPaths = new Set([
      previous.identityFrontPath,
      previous.identityBackPath,
      previous.criminalRecordPath,
      previous.selfiePath,
    ].filter((value): value is string =>
      typeof value === "string" && value.length > 0,
    ));
    const sameSubmissionObjects =
      previous.identityFrontPath === input.identityFrontPath &&
      previous.selfiePath === input.selfiePath &&
      ["pending", "approved", "rejected"].includes(
        String(previous.status ?? ""),
      );
    if (sameSubmissionObjects) {
      // A callable response may be lost after the transaction commits. The
      // same immutable object pair is an idempotent retry, not a new request.
      return;
    }
    if (
      previousPaths.has(input.identityFrontPath) ||
      previousPaths.has(input.selfiePath)
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Yeni başvuru için yeni belge yüklemeleri gerekiyor.",
      );
    }

    const versionByPath = new Map(
      input.versions.map((version) => [version.path, version.generation]),
    );
    transaction.set(requestReference, {
      uid: input.uid,
      ad: userData.ad ?? "",
      soyad: userData.soyad ?? "",
      telefon: userData.telefon ?? "",
      dogumTarihi: userData.dogumTarihi ?? null,
      identityFrontPath: input.identityFrontPath,
      selfiePath: input.selfiePath,
      verificationDocumentObjects: {
        identityFrontPath: {
          path: input.identityFrontPath,
          generation: versionByPath.get(input.identityFrontPath),
        },
        selfiePath: {
          path: input.selfiePath,
          generation: versionByPath.get(input.selfiePath),
        },
      },
      identityFrontUrl: FieldValue.delete(),
      identityBackPath: FieldValue.delete(),
      criminalRecordPath: FieldValue.delete(),
      identityBackUrl: FieldValue.delete(),
      criminalRecordUrl: FieldValue.delete(),
      selfieUrl: FieldValue.delete(),
      identityBackCheck: FieldValue.delete(),
      criminalRecordCheck: FieldValue.delete(),
      status: "pending",
      submissionId: input.submissionId,
      automaticCheckStatus: "pending",
      reasonCode: FieldValue.delete(),
      decisionSource: FieldValue.delete(),
      decidedAt: FieldValue.delete(),
      decisionVersion: FieldValue.delete(),
      retentionStartedAt: FieldValue.delete(),
      legacyCleanupStatus: FieldValue.delete(),
      rejectionReason: FieldValue.delete(),
      identityFrontCheck: {status: "pending", reason: ""},
      selfieCheck: {status: "pending", reason: ""},
      identityUniquenessCheck: {status: "pending", reason: ""},
      automaticCheckCompletedAt: null,
      documentRetentionPolicy: "final_decision_30_days",
      deletionRequestedAt: FieldValue.delete(),
      deletionStatus: FieldValue.delete(),
      documentDeletionOperation: FieldValue.delete(),
      documentsDeletedAt: FieldValue.delete(),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});

    transaction.set(userReference, {
      verified: false,
      verificationStatus: "pending",
      verificationReasonCode: FieldValue.delete(),
      verificationDecisionSource: FieldValue.delete(),
      verificationDecidedAt: FieldValue.delete(),
      verificationRejectionReason: FieldValue.delete(),
      guncellemeTarihi: FieldValue.serverTimestamp(),
    }, {merge: true});
  });
}
