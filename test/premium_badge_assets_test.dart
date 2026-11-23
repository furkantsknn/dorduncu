import 'package:dorduncu/models/user_model.dart';
import 'package:dorduncu/services/plus_entitlement.dart';
import 'package:dorduncu/widgets/game_badge_art.dart';
import 'package:dorduncu/widgets/game_badge_emblem.dart';
import 'package:dorduncu/widgets/plus_membership_label.dart';
import 'package:dorduncu/widgets/premium_badge_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('premium rozetler yalnız exact id ile eşlenir', () {
    expect(premiumBadgeAssets.length, 31);
    expect(
      premiumBadgeAsset('okey'),
      'assets/images/badges/premium_v1/okey.png',
    );
    expect(
      premiumBadgeAsset('okey_101'),
      'assets/images/badges/premium_v1/okey_101.png',
    );
    expect(premiumBadgeAsset('okey_101'), isNot(premiumBadgeAsset('okey')));
    expect(
      premiumBadgeAsset('batak'),
      'assets/images/badges/premium_v1/batak.png',
    );
    expect(
      premiumBadgeAsset('tavla'),
      'assets/images/badges/premium_v1/tavla.png',
    );
    expect(premiumBadgeAsset('okey_extra'), isNull);
    expect(premiumBadgeAsset('Okey'), isNull);
    expect(
      premiumBadgeAsset('futbol'),
      'assets/images/badges/premium_v1/futbol.png',
    );
    expect(
      premiumBadgeAsset('paintball'),
      'assets/images/badges/premium_v1/paintball.png',
    );
    for (final String id in <String>['satranc', 'bric', 'king', 'monopoly']) {
      expect(premiumBadgeAsset(id), 'assets/images/badges/premium_v1/$id.png');
    }
    for (final String id in <String>[
      'uno',
      'jenga',
      'scrabble',
      'tombala',
      'ea_fc',
      'efootball',
      'tekken',
      'tenis',
      'masa_tenisi',
      'badminton',
      'squash',
      'pickleball',
      'basketbol',
      'voleybol',
      'hentbol',
      'golf',
      'yelken',
      'kurek',
      'binicilik',
      'kayak',
      'snowboard',
    ]) {
      expect(premiumBadgeAsset(id), 'assets/images/badges/premium_v1/$id.png');
    }
    expect(
      premiumBadgeAsset(resolveBadgeGameId(gameId: 'okey', gameName: 'Okey')),
      premiumBadgeAssets['okey'],
    );
  });

  test('süresi dolmuş Plus hakkı etiketi açmaz', () {
    final DateTime past = DateTime.now().subtract(const Duration(hours: 2));
    final DateTime future = DateTime.now().add(const Duration(days: 3));
    final UserModel expired = UserModel.fromMap(<String, dynamic>{
      'uid': 'expired',
      'plus': true,
      'plusExpiresAt': past,
    });
    final UserModel active = UserModel.fromMap(<String, dynamic>{
      'uid': 'active',
      'plus': true,
      'plusExpiresAt': future,
    });

    expect(expired.isPlusActive, isFalse);
    expect(active.isPlusActive, isTrue);
    expect(
      PlusEntitlement.isActive(<String, dynamic>{
        'plus': true,
        'plusExpiresAt': past,
      }),
      isFalse,
    );
    expect(
      PlusEntitlement.isActive(<String, dynamic>{
        'plus': true,
        'plusSubscriptionExpiresAt': future,
        'plusSubscriptionState': 'SUBSCRIPTION_STATE_EXPIRED',
      }),
      isFalse,
    );
  });

  testWidgets('premium PNG çizer, bilinmeyen oyun mevcut çizime döner', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: <Widget>[
              GameBadgeEmblem(
                emoji: '',
                imageUrl: '',
                gameId: 'okey',
                gameName: 'Okey',
                size: 48,
              ),
              GameBadgeEmblem(
                emoji: '',
                imageUrl: '',
                gameId: 'bilinmeyen_oyun',
                gameName: 'Bilinmeyen',
                size: 48,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final Image image = tester.widget<Image>(find.byType(Image));
    final ResizeImage resize = image.image as ResizeImage;
    final AssetImage provider = resize.imageProvider as AssetImage;
    expect(provider.assetName, premiumBadgeAssets['okey']);
    expect(resize.width, lessThanOrEqualTo(1254));
    expect(resize.height, lessThanOrEqualTo(1254));
    expect(image.fit, BoxFit.fill);
    final double drawn = 48 * premiumBadgeDrawScale('okey');
    final int pixels = (drawn * tester.view.devicePixelRatio).round();
    expect(resize.width, pixels.clamp(1, 1254));
    expect(resize.height, pixels.clamp(1, 1254));
    expect(resize.width, greaterThan(48));
    expect(find.byType(GameBadgeArt), findsOneWidget);
    expect(tester.widget<GameBadgeArt>(find.byType(GameBadgeArt)).gameId, '');
  });

  testWidgets('aktif olmayan Plus etiketi görünmez', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileNameRow(name: 'Uzun Oyuncu Adı', plusActive: false),
        ),
      ),
    );

    expect(find.text('PLUS'), findsNothing);
    expect(find.text('Uzun Oyuncu Adı'), findsOneWidget);
  });

  testWidgets('uzun ad ve büyük yazıda aktif Plus alt satıra iner', (
    WidgetTester tester,
  ) async {
    const String name = 'Abdullah Kerim Yıldırımoğlu';
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: Scaffold(
            body: ProfileNameRow(
              name: name,
              plusActive: true,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('PLUS'), findsOneWidget);
    expect(find.text(name), findsOneWidget);
    final Rect nameRect = tester.getRect(find.text(name));
    final Rect plusRect = tester.getRect(find.text('PLUS'));
    expect(plusRect.top, greaterThanOrEqualTo(nameRect.bottom - 1));
    expect(plusRect.right, lessThanOrEqualTo(320));
    expect(plusRect.left, greaterThanOrEqualTo(0));
  });

  testWidgets('kısa ad ile aktif Plus aynı satırda durur', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileNameRow(
            name: 'Ece',
            plusActive: true,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final Rect nameRect = tester.getRect(find.text('Ece'));
    final Rect plusRect = tester.getRect(find.text('PLUS'));
    expect((plusRect.center.dy - nameRect.center.dy).abs(), lessThan(8));
    expect(plusRect.left, greaterThan(nameRect.right));
  });
}
