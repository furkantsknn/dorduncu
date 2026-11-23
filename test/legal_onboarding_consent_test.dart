import 'dart:async';

import 'package:dorduncu/legal/legal_service.dart';
import 'package:dorduncu/legal/login_legal_consent.dart';
import 'package:dorduncu/services/language_controller.dart';
import 'package:dorduncu/screens/legal_acceptance_screen.dart';
import 'package:dorduncu/services/session_service.dart';
import 'package:dorduncu/services/user_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  test('all current records are required and bound to the same uid', () {
    Map<String, dynamic> record(String uid, String code) => <String, dynamic>{
      'userId': uid,
      'documentCode': code,
      'version': '1.0.0',
      'source': LegalService.onboardingAcceptanceSource,
      'active': true,
      'acceptedAt': Timestamp.fromMillisecondsSinceEpoch(1),
    };
    final records = <String, Map<String, dynamic>?>{
      for (final code in <String>[
        'terms_of_use',
        'community_rules',
        'age_declaration',
      ])
        code: record('user-a', code),
    };
    expect(
      LegalService.hasValidOnboardingAcceptanceData(
        userId: 'user-a',
        records: records,
      ),
      isTrue,
    );
    records.remove('age_declaration');
    expect(
      LegalService.hasValidOnboardingAcceptanceData(
        userId: 'user-a',
        records: records,
      ),
      isFalse,
    );
    records['age_declaration'] = record('user-b', 'age_declaration');
    expect(
      LegalService.hasValidOnboardingAcceptanceData(
        userId: 'user-a',
        records: records,
      ),
      isFalse,
    );
  });

  test(
    'production session tracker tolerates wrappers, refresh, and reload',
    () {
      final AuthSessionTracker tracker = AuthSessionTracker();
      final AuthSessionBinding binding = tracker.capture(
        userId: 'user-a',
        sessionId: 'session-a',
      );

      // Re-observing the same uid models a new User wrapper, token refresh, or
      // reload within the same Firebase Auth session.
      tracker.observeUserId('user-a');
      expect(
        tracker.matches(
          binding,
          currentUserId: 'user-a',
          currentSessionId: 'session-a',
        ),
        isTrue,
      );

      tracker.observeUserId(null);
      tracker.observeUserId('user-a');
      expect(
        tracker.matches(
          binding,
          currentUserId: 'user-a',
          currentSessionId: 'session-b',
        ),
        isFalse,
      );
    },
  );

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

  testWidgets('failed persistence stays gated and can retry without sign-in', (
    WidgetTester tester,
  ) async {
    var attempts = 0;
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LegalAcceptanceScreen(
          userIdProvider: () => 'user-a',
          recorder: (String uid, String locale) async {
            attempts++;
            if (attempts == 1) throw Exception('network-request-failed');
            if (attempts == 2) throw Exception('permission-denied');
          },
          signOut: () async {},
          onCompleted: () => completed = true,
        ),
      ),
    );
    expect(tester.widget<Checkbox>(find.byType(Checkbox).at(0)).value, isFalse);
    expect(tester.widget<Checkbox>(find.byType(Checkbox).at(1)).value, isFalse);
    await tester.tap(find.byType(Checkbox).at(0));
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(completed, isFalse);
    expect(find.textContaining('kaydedilemedi'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(completed, isFalse);
    expect(find.textContaining('kaydedilemedi'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(attempts, 3);
    expect(completed, isTrue);
  });

  testWidgets('completion is not carried to a different account', (
    WidgetTester tester,
  ) async {
    var uid = 'user-a';
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LegalAcceptanceScreen(
          initiallyConfirmed: true,
          userIdProvider: () => uid,
          recorder: (String recordedUid, String locale) async {
            expect(recordedUid, 'user-a');
            uid = 'user-b';
          },
          signOut: () async {},
          onCompleted: () => completed = true,
        ),
      ),
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(completed, isFalse);
  });

  test(
    'server verification failure is not replaced by cached acceptance',
    () async {
      final Map<String, Map<String, dynamic>> cached =
          <String, Map<String, dynamic>>{};
      for (final document in LegalService.onboardingAcceptanceDocuments()) {
        cached[LegalService.acceptanceDocumentId(
          documentCode: document.code,
          version: document.version,
        )] = <String, dynamic>{
          'userId': 'user-a',
          'documentCode': document.code,
          'version': document.version,
          'source': LegalService.onboardingAcceptanceSource,
          'active': true,
          'acceptedAt': Timestamp.fromMillisecondsSinceEpoch(1),
        };
      }

      expect(
        () => LegalService.validateOnboardingAcceptancesFromServer(
          userId: 'user-a',
          readRecord: (String documentId) async {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'unavailable',
            );
          },
          bindingStillCurrent: () async => true,
        ),
        throwsA(isA<FirebaseException>()),
      );
      expect(cached, isNotEmpty);
    },
  );

  test(
    'AuthControl resolver re-reads expired suspension and gates acceptance',
    () async {
      var refreshes = 0;
      final AuthDestination destination =
          await UserService.resolveLoadedAccountDestination(
            data: <String, dynamic>{
              'accountStatus': 'suspended',
              'suspensionEndsAt': Timestamp.fromDate(DateTime(2025)),
            },
            reloadAccount: () async => <String, dynamic>{
              'accountStatus': 'active',
              'activeSessionId': 'session-a',
            },
            refreshAccountStatus: () async => refreshes++,
            hasCurrentAcceptances: () async => false,
            getLocalSessionId: () async => 'session-a',
            authStillCurrent: () async => true,
            now: () => DateTime(2026),
          );
      expect(refreshes, 1);
      expect(destination.type, AuthDestinationType.legalAcceptanceRequired);
    },
  );

  test('valid accepted account follows normal home path', () async {
    final AuthDestination destination =
        await UserService.resolveLoadedAccountDestination(
          data: <String, dynamic>{
            'accountStatus': 'active',
            'activeSessionId': 'session-a',
            'profilAdi': 'Ada',
          },
          reloadAccount: () async => null,
          refreshAccountStatus: () async {},
          hasCurrentAcceptances: () async => true,
          getLocalSessionId: () async => 'session-a',
          authStillCurrent: () async => true,
        );
    expect(destination.type, AuthDestinationType.home);
    expect(destination.profileName, 'Ada');
  });

  test('unknown status cannot use the default branch to reach home', () async {
    final AuthDestination destination =
        await UserService.resolveLoadedAccountDestination(
          data: <String, dynamic>{'accountStatus': 'future-status'},
          reloadAccount: () async => null,
          refreshAccountStatus: () async {},
          hasCurrentAcceptances: () async => true,
          getLocalSessionId: () async => 'session-a',
          authStillCurrent: () async => true,
        );
    expect(destination.type, AuthDestinationType.suspended);
  });

  testWidgets(
    'timed out save permits safe sign out and late completion is inert',
    (WidgetTester tester) async {
      final Completer<void> save = Completer<void>();
      var signedOut = false;
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: LegalAcceptanceScreen(
            initiallyConfirmed: true,
            userIdProvider: () => 'user-a',
            recorder: (_, _) => save.future,
            signOut: () async => signedOut = true,
            onCompleted: () => completed = true,
            requestTimeout: const Duration(milliseconds: 10),
          ),
        ),
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pump(const Duration(milliseconds: 11));
      expect(find.textContaining('beklenenden uzun'), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(signedOut, isTrue);
      save.complete();
      await tester.pump();
      expect(completed, isFalse);
    },
  );

  testWidgets(
    'account or same-uid session change resets choices and gates completion',
    (WidgetTester tester) async {
      var uid = 'user-a';
      var session = 'session-1';
      final StreamController<String?> changes = StreamController<String?>();
      addTearDown(changes.close);
      final Completer<void> save = Completer<void>();
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: LegalAcceptanceScreen(
            userIdProvider: () => uid,
            sessionIdProvider: () => session,
            bindingChanges: changes.stream,
            recorder: (_, _) => save.future,
            signOut: () async {},
            onCompleted: () => completed = true,
          ),
        ),
      );
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      uid = 'user-b';
      changes.add('user-b:session-1');
      await tester.pump();
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).at(0)).value,
        isFalse,
      );
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).at(1)).value,
        isFalse,
      );

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      session = 'session-2';
      changes.add('user-b:session-2');
      await tester.pump();
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).at(0)).value,
        isFalse,
      );
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).at(1)).value,
        isFalse,
      );

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      uid = 'user-a';
      changes.add('user-a:session-2');
      await tester.pump();
      save.complete();
      await tester.pump();
      expect(completed, isFalse);
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).at(0)).value,
        isFalse,
      );
    },
  );
}
