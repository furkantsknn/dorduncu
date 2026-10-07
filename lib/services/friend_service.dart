import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:async/async.dart';

enum FriendRequestStatus { none, sent, received, friends }

class FriendService {
  FriendService._();

  static final FriendService instance = FriendService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  String get _uid => _auth.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _requestCollection =>
      _firestore.collection('friend_requests');

  CollectionReference<Map<String, dynamic>> _friendCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('friends');
  }

  Future<void> sendRequest(String targetUserId) async {
    await _functions.httpsCallable('sendFriendRequest').call({
      'targetUserId': targetUserId,
    });
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> getRequest(
    String targetUserId,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> sentRequest =
        await _requestCollection
            .where('senderId', isEqualTo: _uid)
            .where('receiverId', isEqualTo: targetUserId)
            .limit(1)
            .get();

    if (sentRequest.docs.isNotEmpty) {
      return sentRequest.docs.first;
    }

    final QuerySnapshot<Map<String, dynamic>> receivedRequest =
        await _requestCollection
            .where('senderId', isEqualTo: targetUserId)
            .where('receiverId', isEqualTo: _uid)
            .limit(1)
            .get();

    if (receivedRequest.docs.isNotEmpty) {
      return receivedRequest.docs.first;
    }

    return null;
  }

  Future<FriendRequestStatus> getStatus(String targetUserId) async {
    final friend = await _friendCollection(_uid).doc(targetUserId).get();

    if (friend.exists) {
      return FriendRequestStatus.friends;
    }

    final request = await getRequest(targetUserId);

    if (request == null) {
      return FriendRequestStatus.none;
    }

    final data = request.data()!;

    if (data['status'] != 'pending') {
      return FriendRequestStatus.none;
    }

    if (data['senderId'] == _uid) {
      return FriendRequestStatus.sent;
    }

    return FriendRequestStatus.received;
  }

  Future<void> acceptRequest(String targetUserId) async {
    final request = await getRequest(targetUserId);

    if (request == null) {
      return;
    }

    await _functions.httpsCallable('acceptFriendRequest').call({
      'requestId': request.id,
    });
  }

  Future<void> rejectRequest(String targetUserId) async {
    final request = await getRequest(targetUserId);

    if (request == null) {
      return;
    }

    await _functions.httpsCallable('rejectFriendRequest').call({
      'requestId': request.id,
    });
  }

  Future<void> cancelRequest(String targetUserId) async {
    final request = await getRequest(targetUserId);

    if (request == null) {
      return;
    }

    await _functions.httpsCallable('cancelFriendRequest').call({
      'requestId': request.id,
    });
  }

  Future<void> removeFriend(String targetUserId) async {
    await _functions.httpsCallable('removeFriend').call({
      'targetUserId': targetUserId,
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> incomingRequests() {
    return _requestCollection
        .where('receiverId', isEqualTo: _uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> outgoingRequests() {
    return _requestCollection
        .where('senderId', isEqualTo: _uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> friends() {
    return _friendCollection(
      _uid,
    ).orderBy('createdAt', descending: true).snapshots();
  }

  Stream<int> pendingRequestCount() {
    return _requestCollection
        .where('receiverId', isEqualTo: _uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<bool> areFriends(String targetUserId) async {
    final doc = await _friendCollection(_uid).doc(targetUserId).get();

    return doc.exists;
  }

  Future<int> friendCount() async {
    final snapshot = await _friendCollection(_uid).get();

    return snapshot.docs.length;
  }

  Stream<bool> isFriendStream(String targetUserId) {
    return _friendCollection(
      _uid,
    ).doc(targetUserId).snapshots().map((doc) => doc.exists);
  }

  Stream<FriendRequestStatus> statusStream(String targetUserId) async* {
    yield await getStatus(targetUserId);

    final Stream<DocumentSnapshot<Map<String, dynamic>>> friendStream =
        _friendCollection(_uid).doc(targetUserId).snapshots();

    final Stream<QuerySnapshot<Map<String, dynamic>>> sentRequestStream =
        _requestCollection
            .where('senderId', isEqualTo: _uid)
            .where('receiverId', isEqualTo: targetUserId)
            .snapshots();

    final Stream<QuerySnapshot<Map<String, dynamic>>> receivedRequestStream =
        _requestCollection
            .where('senderId', isEqualTo: targetUserId)
            .where('receiverId', isEqualTo: _uid)
            .snapshots();

    await for (final _ in StreamGroup.merge([
      friendStream,
      sentRequestStream,
      receivedRequestStream,
    ])) {
      yield await getStatus(targetUserId);
    }
  }

  Future<void> deleteAllRequestsBetween(String targetUserId) async {
    final snapshot = await _requestCollection
        .where('users', arrayContains: _uid)
        .get();

    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final sender = data['senderId'];

      final receiver = data['receiverId'];

      if ((sender == _uid && receiver == targetUserId) ||
          (sender == targetUserId && receiver == _uid)) {
        batch.delete(doc.reference);
      }
    }

    await batch.commit();
  }

  Stream<List<String>> friendIdsStream() {
    return _friendCollection(_uid).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.id).toList();
    });
  }

  Future<List<String>> friendIds() async {
    final snapshot = await _friendCollection(_uid).get();

    return snapshot.docs.map((doc) => doc.id).toList();
  }

  Future<bool> hasPendingRequest(String targetUserId) async {
    final status = await getStatus(targetUserId);

    return status == FriendRequestStatus.sent ||
        status == FriendRequestStatus.received;
  }

  Future<bool> canSendRequest(String targetUserId) async {
    if (targetUserId == _uid) {
      return false;
    }

    if (await areFriends(targetUserId)) {
      return false;
    }

    if (await hasPendingRequest(targetUserId)) {
      return false;
    }

    return true;
  }

  Future<bool> isBlocked(String targetUserId) async {
    final String normalizedTarget = targetUserId.trim();

    if (normalizedTarget.isEmpty || normalizedTarget == _uid) {
      return false;
    }

    final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('blockedUsers')
        .doc(normalizedTarget)
        .get();

    return document.exists;
  }

  Future<void> blockUser(String targetUserId) async {
    final String normalizedTarget = targetUserId.trim();

    if (normalizedTarget.isEmpty || normalizedTarget == _uid) {
      throw StateError('Geçersiz kullanıcı.');
    }

    if (await isBlocked(normalizedTarget)) {
      return;
    }

    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('blockedUsers')
        .doc(normalizedTarget)
        .set(<String, dynamic>{
          'uid': normalizedTarget,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> unblockUser(String targetUserId) async {
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('blockedUsers')
        .doc(targetUserId)
        .delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> blockedUsers() {
    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('blockedUsers')
        .snapshots();
  }
}
