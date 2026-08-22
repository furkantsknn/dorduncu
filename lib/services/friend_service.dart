import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:async/async.dart';
import 'notification_service.dart';

enum FriendRequestStatus {
  none,
  sent,
  received,
  friends,
}

class FriendService {
FriendService._();

static final FriendService instance = FriendService._();

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

final FirebaseAuth _auth = FirebaseAuth.instance;

String get _uid => _auth.currentUser!.uid;

CollectionReference<Map<String, dynamic>> get _requestCollection =>
_firestore.collection('friend_requests');

CollectionReference<Map<String, dynamic>> _friendCollection(
String uid,
) {
return _firestore
.collection('users')
.doc(uid)
.collection('friends');
}

Future<void> sendRequest(
String targetUserId,
) async {
if (targetUserId == _uid) {
throw Exception(
'Kendine arkadaşlık isteği gönderemezsin.',
);
}

final QuerySnapshot<Map<String, dynamic>> existing =
await _requestCollection
.where('users', arrayContains: _uid)
.get();

for (final doc in existing.docs) {
final data = doc.data();

final sender = data['senderId'];

final receiver = data['receiverId'];

if ((sender == _uid &&
receiver == targetUserId) ||
(sender == targetUserId &&
receiver == _uid)) {
return;
}
}

await _requestCollection.add({
'senderId': _uid,
'receiverId': targetUserId,
'status': 'pending',
'users': [
_uid,
targetUserId,
],
'createdAt':
FieldValue.serverTimestamp(),
'updatedAt':
FieldValue.serverTimestamp(),
});
await NotificationService.create(
  userId: targetUserId,
  type: NotificationType.friendRequest.name,
  title: 'Arkadaşlık İsteği',
  body: 'Sana yeni bir arkadaşlık isteği gönderildi.',
  senderUid: _uid,
  route: 'publicProfile',
  data: <String, dynamic>{
    'userId': _uid,
  },
);
}

Future<DocumentSnapshot<Map<String, dynamic>>?>
getRequest(
String targetUserId,
) async {
final QuerySnapshot<Map<String, dynamic>>
result = await _requestCollection
.where(
'users',
arrayContains: _uid,
)
.get();

for (final doc in result.docs) {
final data = doc.data();

final sender =
data['senderId'];

final receiver =
data['receiverId'];

if ((sender == _uid &&
receiver == targetUserId) ||
(sender == targetUserId &&
receiver == _uid)) {
return doc;
}
}

return null;
}

Future<FriendRequestStatus>
getStatus(
String targetUserId,
) async {
final request =
await getRequest(targetUserId);

if (request == null) {
final friend =
await _friendCollection(_uid)
.doc(targetUserId)
.get();

if (friend.exists) {
return FriendRequestStatus
.friends;
}

return FriendRequestStatus.none;
}

final data = request.data()!;

if (data['status'] !=
'pending') {
return FriendRequestStatus.none;
}

if (data['senderId'] == _uid) {
return FriendRequestStatus.sent;
}

return FriendRequestStatus
.received;
}
Future<void> acceptRequest(
    String targetUserId,
    ) async {
  final request = await getRequest(targetUserId);

  if (request == null) {
    return;
  }

  await _firestore.runTransaction(
        (transaction) async {
      transaction.delete(request.reference);

      transaction.set(
        _friendCollection(_uid).doc(targetUserId),
        <String, dynamic>{
          'uid': targetUserId,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      transaction.set(
        _friendCollection(targetUserId).doc(_uid),
        <String, dynamic>{
          'uid': _uid,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    },
  );

  await NotificationService.create(
    userId: targetUserId,
    type: NotificationType.friendAccepted.name,
    title: 'Arkadaşlık İsteği Kabul Edildi',
    body: 'Arkadaşlık isteğin kabul edildi.',
    senderUid: _uid,
    route: 'publicProfile',
    data: <String, dynamic>{
      'userId': _uid,
    },
  );
}
Future<void> rejectRequest(
String targetUserId,
) async {
final request =
await getRequest(targetUserId);

if (request == null) {
return;
}

await request.reference.delete();
}

Future<void> cancelRequest(
String targetUserId,
) async {
final request =
await getRequest(targetUserId);

if (request == null) {
return;
}

await request.reference.delete();
}

Future<void> removeFriend(
String targetUserId,
) async {
await _firestore.runTransaction(
(transaction) async {
transaction.delete(
_friendCollection(_uid)
.doc(targetUserId),
);

transaction.delete(
_friendCollection(targetUserId)
.doc(_uid),
);
},
);
}

Stream<QuerySnapshot<Map<String, dynamic>>>
incomingRequests() {
return _requestCollection
.where(
'receiverId',
isEqualTo: _uid,
)
.where(
'status',
isEqualTo: 'pending',
)
.snapshots();
}

Stream<QuerySnapshot<Map<String, dynamic>>>
outgoingRequests() {
return _requestCollection
.where(
'senderId',
isEqualTo: _uid,
)
.where(
'status',
isEqualTo: 'pending',
)
.snapshots();
}

Stream<QuerySnapshot<Map<String, dynamic>>>
friends() {
return _friendCollection(_uid)
.orderBy(
'createdAt',
descending: true,
)
.snapshots();
}
Stream<int> pendingRequestCount() {
return _requestCollection
.where(
'receiverId',
isEqualTo: _uid,
)
.where(
'status',
isEqualTo: 'pending',
)
.snapshots()
.map(
(snapshot) => snapshot.docs.length,
);
}

Future<bool> areFriends(
String targetUserId,
) async {
final doc =
await _friendCollection(_uid)
.doc(targetUserId)
.get();

return doc.exists;
}

Future<int> friendCount() async {
final snapshot =
await _friendCollection(_uid)
.get();

return snapshot.docs.length;
}

Stream<bool> isFriendStream(
String targetUserId,
) {
return _friendCollection(_uid)
.doc(targetUserId)
.snapshots()
.map(
(doc) => doc.exists,
);
}

Stream<FriendRequestStatus> statusStream(
    String targetUserId,
    ) async* {
  yield await getStatus(targetUserId);

  final Stream<DocumentSnapshot<Map<String, dynamic>>> friendStream =
  _friendCollection(_uid).doc(targetUserId).snapshots();

  final Stream<QuerySnapshot<Map<String, dynamic>>> requestStream =
  _requestCollection
      .where(
    'users',
    arrayContains: _uid,
  )
      .snapshots();

  await for (final _ in StreamGroup.merge([
    friendStream,
    requestStream,
  ])) {
    yield await getStatus(targetUserId);
  }
}

Future<void> deleteAllRequestsBetween(
String targetUserId,
) async {
final snapshot =
await _requestCollection
.where(
'users',
arrayContains: _uid,
)
.get();

final batch =
_firestore.batch();

for (final doc in snapshot.docs) {
final data = doc.data();

final sender =
data['senderId'];

final receiver =
data['receiverId'];

if ((sender == _uid &&
receiver ==
targetUserId) ||
(sender ==
targetUserId &&
receiver == _uid)) {
batch.delete(
doc.reference,
);
}
}

await batch.commit();
}
Stream<List<String>> friendIdsStream() {
  return _friendCollection(_uid)
      .snapshots()
      .map(
        (snapshot) {
      return snapshot.docs
          .map(
            (doc) =>
        doc.id,
      )
          .toList();
    },
  );
}

Future<List<String>>
friendIds() async {
  final snapshot =
  await _friendCollection(
    _uid,
  ).get();

  return snapshot.docs
      .map(
        (doc) => doc.id,
  )
      .toList();
}

Future<bool>
hasPendingRequest(
    String targetUserId,
    ) async {
  final status =
  await getStatus(
    targetUserId,
  );

  return status ==
      FriendRequestStatus
          .sent ||
      status ==
          FriendRequestStatus
              .received;
}

Future<bool>
canSendRequest(
    String targetUserId,
    ) async {
  if (targetUserId ==
      _uid) {
    return false;
  }

  if (await areFriends(
    targetUserId,
  )) {
    return false;
  }

  if (await hasPendingRequest(
    targetUserId,
  )) {
    return false;
  }

  return true;
}

Future<void>
blockUser(
    String targetUserId,
    ) async {
  await _firestore
      .collection('users')
      .doc(_uid)
      .collection('blockedUsers')
      .doc(targetUserId)
      .set({
    'uid': targetUserId,
    'createdAt':
    FieldValue
        .serverTimestamp(),
  });
}

Future<void>
unblockUser(
    String targetUserId,
    ) async {
  await _firestore
      .collection('users')
      .doc(_uid)
      .collection('blockedUsers')
      .doc(targetUserId)
      .delete();
}

Stream<QuerySnapshot<
    Map<String, dynamic>>>
blockedUsers() {
  return _firestore
      .collection('users')
      .doc(_uid)
      .collection(
      'blockedUsers')
      .snapshots();
}
}