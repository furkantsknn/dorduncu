import 'package:dorduncu/services/play_one_time_offer.dart';
import 'package:dorduncu/services/plus_subscription_offer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

void main() {
  test('kampanya teklifi yoksa başka teklife düşmez', () {
    expect(
      () => selectPlayOneTimeOffer(
        offers: <PlayOneTimeOffer>[
          const PlayOneTimeOffer(
            productId: 'badge',
            offerId: '',
            offerToken: 'base',
            purchaseOptionId: 'buy',
            formattedPrice: '₺499,00',
            priceAmountMicros: 499000000,
            currencyCode: 'TRY',
          ),
        ],
        productId: 'badge',
        campaignOfferId: 'c-missing',
      ),
      throwsA(
        isA<PlayOneTimeOfferException>().having(
          (PlayOneTimeOfferException error) => error.code,
          'code',
          'campaign_not_on_play',
        ),
      ),
    );
  });

  test('gösterilen teklifin tokenı ve fiyatı aynı kalır', () {
    const PlayOneTimeOffer shown = PlayOneTimeOffer(
      productId: 'badge',
      offerId: 'c1',
      offerToken: 'token-c1',
      purchaseOptionId: 'buy',
      formattedPrice: '₺399,20',
      priceAmountMicros: 399200000,
      currencyCode: 'TRY',
      fullPriceMicros: 499000000,
    );
    final PlayOneTimeOffer selected = selectPlayOneTimeOffer(
      offers: <PlayOneTimeOffer>[
        shown,
        const PlayOneTimeOffer(
          productId: 'badge',
          offerId: '',
          offerToken: 'base',
          purchaseOptionId: 'buy',
          formattedPrice: '₺499,00',
          priceAmountMicros: 499000000,
          currencyCode: 'TRY',
        ),
      ],
      productId: 'badge',
      campaignOfferId: 'c1',
    );

    expect(samePlayOneTimeOffer(shown, selected), isTrue);
    expect(selected.hasVerifiedListPrice, isTrue);
  });

  test('399 TRY exact Plus teklifi ürün ve option ile seçilir', () {
    const PlayOneTimeOffer expected = PlayOneTimeOffer(
      productId: 'dort_badge_okey_101',
      offerId: 'plus-price',
      offerToken: 'plus-token',
      purchaseOptionId: 'buy',
      formattedPrice: '₺399,00',
      priceAmountMicros: 399000000,
      currencyCode: 'TRY',
      fullPriceMicros: 499000000,
    );
    final PlayOneTimeOffer selected = selectPlayOneTimeOffer(
      offers: const <PlayOneTimeOffer>[
        expected,
        PlayOneTimeOffer(
          productId: 'dort_badge_okey_101',
          offerId: 'plus-price',
          offerToken: 'wrong-option-token',
          purchaseOptionId: 'standard',
          formattedPrice: '₺399,00',
          priceAmountMicros: 399000000,
          currencyCode: 'TRY',
          fullPriceMicros: 499000000,
        ),
      ],
      productId: expected.productId,
      purchaseOptionId: 'buy',
      campaignOfferId: 'plus-price',
    );
    expect(selected.offerToken, 'plus-token');
    expect(selected.priceAmountMicros, 399000000);
    expect(selected.currencyCode, 'TRY');
  });

  test('Plus kampanya teklifi standart plana düşmez', () {
    final List<GooglePlayProductDetails> offers =
        GooglePlayProductDetails.fromProductDetails(
          ProductDetailsWrapper(
            description: 'Plus',
            name: 'Plus',
            productId: 'dort_plus',
            productType: ProductType.subs,
            title: 'Plus',
            subscriptionOfferDetails: <SubscriptionOfferDetailsWrapper>[
              SubscriptionOfferDetailsWrapper(
                basePlanId: 'monthly',
                offerIdToken: 'standard',
                offerTags: const <String>[],
                pricingPhases: <PricingPhaseWrapper>[
                  PricingPhaseWrapper(
                    billingCycleCount: 0,
                    billingPeriod: 'P1M',
                    formattedPrice: '₺799,00',
                    priceAmountMicros: 799000000,
                    priceCurrencyCode: 'TRY',
                    recurrenceMode: RecurrenceMode.infiniteRecurring,
                  ),
                ],
              ),
              SubscriptionOfferDetailsWrapper(
                basePlanId: 'monthly',
                offerId: 'cplus',
                offerIdToken: 'campaign',
                offerTags: const <String>[],
                pricingPhases: <PricingPhaseWrapper>[
                  PricingPhaseWrapper(
                    billingCycleCount: 2,
                    billingPeriod: 'P1M',
                    formattedPrice: '₺399,50',
                    priceAmountMicros: 399500000,
                    priceCurrencyCode: 'TRY',
                    recurrenceMode: RecurrenceMode.finiteRecurring,
                  ),
                  PricingPhaseWrapper(
                    billingCycleCount: 0,
                    billingPeriod: 'P1M',
                    formattedPrice: '₺799,00',
                    priceAmountMicros: 799000000,
                    priceCurrencyCode: 'TRY',
                    recurrenceMode: RecurrenceMode.infiniteRecurring,
                  ),
                ],
              ),
            ],
          ),
        );

    final PlusSubscriptionSelection selection = selectCatalogPlusOffer(
      offers: offers,
      googlePlayProductId: 'dort_plus',
      googlePlayBasePlanId: 'monthly',
      campaignOfferId: 'cplus',
      discountedPeriods: 2,
    );

    expect(selection.offerToken, 'campaign');
    expect(selection.formattedPrice, '₺399,50');
    expect(selection.renewalFormattedPrice, '₺799,00');
    expect(purchaseParamForSelectedPlusOffer(selection).offerToken, 'campaign');
  });
}
