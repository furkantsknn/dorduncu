import {HttpsError, onCall} from "firebase-functions/v2/https";
import {
  FieldValue,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import {assertEventNotPast} from "./eventLifecycle";

const REGION = "europe-west1";

export const updateEvent = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const uid = request.auth?.uid;

    if (!uid) {
      throw new HttpsError(
        "unauthenticated",
        "Bu işlem için kullanıcı girişi gereklidir.",
      );
    }

    const data = request.data;

    if (data === null || typeof data !== "object") {
      throw new HttpsError(
        "invalid-argument",
        "Etkinlik bilgileri geçersiz.",
      );
    }

    const input = data as Record<string, unknown>;

    const eventId = String(input.eventId ?? "").trim();

    if (!eventId) {
      throw new HttpsError(
        "invalid-argument",
        "Etkinlik kimliği gereklidir.",
      );
    }

    const firestore = getFirestore();
    const eventReference =
      firestore.collection("events").doc(eventId);

    const snapshot = await eventReference.get();

    if (!snapshot.exists) {
      throw new HttpsError(
        "not-found",
        "Etkinlik bulunamadı.",
      );
    }

    const eventData = snapshot.data() ?? {};
    assertEventNotPast(eventData);

    if (String(eventData.olusturanUid ?? "").trim() !== uid) {
      throw new HttpsError(
        "permission-denied",
        "Bu etkinliği düzenleme yetkiniz bulunmuyor.",
      );
    }

    const status = String(
      eventData.durum ?? eventData.status ?? "aktif",
    )
      .trim()
      .toLowerCase();

    if (
      status !== "aktif" &&
      status !== "active" &&
      status !== "odeme_bekliyor" &&
      status !== "payment_pending" &&
      status !== "paymentpending"
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Bu durumdaki etkinlik düzenlenemez.",
      );
    }

    const publicUpdates: Record<string, unknown> = {
      updatedAt: FieldValue.serverTimestamp(),
    };

    if (typeof input.game === "string") {
      publicUpdates.oyun = input.game.trim();
    }

    if (input.playerCount !== undefined) {
      const playerCount = Number(input.playerCount);

      if (
        !Number.isInteger(playerCount) ||
        playerCount < 1 ||
        playerCount > 4
      ) {
        throw new HttpsError(
          "invalid-argument",
          "Oyuncu sayısı 1 ile 4 arasında olmalıdır.",
        );
      }

      publicUpdates.oyuncuSayisi = playerCount;
      publicUpdates.oyuncuSayisiMetni =
        `${playerCount} Oyuncu`;
    }

    if (typeof input.memberPreference === "string") {
      publicUpdates.uyeTercihi =
        input.memberPreference.trim();
    }

    if (typeof input.description === "string") {
      publicUpdates.aciklama =
        input.description.trim();
    }

    if (input.eventDate !== undefined) {
      const milliseconds = Number(input.eventDate);

      if (!Number.isFinite(milliseconds)) {
        throw new HttpsError(
          "invalid-argument",
          "Etkinlik tarihi geçersiz.",
        );
      }

      const eventDate = new Date(milliseconds);

      if (eventDate.getTime() < Date.now()) {
        throw new HttpsError(
          "invalid-argument",
          "Geçmiş tarih seçilemez.",
        );
      }

      publicUpdates.tarih =
        Timestamp.fromDate(eventDate);
    }

    if (typeof input.city === "string") {
      publicUpdates.sehir = input.city.trim();
    }

    const updatesPrivateLocation =
      input.city !== undefined ||
      input.district !== undefined ||
      input.neighborhood !== undefined ||
      input.address !== undefined ||
      input.latitude !== undefined ||
      input.longitude !== undefined;

    if (updatesPrivateLocation) {
      publicUpdates.privateLocationAvailable = true;
    }

    const batch = firestore.batch();

    batch.update(eventReference, publicUpdates);

    if (updatesPrivateLocation) {
      const locationReference = eventReference
        .collection("private")
        .doc("location");

      const privateUpdates: Record<string, unknown> = {
        updatedAt: FieldValue.serverTimestamp(),
      };

      if (typeof input.city === "string") {
        privateUpdates.sehir = input.city.trim();
      }

      if (typeof input.district === "string") {
        privateUpdates.ilce = input.district.trim();
      }

      if (typeof input.neighborhood === "string") {
        privateUpdates.semt = input.neighborhood.trim();
      }

      if (typeof input.address === "string") {
        privateUpdates.adres = input.address.trim();
      }

      if (typeof input.latitude === "number") {
        privateUpdates.latitude = input.latitude;
      }

      if (typeof input.longitude === "number") {
        privateUpdates.longitude = input.longitude;
      }

      batch.set(
        locationReference,
        privateUpdates,
        {merge: true},
      );
    }

    await batch.commit();

    return {
      success: true,
      eventId,
    };
  },
);
