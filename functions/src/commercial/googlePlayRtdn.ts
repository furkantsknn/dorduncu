import {createHash} from "crypto";

import {
  FieldValue,
  Timestamp,
} from "firebase-admin/firestore";
import {defineString} from "firebase-functions/params";
import {onMessagePublished} from "firebase-functions/v2/pubsub";

import {
  badgeRemains,
  revokeBadgeGrant,
} from "./giftPurchasePolicy";
import {
  evaluatePlusAccess,
  revokeGiftDuration,
} from "./plusEntitlementPolicy";
import {firestore} from "../config/firebaseAdmin";
import {
  writeAuditLogInTransaction,
} from "../audit/writeAuditLog";
import {
  writeUserNotificationInTransaction,
} from "../notifications/writeUserNotification";
import {
  appendCommercialEvent,
  transitionCommercialOperation,
} from "./commercialLedger";
import {
  getGooglePlaySubscriptionStatus,
  hashPurchaseToken,
} from "./googlePlayVerification";

const androidPackageName = defineString(
  "ANDROID_PACKAGE_NAME",
  {
    default: "com.dortapp.dort",
  },
);

interface DeveloperNotification {
  version?: string;
  packageName?: string;
  eventTimeMillis?: string;
  subscriptionNotification?: {
    version?: string;
    notificationType?: number;
    purchaseToken?: string;
  };
  oneTimeProductNotification?: {
    version?: string;
    notificationType?: number;
    purchaseToken?: string;
    sku?: string;
  };
  voidedPurchaseNotification?: {
    purchaseToken?: string;
    orderId?: string;
    productType?: number;
    refundType?: number;
  };
  pendingRefundReviewNotification?: {
    version?: string;
    pendingRefundToken?: string;
    orderId?: string;
    refundReason?: number;
    obfuscatedAccountId?: string;
    obfuscatedProfileId?: string;
  };
  testNotification?: {
    version?: string;
  };
}

interface TokenRegistry {
  uid: string;
  productId: string;
  googlePlayProductId: string;
  kind:
    "plus_subscription" |
    "badge_non_consumable" |
    "badge_gift" |
    "plus_gift";
  latestOperationId: string;
}

/**
 * Processes Google Play Real-time Developer Notifications.
 *
 * Topic name expected at deploy time: dorduncu-google-play-rtdn.
 * The Play Console Pub/Sub subscription will be connected during release
 * configuration, not during source-only stage work.
 */
export const processGooglePlayRtdn = onMessagePublished(
  {
    topic: "dorduncu-google-play-rtdn",
    region: "europe-west1",
    retry: true,
  },
  async (event) => {
    const eventId = String(event.id ?? "").trim();

    if (!eventId) {
      throw new Error(
        "Google Play RTDN event has no CloudEvent id.",
      );
    }

    const eventReference = firestore
      .collection("google_play_rtdn_events")
      .doc(eventId);

    const existingEvent = await eventReference.get();

    if (existingEvent.data()?.status === "completed") {
      return;
    }

    const notification =
      event.data.message.json as DeveloperNotification;

    const packageName =
      String(notification.packageName ?? "").trim();

    if (packageName !== androidPackageName.value()) {
      await eventReference.set(
        {
          eventId,
          status: "ignored_package_mismatch",
          packageName,
          receivedAt:
            FieldValue.serverTimestamp(),
          updatedAt:
            FieldValue.serverTimestamp(),
        },
        {
          merge: true,
        },
      );

      return;
    }

    await eventReference.set(
      {
        eventId,
        status: "processing",
        packageName,
        providerEventTimeMillis:
          normalizeOptionalString(
            notification.eventTimeMillis,
          ),
        receivedAt:
          existingEvent.exists ?
            existingEvent.data()?.receivedAt ??
              FieldValue.serverTimestamp() :
            FieldValue.serverTimestamp(),
        updatedAt:
          FieldValue.serverTimestamp(),
      },
      {
        merge: true,
      },
    );

    if (notification.testNotification != null) {
      await completeRtdnEvent(
        eventReference,
        "test",
      );
      return;
    }

    if (
      notification.subscriptionNotification != null
    ) {
      await handleSubscriptionNotification(
        eventId,
        notification.subscriptionNotification,
      );
      await completeRtdnEvent(
        eventReference,
        "subscription",
      );
      return;
    }

    if (
      notification.voidedPurchaseNotification != null
    ) {
      await handleVoidedPurchase(
        eventId,
        notification.voidedPurchaseNotification,
      );
      await completeRtdnEvent(
        eventReference,
        "voided_purchase",
      );
      return;
    }

    if (
      notification.pendingRefundReviewNotification != null
    ) {
      await handlePendingRefundReview(
        eventId,
        notification.pendingRefundReviewNotification,
      );
      await completeRtdnEvent(
        eventReference,
        "pending_refund_review",
      );
      return;
    }

    if (
      notification.oneTimeProductNotification != null
    ) {
      await handleOneTimeProductNotification(
        eventId,
        notification.oneTimeProductNotification,
      );
      await completeRtdnEvent(
        eventReference,
        "one_time_product",
      );
      return;
    }

    await completeRtdnEvent(
      eventReference,
      "unknown",
    );
  },
);

/**
 * Synchronizes Plus entitlement from Google Play source of truth.
 *
 * @param {string} eventId RTDN event id.
 * @param {object} notification Subscription notification.
 * @return {Promise<void>} Completion promise.
 */
async function handleSubscriptionNotification(
  eventId: string,
  notification: {
    notificationType?: number;
    purchaseToken?: string;
  },
): Promise<void> {
  const purchaseToken =
    requireProviderString(
      notification.purchaseToken,
      "purchaseToken",
    );
  const tokenHash =
    hashPurchaseToken(purchaseToken);

  const registrySnapshot = await firestore
    .collection("google_play_purchase_tokens")
    .doc(tokenHash)
    .get();

  if (!registrySnapshot.exists) {
    await writeUnmatchedRtdn(
      eventId,
      tokenHash,
      "subscription",
      notification.notificationType,
    );
    return;
  }

  const registry =
    normalizeTokenRegistry(
      registrySnapshot.data() ?? {},
    );

  if (registry.kind !== "plus_subscription") {
    throw new Error(
      "Subscription RTDN token is not registered as Plus.",
    );
  }

  const status =
    await getGooglePlaySubscriptionStatus(
      registry.googlePlayProductId,
      purchaseToken,
    );

  await firestore.runTransaction(
    async (transaction) => {
      const userReference = firestore
        .collection("users")
        .doc(registry.uid);
      const tokenReference = firestore
        .collection("google_play_purchase_tokens")
        .doc(tokenHash);
      const lifecycleReference = firestore
        .collection("google_play_lifecycle_events")
        .doc(eventId);

      const lifecycleSnapshot =
        await transaction.get(lifecycleReference);
      if (lifecycleSnapshot.exists) {
        return;
      }

      const userSnapshot =
        await transaction.get(userReference);

      const userData =
        userSnapshot.data() ?? {};
      const currentTokenHash =
        String(
          userData.plusGooglePlayTokenHash ?? "",
        ).trim();

      const giftValue = userData.plusGiftExpiresAt;
      const giftExpiry = giftValue instanceof Timestamp ?
        giftValue.toDate() :
        null;
      const subscriptionExpiry =
        status.hasEntitlement && status.expiryTime != null ?
          status.expiryTime :
          null;
      const shouldWriteSubscription =
        subscriptionExpiry != null ||
        currentTokenHash === tokenHash;

      if (shouldWriteSubscription) {
        const access = evaluatePlusAccess({
          plusFlag: true,
          subscriptionExpiresAtMs:
            subscriptionExpiry?.getTime() ?? null,
          giftExpiresAtMs: giftExpiry?.getTime() ?? null,
          subscriptionState: status.subscriptionState,
          nowMs: Date.now(),
        });

        transaction.set(
          userReference,
          {
            plus: access.active,
            isPlus: access.active,
            plusGooglePlayTokenHash: tokenHash,
            plusGooglePlayProductId:
              registry.googlePlayProductId,
            plusSubscriptionState:
              status.subscriptionState,
            plusSubscriptionExpiresAt:
              subscriptionExpiry == null ?
                null :
                Timestamp.fromDate(subscriptionExpiry),
            plusExpiresAt: access.expiresAtMs == null ?
              null :
              Timestamp.fromMillis(access.expiresAtMs),
            plusUpdatedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
      }

      transaction.set(
        tokenReference,
        {
          active:
            status.hasEntitlement,
          latestOrderId:
            status.orderId,
          latestExpiryAt:
            status.expiryTime == null ?
              null :
              Timestamp.fromDate(
                status.expiryTime,
              ),
          latestSubscriptionState:
            status.subscriptionState,
          updatedAt:
            FieldValue.serverTimestamp(),
        },
        {
          merge: true,
        },
      );

      transaction.create(
        lifecycleReference,
        {
          eventId,
          provider: "google_play",
          kind: "plus_subscription",
          uid: registry.uid,
          productId:
            registry.productId,
          googlePlayProductId:
            registry.googlePlayProductId,
          purchaseTokenHash:
            tokenHash,
          notificationType:
            notification.notificationType ?? null,
          subscriptionState:
            status.subscriptionState,
          hasEntitlement:
            status.hasEntitlement,
          latestOrderId:
            status.orderId,
          expiryAt:
            status.expiryTime == null ?
              null :
              Timestamp.fromDate(
                status.expiryTime,
              ),
          createdAt:
            FieldValue.serverTimestamp(),
        },
      );

      const previousSubscriptionState =
        String(
          userData.plusSubscriptionState ?? "",
        ).trim();

      if (
        previousSubscriptionState !==
          status.subscriptionState
      ) {
        writeUserNotificationInTransaction(
          firestore,
          transaction,
          {
            userId: registry.uid,
            type:
              status.hasEntitlement ?
                "plus_status_updated" :
                "plus_expired",
            title:
              status.hasEntitlement ?
                "Plus aboneliğin güncellendi" :
                "Plus aboneliğin sona erdi",
            message:
              status.hasEntitlement ?
                "Google Play abonelik durumun hesabına güncellendi." :
                "Google Play doğrulamasına göre Plus erişimin sona erdi.",
            route: "profile",
            data: {
              productId:
                registry.productId,
              subscriptionState:
                status.subscriptionState,
              hasEntitlement:
                status.hasEntitlement,
              expiryAt:
                status.expiryTime
                  ?.toISOString() ?? null,
            },
          },
        );
      }

      writeAuditLogInTransaction(
        firestore,
        transaction,
        {
          action:
            "google_play_plus_lifecycle",
          performedBy:
            "system:google_play",
          targetUid:
            registry.uid,
          metadata: {
            eventId,
            productId:
              registry.productId,
            googlePlayProductId:
              registry.googlePlayProductId,
            notificationType:
              notification.notificationType ?? null,
            previousSubscriptionState,
            subscriptionState:
              status.subscriptionState,
            hasEntitlement:
              status.hasEntitlement,
            expiryAt:
              status.expiryTime
                ?.toISOString() ?? null,
          },
        },
      );

      if (registry.latestOperationId) {
        appendCommercialEvent(
          firestore,
          transaction,
          registry.latestOperationId,
          {
            state: "paid",
            actorUid:
              "system:google_play",
            actorSource:
              "processGooglePlayRtdn",
            metadata: {
              lifecycleEventId: eventId,
              notificationType:
                notification.notificationType ?? null,
              subscriptionState:
                status.subscriptionState,
              hasEntitlement:
                status.hasEntitlement,
              expiryAt:
                status.expiryTime
                  ?.toISOString() ?? null,
            },
          },
        );
      }
    },
  );
}

/**
 * Handles refund/revoke notifications.
 *
 * One-time Badge full refunds revoke the Google Play entitlement.
 * Subscription voids are synchronized from subscriptionsv2 so voluntary
 * cancellation/refund timing cannot remove access too early.
 *
 * @param {string} eventId RTDN event id.
 * @param {object} notification Voided purchase notification.
 * @return {Promise<void>} Completion promise.
 */
async function handleVoidedPurchase(
  eventId: string,
  notification: {
    purchaseToken?: string;
    orderId?: string;
    productType?: number;
    refundType?: number;
  },
): Promise<void> {
  const purchaseToken =
    requireProviderString(
      notification.purchaseToken,
      "purchaseToken",
    );
  const tokenHash =
    hashPurchaseToken(purchaseToken);

  const registrySnapshot = await firestore
    .collection("google_play_purchase_tokens")
    .doc(tokenHash)
    .get();

  if (!registrySnapshot.exists) {
    await writeUnmatchedRtdn(
      eventId,
      tokenHash,
      "voided_purchase",
      notification.refundType,
    );
    return;
  }

  const registry =
    normalizeTokenRegistry(
      registrySnapshot.data() ?? {},
    );

  if (registry.kind === "plus_subscription") {
    await handleSubscriptionNotification(
      eventId,
      {
        notificationType: 0,
        purchaseToken,
      },
    );

    await enqueueCommercialReconciliation(
      eventId,
      registry,
      notification.orderId,
      "subscription_void",
      notification.refundType,
    );
    return;
  }

  if (registry.kind === "plus_gift") {
    await revokePlusGift(
      eventId,
      tokenHash,
      registry,
      notification,
    );
    return;
  }

  if (registry.kind === "badge_gift") {
    await revokeBadgeGift(
      eventId,
      tokenHash,
      registry,
      notification,
    );
    return;
  }

  const fullRefund =
    notification.refundType === 1;
  const entitlementUid =
    String(
      registrySnapshot.data()?.recipientUid ?? "",
    ).trim() || registry.uid;

  await firestore.runTransaction(
    async (transaction) => {
      const ownedBadgeReference = firestore
        .collection("users")
        .doc(entitlementUid)
        .collection("owned_badges")
        .doc(registry.productId);
      const tokenReference = firestore
        .collection("google_play_purchase_tokens")
        .doc(tokenHash);
      const lifecycleReference = firestore
        .collection("google_play_lifecycle_events")
        .doc(eventId);

      const lifecycleSnapshot =
        await transaction.get(lifecycleReference);
      if (lifecycleSnapshot.exists) {
        return;
      }

      const badgeSnapshot =
        await transaction.get(
          ownedBadgeReference,
        );

      const badgeTokenHash =
        String(
          badgeSnapshot.data()
            ?.googlePlayPurchaseTokenHash ?? "",
        ).trim();

      let entitlementRevoked = false;
      let removedOwnedBadge = false;

      if (
        fullRefund &&
        badgeSnapshot.exists &&
        badgeTokenHash === tokenHash
      ) {
        const source =
          String(
            badgeSnapshot.data()?.source ?? "",
          ).trim();
        const grantedByThisPlayPurchase =
          source === "google_play_purchase" ||
          source === "google_play_gift";

        const hasIndependentAdminState =
          badgeSnapshot.data()?.adminGranted === true ||
          badgeSnapshot.data()?.adminBlocked === true;

        if (grantedByThisPlayPurchase && !hasIndependentAdminState) {
          transaction.delete(
            ownedBadgeReference,
          );
          removedOwnedBadge = true;
        } else {
          transaction.set(
            ownedBadgeReference,
            {
              googlePlayEntitled: false,
              googlePlayProductId:
                FieldValue.delete(),
              googlePlayOperationId:
                FieldValue.delete(),
              googlePlayPurchaseTokenHash:
                FieldValue.delete(),
              updatedAt:
                FieldValue.serverTimestamp(),
            },
            {
              merge: true,
            },
          );
        }

        entitlementRevoked = true;
      }

      let refundMessage =
        "Google Play kısmi iade bildirdi. Rozet durumun güncellendi.";

      if (fullRefund && removedOwnedBadge) {
        refundMessage =
          "Google Play tam iade bildirdi. Rozet erişimin kaldırıldı.";
      } else if (fullRefund && entitlementRevoked) {
        refundMessage =
          "Google Play tam iadesi işlendi. " +
          "Rozet başka bir hak nedeniyle hesabında duruyor.";
      } else if (fullRefund) {
        refundMessage =
          "Google Play tam iade bildirdi.";
      }

      transaction.set(
        tokenReference,
        {
          active:
            fullRefund ? false : true,
          latestVoidedOrderId:
            normalizeOptionalString(
              notification.orderId,
            ),
          latestRefundType:
            notification.refundType ?? null,
          updatedAt:
            FieldValue.serverTimestamp(),
        },
        {
          merge: true,
        },
      );

      transaction.create(
        lifecycleReference,
        {
          eventId,
          provider: "google_play",
          kind: "badge_non_consumable",
          uid: registry.uid,
          productId:
            registry.productId,
          googlePlayProductId:
            registry.googlePlayProductId,
          purchaseTokenHash:
            tokenHash,
          orderId:
            normalizeOptionalString(
              notification.orderId,
            ),
          refundType:
            notification.refundType ?? null,
          entitlementRevoked,
          recipientUid:
            entitlementUid,
          createdAt:
            FieldValue.serverTimestamp(),
        },
      );

      if (registry.latestOperationId) {
        transitionCommercialOperation(
          firestore,
          transaction,
          registry.latestOperationId,
          fullRefund ?
            "refunded" :
            "partially_refunded",
          {
            actorUid:
              "system:google_play",
            source:
              "processGooglePlayRtdn",
          },
          {
            lifecycleEventId: eventId,
            orderId:
              normalizeOptionalString(
                notification.orderId,
              ),
            refundType:
              notification.refundType ?? null,
          },
        );
      }

      writeUserNotificationInTransaction(
        firestore,
        transaction,
        {
          userId: entitlementUid,
          type:
            fullRefund ?
              "badge_refunded" :
              "badge_refund_updated",
          title:
            fullRefund ?
              "Rozet iadesi tamamlandı" :
              "Rozet iadesi güncellendi",
          message: refundMessage,
          route: "profile",
          data: {
            productId:
              registry.productId,
            fullRefund,
            refundType:
              notification.refundType ?? null,
          },
        },
      );

      writeAuditLogInTransaction(
        firestore,
        transaction,
        {
          action:
            fullRefund ?
              "google_play_badge_refunded" :
              "google_play_badge_partial_refund",
          performedBy:
            "system:google_play",
          targetUid:
            registry.uid,
          metadata: {
            eventId,
            productId:
              registry.productId,
            googlePlayProductId:
              registry.googlePlayProductId,
            purchaseTokenHash:
              tokenHash,
            orderId:
              normalizeOptionalString(
                notification.orderId,
              ),
            refundType:
              notification.refundType ?? null,
            recipientUid:
              entitlementUid,
            entitlementRevoked,
          },
        },
      );
    },
  );
}

/**
 * Records one-time product notifications.
 *
 * @param {string} eventId RTDN event id.
 * @param {object} notification One-time product notification.
 * @return {Promise<void>} Completion promise.
 */
async function handleOneTimeProductNotification(
  eventId: string,
  notification: {
    notificationType?: number;
    purchaseToken?: string;
    sku?: string;
  },
): Promise<void> {
  const purchaseToken =
    requireProviderString(
      notification.purchaseToken,
      "purchaseToken",
    );
  const tokenHash =
    hashPurchaseToken(purchaseToken);

  await firestore
    .collection("google_play_lifecycle_events")
    .doc(eventId)
    .set(
      {
        eventId,
        provider: "google_play",
        kind: "one_time_product",
        purchaseTokenHash:
          tokenHash,
        googlePlayProductId:
          normalizeOptionalString(
            notification.sku,
          ),
        notificationType:
          notification.notificationType ?? null,
        createdAt:
          FieldValue.serverTimestamp(),
      },
      {
        merge: false,
      },
    );
}

/**
 * Queues a 2026 Google Play pending chargeback review without exposing the
 * raw pendingRefundToken to any client collection.
 *
 * @param {string} eventId RTDN event id.
 * @param {object} notification Pending refund review notification.
 * @return {Promise<void>} Completion promise.
 */
async function handlePendingRefundReview(
  eventId: string,
  notification: {
    pendingRefundToken?: string;
    orderId?: string;
    refundReason?: number;
    obfuscatedAccountId?: string;
    obfuscatedProfileId?: string;
  },
): Promise<void> {
  const pendingRefundToken =
    requireProviderString(
      notification.pendingRefundToken,
      "pendingRefundToken",
    );
  const orderId =
    requireProviderString(
      notification.orderId,
      "orderId",
    );
  const reviewId =
    sha256(
      `google_play_refund_review:${orderId}`,
    );

  const batch = firestore.batch();

  batch.set(
    firestore
      .collection("commercial_review_queue")
      .doc(reviewId),
    {
      reviewId,
      provider: "google_play",
      type:
        "pending_chargeback_review",
      status: "pending",
      providerOrderId: orderId,
      refundReason:
        notification.refundReason ?? null,
      eventId,
      createdAt:
        FieldValue.serverTimestamp(),
      updatedAt:
        FieldValue.serverTimestamp(),
    },
    {
      merge: true,
    },
  );

  batch.set(
    firestore
      .collection(
        "google_play_refund_review_secrets",
      )
      .doc(reviewId),
    {
      reviewId,
      pendingRefundToken,
      pendingRefundTokenHash:
        sha256(pendingRefundToken),
      providerOrderId: orderId,
      obfuscatedAccountId:
        normalizeOptionalString(
          notification.obfuscatedAccountId,
        ),
      obfuscatedProfileId:
        normalizeOptionalString(
          notification.obfuscatedProfileId,
        ),
      eventId,
      createdAt:
        FieldValue.serverTimestamp(),
      updatedAt:
        FieldValue.serverTimestamp(),
    },
    {
      merge: true,
    },
  );

  await batch.commit();
}

/**
 * Creates finance reconciliation work without guessing provider money.
 *
 * @param {string} eventId RTDN event id.
 * @param {TokenRegistry} registry Token registry.
 * @param {unknown} orderId Google order id.
 * @param {string} reason Queue reason.
 * @param {unknown} refundType Refund type.
 * @return {Promise<void>} Completion promise.
 */
async function enqueueCommercialReconciliation(
  eventId: string,
  registry: TokenRegistry,
  orderId: unknown,
  reason: string,
  refundType: unknown,
): Promise<void> {
  const normalizedOrderId =
    normalizeOptionalString(orderId);
  const queueId = sha256(
    [
      "google_play_reconciliation",
      eventId,
      normalizedOrderId ?? "",
    ].join(":"),
  );

  await firestore
    .collection(
      "commercial_reconciliation_queue",
    )
    .doc(queueId)
    .set(
      {
        queueId,
        provider: "google_play",
        reason,
        status: "pending",
        eventId,
        uid: registry.uid,
        productId:
          registry.productId,
        googlePlayProductId:
          registry.googlePlayProductId,
        providerOrderId:
          normalizedOrderId,
        refundType:
          typeof refundType === "number" ?
            refundType :
            null,
        createdAt:
          FieldValue.serverTimestamp(),
        updatedAt:
          FieldValue.serverTimestamp(),
      },
      {
        merge: true,
      },
    );
}

/**
 * Stores an unmatched provider event for later release reconciliation.
 *
 * @param {string} eventId RTDN event id.
 * @param {string} tokenHash Purchase token hash.
 * @param {string} kind Notification kind.
 * @param {unknown} notificationType Provider notification type.
 * @return {Promise<void>} Completion promise.
 */
async function writeUnmatchedRtdn(
  eventId: string,
  tokenHash: string,
  kind: string,
  notificationType: unknown,
): Promise<void> {
  await firestore
    .collection(
      "google_play_unmatched_notifications",
    )
    .doc(eventId)
    .set(
      {
        eventId,
        purchaseTokenHash:
          tokenHash,
        kind,
        notificationType:
          typeof notificationType === "number" ?
            notificationType :
            null,
        status: "unmatched",
        createdAt:
          FieldValue.serverTimestamp(),
        updatedAt:
          FieldValue.serverTimestamp(),
      },
      {
        merge: true,
      },
    );
}

/**
 * Marks one RTDN event as completed.
 *
 * @param {FirebaseFirestore.DocumentReference} reference Event reference.
 * @param {string} kind Processed kind.
 * @return {Promise<void>} Completion promise.
 */
async function completeRtdnEvent(
  reference:
    FirebaseFirestore.DocumentReference,
  kind: string,
): Promise<void> {
  await reference.set(
    {
      status: "completed",
      kind,
      completedAt:
        FieldValue.serverTimestamp(),
      updatedAt:
        FieldValue.serverTimestamp(),
    },
    {
      merge: true,
    },
  );
}

/**
 * Revokes only the Plus time that came from one gift purchase.
 * @param {string} eventId RTDN event id.
 * @param {string} tokenHash Token hash.
 * @param {TokenRegistry} registry Token registry.
 * @param {object} notification Voided purchase notification.
 * @return {Promise<void>} Completion promise.
 */
async function revokePlusGift(
  eventId: string,
  tokenHash: string,
  registry: TokenRegistry,
  notification: {orderId?: string; refundType?: number},
): Promise<void> {
  const tokenReference = firestore
    .collection("google_play_purchase_tokens")
    .doc(tokenHash);
  const tokenSnapshot = await tokenReference.get();
  const tokenData = tokenSnapshot.data() ?? {};
  const recipientUid = String(
    tokenData.recipientUid ?? registry.uid,
  ).trim();
  const grantId = String(tokenData.giftGrantId ?? "").trim();
  const fullRefund = notification.refundType === 1;

  await firestore.runTransaction(async (transaction) => {
    const userReference = firestore.collection("users").doc(recipientUid);
    const userSnapshot = await transaction.get(userReference);
    const userData = userSnapshot.data() ?? {};
    const rawGrants = Array.isArray(userData.plusGiftGrants) ?
      userData.plusGiftGrants as Array<Record<string, unknown>> :
      [];
    const grants = rawGrants.map((grant) => ({
      id: String(grant.id ?? ""),
      durationMs: Number(grant.durationMs ?? 0),
      revoked: grant.revoked === true,
    }));
    const originValue = userData.plusGiftOriginAt;
    const originMs = originValue instanceof Timestamp ?
      originValue.toMillis() :
      Date.now();
    const giftExpiresAtMs = fullRefund ?
      revokeGiftDuration({
        grants,
        revokeId: grantId,
        originMs,
        nowMs: Date.now(),
      }) :
      (
        userData.plusGiftExpiresAt instanceof Timestamp ?
          userData.plusGiftExpiresAt.toMillis() :
          null
      );
    const subscriptionValue = userData.plusSubscriptionExpiresAt;
    const access = evaluatePlusAccess({
      plusFlag: true,
      subscriptionExpiresAtMs:
        subscriptionValue instanceof Timestamp ?
          subscriptionValue.toMillis() :
          null,
      giftExpiresAtMs,
      subscriptionState: String(userData.plusSubscriptionState ?? ""),
      nowMs: Date.now(),
    });
    const nextGrants = rawGrants.map((grant) => (
      String(grant.id ?? "") === grantId && fullRefund ?
        {...grant, revoked: true} :
        grant
    ));

    transaction.set(userReference, {
      plus: access.active,
      isPlus: access.active,
      plusGiftExpiresAt: giftExpiresAtMs == null ?
        null :
        Timestamp.fromMillis(giftExpiresAtMs),
      plusExpiresAt: access.expiresAtMs == null ?
        null :
        Timestamp.fromMillis(access.expiresAtMs),
      plusGiftGrants: nextGrants,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    transaction.set(tokenReference, {
      active: fullRefund ? false : true,
      latestRefundType: notification.refundType ?? null,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    transaction.create(
      firestore.collection("google_play_lifecycle_events").doc(eventId),
      {
        eventId,
        provider: "google_play",
        kind: "plus_gift",
        uid: registry.uid,
        recipientUid,
        productId: registry.productId,
        fullRefund,
        createdAt: FieldValue.serverTimestamp(),
      },
    );
  });
}

/**
 * Revokes one gifted badge without removing another grant.
 * @param {string} eventId RTDN event id.
 * @param {string} tokenHash Token hash.
 * @param {TokenRegistry} registry Token registry.
 * @param {object} notification Voided purchase notification.
 * @return {Promise<void>} Completion promise.
 */
async function revokeBadgeGift(
  eventId: string,
  tokenHash: string,
  registry: TokenRegistry,
  notification: {orderId?: string; refundType?: number},
): Promise<void> {
  const tokenReference = firestore
    .collection("google_play_purchase_tokens")
    .doc(tokenHash);
  const tokenSnapshot = await tokenReference.get();
  const recipientUid = String(
    tokenSnapshot.data()?.recipientUid ?? registry.uid,
  ).trim();
  const fullRefund = notification.refundType === 1;

  await firestore.runTransaction(async (transaction) => {
    const badgeReference = firestore
      .collection("users")
      .doc(recipientUid)
      .collection("owned_badges")
      .doc(registry.productId);
    const badgeSnapshot = await transaction.get(badgeReference);
    const badge = badgeSnapshot.data() ?? {};
    const giftTokenHashes = Array.isArray(badge.giftTokenHashes) ?
      badge.giftTokenHashes.map((value: unknown) => String(value)) :
      [];
    const decision = revokeBadgeGrant({
      personalTokenHash: String(badge.personalTokenHash ?? ""),
      giftTokenHashes,
    }, tokenHash, fullRefund);

    if (!badgeSnapshot.exists) {
      transaction.set(tokenReference, {
        active: fullRefund ? false : true,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return;
    }

    if (badgeRemains(decision.state)) {
      transaction.set(badgeReference, {
        personalTokenHash: decision.state.personalTokenHash,
        giftTokenHashes: decision.state.giftTokenHashes,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    } else if (decision.revokeGift || decision.revokePersonal) {
      if (badge.adminGranted === true || badge.adminBlocked === true) {
        transaction.set(badgeReference, {
          personalTokenHash: decision.state.personalTokenHash,
          giftTokenHashes: decision.state.giftTokenHashes,
          googlePlayEntitled: false,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      } else {
        transaction.delete(badgeReference);
      }
    }

    transaction.set(tokenReference, {
      active: fullRefund ? false : true,
      latestRefundType: notification.refundType ?? null,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    transaction.create(
      firestore.collection("google_play_lifecycle_events").doc(eventId),
      {
        eventId,
        provider: "google_play",
        kind: "badge_gift",
        uid: registry.uid,
        recipientUid,
        productId: registry.productId,
        removed: !badgeRemains(decision.state),
        createdAt: FieldValue.serverTimestamp(),
      },
    );
  });
}

/**
 * Normalizes server-only token registry data.
 *
 * @param {Record<string, unknown>} data Registry data.
 * @return {TokenRegistry} Normalized registry.
 */
function normalizeTokenRegistry(
  data: Record<string, unknown>,
): TokenRegistry {
  const uid =
    requireProviderString(
      data.uid,
      "registry.uid",
    );
  const productId =
    requireProviderString(
      data.productId,
      "registry.productId",
    );
  const googlePlayProductId =
    requireProviderString(
      data.googlePlayProductId,
      "registry.googlePlayProductId",
    );
  const kindValue =
    requireProviderString(
      data.kind,
      "registry.kind",
    );

  if (
    kindValue !== "plus_subscription" &&
    kindValue !== "badge_non_consumable" &&
    kindValue !== "badge_gift" &&
    kindValue !== "plus_gift"
  ) {
    throw new Error(
      "Google Play token registry has invalid kind.",
    );
  }

  return {
    uid,
    productId,
    googlePlayProductId,
    kind: kindValue,
    latestOperationId:
      String(
        data.latestOperationId ?? "",
      ).trim(),
  };
}

/**
 * Reads provider string.
 *
 * @param {unknown} value Raw value.
 * @param {string} field Field name.
 * @return {string} Non-empty string.
 */
function requireProviderString(
  value: unknown,
  field: string,
): string {
  const normalized =
    String(value ?? "").trim();

  if (!normalized) {
    throw new Error(
      `Google Play ${field} is missing.`,
    );
  }

  return normalized;
}

/**
 * Normalizes optional string.
 *
 * @param {unknown} value Raw value.
 * @return {string|null} Normalized value.
 */
function normalizeOptionalString(
  value: unknown,
): string | null {
  const normalized =
    String(value ?? "").trim();

  return normalized ?
    normalized :
    null;
}

/**
 * SHA-256 helper.
 *
 * @param {string} value Raw value.
 * @return {string} Hash.
 */
function sha256(
  value: string,
): string {
  return createHash("sha256")
    .update(value, "utf8")
    .digest("hex");
}
