import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// The single standard base plan chosen for a Plus purchase.
///
/// [formattedPrice] and [billingPeriod] come from the same subscription offer
/// whose [offerToken] is sent to Google Play.
class PlusSubscriptionSelection {
  const PlusSubscriptionSelection({
    required this.productDetails,
    required this.offerToken,
    required this.basePlanId,
    required this.formattedPrice,
    required this.billingPeriod,
    required this.periodLabel,
  });

  final GooglePlayProductDetails productDetails;
  final String offerToken;
  final String basePlanId;
  final String formattedPrice;
  final String billingPeriod;
  final String periodLabel;
}

class PlusSubscriptionOfferException implements Exception {
  const PlusSubscriptionOfferException(this.message, {required this.code});

  final String message;
  final String code;

  @override
  String toString() => message;
}

/// Selects the configured base plan's regular offer.
///
/// Promotional offers have a non-empty [SubscriptionOfferDetailsWrapper.offerId]
/// and are ignored. The choice does not use list position. Zero or more than
/// one matching standard offer closes the purchase.
PlusSubscriptionSelection selectStandardPlusBasePlan({
  required Iterable<ProductDetails> offers,
  required String googlePlayProductId,
  required String googlePlayBasePlanId,
}) {
  final String productId = googlePlayProductId.trim();
  final String basePlanId = googlePlayBasePlanId.trim();

  if (productId.isEmpty) {
    throw const PlusSubscriptionOfferException(
      'Google Play ürün eşlemesi henüz yapılmamış.',
      code: 'missing_product_id',
    );
  }

  if (basePlanId.isEmpty) {
    throw const PlusSubscriptionOfferException(
      'Plus base plan eşlemesi henüz yapılmamış.',
      code: 'missing_base_plan',
    );
  }

  final List<GooglePlayProductDetails> playOffers =
      <GooglePlayProductDetails>[];
  var sawUnreadableOffer = false;

  for (final ProductDetails offer in offers) {
    if (offer.id.trim() != productId) {
      continue;
    }

    if (offer is! GooglePlayProductDetails) {
      sawUnreadableOffer = true;
      continue;
    }

    playOffers.add(offer);
  }

  if (playOffers.isEmpty) {
    throw PlusSubscriptionOfferException(
      sawUnreadableOffer
          ? 'Plus abonelik teklifi okunamadı. Satın alma kapatıldı.'
          : 'Seçilen Plus base planı Google Play üzerinde bulunamadı. '
                'Satın alma kapatıldı.',
      code: sawUnreadableOffer ? 'offer_unreadable' : 'plan_not_found',
    );
  }

  final List<GooglePlayProductDetails> standardOffers =
      <GooglePlayProductDetails>[];
  var sawPromotionalOffer = false;

  for (final GooglePlayProductDetails offer in playOffers) {
    final SubscriptionOfferDetailsWrapper? subscription = _subscriptionOffer(
      offer,
    );

    if (subscription == null) {
      throw const PlusSubscriptionOfferException(
        'Plus abonelik teklifi okunamadı. Satın alma kapatıldı.',
        code: 'offer_unreadable',
      );
    }

    if (subscription.basePlanId.trim() != basePlanId) {
      continue;
    }

    final String promotionalOfferId = subscription.offerId?.trim() ?? '';

    if (promotionalOfferId.isNotEmpty) {
      sawPromotionalOffer = true;
      continue;
    }

    standardOffers.add(offer);
  }

  if (standardOffers.isEmpty) {
    throw PlusSubscriptionOfferException(
      sawPromotionalOffer
          ? 'Seçilen base planın promosyon olmayan standart teklifi '
                'bulunamadı. Satın alma kapatıldı.'
          : 'Seçilen Plus base planı Google Play üzerinde bulunamadı. '
                'Satın alma kapatıldı.',
      code: 'plan_not_found',
    );
  }

  if (standardOffers.length != 1) {
    throw const PlusSubscriptionOfferException(
      'Aynı base plan için birden fazla standart teklif var. '
      'Satın alma kapatıldı.',
      code: 'ambiguous_plan',
    );
  }

  final GooglePlayProductDetails selected = standardOffers.single;
  final SubscriptionOfferDetailsWrapper subscription = _subscriptionOffer(
    selected,
  )!;

  return _selectionFrom(
    product: selected,
    subscription: subscription,
    basePlanId: basePlanId,
  );
}

/// Builds the Play purchase param from the offer already chosen for display.
GooglePlayPurchaseParam purchaseParamForSelectedPlusOffer(
  PlusSubscriptionSelection selection,
) {
  final String token = selection.productDetails.offerToken?.trim() ?? '';

  if (token.isEmpty || token != selection.offerToken) {
    throw const PlusSubscriptionOfferException(
      'Seçilen teklifin satın alma anahtarı okunamadı. Satın alma kapatıldı.',
      code: 'offer_unreadable',
    );
  }

  return GooglePlayPurchaseParam(
    productDetails: selection.productDetails,
    offerToken: selection.offerToken,
  );
}

bool samePlusOffer(
  PlusSubscriptionSelection left,
  PlusSubscriptionSelection right,
) {
  return left.productDetails.id == right.productDetails.id &&
      left.basePlanId == right.basePlanId &&
      left.offerToken == right.offerToken &&
      left.formattedPrice == right.formattedPrice &&
      left.billingPeriod == right.billingPeriod;
}

String plusBillingPeriodLabel(String billingPeriod) {
  switch (billingPeriod.trim()) {
    case 'P1W':
      return 'Haftalık (P1W)';
    case 'P1M':
      return 'Aylık (P1M)';
    case 'P3M':
      return '3 aylık (P3M)';
    case 'P6M':
      return '6 aylık (P6M)';
    case 'P1Y':
      return 'Yıllık (P1Y)';
    default:
      return billingPeriod.trim();
  }
}

SubscriptionOfferDetailsWrapper? _subscriptionOffer(
  GooglePlayProductDetails offer,
) {
  final int? index = offer.subscriptionIndex;
  final List<SubscriptionOfferDetailsWrapper>? details =
      offer.productDetails.subscriptionOfferDetails;

  if (index == null ||
      details == null ||
      index < 0 ||
      index >= details.length) {
    return null;
  }

  return details[index];
}

PlusSubscriptionSelection _selectionFrom({
  required GooglePlayProductDetails product,
  required SubscriptionOfferDetailsWrapper subscription,
  required String basePlanId,
}) {
  final List<PricingPhaseWrapper> phases = subscription.pricingPhases;

  if (phases.length != 1 ||
      phases.single.recurrenceMode != RecurrenceMode.infiniteRecurring) {
    throw const PlusSubscriptionOfferException(
      'Seçilen base planın yenilenen fiyat dönemi belirsiz. '
      'Satın alma kapatıldı.',
      code: 'invalid_price',
    );
  }

  final PricingPhaseWrapper phase = phases.single;
  final String price = phase.formattedPrice.trim();
  final String period = phase.billingPeriod.trim();
  final String token = product.offerToken?.trim() ?? '';

  if (price.isEmpty ||
      period.isEmpty ||
      product.price != phase.formattedPrice ||
      token.isEmpty ||
      token != subscription.offerIdToken) {
    throw const PlusSubscriptionOfferException(
      'Seçilen teklifin fiyatı okunamadı. Satın alma kapatıldı.',
      code: 'invalid_price',
    );
  }

  return PlusSubscriptionSelection(
    productDetails: product,
    offerToken: token,
    basePlanId: basePlanId,
    formattedPrice: price,
    billingPeriod: period,
    periodLabel: plusBillingPeriodLabel(period),
  );
}
