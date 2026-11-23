import 'package:dorduncu/services/purchase_flow_reconcile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

void main() {
  test('ödeme yöntemlerinden dönüşte kayıt yoksa deneme kapanır', () {
    final PurchaseReconcileAction action = reconcilePurchaseQuery(
      returnedFromBillingUi: true,
      verificationInFlight: false,
      querySucceeded: true,
      matches: const <QueriedPurchaseState>[],
    );

    expect(action, PurchaseReconcileAction.cancelAsAbandoned);
    expect(canStartPurchase(attemptOpen: true, action: action), isTrue);
  });

  test('yalnızca resumed olmak açık ödemeyi kapatmaz', () {
    final PurchaseReconcileAction action = reconcilePurchaseQuery(
      returnedFromBillingUi: false,
      verificationInFlight: false,
      querySucceeded: true,
      matches: const <QueriedPurchaseState>[],
    );

    expect(action, PurchaseReconcileAction.keepWaiting);
    expect(canStartPurchase(attemptOpen: true, action: action), isFalse);
  });

  test('pending satın alma ikinci ödemeyi başlatmaz', () {
    final PurchaseReconcileAction action = reconcilePurchaseQuery(
      returnedFromBillingUi: true,
      verificationInFlight: false,
      querySucceeded: true,
      matches: const <QueriedPurchaseState>[QueriedPurchaseState.pending],
    );

    expect(action, PurchaseReconcileAction.waitForPayment);
    expect(canStartPurchase(attemptOpen: true, action: action), isFalse);
  });

  test('geç gelen başarılı satın alma doğrulanır', () {
    expect(shouldVerifyPurchase(PurchaseStatus.purchased), isTrue);
    expect(shouldVerifyPurchase(PurchaseStatus.restored), isTrue);
    expect(
      reconcilePurchaseQuery(
        returnedFromBillingUi: true,
        verificationInFlight: false,
        querySucceeded: true,
        matches: const <QueriedPurchaseState>[QueriedPurchaseState.purchased],
      ),
      PurchaseReconcileAction.verifyExisting,
    );
  });

  test('iptalden sonra yeni satın alma açılabilir', () {
    expect(
      canStartPurchase(
        attemptOpen: false,
        action: PurchaseReconcileAction.cancelAsAbandoned,
      ),
      isTrue,
    );
  });

  test('boş ürün kimlikli iptal açık denemeyi kapatır', () {
    final PurchaseDetails purchase = PurchaseDetails(
      purchaseID: '',
      productID: '',
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: '',
        source: 'google_play',
      ),
      transactionDate: null,
      status: PurchaseStatus.canceled,
    );

    expect(isEmptyProductCancel(purchase), isTrue);
  });

  test('çevrimdışı sorgu yeniden bağlanınca tekrar kontrol edilir', () {
    final PurchaseStatusCheckGate gate = PurchaseStatusCheckGate();

    expect(gate.tryBegin(), isTrue);
    final PurchaseReconcileAction offline = reconcilePurchaseQuery(
      returnedFromBillingUi: true,
      verificationInFlight: false,
      querySucceeded: false,
      matches: const <QueriedPurchaseState>[],
    );
    expect(offline, PurchaseReconcileAction.statusUnknown);
    expect(canStartPurchase(attemptOpen: true, action: offline), isFalse);
    expect(
      openPurchaseFollowUp(
        phase: PurchaseFlowPhase.statusUnknown,
        checkInFlight: true,
      ),
      OpenPurchaseFollowUp.blocked,
    );
    expect(gate.tryBegin(), isFalse);
    expect(gate.queryCount, 1);
    gate.end();

    expect(
      openPurchaseFollowUp(
        phase: PurchaseFlowPhase.statusUnknown,
        checkInFlight: false,
      ),
      OpenPurchaseFollowUp.recheckExisting,
    );
    expect(gate.tryBegin(), isTrue);

    final PurchaseReconcileAction empty = reconcilePurchaseQuery(
      returnedFromBillingUi: true,
      verificationInFlight: false,
      querySucceeded: true,
      matches: const <QueriedPurchaseState>[],
    );
    expect(empty, PurchaseReconcileAction.cancelAsAbandoned);
    expect(canStartPurchase(attemptOpen: true, action: empty), isTrue);
    expect(
      openPurchaseFollowUp(phase: PurchaseFlowPhase.idle, checkInFlight: false),
      OpenPurchaseFollowUp.startPayment,
    );
    gate.end();

    final PurchaseReconcileAction pending = reconcilePurchaseQuery(
      returnedFromBillingUi: true,
      verificationInFlight: false,
      querySucceeded: true,
      matches: const <QueriedPurchaseState>[QueriedPurchaseState.pending],
    );
    expect(pending, PurchaseReconcileAction.waitForPayment);
    expect(canStartPurchase(attemptOpen: true, action: pending), isFalse);

    final PurchaseReconcileAction purchased = reconcilePurchaseQuery(
      returnedFromBillingUi: true,
      verificationInFlight: false,
      querySucceeded: true,
      matches: const <QueriedPurchaseState>[QueriedPurchaseState.purchased],
    );
    expect(purchased, PurchaseReconcileAction.verifyExisting);
    expect(canStartPurchase(attemptOpen: true, action: purchased), isFalse);
    expect(purchaseStatusUnknownMessage, 'Satın alma durumu kontrol edilemedi');
    expect(purchaseStatusRecheckLabel, 'Tekrar kontrol et');
  });

  test('geri yükleme fiyata bağlı değildir ve açık ödemeyi silmez', () {
    expect(
      decideMarketRestore(
        phase: PurchaseFlowPhase.idle,
        checkInFlight: false,
        restoreInFlight: false,
      ).action,
      MarketRestoreAction.restore,
    );
    expect(
      decideMarketRestore(
        phase: PurchaseFlowPhase.pendingPayment,
        checkInFlight: false,
        restoreInFlight: false,
      ).reason,
      MarketRestoreReason.paymentPending,
    );
    expect(
      decideMarketRestore(
        phase: PurchaseFlowPhase.verifying,
        checkInFlight: false,
        restoreInFlight: false,
      ).reason,
      MarketRestoreReason.verifying,
    );
    expect(
      decideMarketRestore(
        phase: PurchaseFlowPhase.statusUnknown,
        checkInFlight: false,
        restoreInFlight: false,
      ).action,
      MarketRestoreAction.recheck,
    );
    expect(
      decideMarketRestore(
        phase: PurchaseFlowPhase.statusUnknown,
        checkInFlight: true,
        restoreInFlight: false,
      ).action,
      MarketRestoreAction.wait,
    );
    expect(
      decideMarketRestore(
        phase: PurchaseFlowPhase.awaitingStore,
        checkInFlight: false,
        restoreInFlight: false,
      ).reason,
      MarketRestoreReason.purchaseInProgress,
    );
  });

  test('eşlemesi olmayan ürün fiyat hatası sayılmaz', () {
    expect(
      playPricePresentation(productId: '', hasPrice: false, queryFailed: true),
      PlayPricePresentation.missingMapping,
    );
    expect(
      playPricePresentation(
        productId: 'dort_badge',
        hasPrice: false,
        queryFailed: true,
      ),
      PlayPricePresentation.failed,
    );
    expect(
      canRetryPlayPriceQuery(
        inFlight: true,
        presentation: PlayPricePresentation.failed,
      ),
      isFalse,
    );
    expect(
      canRetryPlayPriceQuery(
        inFlight: false,
        presentation: PlayPricePresentation.failed,
      ),
      isTrue,
    );
    expect(
      playPricePresentation(
        productId: 'dort_badge',
        hasPrice: false,
        queryFailed: false,
        notFound: true,
      ),
      PlayPricePresentation.notFound,
    );
    expect(
      canRetryPlayPriceQuery(
        inFlight: false,
        presentation: PlayPricePresentation.notFound,
      ),
      isFalse,
    );
    expect(
      canRetryPlayPriceQuery(
        inFlight: false,
        presentation: PlayPricePresentation.missingMapping,
      ),
      isFalse,
    );
    expect(
      plusOfferBlock(
        productId: 'dort_plus',
        basePlanId: '',
        hasQuote: false,
        queryFailed: true,
      ),
      PlusOfferBlock.missingMapping,
    );
    expect(
      plusOfferBlock(
        productId: 'dort_plus',
        basePlanId: 'monthly',
        hasQuote: false,
        queryFailed: true,
      ),
      PlusOfferBlock.priceFailed,
    );
  });

  test('zaten sahip olunan ürün yeni ödeme yerine doğrulanır', () {
    expect(
      isAlreadyOwnedPlayError(
        code: 'itemAlreadyOwned',
        message: 'BillingResponse.itemAlreadyOwned',
      ),
      isTrue,
    );
    expect(
      isAlreadyOwnedPlayError(
        message: 'Google Play satın alma ekranı başlatılamadı.',
      ),
      isFalse,
    );
    expect(
      recoverUnstartedPurchase(querySucceeded: true, hasOwnedPurchase: true),
      OwnedLaunchRecovery.verifyExisting,
    );
    expect(
      recoverUnstartedPurchase(querySucceeded: false, hasOwnedPurchase: true),
      OwnedLaunchRecovery.reportFailure,
    );
    expect(
      recoverUnstartedPurchase(querySucceeded: true, hasOwnedPurchase: false),
      OwnedLaunchRecovery.reportFailure,
    );
  });

  test('doğrulama sürerken sorgu kilidi açmaz', () {
    expect(
      reconcilePurchaseQuery(
        returnedFromBillingUi: true,
        verificationInFlight: true,
        querySucceeded: false,
        matches: const <QueriedPurchaseState>[],
      ),
      PurchaseReconcileAction.keepWaiting,
    );
  });

  test('sunucu doğrulaması düşerse ödeme teslimat bekliyor kalır', () {
    expect(keepsDeliveryPending(null), isTrue);
    expect(keepsDeliveryPending('unavailable'), isTrue);
    expect(keepsDeliveryPending('failed-precondition'), isTrue);
    expect(keepsDeliveryPending('internal'), isTrue);
  });

  test('başka hesaba bağlı veya iptal edilen satın alma beklemede kalmaz', () {
    expect(keepsDeliveryPending('permission-denied'), isFalse);
    expect(keepsDeliveryPending('invalid-argument'), isFalse);
    expect(keepsDeliveryPending('unauthenticated'), isFalse);
    expect(keepsDeliveryPending('cancelled'), isFalse);
  });

  test('teslimat kontrolü sonuçları ayrı ayrı sınıflanır', () {
    DeliveryRecheckOutcome classify({
      bool querySucceeded = true,
      int before = 1,
      int after = 0,
      int missing = 0,
      int pending = 0,
    }) {
      return classifyDeliveryRecheck(
        querySucceeded: querySucceeded,
        awaitingBefore: before,
        awaitingAfter: after,
        missingFromPlay: missing,
        pendingPayments: pending,
      );
    }

    expect(classify(), DeliveryRecheckOutcome.delivered);
    expect(classify(after: 1), DeliveryRecheckOutcome.stillPending);
    expect(classify(missing: 1), DeliveryRecheckOutcome.notInPlay);
    expect(
      classify(after: 1, pending: 1),
      DeliveryRecheckOutcome.paymentPending,
    );
    expect(
      classify(querySucceeded: false, after: 1),
      DeliveryRecheckOutcome.unavailable,
    );
    expect(classify(before: 2, missing: 1), DeliveryRecheckOutcome.delivered);
  });

  test(
    'Play listesinde görünmeyen teslimat önce önbellekteki tokenla sorulur',
    () {
      expect(
        missingPurchaseRecheckAction(hasCachedPurchase: true),
        MissingPurchaseRecheckAction.retryCachedPurchase,
      );
      expect(
        missingPurchaseRecheckAction(hasCachedPurchase: false),
        MissingPurchaseRecheckAction.closeAsNotInPlay,
      );
    },
  );

  test('satın alma callback sonucu hesap oturumları arasında taşınmaz', () {
    expect(
      purchaseCallbackBelongsToSession(
        callbackGeneration: 4,
        currentGeneration: 4,
        callbackUid: 'buyer-a',
        currentUid: 'buyer-a',
      ),
      isTrue,
    );
    expect(
      purchaseCallbackBelongsToSession(
        callbackGeneration: 4,
        currentGeneration: 5,
        callbackUid: 'buyer-a',
        currentUid: 'buyer-b',
      ),
      isFalse,
    );
    expect(
      purchaseCallbackBelongsToSession(
        callbackGeneration: 4,
        currentGeneration: 4,
        callbackUid: 'buyer-a',
        currentUid: 'buyer-b',
      ),
      isFalse,
    );
  });

  test('hediye eylemi yalnız ayrı ürün eşlemesi hazırsa açılır', () {
    expect(
      giftActionAvailable(
        enabled: true,
        giftProductId: 'dort_gift_badge_okey',
        purchaseBusy: false,
      ),
      isTrue,
    );
    expect(
      giftActionAvailable(
        enabled: true,
        giftProductId: '',
        purchaseBusy: false,
      ),
      isFalse,
    );
    expect(
      giftActionAvailable(
        enabled: false,
        giftProductId: 'dort_gift_badge_okey',
        purchaseBusy: false,
      ),
      isFalse,
    );
  });
}
