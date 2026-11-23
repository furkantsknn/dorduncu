import {assertCurrentAdminSession} from "../security/adminAuthorization";
/* eslint-disable max-len */
/* eslint-disable require-jsdoc */
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {
  assertAdminPermission,
  getAdminRole,
} from "../security/adminAuthorization";
import {writeAuditLog} from "../audit/writeAuditLog";

export const adminSaveMarketProduct = onCall(
  {region: "europe-west1", enforceAppCheck: true},
  async (request) => {
    assertAdminPermission(request, "content.manage");
    await assertCurrentAdminSession(request);

    const data = request.data as Record<string, unknown>;
    const adminId = request.auth.uid;
    const adminRole = getAdminRole(request);

    const productId = optionalText(data.productId, 128);
    const title = requiredText(data.title, "Ürün adı gerekli.", 120);
    const code = requiredText(data.code, "Ürün kodu gerekli.", 80).toLowerCase();
    const description = optionalText(data.description, 2000);
    const productType = requiredText(data.productType, "Ürün türü gerekli.", 40);

    if (!["plus", "badge", "digital"].includes(productType)) {
      throw new HttpsError("invalid-argument", "Geçersiz ürün türü.");
    }

    const active = data.active === true;
    const allowTlPayment = data.allowTlPayment === true;
    const allowWalletPayment = data.allowWalletPayment === true;
    const allowPointPayment = data.allowPointPayment === true;

    if (!allowTlPayment && !allowWalletPayment && !allowPointPayment) {
      throw new HttpsError("invalid-argument", "En az bir ödeme yöntemi gerekli.");
    }

    const priceKurus = integer(data.priceKurus, "TL fiyatı geçersiz.", 0, 1000000000);
    const pointPrice = number(data.pointPrice, "Puan fiyatı geçersiz.", 0, 1000000000);
    const durationDays = integer(data.durationDays, "Süre geçersiz.", 0, 36500);

    if ((allowTlPayment || allowWalletPayment) && priceKurus <= 0) {
      throw new HttpsError("invalid-argument", "TL fiyatı gerekli.");
    }

    if (allowPointPayment && pointPrice <= 0) {
      throw new HttpsError("invalid-argument", "Puan fiyatı gerekli.");
    }

    const db = getFirestore();
    const ref = productId ?
      db.collection("marketProducts").doc(productId) :
      db.collection("marketProducts").doc();

    const existing = await ref.get();
    const now = FieldValue.serverTimestamp();

    await ref.set({
      title,
      code,
      description,
      productType,
      active,
      allowTlPayment,
      allowWalletPayment,
      allowPointPayment,
      priceKurus,
      pointPrice,
      durationDays,
      updatedAt: now,
      updatedBy: adminId,
      ...(!existing.exists ? {createdAt: now, createdBy: adminId} : {}),
    }, {merge: true});

    await writeAuditLog({
      action: existing.exists ? "admin_market_product_updated" : "admin_market_product_created",
      performedBy: adminId,
      metadata: {
        productId: ref.id,
        productType,
        code,
        performedByRole: adminRole,
      },
    });

    return {success: true, productId: ref.id};
  },
);

function requiredText(value: unknown, message: string, max: number): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", message);
  }
  const result = value.trim();
  if (!result || result.length > max) {
    throw new HttpsError("invalid-argument", message);
  }
  return result;
}

function optionalText(value: unknown, max: number): string {
  if (value === null || value === undefined) {
    return "";
  }
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "Geçersiz metin değeri.");
  }
  const result = value.trim();
  if (result.length > max) {
    throw new HttpsError("invalid-argument", "Metin değeri çok uzun.");
  }
  return result;
}

function number(
  value: unknown,
  message: string,
  min: number,
  max: number,
): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < min || value > max) {
    throw new HttpsError("invalid-argument", message);
  }
  return value;
}

function integer(
  value: unknown,
  message: string,
  min: number,
  max: number,
): number {
  const result = number(value, message, min, max);
  if (!Number.isInteger(result)) {
    throw new HttpsError("invalid-argument", message);
  }
  return result;
}
