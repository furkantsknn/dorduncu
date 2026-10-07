/* eslint-disable max-len */
/* eslint-disable require-jsdoc */
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {
  assertAdminPermission,
  getAdminRole,
} from "../security/adminAuthorization";
import {writeAuditLog} from "../audit/writeAuditLog";

export const adminUpdateSystemSettings = onCall(
  {region: "europe-west1", enforceAppCheck: true},
  async (request) => {
    assertAdminPermission(request, "settings.manage");

    const data = request.data as Record<string, unknown>;
    const adminId = request.auth.uid;
    const adminRole = getAdminRole(request);

    const settings = {
      maintenanceMode: booleanValue(data.maintenanceMode, "Bakım modu değeri geçersiz."),
      maintenanceMessage: text(data.maintenanceMessage, 1000),
      forceUpdateEnabled: booleanValue(data.forceUpdateEnabled, "Zorunlu güncelleme değeri geçersiz."),
      minimumVersion: text(data.minimumVersion, 40),
      latestVersion: text(data.latestVersion, 40),
      registrationEnabled: booleanValue(data.registrationEnabled, "Kayıt ayarı geçersiz."),
      eventCreationEnabled: booleanValue(data.eventCreationEnabled, "Etkinlik oluşturma ayarı geçersiz."),
      eventApplicationsEnabled: booleanValue(data.eventApplicationsEnabled, "Başvuru ayarı geçersiz."),
      supportEnabled: booleanValue(data.supportEnabled, "Destek ayarı geçersiz."),
      paymentsEnabled: booleanValue(data.paymentsEnabled, "Ödeme ayarı geçersiz."),
      marketEnabled: booleanValue(data.marketEnabled, "Market ayarı geçersiz."),
      supportEmail: text(data.supportEmail, 254),
      termsUrl: text(data.termsUrl, 1000),
      privacyUrl: text(data.privacyUrl, 1000),
    };

    if (settings.forceUpdateEnabled && !settings.minimumVersion) {
      throw new HttpsError(
        "invalid-argument",
        "Zorunlu güncelleme için minimum sürüm gerekli.",
      );
    }

    const ref = getFirestore().collection("system_settings").doc("global");

    await ref.set({
      ...settings,
      updatedBy: adminId,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});

    await writeAuditLog({
      action: "admin_system_settings_updated",
      performedBy: adminId,
      metadata: {
        performedByRole: adminRole,
        maintenanceMode: settings.maintenanceMode,
        forceUpdateEnabled: settings.forceUpdateEnabled,
      },
    });

    return {success: true};
  },
);

function booleanValue(value: unknown, message: string): boolean {
  if (typeof value !== "boolean") {
    throw new HttpsError("invalid-argument", message);
  }
  return value;
}

function text(value: unknown, max: number): string {
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
