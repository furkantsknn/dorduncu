import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

/// The single standard base plan or Apple subscription product chosen for a
/// Plus purchase.
///
/// [formattedPrice] and [billingPeriod] come from the same store offer
/// submitted to Google Play or App Store.
class PlusSubscriptionSelection {
  const PlusSubscriptionSelection({
    required this.productDetails,
    required this.offerToken,
    required this.basePlanId,
    required this.formattedPrice,
    required this.billingPeriod,
    required this.periodLabel,
    this.offerId = '',
    this.discountedPeriodCount = 0,
    this.renewalFormattedPrice = '',
  });

  final ProductDetails productDetails;
  final String offerToken;
  final String basePlanId;
  final String formattedPrice;
  final String billingPeriod;
  final String periodLabel;
  final String offerId;
  final int discountedPeriodCount;
  final String renewalFormattedPrice;
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
  PlusSubscriptionSelection selection, {
  String? applicationUserName,
}) {
  final ProductDetails details = selection.productDetails;
  if (details is! GooglePlayProductDetails) {
    throw const PlusSubscriptionOfferException(
      'Seçilen teklifin Google Play ürün bilgisi okunamadı. Satın alma kapatıldı.',
      code: 'offer_unreadable',
    );
  }
  final String token = details.offerToken?.trim() ?? '';

  if (token.isEmpty || token != selection.offerToken) {
    throw const PlusSubscriptionOfferException(
      'Seçilen teklifin satın alma anahtarı okunamadı. Satın alma kapatıldı.',
      code: 'offer_unreadable',
    );
  }

  return GooglePlayPurchaseParam(
    productDetails: details,
    offerToken: selection.offerToken,
    applicationUserName: applicationUserName,
  );
}

/// Selects the configured Apple auto-renewable Plus subscription product from
/// StoreKit product details.
PlusSubscriptionSelection selectApplePlusProduct({
  required Iterable<ProductDetails> offers,
  required String appleProductId,
}) {
  final String productId = appleProductId.trim();
  if (productId.isEmpty) {
    throw const PlusSubscriptionOfferException(
      'App Store ürün eşlemesi henüz yapılmamış.',
      code: 'missing_product_id',
    );
  }

  final List<ProductDetails> matches = offers
      .where((ProductDetails item) => item.id.trim() == productId)
      .toList();

  if (matches.isEmpty) {
    throw const PlusSubscriptionOfferException(
      'Seçilen Plus aboneliği App Store üzerinde bulunamadı. '
      'Satın alma kapatıldı.',
      code: 'plan_not_found',
    );
  }

  if (matches.length != 1) {
    throw const PlusSubscriptionOfferException(
      'Aynı App Store ürünü için birden fazla teklif döndü. '
      'Satın alma kapatıldı.',
      code: 'ambiguous_plan',
    );
  }

  final ProductDetails selected = matches.single;
  final String price = selected.price.trim();
  if (price.isEmpty) {
    throw const PlusSubscriptionOfferException(
      'Seçilen aboneliğin App Store fiyatı okunamadı. Satın alma kapatıldı.',
      code: 'invalid_price',
    );
  }

  final String billingPeriod = _appleBillingPeriod(selected);
  return PlusSubscriptionSelection(
    productDetails: selected,
    offerToken: '',
    basePlanId: 'apple_subscription',
    formattedPrice: price,
    billingPeriod: billingPeriod,
    periodLabel: plusBillingPeriodLabel(billingPeriod),
  );
}

String _appleBillingPeriod(ProductDetails product) {
  if (product is AppStoreProduct2Details) {
    final SK2SubscriptionPeriod? period =
        product.sk2Product.subscription?.subscriptionPeriod;
    if (period != null && period.value > 0) {
      final String unit = switch (period.unit) {
        SK2SubscriptionPeriodUnit.day => 'D',
        SK2SubscriptionPeriodUnit.week => 'W',
        SK2SubscriptionPeriodUnit.month => 'M',
        SK2SubscriptionPeriodUnit.year => 'Y',
      };
      return 'P${period.value}$unit';
    }
  } else if (product is AppStoreProductDetails) {
    final SKProductSubscriptionPeriodWrapper? period =
        product.skProduct.subscriptionPeriod;
    if (period != null && period.numberOfUnits > 0) {
      final String unit = switch (period.unit) {
        SKSubscriptionPeriodUnit.day => 'D',
        SKSubscriptionPeriodUnit.week => 'W',
        SKSubscriptionPeriodUnit.month => 'M',
        SKSubscriptionPeriodUnit.year => 'Y',
      };
      return 'P${period.numberOfUnits}$unit';
    }
  }
  return 'P1M';
}

/// Selects either the standard base plan or one catalog campaign offer.
///
/// An unknown offer id is rejected. The selector never uses list position.
PlusSubscriptionSelection selectCatalogPlusOffer({
  required Iterable<ProductDetails> offers,
  required String googlePlayProductId,
  required String googlePlayBasePlanId,
  String campaignOfferId = '',
  int discountedPeriods = 0,
}) {
  final String expectedOfferId = campaignOfferId.trim();

  if (expectedOfferId.isEmpty) {
    return selectStandardPlusBasePlan(
      offers: offers,
      googlePlayProductId: googlePlayProductId,
      googlePlayBasePlanId: googlePlayBasePlanId,
    );
  }

  if (discountedPeriods < 1) {
    throw const PlusSubscriptionOfferException(
      'Plus kampanya dönem sayısı katalogda yok. Satın alma kapatıldı.',
      code: 'offer_unreadable',
    );
  }

  final List<GooglePlayProductDetails> matches = <GooglePlayProductDetails>[];

  for (final ProductDetails offer in offers) {
    if (offer is! GooglePlayProductDetails ||
        offer.id.trim() != googlePlayProductId.trim()) {
      continue;
    }

    final SubscriptionOfferDetailsWrapper? subscription = _subscriptionOffer(
      offer,
    );

    if (subscription == null) {
      continue;
    }

    if (subscription.basePlanId.trim() != googlePlayBasePlanId.trim()) {
      continue;
    }

    if ((subscription.offerId?.trim() ?? '') == expectedOfferId) {
      matches.add(offer);
    }
  }

  if (matches.length != 1) {
    throw const PlusSubscriptionOfferException(
      'Kampanya teklifi Google Play üzerinde yok veya birden fazla. '
      'İndirim gösterilmedi.',
      code: 'campaign_not_on_play',
    );
  }

  final GooglePlayProductDetails selected = matches.single;
  final SubscriptionOfferDetailsWrapper subscription = _subscriptionOffer(
    selected,
  )!;
  final List<PricingPhaseWrapper> phases = subscription.pricingPhases;

  if (phases.length < 2 ||
      phases.first.recurrenceMode != RecurrenceMode.finiteRecurring ||
      phases.first.billingCycleCount != discountedPeriods ||
      phases.first.billingPeriod.trim() != 'P1M' ||
      phases.last.recurrenceMode != RecurrenceMode.infiniteRecurring) {
    throw const PlusSubscriptionOfferException(
      'Plus kampanya teklifinin indirimli dönemi veya yenileme fiyatı '
      'Play yanıtında doğrulanamadı.',
      code: 'invalid_price',
    );
  }

  final String token = selected.offerToken?.trim() ?? '';
  final String price = phases.first.formattedPrice.trim();
  final String renewal = phases.last.formattedPrice.trim();

  if (token.isEmpty ||
      token != subscription.offerIdToken ||
      price.isEmpty ||
      renewal.isEmpty ||
      selected.price != phases.first.formattedPrice) {
    throw const PlusSubscriptionOfferException(
      'Kampanya teklifinin satın alma anahtarı fiyatla eşleşmiyor.',
      code: 'invalid_price',
    );
  }

  return PlusSubscriptionSelection(
    productDetails: selected,
    offerToken: token,
    basePlanId: googlePlayBasePlanId.trim(),
    formattedPrice: price,
    billingPeriod: phases.first.billingPeriod.trim(),
    periodLabel: plusBillingPeriodLabel(phases.first.billingPeriod),
    offerId: expectedOfferId,
    discountedPeriodCount: discountedPeriods,
    renewalFormattedPrice: renewal,
  );
}

bool samePlusOffer(
  PlusSubscriptionSelection left,
  PlusSubscriptionSelection right,
) {
  return left.productDetails.id == right.productDetails.id &&
      left.basePlanId == right.basePlanId &&
      left.offerId == right.offerId &&
      left.offerToken == right.offerToken &&
      left.formattedPrice == right.formattedPrice &&
      left.renewalFormattedPrice == right.renewalFormattedPrice &&
      left.billingPeriod == right.billingPeriod;
}

String plusBillingPeriodLabel(
  String billingPeriod, {
  String languageCode = 'tr',
}) {
  final String code = languageCode.toLowerCase();
  String text(String tr, String en, String de) {
    switch (code) {
      case 'en':
        return en;
      case 'de':
        return de;
      default:
        return tr;
    }
  }

  switch (billingPeriod.trim()) {
    case 'P1W':
      return text('Haftalık', 'Weekly', 'Wöchentlich');
    case 'P1M':
      return text('Aylık', 'Monthly', 'Monatlich');
    case 'P3M':
      return text('3 aylık', '3 months', '3 Monate');
    case 'P6M':
      return text('6 aylık', '6 months', '6 Monate');
    case 'P1Y':
      return text('Yıllık', 'Yearly', 'Jährlich');
    default:
      return '';
  }
}

String plusPricePeriodSuffix(
  String billingPeriod, {
  String languageCode = 'tr',
}) {
  if (billingPeriod.trim() != 'P1M') {
    return '';
  }

  switch (languageCode.toLowerCase()) {
    case 'en':
      return '/month';
    case 'de':
      return '/Monat';
    default:
      return '/ay';
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
