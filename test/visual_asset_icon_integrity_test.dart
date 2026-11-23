import 'dart:convert';
import 'dart:io';

import 'package:dorduncu/utils/game_catalog.dart';
import 'package:dorduncu/utils/game_cover_assets.dart';
import 'package:dorduncu/widgets/game_catalog_icon.dart';
import 'package:dorduncu/widgets/home_bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every catalog game resolves to a real, non-empty cover asset', () {
    expect(GameCoverAssets.byId.keys.toSet(), {
      for (final GameDefinition game in GameCatalog.allGames) game.id,
    });

    for (final GameDefinition game in GameCatalog.allGames) {
      final String? path = GameCoverAssets.pathFor(game.id);
      expect(path, isNotNull, reason: game.id);
      final File file = File(path!);
      expect(file.existsSync(), isTrue, reason: path);
      expect(file.lengthSync(), greaterThan(1024), reason: path);
      final List<int> signature = file.readAsBytesSync().take(8).toList();
      final bool jpeg =
          signature.length >= 3 &&
          signature[0] == 0xff &&
          signature[1] == 0xd8 &&
          signature[2] == 0xff;
      final bool png =
          signature.length == 8 &&
          const ListEquality<int>().equals(signature, const <int>[
            0x89,
            0x50,
            0x4e,
            0x47,
            0x0d,
            0x0a,
            0x1a,
            0x0a,
          ]);
      expect(jpeg || png, isTrue, reason: '$path has an invalid signature');
    }
  });

  test('shared catalog icons use the bundled Material icon family', () {
    for (final GameCategoryDefinition category in GameCatalog.categories) {
      final IconData icon = GameCatalogIcon.iconFor(categoryId: category.id);
      expect(icon.fontFamily, 'MaterialIcons', reason: category.id);
      expect(icon.fontPackage, isNull, reason: category.id);
      expect(icon.codePoint, greaterThan(0), reason: category.id);
    }
  });

  test('reported home-screen icons use the bundled Material icon family', () {
    const Map<String, IconData> icons = <String, IconData>{
      'card date': Icons.calendar_today_rounded,
      'card location': Icons.location_on_rounded,
      'card participants': Icons.group_outlined,
      'marker fallback': Icons.place_rounded,
      'bottom messages': Icons.chat_bubble_outline_rounded,
      'bottom create': Icons.add_rounded,
      'bottom profile': Icons.person_outline_rounded,
    };

    for (final MapEntry<String, IconData> entry in icons.entries) {
      expect(entry.value.fontFamily, 'MaterialIcons', reason: entry.key);
      expect(entry.value.fontPackage, isNull, reason: entry.key);
      expect(entry.value.codePoint, greaterThan(0), reason: entry.key);
    }
  });

  testWidgets('production home navigation exposes the three expected icons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: HomeBottomNavigation(
            messageTooltip: 'Messages',
            profileTooltip: 'Profile',
            onMessages: () {},
            onCreateEvent: () {},
            onProfile: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
  });

  test('TR EN DE localization catalogs have matching non-empty keys', () {
    Map<String, dynamic> read(String language) =>
        jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
            as Map<String, dynamic>;

    final Map<String, dynamic> tr = read('tr');
    final Set<String> keys = tr.keys
        .where((String key) => !key.startsWith('@'))
        .toSet();
    for (final String language in <String>['en', 'de']) {
      final Map<String, dynamic> values = read(language);
      expect(
        values.keys.where((String key) => !key.startsWith('@')).toSet(),
        keys,
        reason: language,
      );
      for (final String key in keys) {
        expect(
          values[key].toString().trim(),
          isNotEmpty,
          reason: '$language:$key',
        );
      }
    }
  });

  testWidgets('shared icon remains visible in themes and large text', (
    WidgetTester tester,
  ) async {
    for (final Brightness brightness in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness, useMaterial3: true),
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Center(
              child: GameCatalogIcon(gameIdOrName: 'futbol', size: 32),
            ),
          ),
        ),
      );
      expect(find.byType(Icon), findsOneWidget);
      expect(tester.getSize(find.byType(Icon)), const Size(32, 32));
      expect(tester.takeException(), isNull);
    }
  });
}

class ListEquality<T> {
  const ListEquality();

  bool equals(List<T> left, List<T> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }
}
