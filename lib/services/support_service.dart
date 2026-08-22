import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/support_request_model.dart';
import '../utils/support_categories.dart';

class SupportService {
  SupportService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>> get _requestsCollection {
    return _firestore.collection('support_requests');
  }

  static String? get currentUserId {
    return _auth.currentUser?.uid;
  }

  static Stream<List<SupportRequestModel>> watchCurrentUserRequests() {
    final String? uid = currentUserId;

    if (uid == null) {
      return Stream<List<SupportRequestModel>>.value(
        const <SupportRequestModel>[],
      );
    }

    return _requestsCollection
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final List<SupportRequestModel> requests = snapshot.docs.map((document) {
        return SupportRequestModel.fromMap(
          document.id,
          document.data(),
        );
      }).toList();

      requests.sort((a, b) {
        final int priorityCompare =
        b.priorityScore.compareTo(a.priorityScore);

        if (priorityCompare != 0) {
          return priorityCompare;
        }

        final DateTime aDate =
            a.createdAt?.toDate() ?? DateTime(1970);

        final DateTime bDate =
            b.createdAt?.toDate() ?? DateTime(1970);

        return bDate.compareTo(aDate);
      });

      return requests;
    });
  }

  static Stream<SupportRequestModel?> watchRequest(String requestId) {
    return _requestsCollection.doc(requestId).snapshots().map((document) {
      final Map<String, dynamic>? data = document.data();

      if (!document.exists || data == null) {
        return null;
      }

      return SupportRequestModel.fromMap(
        document.id,
        data,
      );
    });
  }

  static Future<SupportRequestModel?> getRequest(String requestId) async {
    final DocumentSnapshot<Map<String, dynamic>> document =
    await _requestsCollection.doc(requestId).get();

    final Map<String, dynamic>? data = document.data();

    if (!document.exists || data == null) {
      return null;
    }

    return SupportRequestModel.fromMap(
      document.id,
      data,
    );
  }

  static Future<String> createRequest({
    required SupportCategory category,
    required String subject,
    required String description,
    required SupportUrgency urgency,
    String? relatedUserId,
    String? relatedEventId,
    String? relatedMessageId,
    List<String> attachmentUrls = const <String>[],
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Destek talebi oluşturmak için oturum açılmalıdır.',
      );
    }
    final QuerySnapshot<Map<String, dynamic>> recentRequests =
    await _requestsCollection
        .where('userId', isEqualTo: user.uid)
        .where(
      'createdAt',
      isGreaterThan: Timestamp.fromDate(
        DateTime.now().subtract(const Duration(minutes: 2)),
      ),
    )
        .limit(3)
        .get();

    if (recentRequests.docs.isNotEmpty) {
      throw StateError(
        'Çok kısa süre içinde tekrar destek talebi oluşturdunuz. Lütfen birkaç dakika bekleyin.',
      );
    }

    final String cleanedSubject = subject.trim();
    final String cleanedDescription = description.trim();
    final String normalizedSubject = cleanedSubject.toLowerCase().trim();
    final String normalizedDescription = cleanedDescription.toLowerCase().trim();

    for (final document in recentRequests.docs) {
      final data = document.data();

      final oldSubject =
      (data['subject'] ?? '').toString().toLowerCase().trim();

      final oldDescription =
      (data['description'] ?? '').toString().toLowerCase().trim();

      if (oldSubject == normalizedSubject &&
          oldDescription == normalizedDescription) {
        throw StateError(
          'Aynı içerikte bir destek talebi zaten oluşturulmuş.',
        );
      }
    }

    if (cleanedSubject.isEmpty) {
      throw ArgumentError('Konu boş bırakılamaz.');
    }

    if (cleanedDescription.isEmpty) {
      throw ArgumentError('Açıklama boş bırakılamaz.');
    }

    if (category.requiresRelatedUser &&
        (relatedUserId == null || relatedUserId.trim().isEmpty)) {
      throw ArgumentError(
        'Kullanıcı şikâyeti için ilgili kullanıcı gereklidir.',
      );
    }

    if (category.requiresRelatedEvent &&
        (relatedEventId == null || relatedEventId.trim().isEmpty)) {
      throw ArgumentError(
        'Etkinlik şikâyeti için ilgili etkinlik gereklidir.',
      );
    }

    if (category.requiresRelatedMessage &&
        (relatedMessageId == null || relatedMessageId.trim().isEmpty)) {
      throw ArgumentError(
        'Mesaj şikâyeti için ilgili mesaj gereklidir.',
      );
    }

    final DocumentReference<Map<String, dynamic>> requestReference =
    _requestsCollection.doc();

    final Timestamp now = Timestamp.now();
    int priorityScore = 20;

    switch (category) {
      case SupportCategory.securityEmergency:
        priorityScore = 100;
        break;

      case SupportCategory.userReport:
        priorityScore = 80;
        break;

      case SupportCategory.eventReport:
        priorityScore = 70;
        break;

      case SupportCategory.messageReport:
        priorityScore = 70;
        break;

      case SupportCategory.paymentIssue:
        priorityScore = 60;
        break;

      case SupportCategory.inappropriateImage:
        priorityScore = 60;
        break;

      case SupportCategory.bugReport:
        priorityScore = 40;
        break;

      case SupportCategory.generalSupport:
        priorityScore = 20;
        break;

      case SupportCategory.accountAppeal:
        priorityScore = 20;
        break;

      case SupportCategory.suggestion:
        priorityScore = 10;
        break;
    }

    final String ticketId =
        'DST-${DateTime.now().year}-${requestReference.id.substring(0, 6).toUpperCase()}';

    final SupportRequestModel request = SupportRequestModel(
      id: requestReference.id,
      userId: user.uid,
      category: category,
      subject: cleanedSubject,
      description: cleanedDescription,
      relatedUserId: relatedUserId?.trim(),
      relatedEventId: relatedEventId?.trim(),
      relatedMessageId: relatedMessageId?.trim(),
      attachmentUrls: attachmentUrls,
      urgency: category.isCriticalCategory
          ? SupportUrgency.critical
          : urgency,
      status: SupportRequestStatus.newRequest,
      adminResponse: '',
      lastMessage: cleanedDescription,
      lastMessageSenderId: user.uid,
      adminNotes: '',
      createdAt: now,
      updatedAt: now,
      ticketId: ticketId,
      replyCount: 0,
      isReadByUser: true,
      isReadByAdmin: false,
      isDeleted: false,
      tags: const <String>[],
      assignedAdminId: null,
      firstResponseAt: null,
      lastReplyAt: now,
      priorityScore: priorityScore,
    );

    final WriteBatch batch = _firestore.batch();

    batch.set(
      requestReference,
      request.toMap(),
    );

    final DocumentReference<Map<String, dynamic>> historyReference =
    requestReference.collection('history').doc();

    batch.set(historyReference, <String, dynamic>{
      'action': 'created',
      'oldStatus': null,
      'newStatus': SupportRequestStatus.newRequest.value,
      'performedByUid': user.uid,
      'performedByRole': 'user',
      'note': '',
      'ticketId': ticketId,
      'visibleToUser': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final DocumentReference<Map<String, dynamic>> firstMessageReference =
    requestReference.collection('messages').doc();

    batch.set(firstMessageReference, <String, dynamic>{
      'senderId': user.uid,
      'senderRole': 'user',
      'message': cleanedDescription,
      'attachments': attachmentUrls,
      'status': 'sent',
      'edited': false,
      'editedAt': null,
      'deleted': false,
      'deletedAt': null,
      'readBy': <String>[user.uid],
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    return ticketId;
  }

  static Future<void> sendMessage({
    required String requestId,
    required String message,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError('Oturum bulunamadı.');
    }

    final String text = message.trim();

    if (text.isEmpty) {
      return;
    }

    final DocumentReference<Map<String, dynamic>> requestReference =
    _requestsCollection.doc(requestId);

    final DocumentSnapshot<Map<String, dynamic>> requestDocument =
    await requestReference.get();

    if (!requestDocument.exists) {
      throw StateError('Destek talebi bulunamadı.');
    }

    final Map<String, dynamic>? requestData = requestDocument.data();

    if (requestData == null) {
      throw StateError('Destek talebi bulunamadı.');
    }

    if (requestData['status'] == SupportRequestStatus.closed.value) {
      throw StateError(
        'Kapatılmış destek taleplerine yeni mesaj gönderilemez.',
      );
    }

    final DocumentReference<Map<String, dynamic>> messageReference =
    requestReference.collection('messages').doc();

    final DocumentReference<Map<String, dynamic>> historyReference =
    requestReference.collection('history').doc();

    final WriteBatch batch = _firestore.batch();

    batch.set(messageReference, <String, dynamic>{
      'senderId': user.uid,
      'senderRole': 'user',
      'message': text,
      'attachments': const <String>[],
      'status': 'sent',
      'edited': false,
      'editedAt': null,
      'deleted': false,
      'deletedAt': null,
      'readBy': <String>[user.uid],
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.update(requestReference, <String, dynamic>{
      'lastMessage': text,
      'lastMessageSenderId': user.uid,
      'lastReplyAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'replyCount': FieldValue.increment(1),
      'isReadByAdmin': false,
      'isReadByUser': true,

      // Kullanıcı mesaj attığı anda talep tekrar incelemeye alınır.
      'status': SupportRequestStatus.reviewing.value,
    });

    batch.set(historyReference, <String, dynamic>{
      'action': 'message_sent',
      'performedByUid': user.uid,
      'performedByRole': 'user',
      'note': '',
      'visibleToUser': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  static Future<void> deleteOwnMessage({
    required String requestId,
    required String messageId,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError('Oturum bulunamadı.');
    }

    final DocumentReference<Map<String, dynamic>> messageReference =
    _requestsCollection
        .doc(requestId)
        .collection('messages')
        .doc(messageId);

    final DocumentSnapshot<Map<String, dynamic>> messageDocument =
    await messageReference.get();

    final Map<String, dynamic>? messageData = messageDocument.data();

    if (!messageDocument.exists || messageData == null) {
      throw StateError('Mesaj bulunamadı.');
    }

    if (messageData['senderId']?.toString() != user.uid) {
      throw StateError('Bu mesajı silme yetkiniz yok.');
    }

    await messageReference.update(<String, dynamic>{
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> markMessagesAsRead(String requestId) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return;
    }

    final DocumentReference<Map<String, dynamic>> requestReference =
    _requestsCollection.doc(requestId);

    await requestReference.update(<String, dynamic>{
      'isReadByUser': true,
    });
    await requestReference.update(<String, dynamic>{
      'lastViewedByUserAt': FieldValue.serverTimestamp(),
    });

    final QuerySnapshot<Map<String, dynamic>> unreadMessages =
    await requestReference
        .collection('messages')
        .where('senderId', isNotEqualTo: user.uid)
        .get();

    if (unreadMessages.docs.isEmpty) {
      return;
    }

    final WriteBatch batch = _firestore.batch();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
    in unreadMessages.docs) {
      batch.update(document.reference, <String, dynamic>{
        'readBy': FieldValue.arrayUnion(<String>[user.uid]),
      });
    }

    await batch.commit();
  }
  static Future<void> reopenOwnRequest(String requestId) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError('Bu işlem için oturum açılmalıdır.');
    }

    final DocumentReference<Map<String, dynamic>> requestReference =
    _requestsCollection.doc(requestId);

    await _firestore.runTransaction((transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> document =
      await transaction.get(requestReference);

      final Map<String, dynamic>? data = document.data();

      if (!document.exists || data == null) {
        throw StateError('Destek talebi bulunamadı.');
      }

      if (data['userId']?.toString() != user.uid) {
        throw StateError(
          'Bu destek talebi üzerinde işlem yetkiniz yok.',
        );
      }

      transaction.update(requestReference, <String, dynamic>{
        'status': SupportRequestStatus.reviewing.value,
        'updatedAt': FieldValue.serverTimestamp(),
        'isReadByAdmin': false,
      });

      final DocumentReference<Map<String, dynamic>> historyReference =
      requestReference.collection('history').doc();

      transaction.set(historyReference, <String, dynamic>{
        'action': 'reopened_by_user',
        'performedByUid': user.uid,
        'performedByRole': 'user',
        'visibleToUser': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
  static Future<void> closeOwnRequest(String requestId) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError('Bu işlem için oturum açılmalıdır.');
    }

    final DocumentReference<Map<String, dynamic>> requestReference =
    _requestsCollection.doc(requestId);

    await _firestore.runTransaction((transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> document =
      await transaction.get(requestReference);

      final Map<String, dynamic>? data = document.data();

      if (!document.exists || data == null) {
        throw StateError('Destek talebi bulunamadı.');
      }

      if (data['userId']?.toString() != user.uid) {
        throw StateError(
          'Bu destek talebi üzerinde işlem yetkiniz yok.',
        );
      }

      final String oldStatus =
          data['status']?.toString() ?? SupportRequestStatus.newRequest.value;

      if (oldStatus == SupportRequestStatus.closed.value) {
        return;
      }

      transaction.update(requestReference, <String, dynamic>{
        'status': SupportRequestStatus.closed.value,
        'closedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isReadByUser': true,
        'isReadByAdmin': true,
      });

      final DocumentReference<Map<String, dynamic>> historyReference =
      requestReference.collection('history').doc();

      transaction.set(historyReference, <String, dynamic>{
        'action': 'closed_by_user',
        'oldStatus': oldStatus,
        'newStatus': SupportRequestStatus.closed.value,
        'performedByUid': user.uid,
        'performedByRole': 'user',
        'note': '',
        'visibleToUser': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(
      String requestId,
      ) {
    return _requestsCollection
        .doc(requestId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchRequestHistory(
      String requestId,
      ) {
    return _requestsCollection
        .doc(requestId)
        .collection('history')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}