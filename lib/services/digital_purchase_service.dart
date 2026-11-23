import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'apple_account_token.dart';
import 'digital_restore.dart';
import 'plus_subscription_offer.dart';
import 'purchase_analytics.dart';
import 'purchase_flow_reconcile.dart';
import 'store_billing_service.dart';

enum DigitalStoreProductKind { plusSubscription, badgeNonConsumable }

/// Gift actions are shown only when the catalog row has a dedicated gift
/// product mapping. Missing mappings therefore keep the other gifts closed.
const bool kGiftActionsEnabled = true;

/// Campaign authoring remains separate from the verified gift purchase path.
const bool kMarketCampaignActionsEnabled = false;

/// Off until Play exposes the verified 399 TRY offer for all target badges
/// and server-side Plus/offer verification is live.
const bool kPlusBadgeDiscountEnabled = true;

class DigitalPurchaseResult {
  const DigitalPurchaseResult({
    required this.internalProductId,
    required this.googlePlayProductId,
    required this.kind,
    required this.operationId,
    this.plusExpiresAt,
  });

  final String internalProductId;
  final String googlePlayProductId;
  final String kind;
  final String operationId;
  final DateTime? plusExpiresAt;
}

class PlayPriceLoad {
  const PlayPriceLoad({
    this.prices = const <String, String>{},
    this.notFoundIds = const <String>{},
    this.requestedIds = const <String>{},
    this.connectionFailed = false,
  });

  final Map<String, String> prices;
  final Set<String> notFoundIds;
  final Set<String> requestedIds;
  final bool connectionFailed;
}

class DigitalPurchaseService with WidgetsBindingObserver {
  DigitalPurchaseService({
    StoreBillingService? billing,
    FirebaseFunctions? functions,
  }) : _billing = billing ?? StoreBillingService(),
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  static final DigitalPurchaseService instance = DigitalPurchaseService();

  final StoreBillingService _billing;
  final FirebaseFunctions _functions;

  final Map<String, Completer<DigitalPurchaseResult>> _pending =
      <String, Completer<DigitalPurchaseResult>>{};
  final Map<String, String> _giftRecipients = <String, String>{};
  final Map<String, String> _giftIntentIds = <String, String>{};
  final Map<String, PurchaseDetails> _awaitingPurchases =
      <String, PurchaseDetails>{};

  bool _started = false;
  bool _sessionAttached = false;
  int _sessionGeneration = 0;
  bool _explicitRestore = false;
  int _restoreInFlight = 0;
  int _restoreVerifiedForAccount = 0;
  int _restoreGiftsKept = 0;
  int _restorePendingPayments = 0;
  String? _restoreError;
  bool _observingLifecycle = false;
  bool _billingUiCoveredApp = false;
  final PurchaseStatusCheckGate _statusCheck = PurchaseStatusCheckGate();
  final Set<String> _verifyInFlight = <String>{};
  final ValueNotifier<PurchaseFlowPhase> flowPhase =
      ValueNotifier<PurchaseFlowPhase>(PurchaseFlowPhase.idle);
  final ValueNotifier<bool> statusCheckInFlight = ValueNotifier<bool>(false);
  final ValueNotifier<bool> restoreInFlight = ValueNotifier<bool>(false);
  final ValueNotifier<int> verifiedAfterClose = ValueNotifier<int>(0);

  /// Play store ids that Play charged but the server has not delivered yet,
  /// with the last server message. Checking again never opens a new payment.
  final ValueNotifier<Map<String, String>> awaitingDelivery =
      ValueNotifier<Map<String, String>>(const <String, String>{});

  bool get hasOpenPurchaseAttempt => _pending.isNotEmpty;

  bool get verificationInFlight => _verifyInFlight.isNotEmpty;

  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  String get _storeName => _isIOS ? 'App Store' : 'Google Play';

  final Set<String> _restoreHandledKeys = <String>{};

  /// Starts the single store purchase stream for the signed-in session.
  ///
  /// On Android replays purchases that were not acknowledged before process
  /// death. On iOS StoreKit 2 delivers unfinished transactions automatically
  /// via `Transaction.updates` without prompting the user for Apple ID login.
  Future<void> attachSession() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    if (_sessionAttached) {
      return;
    }

    _sessionAttached = true;
    final int generation = ++_sessionGeneration;
    await start();

    if (!_sessionAttached || generation != _sessionGeneration) {
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _billing.restorePurchases();
      } catch (_) {
        // Billing can be unavailable at launch. The next signed-in session retries.
      }
    }
  }

  Future<void> detachSession() async {
    if (!_sessionAttached) {
      return;
    }

    _sessionAttached = false;
    _sessionGeneration++;
    await dispose();
  }

  Future<void> start() async {
    if (_started) {
      return;
    }

    _started = true;
    await _billing.start(onPurchase: _handlePurchaseUpdate);
    if (!_observingLifecycle) {
      WidgetsBinding.instance.addObserver(this);
      _observingLifecycle = true;
    }
  }

  Future<void> dispose() async {
    for (final Completer<DigitalPurchaseResult> completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          const DigitalPurchaseException('Satın alma ekranı kapatıldı.'),
        );
      }
    }

    _pending.clear();
    _giftRecipients.clear();
    _giftIntentIds.clear();
    _awaitingPurchases.clear();
    awaitingDelivery.value = const <String, String>{};
    _started = false;
    if (_observingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      _observingLifecycle = false;
    }
    await _billing.stop();
  }

  Future<String> loadLocalizedPrice(String googlePlayProductId) async {
    final ProductDetails product = await _loadProduct(googlePlayProductId);
    return product.price;
  }

  /// Play formatted prices. A thrown store error is a connection failure.
  /// A product omitted from a successful response was not found.
  Future<PlayPriceLoad> loadLocalizedPrices(Iterable<String> productIds) async {
    final Set<String> requested = productIds
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toSet();

    try {
      final Map<String, ProductDetails> products = await _billing.loadProducts(
        requested,
      );
      final Map<String, String> prices = <String, String>{
        for (final MapEntry<String, ProductDetails> entry in products.entries)
          if (entry.value.price.trim().isNotEmpty)
            entry.key: entry.value.price.trim(),
      };

      return PlayPriceLoad(
        prices: prices,
        notFoundIds: requested
            .where((String id) => !prices.containsKey(id))
            .toSet(),
      );
    } catch (_) {
      return PlayPriceLoad(connectionFailed: true, requestedIds: requested);
    }
  }

  Future<DigitalRestoreResult> restorePurchases() async {
    if (_explicitRestore) {
      throw const DigitalPurchaseException(
        'Satın almalar zaten kontrol ediliyor.',
      );
    }

    _explicitRestore = true;
    restoreInFlight.value = true;
    _restoreInFlight = 0;
    _restoreVerifiedForAccount = 0;
    _restoreGiftsKept = 0;
    _restorePendingPayments = 0;
    _restoreError = null;
    _restoreHandledKeys.clear();

    try {
      await start();
      await _billing.restorePurchases();
      if (_isIOS) {
        final PastPurchaseQuery past = await _billing.queryPastPurchases();
        if (past.succeeded) {
          for (final PurchaseDetails purchase in past.purchases) {
            final String dedupeKey =
                '${purchase.productID}:${purchase.purchaseID ?? ''}';
            if (_restoreHandledKeys.contains(dedupeKey)) {
              continue;
            }
            await _handlePurchaseUpdate(purchase);
          }
        }
      }
      final DateTime deadline = DateTime.now().add(const Duration(seconds: 30));
      while (_restoreInFlight > 0) {
        if (DateTime.now().isAfter(deadline)) {
          throw const DigitalPurchaseException(
            'Satın alma doğrulaması zaman aşımına uğradı.',
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      if (_restoreError != null &&
          _restoreVerifiedForAccount == 0 &&
          _restoreGiftsKept == 0) {
        throw DigitalPurchaseException(_restoreError!);
      }
      return DigitalRestoreResult(
        verifiedForAccount: _restoreVerifiedForAccount,
        giftsKeptWithRecipient: _restoreGiftsKept,
        pendingPayments: _restorePendingPayments,
      );
    } finally {
      _explicitRestore = false;
      restoreInFlight.value = false;
    }
  }

  /// Resolves the standard base plan for the price shown before purchase.
  Future<PlusSubscriptionSelection> loadPlusSelection({
    required String googlePlayProductId,
    required String googlePlayBasePlanId,
    String campaignOfferId = '',
    int discountedPeriods = 0,
  }) async {
    final String storeId = googlePlayProductId.trim();
    final List<ProductDetails> products = await _billing.queryProducts(<String>[
      storeId,
    ]);

    return selectCatalogPlusOffer(
      offers: products,
      googlePlayProductId: storeId,
      googlePlayBasePlanId: googlePlayBasePlanId,
      campaignOfferId: campaignOfferId,
      discountedPeriods: discountedPeriods,
    );
  }

  /// Resolves the App Store auto-renewable Plus subscription product on iOS.
  Future<PlusSubscriptionSelection> loadApplePlusSelection({
    required String appleProductId,
  }) async {
    final String storeId = appleProductId.trim();
    final List<ProductDetails> products = await _billing.queryProducts(<String>[
      storeId,
    ]);

    return selectApplePlusProduct(
      offers: products,
      appleProductId: storeId,
    );
  }

  Future<DigitalPurchaseResult> purchase({
    required String googlePlayProductId,
    required DigitalStoreProductKind kind,
    String? internalProductId,
    String? recipientUid,
    String? googlePlayBasePlanId,
    PlusSubscriptionSelection? plusSelection,
    String? giftIntentId,
    String? oneTimeOfferToken,
  }) async {
    final String storeId = googlePlayProductId.trim();
    final String eventPrefix = kind == DigitalStoreProductKind.plusSubscription
        ? 'plus_purchase'
        : 'badge_purchase';

    if (storeId.isEmpty) {
      await PurchaseAnalytics.log(
        name: '${eventPrefix}_failed',
        googlePlayProductId: storeId,
        internalProductId: internalProductId,
        errorCode: 'missing_product_id',
      );
      throw DigitalPurchaseException(
        '$_storeName ürün eşlemesi henüz yapılmamış.',
      );
    }

    await PurchaseAnalytics.log(
      name: '${eventPrefix}_started',
      googlePlayProductId: storeId,
      internalProductId: internalProductId,
    );

    await start();

    if (_pending.isNotEmpty) {
      await PurchaseAnalytics.log(
        name: '${eventPrefix}_failed',
        googlePlayProductId: storeId,
        internalProductId: internalProductId,
        errorCode: 'in_progress',
      );
      throw const DigitalPurchaseException(
        'Satın alma işlemi zaten devam ediyor.',
        code: 'in_progress',
      );
    }

    final ProductDetails? badgeProduct;
    final PlusSubscriptionSelection? plusOffer;

    try {
      switch (kind) {
        case DigitalStoreProductKind.plusSubscription:
          badgeProduct = null;
          plusOffer = await _selectDisplayedPlusOffer(
            storeId: storeId,
            googlePlayBasePlanId: googlePlayBasePlanId,
            displayed: plusSelection,
          );
          break;
        case DigitalStoreProductKind.badgeNonConsumable:
          badgeProduct = await _loadProduct(storeId);
          plusOffer = null;
          break;
      }
    } on PlusSubscriptionOfferException catch (error) {
      await PurchaseAnalytics.log(
        name: '${eventPrefix}_failed',
        googlePlayProductId: storeId,
        internalProductId: internalProductId,
        errorCode: error.code,
      );
      throw DigitalPurchaseException(error.message, code: error.code);
    } catch (error) {
      await PurchaseAnalytics.log(
        name: '${eventPrefix}_failed',
        googlePlayProductId: storeId,
        internalProductId: internalProductId,
        errorCode: 'product_unavailable',
      );
      rethrow;
    }
    final Completer<DigitalPurchaseResult> completer =
        Completer<DigitalPurchaseResult>();

    _pending[storeId] = completer;
    final String giftRecipient = recipientUid?.trim() ?? '';
    if (giftRecipient.isNotEmpty &&
        giftRecipient != FirebaseAuth.instance.currentUser?.uid) {
      _giftRecipients[storeId] = giftRecipient;
    } else {
      _giftRecipients.remove(storeId);
    }
    final String intentId = giftIntentId?.trim() ?? '';
    if (intentId.isNotEmpty) {
      _giftIntentIds[storeId] = intentId;
    } else {
      _giftIntentIds.remove(storeId);
    }

    final String buyerUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final String? accountId = _isIOS
        ? (buyerUid.isEmpty ? null : appleAppAccountTokenForUid(buyerUid))
        : (intentId.isNotEmpty
            ? intentId
            : (buyerUid.isEmpty ? null : buyerUid));

    _billingUiCoveredApp = false;
    try {
      switch (kind) {
        case DigitalStoreProductKind.plusSubscription:
          await _billing.buySubscription(plusOffer!, accountId: accountId);
          break;
        case DigitalStoreProductKind.badgeNonConsumable:
          await _billing.buyNonConsumable(
            badgeProduct!,
            offerToken: oneTimeOfferToken,
            accountId: accountId,
          );
          break;
      }
    } catch (error) {
      final bool recoverOwned = error is StoreBillingException;
      final bool recovered =
          recoverOwned && await _verifyQueriedPurchase(storeId);
      if (!recovered) {
        _releasePending(storeId);
        flowPhase.value = PurchaseFlowPhase.idle;

        if (!completer.isCompleted) {
          completer.completeError(error);
        }

        await PurchaseAnalytics.log(
          name: '${eventPrefix}_failed',
          googlePlayProductId: storeId,
          internalProductId: internalProductId,
          errorCode: 'billing_start_failed',
        );
        rethrow;
      }
    }

    flowPhase.value = PurchaseFlowPhase.awaitingStore;

    try {
      final DigitalPurchaseResult result = await completer.future;
      await PurchaseAnalytics.log(
        name: '${eventPrefix}_success',
        googlePlayProductId: storeId,
        internalProductId: result.internalProductId,
      );
      return result;
    } on DigitalPurchaseException catch (error) {
      await PurchaseAnalytics.log(
        name: '${eventPrefix}_failed',
        googlePlayProductId: storeId,
        internalProductId: internalProductId,
        errorCode: _analyticsErrorCode(error.message),
      );
      rethrow;
    } catch (error) {
      await PurchaseAnalytics.log(
        name: '${eventPrefix}_failed',
        googlePlayProductId: storeId,
        internalProductId: internalProductId,
        errorCode: error is FirebaseFunctionsException ? error.code : 'unknown',
      );
      rethrow;
    } finally {
      if (_pending.isEmpty) {
        flowPhase.value = PurchaseFlowPhase.idle;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_pending.isEmpty) {
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _billingUiCoveredApp = true;
      return;
    }
    if (state == AppLifecycleState.resumed && _billingUiCoveredApp) {
      _billingUiCoveredApp = false;
      unawaited(_reconcileOpenPurchases());
    }
  }

  Future<void> recheckOpenPurchases() {
    return _reconcileOpenPurchases();
  }

  /// Re-sends purchases Play already charged to the server. A purchase Play
  /// no longer returns (refunded or cancelled) stops waiting for delivery.
  Future<DeliveryRecheckOutcome> recheckAwaitingDelivery() async {
    final List<String> storeIds = awaitingDelivery.value.keys.toList();
    if (storeIds.isEmpty) {
      return DeliveryRecheckOutcome.delivered;
    }
    if (!_statusCheck.tryBegin()) {
      return DeliveryRecheckOutcome.busy;
    }
    statusCheckInFlight.value = true;
    var querySucceeded = false;
    var missingFromPlay = 0;
    var pendingPayments = 0;
    try {
      await start();
      final PastPurchaseQuery query = await _billing.queryPastPurchases();
      querySucceeded = query.succeeded;
      if (query.succeeded) {
        for (final String storeId in storeIds) {
          final List<PurchaseDetails> matches = query.purchases
              .where(
                (PurchaseDetails purchase) => purchase.productID == storeId,
              )
              .toList();
          if (matches.any(_paymentStillPending)) {
            pendingPayments++;
            continue;
          }
          final Iterable<PurchaseDetails> verifiable = matches.where(
            (PurchaseDetails purchase) => shouldVerifyPurchase(purchase.status),
          );
          if (verifiable.isEmpty) {
            final PurchaseDetails? cached = _awaitingPurchases[storeId];
            switch (missingPurchaseRecheckAction(
              hasCachedPurchase: cached != null,
            )) {
              case MissingPurchaseRecheckAction.retryCachedPurchase:
                await _handlePurchaseUpdate(cached!);
                break;
              case MissingPurchaseRecheckAction.closeAsNotInPlay:
                missingFromPlay++;
                _clearAwaitingDelivery(storeId);
                break;
            }
            continue;
          }
          await _handlePurchaseUpdate(verifiable.first);
        }
      }
    } catch (_) {
      querySucceeded = false;
    } finally {
      _statusCheck.end();
      statusCheckInFlight.value = false;
    }
    return classifyDeliveryRecheck(
      querySucceeded: querySucceeded,
      awaitingBefore: storeIds.length,
      awaitingAfter: awaitingDelivery.value.length,
      missingFromPlay: missingFromPlay,
      pendingPayments: pendingPayments,
    );
  }

  void _markAwaitingDelivery(
    String storeId,
    String message, {
    String? code,
    PurchaseDetails? purchase,
  }) {
    if (storeId.isEmpty || !keepsDeliveryPending(code)) {
      _clearAwaitingDelivery(storeId);
      return;
    }
    awaitingDelivery.value = <String, String>{
      ...awaitingDelivery.value,
      storeId: message,
    };
    if (purchase != null) {
      _awaitingPurchases[storeId] = purchase;
    }
  }

  void _clearAwaitingDelivery(String storeId) {
    if (!awaitingDelivery.value.containsKey(storeId)) {
      return;
    }
    awaitingDelivery.value = Map<String, String>.of(awaitingDelivery.value)
      ..remove(storeId);
    _awaitingPurchases.remove(storeId);
  }

  /// Verifies a purchase Play already has. Does not open a new payment.
  Future<bool> _verifyQueriedPurchase(String storeId) async {
    final String productId = storeId.trim();
    if (productId.isEmpty) {
      return false;
    }
    final PastPurchaseQuery query = await _billing.queryPastPurchases();
    final List<PurchaseDetails> owned = query.succeeded
        ? query.purchases
              .where(
                (PurchaseDetails purchase) =>
                    purchase.productID == productId &&
                    shouldVerifyPurchase(purchase.status),
              )
              .toList()
        : const <PurchaseDetails>[];
    if (recoverUnstartedPurchase(
          querySucceeded: query.succeeded,
          hasOwnedPurchase: owned.isNotEmpty,
        ) !=
        OwnedLaunchRecovery.verifyExisting) {
      return false;
    }
    await _handlePurchaseUpdate(owned.first);
    return true;
  }

  Future<void> _reconcileOpenPurchases() async {
    if (_pending.isEmpty || !_statusCheck.tryBegin()) {
      return;
    }
    statusCheckInFlight.value = true;
    try {
      final PastPurchaseQuery query = await _billing.queryPastPurchases();
      for (final String storeId in _pending.keys.toList()) {
        final List<PurchaseDetails> matches = query.succeeded
            ? query.purchases
                  .where(
                    (PurchaseDetails purchase) => purchase.productID == storeId,
                  )
                  .toList()
            : const <PurchaseDetails>[];
        final PurchaseReconcileAction action = reconcilePurchaseQuery(
          returnedFromBillingUi: true,
          verificationInFlight: _verifyInFlight.contains(storeId),
          querySucceeded: query.succeeded,
          matches: matches
              .map(
                (PurchaseDetails purchase) =>
                    queriedPurchaseState(purchase.status),
              )
              .whereType<QueriedPurchaseState>()
              .toList(),
        );
        switch (action) {
          case PurchaseReconcileAction.keepWaiting:
            break;
          case PurchaseReconcileAction.waitForPayment:
            flowPhase.value = PurchaseFlowPhase.pendingPayment;
            break;
          case PurchaseReconcileAction.verifyExisting:
            await _handlePurchaseUpdate(
              matches.firstWhere(
                (PurchaseDetails purchase) =>
                    shouldVerifyPurchase(purchase.status),
              ),
            );
            break;
          case PurchaseReconcileAction.cancelAsAbandoned:
            _finishOpenAttempt(
              storeId,
              const DigitalPurchaseException(
                'Satın alma işlemi iptal edildi.',
                code: 'canceled',
              ),
            );
            break;
          case PurchaseReconcileAction.statusUnknown:
            flowPhase.value = PurchaseFlowPhase.statusUnknown;
            break;
        }
      }
    } finally {
      _statusCheck.end();
      statusCheckInFlight.value = false;
    }
  }

  void _finishOpenAttempt(String storeId, DigitalPurchaseException error) {
    final Completer<DigitalPurchaseResult>? completer = _pending[storeId];
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error);
    }
    _releasePending(storeId);
    if (_pending.isEmpty) {
      flowPhase.value = PurchaseFlowPhase.idle;
    }
  }

  String _analyticsErrorCode(String message) {
    final String normalized = message.toLowerCase();
    if (normalized.contains('iptal')) {
      return 'canceled';
    }
    if (normalized.contains('bekleniyor')) {
      return 'timeout';
    }
    if (normalized.contains('doğrulanamadı') ||
        normalized.contains('dogrulanamadi')) {
      return 'verification_failed';
    }
    return 'purchase_failed';
  }

  Future<PlusSubscriptionSelection> _selectDisplayedPlusOffer({
    required String storeId,
    required String? googlePlayBasePlanId,
    required PlusSubscriptionSelection? displayed,
  }) async {
    if (displayed == null) {
      throw const PlusSubscriptionOfferException(
        'Satın alma, ekranda gösterilen teklif olmadan başlatılamaz.',
        code: 'offer_not_displayed',
      );
    }

    final PlusSubscriptionSelection selected = _isIOS
        ? await loadApplePlusSelection(appleProductId: storeId)
        : await loadPlusSelection(
            googlePlayProductId: storeId,
            googlePlayBasePlanId: googlePlayBasePlanId ?? '',
            campaignOfferId: displayed.offerId,
            discountedPeriods: displayed.discountedPeriodCount,
          );

    if (!samePlusOffer(displayed, selected) ||
        displayed.productDetails.id != storeId) {
      throw PlusSubscriptionOfferException(
        '$_storeName teklifi değişti. Ekrandaki fiyat güncellenmeden '
        'satın alma başlatılmadı.',
        code: 'offer_changed',
      );
    }

    return selected;
  }

  Future<ProductDetails> _loadProduct(String googlePlayProductId) async {
    final String storeId = googlePlayProductId.trim();

    if (storeId.isEmpty) {
      throw DigitalPurchaseException(
        '$_storeName ürün eşlemesi henüz yapılmamış.',
      );
    }

    final Map<String, ProductDetails> products = await _billing.loadProducts(
      <String>[storeId],
    );

    final ProductDetails? product = products[storeId];

    if (product == null) {
      throw DigitalPurchaseException(
        'Ürün $_storeName üzerinde bulunamadı.',
      );
    }

    return product;
  }

  // restorePurchases reports Play's pending payments as restored.
  bool _paymentStillPending(PurchaseDetails purchase) {
    if (purchase.status == PurchaseStatus.pending) {
      return true;
    }
    return purchase is GooglePlayPurchaseDetails &&
        purchase.billingClientPurchase.purchaseState ==
            PurchaseStateWrapper.pending;
  }

  Future<void> _handlePurchaseUpdate(PurchaseDetails purchase) async {
    final int callbackGeneration = _sessionGeneration;
    final String callbackUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool paymentPending = _paymentStillPending(purchase);
    if (_explicitRestore && paymentPending) {
      _restorePendingPayments++;
    }
    final bool trackRestore = _explicitRestore && !paymentPending;
    if (trackRestore) {
      _restoreInFlight++;
    }
    try {
      await _handleTrackedPurchaseUpdate(
        purchase,
        callbackGeneration: callbackGeneration,
        callbackUid: callbackUid,
      );
    } finally {
      if (trackRestore) {
        _restoreInFlight--;
      }
    }
  }

  void _noteRestoreSuccess(Map<dynamic, dynamic> rawData) {
    if (!_explicitRestore) {
      return;
    }
    final String kind = rawData['kind']?.toString() ?? '';
    final String recipient = rawData['recipientUid']?.toString() ?? '';
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool gift = kind == 'badge_gift' || kind == 'plus_gift';
    if (gift && recipient.isNotEmpty && recipient != uid) {
      _restoreGiftsKept++;
      return;
    }
    _restoreVerifiedForAccount++;
  }

  void _noteRestoreFailure(String message) {
    if (!_explicitRestore) {
      return;
    }
    _restoreError ??= message;
  }

  Future<void> _handleTrackedPurchaseUpdate(
    PurchaseDetails purchase, {
    required int callbackGeneration,
    required String callbackUid,
  }) async {
    bool currentSession() => purchaseCallbackBelongsToSession(
      callbackGeneration: callbackGeneration,
      currentGeneration: _sessionGeneration,
      callbackUid: callbackUid,
      currentUid: FirebaseAuth.instance.currentUser?.uid ?? '',
    );

    if (!currentSession()) {
      return;
    }
    final String storeId = purchase.productID.trim();
    if (isEmptyProductCancel(purchase)) {
      for (final String id in _pending.keys.toList()) {
        _finishOpenAttempt(
          id,
          const DigitalPurchaseException(
            'Satın alma işlemi iptal edildi.',
            code: 'canceled',
          ),
        );
      }
      return;
    }
    final Completer<DigitalPurchaseResult>? completer = _pending[storeId];

    // Play has not finished. Keep the local lock so the button stays busy,
    // but do not treat this as a failed attempt.
    if (_paymentStillPending(purchase)) {
      if (completer != null) {
        flowPhase.value = PurchaseFlowPhase.pendingPayment;
      }
      return;
    }

    final bool terminal =
        purchase.status == PurchaseStatus.canceled ||
        purchase.status == PurchaseStatus.error ||
        purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored;
    var keepLocked = false;
    var startedVerification = false;

    try {
      if (purchase.status == PurchaseStatus.canceled) {
        _noteRestoreFailure('Satın alma işlemi iptal edildi.');
        if (completer != null && !completer.isCompleted) {
          completer.completeError(
            const DigitalPurchaseException('Satın alma işlemi iptal edildi.'),
          );
        }

        return;
      }

      final bool isApplePurchase =
          purchase.verificationData.source == 'app_store' || _isIOS;
      final String providerLabel = isApplePurchase
          ? 'App Store'
          : 'Google Play';

      if (purchase.status == PurchaseStatus.error) {
        final String message =
            purchase.error?.message ??
            '$providerLabel satın alma işlemi tamamlanamadı.';
        final bool alreadyOwned = isAlreadyOwnedPlayError(
          code: purchase.error?.code,
          message: message,
        );
        final String ownedProductId = storeId.isNotEmpty
            ? storeId
            : (_pending.length == 1 ? _pending.keys.first : '');
        if (alreadyOwned &&
            ownedProductId.isNotEmpty &&
            await _verifyQueriedPurchase(ownedProductId)) {
          return;
        }
        _noteRestoreFailure(message);
        if (completer != null && !completer.isCompleted) {
          completer.completeError(DigitalPurchaseException(message));
        }

        return;
      }

      if (!shouldVerifyPurchase(purchase.status)) {
        return;
      }
      if (_verifyInFlight.contains(storeId)) {
        keepLocked = true;
        return;
      }
      _verifyInFlight.add(storeId);
      startedVerification = true;
      if (completer != null && !completer.isCompleted) {
        flowPhase.value = PurchaseFlowPhase.verifying;
      }

      final String purchaseToken = purchase
          .verificationData
          .serverVerificationData
          .trim();

      if (purchaseToken.isEmpty) {
        final String missingMsg =
            '$providerLabel doğrulama bilgisi alınamadı.';
        _noteRestoreFailure(missingMsg);
        _markAwaitingDelivery(
          storeId,
          missingMsg,
          purchase: purchase,
        );
        if (completer != null && !completer.isCompleted) {
          completer.completeError(DigitalPurchaseException(missingMsg));
        }

        return;
      }

      if (_explicitRestore) {
        _restoreHandledKeys.add(
          '${purchase.productID}:${purchase.purchaseID ?? ''}',
        );
      }

      final HttpsCallable callable = _functions.httpsCallable(
        isApplePurchase ? 'fulfillApplePurchase' : 'fulfillGooglePlayPurchase',
      );

      final Map<String, dynamic> payload;
      if (isApplePurchase) {
        final String txId = purchase.purchaseID?.trim() ?? '';
        payload = <String, dynamic>{
          'appleProductId': storeId,
          'signedTransactionInfo': purchaseToken,
          if (txId.isNotEmpty) 'transactionId': txId,
        };
      } else {
        payload = <String, dynamic>{
          'googlePlayProductId': storeId,
          'purchaseToken': purchaseToken,
        };
        String? giftIntentId = _giftIntentIds[storeId];
        if (purchase is GooglePlayPurchaseDetails) {
          final String account =
              purchase.billingClientPurchase.obfuscatedAccountId?.trim() ?? '';
          if (account.isNotEmpty &&
              account != FirebaseAuth.instance.currentUser?.uid) {
            giftIntentId = account;
          }
        }
        if (giftIntentId != null && giftIntentId.isNotEmpty) {
          payload['giftIntentId'] = giftIntentId;
        }
      }

      final HttpsCallableResult<dynamic> response = await callable.call(
        payload,
      );

      if (!currentSession()) {
        return;
      }

      final dynamic rawData = response.data;

      if (rawData is! Map) {
        throw const DigitalPurchaseException(
          'Satın alma doğrulama sonucu okunamadı.',
        );
      }

      final bool success = rawData['success'] == true;

      if (!success) {
        final String status = rawData['status']?.toString() ?? '';
        if (status == 'pending') {
          keepLocked = true;
          flowPhase.value = PurchaseFlowPhase.pendingPayment;
          return;
        }
        if (status == 'review') {
          throw DigitalPurchaseException(
            'Ödeme alındı ama teslimat incelemede. Sebep: ${rawData['reason'] ?? 'review'}.',
            code: 'review',
          );
        }
        if (status == 'cancelled') {
          throw const DigitalPurchaseException(
            'Satın alma işlemi iptal edildi.',
            code: 'cancelled',
          );
        }
        throw const DigitalPurchaseException(
          'Satın alma sunucu tarafından doğrulanamadı.',
        );
      }

      final String internalProductId =
          rawData['productId']?.toString().trim() ?? '';
      final String kind = rawData['kind']?.toString().trim() ?? '';
      final String operationId =
          rawData['operationId']?.toString().trim() ?? '';

      if (internalProductId.isEmpty || kind.isEmpty || operationId.isEmpty) {
        throw const DigitalPurchaseException(
          'Satın alma doğrulama kaydı eksik.',
        );
      }

      final String rawExpiry =
          rawData['plusExpiresAt']?.toString().trim() ?? '';

      final DigitalPurchaseResult result = DigitalPurchaseResult(
        internalProductId: internalProductId,
        googlePlayProductId: storeId,
        kind: kind,
        operationId: operationId,
        plusExpiresAt: rawExpiry.isEmpty ? null : DateTime.tryParse(rawExpiry),
      );

      _clearAwaitingDelivery(storeId);
      if (kind != 'badge_gift' && kind != 'plus_gift') {
        try {
          await _billing.completeAfterServerVerification(purchase);
        } catch (_) {
          // The server already delivered and acknowledged. Play replays the
          // purchase on the next session and the server answers idempotently.
        }
      }

      _noteRestoreSuccess(rawData);
      if (completer != null && !completer.isCompleted) {
        completer.complete(result);
      } else {
        verifiedAfterClose.value++;
      }
    } on FirebaseFunctionsException catch (error) {
      if (!currentSession()) {
        return;
      }
      // Provider text may be raw RESOURCE_EXHAUSTED or contain private details.
      final String message = '$_storeName satın alma doğrulanamadı.';
      _noteRestoreFailure(message);
      if (startedVerification) {
        _markAwaitingDelivery(
          storeId,
          message,
          code: error.code,
          purchase: purchase,
        );
      }
      if (completer != null && !completer.isCompleted) {
        completer.completeError(
          DigitalPurchaseException(
            message,
            code: error.code,
            stage: 'server-verification',
          ),
        );
      }
    } catch (error) {
      if (!currentSession()) {
        return;
      }
      final String message = error is DigitalPurchaseException
          ? error.message
          : 'Satın alma sunucu tarafından doğrulanamadı.';
      _noteRestoreFailure(message);
      if (startedVerification) {
        _markAwaitingDelivery(
          storeId,
          message,
          code: error is DigitalPurchaseException ? error.code : null,
          purchase: purchase,
        );
      }
      if (completer != null && !completer.isCompleted) {
        completer.completeError(error);
      }
    } finally {
      if (startedVerification) {
        _verifyInFlight.remove(storeId);
      }
      if (terminal && !keepLocked) {
        _releasePending(storeId);
      }
    }
  }

  void _releasePending(String storeId) {
    _pending.remove(storeId);
    _giftRecipients.remove(storeId);
    _giftIntentIds.remove(storeId);
  }
}

class DigitalPurchaseException implements Exception {
  const DigitalPurchaseException(this.message, {this.code, this.stage});

  final String message;
  final String? code;
  final String? stage;

  @override
  String toString() => message;
}
