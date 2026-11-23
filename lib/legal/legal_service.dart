import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../services/session_service.dart';
import 'legal_document.dart';
import 'legal_versions.dart';

class LegalService {
  LegalService._();

  static final Map<String, String> _documentCache = <String, String>{};

  static const List<String> supportedLanguageCodes = <String>['tr', 'en', 'de'];

  static String normalizeLanguageCode(String? languageCode) {
    final String normalized = languageCode?.trim().toLowerCase() ?? 'tr';

    if (normalized.startsWith('en')) {
      return 'en';
    }

    if (normalized.startsWith('de')) {
      return 'de';
    }

    return 'tr';
  }

  static LegalDocumentDefinition getDocument(LegalDocumentType type) {
    return LegalVersions.byType(type);
  }

  static LegalDocumentDefinition getDocumentByCode(String documentCode) {
    return LegalVersions.byCode(documentCode);
  }

  static String getAssetPath({
    required LegalDocumentType type,
    required String? languageCode,
  }) {
    final LegalDocumentDefinition document = getDocument(type);

    final String normalizedLanguageCode = normalizeLanguageCode(languageCode);

    return document.assetPathForLanguageCode(normalizedLanguageCode);
  }

  static Future<String> loadDocument({
    required LegalDocumentType type,
    required String? languageCode,
  }) async {
    final LegalDocumentDefinition document = getDocument(type);

    return loadDocumentDefinition(
      document: document,
      languageCode: languageCode,
    );
  }

  static Future<String> loadDocumentByCode({
    required String documentCode,
    required String? languageCode,
  }) async {
    final LegalDocumentDefinition document = getDocumentByCode(documentCode);

    return loadDocumentDefinition(
      document: document,
      languageCode: languageCode,
    );
  }

  static Future<String> loadDocumentDefinition({
    required LegalDocumentDefinition document,
    required String? languageCode,
  }) async {
    final String normalizedLanguageCode = normalizeLanguageCode(languageCode);

    final String requestedAssetPath = document.assetPathForLanguageCode(
      normalizedLanguageCode,
    );

    final String? cachedDocument = _documentCache[requestedAssetPath];

    if (cachedDocument != null) {
      return cachedDocument;
    }

    try {
      final String content = await rootBundle.loadString(requestedAssetPath);

      _documentCache[requestedAssetPath] = content;

      return content;
    } catch (_) {
      if (normalizedLanguageCode == 'tr') {
        throw LegalDocumentLoadException(
          documentCode: document.code,
          requestedLanguageCode: normalizedLanguageCode,
          requestedAssetPath: requestedAssetPath,
        );
      }

      return _loadTurkishFallback(
        document: document,
        requestedLanguageCode: normalizedLanguageCode,
        requestedAssetPath: requestedAssetPath,
      );
    }
  }

  static Future<String> _loadTurkishFallback({
    required LegalDocumentDefinition document,
    required String requestedLanguageCode,
    required String requestedAssetPath,
  }) async {
    final String fallbackAssetPath = document.assetPathForLanguageCode('tr');

    final String? cachedFallback = _documentCache[fallbackAssetPath];

    if (cachedFallback != null) {
      return cachedFallback;
    }

    try {
      final String fallbackContent = await rootBundle.loadString(
        fallbackAssetPath,
      );

      _documentCache[fallbackAssetPath] = fallbackContent;

      return fallbackContent;
    } catch (_) {
      throw LegalDocumentLoadException(
        documentCode: document.code,
        requestedLanguageCode: requestedLanguageCode,
        requestedAssetPath: requestedAssetPath,
        fallbackAssetPath: fallbackAssetPath,
      );
    }
  }

  static bool isCurrentVersion({
    required String documentCode,
    required String acceptedVersion,
  }) {
    final LegalDocumentDefinition document = getDocumentByCode(documentCode);

    return document.version.trim() == acceptedVersion.trim();
  }

  static bool requiresNewAcceptance({
    required String documentCode,
    String? acceptedVersion,
    bool accepted = false,
    DateTime? withdrawnAt,
  }) {
    final LegalDocumentDefinition document = getDocumentByCode(documentCode);

    if (!document.requiresAcceptance) {
      return false;
    }

    if (!accepted || withdrawnAt != null) {
      return true;
    }

    if (acceptedVersion == null || acceptedVersion.trim().isEmpty) {
      return true;
    }

    if (!document.requiresReacceptance) {
      return false;
    }

    return !isCurrentVersion(
      documentCode: documentCode,
      acceptedVersion: acceptedVersion,
    );
  }

  static List<LegalDocumentDefinition> getMandatoryDocuments() {
    return LegalVersions.documents
        .where((LegalDocumentDefinition document) => document.isMandatory)
        .toList(growable: false);
  }

  /// Documents recorded when the login checkboxes are confirmed.
  ///
  /// Terms and community rules share one checkbox and are stored as separate
  /// versioned acceptances. The age declaration is the second checkbox.
  /// KVKK and privacy stay informational and are not in this list.
  static List<LegalDocumentDefinition> onboardingAcceptanceDocuments() {
    return const <String>[
      'terms_of_use',
      'community_rules',
      'age_declaration',
    ].map(LegalVersions.byCode).toList(growable: false);
  }

  static List<LegalDocumentDefinition> onboardingInformationDocuments() {
    return const <String>[
      'kvkk_notice',
      'privacy_policy',
    ].map(LegalVersions.byCode).toList(growable: false);
  }

  static List<LegalDocumentDefinition> getOptionalDocuments() {
    return LegalVersions.documents
        .where((LegalDocumentDefinition document) => document.isOptional)
        .toList(growable: false);
  }

  static List<LegalDocumentDefinition> getContextualDocuments() {
    return LegalVersions.documents
        .where((LegalDocumentDefinition document) => document.isContextual)
        .toList(growable: false);
  }

  static const String onboardingAcceptanceSource = 'onboarding/login';

  static String acceptanceDocumentId({
    required String documentCode,
    required String version,
  }) {
    return '${documentCode}_$version';
  }

  /// Writes the login checkbox acceptances.
  ///
  /// `acceptedAt` is a Firestore server timestamp. The document id is
  /// `{code}_{version}`, so the same version is not written twice. A newer
  /// version creates a new document and marks older copies inactive.
  /// Existing records are not deleted. Informational documents are not written.
  static Future<void> recordOnboardingAcceptances({
    required String userId,
    required String locale,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != userId) {
      throw StateError('Legal acceptance requires the signed-in user.');
    }
    final AuthSessionBinding? binding = await SessionService.captureAuthSession(
      user: user,
    );
    if (binding == null) {
      throw StateError('Legal acceptance requires a current app session.');
    }

    final String language = normalizeLanguageCode(locale);
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final CollectionReference<Map<String, dynamic>> collection = firestore
        .collection('users')
        .doc(userId)
        .collection('legal_acceptances');

    final WriteBatch batch = firestore.batch();
    var hasWrites = false;
    for (final LegalDocumentDefinition document
        in onboardingAcceptanceDocuments()) {
      final String documentId = acceptanceDocumentId(
        documentCode: document.code,
        version: document.version,
      );
      final DocumentReference<Map<String, dynamic>> currentRef = collection.doc(
        documentId,
      );
      final DocumentSnapshot<Map<String, dynamic>> current = await currentRef
          .get(const GetOptions(source: Source.server));
      await _assertBinding(binding);
      if (current.exists) {
        continue;
      }

      final QuerySnapshot<Map<String, dynamic>> previous = await collection
          .where('documentCode', isEqualTo: document.code)
          .get(const GetOptions(source: Source.server));
      await _assertBinding(binding);

      for (final QueryDocumentSnapshot<Map<String, dynamic>> old
          in previous.docs) {
        if (old.id == documentId || old.data()['active'] != true) {
          continue;
        }
        batch.update(old.reference, <String, Object>{'active': false});
      }
      batch.set(currentRef, <String, Object>{
        'userId': userId,
        'documentCode': document.code,
        'version': document.version,
        'acceptedAt': FieldValue.serverTimestamp(),
        'locale': language,
        'source': onboardingAcceptanceSource,
        'active': true,
      });
      hasWrites = true;
    }
    if (hasWrites) {
      await batch.commit();
      await _assertBinding(binding);
    }
    if (!await hasCurrentOnboardingAcceptances(
      userId: userId,
      expectedBinding: binding,
    )) {
      throw StateError('Mandatory legal acceptances were not persisted.');
    }
  }

  /// Returns true only when all three current mandatory records are valid.
  static Future<bool> hasCurrentOnboardingAcceptances({
    required String userId,
    AuthSessionBinding? expectedBinding,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != userId) return false;
    final AuthSessionBinding? binding =
        expectedBinding ?? await SessionService.captureAuthSession(user: user);
    if (binding == null ||
        !await SessionService.isAuthSessionCurrent(binding)) {
      return false;
    }
    final CollectionReference<Map<String, dynamic>> collection =
        FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('legal_acceptances');
    return validateOnboardingAcceptancesFromServer(
      userId: userId,
      readRecord: (String documentId) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot = await collection
            .doc(documentId)
            .get(const GetOptions(source: Source.server));
        return snapshot.exists ? snapshot.data() : null;
      },
      bindingStillCurrent: () => SessionService.isAuthSessionCurrent(binding),
    );
  }

  @visibleForTesting
  static Future<bool> validateOnboardingAcceptancesFromServer({
    required String userId,
    required Future<Map<String, dynamic>?> Function(String documentId)
    readRecord,
    required Future<bool> Function() bindingStillCurrent,
  }) async {
    final Map<String, Map<String, dynamic>?> records =
        <String, Map<String, dynamic>?>{};
    for (final LegalDocumentDefinition document
        in onboardingAcceptanceDocuments()) {
      final String documentId = acceptanceDocumentId(
        documentCode: document.code,
        version: document.version,
      );
      records[document.code] = await readRecord(documentId);
      if (!await bindingStillCurrent()) return false;
    }
    return hasValidOnboardingAcceptanceData(userId: userId, records: records);
  }

  static Future<void> _assertBinding(AuthSessionBinding binding) async {
    if (!await SessionService.isAuthSessionCurrent(binding)) {
      throw StateError('Legal acceptance session changed.');
    }
  }

  static bool hasValidOnboardingAcceptanceData({
    required String userId,
    required Map<String, Map<String, dynamic>?> records,
  }) {
    for (final LegalDocumentDefinition document
        in onboardingAcceptanceDocuments()) {
      final Map<String, dynamic>? data = records[document.code];
      if (data == null ||
          data['userId'] != userId ||
          data['documentCode'] != document.code ||
          data['version'] != document.version ||
          data['source'] != onboardingAcceptanceSource ||
          data['active'] != true ||
          data['acceptedAt'] == null) {
        return false;
      }
    }
    return true;
  }

  static void clearCache() {
    _documentCache.clear();
  }

  static void removeFromCache({
    required LegalDocumentType type,
    required String? languageCode,
  }) {
    final String assetPath = getAssetPath(
      type: type,
      languageCode: languageCode,
    );

    _documentCache.remove(assetPath);
  }
}

class LegalDocumentLoadException implements Exception {
  const LegalDocumentLoadException({
    required this.documentCode,
    required this.requestedLanguageCode,
    required this.requestedAssetPath,
    this.fallbackAssetPath,
  });

  final String documentCode;
  final String requestedLanguageCode;
  final String requestedAssetPath;
  final String? fallbackAssetPath;

  @override
  String toString() {
    final String fallbackInformation = fallbackAssetPath == null
        ? ''
        : ' Türkçe yedek dosya da bulunamadı: '
              '$fallbackAssetPath.';

    return 'Hukuki belge yüklenemedi. '
        'Belge: $documentCode, '
        'dil: $requestedLanguageCode, '
        'dosya: $requestedAssetPath.'
        '$fallbackInformation';
  }
}
