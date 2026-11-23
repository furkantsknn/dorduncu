import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dorduncu/home_v2/event_card_carousel.dart';
import 'package:dorduncu/home_v2/featured_event_card.dart';
import 'package:dorduncu/home_v2/home_event_map.dart';
import 'package:dorduncu/home_v2/home_listed_event.dart';
import 'package:dorduncu/home_v2/home_screen_v2.dart';
import 'package:dorduncu/utils/game_cover_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'market_visual_preview_test.dart' show loadPreviewFonts;

HomeListedEvent _event(String gameId, String gameName) {
  return HomeListedEvent.fromMap('preview-$gameId', <String, dynamic>{
    'gameId': gameId,
    'gameName': gameName,
    'sehir': 'İstanbul',
    'ilce': 'Kadıköy',
    'olusturanUid': 'host',
    'katilanlar': <String>['host', 'guest'],
    'playerCount': 4,
    'startAt': Timestamp.fromDate(DateTime(2026, 10, 10, 19, 30)),
    'approxLatitude': 40.99,
    'approxLongitude': 29.03,
  });
}

HomeListedEvent _homeEvent(String id, String gameId, String district) {
  final DateTime now = DateTime.now();
  return HomeListedEvent.fromMap(id, <String, dynamic>{
    'gameId': gameId,
    'sehir': 'İstanbul',
    'ilce': district,
    'olusturanUid': 'host',
    'katilanlar': <String>['host'],
    'playerCount': 1,
    'startAt': Timestamp.fromDate(
      DateTime(now.year, now.month, now.day, 20, 30),
    ),
    'approxLatitude': 41.02,
    'approxLongitude': 29.05,
  });
}

Widget _homeScene(List<HomeListedEvent> events, double scale) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffFF9800),
        brightness: Brightness.dark,
        surface: const Color(0xff111318),
      ),
      scaffoldBackgroundColor: const Color(0xff0F1115),
    ),
    builder: (BuildContext context, Widget? child) => RepaintBoundary(
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
    ),
    home: Scaffold(
      body: SafeArea(
        child: HomeScreenV2(
          greeting: 'Merhaba, Furkan',
          cityLabel: 'İstanbul',
          categories: const <String>['Tümü', 'Futbol', 'Basketbol', 'Tenis'],
          selectedCategory: 'Tümü',
          onCategorySelected: (_) {},
          onSelectCity: () {},
          onCreateEvent: () {},
          onExplore: () {},
          events: events,
          activeEvents: events,
        ),
      ),
    ),
  );
}

Future<void> _save(WidgetTester tester, String name) async {
  final RenderRepaintBoundary boundary = tester.renderObject(
    find.byType(RepaintBoundary).first,
  );
  final ui.Image image = await boundary.toImage(pixelRatio: 2);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  final File file = File('docs/previews/home/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(data!.buffer.asUint8List());
}

Future<void> _precacheImages(WidgetTester tester) async {
  final Iterable<Element> images = find.byType(Image).evaluate().toList();
  await tester.runAsync(() async {
    for (final Element element in images) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump();
}

ThemeData _theme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xffFF9800),
      brightness: Brightness.dark,
    ),
  );
}

Widget _cardRow(HomeListedEvent left, HomeListedEvent right) {
  return SizedBox(
    height: 214,
    child: Row(
      children: <Widget>[
        Expanded(
          child: FeaturedEventCard(event: left, onTap: () {}),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FeaturedEventCard(event: right, onTap: () {}),
        ),
      ],
    ),
  );
}

Widget _scene(double scale, List<HomeListedEvent> events) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _theme(),
    home: Builder(
      builder: (BuildContext context) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            backgroundColor: const Color(0xff0F1115),
            body: RepaintBoundary(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  _cardRow(events[0], events[1]),
                  const SizedBox(height: 10),
                  _cardRow(events[2], events[3]),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      for (final HomeListedEvent event in events)
                        SizedBox(
                          width: 46,
                          height: 46,
                          child: HomeEventPhotoMarker(
                            assetPath: event.imageAsset,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadPreviewFonts);

  test('31 oyunun tamamı ayrı kapak görseline eşlenir', () {
    expect(GameCoverAssets.byId, hasLength(31));
    for (final MapEntry<String, String> entry in GameCoverAssets.byId.entries) {
      expect(
        GameCoverAssets.pathFor(entry.key),
        entry.value,
        reason: entry.key,
      );
      expect(entry.value, startsWith('assets/images/games/'));
      expect(File(entry.value).existsSync(), isTrue, reason: entry.value);
    }
    expect(
      _event('futbol', 'Futbol').imageAsset,
      GameCoverAssets.byId['futbol'],
    );
  });

  testWidgets('ana sayfa kartları ve marker eski fotoğraflarla çizilir', (
    WidgetTester tester,
  ) async {
    final List<HomeListedEvent> events = <HomeListedEvent>[
      _event('okey', 'Okey'),
      _event('futbol', 'Futbol'),
      _event('tavla', 'Tavla'),
      _event('satranc', 'Satranç'),
    ];

    for (final (String name, Size size, double scale)
        in <(String, Size, double)>[
          ('cards_normal', const Size(390, 600), 1),
          ('cards_large_text', const Size(320, 760), 1.6),
        ]) {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = Size(size.width * 2, size.height * 2);
      await tester.pumpWidget(_scene(scale, events));
      await tester.pump();
      await _precacheImages(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsNWidgets(8));
      await tester.runAsync(() => _save(tester, name));
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('harita önizlemesi oyun fotoğrafını gösterir', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(390 * 2, 760 * 2);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final HomeListedEvent event = _event('okey_101', '101 Okey');
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _theme(),
        builder: (BuildContext context, Widget? child) =>
            RepaintBoundary(child: child),
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              backgroundColor: const Color(0xff0F1115),
              body: Center(
                child: TextButton(
                  onPressed: () => showHomeEventPreview(context, event),
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await _precacheImages(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
    await tester.runAsync(() => _save(tester, 'map_preview_sheet'));
  });

  testWidgets('ana ekran: kart ölçüsü etkinlik sayısından bağımsız', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.reset);
    final Directory tileCache = Directory.systemTemp.createTempSync('tiles');
    addTearDown(() async {
      try {
        await tileCache.delete(recursive: true);
      } on FileSystemException {
        // The map cache can still hold the folder open on Windows.
      }
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => tileCache.path,
    );
    final List<HomeListedEvent> five = <HomeListedEvent>[
      _homeEvent('e0', 'okey', 'Çekmeköy'),
      _homeEvent('e1', 'okey', 'Çekmeköy'),
      _homeEvent('e2', 'batak', 'Ataşehir'),
      _homeEvent('e3', 'futbol', 'Beşiktaş'),
      _homeEvent('e4', 'jenga', 'Kadıköy'),
    ];
    final List<HomeListedEvent> two = <HomeListedEvent>[
      _homeEvent('t0', 'okey', 'Çekmeköy'),
      _homeEvent('t1', 'tavla', 'Fatih'),
    ];

    Future<void> render(
      String name,
      List<HomeListedEvent> events,
      Size size,
      double scale,
    ) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = Size(size.width * 2, size.height * 2);
      tester.view.padding = const FakeViewPadding(top: 33 * 2);
      await tester.pumpWidget(_homeScene(events, scale));
      await tester.pump();
      final BuildContext context = tester.element(find.byType(HomeScreenV2));
      await tester.runAsync(() async {
        for (final String path in <String>[
          for (final HomeListedEvent event in events) ?event.imageAsset,
        ]) {
          await precacheImage(AssetImage(path), context);
        }
      });
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() => _save(tester, name));
    }

    const Size phone = Size(393, 851);

    await render('home_two_events', two, phone, 1);
    expect(find.byType(FeaturedEventCard), findsNWidgets(2));
    final Size twoCard = tester.getSize(find.byType(FeaturedEventCard).first);
    expect(
      find.descendant(
        of: find.byType(CircleAvatar),
        matching: find.byIcon(Icons.person_rounded),
      ),
      findsOneWidget,
    );

    await render('home_five_events', five, phone, 1);
    expect(find.byType(FeaturedEventCard), findsNWidgets(5));
    final Size fiveCard = tester.getSize(find.byType(FeaturedEventCard).first);
    expect(twoCard, fiveCard);
    expect(fiveCard.width, closeTo((393 - 74) / 2, 0.5));
    expect(fiveCard.height, closeTo(175, 0.5));
    final Rect peek = tester.getRect(find.byType(FeaturedEventCard).last);
    expect(peek.left, lessThan(phone.width));
    expect(peek.right, greaterThan(phone.width));

    await render(
      'home_five_events_large_text',
      five,
      const Size(393, 1100),
      1.6,
    );
    final Size largeCard = tester.getSize(find.byType(FeaturedEventCard).first);
    expect(largeCard.height, greaterThan(fiveCard.height));
    expect(
      homeEventCardSize(393, TextScaler.noScaling),
      Size((393 - 74) / 2, 175),
    );
  });
}
