import 'package:dorduncu/models/gift_recipient_profile.dart';
import 'package:dorduncu/screens/gift_flow_screen.dart';
import 'package:dorduncu/utils/game_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

void main() {
  testWidgets(
    '31 canonical gifts stay visible; unavailable gifts cannot pay; filters and search work',
    (tester) async {
      expect(GameCatalog.allGames.length, 31);
      final products = GameCatalog.allGames
          .map(
            (game) => GiftProductPresentation(
              id: game.id,
              kind: GiftKind.badge,
              title: game.name,
              playProductId: game.id == 'okey' ? 'gift.okey' : '',
              price: game.id == 'okey' ? '499 TL' : '',
              productDetails: game.id == 'okey'
                  ? ProductDetails(
                      id: 'gift.okey',
                      title: 'Okey',
                      description: '',
                      price: '499 TL',
                      rawPrice: 499,
                      currencyCode: 'TRY',
                    )
                  : null,
              gameId: game.id,
              emoji: game.emoji,
              unavailableReason: game.id == 'okey' ? '' : 'not_ready',
            ),
          )
          .toList();
      const person = GiftRecipientProfile(
        uid: 'must-never-render',
        displayName: 'Ada Sentetik',
      );
      for (final language in ['tr', 'en', 'de']) {
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: const [Locale('tr'), Locale('en'), Locale('de')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(
              body: GiftFlowContent(
                key: ValueKey(language),
                recipients: const [person],
                selectedRecipient: person,
                products: products,
                selectedProduct: null,
                busy: false,
                onRecipientChanged: (_) {},
                onProductChanged: (_) {},
                onPay: () => fail('Unavailable product must not pay'),
              ),
            ),
          ),
        );
        expect(find.text('must-never-render'), findsNothing);
        await tester.enterText(find.byType(TextField), 'Paintball');
        await tester.pump();
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pump();
        expect(find.widgetWithText(ListTile, 'Paintball'), findsOneWidget);
        final unavailable = products.firstWhere((p) => p.id == 'paintball');
        expect(
          giftPaymentReady(
            recipient: person,
            product: unavailable,
            busy: false,
          ),
          false,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
