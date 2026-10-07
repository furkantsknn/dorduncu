import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  FieldValue,
  Timestamp,
} from "firebase-admin/firestore";

import {firestore} from "../config/firebaseAdmin";
import {
  calculateEventPricing,
  MAXIMUM_DURATION_MINUTES,
  MINIMUM_DURATION_MINUTES,
} from "./eventCatalog";
import {
  ACCESS_MODEL_FREE,
  APPLICATION_LIFECYCLE_VERSION,
  applicationPaymentStatus,
} from "./eventLifecycle";
import {isPlusMembershipActive} from "../users/plusMembership";

interface CreateEventRequest {
  gameId?: unknown;
  playerCount?: unknown;
  memberPreference?: unknown;
  description?: unknown;
  city?: unknown;
  district?: unknown;
  neighborhood?: unknown;
  address?: unknown;
  latitude?: unknown;
  longitude?: unknown;
  startAt?: unknown;
  endAt?: unknown;
}

const allowedMemberPreferences = new Set<string>([
  "Herkes",
  "Normal Üye",
  "Plus Üye",
]);
/**
 * Validates a required string.
 * @param {unknown} value Incoming value.
 * @param {string} fieldName Field name.
 * @param {number} maxLength Maximum allowed length.
 * @return {string} Normalized string.
 */
function requireString(

  value: unknown,
  fieldName: string,
  maxLength: number
): string {
  if (typeof value !== "string") {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} geçerli bir metin olmalıdır.`
    );
  }

  const normalizedValue = value.trim();

  if (normalizedValue.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} zorunludur.`
    );
  }

  if (normalizedValue.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} en fazla ${maxLength} karakter olabilir.`
    );
  }

  return normalizedValue;
}

/**
 * Validates an optional string.
 * @param {unknown} value Incoming value.
 * @param {string} fieldName Field name.
 * @param {number} maxLength Maximum allowed length.
 * @return {string} Normalized string.
 */
function optionalString(
  value: unknown,
  fieldName: string,
  maxLength: number
): string {
  if (value === undefined || value === null) {
    return "";
  }

  if (typeof value !== "string") {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} geçerli bir metin olmalıdır.`
    );
  }

  const normalizedValue = value.trim();

  if (normalizedValue.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} en fazla ${maxLength} karakter olabilir.`
    );
  }

  return normalizedValue;
}

/**
 * Validates an integer.
 * @param {unknown} value Incoming value.
 * @param {string} fieldName Field name.
 * @return {number} Validated integer.
 */
function requireInteger(
  value: unknown,
  fieldName: string
): number {
  if (
    typeof value !== "number" ||
    !Number.isInteger(value)
  ) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} geçerli bir tam sayı olmalıdır.`
    );
  }

  return value;
}

/**
 * Validates latitude or longitude.
 * @param {unknown} value Incoming value.
 * @param {string} fieldName Field name.
 * @param {number} minimum Minimum allowed value.
 * @param {number} maximum Maximum allowed value.
 * @return {number} Validated coordinate.
 */
function requireCoordinate(
  value: unknown,
  fieldName: string,
  minimum: number,
  maximum: number
): number {
  if (
    typeof value !== "number" ||
    !Number.isFinite(value) ||
    value < minimum ||
    value > maximum
  ) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} geçerli değil.`
    );
  }

  return value;
}

/**
 * Validates a date value.
 * @param {unknown} value Incoming value.
 * @param {string} fieldName Field name.
 * @return {Date} Parsed date.
 */
function requireDate(
  value: unknown,
  fieldName: string
): Date {
  let date: Date;

  if (typeof value === "number") {
    date = new Date(value);
  } else if (typeof value === "string") {
    date = new Date(value);
  } else {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} geçerli bir tarih olmalıdır.`
    );
  }

  if (Number.isNaN(date.getTime())) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} geçerli bir tarih olmalıdır.`
    );
  }

  return date;
}

/**
 * Rounds a coordinate for public display.
 * @param {number} value Coordinate.
 * @return {number} Rounded coordinate.
 */
function approximateCoordinate(value: number): number {
  return Math.round(value * 100) / 100;
}

export const createEvent = onCall(
  {
    region: "europe-west1",
    enforceAppCheck: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Etkinlik oluşturmak için giriş yapmalısınız."
      );
    }

    const uid = request.auth.uid;
    const data = request.data as CreateEventRequest;

    const gameId = requireString(
      data.gameId,
      "gameId",
      50
    );

    const playerCount = requireInteger(
      data.playerCount,
      "playerCount"
    );

    if (playerCount < 1 || playerCount > 4) {
      throw new HttpsError(
        "invalid-argument",
        "Oyuncu sayısı 1 ile 4 arasında olmalıdır."
      );
    }

    const memberPreference = requireString(
      data.memberPreference,
      "memberPreference",
      30
    );

    if (!allowedMemberPreferences.has(memberPreference)) {
      throw new HttpsError(
        "invalid-argument",
        "Üye tercihi geçerli değil."
      );
    }

    const description = optionalString(
      data.description,
      "description",
      1000
    );

    const city = requireString(
      data.city,
      "city",
      100
    );

    const district = requireString(
      data.district,
      "district",
      100
    );

    const neighborhood = requireString(
      data.neighborhood,
      "neighborhood",
      150
    );

    const address = requireString(
      data.address,
      "address",
      500
    );

    const latitude = requireCoordinate(
      data.latitude,
      "latitude",
      -90,
      90
    );

    const longitude = requireCoordinate(
      data.longitude,
      "longitude",
      -180,
      180
    );

    if (latitude === 0 || longitude === 0) {
      throw new HttpsError(
        "invalid-argument",
        "Etkinlik konumu seçilmelidir."
      );
    }

    const startAt = requireDate(
      data.startAt,
      "startAt"
    );

    const endAt = requireDate(
      data.endAt,
      "endAt"
    );

    if (!endAt.getTime() || endAt <= startAt) {
      throw new HttpsError(
        "invalid-argument",
        "Bitiş zamanı başlangıç zamanından sonra olmalıdır."
      );
    }

    const durationMinutes = Math.round(
      (endAt.getTime() - startAt.getTime()) /
      (60 * 1000)
    );

    if (
      durationMinutes < MINIMUM_DURATION_MINUTES ||
      durationMinutes > MAXIMUM_DURATION_MINUTES
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Etkinlik süresi 1 ile 6 saat arasında olmalıdır."
      );
    }

    if (durationMinutes % 30 !== 0) {
      throw new HttpsError(
        "invalid-argument",
        "Etkinlik süresi 30 dakikalık aralıklarla seçilmelidir."
      );
    }

    const now = new Date();

    if (startAt.getTime() <= now.getTime()) {
      throw new HttpsError(
        "invalid-argument",
        "Geçmiş tarihli etkinlik oluşturulamaz."
      );
    }

    const userReference =
      firestore.collection("users").doc(uid);

    const userSnapshot = await userReference.get();

    if (!userSnapshot.exists) {
      throw new HttpsError(
        "failed-precondition",
        "Kullanıcı profili bulunamadı."
      );
    }

    const userData =
      userSnapshot.data() ??
      {};

    const accountStatus =
      userData.hesapDurumu?.toString() ??
      "active";

    if (
      accountStatus === "blocked" ||
      accountStatus === "suspended" ||
      accountStatus === "disabled"
    ) {
      throw new HttpsError(
        "permission-denied",
        "Hesabınız etkinlik oluşturmaya uygun değil."
      );
    }

    const isPlus = isPlusMembershipActive(userData);

    const today = new Date(
      now.getFullYear(),
      now.getMonth(),
      now.getDate()
    );

    const maximumEventDate = new Date(today);

    maximumEventDate.setDate(
      maximumEventDate.getDate() +
      (isPlus ? 365 : 1)
    );

    const selectedEventDay = new Date(
      startAt.getFullYear(),
      startAt.getMonth(),
      startAt.getDate()
    );

    if (selectedEventDay > maximumEventDate) {
      throw new HttpsError(
        "permission-denied",
        isPlus ?
          "Etkinlik en fazla 365 gün sonrası için oluşturulabilir." :
          "Normal üyeler yalnızca bugün veya yarın için etkinlik oluşturabilir."
      );
    }

    if (
      memberPreference === "Plus Üye" &&
      !isPlus
    ) {
      throw new HttpsError(
        "permission-denied",
        "Yalnızca Plus üyeler Plus Üye tercihiyle etkinlik oluşturabilir."
      );
    }

    const pricing = calculateEventPricing(
      gameId,
      playerCount,
      durationMinutes
    );

    if (!pricing) {
      throw new HttpsError(
        "invalid-argument",
        "Oyun veya fiyatlandırma bilgileri geçerli değil."
      );
    }

    const eventReference =
      firestore.collection("events").doc();

    const privateLocationReference =
      eventReference
        .collection("private")
        .doc("location");

    const creatorProfileName =
      userData.profilAdi?.toString().trim() ??
      "";

    const creatorProfilePhoto =
      userData.profilFotografi?.toString().trim() ??
      "";

    const creatorVerified =
      userData.verified === true ||
      userData.verificationStatus === "approved";

    const eventData = {
      eventId: eventReference.id,

      categoryId: pricing.category.id,
      categoryName: pricing.category.name,

      gameId: pricing.game.id,
      gameName: pricing.game.name,
      oyun: `${pricing.game.emoji} ${pricing.game.name}`,

      oyuncuSayisi: playerCount,
      oyuncuSayisiMetni: `${playerCount} Oyuncu`,
      uyeTercihi: memberPreference,
      aciklama: description,

      sehir: city,
      ilce: district,
      privateLocationAvailable: true,
      approxLatitude: approximateCoordinate(latitude),
      approxLongitude: approximateCoordinate(longitude),

      startAt: Timestamp.fromDate(startAt),
      endAt: Timestamp.fromDate(endAt),
      tarih: Timestamp.fromDate(startAt),

      olusturanUid: uid,
      olusturanProfilAdi: creatorProfileName,
      olusturanProfilFotografi:
        creatorProfilePhoto,
      olusturanPlus: isPlus,
      olusturanDogrulanmis:
        creatorVerified,

      katilanlar: [uid],
      selectedPlayerIds: [],
      basvuranOyuncuIds: [],
      basvuruSayisi: 0,
      chatMemberUids: [uid],

      lifecycleVersion: APPLICATION_LIFECYCLE_VERSION,
      accessModel: ACCESS_MODEL_FREE,
      paymentRequired: false,
      paymentId: "",
      paymentStatus: applicationPaymentStatus.notRequired,
      customerTotal: 0,

      durationMinutes:
        pricing.durationMinutes,
      basePricePerPlayer:
        pricing.basePricePerPlayer,
      durationFactor:
        pricing.durationFactor,
      unitPricePerHour:
        pricing.basePricePerPlayer,

      playerGrossEarning: 0,
      totalPlayerGross: 0,
      platformShare: 0,
      pricingVersion:
        pricing.pricingVersion,

      favoriSayisi: 0,
      durum: "aktif",
      cancellationReason: "",

      createdAt:
        FieldValue.serverTimestamp(),
      olusturmaTarihi:
        FieldValue.serverTimestamp(),
      updatedAt:
        FieldValue.serverTimestamp(),
    };

    const privateLocationData = {
      eventId: eventReference.id,
      sehir: city,
      ilce: district,
      semt: neighborhood,
      adres: address,
      latitude,
      longitude,
      haritadanSecildi: true,
      createdAt:
        FieldValue.serverTimestamp(),
      updatedAt:
        FieldValue.serverTimestamp(),
    };

    const batch = firestore.batch();

    batch.create(
      eventReference,
      eventData
    );

    batch.create(
      privateLocationReference,
      privateLocationData
    );

    await batch.commit();

    return {
      success: true,
      eventId: eventReference.id,
      pricing: {
        customerTotal: 0,
        durationMinutes:
          pricing.durationMinutes,
        pricingVersion:
          pricing.pricingVersion,
      },
    };
  }
);
