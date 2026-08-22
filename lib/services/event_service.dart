import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/event_model.dart';
import '../models/user_model.dart';
import '../utils/game_catalog.dart';
import 'user_service.dart';

class EventService {
  EventService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(
              region: 'europe-west1',
            );

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _events {
    return _firestore.collection('events');
  }

  CollectionReference<Map<String, dynamic>> get _users {
    return _firestore.collection('users');
  }

  String get currentUserId {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Etkinlik işlemi için kullanıcı girişi gereklidir.',
      );
    }

    return user.uid;
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getEvents() {
    return FirebaseFirestore.instance
        .collection('events')
        .orderBy('tarih')
        .snapshots();
  }

  Stream<List<EventModel>> watchActiveEvents({
    String? city,
    int limit = 100,
  }) {
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
          .where(
            (event) =>
            event.eventDate.isAfter(DateTime.now()),
      )
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
          .where(
            (event) =>
            event.eventDate.isAfter(DateTime.now()),
      )
          .toList(),
    );
  }

  Stream<List<EventModel>> watchCreatedEvents({
    String? userId,
    int limit = 100,
  }) {
    final resolvedUserId = userId ?? currentUserId;

    return _events
        .where(
      'olusturanUid',
      isEqualTo: resolvedUserId,
    )
        .orderBy(
      'tarih',
      descending: true,
    )
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map(EventModel.fromDocument)
          .toList(),
    );
  }

  Stream<List<EventModel>> watchJoinedEvents({
    String? userId,
    int limit = 100,
  }) {
    final resolvedUserId = userId ?? currentUserId;

    return _events
        .where(
      'katilanlar',
      arrayContains: resolvedUserId,
    )
        .orderBy(
      'tarih',
      descending: true,
    )
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map(EventModel.fromDocument)
          .where(
            (event) =>
        event.creatorId != resolvedUserId,
      )
          .toList(),
    );
  }

  Stream<List<EventModel>> watchPlayerApplications({
    String? playerId,
    int limit = 100,
  }) {
    final resolvedPlayerId = playerId ?? currentUserId;

    return _events
        .where(
      'basvuranOyuncuIds',
      arrayContains: resolvedPlayerId,
    )
        .orderBy(
      'tarih',
      descending: true,
    )
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map(EventModel.fromDocument)
          .toList(),
    );
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchEvent(
      String eventId,
      ) {
    return _events.doc(eventId).snapshots();
  }

  Stream<EventModel?> watchEventModel(
      String eventId,
      ) {
    return _events.doc(eventId).snapshots().map(
          (snapshot) {
        if (!snapshot.exists) {
          return null;
        }

        return EventModel.fromDocument(snapshot);
      },
    );
  }

  Future<EventModel?> getEvent(
      String eventId,
      ) async {
    if (eventId.trim().isEmpty) {
      return null;
    }

    final snapshot = await _events.doc(eventId).get();

    if (!snapshot.exists) {
      return null;
    }

    return EventModel.fromDocument(snapshot);
  }

   Future<String> createEvent(
    EventModel event,
  ) async {
     final User? firebaseUser = _auth.currentUser;

     if (firebaseUser == null) {
       throw StateError(
         'Etkinlik oluşturmak için yeniden giriş yapmalısınız.',
       );
     }

     final String? idToken;

     try {
       idToken = await firebaseUser.getIdToken(true);
     } on FirebaseAuthException catch (error) {
       throw StateError(
         error.message ??
             'Oturum doğrulanamadı. Lütfen çıkış yapıp yeniden giriş yapın.',
       );
     }

     if (idToken == null || idToken.trim().isEmpty) {
       throw StateError(
         'Oturum doğrulama bilgisi alınamadı. Lütfen yeniden giriş yapın.',
       );
     }

     final String userId = firebaseUser.uid;

     if (event.creatorId != userId) {
       throw StateError(
         'Etkinlik sahibi oturum açan kullanıcıyla eşleşmiyor.',
       );
     }

    if (event.playerCount < 1 || event.playerCount > 4) {
      throw ArgumentError(
        'Oyuncu sayısı 1 ile 4 arasında olmalıdır.',
      );
    }

    if (event.resolvedGameId.trim().isEmpty) {
      throw ArgumentError(
        'Etkinlik için geçerli bir oyun veya spor seçilmelidir.',
      );
    }

    if (!event.resolvedEndAt.isAfter(event.resolvedStartAt)) {
      throw ArgumentError(
        'Bitiş saati başlangıç saatinden sonra olmalıdır.',
      );
    }

    if (event.resolvedDurationMinutes < 60 ||
        event.resolvedDurationMinutes > 360) {
      throw ArgumentError(
        'Etkinlik süresi 1 ile 6 saat arasında olmalıdır.',
      );
    }

    if (event.resolvedStartAt.isBefore(DateTime.now())) {
      throw ArgumentError(
        'Geçmiş tarihli etkinlik oluşturulamaz.',
      );
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
      throw ArgumentError(
        'Etkinlik konum bilgileri eksik.',
      );
    }

    if (latitude == 0 || longitude == 0) {
      throw ArgumentError(
        'Etkinlik konumu haritadan seçilmelidir.',
      );
    }

    try {
      final HttpsCallable callable =
          _functions.httpsCallable('createEvent');

      final HttpsCallableResult<dynamic> result =
          await callable.call(
        <String, dynamic>{
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
          'startAt':
              event.resolvedStartAt.millisecondsSinceEpoch,
          'endAt':
              event.resolvedEndAt.millisecondsSinceEpoch,
        },
      );

      final dynamic responseData = result.data;

      if (responseData is! Map) {
        throw StateError(
          'Sunucudan geçersiz etkinlik yanıtı alındı.',
        );
      }

      final String eventId =
          responseData['eventId']?.toString().trim() ?? '';

      if (eventId.isEmpty) {
        throw StateError(
          'Etkinlik oluşturuldu ancak etkinlik kimliği alınamadı.',
        );
      }

      return eventId;
    } on FirebaseFunctionsException catch (error) {
      final String message =
          error.message?.trim() ?? '';

      if (message.isNotEmpty) {
        throw StateError(message);
      }

      throw StateError(
        'Etkinlik oluşturulurken sunucu hatası oluştu.',
      );
    }
  }

  Future<void> updateEvent({
    required String eventId,
    String? game,
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
    final reference = _events.doc(eventId);
    final snapshot = await reference.get();

    if (!snapshot.exists) {
      throw StateError('Etkinlik bulunamadı.');
    }

    final data = snapshot.data() ?? const <String, dynamic>{};

    if (data['olusturanUid']?.toString() != currentUserId) {
      throw StateError(
        'Bu etkinliği düzenleme yetkiniz bulunmuyor.',
      );
    }

    final status = data['durum']?.toString() ?? 'aktif';

    if (!_isActiveStatus(status) &&
        !_isPaymentPendingStatus(status)) {
      throw StateError(
        'Bu durumdaki etkinlik düzenlenemez.',
      );
    }

    if (playerCount != null &&
        (playerCount < 1 || playerCount > 4)) {
      throw ArgumentError(
        'Oyuncu sayısı 1 ile 4 arasında olmalıdır.',
      );
    }

    if (eventDate != null &&
        eventDate.isBefore(DateTime.now())) {
      throw ArgumentError(
        'Geçmiş tarih seçilemez.',
      );
    }

    final Map<String, dynamic> publicUpdates = <String, dynamic>{
      if (game != null) 'oyun': game.trim(),
      if (playerCount != null) ...<String, dynamic>{
        'oyuncuSayisi': playerCount,
        'oyuncuSayisiMetni': '$playerCount Oyuncu',
      },
      if (memberPreference != null)
        'uyeTercihi': memberPreference.trim(),
      if (description != null)
        'aciklama': description.trim(),
      if (eventDate != null)
        'tarih': Timestamp.fromDate(eventDate),
      if (city != null) 'sehir': city.trim(),
      if (district != null) 'ilce': district.trim(),
      if (neighborhood != null ||
          address != null ||
          latitude != null ||
          longitude != null)
        'privateLocationAvailable': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final bool updatesPrivateLocation =
        city != null ||
            district != null ||
            neighborhood != null ||
            address != null ||
            latitude != null ||
            longitude != null;

    final WriteBatch batch = _firestore.batch();
    batch.update(reference, publicUpdates);

    if (updatesPrivateLocation) {
      final DocumentReference<Map<String, dynamic>> locationReference =
      reference.collection('private').doc('location');

      batch.set(
        locationReference,
        <String, dynamic>{
          if (city != null) 'sehir': city.trim(),
          if (district != null) 'ilce': district.trim(),
          if (neighborhood != null) 'semt': neighborhood.trim(),
          if (address != null) 'adres': address.trim(),
          'latitude': ?latitude,
          'longitude': ?longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
    final Map<String, dynamic> updatedEventData =
        (await reference.get()).data() ?? <String, dynamic>{};

    final List<String> participantIds = <String>{
      ...List<String>.from(
        updatedEventData['selectedPlayerIds'] ?? const <String>[],
      ),
      ...List<String>.from(
        updatedEventData['katilanlar'] ?? const <String>[],
      ),
    }.where((String uid) {
      return uid.trim().isNotEmpty && uid != currentUserId;
    }).toList();

    for (final String userId in participantIds) {
      await _createNotification(
        userId: userId,
        type: 'eventUpdated',
        title: 'Etkinlik Güncellendi',
        message: 'Katılacağın etkinliğin bilgileri güncellendi.',
        eventId: eventId,
        actorId: currentUserId,
      );
    }
  }

  Future<void> applyToEvent({
    required String eventId,
    String note = '',
  }) async {
    final playerId = currentUserId;
    final eventReference = _events.doc(eventId);
    final playerReference = _users.doc(playerId);
    final applicationReference = eventReference
        .collection('applications')
        .doc(playerId);

    final eventBeforeTransaction =
    await eventReference.get();

    if (!eventBeforeTransaction.exists) {
      throw StateError('Etkinlik bulunamadı.');
    }


    final allowed = await UserService.checkApplicationEligibility(
      eventId: eventId,
      userId: playerId,
    );

    if (!allowed) {
      throw StateError(
        'Bu etkinliğe başvurma koşullarını sağlamıyorsunuz.',
      );
    }

    await _firestore.runTransaction(
          (transaction) async {
        final eventSnapshot =
        await transaction.get(eventReference);
        final playerSnapshot =
        await transaction.get(playerReference);

        if (!eventSnapshot.exists) {
          throw StateError('Etkinlik bulunamadı.');
        }

        if (!playerSnapshot.exists) {
          throw StateError(
            'Oyuncu profili bulunamadı.',
          );
        }

        final eventData =
            eventSnapshot.data() ??
                const <String, dynamic>{};

        final playerData =
            playerSnapshot.data() ??
                const <String, dynamic>{};


        final creatorId =
            eventData['olusturanUid']?.toString() ?? '';

        if (creatorId == playerId) {
          throw StateError(
            'Kendi etkinliğinize başvuramazsınız.',
          );
        }

        final eventStatus =
            eventData['durum']?.toString() ?? '';

        if (!_isActiveStatus(eventStatus)) {
          throw StateError(
            'Etkinlik başvuru kabul etmiyor.',
          );
        }

        final eventGameIdOrName =
        _eventGameIdOrName(eventData);
        final playerModel = UserModel.fromMap(
          playerData,
          documentId: playerId,
        );
        final playerSkill =
        playerModel.skillForGame(eventGameIdOrName);

        if (playerSkill == null) {
          final eventGame =
              GameCatalog.gameById(eventGameIdOrName) ??
                  GameCatalog.gameByLegacyValue(
                    eventGameIdOrName,
                  );
          final eventGameName =
              eventGame?.name ?? eventGameIdOrName;

          throw StateError(
            'Başvurmadan önce $eventGameName oyununu profiline eklemelisin.',
          );
        }

        final requiredPlayerCount =
            (eventData['oyuncuSayisi'] as num?)
                ?.toInt() ??
                (eventData['playerCount'] as num?)
                    ?.toInt() ??
                1;
        final currentSelectedPlayerIds =
        List<String>.from(
          eventData['selectedPlayerIds'] ??
              const <String>[],
        );

        if (currentSelectedPlayerIds.length >=
            requiredPlayerCount) {
          throw StateError(
            'Etkinlik için gerekli oyuncu sayısı tamamlandı.',
          );
        }

        final hasPlayerBadge =
            playerData['oyuncuRozeti'] == true;

        if (!hasPlayerBadge) {
          throw StateError(
            'Başvuru yapabilmek için Oyuncu Rozeti gereklidir.',
          );
        }

        final accountStatus =
            playerData['hesapDurumu']?.toString() ??
                'active';

        if (accountStatus == 'blocked' ||
            accountStatus == 'suspended') {
          throw StateError(
            'Hesabınız başvuru yapmaya uygun değil.',
          );
        }

        final preference =
            eventData['uyeTercihi']?.toString() ??
                'Herkes';

        final playerIsPlus =
            playerData['plus'] == true;

        if (preference == 'Plus Üye' &&
            !playerIsPlus) {
          throw StateError(
            'Bu etkinlik yalnızca Plus oyuncu başvurularını kabul ediyor.',
          );
        }

        if (preference == 'Normal Üye' &&
            playerIsPlus) {
          throw StateError(
            'Organizatör bu etkinlik için Normal Üye tercih etti.',
          );
        }

        final selectedPlayerIds =
        List<String>.from(
          eventData['selectedPlayerIds'] ??
              const <String>[],
        );

        if (selectedPlayerIds.contains(playerId)) {
          throw StateError(
            'Bu etkinlik için zaten seçildiniz.',
          );
        }

        final applicantIds =
        List<String>.from(
          eventData['basvuranOyuncuIds'] ??
              const <String>[],
        );

        if (applicantIds.contains(playerId)) {
          throw StateError(
            'Bu etkinliğe daha önce başvurdunuz.',
          );
        }

        transaction.set(
          applicationReference,
          <String, dynamic>{
            'applicationId': playerId,
            'eventId': eventId,
            'playerId': playerId,
            'playerProfileName':
            playerData['profilAdi']?.toString() ??
                '',
            'playerProfilePhoto':
            playerData['profilFotografi']
                ?.toString() ??
                '',
            'playerPlus': playerIsPlus,
            'playerVerified':
            playerData['verified'] == true ||
                playerData['verificationStatus'] ==
                    'approved',
            'gameId': playerSkill.gameId,
            'gameName': playerSkill.gameName,
            'categoryId': playerSkill.categoryId,
            'categoryName': playerSkill.categoryName,
            'skillLevel': playerSkill.level,
            'skillLevelLabel': playerSkill.levelLabel,
            'note': note.trim(),
            'status': 'pending',
            'createdAt':
            FieldValue.serverTimestamp(),
            'updatedAt':
            FieldValue.serverTimestamp(),
          },
        );

        transaction.update(
          eventReference,
          <String, dynamic>{
            'basvuranOyuncuIds':
            FieldValue.arrayUnion(
              <String>[playerId],
            ),
            'basvuruSayisi':
            FieldValue.increment(1),
            'updatedAt':
            FieldValue.serverTimestamp(),
          },
        );
      },
    );

    await _createNotification(
      userId: await _getEventCreatorId(eventId),
      type: 'eventApplication',
      title: 'Yeni oyuncu başvurusu',
      message:
      'Etkinliğinize yeni bir oyuncu başvurdu.',
      eventId: eventId,
      actorId: playerId,
    );
  }

  Future<void> withdrawApplication({
    required String eventId,
  }) async {
    try {
      final HttpsCallable callable =
      _functions.httpsCallable('withdrawApplication');

      await callable.call(
        <String, dynamic>{
          'eventId': eventId,
        },
      );
    } on FirebaseFunctionsException catch (error) {
      final String message =
          error.message?.trim() ?? '';

      if (message.isNotEmpty) {
        throw StateError(message);
      }

      throw StateError(
        'Başvuru geri çekilirken sunucu hatası oluştu.',
      );
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>
  watchApplications(
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
      final HttpsCallable callable =
      _functions.httpsCallable('acceptApplication');

      await callable.call(
        <String, dynamic>{
          'eventId': eventId,
          'playerId': playerId,
        },
      );
      await _createNotification(
        userId: playerId,
        type: 'applicationAccepted',
        title: 'Başvurun Kabul Edildi',
        message: 'Etkinlik başvurun kabul edildi.',
        eventId: eventId,
        actorId: currentUserId,
      );
    } on FirebaseFunctionsException catch (error) {
      final String message =
          error.message?.trim() ?? '';

      if (message.isNotEmpty) {
        throw StateError(message);
      }

      throw StateError(
        'Başvuru kabul edilirken sunucu hatası oluştu.',
      );
    }
  }

  Future<void> rejectApplication({
    required String eventId,
    required String playerId,
    String reason = '',
  }) async {
    try {
      final HttpsCallable callable =
      _functions.httpsCallable('rejectApplication');

      await callable.call(
        <String, dynamic>{
          'eventId': eventId,
          'playerId': playerId,
          'reason': reason,
        },
      );
      await _createNotification(
        userId: playerId,
        type: 'applicationRejected',
        title: 'Başvurun Reddedildi',
        message: reason.isEmpty
            ? 'Etkinlik başvurun reddedildi.'
            : reason,
        eventId: eventId,
        actorId: currentUserId,
      );
    } on FirebaseFunctionsException catch (error) {
      final String message =
          error.message?.trim() ?? '';

      if (message.isNotEmpty) {
        throw StateError(message);
      }

      throw StateError(
        'Başvuru reddedilirken sunucu hatası oluştu.',
      );
    }
  }
  Future<void> removeSelectedPlayer({
    required String eventId,
    required String playerId,
    String reason = '',
  }) async {
    try {
      final HttpsCallable callable =
      _functions.httpsCallable('removeSelectedPlayer');

      await callable.call(
        <String, dynamic>{
          'eventId': eventId,
          'playerId': playerId,
          'reason': reason,
        },
      );
    } on FirebaseFunctionsException catch (error) {
      final String message =
          error.message?.trim() ?? '';

      if (message.isNotEmpty) {
        throw StateError(message);
      }

      throw StateError(
        'Oyuncu kaldırılırken sunucu hatası oluştu.',
      );
    }
  }

  Future<void> cancelUnpaidEvent({
    required String eventId,
    required String reason,
  }) async {
    try {
      final HttpsCallable callable =
      _functions.httpsCallable('cancelUnpaidEvent');

      await callable.call(
        <String, dynamic>{
          'eventId': eventId,
          'reason': reason,
        },
      );
      final DocumentSnapshot<Map<String, dynamic>> eventSnapshot =
      await _events.doc(eventId).get();

      final Map<String, dynamic> eventData =
          eventSnapshot.data() ?? <String, dynamic>{};

      final List<String> participantIds = <String>{
        ...List<String>.from(
          eventData['selectedPlayerIds'] ?? const <String>[],
        ),
        ...List<String>.from(
          eventData['katilanlar'] ?? const <String>[],
        ),
      }.where((String uid) {
        return uid.trim().isNotEmpty && uid != currentUserId;
      }).toList();

      for (final String userId in participantIds) {
        await _createNotification(
          userId: userId,
          type: 'eventCancelled',
          title: 'Etkinlik İptal Edildi',
          message: reason.trim().isEmpty
              ? 'Katılacağın etkinlik iptal edildi.'
              : 'Katılacağın etkinlik iptal edildi. $reason',
          eventId: eventId,
          actorId: currentUserId,
        );
      }
    } on FirebaseFunctionsException catch (error) {
      final String message =
          error.message?.trim() ?? '';

      if (message.isNotEmpty) {
        throw StateError(message);
      }

      throw StateError(
        'Etkinlik iptal edilirken sunucu hatası oluştu.',
      );
    }
  }

  Future<void> markEventCompleted({
    required String eventId,
  }) async {
    try {
      final HttpsCallable callable =
      _functions.httpsCallable('markEventCompleted');

      await callable.call(
        <String, dynamic>{
          'eventId': eventId,
        },
      );
      final DocumentSnapshot<Map<String, dynamic>> eventSnapshot =
      await _events.doc(eventId).get();

      final Map<String, dynamic> eventData =
          eventSnapshot.data() ?? <String, dynamic>{};

      final List<String> participantIds = <String>{
        ...List<String>.from(
          eventData['selectedPlayerIds'] ?? const <String>[],
        ),
        ...List<String>.from(
          eventData['katilanlar'] ?? const <String>[],
        ),
      }.where((String uid) {
        return uid.trim().isNotEmpty && uid != currentUserId;
      }).toList();

      for (final String userId in participantIds) {
        await _createNotification(
          userId: userId,
          type: 'system',
          title: 'Etkinlik Tamamlandı',
          message: 'Katıldığın etkinlik tamamlandı. Değerlendirme yapabilirsin.',
          eventId: eventId,
          actorId: currentUserId,
        );
      }
    } on FirebaseFunctionsException catch (error) {
      final String message =
          error.message?.trim() ?? '';

      if (message.isNotEmpty) {
        throw StateError(message);
      }

      throw StateError(
        'Etkinlik tamamlanırken sunucu hatası oluştu.',
      );
    }
  }

  Future<String> _getEventCreatorId(
      String eventId,
      ) async {
    final snapshot = await _events.doc(eventId).get();

    return snapshot.data()?['olusturanUid']
        ?.toString() ??
        '';
  }

  Future<void> _createNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    required String eventId,
    required String actorId,
  }) async {
    if (userId.trim().isEmpty) {
      return;
    }

    final reference = _users
        .doc(userId)
        .collection('notifications')
        .doc();

    await reference.set(
      <String, dynamic>{
        'notificationId': reference.id,
        'userId': userId,
        'type': type,
        'title': title,
        'message': message,
        'eventId': eventId,
        'actorId': actorId,
        'isRead': false,
        'read': false,
        'okundu': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }
  bool _isActiveStatus(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'aktif' || normalized == 'active';
  }

  bool _isPaymentPendingStatus(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'odeme_bekliyor' ||
        normalized == 'paymentpending' ||
        normalized == 'payment_pending';
  }

  String _eventGameIdOrName(
      Map<String, dynamic> eventData,
      ) {
    const keys = <String>[
      'gameId',
      'gameName',
      'oyun',
      'game',
    ];

    for (final key in keys) {
      final value = eventData[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

}