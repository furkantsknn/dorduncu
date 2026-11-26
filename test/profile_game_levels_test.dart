import 'package:dorduncu/l10n/app_localizations.dart';
import 'package:dorduncu/models/user_model.dart';
import 'package:dorduncu/screens/create_profile_screen.dart';
import 'package:dorduncu/screens/edit_profile_screen.dart';
import 'package:dorduncu/services/session_service.dart';
import 'package:dorduncu/services/user_service.dart';
import 'package:dorduncu/utils/game_catalog.dart';
import 'package:dorduncu/widgets/game_level_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap({
  required Widget child,
  required Locale locale,
  required ThemeMode themeMode,
  double width = 375,
  double textScale = 1.0,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    themeMode: themeMode,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffFF9800),
        brightness: Brightness.light,
      ),
    ),
    darkTheme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffFF9800),
        brightness: Brightness.dark,
      ),
    ),
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 667),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets(
    'Acemi/Orta/Usta selector keeps high contrast on dark onboarding card even under Light Theme',
    (WidgetTester tester) async {
      int level = 30;
      await tester.pumpWidget(
        _wrap(
          locale: const Locale('tr'),
          themeMode: ThemeMode.light,
          width: 320,
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Container(
                color: const Color(0xff1C1F25),
                padding: const EdgeInsets.all(12),
                child: GameLevelSelector(
                  gameId: 'okey',
                  selectedLevel: level,
                  darkSurface: true,
                  onSelected: (SkillLevelDefinition skill) {
                    setState(() => level = skill.value);
                  },
                ),
              );
            },
          ),
        ),
      );

      final Material acemiMat = tester.widget<Material>(
        find.byKey(const ValueKey<String>('game_level_okey_30')),
      );
      final Material ortaMat = tester.widget<Material>(
        find.byKey(const ValueKey<String>('game_level_okey_60')),
      );
      final Material ustaMat = tester.widget<Material>(
        find.byKey(const ValueKey<String>('game_level_okey_90')),
      );

      // Selected chip uses solid orange, unselected uses opaque dark slate
      // (never semi-transparent white over Light Theme surface).
      expect(acemiMat.color, const Color(0xffFF9800));
      expect(ortaMat.color, const Color(0xff252A34));
      expect(ustaMat.color, const Color(0xff252A34));
      expect(acemiMat.color!.a, 1.0);
      expect(ortaMat.color!.a, 1.0);

      // Text contrast: dark text on selected orange, light text on dark slate.
      final Text acemiText = tester.widget<Text>(find.text('Acemi'));
      final Text ortaText = tester.widget<Text>(find.text('Orta'));
      expect(acemiText.style?.color, const Color(0xff111318));
      expect(ortaText.style?.color, const Color(0xffF3F4F6));

      await tester.tap(find.byKey(const ValueKey<String>('game_level_okey_90')));
      await tester.pumpAndSettle();

      expect(level, 90);
      final Material updatedUstaMat = tester.widget<Material>(
        find.byKey(const ValueKey<String>('game_level_okey_90')),
      );
      expect(updatedUstaMat.color, const Color(0xffFF9800));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TR/EN/DE level selectors render cleanly without overflow on 320px iPhone SE with 1.3x text',
    (WidgetTester tester) async {
      for (final ({Locale locale, List<String> labels}) entry
          in <({Locale locale, List<String> labels})>[
            (locale: const Locale('tr'), labels: <String>['Acemi', 'Orta', 'Usta']),
            (
              locale: const Locale('en'),
              labels: <String>['Beginner', 'Intermediate', 'Expert'],
            ),
            (
              locale: const Locale('de'),
              labels: <String>['Anfänger', 'Mittelstufe', 'Experte'],
            ),
          ]) {
        for (final ThemeMode mode in <ThemeMode>[
          ThemeMode.light,
          ThemeMode.dark,
        ]) {
          await tester.pumpWidget(
            _wrap(
              locale: entry.locale,
              themeMode: mode,
              width: 320,
              textScale: 1.3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GameLevelSelector(
                  gameId: 'satranc',
                  selectedLevel: 60,
                  darkSurface: false,
                  onSelected: (_) {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          for (final String label in entry.labels) {
            expect(find.text(label), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'saved per-game levels from onboarding are preserved and editable in EditProfileScreen',
    (WidgetTester tester) async {
      final GameDefinition okey = GameCatalog.gameById('okey')!;
      final GameDefinition satranc = GameCatalog.gameById('satranc')!;
      final Map<String, dynamic> storedProfile = <String, dynamic>{
        'uid': 'user-level-test',
        'ad': 'Deniz',
        'soyad': 'Yılmaz',
        'profilAdi': 'Deniz Y.',
        'sehir': 'İstanbul',
        'oyunlar': <String>[okey.name, satranc.name],
        'gameIds': <String>[okey.id, satranc.id],
        'gameSkills': <String, dynamic>{
          okey.id: <String, dynamic>{
            'gameId': okey.id,
            'gameName': okey.name,
            'categoryId': okey.categoryId,
            'categoryName': GameCatalog.categoryById(okey.categoryId)?.name ?? '',
            'level': 60,
            'levelLabel': GameCatalog.skillLevelForValue(60).label,
          },
          satranc.id: <String, dynamic>{
            'gameId': satranc.id,
            'gameName': satranc.name,
            'categoryId': satranc.categoryId,
            'categoryName':
                GameCatalog.categoryById(satranc.categoryId)?.name ?? '',
            'level': 90,
            'levelLabel': GameCatalog.skillLevelForValue(90).label,
          },
        },
      };

      final UserModel parsed = UserModel.fromMap(storedProfile);
      expect(parsed.gameSkills['okey']?.level, 60);
      expect(parsed.gameSkills['satranc']?.level, 90);

      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          locale: const Locale('tr'),
          themeMode: ThemeMode.light,
          width: 375,
          child: EditProfileScreen(initialData: storedProfile),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('game_level_okey_60')),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      final Semantics okeyOrta = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byKey(const ValueKey<String>('game_level_okey_60')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(okeyOrta.properties.selected, isTrue);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('game_level_satranc_90')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final Semantics satrancUsta = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byKey(const ValueKey<String>('game_level_satranc_90')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(satrancUsta.properties.selected, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  test('ProfileCreationCoordinator records anonymous stage timings', () async {
    final Map<String, int> timings = <String, int>{};
    const AuthSessionBinding binding = AuthSessionBinding(
      userId: 'u1',
      sessionId: 's1',
      authGeneration: 1,
    );

    final AuthDestination? destination =
        await ProfileCreationCoordinator.complete(
          binding: binding,
          isSessionCurrent: (_) async => true,
          readProfileState: () async => ProfileCreationServerState.missing,
          writeProfile: () async {},
          saveSessionMetadata: () async {},
          submitVerification: null,
          resolveDestination: () async =>
              const AuthDestination(type: AuthDestinationType.home),
          onStageTiming: (String stage, int ms) {
            timings[stage] = ms;
          },
        );

    expect(destination?.type, AuthDestinationType.home);
    expect(
      timings.keys,
      containsAll(<String>[
        'read_state',
        'write_profile',
        'save_session',
        'resolve_destination',
      ]),
    );
    expect(timings.containsKey('upload_assets'), isFalse);
    expect(timings.containsKey('finalize_profile'), isFalse);
  });
}
