import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  FieldValue,
} from "firebase-admin/firestore";

import {firestore} from "../config/firebaseAdmin";
import {
  assertVerificationAssignment,
} from "../security/assertVerificationAssignment";
import {
  readVerificationObject,
  verificationObjectPath,
} from "./verificationDocumentStorage";

interface DocumentContentRequest {
  requestId?: unknown;
  documentType?: unknown;
}

const documentFields = {
  identity_front: {
    path: "identityFrontPath",
    legacy: "identityFrontUrl",
  },
  identity_back: {
    path: "identityBackPath",
    legacy: "identityBackUrl",
  },
  criminal_record: {
    path: "criminalRecordPath",
    legacy: "criminalRecordUrl",
  },
  selfie: {
    path: "selfiePath",
    legacy: "selfieUrl",
  },
} as const;

type DocumentType =
  keyof typeof documentFields;

/**
 * Checks whether a requested verification document type is supported.
 * @param {string} value Requested document type.
 * @return {boolean} Whether the type is supported.
 */
function isDocumentType(
  value: string,
): value is DocumentType {
  return value in documentFields;
}

/**
 * Resolves a response MIME type from a verified object path.
 * @param {string} objectPath Private Storage object path.
 * @return {string} Response content type.
 */
function contentTypeFromPath(
  objectPath: string,
): string {
  const value =
    objectPath.toLowerCase();

  if (value.endsWith(".pdf")) {
    return "application/pdf";
  }

  if (value.endsWith(".png")) {
    return "image/png";
  }

  if (value.endsWith(".webp")) {
    return "image/webp";
  }

  return "image/jpeg";
}

export const getVerificationDocumentContent =
  onCall(
    {
      region: "europe-west1",
      enforceAppCheck: true,
      timeoutSeconds: 60,
      memory: "512MiB",
    },
    async (request) => {
      const data =
        request.data as
          DocumentContentRequest;

      const requestId =
        typeof data.requestId ===
        "string" ?
          data.requestId.trim() :
          "";

      const documentType =
        typeof data.documentType ===
        "string" ?
          data.documentType.trim() :
          "";

      if (
        !requestId ||
        !isDocumentType(documentType)
      ) {
        throw new HttpsError(
          "invalid-argument",
          "Belge isteği geçersiz.",
        );
      }

      const reference =
        firestore
          .collection(
            "verification_requests",
          )
          .doc(requestId);

      const snapshot =
        await reference.get();

      if (!snapshot.exists) {
        throw new HttpsError(
          "not-found",
          "Doğrulama başvurusu bulunamadı.",
        );
      }

      const verificationData =
        snapshot.data() ?? {};

      assertVerificationAssignment(
        request,
        verificationData,
      );

      const uid =
        verificationData.uid
          ?.toString()
          .trim() ?? requestId;

      const fields =
        documentFields[documentType];

      const objectPath =
        verificationObjectPath(
          verificationData[fields.path] ??
            verificationData[
              fields.legacy
            ],
          uid,
        );

      if (!objectPath) {
        throw new HttpsError(
          "not-found",
          "Doğrulama belgesi bulunamadı.",
        );
      }

      try {
        const content =
          await readVerificationObject(
            objectPath,
          );

        await firestore
          .collection(
            "verification_document_access_logs",
          )
          .add({
            requestId,
            userId: uid,
            adminId:
              request.auth?.uid ?? "",
            documentType,
            accessedAt:
              FieldValue.serverTimestamp(),
          });

        return {
          content:
            content.toString("base64"),
          contentType:
            contentTypeFromPath(
              objectPath,
            ),
          fileName:
            objectPath
              .split("/")
              .pop() ?? "document",
        };
      } catch (error) {
        console.error(
          "Doğrulama belgesi okunamadı.",
          error,
        );

        throw new HttpsError(
          "internal",
          "Belge güvenli şekilde açılamadı.",
        );
      }
    },
  );
