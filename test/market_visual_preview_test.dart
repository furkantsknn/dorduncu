import 'dart:io';
import 'dart:ui' as ui;

import 'package:dorduncu/l10n/app_localizations.dart';
import 'package:dorduncu/models/badge_product_model.dart';
import 'package:dorduncu/models/market_badge_display.dart';
import 'package:dorduncu/models/user_model.dart';
import 'package:dorduncu/screens/market_screen.dart';
import 'package:dorduncu/screens/profile_screen.dart';
import 'package:dorduncu/screens/user_badges_screen.dart';
import 'package:dorduncu/services/digital_restore.dart';
import 'package:dorduncu/services/purchase_flow_reconcile.dart';
import 'package:dorduncu/widgets/game_badge_emblem.dart';
import 'package:dorduncu/widgets/market_palette.dart';
import 'package:dorduncu/widgets/plus_surface.dart';
import 'package:dorduncu/widgets/plus_emblem.dart';
import 'package:dorduncu/widgets/plus_membership_label.dart';
import 'package:dorduncu/widgets/game_badge_symbols.dart';
import 'package:dorduncu/widgets/market_badge_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Layout sample only. Not a Google Play price and not an entitlement.
const String _layoutPrice = '₺18,99';

const String _fontRoot =
    r'C:\Users\FURKAN\Documents\flutter\bin\cache\artifacts\material_fonts';

Future<void> _loadFamily(String family, List<String> files) async {
  final FontLoader loader = FontLoader(family);
  for (final String name in files) {
    final Uint8List bytes = await File('$_fontRoot\\$name').readAsBytes();
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

Future<void> loadPreviewFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadFamily('Roboto', <String>[
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
  ]);
  await _loadFamily('MaterialIcons', <String>['materialicons-regular.otf']);
}

BadgeProductModel _badge({
  required String id,
  required String name,
  required String playId,
}) {
  return BadgeProductModel(
    id: id,
    gameId: id,
    gameName: name,
    title: name,
    description: '',
    emoji: '',
    priceKurus: 0,
    active: true,
    sortOrder: 1,
    createdAt: null,
    googlePlayProductId: playId,
  );
}

Future<void> _save(WidgetTester tester, String name) async {
  final RenderRepaintBoundary boundary = tester.renderObject(
    find.byType(RepaintBoundary).first,
  );
  final ui.Image image = await boundary.toImage(pixelRatio: 2);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  final File file = File('docs/previews/market/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(data!.buffer.asUint8List());
}

ThemeData _previewTheme(Brightness brightness) {
  final bool dark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    brightness: brightness,
    scaffoldBackgroundColor: dark
        ? const Color(0xff0F1115)
        : const Color(0xffF7F6F2),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xffFF9800),
      brightness: brightness,
      surface: dark ? const Color(0xff111318) : const Color(0xffF7F6F2),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: dark ? const Color(0xff0F1115) : const Color(0xffF7F6F2),
      foregroundColor: dark ? Colors.white : const Color(0xff1B1E24),
    ),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xff181B22) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
  );
}

Widget _app({
  required Brightness brightness,
  required double scale,
  required Widget body,
}) {
  final ThemeData theme = _previewTheme(brightness);
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('tr'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: theme,
    darkTheme: theme,
    themeMode: ThemeMode.light,
    home: Builder(
      builder: (BuildContext context) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: Theme(
            data: theme,
            child: Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              body: DefaultTextStyle(
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xffF4F1EA)
                      : const Color(0xff1B1E24),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
                child: RepaintBoundary(child: body),
              ),
            ),
          ),
        );
      },
    ),
  );
}

Widget _marketBody({required double width, required double scale}) {
  final List<BadgeProductModel> products = <BadgeProductModel>[
    _badge(id: 'okey', name: 'Okey', playId: 'layout_okey'),
    _badge(id: 'okey_101', name: '101', playId: 'layout_101'),
    _badge(id: 'batak', name: 'Batak', playId: 'layout_batak'),
    _badge(id: 'futbol', name: 'Futbol', playId: ''),
    _badge(id: 'tavla', name: 'Tavla', playId: 'layout_tavla'),
    _badge(id: 'tenis', name: 'Tenis', playId: 'layout_tenis'),
  ];
  final bool twoColumns = width >= 340 && scale < 1.3;
  return Builder(
    builder: (BuildContext context) {
      return ColoredBox(
        color: MarketPalette.of(context).background,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            const Text(
              'Dört. Market',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            MarketPlusPromo(
              loading: false,
              entitlementKnown: true,
              enabled: true,
              plusActive: false,
              onTap: () {},
            ),
            const SizedBox(height: 22),
            MarketBadgeCatalogHeader(onChanged: (_) {}),
            const SizedBox(height: 12),
            MarketFilterBar(selected: 'all', ownedCount: 1, onSelected: (_) {}),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                for (final BadgeProductModel product in products)
                  SizedBox(
                    width: twoColumns ? (width - 44) / 2 : width - 32,
                    child: MarketBadgeProductCard(
                      product: product,
                      owned: product.id == 'batak',
                      priceState: product.googlePlayProductId.isEmpty
                          ? PlayPricePresentation.missingMapping
                          : PlayPricePresentation.ready,
                      price: product.googlePlayProductId.isEmpty
                          ? 'Şu an satışta değil'
                          : _layoutPrice,
                      canRetryPrice: false,
                      onRetryPrice: () {},
                      onTap: () {},
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

Widget _plusDetail() {
  return ListView(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
    children: <Widget>[
      const PlusWordmark(markSize: 34),
      const SizedBox(height: 8),
      const Text(
        'Oyuna daha çok yer aç.',
        style: TextStyle(color: PlusSurface.muted, fontSize: 16),
      ),
      const SizedBox(height: 14),
      const PlusPlanSummary(),
      const SizedBox(height: 16),
      PlusSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Aylık plan',
              style: TextStyle(
                color: PlusSurface.ink,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '$_layoutPrice / ay',
              style: TextStyle(
                color: PlusSurface.accent,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: Container(
                alignment: Alignment.center,
                constraints: const BoxConstraints(minHeight: 48),
                decoration: BoxDecoration(
                  color: PlusSurface.accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  "Plus'a abone ol",
                  style: TextStyle(
                    color: Color(0xff15120D),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'Aylık plan, iptal edilmediği sürece her ay yenilenir. Tahsil edilecek tutar: $_layoutPrice /ay.',
      ),
      const SizedBox(height: 8),
      const Align(
        alignment: Alignment.centerLeft,
        child: Text('Plus Abonelik Koşulları'),
      ),
      const Align(
        alignment: Alignment.centerLeft,
        child: Text('Otomatik Yenileme'),
      ),
      const SizedBox(height: 12),
      MarketRestoreFeedbackBanner(
        feedback: ValueNotifier<MarketRestoreFeedback>(
          const MarketRestoreFeedback.none(),
        ),
      ),
      const SizedBox(height: 8),
      TextButton(onPressed: () {}, child: const Text('Geri yükle')),
    ],
  );
}

Widget _okeyDetail() {
  return ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
    children: <Widget>[
      Center(
        child: GameBadgeEmblem(
          emoji: '',
          imageUrl: '',
          gameId: 'okey',
          gameName: 'Okey',
          size: 140,
        ),
      ),
      SizedBox(height: 14),
      Text(
        'Okey',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      SizedBox(height: 8),
      Text(
        'Sevdiğin oyunu profilinde göster.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
      ),
      SizedBox(height: 18),
      Text(
        _layoutPrice,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xffFF9800),
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      SizedBox(height: 8),
      Text(
        'Tek seferlik satın alma. Ödeme ve iade Google Play üzerinden yürür.',
        textAlign: TextAlign.center,
      ),
      SizedBox(height: 12),
      FilledButton(
        onPressed: () {},
        child: const Text('Google Play ile satın al'),
      ),
    ],
  );
}

MarketBadgeDisplay _owned(String id, String name) {
  return MarketBadgeDisplay(
    badgeId: id,
    productId: id,
    title: name,
    gameId: id,
    gameName: name,
    emoji: '',
    imageUrl: '',
    purchasedAt: DateTime(2026, 3, 2),
  );
}

UserModel _previewUser({required String name, required bool plusActive}) {
  return UserModel.fromMap(<String, dynamic>{
    'uid': 'preview-user',
    'profilAdi': name,
    'sehir': 'İstanbul',
    'ilce': 'Kadıköy',
    'hakkimda': 'İyi bir oyun, güzel bir sohbet.',
    'puan': 4.8,
    'completedEventCount': 12,
    'plus': plusActive,
    'plusExpiresAt': plusActive
        ? DateTime.now().add(const Duration(days: 20))
        : DateTime.now().subtract(const Duration(days: 2)),
    'verified': true,
    'oyuncuRozeti': true,
    'gameSkills': <String, Map<String, dynamic>>{
      'okey': <String, dynamic>{
        'gameId': 'okey',
        'gameName': 'Okey',
        'level': 60,
        'levelLabel': 'Orta',
      },
      'tavla': <String, dynamic>{
        'gameId': 'tavla',
        'gameName': 'Tavla',
        'level': 30,
        'levelLabel': 'Başlangıç',
      },
    },
  });
}

Widget _profilePlusCard({required bool active}) {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: PlusMembershipCard(
      user: _previewUser(name: 'Ece', plusActive: active),
      onTap: () {},
    ),
  );
}

Widget _publicPlusIdentity() => const Center(
  child: Padding(
    padding: EdgeInsets.all(20),
    child: ProfileNameRow(
      name: 'Ece',
      plusActive: true,
      style: TextStyle(
        color: PlusSurface.ink,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
    ),
  ),
);

Widget _plusMarkComparison() => const Padding(
  padding: EdgeInsets.all(24),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: <Widget>[
      Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 34.4,
            height: 37.1,
            child: Image(
              image: AssetImage('assets/branding/dort_d_mark_source.png'),
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(height: 10),
          Text('Kaynak D'),
        ],
      ),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PlusMark(size: 64),
          SizedBox(height: 10),
          Text('Türetilmiş D.'),
        ],
      ),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PlusMembershipLabel(),
          SizedBox(height: 10),
          Text('Küçük etiket'),
        ],
      ),
    ],
  ),
);

Widget _profileBody({
  required String name,
  required bool plusActive,
  required List<MarketBadgeDisplay> badges,
}) {
  return ProfileScreenView(
    user: _previewUser(name: name, plusActive: plusActive),
    badges: badges,
    onRefresh: () async {},
    onEdit: () {},
    onSettings: () {},
    onFriends: () {},
    onFriendRequests: () {},
    onUserSearch: () {},
    onMarket: () {},
    onVerify: () {},
    onBadges: () {},
    onPublicProfile: () {},
    onLogout: () {},
  );
}

Widget _catalog() {
  return GridView.builder(
    padding: const EdgeInsets.all(12),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.72,
    ),
    itemCount: badgeArtGameIds.length,
    itemBuilder: (BuildContext context, int index) {
      final String id = badgeArtGameIds[index];
      return Column(
        children: <Widget>[
          GameBadgeEmblem(
            emoji: '',
            imageUrl: '',
            gameId: id,
            gameName: badgeArtLabels[id] ?? id,
            size: 64,
          ),
          const SizedBox(height: 4),
          Text(
            badgeArtLabels[id] ?? id,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      );
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadPreviewFonts);

  testWidgets('market ekranları ve rozet kataloğu widget olarak kaydedilir', (
    WidgetTester tester,
  ) async {
    Future<void> pumpScene({
      required Widget body,
      required Size size,
      required double scale,
      Brightness brightness = Brightness.dark,
    }) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = Size(size.width * 2, size.height * 2);
      await tester.pumpWidget(
        _app(brightness: brightness, scale: scale, body: body),
      );
      await tester.pump();
      final Iterable<Element> images = find.byType(Image).evaluate();
      if (images.isNotEmpty) {
        await tester.runAsync(() async {
          for (final Element element in images) {
            final Image widget = element.widget as Image;
            await precacheImage(widget.image, element);
          }
        });
        await tester.pump();
      }
    }

    await pumpScene(
      body: _marketBody(width: 390, scale: 1),
      size: const Size(390, 980),
      scale: 1,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Dört. Market'), findsOneWidget);
    expect(find.text('Oyun rozetleri'), findsOneWidget);
    expect(
      find.text('Planlarını genişlet, Plus ayrıcalıklarını keşfet.'),
      findsOneWidget,
    );
    expect(find.text('Birden fazla oyuncu'), findsNothing);
    expect(find.text('İleri tarih planı'), findsNothing);
    expect(find.text('Okey'), findsOneWidget);
    expect(find.text('101'), findsOneWidget);
    expect(find.textContaining('P1M'), findsNothing);
    final double promoHeight = tester
        .getSize(find.byType(MarketPlusPromo))
        .height;
    expect(promoHeight, lessThanOrEqualTo(190));
    final Size cardSize = tester.getSize(
      find.byType(MarketBadgeProductCard).first,
    );
    final double badgeEdge = tester
        .getSize(find.byType(GameBadgeEmblem).first)
        .width;
    expect(badgeEdge, inInclusiveRange(96, 112));
    expect(badgeEdge / (cardSize.width - 24), inInclusiveRange(0.65, 0.70));
    await tester.runAsync(() => _save(tester, 'market_normal'));

    await pumpScene(
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: MarketPlusPromo(
          loading: false,
          entitlementKnown: true,
          enabled: true,
          plusActive: false,
          onTap: null,
        ),
      ),
      size: const Size(390, 270),
      scale: 1,
    );
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => _save(tester, 'plus_preview_market_card'));

    await pumpScene(
      body: _marketBody(width: 390, scale: 1),
      size: const Size(390, 980),
      scale: 1,
      brightness: Brightness.light,
    );
    expect(tester.takeException(), isNull);
    expect(
      Theme.of(tester.element(find.text('Dört. Market'))).brightness,
      Brightness.light,
    );
    await tester.runAsync(() => _save(tester, 'market_light'));

    await pumpScene(
      body: _marketBody(width: 320, scale: 1.8),
      size: const Size(320, 2400),
      scale: 1.8,
    );
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => _save(tester, 'market_large_text'));

    await pumpScene(body: _plusDetail(), size: const Size(390, 980), scale: 1);
    expect(tester.takeException(), isNull);
    expect(find.text('Oyuna daha çok yer aç.'), findsOneWidget);
    expect(
      find.text('Ücretsiz üyelikle bugün için 1 oyuncu arayabilirsin.'),
      findsOneWidget,
    );
    expect(find.textContaining('P1M'), findsNothing);
    await tester.runAsync(() => _save(tester, 'plus_detail'));
    await tester.runAsync(() => _save(tester, 'plus_preview_purchase_detail'));

    await pumpScene(
      body: _plusDetail(),
      size: const Size(320, 1700),
      scale: 1.8,
    );
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => _save(tester, 'plus_detail_large'));

    Widget deliveryPending() {
      return Builder(
        builder: (BuildContext context) {
          return ColoredBox(
            color: MarketPalette.of(context).background,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                MarketDeliveryPendingNotice(
                  awaiting:
                      ValueNotifier<Map<String, String>>(const <String, String>{
                        'dort_badge_okey':
                            'Satın alma doğrulanamadı. Tekrar kontrol et.',
                      }),
                  checking: ValueNotifier<bool>(false),
                  feedback: ValueNotifier<String?>(
                    'Teslimat hâlâ bekliyor. Tekrar ödeme yapma; biraz sonra yeniden kontrol et.',
                  ),
                  onRecheck: () async {},
                ),
              ],
            ),
          );
        },
      );
    }

    await pumpScene(
      body: deliveryPending(),
      size: const Size(390, 520),
      scale: 1,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Ödemen alındı, teslimat bekliyor'), findsOneWidget);
    expect(find.text('Teslimatı kontrol et'), findsOneWidget);
    await tester.runAsync(() => _save(tester, 'delivery_pending'));

    await pumpScene(
      body: deliveryPending(),
      size: const Size(320, 1100),
      scale: 1.8,
    );
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => _save(tester, 'delivery_pending_large'));

    await pumpScene(body: _okeyDetail(), size: const Size(390, 760), scale: 1);
    expect(tester.takeException(), isNull);
    expect(find.text('Sevdiğin oyunu profilinde göster.'), findsOneWidget);
    await tester.runAsync(() => _save(tester, 'okey_detail'));

    await pumpScene(
      body: _okeyDetail(),
      size: const Size(320, 1100),
      scale: 1.8,
    );
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => _save(tester, 'okey_detail_large'));

    await pumpScene(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          OwnedBadgeCard(
            badge: MarketBadgeDisplay(
              badgeId: 'okey',
              productId: 'okey',
              title: 'Okey',
              gameId: 'okey',
              gameName: 'Okey',
              emoji: '',
              imageUrl: '',
              purchasedAt: DateTime(2026, 3, 2),
            ),
          ),
          const SizedBox(height: 12),
          OwnedBadgeCard(
            badge: MarketBadgeDisplay(
              badgeId: 'futbol',
              productId: 'futbol',
              title: 'Futbol',
              gameId: 'futbol',
              gameName: 'Futbol',
              emoji: '',
              imageUrl: '',
              purchasedAt: DateTime(2026, 4, 11),
            ),
          ),
        ],
      ),
      size: const Size(390, 720),
      scale: 1,
    );
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => _save(tester, 'my_badges'));

    await pumpScene(
      body: const UserBadgesEmpty(isOwnProfile: true),
      size: const Size(390, 640),
      scale: 1,
    );
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => _save(tester, 'my_badges_empty'));

    await pumpScene(
      body: _profileBody(
        name: 'Ece',
        plusActive: true,
        badges: <MarketBadgeDisplay>[
          _owned('okey', 'Okey'),
          _owned('batak', 'Batak'),
          _owned('tavla', 'Tavla'),
        ],
      ),
      size: const Size(390, 2100),
      scale: 1,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('PLUS'), findsOneWidget);
    expect(find.text('Profilim'), findsOneWidget);
    expect(find.text('Arkadaşlarım'), findsOneWidget);
    expect(find.text('Profil fotoğrafı'), findsOneWidget);
    expect(find.text('%80'), findsOneWidget);
    expect(find.textContaining('ödül'), findsNothing);
    expect(find.text('Hesaptan çıkış yap'), findsOneWidget);
    await tester.runAsync(() => _save(tester, 'profile_badges'));
    await tester.runAsync(() => _save(tester, 'profile_plus_active'));

    await pumpScene(
      body: _profileBody(
        name: 'Ece',
        plusActive: false,
        badges: <MarketBadgeDisplay>[_owned('okey', 'Okey')],
      ),
      size: const Size(390, 2100),
      scale: 1,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('PLUS'), findsNothing);
    await tester.runAsync(() => _save(tester, 'profile_plus_free'));

    await pumpScene(
      body: _profilePlusCard(active: false),
      size: const Size(390, 250),
      scale: 1,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Aktif değil'), findsNothing);
    await tester.runAsync(() => _save(tester, 'plus_preview_profile_free'));

    await pumpScene(
      body: _profilePlusCard(active: true),
      size: const Size(390, 250),
      scale: 1,
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('gün kaldı'), findsNothing);
    await tester.runAsync(() => _save(tester, 'plus_preview_profile_active'));

    await pumpScene(
      body: _publicPlusIdentity(),
      size: const Size(390, 150),
      scale: 1,
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(PlusMembershipLabel), findsOneWidget);
    await tester.runAsync(
      () => _save(tester, 'plus_preview_public_profile_identity'),
    );

    await pumpScene(
      body: _plusMarkComparison(),
      size: const Size(520, 190),
      scale: 1,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Kaynak D'), findsOneWidget);
    expect(find.text('Türetilmiş D.'), findsOneWidget);
    expect(find.text('Küçük etiket'), findsOneWidget);
    await tester.runAsync(() => _save(tester, 'plus_mark_source_comparison'));

    await pumpScene(
      body: _profileBody(
        name: 'Abdullah Kerim Yıldırımoğlu',
        plusActive: true,
        badges: const <MarketBadgeDisplay>[],
      ),
      size: const Size(320, 3600),
      scale: 1.8,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('PLUS'), findsOneWidget);
    final Rect longName = tester.getRect(
      find.text('Abdullah Kerim Yıldırımoğlu'),
    );
    final Rect longPlus = tester.getRect(find.text('PLUS'));
    expect(longPlus.top, greaterThanOrEqualTo(longName.bottom - 1));
    await tester.runAsync(() => _save(tester, 'profile_long_name'));

    await pumpScene(
      body: _profileBody(
        name: 'Ece',
        plusActive: true,
        badges: <MarketBadgeDisplay>[
          for (final String id in <String>[
            'okey',
            'okey_101',
            'batak',
            'tavla',
            'futbol',
            'satranc',
            'tenis',
            'golf',
          ])
            _owned(id, id),
        ],
      ),
      size: const Size(320, 520),
      scale: 1,
    );
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => _save(tester, 'profile_many_badges'));

    await pumpScene(
      body: OwnedBadgeDetail(badge: _owned('okey', 'Okey'), ownsBadges: true),
      size: const Size(390, 520),
      scale: 1,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Bu rozet sende.'), findsOneWidget);
    expect(find.text('Google Play ile satın al'), findsNothing);
    await tester.runAsync(() => _save(tester, 'profile_badge_detail'));

    await pumpScene(
      body: const Wrap(
        spacing: 16,
        runSpacing: 16,
        children: <Widget>[
          GameBadgeEmblem(
            emoji: '',
            imageUrl: '',
            gameId: 'okey',
            gameName: 'Okey 32',
            size: 32,
          ),
          GameBadgeEmblem(
            emoji: '',
            imageUrl: '',
            gameId: 'okey',
            gameName: 'Okey 48',
            size: 48,
          ),
          GameBadgeEmblem(
            emoji: '',
            imageUrl: '',
            gameId: 'okey',
            gameName: 'Okey 64',
            size: 64,
          ),
          GameBadgeEmblem(
            emoji: '',
            imageUrl: '',
            gameId: 'okey_101',
            gameName: '101',
            size: 48,
          ),
          GameBadgeEmblem(
            emoji: '',
            imageUrl: '',
            gameId: 'batak',
            gameName: 'Batak',
            size: 48,
          ),
          GameBadgeEmblem(
            emoji: '',
            imageUrl: '',
            gameId: 'tavla',
            gameName: 'Tavla',
            size: 48,
          ),
        ],
      ),
      size: const Size(430, 240),
      scale: 1,
    );
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => _save(tester, 'badge_sizes'));

    await pumpScene(body: _catalog(), size: const Size(430, 1680), scale: 1);
    expect(tester.takeException(), isNull);
    expect(find.text('Okey'), findsOneWidget);
    expect(find.text('101'), findsOneWidget);
    expect(find.text('Snowboard'), findsOneWidget);
    expect(find.text('Bilardo'), findsOneWidget);
    await tester.runAsync(() => _save(tester, 'badge_catalog'));

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
