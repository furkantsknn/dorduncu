import 'package:dorduncu/models/gift_recipient_profile.dart';
import 'package:dorduncu/screens/gift_flow_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

ProductDetails _details() => ProductDetails(
  id: 'gift.plus.30',
  title: 'Dört. Plus',
  description: '30 gün',
  price: '₺149,99',
  rawPrice: 149.99,
  currencyCode: 'TRY',
);

void main() {
  const recipient = GiftRecipientProfile(
    uid: 'internal-safe-uid',
    displayName: 'Ada Oyuncu',
  );
  late GiftProductPresentation product;

  setUp(() {
    product = GiftProductPresentation(
      id: 'plus30',
      kind: GiftKind.plus,
      title: '30 Gün Plus',
      playProductId: 'gift.plus.30',
      price: '₺149,99',
      productDetails: _details(),
    );
  });

  test(
    'payment readiness requires recipient, purchasable product and idle flow',
    () {
      expect(
        giftPaymentReady(recipient: null, product: product, busy: false),
        isFalse,
      );
      expect(
        giftPaymentReady(recipient: recipient, product: null, busy: false),
        isFalse,
      );
      expect(
        giftPaymentReady(recipient: recipient, product: product, busy: true),
        isFalse,
      );
      expect(
        giftPaymentReady(recipient: recipient, product: product, busy: false),
        isTrue,
      );
    },
  );

  testWidgets('empty state hides payment action and never exposes uid', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: const <Locale>[Locale('tr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: GiftFlowContent(
            recipients: const <GiftRecipientProfile>[recipient],
            selectedRecipient: recipient,
            products: const <GiftProductPresentation>[],
            selectedProduct: null,
            busy: false,
            onRecipientChanged: null,
            onProductChanged: (_) {},
            onPay: () {},
          ),
        ),
      ),
    );
    expect(
      find.text('Şu anda satın alınabilir bir hediye yok.'),
      findsOneWidget,
    );
    expect(find.text('Özeti gör ve öde'), findsNothing);
    expect(find.text('internal-safe-uid'), findsNothing);
  });

  testWidgets(
    'production content renders recipient and Play price on narrow large text',
    (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: MaterialApp(
            locale: const Locale('tr'),
            supportedLocales: const <Locale>[Locale('tr')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(
              body: GiftFlowContent(
                recipients: const <GiftRecipientProfile>[recipient],
                selectedRecipient: recipient,
                products: <GiftProductPresentation>[product],
                selectedProduct: product,
                busy: false,
                onRecipientChanged: null,
                onProductChanged: (_) {},
                onPay: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ada Oyuncu'), findsOneWidget);
      expect(find.text('₺149,99'), findsOneWidget);
      expect(find.text('internal-safe-uid'), findsNothing);
      await expectLater(
        find.byType(GiftFlowContent),
        matchesGoldenFile('goldens/gift_flow_narrow_large_text.png'),
      );
    },
  );
}
