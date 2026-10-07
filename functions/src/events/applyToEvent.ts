/* eslint-disable require-jsdoc */
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";
import {
  APPLICATION_LIFECYCLE_VERSION,
  addressAccessStatus,
  applicationDecisionStatus,
  applicationPaymentStatus,
  applicationStatus,
  assertEventNotPast,
  reservationStatus,
} from "./eventLifecycle";
import {isPlusMembershipActive} from "../users/plusMembership";
import {
  writeUserNotification,
} from "../notifications/writeUserNotification";

const REGION = "europe-west1";

export const applyToEvent = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const playerId = request.auth?.uid;

    if (!playerId) {
      throw new HttpsError(
        "unauthenticated",
        "Bu işlem için kullanıcı girişi gereklidir.",
      );
    }

    const eventId = readRequiredString(
      request.data,
      "eventId",
      "Etkinlik kimliği gereklidir.",
    );

    const note = readOptionalString(
      request.data,
      "note",
    );

    const firestore = getFirestore();

    const eventReference =
      firestore.collection("events").doc(eventId);

    const playerReference =
      firestore.collection("users").doc(playerId);

    const applicationReference =
      eventReference
        .collection("applications")
        .doc(playerId);

    let organizerId = "";
    let playerProfileName = "";
    let eventTitle = "";

    await firestore.runTransaction(
      async (transaction) => {
        const eventSnapshot =
          await transaction.get(eventReference);

        const playerSnapshot =
          await transaction.get(playerReference);

        const applicationSnapshot =
          await transaction.get(applicationReference);

        if (!eventSnapshot.exists) {
          throw new HttpsError(
            "not-found",
            "Etkinlik bulunamadı.",
          );
        }

        if (!playerSnapshot.exists) {
          throw new HttpsError(
            "not-found",
            "Oyuncu profili bulunamadı.",
          );
        }

        if (applicationSnapshot.exists) {
          const existingApplicationData =
            applicationSnapshot.data() ?? {};

          const existingApplicationStatus = String(
            existingApplicationData.status ?? "",
          )
            .trim()
            .toLowerCase();

          if (
            existingApplicationStatus !==
            applicationStatus.rejected
          ) {
            throw new HttpsError(
              "already-exists",
              "Bu etkinliğe daha önce başvurdunuz.",
            );
          }
        }

        const eventData = eventSnapshot.data() ?? {};
        const playerData = playerSnapshot.data() ?? {};

        organizerId = String(
          eventData.olusturanUid ?? "",
        ).trim();

        eventTitle = String(
          eventData.gameName ??
          eventData.oyun ??
          eventData.game ??
          "Etkinlik",
        ).trim();

        playerProfileName = String(
          playerData.profilAdi ??
          playerData.ad ??
          "Bir oyuncu",
        ).trim();

        if (!organizerId) {
          throw new HttpsError(
            "failed-precondition",
            "Etkinlik sahibi bilgisi bulunamadı.",
          );
        }

        if (organizerId === playerId) {
          throw new HttpsError(
            "failed-precondition",
            "Kendi etkinliğinize başvuramazsınız.",
          );
        }

        const organizerBlockedPlayerReference = firestore
          .collection("users")
          .doc(organizerId)
          .collection("blockedUsers")
          .doc(playerId);

        const playerBlockedOrganizerReference = firestore
          .collection("users")
          .doc(playerId)
          .collection("blockedUsers")
          .doc(organizerId);

        const organizerBlockedPlayer =
          await transaction.get(
            organizerBlockedPlayerReference,
          );

        const playerBlockedOrganizer =
          await transaction.get(
            playerBlockedOrganizerReference,
          );

        if (
          organizerBlockedPlayer.exists ||
          playerBlockedOrganizer.exists
        ) {
          throw new HttpsError(
            "permission-denied",
            "Bu kullanıcıyla etkinlik etkileşimi kullanılamıyor.",
          );
        }

        const eventStatus = String(
          eventData.durum ??
          eventData.status ??
          "",
        )
          .trim()
          .toLowerCase();

        if (
          eventStatus !== "aktif" &&
          eventStatus !== "active"
        ) {
          throw new HttpsError(
            "failed-precondition",
            "Etkinlik başvuru kabul etmiyor.",
          );
        }

        assertEventNotPast(eventData);

        const selectedPlayerIds = readStringList(
          eventData.selectedPlayerIds,
        );

        const requiredPlayerCount = Number(
          eventData.oyuncuSayisi ??
          eventData.playerCount ??
          1,
        );

        if (
          !Number.isInteger(requiredPlayerCount) ||
          requiredPlayerCount < 1 ||
          requiredPlayerCount > 4
        ) {
          throw new HttpsError(
            "failed-precondition",
            "Etkinliğin oyuncu sayısı geçersiz.",
          );
        }

        if (
          selectedPlayerIds.length >=
          requiredPlayerCount
        ) {
          throw new HttpsError(
            "failed-precondition",
            "Etkinlik için gerekli oyuncu sayısı tamamlandı.",
          );
        }

        if (selectedPlayerIds.includes(playerId)) {
          throw new HttpsError(
            "already-exists",
            "Bu etkinlik için zaten seçildiniz.",
          );
        }

        if (playerData.oyuncuRozeti !== true) {
          throw new HttpsError(
            "failed-precondition",
            "Başvuru yapabilmek için Oyuncu Rozeti gereklidir.",
          );
        }

        const accountStatus = String(
          playerData.hesapDurumu ??
          playerData.accountStatus ??
          "active",
        )
          .trim()
          .toLowerCase();

        if (
          accountStatus === "blocked" ||
          accountStatus === "suspended" ||
          accountStatus === "disabled"
        ) {
          throw new HttpsError(
            "permission-denied",
            "Hesabınız başvuru yapmaya uygun değil.",
          );
        }

        const preference = String(
          eventData.uyeTercihi ?? "Herkes",
        ).trim();

        const playerIsPlus =
          isPlusMembershipActive(playerData);

        if (
          preference === "Plus Üye" &&
          !playerIsPlus
        ) {
          throw new HttpsError(
            "failed-precondition",
            "Bu etkinlik yalnızca Plus oyuncu başvurularını kabul ediyor.",
          );
        }

        if (
          preference === "Normal Üye" &&
          playerIsPlus
        ) {
          throw new HttpsError(
            "failed-precondition",
            "Organizatör bu etkinlik için Normal Üye tercih etti.",
          );
        }

        const applicantIds = readStringList(
          eventData.basvuranOyuncuIds,
        );

        if (applicantIds.includes(playerId)) {
          throw new HttpsError(
            "already-exists",
            "Bu etkinliğe daha önce başvurdunuz.",
          );
        }

        transaction.set(
          applicationReference,
          {
            applicationId: playerId,
            eventId,
            organizerId,
            playerId,
            playerProfileName:
              String(playerData.profilAdi ?? ""),
            playerProfilePhoto:
              String(playerData.profilFotografi ?? ""),
            playerPlus: playerIsPlus,
            playerVerified:
              playerData.verified === true ||
              playerData.verificationStatus === "approved",
            note,
            lifecycleVersion:
              APPLICATION_LIFECYCLE_VERSION,
            status: applicationStatus.pending,
            decisionStatus:
              applicationDecisionStatus.awaitingOrganizer,
            paymentStatus:
              applicationPaymentStatus.notRequired,
            addressAccessStatus:
              addressAccessStatus.locked,
            reservationStatus:
              reservationStatus.none,
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          },
        );

        transaction.update(
          eventReference,
          {
            basvuranOyuncuIds:
              FieldValue.arrayUnion(playerId),
            basvuruSayisi:
              FieldValue.increment(1),
            lifecycleVersion:
              APPLICATION_LIFECYCLE_VERSION,
            updatedAt:
              FieldValue.serverTimestamp(),
          },
        );
      },
    );

    await writeUserNotification(
      firestore,
      {
        userId: organizerId,
        actorId: playerId,
        eventId,
        type: "application_received",
        title: "Yeni Oyuncu Başvurusu",
        message:
          `${playerProfileName || "Bir oyuncu"} etkinliğine başvurdu.`,
        route: "event_applications",
        data: {
          eventId,
          applicantUserId: playerId,
          eventTitle,
        },
      },
    );

    return {
      success: true,
      eventId,
      playerId,
      applicationStatus:
        applicationStatus.pending,
    };
  },
);

function readRequiredString(
  data: unknown,
  key: string,
  errorMessage: string,
): string {
  if (data === null || typeof data !== "object") {
    throw new HttpsError(
      "invalid-argument",
      errorMessage,
    );
  }

  const value = String(
    (data as Record<string, unknown>)[key] ?? "",
  ).trim();

  if (!value) {
    throw new HttpsError(
      "invalid-argument",
      errorMessage,
    );
  }

  return value;
}

function readOptionalString(
  data: unknown,
  key: string,
): string {
  if (data === null || typeof data !== "object") {
    return "";
  }

  return String(
    (data as Record<string, unknown>)[key] ?? "",
  ).trim();
}

function readStringList(
  value: unknown,
): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((item) => String(item).trim())
    .filter((item) => item.length > 0);
}
