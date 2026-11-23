class PlayOneTimeOffer {
  const PlayOneTimeOffer({
    required this.productId,
    required this.offerId,
    required this.offerToken,
    required this.purchaseOptionId,
    required this.formattedPrice,
    required this.priceAmountMicros,
    required this.currencyCode,
    this.fullPriceMicros,
  });

  final String productId;
  final String offerId;
  final String offerToken;
  final String purchaseOptionId;
  final String formattedPrice;
  final int priceAmountMicros;
  final String currencyCode;
  final int? fullPriceMicros;

  bool get hasVerifiedListPrice =>
      fullPriceMicros != null && fullPriceMicros! > priceAmountMicros;
}

class PlayOneTimeOfferException implements Exception {
  const PlayOneTimeOfferException(this.message, {required this.code});

  final String message;
  final String code;

  @override
  String toString() => message;
}

/// Selects one Play one-time offer by id.
///
/// A campaign that Play did not return is not replaced by another offer.
PlayOneTimeOffer selectPlayOneTimeOffer({
  required Iterable<PlayOneTimeOffer> offers,
  required String productId,
  String campaignOfferId = '',
  String purchaseOptionId = '',
}) {
  final String expectedProduct = productId.trim();
  final String expectedOffer = campaignOfferId.trim();
  final String expectedOption = purchaseOptionId.trim();
  final List<PlayOneTimeOffer> matches = <PlayOneTimeOffer>[];

  for (final PlayOneTimeOffer offer in offers) {
    if (offer.productId.trim() != expectedProduct) {
      continue;
    }
    if (expectedOption.isNotEmpty &&
        offer.purchaseOptionId.trim() != expectedOption) {
      continue;
    }
    final String offerId = offer.offerId.trim();
    if (expectedOffer.isEmpty) {
      if (offerId.isEmpty) {
        matches.add(offer);
      }
    } else if (offerId == expectedOffer) {
      matches.add(offer);
    }
  }

  if (matches.length != 1 || matches.single.offerToken.trim().isEmpty) {
    throw PlayOneTimeOfferException(
      expectedOffer.isEmpty
          ? 'Google Play standart fiyatı bulunamadı. Satın alma kapatıldı.'
          : 'Kampanya teklifi Google Play üzerinde yok. İndirim gösterilmedi.',
      code: expectedOffer.isEmpty ? 'plan_not_found' : 'campaign_not_on_play',
    );
  }

  return matches.single;
}

bool samePlayOneTimeOffer(PlayOneTimeOffer left, PlayOneTimeOffer right) {
  return left.productId == right.productId &&
      left.purchaseOptionId == right.purchaseOptionId &&
      left.currencyCode == right.currencyCode &&
      left.priceAmountMicros == right.priceAmountMicros &&
      left.offerId == right.offerId &&
      left.offerToken == right.offerToken &&
      left.formattedPrice == right.formattedPrice;
}
