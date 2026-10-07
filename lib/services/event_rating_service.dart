import 'package:cloud_functions/cloud_functions.dart';

class EventRatingTargetState {
  const EventRatingTargetState({
    required this.targetUid,
    required this.submitted,
    this.rating,
    this.comment = '',
  });

  final String targetUid;
  final bool submitted;
  final int? rating;
  final String comment;

  factory EventRatingTargetState.fromMap(
    Map<String, dynamic> data,
  ) {
    final num? rawRating = data['rating'] as num?;

    return EventRatingTargetState(
      targetUid: data['targetUid']?.toString().trim() ?? '',
      submitted: data['submitted'] == true,
      rating: rawRating?.toInt(),
      comment: data['comment']?.toString() ?? '',
    );
  }
}

class EventRatingState {
  const EventRatingState({
    required this.eventId,
    required this.completed,
    required this.targets,
  });

  final String eventId;
  final bool completed;
  final List<EventRatingTargetState> targets;

  factory EventRatingState.fromMap(
    Map<String, dynamic> data,
  ) {
    final dynamic rawTargets = data['targets'];
    final List<EventRatingTargetState> targets =
        <EventRatingTargetState>[];

    if (rawTargets is List) {
      for (final dynamic item in rawTargets) {
        if (item is Map) {
          targets.add(
            EventRatingTargetState.fromMap(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    return EventRatingState(
      eventId: data['eventId']?.toString().trim() ?? '',
      completed: data['completed'] == true,
      targets: targets,
    );
  }
}

class EventRatingService {
  EventRatingService({
    FirebaseFunctions? functions,
  }) : _functions = functions ??
            FirebaseFunctions.instanceFor(
              region: 'europe-west1',
            );

  final FirebaseFunctions _functions;

  Future<EventRatingState> getState({
    required String eventId,
  }) async {
    final String normalizedEventId = eventId.trim();

    if (normalizedEventId.isEmpty) {
      throw StateError('Etkinlik kimliği boş olamaz.');
    }

    try {
      final HttpsCallableResult<dynamic> result =
          await _functions
              .httpsCallable('getEventRatingState')
              .call<dynamic>(
        <String, dynamic>{
          'eventId': normalizedEventId,
        },
      );

      final dynamic rawData = result.data;

      if (rawData is! Map) {
        throw StateError(
          'Değerlendirme bilgisi alınamadı.',
        );
      }

      return EventRatingState.fromMap(
        Map<String, dynamic>.from(rawData),
      );
    } on FirebaseFunctionsException catch (error) {
      final String message = error.message?.trim() ?? '';

      throw StateError(
        message.isNotEmpty
            ? message
            : 'Değerlendirme bilgisi alınamadı.',
      );
    }
  }

  Future<void> submit({
    required String eventId,
    required String targetUid,
    required int rating,
    String comment = '',
  }) async {
    final String normalizedEventId = eventId.trim();
    final String normalizedTargetUid = targetUid.trim();
    final String normalizedComment = comment.trim();

    if (normalizedEventId.isEmpty) {
      throw StateError('Etkinlik kimliği boş olamaz.');
    }

    if (normalizedTargetUid.isEmpty) {
      throw StateError(
        'Değerlendirilecek kullanıcı seçilmelidir.',
      );
    }

    if (rating < 1 || rating > 5) {
      throw StateError(
        'Puan 1 ile 5 arasında olmalıdır.',
      );
    }

    if (normalizedComment.length > 500) {
      throw StateError(
        'Yorum en fazla 500 karakter olabilir.',
      );
    }

    try {
      await _functions
          .httpsCallable('submitEventRating')
          .call<void>(
        <String, dynamic>{
          'eventId': normalizedEventId,
          'targetUid': normalizedTargetUid,
          'rating': rating,
          'comment': normalizedComment,
        },
      );
    } on FirebaseFunctionsException catch (error) {
      final String message = error.message?.trim() ?? '';

      throw StateError(
        message.isNotEmpty
            ? message
            : 'Değerlendirme gönderilemedi.',
      );
    }
  }
}
