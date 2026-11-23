/* eslint-disable max-len */
import {FieldValue} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {writeAuditLog} from "../audit/writeAuditLog";
import {firestore} from "../config/firebaseAdmin";
import {
  assertAdminPanelAccess,
  assertCurrentAdminSession,
  hasAdminPermission,
} from "../security/adminAuthorization";

const productIdPattern = /^[a-z0-9_]{1,80}$/;
const appleIdPattern = /^[A-Za-z0-9._-]{1,120}$/;

/**
 * Sets or clears `appleProductId` on one Plus or badge catalog document.
 * Does not modify any Google Play mapping fields.
 */
export const adminSetAppleProductId = onCall(
  {
    region: "europe-west1",
    enforceAppCheck: true,
  },
  async (request) => {
    assertAdminPanelAccess(request);
    await assertCurrentAdminSession(request);

    const allowed =
      hasAdminPermission(request, "content.manage") ||
      hasAdminPermission(request, "finance.manage");

    if (!allowed) {
      throw new HttpsError(
        "permission-denied",
        "You do not have permission for this operation.",
      );
    }

    const data = (request.data ?? {}) as Record<string, unknown>;
    const collectionName = requiredText(data.collection, "Koleksiyon gerekli.");

    if (
      collectionName !== "plus_products" &&
      collectionName !== "badge_products"
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Yalnızca Plus veya rozet kataloğu eşlenebilir.",
      );
    }

    const productId = requiredText(data.productId, "Ürün kimliği gerekli.");
    if (!productIdPattern.test(productId)) {
      throw new HttpsError("invalid-argument", "Ürün kimliği geçersiz.");
    }

    const appleProductId = optionalAppleId(data.appleProductId);
    const reference = firestore.collection(collectionName).doc(productId);
    const current = await reference.get();

    if (!current.exists) {
      throw new HttpsError("not-found", "Katalog ürünü bulunamadı.");
    }

    const previous = String(current.data()?.appleProductId ?? "").trim();
    if (previous === appleProductId) {
      return {success: true, unchanged: true};
    }

    if (appleProductId) {
      await assertAppleIdUnique(appleProductId, collectionName, productId);
    }

    await reference.set(
      {
        appleProductId,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: request.auth.uid,
      },
      {merge: true},
    );

    await writeAuditLog({
      action: "apple_product_mapping_updated",
      performedBy: request.auth.uid,
      metadata: {
        collection: collectionName,
        productId,
        previousAppleProductId: previous,
        appleProductId,
      },
    });

    return {success: true, unchanged: false};
  },
);

/**
 * Ensures one appleProductId is not bound to two catalog entries.
 * @param {string} appleProductId App Store product identifier.
 * @param {string} collectionName Target catalog collection.
 * @param {string} productId Target catalog doc id.
 * @return {Promise<void>} Completes when unique.
 */
async function assertAppleIdUnique(
  appleProductId: string,
  collectionName: string,
  productId: string,
): Promise<void> {
  const collections = ["plus_products", "badge_products"];
  const snapshots = await Promise.all(
    collections.map((name) =>
      firestore
        .collection(name)
        .where("appleProductId", "==", appleProductId)
        .limit(5)
        .get(),
    ),
  );

  const conflict = snapshots.some((snapshot, index) =>
    snapshot.docs.some((doc) => {
      const sameSlot = collections[index] === collectionName &&
        doc.id === productId;
      return !sameSlot;
    }),
  );

  if (conflict) {
    throw new HttpsError(
      "already-exists",
      "Bu App Store ürün kimliği başka bir katalog kaydında kullanılıyor.",
    );
  }
}

/**
 * Reads a required short string.
 * @param {unknown} value Raw value.
 * @param {string} message Validation message.
 * @return {string} Trimmed text.
 */
function requiredText(value: unknown, message: string): string {
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
 * Reads an optional App Store product identifier.
 * @param {unknown} value Raw value.
 * @return {string} Trimmed identifier or empty string.
 */
function optionalAppleId(value: unknown): string {
  if (value == null) {
    return "";
  }
  if (typeof value !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "App Store ürün kimliği metin olmalıdır.",
    );
  }
  const normalized = value.trim();
  if (!normalized) {
    return "";
  }
  if (!appleIdPattern.test(normalized)) {
    throw new HttpsError(
      "invalid-argument",
      "App Store ürün kimliği geçersiz.",
    );
  }
  return normalized;
}
