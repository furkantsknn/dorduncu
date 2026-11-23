import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dorduncu/home_v2/home_listed_event.dart';
import 'package:dorduncu/home_v2/home_screen_v2.dart';
import 'package:dorduncu/l10n/app_localizations.dart';
import 'package:dorduncu/models/badge_product_model.dart';
import 'package:dorduncu/models/market_badge_display.dart';
import 'package:dorduncu/screens/login_screen.dart';
import 'package:dorduncu/screens/market_screen.dart';
import 'package:dorduncu/services/digital_restore.dart';
import 'package:dorduncu/services/language_controller.dart';
import 'package:dorduncu/services/purchase_flow_reconcile.dart';
import 'package:dorduncu/widgets/home_bottom_navigation.dart';
import 'package:dorduncu/widgets/market_badge_strip.dart';
import 'package:dorduncu/widgets/market_palette.dart';
import 'package:dorduncu/widgets/plus_emblem.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadOptionalFonts() async {
  const String fontRoot =
      r'C:\Users\FURKAN\Documents\flutter\bin\cache\artifacts\material_fonts';
  final Directory dir = Directory(fontRoot);
  if (!dir.existsSync()) {
    return;
  }
  Future<void> loadFamily(String family, List<String> files) async {
    final FontLoader loader = FontLoader(family);
    var added = false;
    for (final String name in files) {
      final File f = File('$fontRoot\\$name');
      if (f.existsSync()) {
        final Uint8List bytes = await f.readAsBytes();
        loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
        added = true;
      }
    }
    if (added) {
      await loader.load();
    }
  }

  await loadFamily('Roboto', <String>[
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
  ]);
  await loadFamily('MaterialIcons', <String>['materialicons-regular.otf']);
}

HomeListedEvent _demoEvent(String id, String gameId, String district, int hour) {
  final DateTime now = DateTime.now();
  return HomeListedEvent.fromMap(id, <String, dynamic>{
    'gameId': gameId,
    'sehir': 'İstanbul',
    'ilce': district,
    'olusturanUid': 'demo-host',
    'katilanlar': <String>['demo-host', 'demo-guest'],
    'playerCount': 3,
    'startAt': Timestamp.fromDate(
      DateTime(now.year, now.month, now.day, hour, 30),
    ),
    'approxLatitude': 40.99,
    'approxLongitude': 29.03,
  });
}

BadgeProductModel _demoBadge(String id, String name) {
  return BadgeProductModel(
    id: id,
    gameId: id,
    gameName: name,
    title: '$name Rozeti',
    description: '',
    emoji: '',
    priceKurus: 49900,
    active: true,
    sortOrder: 1,
    createdAt: null,
    appleProductId: 'com.dortapp.dort.badge.$id',
  );
}

Widget _iosShell({
  required Locale locale,
  required Widget home,
  double textScale = 1.0,
  EdgeInsets viewPadding = const EdgeInsets.only(top: 59, bottom: 34),
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: ThemeData(
      useMaterial3: true,
      platform: TargetPlatform.iOS,
      fontFamily: 'Roboto',
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xff0F1115),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffFF9800),
        brightness: Brightness.dark,
        surface: const Color(0xff111318),
      ),
    ),
    builder: (BuildContext context, Widget? child) {
      return RepaintBoundary(
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            padding: viewPadding,
            viewPadding: viewPadding,
          ),
          child: child!,
        ),
      );
    },
    home: home,
  );
}

Future<void> _precacheAllImages(WidgetTester tester) async {
  final List<Element> images = find.byType(Image).evaluate().toList();
  await tester.runAsync(() async {
    for (final Element element in images) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump();
}

Future<void> _captureScreenshot(
  WidgetTester tester,
  String filename, {
  double pixelRatio = 3.0,
}) async {
  final RenderRepaintBoundary boundary = tester.renderObject(
    find.byType(RepaintBoundary).first,
  );
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final File file = File('docs/app_store_screenshots/ios_6_9/$filename');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    await _loadOptionalFonts();
  });

  group('iPhone layout overflow & SafeArea audit (SE / 15 / 16 Pro Max)', () {
    const List<Size> iphoneSizes = <Size>[
      Size(375, 667), // iPhone SE (3rd gen)
      Size(393, 852), // iPhone 15 / 16
      Size(430, 932), // iPhone 15/16 Plus & Pro Max
    ];

    testWidgets('LoginScreen renders without overflow across iPhone sizes and locales', (
      WidgetTester tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        for (final AppLanguage lang in AppLanguage.values) {
          LanguageController.language.value = lang;
          final Locale locale = switch (lang) {
            AppLanguage.turkish => const Locale('tr'),
            AppLanguage.english => const Locale('en'),
            AppLanguage.german => const Locale('de'),
          };
          for (final Size size in iphoneSizes) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              _iosShell(
                locale: locale,
                textScale: size.width == 375 ? 1.25 : 1.0,
                home: const LoginScreen(),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'Overflow on LoginScreen for $lang at $size',
            );
          }
        }
      } finally {
        LanguageController.language.value = AppLanguage.turkish;
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('HomeScreenV2 + HomeBottomNavigation renders without overflow on iPhone SE and 16', (
      WidgetTester tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final List<HomeListedEvent> events = <HomeListedEvent>[
          _demoEvent('e1', 'futbol', 'Kadıköy', 20),
          _demoEvent('e2', 'okey', 'Beşiktaş', 21),
          _demoEvent('e3', 'tenis', 'Şişli', 19),
        ];
        for (final Size size in iphoneSizes) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            _iosShell(
              locale: const Locale('tr'),
              textScale: size.width == 375 ? 1.25 : 1.0,
              home: Scaffold(
                body: SafeArea(
                  bottom: false,
                  child: HomeScreenV2(
                    greeting: 'Merhaba, Mert',
                    cityLabel: 'İstanbul',
                    categories: const <String>[
                      'Tümü',
                      'Futbol',
                      'Basketbol',
                      'Tenis',
                      'Okey',
                    ],
                    selectedCategory: 'Tümü',
                    onCategorySelected: (_) {},
                    onSelectCity: () {},
                    onCreateEvent: () {},
                    onExplore: () {},
                    events: events,
                    activeEvents: events,
                  ),
                ),
                bottomNavigationBar: HomeBottomNavigation(
                  messageTooltip: 'Mesajlar',
                  profileTooltip: 'Profil',
                  onMessages: () {},
                  onCreateEvent: () {},
                  onProfile: () {},
                ),
              ),
            ),
          );
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Overflow on HomeScreenV2 at $size',
          );
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('iOS Market notices never display Google Play wording', (
      WidgetTester tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final ValueNotifier<Map<String, String>> awaiting =
            ValueNotifier<Map<String, String>>(<String, String>{
              'com.dortapp.dort.plus.monthly': 'Doğrulama bekleniyor',
            });
        final ValueNotifier<bool> checking = ValueNotifier<bool>(false);
        final ValueNotifier<String?> feedback = ValueNotifier<String?>(null);
        final ValueNotifier<MarketRestoreFeedback> restore =
            ValueNotifier<MarketRestoreFeedback>(
              const MarketRestoreFeedback.paymentPending(),
            );

        tester.view.physicalSize = const Size(375, 667);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _iosShell(
            locale: const Locale('tr'),
            home: Scaffold(
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    MarketDeliveryPendingNotice(
                      awaiting: awaiting,
                      checking: checking,
                      feedback: feedback,
                    ),
                    MarketRestoreFeedbackBanner(feedback: restore),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.textContaining('Google Play'), findsNothing);
        expect(find.textContaining('App Store'), findsAtLeastNWidgets(2));
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('Real iOS 6.9-inch App Store screenshot generation (1320x2868)', () {
    testWidgets('renders 4 real iOS production UI screenshots cleanly', (
      WidgetTester tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      LanguageController.language.value = AppLanguage.turkish;
      // 440 x 956 @ 3x = 1320 x 2868 (Apple 6.9" iPhone 16 Pro Max required size)
      const Size logicalSize = Size(440, 956);
      tester.view.physicalSize = logicalSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      try {
        // 1. Home Discovery
        final List<HomeListedEvent> events = <HomeListedEvent>[
          _demoEvent('s1', 'futbol', 'Kadıköy', 20),
          _demoEvent('s2', 'okey', 'Beşiktaş', 21),
          _demoEvent('s3', 'tenis', 'Moda', 18),
          _demoEvent('s4', 'basketbol', 'Ataşehir', 19),
        ];
        await tester.pumpWidget(
          _iosShell(
            locale: const Locale('tr'),
            home: Scaffold(
              body: SafeArea(
                bottom: false,
                child: HomeScreenV2(
                  greeting: 'Merhaba, Mert',
                  cityLabel: 'İstanbul',
                  categories: const <String>[
                    'Tümü',
                    'Futbol',
                    'Tenis',
                    'Okey',
                    'Basketbol',
                  ],
                  selectedCategory: 'Tümü',
                  onCategorySelected: (_) {},
                  onSelectCity: () {},
                  onCreateEvent: () {},
                  onExplore: () {},
                  events: events,
                  activeEvents: events,
                ),
              ),
              bottomNavigationBar: HomeBottomNavigation(
                messageTooltip: 'Mesajlar',
                profileTooltip: 'Profil',
                onMessages: () {},
                onCreateEvent: () {},
                onProfile: () {},
              ),
            ),
          ),
        );
        await _precacheAllImages(tester);
        await tester.pump();
        await _captureScreenshot(tester, '01_home_discovery.png');
        expect(tester.takeException(), isNull);

        // 2. Phone SMS Login (iOS)
        await tester.pumpWidget(
          _iosShell(
            locale: const Locale('tr'),
            home: const LoginScreen(),
          ),
        );
        await _precacheAllImages(tester);
        await tester.pumpAndSettle();
        await _captureScreenshot(tester, '02_login_sms.png');
        expect(tester.takeException(), isNull);

        // 3. iOS Market (Plus + Badges, zero Google Play wording)
        final List<BadgeProductModel> badges = <BadgeProductModel>[
          _demoBadge('okey', 'Okey'),
          _demoBadge('futbol', 'Futbol'),
          _demoBadge('tenis', 'Tenis'),
          _demoBadge('tavla', 'Tavla'),
          _demoBadge('basketbol', 'Basketbol'),
          _demoBadge('satranc', 'Satranç'),
        ];
        await tester.pumpWidget(
          _iosShell(
            locale: const Locale('tr'),
            home: Builder(
              builder: (BuildContext context) {
                final MarketPalette palette = MarketPalette.of(context);
                return Scaffold(
                  backgroundColor: palette.background,
                  appBar: AppBar(
                    backgroundColor: palette.background,
                    foregroundColor: palette.ink,
                    title: const Text('Dört. Market'),
                    centerTitle: true,
                  ),
                  body: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: <Widget>[
                      MarketPlusPromo(
                        loading: false,
                        entitlementKnown: true,
                        enabled: true,
                        plusActive: false,
                        verificationPending: false,
                        onTap: () {},
                      ),
                      const SizedBox(height: 18),
                      MarketBadgeCatalogHeader(onChanged: (_) {}),
                      const SizedBox(height: 12),
                      MarketFilterBar(
                        selected: 'all',
                        ownedCount: 2,
                        onSelected: (_) {},
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: <Widget>[
                          for (int i = 0; i < badges.length; i++)
                            SizedBox(
                              width: (440 - 32 - 12) / 2,
                              child: MarketBadgeProductCard(
                                product: badges[i],
                                owned: i < 2,
                                priceState: PlayPricePresentation.ready,
                                price: '₺499,00',
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
            ),
          ),
        );
        await _precacheAllImages(tester);
        await tester.pump();
        expect(find.textContaining('Google Play'), findsNothing);
        await _captureScreenshot(tester, '03_market_badges_ios.png');
        expect(tester.takeException(), isNull);

        // 4. Plus & Profile Badges Showcase (iOS)
        final List<MarketBadgeDisplay> showcaseBadges = <MarketBadgeDisplay>[
          const MarketBadgeDisplay(
            badgeId: 'futbol',
            productId: 'futbol',
            title: 'Futbol',
            gameId: 'futbol',
            gameName: 'Futbol',
            emoji: '',
            imageUrl: '',
          ),
          const MarketBadgeDisplay(
            badgeId: 'okey',
            productId: 'okey',
            title: 'Okey',
            gameId: 'okey',
            gameName: 'Okey',
            emoji: '',
            imageUrl: '',
          ),
          const MarketBadgeDisplay(
            badgeId: 'tenis',
            productId: 'tenis',
            title: 'Tenis',
            gameId: 'tenis',
            gameName: 'Tenis',
            emoji: '',
            imageUrl: '',
          ),
          const MarketBadgeDisplay(
            badgeId: 'satranc',
            productId: 'satranc',
            title: 'Satranç',
            gameId: 'satranc',
            gameName: 'Satranç',
            emoji: '',
            imageUrl: '',
          ),
        ];
        await tester.pumpWidget(
          _iosShell(
            locale: const Locale('tr'),
            home: Scaffold(
              appBar: AppBar(title: const Text('Dört. Plus'), centerTitle: true),
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: <Widget>[
                    const PlusWordmark(markSize: 36),
                    const SizedBox(height: 12),
                    const PlusPlanSummary(),
                    const SizedBox(height: 20),
                    Text(
                      'Profil Rozetlerin',
                      style: Theme.of(
                        tester.element(find.byType(Scaffold)),
                      ).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    MarketBadgeStrip(
                      userId: 'demo-ios-user',
                      projected: showcaseBadges,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await _precacheAllImages(tester);
        await tester.pump();
        await _captureScreenshot(tester, '04_badges_showcase_ios.png');
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
