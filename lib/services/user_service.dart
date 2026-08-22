import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import 'session_service.dart';
import 'package:cloud_functions/cloud_functions.dart';

enum AuthDestinationType {
  login,
  createProfile,
  home,
  suspended,
  banned,
  deletionRequested,
  deleted,
  sessionExpired,
}

class AuthDestination {
  const AuthDestination({
    required this.type,
    this.profileName = '',
  });

  final AuthDestinationType type;
  final String profileName;
}

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createUser(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('public_profiles').doc(uid).get();

    if (!doc.exists) {
      return null;
    }

    final data = doc.data();

    if (data == null) {
      return null;
    }

    return UserModel.fromMap(data);
  }

  Future<List<UserModel>> getPlayers() async {
    final snapshot = await _firestore.collection('public_profiles').get();

    return snapshot.docs.map((doc) {
      return UserModel.fromMap(doc.data());
    }).toList();
  }

  static Future<AuthDestination> getAuthDestination({User? user}) async {
    final currentUser = user ?? FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const AuthDestination(type: AuthDestinationType.login);
    }

    await currentUser.getIdToken(true);

    await Future.delayed(const Duration(milliseconds: 500));

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (!doc.exists || doc.data() == null) {
      return const AuthDestination(
        type: AuthDestinationType.createProfile,
      );
    }

    final data = doc.data()!;
    final profileName = data['profilAdi']?.toString().trim() ?? '';
    final rawStatus = data['accountStatus']?.toString().trim() ?? '';
    final status = rawStatus.isEmpty ? 'active' : rawStatus;
    if (status == 'suspended') {
      final Timestamp? suspensionEndsAt =
      data['suspensionEndsAt'] as Timestamp?;

      if (suspensionEndsAt != null &&
          DateTime.now().isAfter(
            suspensionEndsAt.toDate(),
          )) {
        final HttpsCallable callable =
        FirebaseFunctions.instanceFor(
          region: 'europe-west1',
        ).httpsCallable('refreshAccountStatus');

        await callable.call();

        return AuthDestination(
          type: AuthDestinationType.home,
          profileName: profileName.isNotEmpty
              ? profileName
              : 'Oyuncu',
        );
      }
    }

    if (status == 'active') {
      final String remoteSessionId =
          data['activeSessionId']?.toString().trim() ?? '';
      final String localSessionId =
      await SessionService.getCurrentSessionId();

      if (remoteSessionId.isNotEmpty &&
          localSessionId.isNotEmpty &&
          remoteSessionId != localSessionId) {
        return const AuthDestination(
          type: AuthDestinationType.sessionExpired,
        );
      }
    }

    switch (status) {
      case 'pendingProfile':
        return const AuthDestination(
          type: AuthDestinationType.createProfile,
        );
      case 'suspended':
        return const AuthDestination(
          type: AuthDestinationType.suspended,
        );
      case 'blocked':
      case 'banned':
        return const AuthDestination(
          type: AuthDestinationType.banned,
        );
      case 'deletionRequested':
        return const AuthDestination(
          type: AuthDestinationType.deletionRequested,
        );
      case 'disabled':
        return const AuthDestination(
          type: AuthDestinationType.suspended,
        );
      case 'deleted':
        return const AuthDestination(
          type: AuthDestinationType.deleted,
        );
      case 'active':
      default:
        return AuthDestination(
          type: AuthDestinationType.home,
          profileName: profileName.isNotEmpty ? profileName : 'Oyuncu',
        );
    }
  }


  static Future<void> registerSuccessfulLogin(User user) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final SessionInfo session = await SessionService.createNewSession();
    final DocumentReference<Map<String, dynamic>> userReference =
    firestore.collection('users').doc(user.uid);
    final DocumentSnapshot<Map<String, dynamic>> userDocument =
    await userReference.get();

    if (userDocument.exists && userDocument.data() != null) {
      final Map<String, dynamic> data = userDocument.data()!;
      final String rawStatus =
          data['accountStatus']?.toString().trim() ?? '';
      final String status = rawStatus.isEmpty ? 'active' : rawStatus;

      final Map<String, dynamic> updateData = <String, dynamic>{
        'lastLoginAt': FieldValue.serverTimestamp(),
        'lastLoginPlatform': session.platform,
        'lastLoginAppVersion': session.appVersion,
        'lastDeviceId': session.deviceId,
        'guncellemeTarihi': FieldValue.serverTimestamp(),
      };

      if (status == 'active' || status == 'pendingProfile') {
        updateData['activeSessionId'] = session.sessionId;
      }

      await userReference.update(updateData);
    }

    try {
      await SessionService.saveSessionMetadata(session);
    } catch (_) {}

    try {
      final HttpsCallable callable =
      FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('recordLoginHistory');

      await callable.call(<String, dynamic>{
        'sessionId': session.sessionId,
        'deviceId': session.deviceId,
        'platform': session.platform,
        'appVersion': session.appVersion,
      });
    } catch (_) {}
  }

  static Future<bool> hasProfile() async {
    final destination = await getAuthDestination();
    return destination.type == AuthDestinationType.home;
  }

  static Future<String> getProfileName() async {
    final destination = await getAuthDestination();
    return destination.profileName;
  }

  static Future<Map<String, dynamic>> getProfileData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return {};
    }

    DocumentSnapshot<Map<String, dynamic>> doc;

    try {
      doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      debugPrint('AUTH DESTINATION -> Firestore read successful');
    } on FirebaseException catch (e, s) {
      debugPrint('AUTH DESTINATION FIRESTORE ERROR');
      debugPrint('Code: ${e.code}');
      debugPrint('Message: ${e.message}');
      debugPrintStack(stackTrace: s);
      rethrow;
    }

    final data = doc.data();

    if (!doc.exists || data == null) {
      return {};
    }

    return {
      'uid': data['uid']?.toString() ?? '',
      'ad': data['ad']?.toString() ?? '',
      'soyad': data['soyad']?.toString() ?? '',
      'profilAdi': data['profilAdi']?.toString() ?? '',
      'telefon': data['telefon']?.toString() ?? '',
      'sehir': data['sehir']?.toString() ?? '',
      'aktifSehir': data['aktifSehir']?.toString() ??
          data['sehir']?.toString() ??
          '',
      'ilce': data['ilce']?.toString() ?? '',
      'profilFotografi': data['profilFotografi']?.toString() ?? '',
      'avatarUrl': data['avatarUrl']?.toString() ?? '',
      'hakkimda': data['hakkimda']?.toString() ?? '',
      'latitude': (data['latitude'] as num?)?.toDouble() ?? 0.0,
      'longitude': (data['longitude'] as num?)?.toDouble() ?? 0.0,
      'puan': (data['puan'] as num?)?.toDouble() ?? 0.0,
      'plus': data['plus'] == true || data['isPlus'] == true,
      'plusPlan': data['plusPlan']?.toString() ??
          data['subscriptionPlan']?.toString() ??
          '',
      'plusExpiresAt':
      data['plusExpiresAt'] ?? data['subscriptionExpiresAt'],
      'verified': data['verified'] == true,
      'verificationStatus': data['verificationStatus']?.toString() ?? '',
      'oyuncuRozeti': data['oyuncuRozeti'] == true,
      'accountStatus': data['accountStatus']?.toString() ?? 'active',
      'favoriEtkinlikler':
      List<String>.from(data['favoriEtkinlikler'] ?? const []),
      'oyunlar': List<String>.from(data['oyunlar'] ?? const []),
      'gameIds': List<String>.from(data['gameIds'] ?? const []),
      'gameSkills': Map<String, dynamic>.from(

        data['gameSkills'] ?? const <String, dynamic>{},
      ),
      'badges': List<String>.from(data['badges'] ?? const []),
      'completedEventCount':
      (data['completedEventCount'] as num?)?.toInt() ?? 0,
      'ratingCount': (data['ratingCount'] as num?)?.toInt() ?? 0,
      'olusturmaTarihi': data['olusturmaTarihi'],
    };
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return null;
    }

    DocumentSnapshot<Map<String, dynamic>> doc;

    try {
      doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      debugPrint('AUTH DESTINATION -> Firestore read successful');
    } on FirebaseException catch (e, s) {
      debugPrint('==============================');
      debugPrint('AUTH DESTINATION FIRESTORE ERROR');
      debugPrint('Code: ${e.code}');
      debugPrint('Message: ${e.message}');
      debugPrintStack(stackTrace: s);
      debugPrint('==============================');
      rethrow;
    }

    if (!doc.exists) {
      return null;
    }

    return doc.data();
  }

  static Stream<Map<String, dynamic>?> watchUser(String uid) {
    return FirebaseFirestore.instance
        .collection('public_profiles')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      return snapshot.data();
    });
  }

  static Future<bool> checkApplicationEligibility({
    required String eventId,
    required String userId,
  }) async {
    final eventDoc = await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .get();

    if (!eventDoc.exists) {
      return false;
    }

    final data = eventDoc.data() ?? {};

    final applicants = List<String>.from(
      data['applicantIds'] ?? data['basvuranOyuncuIds'] ?? const [],
    );

    final participants = List<String>.from(
      data['participantIds'] ?? data['katilanlar'] ?? const [],
    );

    if (participants.contains(userId)) {
      return false;
    }

    if (applicants.contains(userId)) {
      return false;
    }

    return true;
  }
}
