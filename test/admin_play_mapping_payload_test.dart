import 'package:dorduncu/admin/admin_play_product_mapping_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('badge mapping payload keeps personal and gift fields separate', () {
    final Map<String, dynamic> payload = buildPlayMappingPayload(
      collectionName: 'badge_products',
      productId: 'okey',
      googlePlayProductId: ' dort_badge_okey ',
      googlePlayBasePlanId: 'unused',
      giftGooglePlayProductId: ' dort_gift_badge_okey ',
      googlePlayPurchaseOptionId: ' standard ',
      giftGooglePlayPurchaseOptionId: ' buy ',
    );

    expect(payload, <String, dynamic>{
      'collection': 'badge_products',
      'productId': 'okey',
      'googlePlayProductId': 'dort_badge_okey',
      'giftGooglePlayProductId': 'dort_gift_badge_okey',
      'giftGooglePlayPurchaseOptionId': 'buy',
      'googlePlayPurchaseOptionId': 'standard',
    });
    expect(payload, isNot(contains('googlePlayBasePlanId')));
  });

  test('empty gift values clear only gift fields', () {
    final Map<String, dynamic> payload = buildPlayMappingPayload(
      collectionName: 'badge_products',
      productId: 'okey',
      googlePlayProductId: 'dort_badge_okey',
      googlePlayBasePlanId: '',
      giftGooglePlayProductId: ' ',
      googlePlayPurchaseOptionId: 'standard',
      giftGooglePlayPurchaseOptionId: '',
    );

    expect(payload['googlePlayProductId'], 'dort_badge_okey');
    expect(payload['googlePlayPurchaseOptionId'], 'standard');
    expect(payload['giftGooglePlayProductId'], isEmpty);
    expect(payload['giftGooglePlayPurchaseOptionId'], isEmpty);
  });
}
