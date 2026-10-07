import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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

    return _requestsCollection.where('userId', isEqualTo: uid).snapshots().map((
      snapshot,
    ) {
      final List<SupportRequestModel> requests = snapshot.docs.map((document) {
        return SupportRequestModel.fromMap(document.id, document.data());
      }).toList();

      requests.sort((a, b) {
        final int priorityCompare = b.priorityScore.compareTo(a.priorityScore);

        if (priorityCompare != 0) {
          return priorityCompare;
        }

        final DateTime aDate = a.createdAt?.toDate() ?? DateTime(1970);

        final DateTime bDate = b.createdAt?.toDate() ?? DateTime(1970);

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

      return SupportRequestModel.fromMap(document.id, data);
    });
  }

  static Future<SupportRequestModel?> getRequest(String requestId) async {
    final DocumentSnapshot<Map<String, dynamic>> document =
        await _requestsCollection.doc(requestId).get();

    final Map<String, dynamic>? data = document.data();

    if (!document.exists || data == null) {
      return null;
    }

    return SupportRequestModel.fromMap(document.id, data);
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
      throw StateError('Destek talebi oluşturmak için oturum açılmalıdır.');
    }

    final HttpsCallable callable = FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    ).httpsCallable('createSupportRequest');

    try {
      final HttpsCallableResult<dynamic> result = await callable
          .call(<String, dynamic>{
            'category': category.value,
            'subject': subject.trim(),
            'description': description.trim(),
            'urgency': urgency.value,
            'relatedUserId': relatedUserId?.trim(),
            'relatedEventId': relatedEventId?.trim(),
            'relatedMessageId': relatedMessageId?.trim(),
            'attachmentUrls': attachmentUrls,
          });

      final Map<String, dynamic> data = Map<String, dynamic>.from(
        result.data as Map<dynamic, dynamic>,
      );

      final String ticketId = data['ticketId']?.toString().trim() ?? '';

      if (ticketId.isEmpty) {
        throw StateError('Destek talebi oluşturulamadı.');
      }

      return ticketId;
    } on FirebaseFunctionsException catch (error) {
      final String message = error.message?.trim() ?? '';

      if (message.isNotEmpty) {
        throw StateError(message);
      }

      throw StateError('Destek talebi oluşturulamadı.');
    }
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

    final HttpsCallable callable = FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    ).httpsCallable('replySupportRequest');

    try {
      await callable.call(<String, dynamic>{
        'requestId': requestId.trim(),
        'message': text,
      });
    } on FirebaseFunctionsException catch (error) {
      final String messageText = error.message?.trim() ?? '';
      throw StateError(
        messageText.isEmpty ? 'Mesaj gönderilemedi.' : messageText,
      );
    }
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

    await requestReference.update(<String, dynamic>{'isReadByUser': true});
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
    await _updateOwnStatus(requestId: requestId, action: 'reopen');
  }

  static Future<void> closeOwnRequest(String requestId) async {
    await _updateOwnStatus(requestId: requestId, action: 'close');
  }

  static Future<void> _updateOwnStatus({
    required String requestId,
    required String action,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError('Bu işlem için oturum açılmalıdır.');
    }

    final HttpsCallable callable = FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    ).httpsCallable('updateOwnSupportRequestStatus');

    try {
      await callable.call(<String, dynamic>{
        'requestId': requestId.trim(),
        'action': action,
      });
    } on FirebaseFunctionsException catch (error) {
      final String messageText = error.message?.trim() ?? '';

      throw StateError(
        messageText.isEmpty ? 'Destek talebi güncellenemedi.' : messageText,
      );
    }
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
