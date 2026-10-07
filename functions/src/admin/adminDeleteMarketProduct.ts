/* eslint-disable max-len */
/* eslint-disable require-jsdoc */
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {getFirestore} from "firebase-admin/firestore";
import {
  assertAdminPermission,
  getAdminRole,
} from "../security/adminAuthorization";
import {writeAuditLog} from "../audit/writeAuditLog";

export const adminDeleteMarketProduct = onCall(
  {region: "europe-west1", enforceAppCheck: true},
  async (request) => {
    assertAdminPermission(request, "content.manage");

    const data = request.data as Record<string, unknown>;
    const productId = readId(data.productId);
    const adminId = request.auth.uid;
    const adminRole = getAdminRole(request);

    const ref = getFirestore().collection("marketProducts").doc(productId);
    const snap = await ref.get();

    if (!snap.exists) {
      throw new HttpsError("not-found", "Market ürünü bulunamadı.");
    }

    const product = snap.data() ?? {};

    await ref.delete();

    await writeAuditLog({
      action: "admin_market_product_deleted",
      performedBy: adminId,
      metadata: {
        productId,
        code: product.code ?? null,
        productType: product.productType ?? null,
        performedByRole: adminRole,
      },
    });

    return {success: true};
  },
);

function readId(value: unknown): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "Ürün kimliği gerekli.");
  }
  const result = value.trim();
  if (!result || result.length > 128 || result.includes("/")) {
    throw new HttpsError("invalid-argument", "Geçersiz ürün kimliği.");
  }
  return result;
}
