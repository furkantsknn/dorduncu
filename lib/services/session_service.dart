import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionInfo {
  const SessionInfo({
    required this.sessionId,
    required this.deviceId,
    required this.platform,
    required this.appVersion,
  });

  final String sessionId;
  final String deviceId;
  final String platform;
  final String appVersion;
}

class SessionMetadata {
  const SessionMetadata({
    required this.session,
    required this.createdAt,
    required this.lastSeenAt,
  });

  final SessionInfo session;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;
}

@immutable
class AuthSessionBinding {
  const AuthSessionBinding({
    required this.userId,
    required this.sessionId,
    required this.authGeneration,
  });

  final String userId;
  final String sessionId;
  final int authGeneration;

  String get key => '$userId:$sessionId:$authGeneration';
}

@visibleForTesting
class AuthSessionTracker {
  String? _observedUserId;
  var _generation = 0;

  int get generation => _generation;

  void observeUserId(String? userId) {
    if (userId == _observedUserId) return;
    _observedUserId = userId;
    _generation++;
  }

  AuthSessionBinding capture({
    required String userId,
    required String sessionId,
  }) {
    observeUserId(userId);
    return AuthSessionBinding(
      userId: userId,
      sessionId: sessionId,
      authGeneration: _generation,
    );
  }

  bool matches(
    AuthSessionBinding binding, {
    required String? currentUserId,
    required String currentSessionId,
  }) {
    observeUserId(currentUserId);
    return currentUserId == binding.userId &&
        currentSessionId == binding.sessionId &&
        _generation == binding.authGeneration;
  }
}

class SessionService {
  SessionService();

  static const String _sessionIdKey = 'active_session_id';
  static const String _deviceIdKey = 'device_id';
  static const String _appVersionKey = 'app_version';

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );
  static final AuthSessionTracker _authSessionTracker = AuthSessionTracker();
  static StreamSubscription<String?>? _authBindingSubscription;
  static String? Function() _currentAuthUserId = () => _auth.currentUser?.uid;
  static Stream<String?> Function() _authUserIdChanges = () =>
      _auth.authStateChanges().map((User? user) => user?.uid);
  static Future<String> Function() _authSessionIdReader = getCurrentSessionId;

  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _sessionSubscription;

  static void _ensureAuthBindingTracking() {
    if (_authBindingSubscription != null) return;
    _authSessionTracker.observeUserId(_currentAuthUserId());
    _authBindingSubscription = _authUserIdChanges().listen(
      _authSessionTracker.observeUserId,
    );
  }

  @visibleForTesting
  static Future<void> configureAuthSessionTesting({
    required String? Function() currentUserId,
    required Stream<String?> Function() authStateChanges,
    required Future<String> Function() readSessionId,
  }) async {
    await _authBindingSubscription?.cancel();
    _authBindingSubscription = null;
    _currentAuthUserId = currentUserId;
    _authUserIdChanges = authStateChanges;
    _authSessionIdReader = readSessionId;
    _authSessionTracker.observeUserId(null);
  }

  @visibleForTesting
  static Future<void> resetAuthSessionTesting() async {
    await _authBindingSubscription?.cancel();
    _authBindingSubscription = null;
    _currentAuthUserId = () => _auth.currentUser?.uid;
    _authUserIdChanges = () =>
        _auth.authStateChanges().map((User? user) => user?.uid);
    _authSessionIdReader = getCurrentSessionId;
    _authSessionTracker.observeUserId(null);
  }

  static Future<AuthSessionBinding?> captureAuthSession({User? user}) async {
    return captureAuthSessionForUserId((user ?? _auth.currentUser)?.uid);
  }

  @visibleForTesting
  static Future<AuthSessionBinding?> captureAuthSessionForUserId(
    String? requestedUserId,
  ) async {
    _ensureAuthBindingTracking();
    final String? initialUserId = _currentAuthUserId();
    final int initialGeneration = _authSessionTracker.generation;
    if (requestedUserId == null || initialUserId != requestedUserId) {
      return null;
    }
    final String sessionId = await _authSessionIdReader();
    if (sessionId.isEmpty ||
        _currentAuthUserId() != initialUserId ||
        _authSessionTracker.generation != initialGeneration) {
      return null;
    }
    return AuthSessionBinding(
      userId: initialUserId!,
      sessionId: sessionId,
      authGeneration: initialGeneration,
    );
  }

  static Future<bool> isAuthSessionCurrent(AuthSessionBinding binding) async {
    _ensureAuthBindingTracking();
    final int initialGeneration = _authSessionTracker.generation;
    final String sessionId = await _authSessionIdReader();
    final String? currentUserId = _currentAuthUserId();
    if (_authSessionTracker.generation != initialGeneration) return false;
    return _authSessionTracker.matches(
      binding,
      currentUserId: currentUserId,
      currentSessionId: sessionId,
    );
  }

  static String _generateId() {
    final Random random = Random.secure();
    final int timestamp = DateTime.now().microsecondsSinceEpoch;

    final String randomPart = List<String>.generate(
      32,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();

    return '$timestamp-$randomPart';
  }

  static Future<String> _getOrCreateDeviceId() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    final String savedDeviceId =
        preferences.getString(_deviceIdKey)?.trim() ?? '';

    if (savedDeviceId.isNotEmpty) {
      return savedDeviceId;
    }

    final String newDeviceId = _generateId();
    await preferences.setString(_deviceIdKey, newDeviceId);

    return newDeviceId;
  }

  static String _getPlatform() {
    if (kIsWeb) {
      return 'web';
    }

    if (Platform.isAndroid) {
      return 'android';
    }

    if (Platform.isIOS) {
      return 'ios';
    }

    if (Platform.isWindows) {
      return 'windows';
    }

    if (Platform.isMacOS) {
      return 'macos';
    }

    if (Platform.isLinux) {
      return 'linux';
    }

    return 'unknown';
  }

  static Future<String> _getAppVersion() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    final String appVersion =
        preferences.getString(_appVersionKey)?.trim() ?? '';

    return appVersion.isEmpty ? 'unknown' : appVersion;
  }

  static Future<void> updateAppVersion(String appVersion) async {
    final String normalizedVersion = appVersion.trim();

    if (normalizedVersion.isEmpty) {
      return;
    }

    final SharedPreferences preferences = await SharedPreferences.getInstance();

    await preferences.setString(_appVersionKey, normalizedVersion);

    final User? user = _auth.currentUser;
    final String sessionId = await getCurrentSessionId();

    if (user == null || sessionId.isEmpty) {
      return;
    }

    await _functions.httpsCallable('registerSession').call(<String, dynamic>{
      'action': 'updateAppVersion',
      'sessionId': sessionId,
      'appVersion': normalizedVersion,
    });
  }

  static Future<String> getCurrentSessionId() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    return preferences.getString(_sessionIdKey)?.trim() ?? '';
  }

  static Future<SessionInfo> createNewSession() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError('Kullanıcı oturumu bulunamadı.');
    }

    final SessionInfo session = SessionInfo(
      sessionId: _generateId(),
      deviceId: await _getOrCreateDeviceId(),
      platform: _getPlatform(),
      appVersion: await _getAppVersion(),
    );

    final SharedPreferences preferences = await SharedPreferences.getInstance();

    await preferences.setString(_sessionIdKey, session.sessionId);

    return session;
  }

  static Future<void> saveSessionMetadata(SessionInfo session) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return;
    }

    await _functions.httpsCallable('registerSession').call(<String, dynamic>{
      'action': 'register',
      'sessionId': session.sessionId,
      'deviceId': session.deviceId,
      'platform': session.platform,
      'appVersion': session.appVersion,
    });
  }

  static Future<SessionInfo> getOrCreateCurrentSession() async {
    final String currentSessionId = await getCurrentSessionId();

    if (currentSessionId.isEmpty) {
      return createNewSession();
    }

    return SessionInfo(
      sessionId: currentSessionId,
      deviceId: await _getOrCreateDeviceId(),
      platform: _getPlatform(),
      appVersion: await _getAppVersion(),
    );
  }

  static Future<SessionMetadata> getCurrentDeviceInfo() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError('Kullanıcı oturumu bulunamadı.');
    }

    final SessionInfo localSession = await getOrCreateCurrentSession();

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('sessions')
        .doc(user.uid)
        .get();

    final Map<String, dynamic>? data = snapshot.data();

    final String remoteSessionId = data?['sessionId']?.toString().trim() ?? '';
    final bool sameSession =
        remoteSessionId.isEmpty || remoteSessionId == localSession.sessionId;

    final SessionInfo session = sameSession
        ? SessionInfo(
            sessionId: localSession.sessionId,
            deviceId: data?['deviceId']?.toString().trim().isNotEmpty == true
                ? data!['deviceId'].toString().trim()
                : localSession.deviceId,
            platform: data?['platform']?.toString().trim().isNotEmpty == true
                ? data!['platform'].toString().trim()
                : localSession.platform,
            appVersion:
                data?['appVersion']?.toString().trim().isNotEmpty == true
                ? data!['appVersion'].toString().trim()
                : localSession.appVersion,
          )
        : localSession;

    return SessionMetadata(
      session: session,
      createdAt: sameSession
          ? (data?['createdAt'] as Timestamp?)?.toDate()
          : null,
      lastSeenAt: sameSession
          ? (data?['lastSeenAt'] as Timestamp?)?.toDate()
          : null,
    );
  }

  static Future<SessionInfo> signOutOtherDevices() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError('Kullanıcı oturumu bulunamadı.');
    }

    await stopListening();

    final SessionInfo newSession = await createNewSession();

    await _functions.httpsCallable('registerSession').call(<String, dynamic>{
      'action': 'register',
      'sessionId': newSession.sessionId,
      'deviceId': newSession.deviceId,
      'platform': newSession.platform,
      'appVersion': newSession.appVersion,
    });

    return newSession;
  }

  static Future<bool> isCurrentSessionValid() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    final String localSessionId = await getCurrentSessionId();

    if (localSessionId.isEmpty) {
      return false;
    }

    final DocumentSnapshot<Map<String, dynamic>> userDocument = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    final String remoteSessionId =
        userDocument.data()?['activeSessionId']?.toString().trim() ?? '';

    return remoteSessionId.isEmpty || remoteSessionId == localSessionId;
  }

  static Future<void> updateLastSeen() async {
    final User? user = _auth.currentUser;
    final String sessionId = await getCurrentSessionId();

    if (user == null || sessionId.isEmpty) {
      return;
    }

    try {
      await _functions.httpsCallable('registerSession').call(<String, dynamic>{
        'action': 'heartbeat',
        'sessionId': sessionId,
      });
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'failed-precondition') {
        return;
      }
      rethrow;
    }
  }

  static Future<void> startListening({
    required VoidCallback onSessionExpired,
  }) async {
    await stopListening();

    final User? user = _auth.currentUser;
    final String localSessionId = await getCurrentSessionId();

    if (user == null || localSessionId.isEmpty) {
      return;
    }

    bool callbackTriggered = false;

    _sessionSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((DocumentSnapshot<Map<String, dynamic>> snapshot) async {
          if (callbackTriggered || !snapshot.exists) {
            return;
          }

          final String remoteSessionId =
              snapshot.data()?['activeSessionId']?.toString().trim() ?? '';

          if (remoteSessionId.isEmpty || remoteSessionId == localSessionId) {
            return;
          }

          callbackTriggered = true;
          await stopListening();
          await clearLocalSession();
          onSessionExpired();
        });
  }

  static Future<void> stopListening() async {
    await _sessionSubscription?.cancel();
    _sessionSubscription = null;
  }

  static Future<void> clearLocalSession() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    await preferences.remove(_sessionIdKey);
  }

  static Future<void> clearSession() async {
    await stopListening();
    await clearLocalSession();
  }
}
