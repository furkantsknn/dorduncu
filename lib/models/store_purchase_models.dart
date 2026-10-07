import 'package:in_app_purchase/in_app_purchase.dart';

enum StorePurchaseKind {
  plusSubscription,
  badgeNonConsumable,
}

class StoreProductRequest {
  const StoreProductRequest({
    required this.productId,
    required this.kind,
  });

  final String productId;
  final StorePurchaseKind kind;
}

class StorePurchaseEnvelope {
  const StorePurchaseEnvelope({
    required this.productId,
    required this.purchaseToken,
    required this.status,
    required this.pendingCompletePurchase,
    required this.transactionDate,
  });

  factory StorePurchaseEnvelope.fromPurchaseDetails(
    PurchaseDetails details,
  ) {
    return StorePurchaseEnvelope(
      productId: details.productID,
      purchaseToken:
          details.verificationData.serverVerificationData.trim(),
      status: details.status,
      pendingCompletePurchase: details.pendingCompletePurchase,
      transactionDate: details.transactionDate,
    );
  }

  final String productId;
  final String purchaseToken;
  final PurchaseStatus status;
  final bool pendingCompletePurchase;
  final String? transactionDate;

  bool get requiresServerVerification =>
      status == PurchaseStatus.purchased ||
      status == PurchaseStatus.restored;

  bool get isPending => status == PurchaseStatus.pending;

  bool get hasVerificationToken => purchaseToken.isNotEmpty;
}
