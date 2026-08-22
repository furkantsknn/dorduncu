enum LegalDocumentType {
  kvkkNotice,
  explicitConsent,
  privacyPolicy,
  termsOfUse,
  communityRules,
  safeMeetingGuide,
  prohibitedConduct,
  complaintAndAppeal,
  accountSuspension,
  documentVerification,
  locationData,
  messagingData,
  paymentCancellationRefund,
  plusSubscription,
  digitalProducts,
  automaticRenewal,
  meetingLiability,
  ageDeclaration,
  intellectualProperty,
  forceMajeure,
  governingLaw,
}

enum LegalAcceptanceRequirement {
  none,
  mandatory,
  optional,
  contextual,
}

class LegalDocumentDefinition {
  const LegalDocumentDefinition({
    required this.type,
    required this.code,
    required this.version,
    required this.effectiveDate,
    required this.acceptanceRequirement,
    required this.requiresReacceptance,
    required this.assetName,
  });

  final LegalDocumentType type;

  /// Firebase ve uygulama içindeki değişmeyen belge kodu.
  final String code;

  /// Semantik sürüm numarası: 1.0.0, 1.1.0 gibi.
  final String version;

  /// Belgenin yürürlüğe girdiği tarih.
  final DateTime effectiveDate;

  /// Belgenin kullanıcı tarafından kabul edilme biçimi.
  final LegalAcceptanceRequirement acceptanceRequirement;

  /// Sürüm değiştiğinde yeniden kabul gerekip gerekmediği.
  final bool requiresReacceptance;

  /// Dil eki olmadan kullanılan varlık dosyası adı.
  ///
  /// Örnek:
  /// kvkk_notice_tr.md
  /// kvkk_notice_en.md
  /// kvkk_notice_de.md
  final String assetName;

  bool get requiresAcceptance =>
      acceptanceRequirement !=
          LegalAcceptanceRequirement.none;

  bool get isMandatory =>
      acceptanceRequirement ==
          LegalAcceptanceRequirement.mandatory;

  bool get isOptional =>
      acceptanceRequirement ==
          LegalAcceptanceRequirement.optional;

  bool get isContextual =>
      acceptanceRequirement ==
          LegalAcceptanceRequirement.contextual;

  String assetPathForLanguageCode(
      String languageCode,
      ) {
    final String normalizedLanguageCode =
    _normalizeLanguageCode(languageCode);

    return 'assets/legal/'
        '${assetName}_$normalizedLanguageCode.md';
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'code': code,
      'version': version,
      'effectiveDate':
      effectiveDate.toUtc().toIso8601String(),
      'acceptanceRequirement':
      acceptanceRequirement.name,
      'requiresReacceptance':
      requiresReacceptance,
      'assetName': assetName,
    };
  }

  static String _normalizeLanguageCode(
      String languageCode,
      ) {
    switch (languageCode.trim().toLowerCase()) {
      case 'en':
        return 'en';
      case 'de':
        return 'de';
      case 'tr':
      default:
        return 'tr';
    }
  }
}

class LegalAcceptanceRecord {
  const LegalAcceptanceRecord({
    required this.documentCode,
    required this.documentVersion,
    required this.accepted,
    required this.recordedAt,
    required this.languageCode,
    required this.source,
    this.withdrawnAt,
  });

  final String documentCode;
  final String documentVersion;
  final bool accepted;
  final DateTime recordedAt;
  final String languageCode;

  /// Onayın alındığı bölüm.
  ///
  /// Örnekler:
  /// registration
  /// settings
  /// payment
  /// verification
  /// location_request
  final String source;

  final DateTime? withdrawnAt;

  bool get isWithdrawn => withdrawnAt != null;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'documentCode': documentCode,
      'documentVersion': documentVersion,
      'accepted': accepted,
      'recordedAt': recordedAt.toUtc(),
      'languageCode': languageCode,
      'source': source,
      'withdrawnAt': withdrawnAt?.toUtc(),
    };
  }

  factory LegalAcceptanceRecord.fromMap(
      Map<String, dynamic> map,
      ) {
    return LegalAcceptanceRecord(
      documentCode:
      (map['documentCode'] ?? '').toString(),
      documentVersion:
      (map['documentVersion'] ?? '').toString(),
      accepted: map['accepted'] == true,
      recordedAt: _readDateTime(
        map['recordedAt'],
      ) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      languageCode:
      (map['languageCode'] ?? 'tr').toString(),
      source: (map['source'] ?? '').toString(),
      withdrawnAt: _readDateTime(
        map['withdrawnAt'],
      ),
    );
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    try {
      final dynamic dateValue = value.toDate();

      if (dateValue is DateTime) {
        return dateValue;
      }
    } catch (_) {
      // Firestore Timestamp değilse diğer
      // dönüştürme yöntemleri denenir.
    }

    return DateTime.tryParse(value.toString());
  }
}