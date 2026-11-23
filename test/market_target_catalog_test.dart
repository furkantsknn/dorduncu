import 'package:dorduncu/models/badge_product_model.dart';
import 'package:dorduncu/services/market_service.dart';
import 'package:dorduncu/widgets/premium_badge_assets.dart';
import 'package:flutter_test/flutter_test.dart';

BadgeProductModel _product(String id, {String? gameId}) => BadgeProductModel(
  id: id,
  gameId: gameId ?? id,
  gameName: id,
  title: '$id badge',
  description: '',
  emoji: '',
  priceKurus: 49900,
  active: true,
  sortOrder: 1,
  createdAt: null,
);

void main() {
  test('satış kataloğu yalnız exact 31 premium oyununu kabul eder', () {
    expect(premiumBadgeAssets, hasLength(31));
    for (final String id in premiumBadgeAssets.keys) {
      expect(isTargetPremiumBadgeProduct(_product(id)), isTrue, reason: id);
      expect(premiumBadgeAsset(id), endsWith('/$id.png'), reason: id);
    }
  });

  test('legacy ve yanlış eşlenmiş ürünler satış kataloğuna girmez', () {
    expect(isTargetPremiumBadgeProduct(_product('dart')), isFalse);
    expect(isTargetPremiumBadgeProduct(_product('yuzme')), isFalse);
    expect(
      isTargetPremiumBadgeProduct(_product('okey', gameId: 'tavla')),
      isFalse,
    );
  });
}
