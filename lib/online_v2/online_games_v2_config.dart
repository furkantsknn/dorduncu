import 'package:flutter/foundation.dart';

/// V2 online tables stay out of the V1 shell unless this define is set.
///
/// `flutter run --dart-define=ONLINE_GAMES_V2=true`
const bool kOnlineGamesV2Enabled = bool.fromEnvironment(
  'ONLINE_GAMES_V2',
  defaultValue: false,
);

/// Multiplayer talks only to the local Firebase emulators.
/// Production Firestore and Functions are never used for these tables.
///
/// `flutter run --dart-define=ONLINE_GAMES_V2=true --dart-define=ONLINE_GAMES_V2_EMULATOR=true`
const bool kOnlineGamesV2UseEmulator = bool.fromEnvironment(
  'ONLINE_GAMES_V2_EMULATOR',
  defaultValue: false,
);

const String kOnlineGamesV2EmulatorHost = '127.0.0.1';
const int kOnlineGamesV2FirestorePort = 8080;
const int kOnlineGamesV2FunctionsPort = 5001;
const int kOnlineGamesV2AuthPort = 9099;

bool get onlineGamesV2MultiplayerAvailable =>
    kOnlineGamesV2Enabled && kOnlineGamesV2UseEmulator && !kReleaseMode;
