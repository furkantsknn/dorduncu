import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  onDocumentWritten,
} from "firebase-functions/v2/firestore";
import {
  FieldValue,
} from "firebase-admin/firestore";
import vision from "@google-cloud/vision";

import {firestore} from "../config/firebaseAdmin";
import {assertAdmin} from "../security/assertAdmin";
import {
  defineSecret,
} from "firebase-functions/params";
import {
  createHmac,
} from "node:crypto";

interface AnalyzeVerificationRequest {
  requestId?: unknown;
}

interface CheckResult {
  status: "passed" | "failed";
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
   * @param {string} imageUrl Identity image URL.
   * @return {Promise<string|null>} TCKN or null.
   */
async function readIdentityTckn(
  imageUrl: string,
): Promise<string | null> {
  try {
    const [result] =
        await visionClient.textDetection(
          imageUrl,
        );

    const detectedText =
        result.fullTextAnnotation?.text ??
        result.textAnnotations?.[0]
          ?.description ??
        "";

    return extractTckn(
      detectedText,
    );
  } catch (error) {
    console.error(
      "TCKN OCR hatası",
      error,
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
   * Reserves an identity for one account.
   * @param {string} uid User id.
   * @param {string} fingerprint Identity fingerprint.
   * @return {Promise<CheckResult>} Uniqueness result.
   */
async function reserveIdentity(
  uid: string,
  fingerprint: string,
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
            reason:
                "Bu kimlik başka bir hesapta daha önce kullanılmış.",
          };
        }

        const currentStatus =
            current.status
              ?.toString()
              .trim() ?? "";

        transaction.set(
          reference,
          {
            uid,
            status:
                currentStatus ===
                  "approved" ?
                  "approved" :
                  "reserved",
            updatedAt:
                FieldValue.serverTimestamp(),
          },
          {
            merge: true,
          },
        );

        return {
          status: "passed",
          reason:
              "Kimlik bu hesaba ait önceki başvuruyla eşleşiyor.",
        };
      }

      transaction.set(
        reference,
        {
          uid,
          status: "reserved",
          createdAt:
              FieldValue.serverTimestamp(),
          updatedAt:
              FieldValue.serverTimestamp(),
        },
      );

      return {
        status: "passed",
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
 * @param {string} imageUrl Image URL.
 * @param {string[]} requiredTerms Expected terms.
 * @param {string} documentName Document name.
 * @return {Promise<CheckResult>} Check result.
 */
async function analyzeTextDocument(
  imageUrl: string,
  requiredTerms: string[],
  documentName: string,
): Promise<CheckResult> {
  try {
    const [result] =
      await visionClient.textDetection(
        imageUrl,
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
        status: "failed",
        reason:
          `${documentName} üzerinde okunabilir metin tespit edilemedi.`,
      };
    }

    const matched =
      requiredTerms.some(
        (term) =>
          normalized.includes(
            normalizeText(term),
          ),
      );

    if (!matched) {
      return {
        status: "failed",
        reason:
          `${documentName} beklenen belge türü olarak doğrulanamadı.`,
      };
    }

    return {
      status: "passed",
      reason:
        "Belge okunabilir ve temel belge kontrolü başarılı.",
    };
  } catch (error) {
    console.error(
      `${documentName} analiz hatası`,
      error,
    );

    return {
      status: "failed",
      reason:
        `${documentName} otomatik olarak analiz edilemedi.`,
    };
  }
}

/**
 * Checks OCR text from a PDF.
 * @param {string} fileUrl PDF URL.
 * @param {string[]} requiredTerms Expected terms.
 * @param {string} documentName Document name.
 * @return {Promise<CheckResult>} Check result.
 */
async function analyzePdfDocument(
  fileUrl: string,
  requiredTerms: string[],
  documentName: string,
): Promise<CheckResult> {
  try {
    const response =
      await fetch(fileUrl);

    if (!response.ok) {
      return {
        status: "failed",
        reason:
          `${documentName} dosyasına erişilemedi.`,
      };
    }

    const arrayBuffer =
      await response.arrayBuffer();

    const content =
      Buffer.from(arrayBuffer);

    const [result] =
      await visionClient.batchAnnotateFiles({
        requests: [
          {
            inputConfig: {
              mimeType:
                "application/pdf",
              content,
            },
            features: [
              {
                type:
                  "DOCUMENT_TEXT_DETECTION",
              },
            ],
            pages: [
              1,
              2,
              -1,
            ],
          },
        ],
      });

    const responses =
      result.responses?.[0]
        ?.responses ?? [];

    const detectedText =
      responses
        .map(
          (item) =>
            item.fullTextAnnotation
              ?.text ??
            "",
        )
        .join(" ");

    const normalized =
      normalizeText(detectedText);

    if (!normalized) {
      return {
        status: "failed",
        reason:
          `${documentName} PDF dosyasında okunabilir metin tespit edilemedi.`,
      };
    }

    const matched =
      requiredTerms.some(
        (term) =>
          normalized.includes(
            normalizeText(term),
          ),
      );

    if (!matched) {
      return {
        status: "failed",
        reason:
          `${documentName} beklenen belge türü olarak doğrulanamadı.`,
      };
    }

    return {
      status: "passed",
      reason:
        "PDF okunabilir ve temel belge kontrolü başarılı.",
    };
  } catch (error) {
    console.error(
      `${documentName} PDF analiz hatası`,
      error,
    );

    return {
      status: "failed",
      reason:
        `${documentName} PDF dosyası otomatik olarak analiz edilemedi.`,
    };
  }
}

/**
 * Checks whether selfie has one face.
 * @param {string} imageUrl Selfie URL.
 * @return {Promise<CheckResult>} Check result.
 */
async function analyzeSelfie(
  imageUrl: string,
): Promise<CheckResult> {
  try {
    const [result] =
      await visionClient.faceDetection(
        imageUrl,
      );

    const faces =
      result.faceAnnotations ?? [];

    if (faces.length === 0) {
      return {
        status: "failed",
        reason:
          "Selfie görüntüsünde yüz tespit edilemedi.",
      };
    }

    if (faces.length > 1) {
      return {
        status: "failed",
        reason:
          "Selfie görüntüsünde birden fazla yüz tespit edildi.",
      };
    }

    return {
      status: "passed",
      reason:
        "Selfie görüntüsünde tek yüz tespit edildi.",
    };
  } catch (error) {
    console.error(
      "Selfie analiz hatası",
      error,
    );

    return {
      status: "failed",
      reason:
        "Selfie otomatik olarak analiz edilemedi.",
    };
  }
}

/**
 * Runs verification analysis.
 * @param {string} requestId Verification request id.
 * @return {Promise<void>} Completion promise.
 */
export async function runVerificationAnalysis(
  requestId: string,
): Promise<void> {
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

  const identityFrontUrl =
    verificationData.identityFrontUrl
      ?.toString()
      .trim() ?? "";

  const identityBackUrl =
    verificationData.identityBackUrl
      ?.toString()
      .trim() ?? "";

  const criminalRecordUrl =
    verificationData.criminalRecordUrl
      ?.toString()
      .trim() ?? "";

  const selfieUrl =
    verificationData.selfieUrl
      ?.toString()
      .trim() ?? "";

  if (
    !identityFrontUrl ||
    !identityBackUrl ||
    !criminalRecordUrl ||
    !selfieUrl
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Başvuru belgeleri eksik.",
    );
  }

  await verificationReference.update({
    automaticCheckStatus:
      "processing",
    updatedAt:
      FieldValue.serverTimestamp(),
  });

  const tckn =
  await readIdentityTckn(
    identityFrontUrl,
  );

  let identityFingerprint = "";

  let identityUniquenessCheck:
  CheckResult;

  if (!tckn) {
    identityUniquenessCheck = {
      status: "failed",
      reason:
      "Kimlik üzerindeki T.C. kimlik numarası güvenilir şekilde okunamadı.",
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
    );
  }

  const [
    identityFrontCheck,
    identityBackCheck,
    criminalRecordCheck,
    selfieCheck,
  ] = await Promise.all([
    analyzeTextDocument(
      identityFrontUrl,
      [
        "türkiye cumhuriyeti",
        "republic of turkey",
        "kimlik kartı",
      ],
      "Kimlik ön yüzü",
    ),
    analyzeTextDocument(
      identityBackUrl,
      [
        "kimlik",
        "identity",
        "uyruğu",
        "nationality",
      ],
      "Kimlik arka yüzü",
    ),
    criminalRecordUrl
      .toLowerCase()
      .includes(".pdf") ?
      analyzePdfDocument(
        criminalRecordUrl,
        [
          "adli sicil",
          "arşiv kaydı",
          "sabıka",
          "judicial record",
        ],
        "Adli sicil belgesi",
      ) :
      analyzeTextDocument(
        criminalRecordUrl,
        [
          "adli sicil",
          "arşiv kaydı",
          "sabıka",
          "judicial record",
        ],
        "Adli sicil belgesi",
      ),
    analyzeSelfie(
      selfieUrl,
    ),
  ]);

  const checks = [
    identityFrontCheck,
    identityBackCheck,
    criminalRecordCheck,
    selfieCheck,
    identityUniquenessCheck,
  ];


  const hasFailed =
    checks.some(
      (check) =>
        check.status === "failed",
    );

  await verificationReference.update({
    identityFrontCheck,
    identityBackCheck,
    criminalRecordCheck,
    selfieCheck,
    identityUniquenessCheck,
    identityFingerprint:
      identityUniquenessCheck.status ===
        "passed" ?
        identityFingerprint :
        FieldValue.delete(),
    automaticCheckStatus:
      hasFailed ?
        "failed" :
        "passed",
    automaticCheckCompletedAt:
      FieldValue.serverTimestamp(),
    updatedAt:
      FieldValue.serverTimestamp(),
  });
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
      assertAdmin(request);

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

      await runVerificationAnalysis(
        requestId,
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

      try {
        await runVerificationAnalysis(
          requestId,
        );
      } catch (error) {
        console.error(
          "Otomatik doğrulama analizi başarısız.",
          error,
        );

        await after.ref.update({
          automaticCheckStatus:
            "failed",
          automaticCheckCompletedAt:
            FieldValue.serverTimestamp(),
          updatedAt:
            FieldValue.serverTimestamp(),
        });
      }
    },
  );
