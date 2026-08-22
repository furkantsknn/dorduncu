import 'legal_document.dart';

class LegalVersions {
  LegalVersions._();

  static const String currentVersion = '1.0.0';

  static final List<LegalDocumentDefinition> documents =
  <LegalDocumentDefinition>[
    LegalDocumentDefinition(
      type: LegalDocumentType.kvkkNotice,
      code: 'kvkk_notice',
      version: currentVersion,
      effectiveDate: DateTime(2026, 7, 24),
      acceptanceRequirement:
      LegalAcceptanceRequirement.mandatory,
      requiresReacceptance: true,
      assetName: 'kvkk_notice',
    ),

    LegalDocumentDefinition(
      type: LegalDocumentType.explicitConsent,
      code: 'explicit_consent',
      version: currentVersion,
      effectiveDate: DateTime(2026, 7, 24),
      acceptanceRequirement:
      LegalAcceptanceRequirement.optional,
      requiresReacceptance: true,
      assetName: 'explicit_consent',
    ),

    LegalDocumentDefinition(
      type: LegalDocumentType.privacyPolicy,
      code: 'privacy_policy',
      version: currentVersion,
      effectiveDate: DateTime(2026, 7, 24),
      acceptanceRequirement:
      LegalAcceptanceRequirement.mandatory,
      requiresReacceptance: true,
      assetName: 'privacy_policy',
    ),

    LegalDocumentDefinition(
      type: LegalDocumentType.termsOfUse,
      code: 'terms_of_use',
      version: currentVersion,
      effectiveDate: DateTime(2026, 7, 24),
      acceptanceRequirement:
      LegalAcceptanceRequirement.mandatory,
      requiresReacceptance: true,
      assetName: 'terms_of_use',
    ),

    LegalDocumentDefinition(
      type: LegalDocumentType.communityRules,
      code: 'community_rules',
      version: currentVersion,
      effectiveDate: DateTime(2026, 7, 24),
      acceptanceRequirement:
      LegalAcceptanceRequirement.mandatory,
      requiresReacceptance: true,
      assetName: 'community_rules',
    ),

    LegalDocumentDefinition(
      type: LegalDocumentType.safeMeetingGuide,
      code: 'safe_meeting',
      version: currentVersion,
      effectiveDate: DateTime(2026, 7, 24),
      acceptanceRequirement:
      LegalAcceptanceRequirement.none,
      requiresReacceptance: false,
      assetName: 'safe_meeting',
    ),

    LegalDocumentDefinition(
      type: LegalDocumentType.prohibitedConduct,
      code: 'prohibited_conduct',
      version: currentVersion,
      effectiveDate: DateTime(2026, 7, 24),
      acceptanceRequirement:
      LegalAcceptanceRequirement.none,
      requiresReacceptance: false,
      assetName: 'prohibited_conduct',
    ),

    LegalDocumentDefinition(
      type: LegalDocumentType.complaintAndAppeal,
      code: 'complaint_procedure',
      version: currentVersion,
      effectiveDate: DateTime(2026, 7, 24),
      acceptanceRequirement:
      LegalAcceptanceRequirement.none,
      requiresReacceptance: false,
      assetName: 'complaint_procedure',
    ),

    LegalDocumentDefinition(
      type: LegalDocumentType.accountSuspension,
      code: 'account_policy',
      version: currentVersion,
      effectiveDate: DateTime(2026, 7, 24),
      acceptanceRequirement:
      LegalAcceptanceRequirement.none,
      requiresReacceptance: false,
      assetName: 'account_policy',
    ),

    LegalDocumentDefinition(
      type: LegalDocumentType.documentVerification,
      code: 'verification_policy',
      version: currentVersion,
      effectiveDate: DateTime(2026, 7, 24),
      acceptanceRequirement:
      LegalAcceptanceRequirement.contextual,
      requiresReacceptance: false,
      assetName: 'verification_policy',
    ),

    LegalDocumentDefinition(
      type: LegalDocumentType.locationData,
      code: 'location_policy',
      version: currentVersion,
      effectiveDate: DateTime(2026, 7, 24),
      acceptanceRequirement:
      LegalAcceptanceRequirement.contextual,
      requiresReacceptance: false,
      assetName: 'location_policy',
    ),

    LegalDocumentDefinition(
      type: LegalDocumentType.messagingData,
      code: 'messaging_policy',
      version: currentVersion,
      effectiveDate: DateTime(2026, 7, 24),
      acceptanceRequirement:
      LegalAcceptanceRequirement.none,
      requiresReacceptance: false,
      assetName: 'messaging_policy',
    ),

    LegalDocumentDefinition(
      type: LegalDocumentType.paymentCancellationRefund,
      code: 'payment_policy',
      version: currentVersion,
      effectiveDate: DateTime(2026, 7, 24),
      acceptanceRequirement:
      LegalAcceptanceRequirement.contextual,
      requiresReacceptance: true,
      assetName: 'payment_policy',
    ),

    LegalDocumentDefinition(
      type: LegalDocumentType.plusSubscription,
      code: 'plus_subscription',
      version: currentVersion,
      effectiveDate: DateTime(2026, 7, 24),
      acceptanceRequirement:
      LegalAcceptanceRequirement.contextual,
      requiresReacceptance: true,
      assetName: 'plus_subscription',
    ),

    LegalDocumentDefinition(
      type: LegalDocumentType.digitalProducts,
      code: 'digital_products',
      version: currentVersion,
      effectiveDate: DateTime(2026, 7, 24),
      acceptanceRequirement:
      LegalAcceptanceRequirement.contextual,
      requiresReacceptance: true,
      assetName: 'digital_products',
    ),

    LegalDocumentDefinition(
      type: LegalDocumentType.automaticRenewal,
      code: 'automatic_renewal',
      version: currentVersion,
      effectiveDate: DateTime(2026, 7, 24),
      acceptanceRequirement:
      LegalAcceptanceRequirement.contextual,
      requiresReacceptance: true,
      assetName: 'automatic_renewal',
    ),

    LegalDocumentDefinition(
      type: LegalDocumentType.meetingLiability,
      code: 'meeting_liability',
      version: currentVersion,
      effectiveDate: DateTime(2026, 7, 24),
      acceptanceRequirement:
      LegalAcceptanceRequirement.none,
      requiresReacceptance: false,
      assetName: 'meeting_liability',
    ),

    LegalDocumentDefinition(
      type: LegalDocumentType.ageDeclaration,
      code: 'age_declaration',
      version: currentVersion,
      effectiveDate: DateTime(2026, 7, 24),
      acceptanceRequirement:
      LegalAcceptanceRequirement.mandatory,
      requiresReacceptance: true,
      assetName: 'age_declaration',
    ),

    LegalDocumentDefinition(
      type: LegalDocumentType.intellectualProperty,
      code: 'intellectual_property',
      version: currentVersion,
      effectiveDate: DateTime(2026, 7, 24),
      acceptanceRequirement:
      LegalAcceptanceRequirement.none,
      requiresReacceptance: false,
      assetName: 'intellectual_property',
    ),

    LegalDocumentDefinition(
      type: LegalDocumentType.forceMajeure,
      code: 'force_majeure',
      version: currentVersion,
      effectiveDate: DateTime(2026, 7, 24),
      acceptanceRequirement:
      LegalAcceptanceRequirement.none,
      requiresReacceptance: false,
      assetName: 'force_majeure',
    ),

    LegalDocumentDefinition(
      type: LegalDocumentType.governingLaw,
      code: 'governing_law',
      version: currentVersion,
      effectiveDate: DateTime(2026, 7, 24),
      acceptanceRequirement:
      LegalAcceptanceRequirement.none,
      requiresReacceptance: false,
      assetName: 'governing_law',
    ),
  ];

  static LegalDocumentDefinition byType(
      LegalDocumentType type) {
    return documents.firstWhere(
          (e) => e.type == type,
    );
  }

  static LegalDocumentDefinition byCode(
      String code) {
    return documents.firstWhere(
          (e) => e.code == code,
    );
  }
}