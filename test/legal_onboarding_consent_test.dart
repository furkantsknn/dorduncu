import 'package:dorduncu/legal/legal_service.dart';
import 'package:dorduncu/legal/login_legal_consent.dart';
import 'package:dorduncu/services/language_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('login records terms, community rules, and age only', () {
    final List<String> recorded = LegalService.onboardingAcceptanceDocuments()
        .map((document) => document.code)
        .toList();
    final List<String> informational =
        LegalService.onboardingInformationDocuments()
            .map((document) => document.code)
            .toList();

    expect(recorded, <String>[
      'terms_of_use',
      'community_rules',
      'age_declaration',
    ]);
    expect(informational, <String>['kvkk_notice', 'privacy_policy']);

    for (final document in LegalService.onboardingAcceptanceDocuments()) {
      expect(document.isMandatory, isTrue);
      expect(document.version, '1.0.0');
      expect(
        LegalService.requiresNewAcceptance(documentCode: document.code),
        isTrue,
      );
    }

    for (final document in LegalService.onboardingInformationDocuments()) {
      expect(document.isInformational, isTrue);
      expect(document.requiresAcceptance, isFalse);
      expect(
        LegalService.requiresNewAcceptance(documentCode: document.code),
        isFalse,
      );
    }
  });

  testWidgets('document links do not check the boxes', (
    WidgetTester tester,
  ) async {
    String? opened;
    bool terms = false;
    bool age = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return LoginLegalConsent(
                termsAccepted: terms,
                ageDeclared: age,
                language: AppLanguage.turkish,
                onTermsChanged: (bool value) {
                  setState(() {
                    terms = value;
                  });
                },
                onAgeChanged: (bool value) {
                  setState(() {
                    age = value;
                  });
                },
                onOpenDocument: (String code) {
                  opened = code;
                },
              );
            },
          ),
        ),
      ),
    );

    Checkbox checkbox(int index) {
      return tester.widget<Checkbox>(find.byType(Checkbox).at(index));
    }

    expect(checkbox(0).value, isFalse);
    expect(checkbox(1).value, isFalse);

    void tapLink(String label) {
      final RichText richText = tester.widget<RichText>(
        find.byWidgetPredicate((Widget widget) {
          return widget is RichText &&
              widget.text.toPlainText().contains(label);
        }),
      );
      var found = false;
      richText.text.visitChildren((InlineSpan span) {
        if (span is TextSpan &&
            span.text == label &&
            span.recognizer is TapGestureRecognizer) {
          (span.recognizer! as TapGestureRecognizer).onTap?.call();
          found = true;
          return false;
        }
        return true;
      });
      expect(found, isTrue);
    }

    tapLink('Kullanım Koşulları');
    await tester.pump();
    expect(opened, 'terms_of_use');
    expect(checkbox(0).value, isFalse);

    tapLink('Topluluk Kuralları');
    await tester.pump();
    expect(opened, 'community_rules');
    expect(checkbox(0).value, isFalse);

    tapLink('KVKK Aydınlatma Metni');
    await tester.pump();
    expect(opened, 'kvkk_notice');
    expect(checkbox(0).value, isFalse);
    expect(checkbox(1).value, isFalse);

    tapLink('Gizlilik Politikası');
    await tester.pump();
    expect(opened, 'privacy_policy');
    expect(checkbox(0).value, isFalse);

    await tester.tap(find.byType(Checkbox).at(0));
    await tester.pump();
    expect(checkbox(0).value, isTrue);
    expect(checkbox(1).value, isFalse);

    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();
    expect(checkbox(1).value, isTrue);
  });

  testWidgets('consent text wraps on a small screen with large text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: Scaffold(
          body: LoginLegalConsent(
            termsAccepted: false,
            ageDeclared: false,
            language: AppLanguage.german,
            onTermsChanged: (_) {},
            onAgeChanged: (_) {},
            onOpenDocument: (_) {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Nutzungsbedingungen'), findsOneWidget);
    expect(find.textContaining('Datenschutzhinweis'), findsOneWidget);
    expect(find.textContaining('18. Lebensjahr'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
