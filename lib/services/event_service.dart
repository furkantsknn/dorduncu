import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/event_model.dart';
import 'event_operation_failure.dart';

const plusPlayerLimitErrorCode = 'plus_required_for_multiple_players';
const eventFreeTodayErrorCode = 'event_free_today_only';
const openEventQuotaErrorCode = 'free_open_event_quota_reached';

class OpenEventQuotaException implements Exception {
  const OpenEventQuotaException();
}

class EventCreationQuotaState {
  const EventCreationQuotaState({
    required this.openEventCount,
    required this.plusActive,
    required this.limit,
    required this.canCreate,
  });

  final int openEventCount;
  final bool plusActive;
  final int? limit;
  final bool canCreate;
}

class PlusPlayerLimitException implements Exception {
  const PlusPlayerLimitException();
}

class EventScheduleException implements Exception {
  const EventScheduleException(this.code);

  final String code;
}

bool isEventScheduleFailure({Object? details}) {
  if (details is! Map) {
    return false;
  }
  final Object? code = details['code'];
  return code == eventFreeTodayErrorCode;
}

bool isPlusPlayerLimitFailure({Object? details, String? message}) {
  if (details is Map && details['code'] == plusPlayerLimitErrorCode) {
    return true;
  }

  return message?.trim() ==
      '2 veya daha fazla oyuncu için Plus üyelik gerekir.';
}

class EventService {
  EventService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _events {
    return _firestore.collection('events');
  }

  Future<EventCreationQuotaState> getCreationQuotaState({String? uid}) async {
    final HttpsCallableResult<dynamic> result = await _functions
        .httpsCallable('getEventCreationQuotaState')
        .call(<String, dynamic>{'uid': ?uid});
    final dynamic data = result.data;
    if (data is! Map) throw StateError('Etkinlik kota bilgisi okunamadı.');
    return EventCreationQuotaState(
      openEventCount: (data['openEventCount'] as num?)?.toInt() ?? 0,
      plusActive: data['plusActive'] == true,
      limit: (data['limit'] as num?)?.toInt(),
      canCreate: data['canCreate'] == true,
    );
  }

  String get currentUserId {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Etkinlik işlemi için kullanıcı girişi gereklidir.');
    }

    return user.uid;
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchListedEvents({
    required String city,
    bool nearbyNationwide = false,
    int limit = 100,
  }) {
    final int safeLimit = limit < 1 ? 1 : limit;
    final String trimmedCity = city.trim();
    final Query<Map<String, dynamic>> events = FirebaseFirestore.instance
        .collection('events');
    final Timestamp now = Timestamp.fromDate(DateTime.now());

    if (nearbyNationwide) {
      return events
          .where('durum', isEqualTo: 'aktif')
          .where('tarih', isGreaterThan: now)
          .orderBy('tarih')
          .snapshots();
    }

    if (trimmedCity.isEmpty) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }

    return events
        .where('sehir', isEqualTo: trimmedCity)
        .where('durum', isEqualTo: 'aktif')
        .where('tarih', isGreaterThan: now)
        .orderBy('tarih')
        .limit(safeLimit)
        .snapshots();
  }

  Stream<List<EventModel>> watchActiveEvents({String? city, int limit = 100}) {
    Query<Map<String, dynamic>> query = _events
        .where('durum', isEqualTo: 'aktif')
        .orderBy('tarih')
        .limit(limit);

    final normalizedCity = city?.trim() ?? '';

    if (normalizedCity.isNotEmpty) {
      query = _events
          .where('durum', isEqualTo: 'aktif')
          .where('sehir', isEqualTo: normalizedCity)
          .orderBy('tarih')
          .limit(limit);
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map(EventModel.fromDocument)
          .where((event) => event.eventDate.isAfter(DateTime.now()))
          .toList(),
    );
  }

  Stream<List<EventModel>> watchEventsByCity({
    required String city,
    int limit = 100,
  }) {
    return _events
        .where('sehir', isEqualTo: city.trim())
        .where('durum', isEqualTo: 'aktif')
        .orderBy('tarih')
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(EventModel.fromDocument)
              .where((event) => event.eventDate.isAfter(DateTime.now()))
              .toList(),
        );
  }

  Stream<List<EventModel>> watchCreatedEvents({
    String? userId,
    int limit = 100,
  }) {
    final resolvedUserId = userId ?? currentUserId;

    return _events
        .where('olusturanUid', isEqualTo: resolvedUserId)
        .orderBy('tarih', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(EventModel.fromDocument).toList());
  }

  Stream<List<EventModel>> watchJoinedEvents({
    String? userId,
    int limit = 100,
  }) {
    final resolvedUserId = userId ?? currentUserId;

    return _events
        .where('katilanlar', arrayContains: resolvedUserId)
        .orderBy('tarih', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(EventModel.fromDocument)
              .where((event) => event.creatorId != resolvedUserId)
              .toList(),
        );
  }

  Stream<List<EventModel>> watchPlayerApplications({
    String? playerId,
    int limit = 100,
  }) {
    final resolvedPlayerId = playerId ?? currentUserId;

    return _events
        .where('basvuranOyuncuIds', arrayContains: resolvedPlayerId)
        .orderBy('tarih', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(EventModel.fromDocument).toList());
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchEvent(String eventId) {
    return _events.doc(eventId).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchApplication({
    required String eventId,
    String? playerId,
  }) {
    final String resolvedPlayerId = playerId ?? currentUserId;

    return _events
        .doc(eventId)
        .collection('applications')
        .doc(resolvedPlayerId)
        .snapshots();
  }

  Future<Map<String, dynamic>> getPrivateLocation({
    required String eventId,
  }) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _events
          .doc(eventId)
          .collection('private')
          .doc('location')
          .get(const GetOptions(source: Source.server));

      if (!snapshot.exists) {
        throw StateError('Etkinliğin özel konum bilgisi bulunamadı.');
      }

      return snapshot.data() ?? <String, dynamic>{};
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw StateError(
          'Açık adres ve yol tarifi ödeme tamamlandıktan sonra açılır.',
        );
      }

      final String message = error.message?.trim() ?? '';
      if (message.isNotEmpty) {
        throw StateError(message);
      }

      throw StateError('Özel konum bilgisi alınamadı.');
    }
  }

  Stream<EventModel?> watchEventModel(String eventId) {
    return _events.doc(eventId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      return EventModel.fromDocument(snapshot);
    });
  }

  Future<EventModel?> getEvent(String eventId) async {
    if (eventId.trim().isEmpty) {
      return null;
    }

    final snapshot = await _events
        .doc(eventId)
        .get(const GetOptions(source: Source.server));

    if (!snapshot.exists) {
      return null;
    }

    return EventModel.fromDocument(snapshot);
  }

  Future<String> createEvent(EventModel event, {String? requestId}) async {
    final User? firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw StateError('Etkinlik oluşturmak için yeniden giriş yapmalısınız.');
    }

    final String? idToken;

    try {
      idToken = await firebaseUser.getIdToken(true);
    } on FirebaseAuthException catch (error, stack) {
      Error.throwWithStackTrace(
        EventOperationFailure(code: error.code, stage: 'auth-token'),
        stack,
      );
    }

    if (idToken == null || idToken.trim().isEmpty) {
      throw StateError(
        'Oturum doğrulama bilgisi alınamadı. Lütfen yeniden giriş yapın.',
      );
    }

    final String userId = firebaseUser.uid;

    if (event.creatorId != userId) {
      throw StateError('Etkinlik sahibi oturum açan kullanıcıyla eşleşmiyor.');
    }

    if (event.playerCount < 1) {
      throw ArgumentError('Oyuncu sayısı pozitif bir tam sayı olmalıdır.');
    }

    if (event.resolvedGameId.trim().isEmpty) {
      throw ArgumentError(
        'Etkinlik için geçerli bir oyun veya spor seçilmelidir.',
      );
    }

    if (!event.resolvedEndAt.isAfter(event.resolvedStartAt)) {
      throw ArgumentError('Bitiş saati başlangıç saatinden sonra olmalıdır.');
    }

    if (event.resolvedDurationMinutes < 60 ||
        event.resolvedDurationMinutes > 360) {
      throw ArgumentError('Etkinlik süresi 1 ile 6 saat arasında olmalıdır.');
    }

    if (event.resolvedStartAt.isBefore(DateTime.now())) {
      throw ArgumentError('Geçmiş tarihli etkinlik oluşturulamaz.');
    }

    final String city = event.city.trim();
    final String district = event.district.trim();
    final String neighborhood = event.neighborhood.trim();
    final String address = event.address.trim();
    final double latitude = event.latitude;
    final double longitude = event.longitude;

    if (city.isEmpty ||
        district.isEmpty ||
        neighborhood.isEmpty ||
        address.isEmpty) {
      throw ArgumentError('Etkinlik konum bilgileri eksik.');
    }

    if (latitude == 0 || longitude == 0) {
      throw ArgumentError('Etkinlik konumu haritadan seçilmelidir.');
    }

    try {
      final HttpsCallable callable = _functions.httpsCallable('createEvent');

      final HttpsCallableResult<dynamic> result = await callable
          .call(<String, dynamic>{
            'requestId': ?requestId,
            'gameId': event.resolvedGameId,
            'playerCount': event.playerCount,
            'memberPreference': event.memberPreference,
            'description': event.description,
            'city': city,
            'district': district,
            'neighborhood': neighborhood,
            'address': address,
            'latitude': latitude,
            'longitude': longitude,
            'startAt': event.resolvedStartAt.millisecondsSinceEpoch,
            'endAt': event.resolvedEndAt.millisecondsSinceEpoch,
          });

      final dynamic responseData = result.data;

      if (responseData is! Map) {
        throw StateError('Sunucudan geçersiz etkinlik yanıtı alındı.');
      }

      final String eventId = responseData['eventId']?.toString().trim() ?? '';

      if (eventId.isEmpty) {
        throw StateError(
          'Etkinlik oluşturuldu ancak etkinlik kimliği alınamadı.',
        );
      }

      return eventId;
    } on FirebaseFunctionsException catch (error, stack) {
      if (error.details is Map &&
          (error.details as Map)['code'] == openEventQuotaErrorCode) {
        throw const OpenEventQuotaException();
      }
      if (isPlusPlayerLimitFailure(
        details: error.details,
        message: error.message,
      )) {
        throw const PlusPlayerLimitException();
      }

      if (isEventScheduleFailure(details: error.details)) {
        final Object? code = error.details is Map
            ? (error.details as Map)['code']
            : null;
        throw EventScheduleException(
          code?.toString() ?? eventFreeTodayErrorCode,
        );
      }

      Error.throwWithStackTrace(
        EventOperationFailure(code: error.code, stage: 'create-callable'),
        stack,
      );
    }
  }

  Future<void> updateEvent({
    required String eventId,
    String? gameId,
    int? playerCount,
    String? memberPreference,
    String? description,
    DateTime? eventDate,
    String? city,
    String? district,
    String? neighborhood,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('updateEvent');

      await callable.call(<String, dynamic>{
        'eventId': eventId,
        'gameId': ?gameId?.trim(),
        'playerCount': ?playerCount,
        if (memberPreference != null)
          'memberPreference': memberPreference.trim(),
        if (description != null) 'description': description.trim(),
        if (eventDate != null) 'eventDate': eventDate.millisecondsSinceEpoch,
        'city': ?city?.trim(),
        'district': ?district?.trim(),
        if (neighborhood != null) 'neighborhood': neighborhood.trim(),
        if (address != null) 'address': address.trim(),
        'latitude': ?latitude,
        'longitude': ?longitude,
      });
    } on FirebaseFunctionsException catch (error) {
      if (isPlusPlayerLimitFailure(
        details: error.details,
        message: error.message,
      )) {
        throw const PlusPlayerLimitException();
      }

      if (isEventScheduleFailure(details: error.details)) {
        final Object? code = error.details is Map
            ? (error.details as Map)['code']
            : null;
        throw EventScheduleException(
          code?.toString() ?? eventFreeTodayErrorCode,
        );
      }

      final String message = error.message?.trim() ?? '';

      if (message.isNotEmpty) {
        throw StateError(message);
      }

      throw StateError('Etkinlik güncellenirken sunucu hatası oluştu.');
    }
  }

  Future<void> applyToEvent({required String eventId, String note = ''}) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('applyToEvent');

      await callable.call(<String, dynamic>{
        'eventId': eventId,
        'note': note.trim(),
      });
    } on FirebaseFunctionsException catch (error) {
      final String message = error.message?.trim() ?? '';

      if (message.isNotEmpty) {
        throw StateError(message);
      }

      throw StateError('Etkinlik başvurusu yapılırken sunucu hatası oluştu.');
    }
  }

  Future<void> leaveEvent({required String eventId}) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('leaveEvent');

      await callable.call(<String, dynamic>{'eventId': eventId});
    } on FirebaseFunctionsException catch (error) {
      final String message = error.message?.trim() ?? '';

      if (message.isNotEmpty) {
        throw StateError(message);
      }

      throw StateError('Etkinlikten ayrılırken sunucu hatası oluştu.');
    }
  }

  Future<void> withdrawApplication({required String eventId}) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable(
        'withdrawApplication',
      );

      await callable.call(<String, dynamic>{'eventId': eventId});
    } on FirebaseFunctionsException catch (error) {
      final String message = error.message?.trim() ?? '';

      if (message.isNotEmpty) {
        throw StateError(message);
      }

      throw StateError('Başvuru geri çekilirken sunucu hatası oluştu.');
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchApplications(
    String eventId,
  ) {
    return _events
        .doc(eventId)
        .collection('applications')
        .orderBy('createdAt')
        .snapshots();
  }

  Future<void> acceptApplication({
    required String eventId,
    required String playerId,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable(
        'acceptApplication',
      );

      await callable.call(<String, dynamic>{
        'eventId': eventId,
        'playerId': playerId,
      });
    } on FirebaseFunctionsException catch (error) {
      final String message = error.message?.trim() ?? '';

      if (message.isNotEmpty) {
        throw StateError(message);
      }

      throw StateError('Başvuru kabul edilirken sunucu hatası oluştu.');
    }
  }

  Future<void> rejectApplication({
    required String eventId,
    required String playerId,
    String reason = '',
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable(
        'rejectApplication',
      );

      await callable.call(<String, dynamic>{
        'eventId': eventId,
        'playerId': playerId,
        'reason': reason,
      });
    } on FirebaseFunctionsException catch (error) {
      final String message = error.message?.trim() ?? '';

      if (message.isNotEmpty) {
        throw StateError(message);
      }

      throw StateError('Başvuru reddedilirken sunucu hatası oluştu.');
    }
  }

  Future<void> removeSelectedPlayer({
    required String eventId,
    required String playerId,
    String reason = '',
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable(
        'removeSelectedPlayer',
      );

      await callable.call(<String, dynamic>{
        'eventId': eventId,
        'playerId': playerId,
        'reason': reason,
      });
    } on FirebaseFunctionsException catch (error) {
      final String message = error.message?.trim() ?? '';

      if (message.isNotEmpty) {
        throw StateError(message);
      }

      throw StateError('Oyuncu kaldırılırken sunucu hatası oluştu.');
    }
  }

  Future<void> cancelUnpaidEvent({
    required String eventId,
    required String reason,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable(
        'cancelUnpaidEvent',
      );

      await callable.call(<String, dynamic>{
        'eventId': eventId,
        'reason': reason,
      });
    } on FirebaseFunctionsException catch (error) {
      final String message = error.message?.trim() ?? '';

      if (message.isNotEmpty) {
        throw StateError(message);
      }

      throw StateError('Etkinlik iptal edilirken sunucu hatası oluştu.');
    }
  }

  Future<Map<String, dynamic>> requestMaskedEventCall({
    required String eventId,
    required String targetUid,
  }) async {
    final String normalizedEventId = eventId.trim();
    final String normalizedTargetUid = targetUid.trim();

    if (normalizedEventId.isEmpty) {
      throw ArgumentError('Etkinlik kimliği gereklidir.');
    }

    if (normalizedTargetUid.isEmpty) {
      throw ArgumentError('Aranacak kullanıcı kimliği gereklidir.');
    }

    if (normalizedTargetUid == currentUserId) {
      throw StateError('Kullanıcı kendisini arayamaz.');
    }

    try {
      final HttpsCallable callable = _functions.httpsCallable(
        'requestMaskedEventCall',
      );

      final HttpsCallableResult<dynamic> result = await callable.call(
        <String, dynamic>{
          'eventId': normalizedEventId,
          'targetUid': normalizedTargetUid,
        },
      );

      if (result.data is! Map) {
        throw StateError('Maskeli arama için geçersiz sunucu yanıtı alındı.');
      }

      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (error) {
      final String message = error.message?.trim() ?? '';

      if (message.isNotEmpty) {
        throw StateError(message);
      }

      throw StateError('Maskeli arama başlatılamadı.');
    }
  }

  Future<void> markEventCompleted({required String eventId}) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable(
        'markEventCompleted',
      );

      await callable.call(<String, dynamic>{
        'eventId': eventId,
        'confirmedOccurred': true,
      });
    } on FirebaseFunctionsException catch (error) {
      final String message = error.message?.trim() ?? '';

      if (message.isNotEmpty) {
        throw StateError(message);
      }

      throw StateError('Etkinlik tamamlanırken sunucu hatası oluştu.');
    }
  }
}
