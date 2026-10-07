import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'plus_subscription_offer.dart';

typedef StorePurchaseHandler = Future<void> Function(PurchaseDetails details);

class StoreBillingService {
  StoreBillingService({InAppPurchase? inAppPurchase})
    : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  final InAppPurchase _inAppPurchase;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  StorePurchaseHandler? _purchaseHandler;

  bool _started = false;

  Future<bool> isAvailable() {
    return _inAppPurchase.isAvailable();
  }

  Future<void> start({required StorePurchaseHandler onPurchase}) async {
    _purchaseHandler = onPurchase;

    if (_started) {
      return;
    }

    _started = true;

    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        // PurchaseDetails errors are handled per purchase below.
        // A stream-level transport error must not grant entitlement.
      },
    );
  }

  Future<void> stop() async {
    await _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    _purchaseHandler = null;
    _started = false;
  }

  /// Returns every Play offer. Subscription product ids are not collapsed.
  Future<List<ProductDetails>> queryProducts(
    Iterable<String> productIds,
  ) async {
    final Set<String> ids = productIds
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toSet();

    if (ids.isEmpty) {
      return <ProductDetails>[];
    }

    final bool available = await isAvailable();

    if (!available) {
      throw const StoreBillingException(
        'Google Play satın alma servisi kullanılamıyor.',
      );
    }

    final ProductDetailsResponse response = await _inAppPurchase
        .queryProductDetails(ids);

    if (response.error != null) {
      throw StoreBillingException(
        response.error!.message,
        code: response.error!.code,
      );
    }

    return response.productDetails;
  }

  /// One-time products are keyed by id. Do not use this for Plus subscriptions:
  /// several base plans share one product id and a map keeps only one of them.
  Future<Map<String, ProductDetails>> loadProducts(
    Iterable<String> productIds,
  ) async {
    final List<ProductDetails> products = await queryProducts(productIds);

    return <String, ProductDetails>{
      for (final ProductDetails product in products) product.id: product,
    };
  }

  Future<void> buyNonConsumable(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);

    final bool started = await _inAppPurchase.buyNonConsumable(
      purchaseParam: purchaseParam,
    );

    if (!started) {
      throw const StoreBillingException(
        'Google Play satın alma ekranı başlatılamadı.',
      );
    }
  }

  Future<void> buySubscription(PlusSubscriptionSelection selection) async {
    final GooglePlayPurchaseParam purchaseParam =
        purchaseParamForSelectedPlusOffer(selection);

    final bool started = await _inAppPurchase.buyNonConsumable(
      purchaseParam: purchaseParam,
    );

    if (!started) {
      throw const StoreBillingException(
        'Google Play satın alma ekranı başlatılamadı.',
      );
    }
  }

  Future<void> restorePurchases() async {
    final bool available = await isAvailable();

    if (!available) {
      throw const StoreBillingException(
        'Google Play satın alma servisi kullanılamıyor.',
      );
    }

    await _inAppPurchase.restorePurchases();
  }

  Future<void> completeAfterServerVerification(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) {
      return;
    }

    await _inAppPurchase.completePurchase(purchase);
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    final StorePurchaseHandler? handler = _purchaseHandler;

    if (handler == null) {
      return;
    }

    for (final PurchaseDetails purchase in purchases) {
      await handler(purchase);
    }
  }
}

class StoreBillingException implements Exception {
  const StoreBillingException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}
