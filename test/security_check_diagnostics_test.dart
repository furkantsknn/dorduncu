import 'package:cloud_functions/cloud_functions.dart';
import 'package:dorduncu/services/language_controller.dart';
import 'package:dorduncu/services/security_check_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'unauthenticated functions hatası kodu ve güvenli açıklamayı gösterir',
    () {
      final FirebaseFunctionsException error = FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'UNAUTHENTICATED',
        details: <String, Object?>{
          'phone': '+905551234567',
          'token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTYifQ.signature1234567890',
        },
      );

      final SecurityCheckFailureDiagnostic diagnostic =
          buildSecurityCheckFailureDiagnostic(
            error,
            language: AppLanguage.turkish,
          );

      expect(diagnostic.code, 'unauthenticated');
      expect(diagnostic.userMessage, contains('unauthenticated'));
      expect(
        diagnostic.userMessage,
        contains('Uygulama veya oturum doğrulaması reddedildi'),
      );
      expect(diagnostic.logLine, contains('code=unauthenticated'));
      expect(diagnostic.logLine, isNot(contains('+905551234567')));
      expect(diagnostic.logLine, isNot(contains('eyJhbGci')));
    },
  );

  test(
    'güvenli sunucu mesajı korunur ve tüm dillerde kod bilgisi taşınır',
    () {
      final SecurityCheckFailureDiagnostic tr =
          buildSecurityCheckFailureDiagnosticFromParts(
            rawCode: 'failed-precondition',
            rawMessage: 'Telefon numarası doğrulanamadı.',
            language: AppLanguage.turkish,
          );
      expect(tr.code, 'failed-precondition');
      expect(
        tr.userMessage,
        contains('failed-precondition: Telefon numarası doğrulanamadı.'),
      );

      final SecurityCheckFailureDiagnostic en =
          buildSecurityCheckFailureDiagnosticFromParts(
            rawCode: 'unavailable',
            rawMessage: 'UNAVAILABLE',
            language: AppLanguage.english,
          );
      expect(
        en.userMessage,
        contains('unavailable: Server is temporarily unavailable'),
      );

      final SecurityCheckFailureDiagnostic de =
          buildSecurityCheckFailureDiagnosticFromParts(
            rawCode: 'not-found',
            rawMessage: null,
            language: AppLanguage.german,
          );
      expect(
        de.userMessage,
        contains('not-found: Sicherheitsprüfungsdienst wurde nicht gefunden'),
      );
    },
  );

  test(
    'SMS kodu, telefon numarası, e-posta ve token içeren ham mesaj sızmaz',
    () {
      final SecurityCheckFailureDiagnostic diagnostic =
          buildSecurityCheckFailureDiagnosticFromParts(
            rawCode: 'internal',
            rawMessage:
                'Verify failed for +90 555 123 45 67 sms=654321 user@example.com '
                'token=eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJhYmMifQ.sig1234567890abcdef',
            language: AppLanguage.turkish,
          );

      expect(diagnostic.code, 'internal');
      expect(diagnostic.safeMessage, 'Sunucu güvenlik doğrulaması başarısız');
      expect(diagnostic.userMessage, isNot(contains('555')));
      expect(diagnostic.userMessage, isNot(contains('654321')));
      expect(diagnostic.userMessage, isNot(contains('user@example.com')));
      expect(diagnostic.userMessage, isNot(contains('eyJhbGci')));
      expect(diagnostic.logLine, isNot(contains('555')));
      expect(diagnostic.logLine, isNot(contains('654321')));
      expect(diagnostic.logLine, isNot(contains('user@example.com')));
      expect(diagnostic.logLine, isNot(contains('eyJhbGci')));
    },
  );

  test('uzun opak tokenlar ve kontrol karakterleri temizlenir', () {
    final String sanitized = sanitizeFunctionsErrorMessage(
      'Header\nrejected\tABCDEFGHIJKLMNOPQRSTUVWXYZ123456',
      code: 'permission-denied',
    );

    expect(sanitized, isNot(contains('ABCDEFGHIJKLMNOPQRSTUVWXYZ123456')));
    expect(sanitized, isNot(contains('\n')));
    expect(sanitized, isNot(contains('\t')));
  });
}
