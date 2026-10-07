import 'package:dorduncu/services/plus_subscription_offer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

void main() {
  const String productId = 'dort_plus';
  const String monthlyPlan = 'plus-monthly';

  test('birden fazla teklifte standart base plan seçilir', () {
    final List<GooglePlayProductDetails> offers = _offers(
      productId: productId,
      subscriptions: <SubscriptionOfferDetailsWrapper>[
        _subscription(
          basePlanId: 'plus-yearly',
          token: 'token-yearly',
          price: '₺399,99',
          period: 'P1Y',
        ),
        _subscription(
          basePlanId: monthlyPlan,
          offerId: 'intro-month',
          token: 'token-promo',
          price: '₺9,99',
        ),
        _subscription(
          basePlanId: monthlyPlan,
          token: 'token-standard',
          price: '₺49,99',
        ),
      ],
    );

    final PlusSubscriptionSelection selection = selectStandardPlusBasePlan(
      offers: offers,
      googlePlayProductId: productId,
      googlePlayBasePlanId: monthlyPlan,
    );

    expect(selection.offerToken, 'token-standard');
    expect(selection.formattedPrice, '₺49,99');
    expect(selection.billingPeriod, 'P1M');
    expect(selection.periodLabel, 'Aylık (P1M)');
    expect(selection.productDetails.price, '₺49,99');
    expect(selection.productDetails.offerToken, selection.offerToken);

    final GooglePlayPurchaseParam param = purchaseParamForSelectedPlusOffer(
      selection,
    );
    expect(param.offerToken, 'token-standard');
    expect(identical(param.productDetails, selection.productDetails), isTrue);
  });

  test('liste sırası değişince aynı teklif seçilir', () {
    final List<SubscriptionOfferDetailsWrapper> subscriptions =
        <SubscriptionOfferDetailsWrapper>[
          _subscription(
            basePlanId: monthlyPlan,
            offerId: 'intro-month',
            token: 'token-promo',
            price: '₺9,99',
          ),
          _subscription(
            basePlanId: monthlyPlan,
            token: 'token-standard',
            price: '₺49,99',
          ),
          _subscription(
            basePlanId: 'plus-yearly',
            token: 'token-yearly',
            price: '₺399,99',
            period: 'P1Y',
          ),
        ];

    final PlusSubscriptionSelection forward = selectStandardPlusBasePlan(
      offers: _offers(productId: productId, subscriptions: subscriptions),
      googlePlayProductId: productId,
      googlePlayBasePlanId: monthlyPlan,
    );
    final PlusSubscriptionSelection reversed = selectStandardPlusBasePlan(
      offers: _offers(
        productId: productId,
        subscriptions: subscriptions.reversed.toList(),
      ),
      googlePlayProductId: productId,
      googlePlayBasePlanId: monthlyPlan,
    );

    expect(forward.offerToken, 'token-standard');
    expect(reversed.offerToken, forward.offerToken);
    expect(reversed.formattedPrice, forward.formattedPrice);
    expect(reversed.billingPeriod, forward.billingPeriod);
    expect(
      _collapsedPrice(
        _offers(productId: productId, subscriptions: subscriptions),
      ),
      isNot(forward.formattedPrice),
    );
    expect(
      _collapsedPrice(
        _offers(
          productId: productId,
          subscriptions: subscriptions.reversed.toList(),
        ),
      ),
      '₺9,99',
    );
  });

  test('hedef plan yoksa başka plana düşmez', () {
    final List<GooglePlayProductDetails> offers = _offers(
      productId: productId,
      subscriptions: <SubscriptionOfferDetailsWrapper>[
        _subscription(
          basePlanId: 'plus-yearly',
          token: 'token-yearly',
          price: '₺399,99',
          period: 'P1Y',
        ),
        _subscription(
          basePlanId: monthlyPlan,
          offerId: 'intro-month',
          token: 'token-promo',
          price: '₺9,99',
        ),
      ],
    );

    expect(
      () => selectStandardPlusBasePlan(
        offers: offers,
        googlePlayProductId: productId,
        googlePlayBasePlanId: 'plus-missing',
      ),
      throwsA(
        isA<PlusSubscriptionOfferException>().having(
          (PlusSubscriptionOfferException error) => error.code,
          'code',
          'plan_not_found',
        ),
      ),
    );
    expect(
      () => selectStandardPlusBasePlan(
        offers: offers,
        googlePlayProductId: productId,
        googlePlayBasePlanId: monthlyPlan,
      ),
      throwsA(
        isA<PlusSubscriptionOfferException>().having(
          (PlusSubscriptionOfferException error) => error.code,
          'code',
          'plan_not_found',
        ),
      ),
    );
  });

  test('aynı base planın birden fazla standart teklifi belirsizdir', () {
    final List<GooglePlayProductDetails> offers = _offers(
      productId: productId,
      subscriptions: <SubscriptionOfferDetailsWrapper>[
        _subscription(
          basePlanId: monthlyPlan,
          token: 'token-a',
          price: '₺49,99',
        ),
        _subscription(
          basePlanId: monthlyPlan,
          token: 'token-b',
          price: '₺59,99',
        ),
      ],
    );

    expect(
      () => selectStandardPlusBasePlan(
        offers: offers.reversed.toList(),
        googlePlayProductId: productId,
        googlePlayBasePlanId: monthlyPlan,
      ),
      throwsA(
        isA<PlusSubscriptionOfferException>().having(
          (PlusSubscriptionOfferException error) => error.code,
          'code',
          'ambiguous_plan',
        ),
      ),
    );
  });

  test('birden fazla fiyat dönemi olan standart teklif kapanır', () {
    final List<GooglePlayProductDetails> offers = _offers(
      productId: productId,
      subscriptions: <SubscriptionOfferDetailsWrapper>[
        _subscription(
          basePlanId: monthlyPlan,
          token: 'token-phased',
          price: '₺0,00',
          phases: <PricingPhaseWrapper>[
            _phase(price: '₺0,00', mode: RecurrenceMode.finiteRecurring),
            _phase(price: '₺49,99'),
          ],
        ),
      ],
    );

    expect(
      () => selectStandardPlusBasePlan(
        offers: offers,
        googlePlayProductId: productId,
        googlePlayBasePlanId: monthlyPlan,
      ),
      throwsA(
        isA<PlusSubscriptionOfferException>().having(
          (PlusSubscriptionOfferException error) => error.code,
          'code',
          'invalid_price',
        ),
      ),
    );
  });

  test('okunamayan ürün detayı son eleman olsa da seçilmez', () {
    final List<ProductDetails> offers = <ProductDetails>[
      ProductDetails(
        id: productId,
        title: 'Plus',
        description: 'Plus',
        price: '₺1,00',
        rawPrice: 1,
        currencyCode: 'TRY',
      ),
    ];

    expect(
      () => selectStandardPlusBasePlan(
        offers: offers,
        googlePlayProductId: productId,
        googlePlayBasePlanId: monthlyPlan,
      ),
      throwsA(
        isA<PlusSubscriptionOfferException>().having(
          (PlusSubscriptionOfferException error) => error.code,
          'code',
          'offer_unreadable',
        ),
      ),
    );
    expect(
      () => selectStandardPlusBasePlan(
        offers: offers,
        googlePlayProductId: productId,
        googlePlayBasePlanId: '',
      ),
      throwsA(
        isA<PlusSubscriptionOfferException>().having(
          (PlusSubscriptionOfferException error) => error.code,
          'code',
          'missing_base_plan',
        ),
      ),
    );
  });
}

String _collapsedPrice(List<GooglePlayProductDetails> offers) {
  final Map<String, ProductDetails> collapsed = <String, ProductDetails>{
    for (final GooglePlayProductDetails offer in offers) offer.id: offer,
  };

  return collapsed.values.single.price;
}

List<GooglePlayProductDetails> _offers({
  required String productId,
  required List<SubscriptionOfferDetailsWrapper> subscriptions,
}) {
  return GooglePlayProductDetails.fromProductDetails(
    ProductDetailsWrapper(
      description: 'Dört Plus',
      name: 'Dört Plus',
      productId: productId,
      productType: ProductType.subs,
      title: 'Dört Plus',
      subscriptionOfferDetails: subscriptions,
    ),
  );
}

SubscriptionOfferDetailsWrapper _subscription({
  required String basePlanId,
  required String token,
  required String price,
  String period = 'P1M',
  String? offerId,
  List<PricingPhaseWrapper>? phases,
}) {
  return SubscriptionOfferDetailsWrapper(
    basePlanId: basePlanId,
    offerId: offerId,
    offerTags: const <String>[],
    offerIdToken: token,
    pricingPhases:
        phases ?? <PricingPhaseWrapper>[_phase(price: price, period: period)],
  );
}

PricingPhaseWrapper _phase({
  required String price,
  String period = 'P1M',
  RecurrenceMode mode = RecurrenceMode.infiniteRecurring,
}) {
  return PricingPhaseWrapper(
    billingCycleCount: mode == RecurrenceMode.infiniteRecurring ? 0 : 1,
    billingPeriod: period,
    formattedPrice: price,
    priceAmountMicros: 49990000,
    priceCurrencyCode: 'TRY',
    recurrenceMode: mode,
  );
}
