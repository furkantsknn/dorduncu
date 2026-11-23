import 'dart:io';
import 'package:dorduncu/admin/admin_ui.dart';
import 'package:dorduncu/widgets/market_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const String _fontRoot =
    r'C:\Users\FURKAN\Documents\flutter\bin\cache\artifacts\material_fonts';

Future<void> _loadFonts() async {
  for (final MapEntry<String, List<String>> family in <String, List<String>>{
    'Roboto': <String>[
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
    ],
    'MaterialIcons': <String>['materialicons-regular.otf'],
  }.entries) {
    final FontLoader loader = FontLoader(family.key);
    for (final String name in family.value) {
      final Uint8List bytes = await File('$_fontRoot\\$name').readAsBytes();
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

Future<void> _save(WidgetTester tester, String name) async {
  await expectLater(
    find.byKey(const Key('adminPreviewBoundary')),
    matchesGoldenFile('../docs/previews/admin/$name.png'),
  );
}

ThemeData _theme() {
  const Color background = Color(0xff0F1115);
  const Color surface = Color(0xff1C2028);
  const Color line = Color(0xff343A46);
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xffFF9800),
    brightness: Brightness.dark,
    surface: surface,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: line),
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

Widget _app(Widget child, double scale) => MaterialApp(
  theme: _theme(),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(
      body: RepaintBoundary(
        key: const Key('adminPreviewBoundary'),
        child: SafeArea(child: child),
      ),
    ),
  ),
);

Widget _page(String title, String description, List<Widget> children) =>
    Builder(
      builder: (BuildContext context) => ColoredBox(
        color: MarketPalette.of(context).background,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            AdminPageIntro(
              title: title,
              description: description,
              icon: Icons.admin_panel_settings_outlined,
            ),
            const SizedBox(height: 8),
            ...children.map(
              (Widget child) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );

AdminSectionCard _record({
  required String title,
  required String id,
  required String status,
  AdminStatusTone tone = AdminStatusTone.neutral,
  IconData icon = Icons.person_outline,
}) => AdminSectionCard(
  title: title,
  icon: icon,
  trailing: AdminStatusBadge(label: status, tone: tone),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      AdminCopyableId(label: 'Kimlik', value: id),
      const SizedBox(height: 8),
      const Text(
        'İşlem ayrıntıları, yardımcı açıklama ve yetkiye göre kullanılabilir eylemler.',
      ),
    ],
  ),
);

void main() {
  setUpAll(_loadFonts);
  final Map<String, Widget> pages = <String, Widget>{
    'dashboard': _page(
      'Yönetim paneli',
      'Yetkin olan alanlara hızlı ve güvenli erişim.',
      <Widget>[
        _record(
          title: 'Kullanıcılar',
          id: 'users',
          status: '1.248 kayıt',
          tone: AdminStatusTone.success,
          icon: Icons.people_outline,
        ),
        _record(
          title: 'Play satışları',
          id: 'commercial_operations',
          status: 'İncele',
          icon: Icons.receipt_long_outlined,
        ),
      ],
    ),
    'user_detail': _page(
      'Kullanıcı detayı',
      'Rol, üyelik, hesap durumu ve rozet işlemleri.',
      <Widget>[
        _record(
          title: 'Hesap ve roller',
          id: 'u_very_long_firebase_identifier_123456789',
          status: 'Aktif',
          tone: AdminStatusTone.success,
        ),
        _record(
          title: 'Oyun rozetleri',
          id: 'okey',
          status: 'Sahip',
          tone: AdminStatusTone.success,
          icon: Icons.military_tech_outlined,
        ),
      ],
    ),
    'badge_management': _page(
      'Rozet yönetimi',
      'Verme ve kaldırma işlemleri gerekçe ve audit kaydıyla yürütülür.',
      <Widget>[
        _record(
          title: 'Okey',
          id: 'dort_badge_okey',
          status: 'Kaldırma tehlikeli',
          tone: AdminStatusTone.danger,
          icon: Icons.shield_outlined,
        ),
      ],
    ),
    'verification': _page(
      'Kimlik doğrulama başvurusu',
      'Belge durumunu incele ve gerekçeli karar ver.',
      <Widget>[
        _record(
          title: 'Başvuru bilgileri',
          id: 'verification_application_2026_very_long',
          status: 'Bekliyor',
          tone: AdminStatusTone.warning,
          icon: Icons.verified_user_outlined,
        ),
      ],
    ),
    'play_mapping': _page(
      'Play ürün eşlemesi',
      'Boş kaydedilen alan yalnız ilgili eşlemeyi siler.',
      <Widget>[
        _record(
          title: 'Kişisel satın alma',
          id: 'dort_badge_okey · standard',
          status: 'Bağlı',
          tone: AdminStatusTone.success,
          icon: Icons.person_outline,
        ),
        _record(
          title: 'Hediye',
          id: 'dort_gift_badge_okey · buy',
          status: 'Bağlı',
          tone: AdminStatusTone.success,
          icon: Icons.card_giftcard_outlined,
        ),
      ],
    ),
  };

  for (final MapEntry<String, Widget> page in pages.entries) {
    for (final double scale in <double>[1, 1.6]) {
      testWidgets('${page.key} ${scale == 1 ? 'normal' : 'large'} render', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(_app(page.value, scale));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await _save(tester, '${page.key}_${scale == 1 ? 'normal' : 'large'}');
      });
    }
  }
}
