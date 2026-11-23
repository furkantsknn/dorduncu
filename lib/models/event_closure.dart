import 'package:flutter/widgets.dart';
import 'event_model.dart';

enum EventClosure {
  active,
  expired,
  confirmed,
  legacyClosed,
  cancelled,
  hidden,
}

EventClosure eventClosure(Map<String, dynamic> data, {DateTime? now}) {
  final status = (data['status'] ?? data['durum'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  if (const {'cancelled', 'canceled', 'iptal', 'iptal_edildi'}.contains(status)) {
    return EventClosure.cancelled;
  }
  if (const {'hidden', 'removed', 'deleted'}.contains(status)) {
    return EventClosure.hidden;
  }
  if (const {
    'completed',
    'tamamlandi',
    'tamamlandı',
    'finished',
    'closed',
  }.contains(status)) {
    return data['closureReason'] == 'occurred_confirmed'
        ? EventClosure.confirmed
        : EventClosure.legacyClosed;
  }
  if (status == 'expired' ||
      data['closureReason'] == 'time_elapsed' ||
      (EventModel.mapEndAt(data)?.isAfter(now ?? DateTime.now()) == false)) {
    return EventClosure.expired;
  }
  return EventClosure.active;
}

String eventClosureLabel(BuildContext context, EventClosure state) {
  final language = Localizations.localeOf(context).languageCode;
  final labels = <EventClosure, List<String>>{
    EventClosure.active: ['Aktif', 'Active', 'Aktiv'],
    EventClosure.expired: ['Tarihi geçti', 'Expired', 'Abgelaufen'],
    EventClosure.confirmed: ['Tamamlandı', 'Completed', 'Abgeschlossen'],
    EventClosure.legacyClosed: [
      'Geçmiş kayıt',
      'Past record',
      'Vergangener Eintrag',
    ],
    EventClosure.cancelled: ['İptal edildi', 'Cancelled', 'Abgesagt'],
    EventClosure.hidden: ['Gizli', 'Hidden', 'Ausgeblendet'],
  };
  return labels[state]![language == 'en'
      ? 1
      : language == 'de'
      ? 2
      : 0];
}
