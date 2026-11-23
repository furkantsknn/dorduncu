import 'dart:async';

import 'package:dorduncu/screens/create_profile_screen.dart';
import 'package:dorduncu/services/session_service.dart';
import 'package:dorduncu/services/user_service.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUserPlatform extends Fake implements UserPlatform {
  _FakeUserPlatform(this._uid);

  final String _uid;

  @override
  String get uid => _uid;
}

class _FakeFirebaseAuthPlatform extends FirebaseAuthPlatform {
  UserPlatform? _currentUser;
  final StreamController<UserPlatform?> _changes =
      StreamController<UserPlatform?>.broadcast(sync: true);

  @override
  UserPlatform? get currentUser => _currentUser;

  @override
  Stream<UserPlatform?> authStateChanges() => _changes.stream;

  void replaceWrapper(String uid) {
    _currentUser = _FakeUserPlatform(uid);
  }

  void changeSession(String? uid) {
    _currentUser = uid == null ? null : _FakeUserPlatform(uid);
    _changes.add(_currentUser);
  }

  Future<void> close() => _changes.close();
}

void main() {
  late _FakeFirebaseAuthPlatform auth;
  late FirebaseAuthPlatform originalAuthPlatform;
  late String sessionId;
  Completer<String>? pendingSessionRead;

  setUp(() async {
    originalAuthPlatform = FirebaseAuthPlatform.instance;
    auth = _FakeFirebaseAuthPlatform();
    FirebaseAuthPlatform.instance = auth;
    sessionId = 'session-a';
    await SessionService.configureAuthSessionTesting(
      currentUserId: () => auth.currentUser?.uid,
      authStateChanges: () =>
          auth.authStateChanges().map((UserPlatform? user) => user?.uid),
      readSessionId: () =>
          pendingSessionRead?.future ?? Future.value(sessionId),
    );
  });

  tearDown(() async {
    await SessionService.resetAuthSessionTesting();
    FirebaseAuthPlatform.instance = originalAuthPlatform;
    await auth.close();
  });

  test(
    'same auth session accepts different User wrappers and reloads',
    () async {
      auth.changeSession('user-a');
      final AuthSessionBinding? binding =
          await SessionService.captureAuthSessionForUserId('user-a');
      expect(binding, isNotNull);

      auth.replaceWrapper('user-a');
      expect(await SessionService.isAuthSessionCurrent(binding!), isTrue);

      // A token refresh/reload can replace the wrapper without an auth-state
      // transition. UID, app session id and auth generation remain stable.
      auth.replaceWrapper('user-a');
      expect(await SessionService.isAuthSessionCurrent(binding), isTrue);
    },
  );

  test('account change while session read waits rejects old capture', () async {
    auth.changeSession('user-a');
    pendingSessionRead = Completer<String>();
    final Future<AuthSessionBinding?> capture =
        SessionService.captureAuthSessionForUserId('user-a');

    auth.changeSession('user-b');
    sessionId = 'session-b';
    pendingSessionRead!.complete(sessionId);

    expect(await capture, isNull);
  });

  test('same uid sign-out and new sign-in rejects an old operation', () async {
    auth.changeSession('user-a');
    final AuthSessionBinding binding =
        (await SessionService.captureAuthSessionForUserId('user-a'))!;
    pendingSessionRead = Completer<String>();
    final Future<bool> validation = SessionService.isAuthSessionCurrent(
      binding,
    );

    auth.changeSession(null);
    auth.changeSession('user-a');
    sessionId = 'session-b';
    pendingSessionRead!.complete(sessionId);

    expect(await validation, isFalse);
  });

  test('profile completion stops after write when account changes', () async {
    auth.changeSession('user-a');
    final AuthSessionBinding binding =
        (await SessionService.captureAuthSessionForUserId('user-a'))!;
    final Completer<void> write = Completer<void>();
    var metadataCalls = 0;
    var verificationCalls = 0;
    var resolveCalls = 0;

    final Future<AuthDestination?> result = ProfileCreationCoordinator.complete(
      binding: binding,
      isSessionCurrent: SessionService.isAuthSessionCurrent,
      writeProfile: () => write.future,
      saveSessionMetadata: () async {
        metadataCalls++;
      },
      submitVerification: () async {
        verificationCalls++;
      },
      resolveDestination: () async {
        resolveCalls++;
        return const AuthDestination(type: AuthDestinationType.home);
      },
    );

    auth.changeSession('user-b');
    sessionId = 'session-b';
    write.complete();

    expect(await result, isNull);
    expect(metadataCalls, 0);
    expect(verificationCalls, 0);
    expect(resolveCalls, 0);
  });

  test(
    'normal profile completion returns the gated home destination',
    () async {
      auth.changeSession('user-a');
      final AuthSessionBinding binding =
          (await SessionService.captureAuthSessionForUserId('user-a'))!;

      final AuthDestination? result = await ProfileCreationCoordinator.complete(
        binding: binding,
        isSessionCurrent: SessionService.isAuthSessionCurrent,
        writeProfile: () async {},
        saveSessionMetadata: () async {},
        submitVerification: null,
        resolveDestination: () async =>
            const AuthDestination(type: AuthDestinationType.home),
      );

      expect(result?.type, AuthDestinationType.home);
    },
  );

  test(
    'profile onboarding orders pending, upload, finalize, and verification',
    () async {
      auth.changeSession('user-a');
      final AuthSessionBinding binding =
          (await SessionService.captureAuthSessionForUserId('user-a'))!;
      final List<String> calls = <String>[];

      final AuthDestination? result = await ProfileCreationCoordinator.complete(
        binding: binding,
        isSessionCurrent: SessionService.isAuthSessionCurrent,
        writeProfile: () async => calls.add('pending'),
        uploadAssets: () async => calls.add('upload'),
        finalizeProfile: () async => calls.add('active'),
        saveSessionMetadata: () async => calls.add('session'),
        submitVerification: () async => calls.add('verification'),
        resolveDestination: () async {
          calls.add('destination');
          return const AuthDestination(type: AuthDestinationType.home);
        },
      );

      expect(result?.type, AuthDestinationType.home);
      expect(calls, <String>[
        'pending',
        'upload',
        'active',
        'session',
        'verification',
        'destination',
      ]);
    },
  );

  test('session change after onboarding upload prevents activation', () async {
    auth.changeSession('user-a');
    final AuthSessionBinding binding =
        (await SessionService.captureAuthSessionForUserId('user-a'))!;
    var finalized = false;

    final AuthDestination? result = await ProfileCreationCoordinator.complete(
      binding: binding,
      isSessionCurrent: SessionService.isAuthSessionCurrent,
      writeProfile: () async {},
      uploadAssets: () async => auth.changeSession('user-b'),
      finalizeProfile: () async => finalized = true,
      saveSessionMetadata: () async {},
      submitVerification: null,
      resolveDestination: () async =>
          const AuthDestination(type: AuthDestinationType.home),
    );

    expect(result, isNull);
    expect(finalized, isFalse);
  });

  test(
    'active retry skips profile writes and completes only follow-up steps',
    () async {
      auth.changeSession('user-a');
      final AuthSessionBinding binding =
          (await SessionService.captureAuthSessionForUserId('user-a'))!;
      final List<String> calls = <String>[];
      final AuthDestination? result = await ProfileCreationCoordinator.complete(
        binding: binding,
        isSessionCurrent: SessionService.isAuthSessionCurrent,
        readProfileState: () async => ProfileCreationServerState.active,
        writeProfile: () async => calls.add('write'),
        uploadAssets: () async => calls.add('upload'),
        finalizeProfile: () async => calls.add('finalize'),
        saveSessionMetadata: () async => calls.add('session'),
        submitVerification: () async => calls.add('verification'),
        resolveDestination: () async =>
            const AuthDestination(type: AuthDestinationType.home),
      );
      expect(result?.type, AuthDestinationType.home);
      expect(calls, <String>['session', 'verification']);
    },
  );

  test(
    'session failure after finalization retries without reverting active',
    () async {
      auth.changeSession('user-a');
      final AuthSessionBinding binding =
          (await SessionService.captureAuthSessionForUserId('user-a'))!;
      var state = ProfileCreationServerState.missing;
      var writes = 0;
      var uploads = 0;
      var sessionAttempts = 0;

      Future<AuthDestination?> run() => ProfileCreationCoordinator.complete(
        binding: binding,
        isSessionCurrent: SessionService.isAuthSessionCurrent,
        readProfileState: () async => state,
        writeProfile: () async => writes++,
        uploadAssets: () async => uploads++,
        finalizeProfile: () async => state = ProfileCreationServerState.active,
        saveSessionMetadata: () async {
          sessionAttempts++;
          if (sessionAttempts == 1) throw StateError('session failure');
        },
        submitVerification: null,
        resolveDestination: () async =>
            const AuthDestination(type: AuthDestinationType.home),
      );

      await expectLater(run(), throwsStateError);
      expect(state, ProfileCreationServerState.active);
      expect((await run())?.type, AuthDestinationType.home);
      expect(writes, 1);
      expect(uploads, 1);
    },
  );

  test(
    'lost verification response retries idempotently without profile rewrite',
    () async {
      auth.changeSession('user-a');
      final AuthSessionBinding binding =
          (await SessionService.captureAuthSessionForUserId('user-a'))!;
      var state = ProfileCreationServerState.missing;
      var serverRequests = 0;
      var submitAttempts = 0;
      var writes = 0;

      Future<void> submit() async {
        submitAttempts++;
        if (serverRequests == 0) serverRequests++;
        if (submitAttempts == 1) throw StateError('response lost');
      }

      Future<AuthDestination?> run() => ProfileCreationCoordinator.complete(
        binding: binding,
        isSessionCurrent: SessionService.isAuthSessionCurrent,
        readProfileState: () async => state,
        writeProfile: () async => writes++,
        uploadAssets: () async {},
        finalizeProfile: () async => state = ProfileCreationServerState.active,
        saveSessionMetadata: () async {},
        submitVerification: submit,
        resolveDestination: () async =>
            const AuthDestination(type: AuthDestinationType.home),
      );

      await expectLater(run(), throwsStateError);
      expect((await run())?.type, AuthDestinationType.home);
      expect(writes, 1);
      expect(serverRequests, 1);
      expect(submitAttempts, 2);
    },
  );

  test(
    'verification failure retries only submission after finalization',
    () async {
      auth.changeSession('user-a');
      final AuthSessionBinding binding =
          (await SessionService.captureAuthSessionForUserId('user-a'))!;
      var state = ProfileCreationServerState.missing;
      var writes = 0;
      var attempts = 0;
      Future<AuthDestination?> run() => ProfileCreationCoordinator.complete(
        binding: binding,
        isSessionCurrent: SessionService.isAuthSessionCurrent,
        readProfileState: () async => state,
        writeProfile: () async => writes++,
        uploadAssets: () async {},
        finalizeProfile: () async => state = ProfileCreationServerState.active,
        saveSessionMetadata: () async {},
        submitVerification: () async {
          attempts++;
          if (attempts == 1) throw StateError('submit failed');
        },
        resolveDestination: () async =>
            const AuthDestination(type: AuthDestinationType.home),
      );
      await expectLater(run(), throwsStateError);
      expect((await run())?.type, AuthDestinationType.home);
      expect(writes, 1);
      expect(attempts, 2);
    },
  );

  for (final ({bool photo, bool documents}) variant
      in <({bool photo, bool documents})>[
        (photo: false, documents: false),
        (photo: true, documents: false),
        (photo: false, documents: true),
        (photo: true, documents: true),
      ]) {
    test('successful onboarding assets photo=${variant.photo} '
        'documents=${variant.documents}', () async {
      auth.changeSession('user-a');
      final AuthSessionBinding binding =
          (await SessionService.captureAuthSessionForUserId('user-a'))!;
      var photoUploads = 0;
      var documentUploads = 0;
      final result = await ProfileCreationCoordinator.complete(
        binding: binding,
        isSessionCurrent: SessionService.isAuthSessionCurrent,
        readProfileState: () async => ProfileCreationServerState.missing,
        writeProfile: () async {},
        uploadAssets: () async {
          if (variant.photo) photoUploads++;
          if (variant.documents) documentUploads += 2;
        },
        finalizeProfile: () async {},
        saveSessionMetadata: () async {},
        submitVerification: variant.documents ? () async {} : null,
        resolveDestination: () async =>
            const AuthDestination(type: AuthDestinationType.home),
      );
      expect(result?.type, AuthDestinationType.home);
      expect(photoUploads, variant.photo ? 1 : 0);
      expect(documentUploads, variant.documents ? 2 : 0);
    });
  }

  test('missing acceptance remains gated after profile creation', () async {
    auth.changeSession('user-a');
    final AuthSessionBinding binding =
        (await SessionService.captureAuthSessionForUserId('user-a'))!;

    final AuthDestination? result = await ProfileCreationCoordinator.complete(
      binding: binding,
      isSessionCurrent: SessionService.isAuthSessionCurrent,
      writeProfile: () async {},
      saveSessionMetadata: () async {},
      submitVerification: null,
      resolveDestination: () async => const AuthDestination(
        type: AuthDestinationType.legalAcceptanceRequired,
      ),
    );

    expect(result?.type, AuthDestinationType.legalAcceptanceRequired);
  });
}
