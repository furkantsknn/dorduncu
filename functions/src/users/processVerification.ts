import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  FieldValue,
} from "firebase-admin/firestore";

import {firestore} from "../config/firebaseAdmin";
import {
  assertVerificationAssignment,
} from "../security/assertVerificationAssignment";
import {writeAuditLog} from "../audit/writeAuditLog";

interface ProcessVerificationRequest {
  requestId?: unknown;
  status?: unknown;
  decisionReason?: unknown;
  adminNote?: unknown;
}

export const processVerification = onCall(
  {
    region: "europe-west1",
    enforceAppCheck: true,
  },
  async (request) => {
    const data =
      request.data as ProcessVerificationRequest;

    const requestId =
      typeof data.requestId === "string" ?
        data.requestId.trim() :
        "";

    const status =
      typeof data.status === "string" ?
        data.status.trim().toLowerCase() :
        "";

    const decisionReason =
      typeof data.decisionReason === "string" ?
        data.decisionReason.trim() :
        typeof data.adminNote === "string" ?
          data.adminNote.trim() :
          "";

    if (!requestId) {
      throw new HttpsError(
        "invalid-argument",
        "Başvuru kimliği gerekli.",
      );
    }

    if (
      status !== "approved" &&
      status !== "revision" &&
      status !== "rejected"
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Geçersiz başvuru durumu.",
      );
    }

    if (
      (
        status === "rejected" ||
        status === "revision"
      ) &&
      decisionReason.length < 3
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Red veya düzeltme için neden belirtilmelidir.",
      );
    }

    const requestReference =
      firestore
        .collection(
          "verification_requests",
        )
        .doc(requestId);

    const requestSnapshot =
      await requestReference.get();

    if (!requestSnapshot.exists) {
      throw new HttpsError(
        "not-found",
        "Doğrulama başvurusu bulunamadı.",
      );
    }

    const requestData =
      requestSnapshot.data() ?? {};

    assertVerificationAssignment(
      request,
      requestData,
    );

    const uid =
      requestData.uid
        ?.toString()
        .trim() ?? "";

    if (!uid) {
      throw new HttpsError(
        "failed-precondition",
        "Başvurunun kullanıcı kimliği bulunamadı.",
      );
    }

    const identityFingerprint =
      requestData.identityFingerprint
        ?.toString()
        .trim() ?? "";

    const identityUniquenessStatus =
  requestData.identityUniquenessCheck
    ?.status
    ?.toString()
    .trim() ?? "";

    if (
      status === "approved" &&
  (
    !identityFingerprint ||
    identityUniquenessStatus !== "passed"
  )
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Kimlik benzersizlik kontrolü başarılı olmadan başvuru onaylanamaz.",
      );
    }
    const userReference =
      firestore
        .collection("users")
        .doc(uid);

    const notificationReference =
      userReference
        .collection("notifications")
        .doc();

    await firestore.runTransaction(
      async (transaction) => {
        let identityReference:
          FirebaseFirestore.DocumentReference |
          null = null;

        let identitySnapshot:
          FirebaseFirestore.DocumentSnapshot |
          null = null;

        if (identityFingerprint) {
          identityReference =
            firestore
              .collection(
                "verification_identity_keys",
              )
              .doc(identityFingerprint);

          identitySnapshot =
            await transaction.get(
              identityReference,
            );
        }

        if (
          status === "approved" &&
          identityReference
        ) {
          if (
            identitySnapshot?.exists
          ) {
            const identityData =
              identitySnapshot.data() ?? {};

            const ownerUid =
              identityData.uid
                ?.toString()
                .trim() ?? "";

            if (
              ownerUid &&
              ownerUid !== uid
            ) {
              throw new HttpsError(
                "already-exists",
                "Bu kimlik başka bir hesapta kullanılmış.",
              );
            }
          }

          transaction.set(
            identityReference,
            {
              uid,
              status: "approved",
              approvedAt:
                FieldValue.serverTimestamp(),
              updatedAt:
                FieldValue.serverTimestamp(),
            },
            {
              merge: true,
            },
          );
        }

        if (
          (
            status === "rejected" ||
            status === "revision"
          ) &&
          identityReference &&
          identitySnapshot?.exists
        ) {
          const identityData =
            identitySnapshot.data() ?? {};

          const ownerUid =
            identityData.uid
              ?.toString()
              .trim() ?? "";

          const identityStatus =
            identityData.status
              ?.toString()
              .trim() ?? "";

          if (
            ownerUid === uid &&
            identityStatus !== "approved"
          ) {
            transaction.delete(
              identityReference,
            );
          }
        }

        transaction.update(
          requestReference,
          {
            status,
            decisionReason,
            adminNote:
              FieldValue.delete(),
            reviewedAt:
              FieldValue.serverTimestamp(),
            reviewedBy:
              request.auth.uid,
            updatedAt:
              FieldValue.serverTimestamp(),
          },
        );

        if (status === "approved") {
          transaction.set(
            userReference,
            {
              verified: true,
              verificationStatus:
                "approved",
              verificationRejectionReason:
                FieldValue.delete(),
              verificationAdminNote:
                FieldValue.delete(),
              oyuncuRozeti: true,
              guncellemeTarihi:
                FieldValue.serverTimestamp(),
            },
            {
              merge: true,
            },
          );

          transaction.set(
            notificationReference,
            {
              notificationId:
                notificationReference.id,
              userId: uid,
              actorId:
                request.auth.uid,
              type:
                "verification_approved",
              title:
                "Profilin doğrulandı",
              message:
                "Profil doğrulama başvurun onaylandı.",
              isRead: false,
              read: false,
              okundu: false,
              createdAt:
                FieldValue.serverTimestamp(),
              updatedAt:
                FieldValue.serverTimestamp(),
            },
          );
        } else {
          transaction.set(
            userReference,
            {
              verified: false,
              verificationStatus:
                status,
              verificationRejectionReason:
                decisionReason,
              verificationAdminNote:
                FieldValue.delete(),
              oyuncuRozeti: false,
              guncellemeTarihi:
                FieldValue.serverTimestamp(),
            },
            {
              merge: true,
            },
          );

          const title =
            status === "revision" ?
              "Doğrulama belgesi düzeltme gerekli" :
              "Profil doğrulama başvurun reddedildi";

          const message =
            status === "revision" ?
              [
                "Belgeni düzeltip yeniden göndermen gerekiyor.",
                `Neden: ${decisionReason}`,
              ].join(" ") :
              [
                "Profil doğrulama başvurun reddedildi.",
                `Neden: ${decisionReason}`,
              ].join(" ");

          transaction.set(
            notificationReference,
            {
              notificationId:
                notificationReference.id,
              userId: uid,
              actorId:
                request.auth.uid,
              type:
                status === "revision" ?
                  "verification_revision" :
                  "verification_rejected",
              title,
              message,
              reason: decisionReason,
              isRead: false,
              read: false,
              okundu: false,
              createdAt:
                FieldValue.serverTimestamp(),
              updatedAt:
                FieldValue.serverTimestamp(),
            },
          );
        }
      },
    );

    await writeAuditLog({
      action: "processVerification",
      performedBy:
        request.auth.uid,
      targetUid: uid,
      metadata: {
        requestId,
        status,
        decisionReason,
      },
    });

    return {
      success: true,
      uid,
      status,
    };
  },
);
