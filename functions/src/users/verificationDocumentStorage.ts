import {randomUUID} from "node:crypto";

import {getStorage} from "firebase-admin/storage";
import * as logger from "firebase-functions/logger";

const allowedStorageBuckets = new Set([
  "dorduncu-8e599.firebasestorage.app",
  "dorduncu-8e599.appspot.com",
]);

const maximumVerificationBytes =
  10 * 1024 * 1024;

const allowedContentTypes = new Set([
  "image/jpeg",
  "image/jpg",
  "image/png",
  "image/webp",
  "application/pdf",
]);

/**
 * Converts a private path or legacy URL to an owned object path.
 * @param {unknown} value Stored path or legacy URL.
 * @param {string} uid Owner user id.
 * @return {string} Valid object path or an empty string.
 */
export function verificationObjectPath(
  value: unknown,
  uid: string,
): string {
  if (
    typeof value !== "string" ||
    !uid
  ) {
    return "";
  }

  const trimmed = value.trim();

  if (!trimmed) {
    return "";
  }

  const requiredPrefix =
    `verification_documents/${uid}/`;

  let objectPath = trimmed;

  if (
    trimmed.startsWith("https://")
  ) {
    try {
      const url = new URL(trimmed);

      if (
        url.protocol !== "https:" ||
        url.hostname !==
          "firebasestorage.googleapis.com"
      ) {
        return "";
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
        return "";
      }

      const bucket =
        decodeURIComponent(parts[2]);

      if (
        !allowedStorageBuckets.has(bucket)
      ) {
        return "";
      }

      objectPath =
        decodeURIComponent(
          parts.slice(4).join("/"),
        );
    } catch {
      return "";
    }
  }

  if (
    !objectPath.startsWith(
      requiredPrefix,
    )
  ) {
    return "";
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
    relativePath.includes("\\") ||
    relativePath.includes("/")
  ) {
    return "";
  }

  return objectPath;
}

/**
 * Validates that a verification object exists and has safe metadata.
 * @param {string} objectPath Private Storage object path.
 * @return {Promise<void>} Completion promise.
 */
export async function assertVerificationObject(
  objectPath: string,
): Promise<void> {
  const file =
    getStorage()
      .bucket()
      .file(objectPath);

  const [exists] =
    await file.exists();

  if (!exists) {
    throw new Error(
      "Verification object does not exist.",
    );
  }

  const [metadata] =
    await file.getMetadata();

  const size =
    Number(metadata.size ?? 0);

  const contentType =
    metadata.contentType ?? "";

  if (
    size <= 0 ||
    size > maximumVerificationBytes ||
    !allowedContentTypes.has(contentType)
  ) {
    throw new Error(
      "Verification object metadata is invalid.",
    );
  }
}

/**
 * Rotates the download token without exposing the replacement.
 * @param {string} objectPath Private Storage object path.
 * @return {Promise<void>} Completion promise.
 */
export async function rotateDownloadToken(
  objectPath: string,
): Promise<void> {
  const file =
    getStorage()
      .bucket()
      .file(objectPath);

  await file.setMetadata({
    metadata: {
      firebaseStorageDownloadTokens:
        randomUUID(),
    },
  });
}

/**
 * Reads a private verification object through Admin SDK credentials.
 * @param {string} objectPath Private Storage object path.
 * @return {Promise<Buffer>} File bytes.
 */
export async function readVerificationObject(
  objectPath: string,
): Promise<Buffer> {
  const file =
    getStorage()
      .bucket()
      .file(objectPath);

  const [content] =
    await file.download();

  return content;
}

/**
 * Deletes verification objects if they still exist.
 * @param {string[]} objectPaths Private Storage object paths.
 * @return {Promise<number>} Number of objects deleted.
 */
export async function deleteVerificationObjects(
  objectPaths: string[],
): Promise<number> {
  const uniquePaths = [
    ...new Set(
      objectPaths
        .map((value) => value.trim())
        .filter((value) => value.length > 0),
    ),
  ];

  let deleted = 0;

  for (const objectPath of uniquePaths) {
    try {
      await getStorage().bucket().file(objectPath).delete({
        ignoreNotFound: true,
      });
      deleted += 1;
    } catch (error) {
      logger.error(
        "verification_document_delete_failed",
        {
          objectPath,
          error,
        },
      );
      throw error;
    }
  }

  return deleted;
}
