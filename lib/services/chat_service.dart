import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/event_model.dart';

class ChatService {
  ChatService({
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

  static const String eventsCollection = 'events';
  static const String messagesCollection = 'messages';
  static const String usersCollection = 'users';

  User get _requiredUser {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw const ChatServiceException(
        'Mesajlaşmak için giriş yapmalısın.',
        code: 'not-authenticated',
      );
    }

    return user;
  }

  DocumentReference<Map<String, dynamic>> eventReference(String eventId) {
    final String normalizedEventId = eventId.trim();

    if (normalizedEventId.isEmpty) {
      throw const ChatServiceException(
        'Etkinlik kimliği boş olamaz.',
        code: 'invalid-event-id',
      );
    }

    return _firestore.collection(eventsCollection).doc(normalizedEventId);
  }

  CollectionReference<Map<String, dynamic>> messagesReference(String eventId) {
    return eventReference(eventId).collection(messagesCollection);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessageDocuments(
    String eventId, {
    int limit = 100,
  }) {
    final int safeLimit = limit.clamp(1, 200);

    return messagesReference(
      eventId,
    ).orderBy('createdAt', descending: true).limit(safeLimit).snapshots();
  }

  Stream<List<ChatMessage>> watchMessages(String eventId, {int limit = 100}) {
    return watchMessageDocuments(eventId, limit: limit).map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      return snapshot.docs
          .map(ChatMessage.fromDocument)
          .toList(growable: false);
    });
  }

  Future<List<ChatMessage>> getMessages(
    String eventId, {
    int limit = 100,
  }) async {
    final int safeLimit = limit.clamp(1, 200);

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await messagesReference(
            eventId,
          ).orderBy('createdAt', descending: true).limit(safeLimit).get();

      return snapshot.docs
          .map(ChatMessage.fromDocument)
          .toList(growable: false);
    } on FirebaseException catch (error) {
      throw ChatServiceException.fromFirebase(
        error,
        fallback: 'Mesajlar yüklenemedi.',
      );
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchEventChat(
    String eventId,
  ) {
    return eventReference(eventId).snapshots();
  }

  Stream<List<String>> watchTypingUserIds(String eventId) {
    final String currentUserId = _auth.currentUser?.uid ?? '';

    return watchEventChat(eventId).map((
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) {
      final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};

      final Map<String, dynamic> typingUsers = _mapValue(data['typingUsers']);

      final Timestamp nowTimestamp = Timestamp.now();

      final List<String> activeUserIds = <String>[];

      for (final MapEntry<String, dynamic> entry in typingUsers.entries) {
        if (entry.key == currentUserId) {
          continue;
        }

        final DateTime? updatedAt = _dateValue(entry.value);

        if (updatedAt == null) {
          continue;
        }

        final Duration difference = nowTimestamp.toDate().difference(updatedAt);

        if (difference.inSeconds <= 8) {
          activeUserIds.add(entry.key);
        }
      }

      return activeUserIds;
    });
  }

  Future<ChatSenderProfile> getCurrentSenderProfile() async {
    final User user = _requiredUser;

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(usersCollection)
          .doc(user.uid)
          .get();

      final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};

      final String displayName = _firstText(data, <String>[
        'displayName',
        'profilAdi',
        'name',
        'adSoyad',
      ], fallback: user.displayName?.trim() ?? '');

      final String photoUrl = _firstText(data, <String>[
        'photoUrl',
        'profilFotografi',
        'profilePhotoUrl',
        'avatarUrl',
      ], fallback: user.photoURL?.trim() ?? '');

      return ChatSenderProfile(
        uid: user.uid,
        displayName: displayName.isEmpty ? 'Üye' : displayName,
        photoUrl: photoUrl,
      );
    } on FirebaseException catch (error) {
      throw ChatServiceException.fromFirebase(
        error,
        fallback: 'Kullanıcı bilgileri alınamadı.',
      );
    }
  }

  Future<String> sendTextMessage({
    required String eventId,
    required String text,
  }) async {
    _requiredUser;

    final String normalizedEventId = eventId.trim();
    final String normalizedText = text.trim();

    if (normalizedEventId.isEmpty) {
      throw const ChatServiceException(
        'Etkinlik kimliği boş olamaz.',
        code: 'invalid-event-id',
      );
    }

    if (normalizedText.isEmpty) {
      throw const ChatServiceException(
        'Boş mesaj gönderilemez.',
        code: 'empty-message',
      );
    }

    if (normalizedText.length > 2000) {
      throw const ChatServiceException(
        'Mesaj en fazla 2000 karakter olabilir.',
        code: 'message-too-long',
      );
    }

    try {
      final HttpsCallableResult<dynamic> result = await _functions
          .httpsCallable('sendEventMessage')
          .call<dynamic>(<String, dynamic>{
            'eventId': normalizedEventId,
            'text': normalizedText,
          });

      final dynamic rawData = result.data;

      if (rawData is! Map) {
        throw const ChatServiceException(
          'Mesaj gönderimi tamamlanamadı.',
          code: 'invalid-server-response',
        );
      }

      final String messageId = rawData['messageId']?.toString().trim() ?? '';

      if (messageId.isEmpty) {
        throw const ChatServiceException(
          'Mesaj gönderimi tamamlanamadı.',
          code: 'invalid-server-response',
        );
      }

      return messageId;
    } on ChatServiceException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw ChatServiceException.fromFunctions(
        error,
        fallback: 'Mesaj gönderilemedi.',
      );
    }
  }

  Future<void> editMessage({
    required String eventId,
    required String messageId,
    required String newText,
  }) async {
    _requiredUser;

    final String normalizedEventId = eventId.trim();
    final String normalizedMessageId = messageId.trim();
    final String normalizedText = newText.trim();

    if (normalizedEventId.isEmpty) {
      throw const ChatServiceException(
        'Etkinlik kimliği boş olamaz.',
        code: 'invalid-event-id',
      );
    }

    if (normalizedMessageId.isEmpty) {
      throw const ChatServiceException(
        'Mesaj kimliği boş olamaz.',
        code: 'invalid-message-id',
      );
    }

    if (normalizedText.isEmpty) {
      throw const ChatServiceException(
        'Mesaj metni boş olamaz.',
        code: 'empty-message',
      );
    }

    if (normalizedText.length > 2000) {
      throw const ChatServiceException(
        'Mesaj en fazla 2000 karakter olabilir.',
        code: 'message-too-long',
      );
    }

    try {
      await _functions
          .httpsCallable('editEventMessage')
          .call<void>(<String, dynamic>{
            'eventId': normalizedEventId,
            'messageId': normalizedMessageId,
            'text': normalizedText,
          });
    } on FirebaseFunctionsException catch (error) {
      throw ChatServiceException.fromFunctions(
        error,
        fallback: 'Mesaj düzenlenemedi.',
      );
    }
  }

  Future<void> deleteMessage({
    required String eventId,
    required String messageId,
  }) async {
    _requiredUser;

    final String normalizedEventId = eventId.trim();
    final String normalizedMessageId = messageId.trim();

    if (normalizedEventId.isEmpty) {
      throw const ChatServiceException(
        'Etkinlik kimliği boş olamaz.',
        code: 'invalid-event-id',
      );
    }

    if (normalizedMessageId.isEmpty) {
      throw const ChatServiceException(
        'Mesaj kimliği boş olamaz.',
        code: 'invalid-message-id',
      );
    }

    try {
      await _functions.httpsCallable('deleteEventMessage').call<void>(
        <String, dynamic>{
          'eventId': normalizedEventId,
          'messageId': normalizedMessageId,
        },
      );
    } on FirebaseFunctionsException catch (error) {
      throw ChatServiceException.fromFunctions(
        error,
        fallback: 'Mesaj silinemedi.',
      );
    }
  }

  Future<void> markMessagesAsRead({
    required String eventId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? documents,
  }) async {
    final User user = _requiredUser;

    try {
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> messageDocuments;

      if (documents != null) {
        messageDocuments = documents;
      } else {
        final QuerySnapshot<Map<String, dynamic>> snapshot =
            await messagesReference(
              eventId,
            ).where('senderUid', isNotEqualTo: user.uid).limit(100).get();

        messageDocuments = snapshot.docs;
      }

      final List<QueryDocumentSnapshot<Map<String, dynamic>>> unreadDocuments =
          messageDocuments
              .where((QueryDocumentSnapshot<Map<String, dynamic>> document) {
                final Map<String, dynamic> data = document.data();

                final String senderUid = _textValue(data['senderUid']);

                final List<String> readBy = _stringList(data['readBy']);

                return senderUid.isNotEmpty &&
                    senderUid != user.uid &&
                    !readBy.contains(user.uid);
              })
              .toList(growable: false);

      final DocumentReference<Map<String, dynamic>> eventRef = eventReference(
        eventId,
      );

      if (unreadDocuments.isEmpty) {
        await eventRef.update(<String, dynamic>{
          'lastMessageReadBy': FieldValue.arrayUnion(<String>[user.uid]),
        });

        return;
      }

      const int batchLimit = 450;

      for (int start = 0; start < unreadDocuments.length; start += batchLimit) {
        final int end = (start + batchLimit) > unreadDocuments.length
            ? unreadDocuments.length
            : start + batchLimit;

        final WriteBatch batch = _firestore.batch();

        for (final QueryDocumentSnapshot<Map<String, dynamic>> document
            in unreadDocuments.sublist(start, end)) {
          batch.update(document.reference, <String, dynamic>{
            'readBy': FieldValue.arrayUnion(<String>[user.uid]),
          });
        }

        batch.update(eventRef, <String, dynamic>{
          'lastMessageReadBy': FieldValue.arrayUnion(<String>[user.uid]),
        });

        await batch.commit();
      }
    } on FirebaseException catch (error) {
      throw ChatServiceException.fromFirebase(
        error,
        fallback: 'Okundu bilgisi güncellenemedi.',
      );
    }
  }

  Future<void> setTyping({
    required String eventId,
    required bool isTyping,
  }) async {
    final User user = _requiredUser;
    final DocumentReference<Map<String, dynamic>> eventRef = eventReference(
      eventId,
    );

    try {
      if (isTyping) {
        await eventRef.update(<String, dynamic>{
          'typingUsers.${user.uid}': FieldValue.serverTimestamp(),
        });
      } else {
        await eventRef.update(<String, dynamic>{
          'typingUsers.${user.uid}': FieldValue.delete(),
        });
      }
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw ChatServiceException.fromFirebase(
          error,
          fallback: 'Yazıyor bilgisi güncellenemedi.',
        );
      }
    }
  }

  Future<void> clearTyping({required String eventId}) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      await eventReference(eventId).update(<String, dynamic>{
        'typingUsers.${user.uid}': FieldValue.delete(),
      });
    } catch (_) {
      // Yazıyor bilgisinin temizlenememesi sohbeti durdurmaz.
    }
  }

  Future<bool> canCurrentUserAccessChat(String eventId) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await eventReference(eventId).get();

      if (!snapshot.exists) {
        return false;
      }

      final Map<String, dynamic> eventData =
          snapshot.data() ?? <String, dynamic>{};
      Map<String, dynamic>? application;
      var applicationResolved = false;

      if (requiresCanonicalApplication(eventData, user.uid)) {
        final DocumentSnapshot<Map<String, dynamic>> applicationSnapshot =
            await eventReference(
              eventId,
            ).collection('applications').doc(user.uid).get();
        application = applicationSnapshot.data();
        applicationResolved = true;
      }

      return messageReadAllowed(
        event: eventData,
        uid: user.uid,
        application: application,
        applicationResolved: applicationResolved,
      );
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return false;
      }

      rethrow;
    }
  }

  /// Mirrors `isChatMember` in firestore.rules.
  ///
  /// Event payment must be one of the exact paid statuses. Lifecycle v2
  /// players also need a selected slot and an unlocked, paid application.
  /// Owners do not. Missing lifecycle version follows the legacy branch.
  static bool messageReadAllowed({
    required Map<String, dynamic> event,
    required String uid,
    Map<String, dynamic>? application,
    bool applicationResolved = false,
  }) {
    if (EventModel.mapIsFreeAccess(event)) {
      if (_isRulesEventOwner(event, uid)) {
        return true;
      }

      return _isRulesSelectedPlayer(event, uid) &&
          applicationResolved &&
          _hasFreeMembershipAccess(application);
    }

    if (!_hasRulesPaidEventPayment(event)) {
      return false;
    }

    if (_isRulesEventOwner(event, uid)) {
      return true;
    }

    if (_isRulesLifecycleV2(event)) {
      return _isRulesSelectedPlayer(event, uid) &&
          applicationResolved &&
          _hasRulesCanonicalAddressAccess(application);
    }

    return _isRulesSelectedPlayer(event, uid) ||
        _rulesListContains(event['chatMemberUids'], uid);
  }

  static bool requiresCanonicalApplication(
    Map<String, dynamic> event,
    String uid,
  ) {
    if (EventModel.mapIsFreeAccess(event)) {
      return !_isRulesEventOwner(event, uid);
    }

    return _hasRulesPaidEventPayment(event) &&
        !_isRulesEventOwner(event, uid) &&
        _isRulesLifecycleV2(event);
  }

  static String applicationCacheKey(
    String eventId,
    Map<String, dynamic> event,
  ) {
    return '$eventId|${event['paymentStatus']}';
  }

  static bool _hasRulesPaidEventPayment(Map<String, dynamic> event) {
    final Object? status = event['paymentStatus'];

    return status == 'paid' ||
        status == 'completed' ||
        status == 'success' ||
        status == 'succeeded' ||
        status == 'escrowheld' ||
        status == 'escrow_held';
  }

  static bool _isRulesEventOwner(Map<String, dynamic> event, String uid) {
    return event['olusturanUid'] == uid;
  }

  static bool _isRulesLifecycleV2(Map<String, dynamic> event) {
    final Object? version = event['lifecycleVersion'];
    return version == 2;
  }

  static bool _isRulesSelectedPlayer(Map<String, dynamic> event, String uid) {
    return _rulesListContains(event['selectedPlayerIds'], uid);
  }

  static bool _hasFreeMembershipAccess(Map<String, dynamic>? application) {
    if (application == null) {
      return false;
    }

    final String status =
        application['status']?.toString().trim().toLowerCase() ?? '';
    final String paymentStatus =
        application['paymentStatus']?.toString().trim().toLowerCase() ?? '';
    const Set<String> blocked = <String>{
      'pending',
      'rejected',
      'withdrawn',
      'removed',
      'left',
      'cancelled',
      'refund_pending',
      'refunded',
    };

    return application['addressAccessStatus'] == 'unlocked' &&
        paymentStatus == 'not_required' &&
        !blocked.contains(status);
  }

  static bool _hasRulesCanonicalAddressAccess(
    Map<String, dynamic>? application,
  ) {
    if (application == null) {
      return false;
    }

    final Object? paymentStatus = application['paymentStatus'];

    return application['addressAccessStatus'] == 'unlocked' &&
        (paymentStatus == 'paid' || paymentStatus == 'completed');
  }

  static bool _rulesListContains(Object? value, String uid) {
    if (value is! List) {
      return false;
    }

    return value.contains(uid);
  }

  Future<void> ensureCurrentUserIsChatMember(String eventId) async {
    _requiredUser;

    final bool canAccess = await canCurrentUserAccessChat(eventId);

    if (!canAccess) {
      throw const ChatServiceException(
        'Bu etkinliğin sohbetine erişim iznin yok.',
        code: 'chat-access-denied',
      );
    }
  }

  static String _firstText(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final String key in keys) {
      final String value = _textValue(data[key]);

      if (value.isNotEmpty) {
        return value;
      }
    }

    return fallback.trim();
  }

  static String _textValue(Object? value) {
    if (value == null) {
      return '';
    }

    final String text = value.toString().trim();

    if (text.toLowerCase() == 'null') {
      return '';
    }

    return text;
  }

  static List<String> _stringList(Object? value) {
    if (value is! Iterable) {
      return <String>[];
    }

    return value
        .map(_textValue)
        .where((String item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static Map<String, dynamic> _mapValue(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map((Object? key, Object? item) {
        return MapEntry<String, dynamic>(key.toString(), item);
      });
    }

    return <String, dynamic>{};
  }

  static DateTime? _dateValue(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    return null;
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.eventId,
    required this.type,
    required this.text,
    required this.senderUid,
    required this.senderName,
    required this.senderPhotoUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.edited,
    required this.deleted,
    required this.readBy,
  });

  final String id;
  final String eventId;
  final ChatMessageType type;
  final String text;
  final String senderUid;
  final String senderName;
  final String senderPhotoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool edited;
  final bool deleted;
  final List<String> readBy;

  bool isMine(String currentUserId) {
    return senderUid == currentUserId;
  }

  bool isReadByAnotherUser(String currentUserId) {
    return readBy.any((String userId) => userId != currentUserId);
  }

  String get previewText {
    if (deleted) {
      return 'Mesaj silindi';
    }

    switch (type) {
      case ChatMessageType.image:
        return 'Fotoğraf';
      case ChatMessageType.system:
        return text.isEmpty ? 'Sistem mesajı' : text;
      case ChatMessageType.text:
        return text;
    }
  }

  factory ChatMessage.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return ChatMessage.fromMap(id: document.id, data: document.data());
  }

  factory ChatMessage.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return ChatMessage.fromMap(
      id: document.id,
      data: document.data() ?? <String, dynamic>{},
    );
  }

  factory ChatMessage.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final String typeText = ChatService._textValue(data['type']);

    return ChatMessage(
      id: ChatService._firstText(data, <String>[
        'messageId',
        'id',
      ], fallback: id),
      eventId: ChatService._firstText(data, <String>['eventId', 'etkinlikId']),
      type: ChatMessageType.values.firstWhere(
        (ChatMessageType type) => type.name == typeText,
        orElse: () => ChatMessageType.text,
      ),
      text: ChatService._firstText(data, <String>['text', 'message', 'mesaj']),
      senderUid: ChatService._firstText(data, <String>[
        'senderUid',
        'gonderenUid',
        'userId',
      ]),
      senderName: ChatService._firstText(data, <String>[
        'senderName',
        'gonderenAdi',
        'displayName',
      ], fallback: 'Üye'),
      senderPhotoUrl: ChatService._firstText(data, <String>[
        'senderPhotoUrl',
        'gonderenFotoUrl',
        'photoUrl',
      ]),
      createdAt: ChatService._dateValue(
        data['createdAt'] ?? data['olusturulmaZamani'],
      ),
      updatedAt: ChatService._dateValue(
        data['updatedAt'] ?? data['guncellenmeZamani'],
      ),
      edited: data['edited'] == true,
      deleted: data['deleted'] == true,
      readBy: ChatService._stringList(data['readBy'] ?? data['okuyanlar']),
    );
  }
}

class ChatSenderProfile {
  const ChatSenderProfile({
    required this.uid,
    required this.displayName,
    required this.photoUrl,
  });

  final String uid;
  final String displayName;
  final String photoUrl;
}

enum ChatMessageType { text, image, system }

class ChatServiceException implements Exception {
  const ChatServiceException(this.message, {this.code = 'chat-error'});

  final String message;
  final String code;

  factory ChatServiceException.fromFunctions(
    FirebaseFunctionsException error, {
    required String fallback,
  }) {
    final String message = error.message?.trim() ?? '';

    return ChatServiceException(
      message.isNotEmpty ? message : fallback,
      code: error.code,
    );
  }

  factory ChatServiceException.fromFirebase(
    FirebaseException error, {
    required String fallback,
  }) {
    switch (error.code) {
      case 'permission-denied':
        return const ChatServiceException(
          'Bu işlem için yetkin yok.',
          code: 'permission-denied',
        );
      case 'not-found':
        return const ChatServiceException(
          'İstenen sohbet veya mesaj bulunamadı.',
          code: 'not-found',
        );
      case 'unavailable':
        return const ChatServiceException(
          'Bağlantı kurulamadı. İnternet bağlantını kontrol et.',
          code: 'unavailable',
        );
      case 'failed-precondition':
        return const ChatServiceException(
          'Bu işlem için gerekli Firestore indexi veya yapılandırması eksik.',
          code: 'failed-precondition',
        );
      case 'unauthenticated':
        return const ChatServiceException(
          'Mesajlaşmak için giriş yapmalısın.',
          code: 'not-authenticated',
        );
      default:
        return ChatServiceException(
          error.message?.trim().isNotEmpty == true
              ? error.message!.trim()
              : fallback,
          code: error.code,
        );
    }
  }

  @override
  String toString() => message;
}
