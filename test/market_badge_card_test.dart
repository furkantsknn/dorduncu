import 'package:dorduncu/models/badge_product_model.dart';
import 'package:dorduncu/screens/market_screen.dart';
import 'package:dorduncu/services/purchase_flow_reconcile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sahip olunan rozet kartı detayı açmak için tıklanabilir kalır', (
    WidgetTester tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarketBadgeProductCard(
            product: BadgeProductModel(
              id: 'okey',
              gameId: 'okey',
              gameName: 'Okey',
              title: 'Okey Rozeti',
              description: '',
              emoji: '',
              priceKurus: 49900,
              active: true,
              sortOrder: 1,
              createdAt: null,
              googlePlayProductId: 'dort_badge_okey',
              giftGooglePlayProductId: 'dort_gift_badge_okey',
            ),
            owned: true,
            priceState: PlayPricePresentation.ready,
            price: '₺499,00',
            canRetryPrice: false,
            onRetryPrice: () {},
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Owned'), findsOneWidget);
    await tester.tap(find.byType(MarketBadgeProductCard));
    expect(tapped, isTrue);
  });

  testWidgets('dar ekran ve büyük yazıda oyun adı taşmadan okunur', (
    WidgetTester tester,
  ) async {
    const String gameName = 'Çok Uzun Halı Saha Oyunu';
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: Scaffold(
            body: MarketBadgeProductCard(
              product: BadgeProductModel(
                id: 'badge-1',
                gameId: 'hali',
                gameName: gameName,
                title: 'Halı Saha Rozeti',
                description: 'Profilde görünen oyun rozeti',
                emoji: '⚽',
                priceKurus: 49900,
                active: true,
                sortOrder: 1,
                createdAt: null,
                googlePlayProductId: 'dort_badge',
              ),
              owned: false,
              priceState: PlayPricePresentation.failed,
              price: 'Fiyat yüklenemedi',
              canRetryPrice: true,
              onRetryPrice: () {},
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(gameName), findsOneWidget);
    expect(find.text('Halı Saha Rozeti'), findsNothing);
    expect(find.textContaining('severlere özel'), findsNothing);
    expect(find.text('Fiyat yüklenemedi'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('Plus özeti dar ekranda ve büyük yazıda taşmaz', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: Scaffold(
            body: SingleChildScrollView(child: PlusPlanSummary()),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('More, together.'), findsNothing);
    expect(find.text('Create events with multiple players.'), findsOneWidget);
    expect(find.text('Plan ahead'), findsOneWidget);
    expect(
      find.text('Choose the player count for your event.'),
      findsOneWidget,
    );
  });
}
