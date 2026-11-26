import 'package:in_app_purchase/in_app_purchase.dart';

enum PurchaseFlowPhase {
  idle,
  awaitingStore,
  pendingPayment,
  verifying,
  statusUnknown,
}

const String purchaseStatusUnknownMessage =
    'Satın alma durumu kontrol edilemedi';
const String purchaseStatusRecheckLabel = 'Tekrar kontrol et';

enum QueriedPurchaseState { pending, purchased }

enum PurchaseReconcileAction {
  keepWaiting,
  waitForPayment,
  verifyExisting,
  cancelAsAbandoned,
  statusUnknown,
}

enum OpenPurchaseFollowUp { recheckExisting, startPayment, blocked }

class PurchaseStatusCheckGate {
  bool _inFlight = false;
  int _queryCount = 0;

  bool get inFlight => _inFlight;

  int get queryCount => _queryCount;

  bool tryBegin() {
    if (_inFlight) {
      return false;
    }
    _inFlight = true;
    _queryCount++;
    return true;
  }

  void end() {
    _inFlight = false;
  }
}

PurchaseReconcileAction reconcilePurchaseQuery({
  required bool returnedFromBillingUi,
  required bool verificationInFlight,
  required bool querySucceeded,
  required List<QueriedPurchaseState> matches,
}) {
  if (!returnedFromBillingUi || verificationInFlight) {
    return PurchaseReconcileAction.keepWaiting;
  }
  if (!querySucceeded) {
    return PurchaseReconcileAction.statusUnknown;
  }
  if (matches.contains(QueriedPurchaseState.pending)) {
    return PurchaseReconcileAction.waitForPayment;
  }
  if (matches.contains(QueriedPurchaseState.purchased)) {
    return PurchaseReconcileAction.verifyExisting;
  }
  return PurchaseReconcileAction.cancelAsAbandoned;
}

OpenPurchaseFollowUp openPurchaseFollowUp({
  required PurchaseFlowPhase phase,
  required bool checkInFlight,
}) {
  if (checkInFlight) {
    return OpenPurchaseFollowUp.blocked;
  }
  if (phase == PurchaseFlowPhase.statusUnknown) {
    return OpenPurchaseFollowUp.recheckExisting;
  }
  if (phase == PurchaseFlowPhase.idle) {
    return OpenPurchaseFollowUp.startPayment;
  }
  return OpenPurchaseFollowUp.blocked;
}

bool canStartPurchase({
  required bool attemptOpen,
  required PurchaseReconcileAction action,
}) {
  if (!attemptOpen) {
    return true;
  }
  return action == PurchaseReconcileAction.cancelAsAbandoned;
}

bool isEmptyProductCancel(PurchaseDetails purchase) {
  return purchase.status == PurchaseStatus.canceled &&
      purchase.productID.trim().isEmpty;
}

bool shouldVerifyPurchase(PurchaseStatus status) {
  return status == PurchaseStatus.purchased ||
      status == PurchaseStatus.restored;
}

bool isAlreadyOwnedPlayError({String? code, String? message}) {
  final String text = '${code ?? ''} ${message ?? ''}'
      .toLowerCase()
      .replaceAll('_', '')
      .replaceAll(' ', '');
  return text.contains('itemalreadyowned') || text.contains('alreadyowned');
}

/// Play has charged, but the server did not deliver. A purchase bound to
/// another account, a malformed request or a cancelled order is not a
/// delivery wait; the user cannot fix those by checking again.
bool keepsDeliveryPending(String? errorCode) {
  switch (errorCode) {
    case 'permission-denied':
    case 'invalid-argument':
    case 'unauthenticated':
    case 'cancelled':
    case 'canceled':
      return false;
    default:
      return true;
  }
}

enum DeliveryRecheckOutcome {
  delivered,
  stillPending,
  paymentPending,
  notInPlay,
  unavailable,
  busy,
}

enum MissingPurchaseRecheckAction { retryCachedPurchase, closeAsNotInPlay }

MissingPurchaseRecheckAction missingPurchaseRecheckAction({
  required bool hasCachedPurchase,
}) => hasCachedPurchase
    ? MissingPurchaseRecheckAction.retryCachedPurchase
    : MissingPurchaseRecheckAction.closeAsNotInPlay;

bool purchaseCallbackBelongsToSession({
  required int callbackGeneration,
  required int currentGeneration,
  required String callbackUid,
  required String currentUid,
}) =>
    callbackGeneration == currentGeneration &&
    callbackUid.isNotEmpty &&
    callbackUid == currentUid;

bool giftActionAvailable({
  required bool enabled,
  required String giftProductId,
  required bool purchaseBusy,
}) => enabled && giftProductId.trim().isNotEmpty && !purchaseBusy;

DeliveryRecheckOutcome classifyDeliveryRecheck({
  required bool querySucceeded,
  required int awaitingBefore,
  required int awaitingAfter,
  required int missingFromPlay,
  required int pendingPayments,
}) {
  if (!querySucceeded) {
    return DeliveryRecheckOutcome.unavailable;
  }
  if (pendingPayments > 0) {
    return DeliveryRecheckOutcome.paymentPending;
  }
  if (awaitingAfter > 0) {
    return DeliveryRecheckOutcome.stillPending;
  }
  if (awaitingBefore > 0 && missingFromPlay >= awaitingBefore) {
    return DeliveryRecheckOutcome.notInPlay;
  }
  return DeliveryRecheckOutcome.delivered;
}

enum OwnedLaunchRecovery { verifyExisting, reportFailure }

/// A refused Play sheet is not a new payment. Verify only a purchase the
/// query actually returned.
OwnedLaunchRecovery recoverUnstartedPurchase({
  required bool querySucceeded,
  required bool hasOwnedPurchase,
}) {
  if (querySucceeded && hasOwnedPurchase) {
    return OwnedLaunchRecovery.verifyExisting;
  }
  return OwnedLaunchRecovery.reportFailure;
}

enum MarketRestoreAction { restore, recheck, wait }

enum MarketRestoreReason {
  none,
  checkingPurchases,
  paymentPending,
  verifying,
  purchaseInProgress,
  statusUnknown,
}

class MarketRestoreDecision {
  const MarketRestoreDecision({required this.action, required this.reason});

  final MarketRestoreAction action;
  final MarketRestoreReason reason;
}

/// Restore stays available when no Play payment or server check is open.
/// A missing store price does not affect this decision.
MarketRestoreDecision decideMarketRestore({
  required PurchaseFlowPhase phase,
  required bool checkInFlight,
  required bool restoreInFlight,
}) {
  if (restoreInFlight || checkInFlight) {
    return const MarketRestoreDecision(
      action: MarketRestoreAction.wait,
      reason: MarketRestoreReason.checkingPurchases,
    );
  }

  switch (phase) {
    case PurchaseFlowPhase.idle:
      return const MarketRestoreDecision(
        action: MarketRestoreAction.restore,
        reason: MarketRestoreReason.none,
      );
    case PurchaseFlowPhase.statusUnknown:
      return const MarketRestoreDecision(
        action: MarketRestoreAction.recheck,
        reason: MarketRestoreReason.statusUnknown,
      );
    case PurchaseFlowPhase.pendingPayment:
      return const MarketRestoreDecision(
        action: MarketRestoreAction.wait,
        reason: MarketRestoreReason.paymentPending,
      );
    case PurchaseFlowPhase.verifying:
      return const MarketRestoreDecision(
        action: MarketRestoreAction.wait,
        reason: MarketRestoreReason.verifying,
      );
    case PurchaseFlowPhase.awaitingStore:
      return const MarketRestoreDecision(
        action: MarketRestoreAction.wait,
        reason: MarketRestoreReason.purchaseInProgress,
      );
  }
}

enum PlayPricePresentation { loading, failed, notFound, missingMapping, ready }

PlayPricePresentation playPricePresentation({
  required String productId,
  required bool hasPrice,
  required bool queryFailed,
  bool notFound = false,
}) {
  if (productId.trim().isEmpty) {
    return PlayPricePresentation.missingMapping;
  }
  if (hasPrice) {
    return PlayPricePresentation.ready;
  }
  if (queryFailed) {
    return PlayPricePresentation.failed;
  }
  if (notFound) {
    return PlayPricePresentation.notFound;
  }
  return PlayPricePresentation.loading;
}

bool canRetryPlayPriceQuery({
  required bool inFlight,
  required PlayPricePresentation presentation,
}) {
  return !inFlight && presentation == PlayPricePresentation.failed;
}

/// Returns the store product IDs that still need a price query.
///
/// IDs that already resolved, failed, or were explicitly reported as not found
/// by the store are excluded so widgets never loop `queryProductDetails` on
/// every rebuild. Pull-to-refresh or explicit retry clears those sets first.
Set<String> pendingStorePriceIds({
  required Iterable<String> rawIds,
  required Set<String> loadedIds,
  required Set<String> failedIds,
  required Set<String> notFoundIds,
}) {
  return rawIds
      .map((String id) => id.trim())
      .where(
        (String id) =>
            id.isNotEmpty &&
            !loadedIds.contains(id) &&
            !failedIds.contains(id) &&
            !notFoundIds.contains(id),
      )
      .toSet();
}

enum PlusOfferBlock { none, missingMapping, loading, priceFailed }

PlusOfferBlock plusOfferBlock({
  required String productId,
  required String basePlanId,
  required bool hasQuote,
  required bool queryFailed,
}) {
  if (productId.trim().isEmpty || basePlanId.trim().isEmpty) {
    return PlusOfferBlock.missingMapping;
  }
  if (hasQuote) {
    return PlusOfferBlock.none;
  }
  if (queryFailed) {
    return PlusOfferBlock.priceFailed;
  }
  return PlusOfferBlock.loading;
}

QueriedPurchaseState? queriedPurchaseState(PurchaseStatus status) {
  switch (status) {
    case PurchaseStatus.pending:
      return QueriedPurchaseState.pending;
    case PurchaseStatus.purchased:
    case PurchaseStatus.restored:
      return QueriedPurchaseState.purchased;
    case PurchaseStatus.canceled:
    case PurchaseStatus.error:
      return null;
  }
}
