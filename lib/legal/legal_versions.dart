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
          effectiveDate: DateTime(2026, 10, 5),
          acceptanceRequirement: LegalAcceptanceRequirement.mandatory,
          requiresReacceptance: true,
          assetName: 'kvkk_notice',
        ),
        LegalDocumentDefinition(
          type: LegalDocumentType.privacyPolicy,
          code: 'privacy_policy',
          version: currentVersion,
          effectiveDate: DateTime(2026, 10, 5),
          acceptanceRequirement: LegalAcceptanceRequirement.mandatory,
          requiresReacceptance: true,
          assetName: 'privacy_policy',
        ),
        LegalDocumentDefinition(
          type: LegalDocumentType.termsOfUse,
          code: 'terms_of_use',
          version: currentVersion,
          effectiveDate: DateTime(2026, 10, 5),
          acceptanceRequirement: LegalAcceptanceRequirement.mandatory,
          requiresReacceptance: true,
          assetName: 'terms_of_use',
        ),
        LegalDocumentDefinition(
          type: LegalDocumentType.communityRules,
          code: 'community_rules',
          version: currentVersion,
          effectiveDate: DateTime(2026, 10, 5),
          acceptanceRequirement: LegalAcceptanceRequirement.mandatory,
          requiresReacceptance: true,
          assetName: 'community_rules',
        ),
        LegalDocumentDefinition(
          type: LegalDocumentType.accountSuspension,
          code: 'account_policy',
          version: currentVersion,
          effectiveDate: DateTime(2026, 10, 5),
          acceptanceRequirement: LegalAcceptanceRequirement.none,
          requiresReacceptance: false,
          assetName: 'account_policy',
        ),
        LegalDocumentDefinition(
          type: LegalDocumentType.locationData,
          code: 'location_policy',
          version: currentVersion,
          effectiveDate: DateTime(2026, 10, 5),
          acceptanceRequirement: LegalAcceptanceRequirement.contextual,
          requiresReacceptance: false,
          assetName: 'location_policy',
        ),
        LegalDocumentDefinition(
          type: LegalDocumentType.messagingData,
          code: 'messaging_policy',
          version: currentVersion,
          effectiveDate: DateTime(2026, 10, 5),
          acceptanceRequirement: LegalAcceptanceRequirement.none,
          requiresReacceptance: false,
          assetName: 'messaging_policy',
        ),
        LegalDocumentDefinition(
          type: LegalDocumentType.plusSubscription,
          code: 'plus_subscription',
          version: currentVersion,
          effectiveDate: DateTime(2026, 10, 5),
          acceptanceRequirement: LegalAcceptanceRequirement.contextual,
          requiresReacceptance: true,
          assetName: 'plus_subscription',
        ),
        LegalDocumentDefinition(
          type: LegalDocumentType.digitalProducts,
          code: 'digital_products',
          version: currentVersion,
          effectiveDate: DateTime(2026, 10, 5),
          acceptanceRequirement: LegalAcceptanceRequirement.contextual,
          requiresReacceptance: true,
          assetName: 'digital_products',
        ),
        LegalDocumentDefinition(
          type: LegalDocumentType.automaticRenewal,
          code: 'automatic_renewal',
          version: currentVersion,
          effectiveDate: DateTime(2026, 10, 5),
          acceptanceRequirement: LegalAcceptanceRequirement.contextual,
          requiresReacceptance: true,
          assetName: 'automatic_renewal',
        ),
        LegalDocumentDefinition(
          type: LegalDocumentType.ageDeclaration,
          code: 'age_declaration',
          version: currentVersion,
          effectiveDate: DateTime(2026, 10, 5),
          acceptanceRequirement: LegalAcceptanceRequirement.mandatory,
          requiresReacceptance: true,
          assetName: 'age_declaration',
        ),
      ];

  static LegalDocumentDefinition byType(LegalDocumentType type) {
    return documents.firstWhere((e) => e.type == type);
  }

  static LegalDocumentDefinition byCode(String code) {
    return documents.firstWhere((e) => e.code == code);
  }
}
