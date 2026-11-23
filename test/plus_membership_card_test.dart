import 'package:dorduncu/l10n/app_localizations.dart';
import 'package:dorduncu/models/user_model.dart';
import 'package:dorduncu/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(UserModel user) => MaterialApp(
  locale: const Locale('tr'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(
    body: PlusMembershipCard(user: user, onTap: () {}),
  ),
);

UserModel _user({required bool plus, DateTime? expiry, String state = ''}) =>
    UserModel.fromMap(<String, dynamic>{
      'uid': 'plus-state-test',
      'plus': plus,
      'plusExpiresAt': expiry,
      'plusSubscriptionExpiresAt': expiry,
      'plusSubscriptionState': state,
    });

void main() {
  testWidgets('ücretsiz üyelik satış çağrısını gösterir', (tester) async {
    await tester.pumpWidget(_app(_user(plus: false)));
    expect(find.text("Plus'ı keşfet"), findsOneWidget);
    expect(find.text('Aktif değil'), findsNothing);
  });

  testWidgets('aktif üyelik yenilemeyi varsaymadan geçerliliği gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _user(
          plus: true,
          expiry: DateTime.now().add(const Duration(days: 10)),
          state: 'SUBSCRIPTION_STATE_ACTIVE',
        ),
      ),
    );
    expect(find.textContaining('Geçerlilik:'), findsOneWidget);
    expect(find.text('Üyeliği yönet'), findsOneWidget);
    expect(find.textContaining('Sonraki yenileme:'), findsNothing);
  });

  testWidgets('iptal edilmiş fakat süren üyelik aktif bitişini gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _user(
          plus: true,
          expiry: DateTime.now().add(const Duration(days: 5)),
          state: 'SUBSCRIPTION_STATE_CANCELED',
        ),
      ),
    );
    expect(find.textContaining('Şu tarihe kadar aktif:'), findsOneWidget);
    expect(find.text('Üyeliği yönet'), findsOneWidget);
  });

  testWidgets('süresi dolmuş üyelik aktif gösterilmez', (tester) async {
    await tester.pumpWidget(
      _app(
        _user(
          plus: true,
          expiry: DateTime.now().subtract(const Duration(minutes: 1)),
          state: 'SUBSCRIPTION_STATE_CANCELED',
        ),
      ),
    );
    expect(find.text("Plus'ı keşfet"), findsOneWidget);
    expect(find.text('Plus üyeliğin aktif'), findsNothing);
  });
}
