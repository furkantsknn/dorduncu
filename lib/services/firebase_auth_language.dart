import 'package:firebase_auth/firebase_auth.dart';

const Set<String> supportedFirebaseAuthLanguages = <String>{'tr', 'en', 'de'};

String normalizeFirebaseAuthLanguage(String? languageCode) {
  final String normalized = languageCode?.trim().toLowerCase() ?? '';
  return supportedFirebaseAuthLanguages.contains(normalized)
      ? normalized
      : 'tr';
}

/// Applies the app language immediately before Firebase starts an SMS flow.
Future<void> applyFirebaseAuthLanguage(
  FirebaseAuth auth,
  String? languageCode,
) {
  return auth.setLanguageCode(normalizeFirebaseAuthLanguage(languageCode));
}
