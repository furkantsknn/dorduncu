import 'dart:io';
import 'dart:ui' as ui;

import 'package:dorduncu/screens/event_chat_screen.dart';
import 'package:dorduncu/screens/messages_screen.dart';
import 'package:dorduncu/screens/notification_center_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const String _fontRoot =
    r'C:\Users\FURKAN\Documents\flutter\bin\cache\artifacts\material_fonts';

Future<void> _loadFonts() async {
  for (final MapEntry<String, List<String>> entry in <String, List<String>>{
    'Roboto': <String>[
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
    ],
    'MaterialIcons': <String>['materialicons-regular.otf'],
  }.entries) {
    final FontLoader loader = FontLoader(entry.key);
    for (final String name in entry.value) {
      final bytes = await File('$_fontRoot\\$name').readAsBytes();
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

Future<void> _save(WidgetTester tester, String name) async {
  final RenderRepaintBoundary boundary = tester.renderObject(
    find.byType(RepaintBoundary).first,
  );
  final ui.Image image = await boundary.toImage(pixelRatio: 2);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final File file = File('docs/previews/communication/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(data!.buffer.asUint8List());
}

Widget _app(Widget child, double scale) => MaterialApp(
  theme: ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xffFF9800),
      brightness: Brightness.dark,
    ),
  ),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: Scaffold(body: RepaintBoundary(child: child)),
    ),
  ),
);

void main() {
  setUpAll(_loadFonts);
  testWidgets(
    'gerçek iletişim bileşenleri normal ve büyük yazıda render olur',
    (tester) async {
      Future<void> render(String name, Widget body, double scale) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 640);
        await tester.pumpWidget(_app(body, scale));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() => _save(tester, name));
      }

      await render('messages_normal', buildMessagesDesignPreview(), 1);
      await render('messages_large_text', buildMessagesDesignPreview(), 1.5);
      await render(
        'notifications_normal',
        buildNotificationsDesignPreview(),
        1,
      );
      await render(
        'notifications_large_text',
        buildNotificationsDesignPreview(),
        1.5,
      );
      await render('event_chat_normal', buildEventChatDesignPreview(), 1);
      await render('event_chat_large_text', buildEventChatDesignPreview(), 1.5);

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );
}
