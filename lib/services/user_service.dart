import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../legal/legal_service.dart';
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
  legalAcceptanceRequired,
}

class AuthDestination {
  const AuthDestination({required this.type, this.profileName = ''});

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

  static Future<AuthDestination> getAuthDestination({
    User? user,
    bool allowStatusRefresh = true,
    bool skipTokenRefresh = false,
    bool skipPostAuthDelay = false,
  }) async {
    final currentUser = user ?? FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const AuthDestination(type: AuthDestinationType.login);
    }
    final AuthSessionBinding? authBinding =
        await SessionService.captureAuthSession(user: currentUser);
    if (authBinding == null) {
      return const AuthDestination(type: AuthDestinationType.sessionExpired);
    }

    AuthDestination sessionChanged() =>
        const AuthDestination(type: AuthDestinationType.login);

    if (!await SessionService.isAuthSessionCurrent(authBinding)) {
      return sessionChanged();
    }

    if (!skipTokenRefresh) {
      await currentUser.getIdToken(true);
      if (!await SessionService.isAuthSessionCurrent(authBinding)) {
        return sessionChanged();
      }
    }

    if (!skipPostAuthDelay) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!await SessionService.isAuthSessionCurrent(authBinding)) {
        return sessionChanged();
      }
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get(const GetOptions(source: Source.server));
    if (!await SessionService.isAuthSessionCurrent(authBinding)) {
      return sessionChanged();
    }

    return resolveLoadedAccountDestination(
      data: doc.exists ? doc.data() : null,
      reloadAccount: () async {
        final refreshed = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get(const GetOptions(source: Source.server));
        return refreshed.exists ? refreshed.data() : null;
      },
      refreshAccountStatus: () => FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('refreshAccountStatus').call(),
      hasCurrentAcceptances: () => LegalService.hasCurrentOnboardingAcceptances(
        userId: currentUser.uid,
        expectedBinding: authBinding,
      ),
      getLocalSessionId: SessionService.getCurrentSessionId,
      authStillCurrent: () => SessionService.isAuthSessionCurrent(authBinding),
      allowStatusRefresh: allowStatusRefresh,
    );
  }

  @visibleForTesting
  static Future<AuthDestination> resolveLoadedAccountDestination({
    required Map<String, dynamic>? data,
    required Future<Map<String, dynamic>?> Function() reloadAccount,
    required Future<void> Function() refreshAccountStatus,
    required Future<bool> Function() hasCurrentAcceptances,
    required Future<String> Function() getLocalSessionId,
    required Future<bool> Function() authStillCurrent,
    bool allowStatusRefresh = true,
    DateTime Function()? now,
  }) async {
    AuthDestination sessionChanged() =>
        const AuthDestination(type: AuthDestinationType.login);
    if (!await authStillCurrent()) return sessionChanged();
    if (data == null) {
      if (!await hasCurrentAcceptances()) {
        return const AuthDestination(
          type: AuthDestinationType.legalAcceptanceRequired,
        );
      }
      if (!await authStillCurrent()) return sessionChanged();
      await getLocalSessionId();
      if (!await authStillCurrent()) return sessionChanged();
      return const AuthDestination(type: AuthDestinationType.createProfile);
    }

    final profileName = data['profilAdi']?.toString().trim() ?? '';
    final rawStatus = data['accountStatus']?.toString().trim() ?? '';
    final status = rawStatus.isEmpty ? 'active' : rawStatus;
    if (status == 'suspended') {
      final Timestamp? suspensionEndsAt =
          data['suspensionEndsAt'] as Timestamp?;

      if (suspensionEndsAt != null &&
          (now ?? DateTime.now)().isAfter(suspensionEndsAt.toDate())) {
        if (!allowStatusRefresh) {
          return const AuthDestination(type: AuthDestinationType.suspended);
        }
        await refreshAccountStatus();
        if (!await authStillCurrent()) {
          return sessionChanged();
        }
        final Map<String, dynamic>? refreshedData = await reloadAccount();
        if (!await authStillCurrent()) return sessionChanged();
        return resolveLoadedAccountDestination(
          data: refreshedData,
          reloadAccount: reloadAccount,
          refreshAccountStatus: refreshAccountStatus,
          hasCurrentAcceptances: hasCurrentAcceptances,
          getLocalSessionId: getLocalSessionId,
          authStillCurrent: authStillCurrent,
          allowStatusRefresh: false,
          now: now,
        );
      }
    }

    if (status == 'active' || status == 'pendingProfile') {
      final String remoteSessionId =
          data['activeSessionId']?.toString().trim() ?? '';
      final String localSessionId = await getLocalSessionId();
      if (!await authStillCurrent()) {
        return sessionChanged();
      }

      if (remoteSessionId.isNotEmpty &&
          localSessionId.isNotEmpty &&
          remoteSessionId != localSessionId) {
        return const AuthDestination(type: AuthDestinationType.sessionExpired);
      }
    }

    if ((status == 'active' || status == 'pendingProfile') &&
        !await hasCurrentAcceptances()) {
      return const AuthDestination(
        type: AuthDestinationType.legalAcceptanceRequired,
      );
    }
    if (!await authStillCurrent()) {
      return sessionChanged();
    }

    switch (status) {
      case 'pendingProfile':
        return const AuthDestination(type: AuthDestinationType.createProfile);
      case 'suspended':
        return const AuthDestination(type: AuthDestinationType.suspended);
      case 'blocked':
      case 'banned':
        return const AuthDestination(type: AuthDestinationType.banned);
      case 'deletionRequested':
        return const AuthDestination(
          type: AuthDestinationType.deletionRequested,
        );
      case 'disabled':
        return const AuthDestination(type: AuthDestinationType.suspended);
      case 'deleted':
        return const AuthDestination(type: AuthDestinationType.deleted);
      case 'active':
        return AuthDestination(
          type: AuthDestinationType.home,
          profileName: profileName.isNotEmpty ? profileName : 'Oyuncu',
        );
      default:
        return const AuthDestination(type: AuthDestinationType.suspended);
    }
  }

  static Future<void> registerSuccessfulLogin(User user) async {
    final SessionInfo session = await SessionService.createNewSession();

    try {
      await SessionService.saveSessionMetadata(session);
    } catch (_) {}

    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
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
      'aktifSehir':
          data['aktifSehir']?.toString() ?? data['sehir']?.toString() ?? '',
      'ilce': data['ilce']?.toString() ?? '',
      'profilFotografi': data['profilFotografi']?.toString() ?? '',
      'avatarUrl': data['avatarUrl']?.toString() ?? '',
      'hakkimda': data['hakkimda']?.toString() ?? '',
      'latitude': (data['latitude'] as num?)?.toDouble() ?? 0.0,
      'longitude': (data['longitude'] as num?)?.toDouble() ?? 0.0,
      'puan': (data['puan'] as num?)?.toDouble() ?? 0.0,
      'plus': data['plus'] == true || data['isPlus'] == true,
      'plusAdminGranted': data['plusAdminGranted'] == true,
      'plusPlan':
          data['plusPlan']?.toString() ??
          data['subscriptionPlan']?.toString() ??
          '',
      'plusExpiresAt': data['plusExpiresAt'] ?? data['subscriptionExpiresAt'],
      'plusSubscriptionExpiresAt': data['plusSubscriptionExpiresAt'],
      'plusSubscriptionState': data['plusSubscriptionState'],
      'plusGiftExpiresAt': data['plusGiftExpiresAt'],
      'verified': data['verified'] == true,
      'verificationStatus': data['verificationStatus']?.toString() ?? '',
      'oyuncuRozeti': data['oyuncuRozeti'] == true,
      'accountStatus': data['accountStatus']?.toString() ?? 'active',
      'favoriEtkinlikler': List<String>.from(
        data['favoriEtkinlikler'] ?? const [],
      ),
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
