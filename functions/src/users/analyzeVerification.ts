import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  onDocumentWritten,
} from "firebase-functions/v2/firestore";
import {
  FieldValue,
  Timestamp,
} from "firebase-admin/firestore";
import vision from "@google-cloud/vision";

import {firestore} from "../config/firebaseAdmin";
import {
  readVerificationObject,
  verificationObjectPath,
} from "./verificationDocumentStorage";
import {
  assertVerificationAssignment,
} from "../security/assertVerificationAssignment";
import {
  defineSecret,
} from "firebase-functions/params";
import {
  createHmac,
} from "node:crypto";
import {
  classifyIdentityTerms,
  decideVerification,
  VerificationCheck,
} from "./verificationDecision";
import {
  identityKeyFromData,
  ownerApprovedFromUser,
  planIdentityReservationRelease,
} from "./identityReservationPolicy";
import {
  writeAuditLogInTransaction,
} from "../audit/writeAuditLog";
import {
  assertDecisionWriteAllowed,
  verificationDecisionRetentionFields,
} from "./verificationRetentionPolicy";
import {
  evaluateVerificationQueueRecovery,
} from "./verificationQueuePolicy";

interface AnalyzeVerificationRequest {
  requestId?: unknown;
}

interface CheckResult extends VerificationCheck {
  reason: string;
}

const visionClient =
  new vision.ImageAnnotatorClient();
const identityHmacSecret =
    defineSecret(
      "IDENTITY_HMAC_SECRET",
    );

/**
   * Validates a Turkish identity number.
   * @param {string} value Candidate TCKN.
   * @return {boolean} Whether the TCKN is valid.
   */
function isValidTckn(
  value: string,
): boolean {
  if (!/^[1-9][0-9]{10}$/.test(value)) {
    return false;
  }

  const digits =
      value
        .split("")
        .map(Number);

  const oddSum =
      digits[0] +
      digits[2] +
      digits[4] +
      digits[6] +
      digits[8];

  const evenSum =
      digits[1] +
      digits[3] +
      digits[5] +
      digits[7];

  const tenth =
      (
        oddSum * 7 -
        evenSum
      ) % 10;

  if (
    tenth !== digits[9]
  ) {
    return false;
  }

  const firstTenSum =
      digits
        .slice(0, 10)
        .reduce(
          (sum, digit) =>
            sum + digit,
          0,
        );

  return (
    firstTenSum % 10 ===
      digits[10]
  );
}

/**
   * Finds a valid TCKN in OCR text.
   * @param {string} text OCR text.
   * @return {string|null} TCKN or null.
   */
function extractTckn(
  text: string,
): string | null {
  const compactCandidates =
      text.match(
        /(?<!\d)\d{11}(?!\d)/g,
      ) ?? [];

  for (
    const candidate
    of compactCandidates
  ) {
    if (
      isValidTckn(candidate)
    ) {
      return candidate;
    }
  }

  const digitsOnly =
      text.replace(
        /\D/g,
        " ",
      );

  const candidates =
      digitsOnly
        .split(/\s+/)
        .filter(
          (value) =>
            value.length === 11,
        );

  for (
    const candidate
    of candidates
  ) {
    if (
      isValidTckn(candidate)
    ) {
      return candidate;
    }
  }

  return null;
}

/**
   * Reads TCKN from identity front image.
   * @param {string} objectPath Private Storage object path.
   * @return {Promise<string|null>} TCKN or null.
   */
async function readIdentityTckn(
  objectPath: string,
): Promise<string | null> {
  try {
    const content =
      await readVerificationObject(
        objectPath,
      );

    const [result] =
      await visionClient.textDetection(
        content,
      );

    const detectedText =
        result.fullTextAnnotation?.text ??
        result.textAnnotations?.[0]
          ?.description ??
        "";

    return extractTckn(
      detectedText,
    );
  } catch {
    console.error(
      "TCKN OCR hatası",
    );

    return null;
  }
}

/**
   * Creates a non-reversible identity fingerprint.
   * @param {string} tckn Turkish identity number.
   * @return {string} HMAC fingerprint.
   */
function createIdentityFingerprint(
  tckn: string,
): string {
  return createHmac(
    "sha256",
    identityHmacSecret.value(),
  )
    .update(
      `tckn:${tckn}`,
    )
    .digest("hex");
}

/**
   * Reserves an identity for one account and submission.
   * An approved or blocked key is not replaced.
   * @param {string} uid User id.
   * @param {string} fingerprint Identity fingerprint.
   * @param {string} submissionId Current application submission.
   * @return {Promise<CheckResult>} Uniqueness result.
   */
async function reserveIdentity(
  uid: string,
  fingerprint: string,
  submissionId: string,
): Promise<CheckResult> {
  const reference =
      firestore
        .collection(
          "verification_identity_keys",
        )
        .doc(fingerprint);

  return firestore.runTransaction(
    async (transaction) => {
      const snapshot =
          await transaction.get(
            reference,
          );

      if (snapshot.exists) {
        const current =
            snapshot.data() ?? {};

        const ownerUid =
            current.uid
              ?.toString()
              .trim() ?? "";

        if (
          ownerUid &&
            ownerUid !== uid
        ) {
          return {
            status: "failed",
            reasonCode: "identity_already_used",
            reason:
                "Bu kimlik başka bir hesapta daha önce kullanılmış.",
          };
        }

        const currentStatus =
            current.status
              ?.toString()
              .trim() ?? "";

        if (
          currentStatus === "approved" ||
          currentStatus === "blocked_after_deletion" ||
          current.approvedAt != null
        ) {
          return {
            status: "passed",
            reasonCode: "identity_unique",
            reason:
                "Kimlik bu hesaba ait önceki başvuruyla eşleşiyor.",
          };
        }

        transaction.set(
          reference,
          {
            uid,
            status: "reserved",
            submissionId,
            updatedAt:
                FieldValue.serverTimestamp(),
          },
          {
            merge: true,
          },
        );

        return {
          status: "passed",
          reasonCode: "identity_unique",
          reason:
              "Kimlik bu hesaba ait önceki başvuruyla eşleşiyor.",
        };
      }

      transaction.set(
        reference,
        {
          uid,
          status: "reserved",
          submissionId,
          createdAt:
              FieldValue.serverTimestamp(),
          updatedAt:
              FieldValue.serverTimestamp(),
        },
      );

      return {
        status: "passed",
        reasonCode: "identity_unique",
        reason:
            "Kimlik başka bir hesapta kullanılmamış.",
      };
    },
  );
}

/**
 * Normalizes OCR text.
 * @param {string} value Raw OCR text.
 * @return {string} Normalized text.
 */
function normalizeText(
  value: string,
): string {
  return value
    .toLocaleLowerCase("tr-TR")
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * Checks OCR text from an image.
 * @param {string} objectPath Private Storage object path.
 * @param {string[]} requiredTerms Expected terms.
 * @param {string} documentName Document name.
 * @return {Promise<CheckResult>} Check result.
 */
async function analyzeTextDocument(
  objectPath: string,
  requiredTerms: string[],
  documentName: string,
): Promise<CheckResult> {
  try {
    const content =
      await readVerificationObject(
        objectPath,
      );

    const [result] =
      await visionClient.textDetection(
        content,
      );

    const detectedText =
      result.fullTextAnnotation?.text ??
      result.textAnnotations?.[0]
        ?.description ??
      "";

    const normalized =
      normalizeText(detectedText);

    if (!normalized) {
      return {
        status: "unavailable",
        reasonCode: "identity_text_unreadable",
        reason:
          `${documentName} üzerinde okunabilir metin tespit edilemedi.`,
      };
    }

    const classified =
      classifyIdentityTerms({
        readable: true,
        termsMatched: requiredTerms.some(
          (term) =>
            normalized.includes(
              normalizeText(term),
            ),
        ),
      });

    return {
      status: classified.status,
      reasonCode: classified.reasonCode,
      reason: classified.status === "passed" ?
        "Belge okunabilir ve temel belge kontrolü başarılı." :
        `${documentName} üzerindeki metin otomatik olarak doğrulanamadı.`,
    };
  } catch {
    console.error(
      `${documentName} analiz hatası`,
    );

    return {
      status: "unavailable",
      reasonCode: "identity_ocr_unavailable",
      reason:
        `${documentName} otomatik olarak analiz edilemedi.`,
    };
  }
}

/**
 * Checks whether selfie has one face.
 * @param {string} objectPath Private Storage object path.
 * @return {Promise<CheckResult>} Check result.
 */
async function analyzeSelfie(
  objectPath: string,
): Promise<CheckResult> {
  try {
    const content =
      await readVerificationObject(
        objectPath,
      );

    const [result] =
      await visionClient.faceDetection(
        content,
      );

    const faces =
      result.faceAnnotations ?? [];

    if (faces.length === 0) {
      return {
        status: "failed",
        reasonCode: "selfie_no_face",
        reason:
          "Uygun selfie bulunamadı.",
      };
    }

    if (faces.length > 1) {
      return {
        status: "failed",
        reasonCode: "selfie_multiple_faces",
        reason:
          "Uygun selfie bulunamadı.",
      };
    }

    return {
      status: "passed",
      reasonCode: "selfie_single_face",
      reason:
        "Selfie görüntüsünde tek yüz tespit edildi.",
    };
  } catch {
    console.error(
      "Selfie analiz hatası",
    );

    return {
      status: "unavailable",
      reasonCode: "selfie_analysis_unavailable",
      reason:
        "Selfie otomatik olarak analiz edilemedi.",
    };
  }
}

/**
 * Runs verification analysis.
 * @param {string} requestId Verification request id.
 * @param {boolean} allowManualRerun Allow admin to re-run pending analysis.
 * @return {Promise<void>} Completion promise.
 */
export async function runVerificationAnalysis(
  requestId: string,
  allowManualRerun = false,
): Promise<void> {
  if (process.env.FUNCTIONS_EMULATOR === "true" ||
      process.env.FIRESTORE_EMULATOR_HOST) {
    // The synthetic review workflow remains manual; Dev never invokes Vision.
    return;
  }
  const verificationReference =
    firestore
      .collection(
        "verification_requests",
      )
      .doc(requestId);

  const snapshot =
    await verificationReference.get();

  if (!snapshot.exists) {
    throw new HttpsError(
      "not-found",
      "Doğrulama başvurusu bulunamadı.",
    );
  }

  const verificationData =
    snapshot.data() ?? {};

  const uid =
      verificationData.uid
        ?.toString()
        .trim() ?? "";

  if (!uid) {
    throw new HttpsError(
      "failed-precondition",
      "Başvurunun kullanıcı kimliği bulunamadı.",
    );
  }

  const identityFrontPath =
    verificationObjectPath(
      verificationData.identityFrontPath ??
        verificationData.identityFrontUrl,
      uid,
    );

  const selfiePath =
    verificationObjectPath(
      verificationData.selfiePath ??
        verificationData.selfieUrl,
      uid,
    );

  if (
    !identityFrontPath ||
    !selfiePath
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Başvuru belgeleri eksik.",
    );
  }

  const submissionId =
    verificationData.submissionId
      ?.toString()
      .trim() ?? "";

  const claimed =
    await firestore.runTransaction(
      async (transaction) => {
        const fresh =
          await transaction.get(
            verificationReference,
          );
        const freshData =
          fresh.data() ?? {};
        const freshSubmission =
          freshData.submissionId
            ?.toString()
            .trim() ?? "";

        if (
          submissionId &&
          freshSubmission !== submissionId
        ) {
          return false;
        }

        const currentStatus =
          freshData.status?.toString().trim() ?? "";
        const currentCheckStatus =
          freshData.automaticCheckStatus?.toString().trim() ?? "";
        const attemptCount = Number(
          freshData.automaticCheckAttemptCount ?? 0,
        );
        const startedAt =
          freshData.automaticCheckStartedAt instanceof Timestamp ?
            freshData.automaticCheckStartedAt.toMillis() :
            null;
        const updatedAt =
          freshData.updatedAt instanceof Timestamp ?
            freshData.updatedAt.toMillis() :
            null;

        const queueDecision = evaluateVerificationQueueRecovery({
          status: currentStatus,
          automaticCheckStatus: currentCheckStatus,
          attemptCount,
          processingStartedAtMs: startedAt,
          lastAttemptAtMs: updatedAt,
          nowMs: Date.now(),
        });

        const manualEligible =
          allowManualRerun &&
          currentStatus === "pending" &&
          currentCheckStatus !== "processing";

        if (queueDecision.action === "escalate_manual_review" &&
            !manualEligible) {
          transaction.update(
            verificationReference,
            {
              automaticCheckStatus: "needs_review",
              reasonCode: queueDecision.reasonCode,
              decisionSource: "automatic",
              updatedAt: FieldValue.serverTimestamp(),
            },
          );
          return false;
        }

        if (queueDecision.action !== "retry" && !manualEligible) {
          return false;
        }

        transaction.update(
          verificationReference,
          {
            automaticCheckStatus:
              "processing",
            automaticCheckAttemptCount:
              manualEligible ?
                Math.max(1, attemptCount + 1) :
                queueDecision.nextAttemptCount,
            automaticCheckStartedAt:
              FieldValue.serverTimestamp(),
            updatedAt:
              FieldValue.serverTimestamp(),
          },
        );

        return true;
      },
    );

  if (!claimed) {
    return;
  }

  const tckn =
  await readIdentityTckn(
    identityFrontPath,
  );

  let identityFingerprint = "";

  let identityUniquenessCheck:
  CheckResult;

  if (!tckn) {
    identityUniquenessCheck = {
      status: "unavailable",
      reasonCode: "tckn_unreadable",
      reason:
      "Kimlik numarası otomatik okunamadı.",
    };
  } else {
    identityFingerprint =
    createIdentityFingerprint(
      tckn,
    );

    identityUniquenessCheck =
    await reserveIdentity(
      uid,
      identityFingerprint,
      submissionId,
    );
  }

  const [
    identityFrontCheck,
    selfieCheck,
  ] = await Promise.all([
    analyzeTextDocument(
      identityFrontPath,
      [
        "türkiye cumhuriyeti",
        "republic of turkey",
        "kimlik kartı",
      ],
      "Kimlik ön yüzü",
    ),
    analyzeSelfie(
      selfiePath,
    ),
  ]);

  const checks = [
    identityFrontCheck,
    selfieCheck,
    identityUniquenessCheck,
  ];


  const decision =
    decideVerification(checks);

  const stillCurrent =
    await firestore.runTransaction(
      async (transaction) => {
        const fresh =
          await transaction.get(
            verificationReference,
          );
        const freshData =
          fresh.data() ?? {};
        const freshSubmission =
          freshData.submissionId
            ?.toString()
            .trim() ?? "";

        if (
          submissionId &&
          freshSubmission !== submissionId
        ) {
          return false;
        }

        if (freshData.status !== "pending") {
          return false;
        }

        assertDecisionWriteAllowed(freshData, submissionId);

        const userReference =
          firestore.collection("users").doc(uid);
        const userSnapshot =
          await transaction.get(userReference);
        let releaseReservation = false;

        if (
          decision.status === "rejected" &&
          identityUniquenessCheck.status ===
            "passed" &&
          identityFingerprint
        ) {
          const identityReference =
            firestore
              .collection(
                "verification_identity_keys",
              )
              .doc(identityFingerprint);
          const identitySnapshot =
            await transaction.get(
              identityReference,
            );
          const plan =
            planIdentityReservationRelease({
              key: identityKeyFromData(
                identitySnapshot.data(),
                identitySnapshot.exists,
              ),
              request: {
                uid,
                status: "rejected",
                submissionId,
              },
              ownerApproved:
                ownerApprovedFromUser(
                  userSnapshot.data(),
                ),
            });

          releaseReservation = plan.release;
        }

        const userUpdate =
          decision.userStatus === "rejected" ?
            {
              verified: false,
              verificationStatus: "rejected",
              verificationReasonCode:
                decision.reasonCode,
              verificationDecisionSource:
                decision.decisionSource,
              verificationDecidedAt:
                FieldValue.serverTimestamp(),
              verificationRejectionReason:
                FieldValue.delete(),
              guncellemeTarihi:
                FieldValue.serverTimestamp(),
            } :
            {
              verified: false,
              verificationStatus: "pending",
              verificationReasonCode:
                FieldValue.delete(),
              verificationDecisionSource:
                FieldValue.delete(),
              verificationDecidedAt:
                FieldValue.delete(),
              verificationRejectionReason:
                FieldValue.delete(),
              guncellemeTarihi:
                FieldValue.serverTimestamp(),
            };

        transaction.update(
          verificationReference,
          {
            identityFrontCheck,
            identityBackCheck:
              FieldValue.delete(),
            criminalRecordCheck:
              FieldValue.delete(),
            selfieCheck,
            identityUniquenessCheck,
            identityFingerprint:
              identityUniquenessCheck.status ===
                "passed" ?
                identityFingerprint :
                FieldValue.delete(),
            automaticCheckStatus:
              decision.automaticCheckStatus,
            status: decision.status,
            ...verificationDecisionRetentionFields(decision.status),
            reasonCode: decision.reasonCode,
            decisionSource:
              decision.decisionSource,
            decidedAt:
              decision.status === "rejected" ?
                FieldValue.serverTimestamp() :
                FieldValue.delete(),
            rejectionReason:
              FieldValue.delete(),
            automaticCheckCompletedAt:
              FieldValue.serverTimestamp(),
            updatedAt:
              FieldValue.serverTimestamp(),
          },
        );

        transaction.set(
          userReference,
          userUpdate,
          {merge: true},
        );

        if (releaseReservation) {
          transaction.delete(
            firestore
              .collection(
                "verification_identity_keys",
              )
              .doc(identityFingerprint),
          );
          writeAuditLogInTransaction(
            firestore,
            transaction,
            {
              action:
                "verification_identity_reservation_released",
              performedBy:
                "system:verification_analysis",
              targetUid: uid,
              metadata: {
                requestStatus: "rejected",
                outcome: "released",
              },
            },
          );
        }

        return true;
      },
    );

  if (!stillCurrent) {
    return;
  }
}

export const analyzeVerification =
  onCall(
    {
      region: "europe-west1",
      enforceAppCheck: true,
      timeoutSeconds: 120,
      memory: "512MiB",
      secrets: [
        identityHmacSecret,
      ],
    },
    async (request) => {
      const data =
        request.data as
          AnalyzeVerificationRequest;

      const requestId =
        typeof data.requestId ===
        "string" ?
          data.requestId.trim() :
          "";

      if (!requestId) {
        throw new HttpsError(
          "invalid-argument",
          "Başvuru kimliği gerekli.",
        );
      }

      const verificationSnapshot =
        await firestore
          .collection(
            "verification_requests",
          )
          .doc(requestId)
          .get();

      if (!verificationSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "Doğrulama başvurusu bulunamadı.",
        );
      }

      assertVerificationAssignment(
        request,
        verificationSnapshot.data() ?? {},
      );

      await runVerificationAnalysis(
        requestId,
        true,
      );

      return {
        success: true,
      };
    },
  );

export const analyzeVerificationOnWrite =
  onDocumentWritten(
    {
      document:
        "verification_requests/{requestId}",
      region: "europe-west1",
      timeoutSeconds: 120,
      memory: "512MiB",
      secrets: [
        identityHmacSecret,
      ],
    },
    async (event) => {
      const after =
        event.data?.after;

      if (
        !after ||
        !after.exists
      ) {
        return;
      }

      const data =
        after.data();

      if (!data) {
        return;
      }

      if (
        data.status !== "pending" ||
        data.automaticCheckStatus !==
          "pending"
      ) {
        return;
      }

      const requestId =
        event.params.requestId;

      const submissionId =
        data.submissionId
          ?.toString()
          .trim() ?? "";

      try {
        await runVerificationAnalysis(
          requestId,
        );
      } catch {
        console.error(
          "Otomatik doğrulama analizi başarısız.",
        );

        await firestore.runTransaction(
          async (transaction) => {
            const fresh =
              await transaction.get(after.ref);
            const freshData =
              fresh.data() ?? {};
            const freshSubmission =
              freshData.submissionId
                ?.toString()
                .trim() ?? "";

            if (
              submissionId &&
              freshSubmission !== submissionId
            ) {
              return;
            }

            if (freshData.status !== "pending") {
              return;
            }

            transaction.update(after.ref, {
              automaticCheckStatus:
                "needs_review",
              reasonCode:
                "analysis_unavailable",
              decisionSource: "automatic",
              status: "pending",
              automaticCheckCompletedAt:
                FieldValue.serverTimestamp(),
              updatedAt:
                FieldValue.serverTimestamp(),
            });
          },
        );
      }
    },
  );
