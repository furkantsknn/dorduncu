const int freeEventDayOffset = 0;

/// Turkey civil time is UTC+3. Europe/Istanbul has not used DST since 2016.
const Duration istanbulUtcOffset = Duration(hours: 3);

enum EventScheduleDecision { ok, past, freeNotToday }

int istanbulDayNumber(DateTime instant) {
  final DateTime civil = instant.toUtc().add(istanbulUtcOffset);
  return DateTime.utc(
        civil.year,
        civil.month,
        civil.day,
      ).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
}

DateTime istanbulCivilDate(DateTime instant) {
  final DateTime civil = instant.toUtc().add(istanbulUtcOffset);
  return DateTime(civil.year, civil.month, civil.day);
}

/// Interprets the picked clock as Europe/Istanbul, not the device zone.
DateTime instantFromIstanbulCivil({
  required int year,
  required int month,
  required int day,
  required int hour,
  required int minute,
}) {
  return DateTime.utc(
    year,
    month,
    day,
    hour,
    minute,
  ).subtract(istanbulUtcOffset);
}

EventScheduleDecision evaluateEventSchedule({
  required DateTime startAt,
  required DateTime now,
  required bool plusActive,
}) {
  if (!startAt.toUtc().isAfter(now.toUtc())) {
    return EventScheduleDecision.past;
  }

  final int dayOffset = istanbulDayNumber(startAt) - istanbulDayNumber(now);
  if (dayOffset < 0) {
    return EventScheduleDecision.past;
  }

  if (!plusActive && dayOffset > freeEventDayOffset) {
    return EventScheduleDecision.freeNotToday;
  }

  return EventScheduleDecision.ok;
}
