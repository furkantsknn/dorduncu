import {FieldValue} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {writeAuditLog} from "../audit/writeAuditLog";
import {firestore} from "../config/firebaseAdmin";
import {
  assertAdminPanelAccess,
  hasAdminPermission,
} from "../security/adminAuthorization";

const productIdPattern = /^[a-z0-9_]{1,80}$/;
const playIdPattern = /^[A-Za-z0-9._-]{1,80}$/;
const basePlanPattern = /^[a-z0-9][a-z0-9-]{0,62}$/;

/**
 * Sets the Google Play product id on one Plus or badge catalog document.
 *
 * An empty value clears the mapping. The internal badge or Plus id is never
 * replaced by the Play id.
 */
export const adminSetGooglePlayProductId = onCall(
  {
    region: "europe-west1",
    enforceAppCheck: true,
  },
  async (request) => {
    assertAdminPanelAccess(request);

    const allowed =
      hasAdminPermission(request, "content.manage") ||
      hasAdminPermission(request, "finance.manage");

    if (!allowed) {
      throw new HttpsError(
        "permission-denied",
        "You do not have permission for this operation.",
      );
    }

    const data = request.data as Record<string, unknown>;
    const collectionName = text(data.collection, "Koleksiyon gerekli.");

    if (
      collectionName !== "plus_products" &&
      collectionName !== "badge_products"
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Yalnızca Plus veya rozet kataloğu eşlenebilir.",
      );
    }

    const productId = text(data.productId, "Ürün kimliği gerekli.");

    if (!productIdPattern.test(productId)) {
      throw new HttpsError(
        "invalid-argument",
        "Ürün kimliği geçersiz.",
      );
    }

    const googlePlayProductId = optionalPlayId(data.googlePlayProductId);
    const basePlanProvided = Object.prototype.hasOwnProperty.call(
      data,
      "googlePlayBasePlanId",
    );

    if (collectionName === "badge_products" && basePlanProvided) {
      throw new HttpsError(
        "invalid-argument",
        "Rozet kataloğunda base plan eşlemesi yoktur.",
      );
    }

    const googlePlayBasePlanId = collectionName === "plus_products" &&
      basePlanProvided ?
      optionalBasePlanId(data.googlePlayBasePlanId) :
      undefined;
    const reference = firestore.collection(collectionName).doc(productId);
    const current = await reference.get();

    if (!current.exists) {
      throw new HttpsError("not-found", "Katalog ürünü bulunamadı.");
    }

    const previous = String(
      current.data()?.googlePlayProductId ?? "",
    ).trim();
    const previousBasePlan = String(
      current.data()?.googlePlayBasePlanId ?? "",
    ).trim();
    const nextBasePlan = googlePlayBasePlanId ?? previousBasePlan;

    if (
      previous === googlePlayProductId &&
      previousBasePlan === nextBasePlan
    ) {
      return {success: true, unchanged: true};
    }

    if (googlePlayProductId) {
      await assertPlayIdIsUnique(
        googlePlayProductId,
        collectionName,
        productId,
      );
    }

    const payload: Record<string, unknown> = {
      googlePlayProductId,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: request.auth.uid,
    };

    if (collectionName === "plus_products" && basePlanProvided) {
      payload.googlePlayBasePlanId = nextBasePlan;
    }

    await reference.set(payload, {merge: true});

    await writeAuditLog({
      action: "google_play_product_mapping_updated",
      performedBy: request.auth.uid,
      metadata: {
        collection: collectionName,
        productId,
        previousGooglePlayProductId: previous,
        googlePlayProductId,
        previousGooglePlayBasePlanId: previousBasePlan,
        googlePlayBasePlanId: nextBasePlan,
      },
    });

    return {success: true, unchanged: false};
  },
);

/**
 * Rejects a Play id that is already mapped to another active catalog row.
 * @param {string} googlePlayProductId Play product id.
 * @param {string} collectionName Catalog being edited.
 * @param {string} productId Internal product id.
 * @return {Promise<void>} Completes when the id is unique.
 */
async function assertPlayIdIsUnique(
  googlePlayProductId: string,
  collectionName: string,
  productId: string,
): Promise<void> {
  const [plusSnapshot, badgeSnapshot] = await Promise.all([
    firestore
      .collection("plus_products")
      .where("googlePlayProductId", "==", googlePlayProductId)
      .limit(5)
      .get(),
    firestore
      .collection("badge_products")
      .where("googlePlayProductId", "==", googlePlayProductId)
      .limit(5)
      .get(),
  ]);

  const conflict = [...plusSnapshot.docs, ...badgeSnapshot.docs].some(
    (document) =>
      !(document.ref.parent.id === collectionName && document.id === productId),
  );

  if (conflict) {
    throw new HttpsError(
      "already-exists",
      "Bu Google Play ürün kimliği başka bir katalog kaydında kullanılıyor.",
    );
  }
}

/**
 * Reads one required short text field.
 * @param {unknown} value Raw value.
 * @param {string} message Error message.
 * @return {string} Trimmed text.
 */
function text(value: unknown, message: string): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", message);
  }

  const normalized = value.trim();

  if (!normalized || normalized.length > 80) {
    throw new HttpsError("invalid-argument", message);
  }

  return normalized;
}

/**
 * Reads an optional Play base plan id. Empty clears the Plus mapping.
 *
 * Play Console base plan ids are 1–63 characters, start with a lowercase
 * letter or number, and contain only lowercase letters, numbers and hyphens.
 * @param {unknown} value Raw value.
 * @return {string} Normalized base plan id.
 */
function optionalBasePlanId(value: unknown): string {
  if (value == null) {
    return "";
  }

  if (typeof value !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "Google Play base plan kimliği metin olmalıdır.",
    );
  }

  const normalized = value.trim();

  if (!normalized) {
    return "";
  }

  if (!basePlanPattern.test(normalized)) {
    throw new HttpsError(
      "invalid-argument",
      "Google Play base plan kimliği geçersiz.",
    );
  }

  return normalized;
}

/**
 * Reads an optional Play product id. Empty clears the mapping.
 * @param {unknown} value Raw value.
 * @return {string} Normalized Play id.
 */
function optionalPlayId(value: unknown): string {
  if (value == null) {
    return "";
  }

  if (typeof value !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "Google Play ürün kimliği metin olmalıdır.",
    );
  }

  const normalized = value.trim();

  if (!normalized) {
    return "";
  }

  if (!playIdPattern.test(normalized)) {
    throw new HttpsError(
      "invalid-argument",
      "Google Play ürün kimliği geçersiz.",
    );
  }

  return normalized;
}
