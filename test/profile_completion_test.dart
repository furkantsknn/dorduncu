import 'package:dorduncu/l10n/app_localizations.dart';
import 'package:dorduncu/models/user_model.dart';
import 'package:dorduncu/screens/edit_profile_screen.dart';
import 'package:dorduncu/screens/profile_screen.dart';
import 'package:dorduncu/utils/profile_completion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

UserModel _user({
  String profilAdi = 'Ece',
  String ad = '',
  String soyad = '',
  String photo = 'https://example.com/a.jpg',
  String about = 'Merhaba',
  String city = 'İstanbul',
  String activeCity = '',
  bool games = true,
  bool playerBadge = false,
  bool verified = false,
  bool plus = false,
}) {
  return UserModel.fromMap(<String, dynamic>{
    'uid': 'completion-user',
    'ad': ad,
    'soyad': soyad,
    'profilAdi': profilAdi,
    'profilFotografi': photo,
    'hakkimda': about,
    'sehir': city,
    'aktifSehir': activeCity,
    'oyuncuRozeti': playerBadge,
    'verified': verified,
    'plus': plus,
    if (games)
      'gameSkills': <String, Map<String, dynamic>>{
        'okey': <String, dynamic>{
          'gameId': 'okey',
          'gameName': 'Okey',
          'level': 60,
          'levelLabel': 'Orta',
        },
      },
  });
}

void main() {
  test('complete profile is 100 without verification or a purchase', () {
    final ProfileCompletion completion = profileCompletionOf(
      _user(playerBadge: false, verified: false, plus: false),
    );

    expect(completion.percent, 100);
    expect(completion.missingActions, isEmpty);
    expect(completion.checks.length, 5);
    expect(completion.checks.containsKey(ProfileCompletionField.name), isTrue);
    expect(
      ProfileCompletionField.values.map((ProfileCompletionField field) {
        return field.name;
      }),
      isNot(contains('playerBadge')),
    );
  });

  test('stored name counts and the Kullanıcı fallback does not', () {
    expect(
      profileCompletionOf(
        _user(profilAdi: '   ', ad: '', soyad: ''),
      ).isComplete(ProfileCompletionField.name),
      isFalse,
    );
    expect(
      profileCompletionOf(
        _user(profilAdi: '', ad: 'Ada', soyad: 'Yılmaz'),
      ).isComplete(ProfileCompletionField.name),
      isTrue,
    );
  });

  test('home event filter does not complete the profile city', () {
    final ProfileCompletion filtered = profileCompletionOf(
      _user(city: '', activeCity: 'Ankara'),
    );
    final ProfileCompletion profileCity = profileCompletionOf(
      _user(city: 'İstanbul', activeCity: 'Ankara'),
    );

    expect(filtered.isComplete(ProfileCompletionField.city), isFalse);
    expect(filtered.missingActions, contains(ProfileCompletionField.city));
    expect(profileCity.isComplete(ProfileCompletionField.city), isTrue);
  });

  test('missing fields come from the same five checks', () {
    final ProfileCompletion completion = profileCompletionOf(
      _user(profilAdi: '', photo: '', about: '', city: '', games: false),
    );

    expect(completion.percent, 0);
    expect(completion.missingActions, ProfileCompletionField.values);
  });

  test('editor patch writes profile city and name, not the event filter', () {
    final Map<String, dynamic> patch = profileEditorPatch(
      name: ' Ece ',
      city: 'Bursa',
      previousCity: 'İstanbul',
      photoUrl: 'https://example.com/a.jpg',
      avatarUrl: '',
      about: 'Merhaba',
      gameNames: <String>['Okey'],
      gameIds: <String>['okey'],
      gameSkills: <String, dynamic>{'okey': <String, dynamic>{}},
    );

    expect(patch['profilAdi'], 'Ece');
    expect(patch['sehir'], 'Bursa');
    expect(patch['ilce'], '');
    expect(patch.containsKey('aktifSehir'), isFalse);
    expect(patch.containsKey('oyuncuRozeti'), isFalse);
    expect(patch.containsKey('verified'), isFalse);
    expect(patch.containsKey('plus'), isFalse);
  });

  test('unchanged profile city does not clear the district', () {
    final Map<String, dynamic> patch = profileEditorPatch(
      name: '',
      city: 'İstanbul',
      previousCity: 'İstanbul',
      photoUrl: '',
      avatarUrl: '',
      about: '',
      gameNames: <String>['Okey'],
      gameIds: <String>['okey'],
      gameSkills: <String, dynamic>{},
    );

    expect(patch.containsKey('profilAdi'), isFalse);
    expect(patch['sehir'], 'İstanbul');
    expect(patch.containsKey('ilce'), isFalse);
  });

  testWidgets('every missing field opens profile editing', (
    WidgetTester tester,
  ) async {
    final List<ProfileCompletionField> opened = <ProfileCompletionField>[];
    var verifies = 0;

    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: ProfileScreenView(
          user: _user(profilAdi: '', ad: '', soyad: '', photo: '', city: ''),
          onRefresh: () async {},
          onEdit: () {},
          onEditField: opened.add,
          onSettings: () {},
          onFriends: () {},
          onFriendRequests: () {},
          onUserSearch: () {},
          onMarket: () {},
          onVerify: () => verifies++,
          onBadges: () {},
          onPublicProfile: () {},
          onLogout: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('%40'), 400);

    expect(find.text('%40'), findsOneWidget);

    for (final String label in <String>['İsim', 'Profil fotoğrafı', 'Şehir']) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pump();
    }

    expect(opened, <ProfileCompletionField>[
      ProfileCompletionField.name,
      ProfileCompletionField.photo,
      ProfileCompletionField.city,
    ]);
    expect(verifies, 0);
    expect(find.textContaining('ödül'), findsNothing);
    expect(find.textContaining('ayrıcalık'), findsNothing);
  });

  testWidgets('edit screen shows the profile city, not the event filter', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: EditProfileScreen(
          focus: ProfileCompletionField.city,
          initialData: <String, dynamic>{
            'uid': 'completion-user',
            'profilAdi': '',
            'ad': 'Ada',
            'soyad': 'Yılmaz',
            'sehir': 'İstanbul',
            'aktifSehir': 'Ankara',
            'ilce': 'Kadıköy',
            'hakkimda': '',
            'gameSkills': <String, dynamic>{},
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('İstanbul'), findsOneWidget);
    expect(find.text('Ankara'), findsNothing);
    final Iterable<String> fieldValues = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((TextField field) => field.controller?.text ?? '');
    expect(fieldValues, contains('Ada Yılmaz'));
  });

  testWidgets('large text keeps menu titles without overflow', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 2400),
            textScaler: TextScaler.linear(1.8),
          ),
          child: ProfileScreenView(
            user: _user(photo: ''),
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
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.text('My Friends'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Find a player'), 400);
    expect(find.text('Find a player'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Profile photo'), 400);
    expect(find.text('Profile photo'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sign out of account'), 400);
    expect(tester.takeException(), isNull);
  });
}
