import 'package:dorduncu/legal/legal_versions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const List<String> requiredCodes = <String>[
    'kvkk_notice',
    'privacy_policy',
    'terms_of_use',
    'community_rules',
    'plus_subscription',
    'digital_products',
    'automatic_renewal',
    'account_policy',
    'location_policy',
    'messaging_policy',
    'age_declaration',
  ];

  test('registered legal documents match real asset files', () async {
    expect(
      LegalVersions.documents.map((document) => document.code).toSet(),
      requiredCodes.toSet(),
    );

    String? kvkk;
    String? privacy;

    for (final document in LegalVersions.documents) {
      expect(document.assetName, document.code);

      for (final language in <String>['tr', 'en', 'de']) {
        final String path = document.assetPathForLanguageCode(language);
        expect(path, 'assets/legal/$language/${document.code}.md');

        final String content = await rootBundle.loadString(path);
        expect(content.trim(), isNotEmpty);
        expect(content.contains('Dördüncü'), isFalse);
        expect(content.toLowerCase().contains('furkantskn'), isFalse);
        expect(content.toLowerCase().contains('mersis'), isFalse);
        expect(content.contains('%40'), isFalse);
        expect(content.toLowerCase().contains('cüzdan'), isFalse);
        expect(content.toLowerCase().contains('şirket kuruluş'), isFalse);
        expect(content.toLowerCase().contains('wallet'), isFalse);

        if (language == 'tr' && document.code == 'kvkk_notice') {
          kvkk = content;
        }
        if (language == 'tr' && document.code == 'privacy_policy') {
          privacy = content;
        }
      }
    }

    expect(kvkk, isNotNull);
    expect(privacy, isNotNull);
    expect(kvkk, isNot(privacy));
  });
}
