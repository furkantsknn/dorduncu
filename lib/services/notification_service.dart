import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  NotificationService._();

  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;
  static final FirebaseAuth _auth =
      FirebaseAuth.instance;

  static const String usersCollection = 'users';
  static const String notificationsCollection =
      'notifications';

  static CollectionReference<Map<String, dynamic>>
  notificationsReference(
      String userId,
      ) {
    final String normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      throw const NotificationServiceException(
        'Kullanıcı kimliği boş olamaz.',
        code: 'invalid-user-id',
      );
    }

    return _firestore
        .collection(usersCollection)
        .doc(normalizedUserId)
        .collection(notificationsCollection);
  }

  static CollectionReference<Map<String, dynamic>>
  currentUserNotificationsReference() {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw const NotificationServiceException(
        'Bildirimleri görmek için giriş yapmalısın.',
        code: 'not-authenticated',
      );
    }

    return notificationsReference(user.uid);
  }

  static Stream<
      QuerySnapshot<Map<String, dynamic>>>
  watchNotificationDocuments({
    String? userId,
    int limit = 100,
  }) {
    final String resolvedUserId =
    _resolveUserId(userId);
    final int safeLimit = limit.clamp(1, 250);

    return notificationsReference(
      resolvedUserId,
    )
        .orderBy(
      'createdAt',
      descending: true,
    )
        .limit(safeLimit)
        .snapshots();
  }

  static Stream<List<AppNotification>>
  watchNotifications({
    String? userId,
    int limit = 100,
  }) {
    return watchNotificationDocuments(
      userId: userId,
      limit: limit,
    ).map(
          (
          QuerySnapshot<Map<String, dynamic>>
          snapshot,
          ) {
        return snapshot.docs
            .map(
          AppNotification.fromDocument,
        )
            .toList(growable: false);
      },
    );
  }

  static Stream<int> watchUnreadCount({
    String? userId,
    int limit = 400,
  }) {
    return watchNotificationDocuments(
      userId: userId,
      limit: limit,
    ).map(
          (
          QuerySnapshot<Map<String, dynamic>>
          snapshot,
          ) {
        return snapshot.docs.where(
              (
              QueryDocumentSnapshot<
                  Map<String, dynamic>>
              document,
              ) {
            return !isReadData(
              document.data(),
            );
          },
        ).length;
      },
    );
  }

  static Future<List<AppNotification>>
  getNotifications({
    String? userId,
    int limit = 100,
  }) async {
    final String resolvedUserId =
    _resolveUserId(userId);
    final int safeLimit = limit.clamp(1, 250);

    try {
      final QuerySnapshot<Map<String, dynamic>>
      snapshot = await notificationsReference(
        resolvedUserId,
      )
          .orderBy(
        'createdAt',
        descending: true,
      )
          .limit(safeLimit)
          .get();

      return snapshot.docs
          .map(
        AppNotification.fromDocument,
      )
          .toList(growable: false);
    } on FirebaseException catch (error) {
      throw NotificationServiceException
          .fromFirebase(
        error,
        fallback:
        'Bildirimler yüklenemedi.',
      );
    }
  }

  static Future<int> getUnreadCount({
    String? userId,
    int limit = 400,
  }) async {
    final List<AppNotification> notifications =
    await getNotifications(
      userId: userId,
      limit: limit,
    );

    return notifications.where(
          (AppNotification notification) =>
      !notification.isRead,
    ).length;
  }

  static Future<String> create({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? eventId,
    String? eventTitle,
    String? senderUid,
    String? senderName,
    String? senderPhotoUrl,
    String? route,
    Map<String, dynamic>? data,
    Map<String, dynamic>? extra,
  }) async {
    return send(
      userUid: userId,
      type: type,
      title: title,
      message: body,
      eventId: eventId,
      eventTitle: eventTitle,
      senderUid: senderUid,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      route: route,
      data: data,
      extra: extra,
    );
  }

  static Future<String> send({
    required String userUid,
    required String type,
    required String title,
    required String message,
    String? eventId,
    String? eventTitle,
    String? senderUid,
    String? senderName,
    String? senderPhotoUrl,
    String? route,
    Map<String, dynamic>? data,
    Map<String, dynamic>? extra,
  }) async {
    final String normalizedUserId =
    userUid.trim();
    final String normalizedTitle =
    title.trim();
    final String normalizedMessage =
    message.trim();
    final String normalizedType =
    type.trim().isEmpty
        ? NotificationType.system.name
        : type.trim();

    if (normalizedUserId.isEmpty) {
      throw const NotificationServiceException(
        'Bildirim alıcısı belirtilmedi.',
        code: 'invalid-user-id',
      );
    }

    if (normalizedTitle.isEmpty) {
      throw const NotificationServiceException(
        'Bildirim başlığı boş olamaz.',
        code: 'empty-title',
      );
    }

    if (normalizedMessage.isEmpty) {
      throw const NotificationServiceException(
        'Bildirim metni boş olamaz.',
        code: 'empty-message',
      );
    }

    final DocumentReference<Map<String, dynamic>>
    reference = notificationsReference(
      normalizedUserId,
    ).doc();

    final Map<String, dynamic> payload =
    <String, dynamic>{
      'notificationId': reference.id,
      'userId': normalizedUserId,
      'type': normalizedType,
      'notificationType': normalizedType,
      'category': normalizedType,
      'title': normalizedTitle,
      'message': normalizedMessage,
      'body': normalizedMessage,
      'description': normalizedMessage,
      'eventId': _nullableText(eventId),
      'relatedEventId': _nullableText(eventId),
      'eventTitle': _nullableText(eventTitle),
      'senderUid': _nullableText(senderUid),
      'senderName': _nullableText(senderName),
      'senderPhotoUrl':
      _nullableText(senderPhotoUrl),
      'route': _nullableText(route),
      'read': false,
      'isRead': false,
      'okundu': false,
      'createdAt':
      FieldValue.serverTimestamp(),
      'updatedAt':
      FieldValue.serverTimestamp(),
      'data': ?data,
      ...?extra,
    };

    try {
      await reference.set(payload);
      return reference.id;
    } on FirebaseException catch (error) {
      throw NotificationServiceException
          .fromFirebase(
        error,
        fallback:
        'Bildirim oluşturulamadı.',
      );
    }
  }

  static Future<String>
  createApplicationNotification({
    required String receiverUserId,
    required String eventId,
    required String eventTitle,
    required String applicantUserId,
    required String applicantName,
    String? applicantPhotoUrl,
  }) {
    return create(
      userId: receiverUserId,
      title: 'Yeni etkinlik başvurusu',
      body:
      '$applicantName, $eventTitle etkinliğine katılmak istiyor.',
      type: NotificationType.application.name,
      eventId: eventId,
      eventTitle: eventTitle,
      senderUid: applicantUserId,
      senderName: applicantName,
      senderPhotoUrl: applicantPhotoUrl,
      data: <String, dynamic>{
        'applicantUserId':
        applicantUserId,
      },
    );
  }

  static Future<String>
  createApplicationAcceptedNotification({
    required String receiverUserId,
    required String eventId,
    required String eventTitle,
    String? senderUid,
    String? senderName,
  }) {
    return create(
      userId: receiverUserId,
      title: 'Başvurun kabul edildi',
      body:
      '$eventTitle etkinliğine katılım başvurun kabul edildi.',
      type:
      NotificationType.applicationAccepted.name,
      eventId: eventId,
      eventTitle: eventTitle,
      senderUid: senderUid,
      senderName: senderName,
    );
  }

  static Future<String>
  createApplicationRejectedNotification({
    required String receiverUserId,
    required String eventId,
    required String eventTitle,
    String? senderUid,
    String? senderName,
    String? reason,
  }) {
    final String normalizedReason =
        reason?.trim() ?? '';

    return create(
      userId: receiverUserId,
      title: 'Başvuru sonucu',
      body: normalizedReason.isEmpty
          ? '$eventTitle etkinliğine katılım başvurun kabul edilmedi.'
          : '$eventTitle etkinliğine katılım başvurun kabul edilmedi. $normalizedReason',
      type:
      NotificationType.applicationRejected.name,
      eventId: eventId,
      eventTitle: eventTitle,
      senderUid: senderUid,
      senderName: senderName,
      data: normalizedReason.isEmpty
          ? null
          : <String, dynamic>{
        'reason': normalizedReason,
      },
    );
  }

  static Future<String>
  createMessageNotification({
    required String receiverUserId,
    required String eventId,
    required String eventTitle,
    required String senderUid,
    required String senderName,
    required String messagePreview,
    String? senderPhotoUrl,
  }) {
    final String preview =
    messagePreview.trim();

    return create(
      userId: receiverUserId,
      title: senderName,
      body: preview.isEmpty
          ? '$eventTitle sohbetinde yeni bir mesajın var.'
          : preview,
      type: NotificationType.message.name,
      eventId: eventId,
      eventTitle: eventTitle,
      senderUid: senderUid,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      route: 'eventChat',
    );
  }

  static Future<String>
  createEventCancelledNotification({
    required String receiverUserId,
    required String eventId,
    required String eventTitle,
    String? senderUid,
    String? senderName,
  }) {
    return create(
      userId: receiverUserId,
      title: 'Etkinlik iptal edildi',
      body:
      '$eventTitle etkinliği organizatör tarafından iptal edildi.',
      type:
      NotificationType.eventCancelled.name,
      eventId: eventId,
      eventTitle: eventTitle,
      senderUid: senderUid,
      senderName: senderName,
    );
  }

  static Future<String>
  createSystemNotification({
    required String receiverUserId,
    required String title,
    required String body,
    String? route,
    Map<String, dynamic>? data,
  }) {
    return create(
      userId: receiverUserId,
      title: title,
      body: body,
      type: NotificationType.system.name,
      route: route,
      data: data,
    );
  }

  static Future<void> markRead({
    required String notificationId,
    String? userId,
  }) async {
    final String resolvedUserId =
    _resolveUserId(userId);
    final String normalizedNotificationId =
    notificationId.trim();

    if (normalizedNotificationId.isEmpty) {
      throw const NotificationServiceException(
        'Bildirim kimliği boş olamaz.',
        code: 'invalid-notification-id',
      );
    }

    try {
      await notificationsReference(
        resolvedUserId,
      ).doc(normalizedNotificationId).set(
        <String, dynamic>{
          'read': true,
          'isRead': true,
          'okundu': true,
          'readAt':
          FieldValue.serverTimestamp(),
          'updatedAt':
          FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } on FirebaseException catch (error) {
      throw NotificationServiceException
          .fromFirebase(
        error,
        fallback:
        'Bildirim okundu olarak işaretlenemedi.',
      );
    }
  }

  static Future<void> markUnread({
    required String notificationId,
    String? userId,
  }) async {
    final String resolvedUserId =
    _resolveUserId(userId);
    final String normalizedNotificationId =
    notificationId.trim();

    if (normalizedNotificationId.isEmpty) {
      throw const NotificationServiceException(
        'Bildirim kimliği boş olamaz.',
        code: 'invalid-notification-id',
      );
    }

    try {
      await notificationsReference(
        resolvedUserId,
      ).doc(normalizedNotificationId).set(
        <String, dynamic>{
          'read': false,
          'isRead': false,
          'okundu': false,
          'readAt': FieldValue.delete(),
          'updatedAt':
          FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } on FirebaseException catch (error) {
      throw NotificationServiceException
          .fromFirebase(
        error,
        fallback:
        'Bildirim okunmamış olarak işaretlenemedi.',
      );
    }
  }

  static Future<int> markAllRead([
    String? userUid,
  ]) async {
    final String resolvedUserId =
    _resolveUserId(userUid);

    try {
      final QuerySnapshot<Map<String, dynamic>>
      snapshot = await notificationsReference(
        resolvedUserId,
      ).limit(500).get();

      final List<
          QueryDocumentSnapshot<
              Map<String, dynamic>>>
      unreadDocuments =
      snapshot.docs.where(
            (
            QueryDocumentSnapshot<
                Map<String, dynamic>>
            document,
            ) {
          return !isReadData(
            document.data(),
          );
        },
      ).toList(growable: false);

      if (unreadDocuments.isEmpty) {
        return 0;
      }

      const int batchSize = 450;
      int updatedCount = 0;

      for (int start = 0;
      start < unreadDocuments.length;
      start += batchSize) {
        final int end =
        (start + batchSize) >
            unreadDocuments.length
            ? unreadDocuments.length
            : start + batchSize;

        final WriteBatch batch =
        _firestore.batch();

        for (final QueryDocumentSnapshot<
            Map<String, dynamic>>
        document in unreadDocuments.sublist(
          start,
          end,
        )) {
          batch.set(
            document.reference,
            <String, dynamic>{
              'read': true,
              'isRead': true,
              'okundu': true,
              'readAt':
              FieldValue.serverTimestamp(),
              'updatedAt':
              FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }

        await batch.commit();
        updatedCount += end - start;
      }

      return updatedCount;
    } on FirebaseException catch (error) {
      throw NotificationServiceException
          .fromFirebase(
        error,
        fallback:
        'Bildirimler güncellenemedi.',
      );
    }
  }

  static Future<void> deleteNotification({
    required String notificationId,
    String? userId,
  }) async {
    final String resolvedUserId =
    _resolveUserId(userId);
    final String normalizedNotificationId =
    notificationId.trim();

    if (normalizedNotificationId.isEmpty) {
      throw const NotificationServiceException(
        'Bildirim kimliği boş olamaz.',
        code: 'invalid-notification-id',
      );
    }

    try {
      await notificationsReference(
        resolvedUserId,
      ).doc(normalizedNotificationId).delete();
    } on FirebaseException catch (error) {
      throw NotificationServiceException
          .fromFirebase(
        error,
        fallback:
        'Bildirim silinemedi.',
      );
    }
  }

  static Future<int> deleteAll({
    String? userId,
    bool onlyRead = false,
  }) async {
    final String resolvedUserId =
    _resolveUserId(userId);

    try {
      final QuerySnapshot<Map<String, dynamic>>
      snapshot = await notificationsReference(
        resolvedUserId,
      ).limit(500).get();

      final List<
          QueryDocumentSnapshot<
              Map<String, dynamic>>>
      documents = snapshot.docs.where(
            (
            QueryDocumentSnapshot<
                Map<String, dynamic>>
            document,
            ) {
          if (!onlyRead) {
            return true;
          }

          return isReadData(
            document.data(),
          );
        },
      ).toList(growable: false);

      if (documents.isEmpty) {
        return 0;
      }

      const int batchSize = 450;
      int deletedCount = 0;

      for (int start = 0;
      start < documents.length;
      start += batchSize) {
        final int end =
        (start + batchSize) >
            documents.length
            ? documents.length
            : start + batchSize;

        final WriteBatch batch =
        _firestore.batch();

        for (final QueryDocumentSnapshot<
            Map<String, dynamic>>
        document in documents.sublist(
          start,
          end,
        )) {
          batch.delete(document.reference);
        }

        await batch.commit();
        deletedCount += end - start;
      }

      return deletedCount;
    } on FirebaseException catch (error) {
      throw NotificationServiceException
          .fromFirebase(
        error,
        fallback:
        'Bildirimler silinemedi.',
      );
    }
  }

  static Future<int> deleteOlderThan({
    String? userId,
    required DateTime date,
  }) async {
    final String resolvedUserId =
    _resolveUserId(userId);

    try {
      final QuerySnapshot<Map<String, dynamic>>
      snapshot = await notificationsReference(
        resolvedUserId,
      )
          .where(
        'createdAt',
        isLessThan:
        Timestamp.fromDate(date),
      )
          .limit(450)
          .get();

      if (snapshot.docs.isEmpty) {
        return 0;
      }

      final WriteBatch batch =
      _firestore.batch();

      for (final QueryDocumentSnapshot<
          Map<String, dynamic>>
      document in snapshot.docs) {
        batch.delete(document.reference);
      }

      await batch.commit();
      return snapshot.docs.length;
    } on FirebaseException catch (error) {
      throw NotificationServiceException
          .fromFirebase(
        error,
        fallback:
        'Eski bildirimler silinemedi.',
      );
    }
  }

  static bool isReadData(
      Map<String, dynamic> data,
      ) {
    return data['read'] == true ||
        data['isRead'] == true ||
        data['okundu'] == true;
  }

  static String _resolveUserId(
      String? userId,
      ) {
    final String explicitUserId =
        userId?.trim() ?? '';

    if (explicitUserId.isNotEmpty) {
      return explicitUserId;
    }

    final User? currentUser =
        _auth.currentUser;

    if (currentUser == null) {
      throw const NotificationServiceException(
        'Bildirimleri görmek için giriş yapmalısın.',
        code: 'not-authenticated',
      );
    }

    return currentUser.uid;
  }

  static String? _nullableText(
      String? value,
      ) {
    final String normalized =
        value?.trim() ?? '';

    return normalized.isEmpty
        ? null
        : normalized;
  }

  static String _firstText(
      Map<String, dynamic> data,
      List<String> keys, {
        String fallback = '',
      }) {
    for (final String key in keys) {
      final Object? rawValue = data[key];

      if (rawValue == null) {
        continue;
      }

      final String value =
      rawValue.toString().trim();

      if (value.isNotEmpty &&
          value.toLowerCase() != 'null') {
        return value;
      }
    }

    return fallback.trim();
  }

  static DateTime? _dateValue(
      Object? value,
      ) {
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
      return DateTime.fromMillisecondsSinceEpoch(
        value,
      );
    }

    return null;
  }

  static Map<String, dynamic> _mapValue(
      Object? value,
      ) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map(
            (
            Object? key,
            Object? item,
            ) {
          return MapEntry<String, dynamic>(
            key.toString(),
            item,
          );
        },
      );
    }

    return <String, dynamic>{};
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.eventId,
    required this.eventTitle,
    required this.senderUid,
    required this.senderName,
    required this.senderPhotoUrl,
    required this.route,
    required this.isRead,
    required this.createdAt,
    required this.readAt,
    required this.data,
  });

  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final String eventId;
  final String eventTitle;
  final String senderUid;
  final String senderName;
  final String senderPhotoUrl;
  final String route;
  final bool isRead;
  final DateTime? createdAt;
  final DateTime? readAt;
  final Map<String, dynamic> data;

  bool get hasEvent => eventId.isNotEmpty;
  bool get hasSender => senderUid.isNotEmpty;

  AppNotification copyWith({
    bool? isRead,
    DateTime? readAt,
  }) {
    return AppNotification(
      id: id,
      userId: userId,
      type: type,
      title: title,
      body: body,
      eventId: eventId,
      eventTitle: eventTitle,
      senderUid: senderUid,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      route: route,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      data: data,
    );
  }

  factory AppNotification.fromDocument(
      QueryDocumentSnapshot<
          Map<String, dynamic>>
      document,
      ) {
    return AppNotification.fromMap(
      id: document.id,
      data: document.data(),
    );
  }

  factory AppNotification.fromSnapshot(
      DocumentSnapshot<Map<String, dynamic>>
      document,
      ) {
    return AppNotification.fromMap(
      id: document.id,
      data: document.data() ??
          <String, dynamic>{},
    );
  }

  factory AppNotification.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final String rawType =
    NotificationService._firstText(
      data,
      <String>[
        'type',
        'notificationType',
        'category',
      ],
    ).toLowerCase();

    return AppNotification(
      id: NotificationService._firstText(
        data,
        <String>[
          'notificationId',
          'id',
        ],
        fallback: id,
      ),
      userId:
      NotificationService._firstText(
        data,
        <String>[
          'userId',
          'userUid',
          'receiverUid',
        ],
      ),
      type: NotificationTypeX.fromValue(
        rawType,
      ),
      title:
      NotificationService._firstText(
        data,
        <String>[
          'title',
          'baslik',
        ],
        fallback: 'Bildirim',
      ),
      body:
      NotificationService._firstText(
        data,
        <String>[
          'message',
          'body',
          'description',
          'text',
        ],
      ),
      eventId:
      NotificationService._firstText(
        data,
        <String>[
          'eventId',
          'relatedEventId',
          'etkinlikId',
        ],
      ),
      eventTitle:
      NotificationService._firstText(
        data,
        <String>[
          'eventTitle',
          'etkinlikBasligi',
          'gameName',
          'oyun',
        ],
      ),
      senderUid:
      NotificationService._firstText(
        data,
        <String>[
          'senderUid',
          'senderUserId',
          'gonderenUid',
        ],
      ),
      senderName:
      NotificationService._firstText(
        data,
        <String>[
          'senderName',
          'gonderenAdi',
          'displayName',
        ],
      ),
      senderPhotoUrl:
      NotificationService._firstText(
        data,
        <String>[
          'senderPhotoUrl',
          'gonderenFotoUrl',
          'photoUrl',
        ],
      ),
      route:
      NotificationService._firstText(
        data,
        <String>[
          'route',
          'screen',
          'target',
        ],
      ),
      isRead:
      NotificationService.isReadData(
        data,
      ),
      createdAt:
      NotificationService._dateValue(
        data['createdAt'] ??
            data['olusturulmaZamani'] ??
            data['timestamp'],
      ),
      readAt:
      NotificationService._dateValue(
        data['readAt'] ??
            data['okunmaZamani'],
      ),
      data:
      NotificationService._mapValue(
        data['data'],
      ),
    );
  }
}

enum NotificationType {
  application,
  applicationAccepted,
  applicationRejected,
  message,
  eventCancelled,
  eventUpdated,
  eventReminder,
  payment,
  refund,
  verification,
  friendRequest,
  friendAccepted,
  system,
  unknown,
}

extension NotificationTypeX
on NotificationType {
  static NotificationType fromValue(
      String value,
      ) {
    final String normalized =
    value.trim().toLowerCase();

    if (normalized.contains('application') &&
        normalized.contains('accept') ||
        normalized.contains('approved') ||
        normalized.contains('kabul')) {
      return NotificationType
          .applicationAccepted;
    }

    if (normalized.contains('application') &&
        normalized.contains('reject') ||
        normalized.contains('declined') ||
        normalized.contains('ret')) {
      return NotificationType
          .applicationRejected;
    }

    if (normalized.contains('application') ||
        normalized.contains('basvuru')) {
      return NotificationType.application;
    }

    if (normalized.contains('message') ||
        normalized.contains('mesaj') ||
        normalized.contains('chat')) {
      return NotificationType.message;
    }

    if (normalized.contains('cancel') ||
        normalized.contains('iptal')) {
      return NotificationType
          .eventCancelled;
    }

    if (normalized.contains('update') ||
        normalized.contains('guncelle')) {
      return NotificationType.eventUpdated;
    }

    if (normalized.contains('reminder') ||
        normalized.contains('hatirlat')) {
      return NotificationType.eventReminder;
    }

    if (normalized.contains('payment') ||
        normalized.contains('odeme')) {
      return NotificationType.payment;
    }

    if (normalized.contains('refund') ||
        normalized.contains('iade')) {
      return NotificationType.refund;
    }

    if (normalized.contains('verification') ||
        normalized.contains('dogrulama')) {
      return NotificationType.verification;
    }

    if (normalized.contains('friend') &&
        normalized.contains('accept') ||
        normalized.contains('arkadas') &&
            normalized.contains('kabul')) {
      return NotificationType.friendAccepted;
    }

    if (normalized.contains('friend_request') ||
        normalized.contains('friendrequest') ||
        normalized.contains('arkadaslik_istegi') ||
        normalized.contains('arkadas_istegi')) {
      return NotificationType.friendRequest;
    }
    if (normalized.contains('system') ||
        normalized.contains('sistem')) {
      return NotificationType.system;
    }

    return NotificationType.unknown;
  }

  String get displayName {
    switch (this) {
      case NotificationType.application:
        return 'Başvuru';
      case NotificationType.applicationAccepted:
        return 'Kabul';
      case NotificationType.applicationRejected:
        return 'Ret';
      case NotificationType.message:
        return 'Mesaj';
      case NotificationType.eventCancelled:
        return 'İptal';
      case NotificationType.eventUpdated:
        return 'Etkinlik';
      case NotificationType.eventReminder:
        return 'Hatırlatma';
      case NotificationType.payment:
        return 'Ödeme';
      case NotificationType.refund:
        return 'İade';
      case NotificationType.verification:
        return 'Doğrulama';
      case NotificationType.friendRequest:
        return 'Arkadaşlık İsteği';

      case NotificationType.friendAccepted:
        return 'Arkadaşlık Kabul Edildi';
      case NotificationType.system:
        return 'Sistem';
      case NotificationType.unknown:
        return 'Bildirim';
    }
  }
}

class NotificationServiceException
    implements Exception {
  const NotificationServiceException(
      this.message, {
        this.code = 'notification-error',
      });

  final String message;
  final String code;

  factory NotificationServiceException
      .fromFirebase(
      FirebaseException error, {
        required String fallback,
      }) {
    switch (error.code) {
      case 'permission-denied':
        return const NotificationServiceException(
          'Bu işlem için yetkin yok.',
          code: 'permission-denied',
        );
      case 'not-found':
        return const NotificationServiceException(
          'Bildirim bulunamadı.',
          code: 'not-found',
        );
      case 'unavailable':
        return const NotificationServiceException(
          'Bağlantı kurulamadı. İnternet bağlantını kontrol et.',
          code: 'unavailable',
        );
      case 'failed-precondition':
        return const NotificationServiceException(
          'Bu işlem için gerekli Firestore indexi veya yapılandırması eksik.',
          code: 'failed-precondition',
        );
      case 'unauthenticated':
        return const NotificationServiceException(
          'Bildirimleri görmek için giriş yapmalısın.',
          code: 'not-authenticated',
        );
      default:
        return NotificationServiceException(
          error.message?.trim().isNotEmpty ==
              true
              ? error.message!.trim()
              : fallback,
          code: error.code,
        );
    }
  }

  @override
  String toString() => message;
}