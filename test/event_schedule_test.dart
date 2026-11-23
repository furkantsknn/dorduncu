import 'package:dorduncu/services/event_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 10, 8, 21, 5);
  final DateTime laterToday = DateTime.utc(2026, 10, 8, 21, 30);
  final DateTime tomorrow = DateTime.utc(2026, 10, 9, 21, 30);
  final DateTime plusSeven = DateTime.utc(2026, 10, 16, 9);
  final DateTime plusEight = DateTime.utc(2026, 10, 17, 9);

  test('ücretsiz üyelik yarını reddeder', () {
    expect(
      evaluateEventSchedule(startAt: tomorrow, now: now, plusActive: false),
      EventScheduleDecision.freeNotToday,
    );
  });

  test('aktif Plus 7 ve 365 günden ileri geçerli tarihleri kabul eder', () {
    expect(
      evaluateEventSchedule(startAt: plusSeven, now: now, plusActive: true),
      EventScheduleDecision.ok,
    );
    expect(
      evaluateEventSchedule(startAt: plusEight, now: now, plusActive: true),
      EventScheduleDecision.ok,
    );
    expect(
      evaluateEventSchedule(
        startAt: now.add(const Duration(days: 500)),
        now: now,
        plusActive: true,
      ),
      EventScheduleDecision.ok,
    );
  });

  test('İstanbul gece yarısı sınırı', () {
    final DateTime beforeMidnight = DateTime.utc(2026, 10, 8, 20, 50);
    final DateTime afterMidnight = DateTime.utc(2026, 10, 8, 21, 20);

    expect(
      evaluateEventSchedule(startAt: laterToday, now: now, plusActive: false),
      EventScheduleDecision.ok,
    );
    expect(
      evaluateEventSchedule(
        startAt: afterMidnight,
        now: beforeMidnight,
        plusActive: false,
      ),
      EventScheduleDecision.freeNotToday,
    );
  });

  test('geçmiş saat reddedilir', () {
    expect(
      evaluateEventSchedule(
        startAt: now.subtract(const Duration(minutes: 1)),
        now: now,
        plusActive: true,
      ),
      EventScheduleDecision.past,
    );
  });
}
