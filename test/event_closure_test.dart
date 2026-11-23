import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dorduncu/models/event_closure.dart';

void main() {
  final now = DateTime.utc(2026, 10, 28, 12);
  test(
    'elapsed time, proven completion, cancellation and legacy are distinct',
    () {
      expect(
        eventClosure({'status': 'active', 'endAt': now}, now: now),
        EventClosure.expired,
      );
      expect(
        eventClosure({'status': 'completed'}, now: now),
        EventClosure.legacyClosed,
      );
      expect(
        eventClosure({
          'status': 'completed',
          'closureReason': 'occurred_confirmed',
        }, now: now),
        EventClosure.confirmed,
      );
      expect(
        eventClosure({'status': 'cancelled', 'endAt': now}, now: now),
        EventClosure.cancelled,
      );
      expect(
        eventClosure({
          'status': 'active',
          'endAt': now.add(const Duration(seconds: 1)),
        }, now: now),
        EventClosure.active,
      );
      expect(
        eventClosure({
          'status': 'expired',
          'closureReason': 'time_elapsed',
        }, now: now),
        EventClosure.expired,
      );
    },
  );
  testWidgets('all closure meanings have TR EN DE labels', (tester) async {
    for (final language in ['tr', 'en', 'de']) {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          supportedLocales: const [Locale('tr'), Locale('en'), Locale('de')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(
            builder: (context) {
              for (final state in EventClosure.values) {
                expect(eventClosureLabel(context, state), isNotEmpty);
              }
              return const SizedBox();
            },
          ),
        ),
      );
    }
  });
}
