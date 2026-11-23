import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

import 'plus_subscription_offer.dart';

typedef StorePurchaseHandler = Future<void> Function(PurchaseDetails details);

class StoreBillingService {
  StoreBillingService({InAppPurchase? inAppPurchase})
    : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  final InAppPurchase _inAppPurchase;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  StorePurchaseHandler? _purchaseHandler;

  bool _started = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  String get _storeName => _isIOS ? 'App Store' : 'Google Play';

  Future<bool> isAvailable() {
    if (const String.fromEnvironment('DORT_ENV') == 'development') {
      return Future<bool>.value(true);
    }
    if (!_isAndroid && !_isIOS) {
      return Future<bool>.value(false);
    }
    return _inAppPurchase.isAvailable();
  }

  Future<void> start({required StorePurchaseHandler onPurchase}) async {
    _purchaseHandler = onPurchase;
    if (const String.fromEnvironment('DORT_ENV') == 'development') return;

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

  /// Returns every store offer. Subscription product ids are not collapsed.
  Future<List<ProductDetails>> queryProducts(
    Iterable<String> productIds,
  ) async {
    if (const String.fromEnvironment('DORT_ENV') == 'development') {
      final docs = await FirebaseFirestore.instance
          .collection('dev_store_products')
          .get();
      final ids = productIds.toSet();
      return docs.docs
          .where((d) => ids.contains(d.id) && d.data()['available'] == true)
          .map(
            (d) => ProductDetails(
              id: d.id,
              title: d.data()['title']?.toString() ?? 'Dev',
              description: 'Dev simulation',
              price: '${d.data()['price']} (Dev)',
              rawPrice: (d.data()['rawPrice'] as num).toDouble(),
              currencyCode: 'TRY',
            ),
          )
          .toList();
    }
    _requireSupportedStore();
    final Set<String> ids = productIds
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toSet();

    if (ids.isEmpty) {
      return <ProductDetails>[];
    }

    final bool available = await isAvailable();

    if (!available) {
      throw StoreBillingException(
        '$_storeName satın alma servisi kullanılamıyor.',
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

  /// One-time products are keyed by id. Do not use this for Android Plus
  /// subscriptions: several base plans share one product id.
  Future<Map<String, ProductDetails>> loadProducts(
    Iterable<String> productIds,
  ) async {
    final List<ProductDetails> products = await queryProducts(productIds);

    return <String, ProductDetails>{
      for (final ProductDetails product in products) product.id: product,
    };
  }

  Future<void> buyNonConsumable(
    ProductDetails product, {
    String? offerToken,
    String? accountId,
  }) async {
    if (const String.fromEnvironment('DORT_ENV') == 'development') {
      throw const StoreBillingException(
        'Dev simülasyonu: gerçek ödeme kapalı.',
      );
    }
    _requireSupportedStore();

    final PurchaseParam purchaseParam = _isAndroid
        ? GooglePlayPurchaseParam(
            productDetails: product,
            offerToken: offerToken,
            applicationUserName: accountId,
          )
        : PurchaseParam(
            productDetails: product,
            applicationUserName: accountId,
          );

    final bool started = await _inAppPurchase.buyNonConsumable(
      purchaseParam: purchaseParam,
    );

    if (!started) {
      throw StoreBillingException(
        '$_storeName satın alma ekranı başlatılamadı.',
      );
    }
  }

  Future<void> buySubscription(
    PlusSubscriptionSelection selection, {
    String? accountId,
  }) async {
    _requireSupportedStore();
    final PurchaseParam purchaseParam = _isAndroid
        ? purchaseParamForSelectedPlusOffer(
            selection,
            applicationUserName: accountId,
          )
        : PurchaseParam(
            productDetails: selection.productDetails,
            applicationUserName: accountId,
          );

    final bool started = await _inAppPurchase.buyNonConsumable(
      purchaseParam: purchaseParam,
    );

    if (!started) {
      throw StoreBillingException(
        '$_storeName satın alma ekranı başlatılamadı.',
      );
    }
  }

  /// Reads current store purchases without opening a payment sheet.
  ///
  /// On Android queries Google Play Billing past purchases.
  /// On iOS queries StoreKit 2 signed transactions (`Transaction.all`).
  Future<PastPurchaseQuery> queryPastPurchases() async {
    if (const String.fromEnvironment('DORT_ENV') == 'development') {
      return const PastPurchaseQuery.ok(<PurchaseDetails>[]);
    }
    if (_isAndroid) {
      try {
        final InAppPurchaseAndroidPlatformAddition addition = _inAppPurchase
            .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
        final QueryPurchaseDetailsResponse response = await addition
            .queryPastPurchases();
        if (response.error != null) {
          return const PastPurchaseQuery.failed();
        }
        return PastPurchaseQuery.ok(response.pastPurchases);
      } catch (_) {
        return const PastPurchaseQuery.failed();
      }
    }
    if (_isIOS) {
      try {
        final List<SK2Transaction> transactions =
            await SK2Transaction.transactions();
        final List<PurchaseDetails> details = <PurchaseDetails>[];
        for (final SK2Transaction tx in transactions) {
          final String jws = tx.receiptData?.trim() ?? '';
          if (jws.isEmpty) {
            continue;
          }
          details.add(
            SK2PurchaseDetails(
              productID: tx.productId,
              purchaseID: tx.id,
              verificationData: PurchaseVerificationData(
                localVerificationData: tx.jsonRepresentation ?? '',
                serverVerificationData: jws,
                source: 'app_store',
              ),
              transactionDate: tx.purchaseDate,
              status: PurchaseStatus.restored,
              appAccountToken: tx.appAccountToken,
            ),
          );
        }
        return PastPurchaseQuery.ok(details);
      } catch (_) {
        return const PastPurchaseQuery.failed();
      }
    }
    return const PastPurchaseQuery.failed();
  }

  Future<void> restorePurchases() async {
    _requireSupportedStore();
    final bool available = await isAvailable();

    if (!available) {
      throw StoreBillingException(
        '$_storeName satın alma servisi kullanılamıyor.',
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

  void _requireSupportedStore() {
    if (const String.fromEnvironment('DORT_ENV') == 'development') {
      throw const StoreBillingException(
        'Dev simülasyonu: gerçek mağaza işlemleri kapalı.',
      );
    }
    if (!_isAndroid && !_isIOS) {
      throw const StoreBillingException(
        'Bu platformda uygulama içi satın alma desteklenmiyor.',
        code: 'unsupported-store-platform',
      );
    }
  }
}

class PastPurchaseQuery {
  const PastPurchaseQuery.ok(this.purchases) : succeeded = true;

  const PastPurchaseQuery.failed()
    : succeeded = false,
      purchases = const <PurchaseDetails>[];

  final bool succeeded;
  final List<PurchaseDetails> purchases;
}

class StoreBillingException implements Exception {
  const StoreBillingException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}
