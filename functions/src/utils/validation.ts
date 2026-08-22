import {HttpsError} from "firebase-functions/https";

/**
 * Validates and normalizes a required string.
 * @param {unknown} value Value to validate.
 * @param {string} fieldName Field name for error messages.
 * @param {number} maxLength Maximum allowed length.
 * @return {string} Normalized string.
 */
export function requireString(
  value: unknown,
  fieldName: string,
  maxLength: number
): string {
  if (typeof value !== "string") {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must be a string.`
    );
  }

  const normalizedValue = value.trim();

  if (!normalizedValue) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} is required.`
    );
  }

  if (normalizedValue.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must not exceed ${maxLength} characters.`
    );
  }

  return normalizedValue;
}

/**
 * Validates an optional string.
 * @param {unknown} value Value to validate.
 * @param {string} fieldName Field name for error messages.
 * @param {number} maxLength Maximum allowed length.
 * @return {string | null} Normalized string or null.
 */
export function optionalString(
  value: unknown,
  fieldName: string,
  maxLength: number
): string | null {
  if (value === undefined || value === null) {
    return null;
  }

  if (typeof value !== "string") {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must be a string.`
    );
  }

  const normalizedValue = value.trim();

  if (!normalizedValue) {
    return null;
  }

  if (normalizedValue.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must not exceed ${maxLength} characters.`
    );
  }

  return normalizedValue;
}

/**
 * Validates a required boolean.
 * @param {unknown} value Value to validate.
 * @param {string} fieldName Field name for error messages.
 * @return {boolean} Validated boolean.
 */
export function requireBoolean(
  value: unknown,
  fieldName: string
): boolean {
  if (typeof value !== "boolean") {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must be a boolean.`
    );
  }

  return value;
}

/**
 * Validates a required finite number.
 * @param {unknown} value Value to validate.
 * @param {string} fieldName Field name for error messages.
 * @return {number} Validated number.
 */
export function requireNumber(
  value: unknown,
  fieldName: string
): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must be a valid number.`
    );
  }

  return value;
}
