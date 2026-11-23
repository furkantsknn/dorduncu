import 'package:flutter_test/flutter_test.dart';
import 'package:dorduncu/models/market_badge_display.dart';

void main() {
  test('admin block wins over a restored Play entitlement', () {
    expect(
      ownedBadgeIsEntitled(<String, dynamic>{
        'adminBlocked': true,
        'googlePlayEntitled': true,
      }),
      isFalse,
    );
  });

  test('admin grant survives an invalidated Play entitlement', () {
    expect(
      ownedBadgeIsEntitled(<String, dynamic>{
        'adminGranted': true,
        'googlePlayEntitled': false,
      }),
      isTrue,
    );
  });

  test('legacy ownership remains compatible without source guessing', () {
    expect(ownedBadgeIsEntitled(<String, dynamic>{}), isTrue);
  });
}
