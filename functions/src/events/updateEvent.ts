import {HttpsError, onCall} from "firebase-functions/v2/https";
import {
  FieldValue,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import {approximateCoordinate} from "./createEvent";
import {assertEventNotPast} from "./eventLifecycle";
import {isPlusMembershipActive} from "../users/plusMembership";
import {
  evaluateEventSchedule,
  eventStartIsUnchanged,
  EVENT_FREE_TODAY_CODE,
} from "./eventSchedulePolicy";
import {
  evaluateSoughtPlayerCount,
  PLUS_PLAYER_LIMIT_CODE,
  soughtPlayerCountIsUnchanged,
} from "./plusPlayerLimit";
import {getEventCategory, getEventGame} from "./eventCatalog";

const REGION = "europe-west1";

/**
 * Reads a Firestore timestamp as epoch milliseconds.
 *
 * @param {unknown} value Stored start or date.
 * @return {number | null} Milliseconds, when the value is a timestamp.
 */
function timestampMillis(value: unknown): number | null {
  if (value instanceof Timestamp) {
    return value.toMillis();
  }

  return null;
}

/**
 * Validates an optional coordinate from the edit request.
 *
 * @param {unknown} value Supplied coordinate.
 * @param {string} fieldName Field label for the error.
 * @param {number} limit Absolute maximum.
 * @return {number | null} Coordinate, or null when not supplied.
 */
function optionalCoordinate(
  value: unknown,
  fieldName: string,
  limit: number,
): number | null {
  if (value === undefined || value === null) {
    return null;
  }

  if (
    typeof value !== "number" ||
    !Number.isFinite(value) ||
    Math.abs(value) > limit
  ) {
    throw new HttpsError("invalid-argument", `${fieldName} geçerli değil.`);
  }

  return value;
}

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

    if (input.gameId !== undefined) {
      const gameId = String(input.gameId ?? "").trim();
      const game = getEventGame(gameId);
      const category = game ? getEventCategory(game.categoryId) : null;
      if (!game || !category || game.id !== gameId) {
        throw new HttpsError(
          "invalid-argument",
          "Geçerli bir oyun veya spor seçilmelidir.",
        );
      }
      publicUpdates.gameId = game.id;
      publicUpdates.gameName = game.name;
      publicUpdates.categoryId = category.id;
      publicUpdates.categoryName = category.name;
      publicUpdates.oyun = `${game.emoji} ${game.name}`;
    }

    let plusActive: boolean | undefined;

    const readPlusActive = async (): Promise<boolean> => {
      if (plusActive !== undefined) {
        return plusActive;
      }

      const userSnapshot = await firestore
        .collection("users")
        .doc(uid)
        .get();
      plusActive = userSnapshot.exists &&
        isPlusMembershipActive(userSnapshot.data() ?? {});
      return plusActive;
    };

    if (input.playerCount !== undefined) {
      const playerCount = Number(input.playerCount);
      const playerChanged = !soughtPlayerCountIsUnchanged(
        playerCount,
        eventData.oyuncuSayisi ?? eventData.playerCount,
      );

      if (playerChanged) {
        const playerLimit = evaluateSoughtPlayerCount(
          playerCount,
          await readPlusActive(),
        );

        if (playerLimit === "invalid_range") {
          throw new HttpsError(
            "invalid-argument",
            "Oyuncu sayısı pozitif bir tam sayı olmalıdır.",
          );
        }

        if (playerLimit === "plus_required") {
          throw new HttpsError(
            "permission-denied",
            "2 veya daha fazla oyuncu için Plus üyelik gerekir.",
            {code: PLUS_PLAYER_LIMIT_CODE},
          );
        }

        publicUpdates.oyuncuSayisi = playerCount;
        publicUpdates.oyuncuSayisiMetni =
          `${playerCount} Oyuncu`;
      }
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

      const storedStart = timestampMillis(eventData.startAt) ??
        timestampMillis(eventData.tarih);
      const dateChanged = !eventStartIsUnchanged(
        milliseconds,
        storedStart,
      );

      if (dateChanged) {
        const schedule = evaluateEventSchedule(
          milliseconds,
          Date.now(),
          await readPlusActive(),
        );

        if (schedule === "past") {
          throw new HttpsError(
            "invalid-argument",
            "Geçmiş tarih seçilemez.",
          );
        }

        if (schedule === "free_not_today") {
          throw new HttpsError(
            "permission-denied",
            "Ücretsiz üyelikte etkinlik yalnızca bugün için açılabilir.",
            {code: EVENT_FREE_TODAY_CODE},
          );
        }

        const eventDate = Timestamp.fromMillis(milliseconds);
        publicUpdates.tarih = eventDate;
        publicUpdates.startAt = eventDate;
      }
    }

    if (typeof input.city === "string") {
      publicUpdates.sehir = input.city.trim();
    }

    if (typeof input.district === "string") {
      publicUpdates.ilce = input.district.trim();
    }

    const latitude = optionalCoordinate(input.latitude, "Enlem", 90);
    const longitude = optionalCoordinate(input.longitude, "Boylam", 180);

    if (latitude !== null) {
      publicUpdates.approxLatitude = approximateCoordinate(latitude);
    }

    if (longitude !== null) {
      publicUpdates.approxLongitude = approximateCoordinate(longitude);
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

      if (latitude !== null) {
        privateUpdates.latitude = latitude;
      }

      if (longitude !== null) {
        privateUpdates.longitude = longitude;
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
