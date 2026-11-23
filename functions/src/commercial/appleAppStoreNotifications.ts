/* eslint-disable max-len */
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {defineString} from "firebase-functions/params";
import {HttpsError, onRequest} from "firebase-functions/v2/https";

import {writeAuditLogInTransaction} from "../audit/writeAuditLog";
import {firestore} from "../config/firebaseAdmin";
import {
  writeUserNotificationInTransaction,
} from "../notifications/writeUserNotification";
import {
  DEFAULT_APPLE_BUNDLE_ID,
  resolveAppleSubscriptionState,
  VerifiedAppleNotification,
  verifyAppleServerNotification,
} from "./appleAppStoreVerification";
import {
  appendCommercialEvent,
  transitionCommercialOperation,
} from "./commercialLedger";
import {evaluatePlusAccess} from "./plusEntitlementPolicy";

const appleBundleId = defineString("APPLE_BUNDLE_ID", {
  default: DEFAULT_APPLE_BUNDLE_ID,
});

interface AppleRegistryRecord {
  uid: string;
  productId: string;
  appleProductId: string;
  kind: "plus_subscription" | "badge_non_consumable";
  latestOperationId: string;
}

/**
 * Handles App Store Server Notifications V2 webhooks for iOS subscriptions
 * and non-consumable badge refunds/revocations.
 */
export const processAppleAppStoreNotification = onRequest(
  {
    region: "europe-west1",
    maxInstances: 10,
  },
  async (request, response) => {
    if (request.method !== "POST") {
      response.status(405).json({error: "method_not_allowed"});
      return;
    }

    const body = request.body as Record<string, unknown> | undefined;
    const signedPayload = typeof body?.signedPayload === "string" ?
      body.signedPayload.trim() :
      "";
    if (!signedPayload) {
      response.status(400).json({error: "missing_signed_payload"});
      return;
    }

    let notification: VerifiedAppleNotification;
    try {
      notification = verifyAppleServerNotification(signedPayload, {
        expectedBundleId: appleBundleId.value(),
      });
    } catch (error) {
      logger.warn("Rejected invalid Apple server notification", {
        code: error instanceof HttpsError ? error.code : "unknown",
      });
      response.status(400).json({error: "invalid_signed_payload"});
      return;
    }

    const eventRef = firestore
      .collection("apple_notification_events")
      .doc(notification.notificationUUID);
    const existingEvent = await eventRef.get();
    if (existingEvent.data()?.status === "completed") {
      response.status(200).json({ok: true, duplicate: true});
      return;
    }

    await eventRef.set(
      {
        notificationUUID: notification.notificationUUID,
        notificationType: notification.notificationType,
        subtype: notification.subtype,
        environment: notification.environment,
        bundleId: notification.bundleId,
        version: notification.version,
        status: "processing",
        receivedAt: existingEvent.exists ?
          existingEvent.data()?.receivedAt ?? FieldValue.serverTimestamp() :
          FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    if (notification.notificationType === "TEST") {
      await eventRef.set(
        {
          status: "completed",
          handledAs: "test",
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
      response.status(200).json({ok: true, test: true});
      return;
    }

    const tx = notification.transaction;
    if (!tx) {
      await eventRef.set(
        {
          status: "completed",
          handledAs: "no_transaction",
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
      response.status(200).json({ok: true});
      return;
    }

    const registrySnapshot = await firestore
      .collection("apple_purchase_transactions")
      .doc(tx.originalTransactionId)
      .get();

    if (!registrySnapshot.exists) {
      await eventRef.set(
        {
          status: "completed",
          handledAs: "unmatched_transaction",
          originalTransactionId: tx.originalTransactionId,
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
      response.status(200).json({ok: true, unmatched: true});
      return;
    }

    const registry = normalizeRegistry(registrySnapshot.data() ?? {});

    if (registry.kind === "plus_subscription") {
      await syncAppleSubscriptionLifecycle(notification, registry);
    } else if (
      notification.notificationType === "REFUND" ||
      notification.notificationType === "REVOKE" ||
      notification.notificationType === "REFUND_REVERSED"
    ) {
      await syncAppleBadgeRefundLifecycle(notification, registry);
    }

    await eventRef.set(
      {
        status: "completed",
        handledAs: registry.kind,
        originalTransactionId: tx.originalTransactionId,
        uid: registry.uid,
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    response.status(200).json({ok: true});
  },
);

/**
 * Synchronizes canonical Plus entitlement fields from a verified Apple
 * subscription notification.
 * @param {VerifiedAppleNotification} notification Verified notification.
 * @param {AppleRegistryRecord} registry Transaction owner record.
 * @return {Promise<void>} Completion promise.
 */
async function syncAppleSubscriptionLifecycle(
  notification: VerifiedAppleNotification,
  registry: AppleRegistryRecord,
): Promise<void> {
  const tx = notification.transaction!;
  const resolved = resolveAppleSubscriptionState({
    notificationType: notification.notificationType,
    subtype: notification.subtype,
    transaction: tx,
    renewalInfo: notification.renewalInfo,
  });

  await firestore.runTransaction(async (transaction) => {
    const userRef = firestore.collection("users").doc(registry.uid);
    const registryRef = firestore
      .collection("apple_purchase_transactions")
      .doc(tx.originalTransactionId);
    const lifecycleRef = firestore
      .collection("apple_lifecycle_events")
      .doc(notification.notificationUUID);

    const lifecycleSnapshot = await transaction.get(lifecycleRef);
    if (lifecycleSnapshot.exists) {
      return;
    }

    const userSnapshot = await transaction.get(userRef);
    const userData = userSnapshot.data() ?? {};
    const currentAppleTx = String(
      userData.plusAppleOriginalTransactionId ?? "",
    ).trim();

    const giftValue = userData.plusGiftExpiresAt;
    const giftExpiry = giftValue instanceof Timestamp ?
      giftValue.toDate() :
      null;
    const subscriptionExpiry =
      resolved.hasEntitlement && resolved.expiryTime != null ?
        resolved.expiryTime :
        null;
    const shouldWriteSubscription =
      subscriptionExpiry != null ||
      currentAppleTx === tx.originalTransactionId;

    if (shouldWriteSubscription) {
      const access = evaluatePlusAccess({
        plusFlag: true,
        subscriptionExpiresAtMs: subscriptionExpiry?.getTime() ?? null,
        giftExpiresAtMs: giftExpiry?.getTime() ?? null,
        subscriptionState: resolved.subscriptionState,
        nowMs: Date.now(),
      });

      transaction.set(
        userRef,
        {
          plus: access.active,
          isPlus: access.active,
          plusProvider: "apple_app_store",
          plusAppleOriginalTransactionId: tx.originalTransactionId,
          plusAppleProductId: registry.appleProductId,
          plusSubscriptionState: resolved.subscriptionState,
          plusSubscriptionExpiresAt: subscriptionExpiry == null ?
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
      registryRef,
      {
        active: resolved.hasEntitlement,
        latestTransactionId: tx.transactionId,
        latestExpiryAt: resolved.expiryTime == null ?
          null :
          Timestamp.fromDate(resolved.expiryTime),
        latestSubscriptionState: resolved.subscriptionState,
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    transaction.create(lifecycleRef, {
      eventId: notification.notificationUUID,
      provider: "apple_app_store",
      kind: "plus_subscription",
      uid: registry.uid,
      productId: registry.productId,
      appleProductId: registry.appleProductId,
      originalTransactionId: tx.originalTransactionId,
      transactionId: tx.transactionId,
      notificationType: notification.notificationType,
      subtype: notification.subtype,
      subscriptionState: resolved.subscriptionState,
      hasEntitlement: resolved.hasEntitlement,
      expiryAt: resolved.expiryTime == null ?
        null :
        Timestamp.fromDate(resolved.expiryTime),
      createdAt: FieldValue.serverTimestamp(),
    });

    const previousState = String(userData.plusSubscriptionState ?? "").trim();
    if (previousState !== resolved.subscriptionState) {
      writeUserNotificationInTransaction(firestore, transaction, {
        userId: registry.uid,
        type: resolved.hasEntitlement ?
          "plus_status_updated" :
          "plus_expired",
        title: resolved.hasEntitlement ?
          "Plus aboneliğin güncellendi" :
          "Plus aboneliğin sona erdi",
        message: resolved.hasEntitlement ?
          "App Store abonelik durumun hesabında güncellendi." :
          "App Store doğrulamasına göre Plus erişimin sona erdi.",
        route: "profile",
        data: {
          productId: registry.productId,
          subscriptionState: resolved.subscriptionState,
          hasEntitlement: resolved.hasEntitlement,
          expiryAt: resolved.expiryTime?.toISOString() ?? null,
        },
      });
    }

    writeAuditLogInTransaction(firestore, transaction, {
      action: "apple_plus_lifecycle",
      performedBy: "system:apple_app_store",
      targetUid: registry.uid,
      metadata: {
        notificationUUID: notification.notificationUUID,
        notificationType: notification.notificationType,
        subtype: notification.subtype,
        productId: registry.productId,
        appleProductId: registry.appleProductId,
        originalTransactionId: tx.originalTransactionId,
        previousSubscriptionState: previousState,
        subscriptionState: resolved.subscriptionState,
        hasEntitlement: resolved.hasEntitlement,
        expiryAt: resolved.expiryTime?.toISOString() ?? null,
      },
    });

    if (registry.latestOperationId) {
      appendCommercialEvent(firestore, transaction, registry.latestOperationId, {
        state:
          resolved.subscriptionState === "SUBSCRIPTION_STATE_REVOKED" ?
            "refunded" :
            "paid",
        actorUid: "system:apple_app_store",
        actorSource: "processAppleAppStoreNotification",
        metadata: {
          lifecycleEventId: notification.notificationUUID,
          notificationType: notification.notificationType,
          subtype: notification.subtype,
          subscriptionState: resolved.subscriptionState,
          hasEntitlement: resolved.hasEntitlement,
        },
      });
    }
  });
}

/**
 * Handles REFUND, REVOKE, and REFUND_REVERSED for non-consumable badges.
 * Preserves independent Google Play and admin grants.
 * @param {VerifiedAppleNotification} notification Verified notification.
 * @param {AppleRegistryRecord} registry Transaction owner record.
 * @return {Promise<void>} Completion promise.
 */
async function syncAppleBadgeRefundLifecycle(
  notification: VerifiedAppleNotification,
  registry: AppleRegistryRecord,
): Promise<void> {
  const tx = notification.transaction!;
  const isReversal = notification.notificationType === "REFUND_REVERSED";

  await firestore.runTransaction(async (transaction) => {
    const ownedBadgeRef = firestore
      .collection("users")
      .doc(registry.uid)
      .collection("owned_badges")
      .doc(registry.productId);
    const registryRef = firestore
      .collection("apple_purchase_transactions")
      .doc(tx.originalTransactionId);
    const lifecycleRef = firestore
      .collection("apple_lifecycle_events")
      .doc(notification.notificationUUID);

    const lifecycleSnapshot = await transaction.get(lifecycleRef);
    if (lifecycleSnapshot.exists) {
      return;
    }

    const badgeSnapshot = await transaction.get(ownedBadgeRef);
    const badgeData = badgeSnapshot.data() ?? {};

    let entitlementRevoked = false;
    let removedOwnedBadge = false;

    if (isReversal) {
      if (badgeSnapshot.exists) {
        transaction.set(
          ownedBadgeRef,
          {
            appleEntitled: true,
            appleOriginalTransactionId: tx.originalTransactionId,
            appleTransactionId: tx.transactionId,
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
      }
    } else if (
      badgeSnapshot.exists &&
      String(badgeData.appleOriginalTransactionId ?? "").trim() ===
        tx.originalTransactionId
    ) {
      const source = String(badgeData.source ?? "").trim();
      const hasIndependentEntitlement =
        badgeData.adminGranted === true ||
        badgeData.adminBlocked === true ||
        badgeData.googlePlayEntitled === true;

      if (
        source === "apple_app_store_purchase" &&
        !hasIndependentEntitlement
      ) {
        transaction.delete(ownedBadgeRef);
        removedOwnedBadge = true;
      } else {
        transaction.set(
          ownedBadgeRef,
          {
            appleEntitled: false,
            appleProductId: FieldValue.delete(),
            appleOriginalTransactionId: FieldValue.delete(),
            appleTransactionId: FieldValue.delete(),
            appleOperationId: FieldValue.delete(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
      }
      entitlementRevoked = true;
    }

    transaction.set(
      registryRef,
      {
        active: isReversal,
        latestTransactionId: tx.transactionId,
        latestNotificationType: notification.notificationType,
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    transaction.create(lifecycleRef, {
      eventId: notification.notificationUUID,
      provider: "apple_app_store",
      kind: "badge_non_consumable",
      uid: registry.uid,
      productId: registry.productId,
      appleProductId: registry.appleProductId,
      originalTransactionId: tx.originalTransactionId,
      notificationType: notification.notificationType,
      entitlementRevoked,
      removedOwnedBadge,
      createdAt: FieldValue.serverTimestamp(),
    });

    if (registry.latestOperationId && !isReversal) {
      transitionCommercialOperation(
        firestore,
        transaction,
        registry.latestOperationId,
        "refunded",
        {
          actorUid: "system:apple_app_store",
          source: "processAppleAppStoreNotification",
        },
        {
          lifecycleEventId: notification.notificationUUID,
          notificationType: notification.notificationType,
        },
      );
    }

    if (!isReversal) {
      const message = removedOwnedBadge ?
        "App Store iadesi işlendi. Rozet erişimin kaldırıldı." :
        entitlementRevoked ?
          "App Store iadesi işlendi. Rozet başka bir hak nedeniyle hesabında duruyor." :
          "App Store iade bildirimi işlendi.";

      writeUserNotificationInTransaction(firestore, transaction, {
        userId: registry.uid,
        type: "badge_refunded",
        title: "Rozet iadesi tamamlandı",
        message,
        route: "profile",
        data: {
          productId: registry.productId,
          entitlementRevoked,
        },
      });
    }

    writeAuditLogInTransaction(firestore, transaction, {
      action: isReversal ?
        "apple_badge_refund_reversed" :
        "apple_badge_refunded",
      performedBy: "system:apple_app_store",
      targetUid: registry.uid,
      metadata: {
        notificationUUID: notification.notificationUUID,
        productId: registry.productId,
        appleProductId: registry.appleProductId,
        originalTransactionId: tx.originalTransactionId,
        entitlementRevoked,
        removedOwnedBadge,
      },
    });
  });
}

/**
 * Normalizes a stored Apple purchase transaction registry document.
 * @param {Record<string, unknown>} data Raw Firestore data.
 * @return {AppleRegistryRecord} Validated registry record.
 */
function normalizeRegistry(
  data: Record<string, unknown>,
): AppleRegistryRecord {
  const uid = String(data.uid ?? "").trim();
  const productId = String(data.productId ?? "").trim();
  const appleProductId = String(data.appleProductId ?? "").trim();
  const rawKind = String(data.kind ?? "").trim();
  const kind = rawKind === "plus_subscription" ?
    "plus_subscription" :
    "badge_non_consumable";

  if (!uid || !productId || !appleProductId) {
    throw new Error("invalid_apple_registry_record");
  }

  return {
    uid,
    productId,
    appleProductId,
    kind,
    latestOperationId: String(data.latestOperationId ?? "").trim(),
  };
}
