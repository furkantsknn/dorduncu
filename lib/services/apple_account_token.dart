import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Deterministically derives an RFC-4122 UUID v5 formatted StoreKit 2
/// `appAccountToken` from a Firebase UID.
///
/// Must stay byte-identical to `appleAppAccountTokenForUid` in
/// `functions/src/commercial/appleAppStoreVerification.ts`.
String appleAppAccountTokenForUid(String uid) {
  final String normalized = uid.trim();
  if (normalized.isEmpty) {
    throw ArgumentError('Firebase UID must not be empty.');
  }

  final Digest digest = sha256.convert(
    utf8.encode('dort:apple_app_account_token:$normalized'),
  );
  final Uint8List bytes = Uint8List.fromList(digest.bytes.sublist(0, 16));
  bytes[6] = (bytes[6] & 0x0f) | 0x50; // Version 5
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant

  final String hex = bytes
      .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';
}
