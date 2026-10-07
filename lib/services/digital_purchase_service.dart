import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'plus_subscription_offer.dart';
import 'purchase_analytics.dart';
import 'store_billing_service.dart';

enum DigitalStoreProductKind { plusSubscription, badgeNonConsumable }

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

class DigitalPurchaseService {
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

  bool _started = false;
  bool _sessionAttached = false;
  int _sessionGeneration = 0;

  /// Starts the single Play purchase stream for the signed-in session and
  /// replays purchases that were not acknowledged before the process died.
  Future<void> attachSession() async {
    if (_sessionAttached) {
      return;
    }

    _sessionAttached = true;
    final int generation = ++_sessionGeneration;
    await start();

    if (!_sessionAttached || generation != _sessionGeneration) {
      return;
    }

    try {
      await _billing.restorePurchases();
    } catch (_) {
      // Billing can be unavailable at launch. The next signed-in session retries.
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
    _started = false;
    await _billing.stop();
  }

  Future<String> loadLocalizedPrice(String googlePlayProductId) async {
    final ProductDetails product = await _loadProduct(googlePlayProductId);
    return product.price;
  }

  /// Returns Play formatted prices for the products the store can resolve.
  /// Missing or unavailable products are omitted so the caller can keep the
  /// catalog price.
  Future<Map<String, String>> loadLocalizedPrices(
    Iterable<String> productIds,
  ) async {
    try {
      final Map<String, ProductDetails> products = await _billing.loadProducts(
        productIds,
      );

      return <String, String>{
        for (final MapEntry<String, ProductDetails> entry in products.entries)
          if (entry.value.price.trim().isNotEmpty)
            entry.key: entry.value.price.trim(),
      };
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> restorePurchases() async {
    await start();
    await _billing.restorePurchases();
  }

  /// Resolves the standard base plan for the price shown before purchase.
  Future<PlusSubscriptionSelection> loadPlusSelection({
    required String googlePlayProductId,
    required String googlePlayBasePlanId,
  }) async {
    final String storeId = googlePlayProductId.trim();
    final List<ProductDetails> products = await _billing.queryProducts(<String>[
      storeId,
    ]);

    return selectStandardPlusBasePlan(
      offers: products,
      googlePlayProductId: storeId,
      googlePlayBasePlanId: googlePlayBasePlanId,
    );
  }

  Future<DigitalPurchaseResult> purchase({
    required String googlePlayProductId,
    required DigitalStoreProductKind kind,
    String? internalProductId,
    String? recipientUid,
    String? googlePlayBasePlanId,
    PlusSubscriptionSelection? plusSelection,
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
      throw const DigitalPurchaseException(
        'Google Play ürün eşlemesi henüz yapılmamış.',
      );
    }

    await PurchaseAnalytics.log(
      name: '${eventPrefix}_started',
      googlePlayProductId: storeId,
      internalProductId: internalProductId,
    );

    await start();

    if (_pending.containsKey(storeId)) {
      await PurchaseAnalytics.log(
        name: '${eventPrefix}_failed',
        googlePlayProductId: storeId,
        internalProductId: internalProductId,
        errorCode: 'in_progress',
      );
      throw const DigitalPurchaseException(
        'Bu ürün için satın alma işlemi zaten devam ediyor.',
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

    try {
      switch (kind) {
        case DigitalStoreProductKind.plusSubscription:
          await _billing.buySubscription(plusOffer!);
          break;
        case DigitalStoreProductKind.badgeNonConsumable:
          await _billing.buyNonConsumable(badgeProduct!);
          break;
      }
    } catch (error) {
      _releasePending(storeId);

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

    try {
      final DigitalPurchaseResult result = await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          _releasePending(storeId);

          throw const DigitalPurchaseException(
            'Google Play satın alma sonucu bekleniyor. '
            'İşlem tamamlanırsa hesabına otomatik yansıyacak.',
          );
        },
      );
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

    final PlusSubscriptionSelection selected = await loadPlusSelection(
      googlePlayProductId: storeId,
      googlePlayBasePlanId: googlePlayBasePlanId ?? '',
    );

    if (!samePlusOffer(displayed, selected) ||
        displayed.productDetails.id != storeId) {
      throw const PlusSubscriptionOfferException(
        'Google Play teklifi değişti. Ekrandaki fiyat güncellenmeden '
        'satın alma başlatılmadı.',
        code: 'offer_changed',
      );
    }

    return selected;
  }

  Future<ProductDetails> _loadProduct(String googlePlayProductId) async {
    final String storeId = googlePlayProductId.trim();

    if (storeId.isEmpty) {
      throw const DigitalPurchaseException(
        'Google Play ürün eşlemesi henüz yapılmamış.',
      );
    }

    final Map<String, ProductDetails> products = await _billing.loadProducts(
      <String>[storeId],
    );

    final ProductDetails? product = products[storeId];

    if (product == null) {
      throw const DigitalPurchaseException(
        'Ürün Google Play üzerinde bulunamadı.',
      );
    }

    return product;
  }

  Future<void> _handlePurchaseUpdate(PurchaseDetails purchase) async {
    final String storeId = purchase.productID.trim();
    final Completer<DigitalPurchaseResult>? completer = _pending[storeId];

    // Play has not finished. Keep the local lock so the button stays busy,
    // but do not treat this as a failed attempt.
    if (purchase.status == PurchaseStatus.pending) {
      return;
    }

    final bool terminal =
        purchase.status == PurchaseStatus.canceled ||
        purchase.status == PurchaseStatus.error ||
        purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored;

    try {
      if (purchase.status == PurchaseStatus.canceled) {
        if (completer != null && !completer.isCompleted) {
          completer.completeError(
            const DigitalPurchaseException('Satın alma işlemi iptal edildi.'),
          );
        }

        return;
      }

      if (purchase.status == PurchaseStatus.error) {
        if (completer != null && !completer.isCompleted) {
          completer.completeError(
            DigitalPurchaseException(
              purchase.error?.message ??
                  'Google Play satın alma işlemi tamamlanamadı.',
            ),
          );
        }

        return;
      }

      if (purchase.status != PurchaseStatus.purchased &&
          purchase.status != PurchaseStatus.restored) {
        return;
      }

      final String purchaseToken = purchase
          .verificationData
          .serverVerificationData
          .trim();

      if (purchaseToken.isEmpty) {
        if (completer != null && !completer.isCompleted) {
          completer.completeError(
            const DigitalPurchaseException(
              'Google Play doğrulama bilgisi alınamadı.',
            ),
          );
        }

        return;
      }

      final HttpsCallable callable = _functions.httpsCallable(
        'fulfillGooglePlayPurchase',
      );

      final Map<String, dynamic> payload = <String, dynamic>{
        'googlePlayProductId': storeId,
        'purchaseToken': purchaseToken,
      };
      final String? giftRecipient = _giftRecipients[storeId];
      if (giftRecipient != null && giftRecipient.isNotEmpty) {
        payload['recipientUid'] = giftRecipient;
      }

      final HttpsCallableResult<dynamic> response = await callable.call(
        payload,
      );

      final dynamic rawData = response.data;

      if (rawData is! Map) {
        throw const DigitalPurchaseException(
          'Satın alma doğrulama sonucu okunamadı.',
        );
      }

      final bool success = rawData['success'] == true;

      if (!success) {
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

      await _billing.completeAfterServerVerification(purchase);

      if (completer != null && !completer.isCompleted) {
        completer.complete(result);
      }
    } on FirebaseFunctionsException catch (error) {
      if (completer != null && !completer.isCompleted) {
        completer.completeError(
          DigitalPurchaseException(
            error.message ?? 'Google Play satın alma doğrulanamadı.',
          ),
        );
      }
    } catch (error) {
      if (completer != null && !completer.isCompleted) {
        completer.completeError(error);
      }
    } finally {
      if (terminal) {
        _releasePending(storeId);
      }
    }
  }

  void _releasePending(String storeId) {
    _pending.remove(storeId);
    _giftRecipients.remove(storeId);
  }
}

class DigitalPurchaseException implements Exception {
  const DigitalPurchaseException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}
