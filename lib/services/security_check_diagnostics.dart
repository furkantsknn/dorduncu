import 'package:cloud_functions/cloud_functions.dart';

import 'language_controller.dart';

class SecurityCheckFailureDiagnostic {
  const SecurityCheckFailureDiagnostic({
    required this.callableName,
    required this.code,
    required this.safeMessage,
    required this.userMessage,
    required this.logLine,
  });

  final String callableName;
  final String code;
  final String safeMessage;
  final String userMessage;
  final String logLine;
}

final RegExp _jwtPattern = RegExp(
  r'[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}',
);
final RegExp _emailPattern = RegExp(
  r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
);
final RegExp _longTokenPattern = RegExp(r'[A-Za-z0-9+/=_-]{24,}');
final RegExp _phoneOrCodePattern = RegExp(
  r'\+?\d[\d\s\-().]{2,}\d|\b\d{4,}\b',
);
final RegExp _controlCharsPattern = RegExp(r'[\r\n\t\x00-\x1F\x7F]+');
final RegExp _multiSpacePattern = RegExp(r'\s+');
final RegExp _codeUnsafeCharsPattern = RegExp(r'[^a-z0-9_-]');

String normalizeFunctionsErrorCode(String? rawCode) {
  final String cleaned = (rawCode ?? '')
      .trim()
      .toLowerCase()
      .replaceAll(' ', '-')
      .replaceAll(_codeUnsafeCharsPattern, '');
  if (cleaned.isEmpty) {
    return 'unknown';
  }
  return cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
}

/// Removes tokens, JWTs, emails, phone numbers, and numeric codes (including
/// 6-digit SMS codes) so diagnostic strings never leak secrets or PII.
String sanitizeFunctionsErrorMessage(String? rawMessage, {String? code}) {
  if (rawMessage == null) return '';
  String text = rawMessage
      .replaceAll(_controlCharsPattern, ' ')
      .replaceAll(_jwtPattern, '[redacted]')
      .replaceAll(_emailPattern, '[redacted]')
      .replaceAll(_longTokenPattern, '[redacted]')
      .replaceAll(_phoneOrCodePattern, '[redacted]')
      .replaceAll(_multiSpacePattern, ' ')
      .trim();

  if (text.isEmpty) return '';

  final String normalizedCode = normalizeFunctionsErrorCode(code);
  final String comparable = text
      .toLowerCase()
      .replaceAll('_', '-')
      .replaceAll(' ', '-')
      .replaceAll(_codeUnsafeCharsPattern, '');
  if (comparable == normalizedCode || text == '[redacted]') {
    return '';
  }

  if (text.length > 120) {
    text = '${text.substring(0, 117).trimRight()}...';
  }
  return text;
}

String safeSecurityCheckReasonForCode(String code, AppLanguage language) {
  String value({required String tr, required String en, required String de}) {
    switch (language) {
      case AppLanguage.turkish:
        return tr;
      case AppLanguage.english:
        return en;
      case AppLanguage.german:
        return de;
    }
  }

  switch (code) {
    case 'unauthenticated':
      return value(
        tr: 'Uygulama veya oturum doğrulaması reddedildi',
        en: 'App or session verification was rejected',
        de: 'App- oder Sitzungsverifizierung wurde abgelehnt',
      );
    case 'permission-denied':
      return value(
        tr: 'Erişim yetkisi reddedildi',
        en: 'Access permission was denied',
        de: 'Zugriffsberechtigung wurde verweigert',
      );
    case 'failed-precondition':
      return value(
        tr: 'Telefon doğrulama ön koşulu sağlanamadı',
        en: 'Phone verification precondition was not met',
        de: 'Vorbedingung der Telefonverifizierung nicht erfüllt',
      );
    case 'not-found':
      return value(
        tr: 'Güvenlik doğrulama servisi bulunamadı',
        en: 'Security verification service was not found',
        de: 'Sicherheitsprüfungsdienst wurde nicht gefunden',
      );
    case 'unavailable':
    case 'deadline-exceeded':
      return value(
        tr: 'Sunucuya geçici olarak ulaşılamadı',
        en: 'Server is temporarily unavailable',
        de: 'Server ist vorübergehend nicht erreichbar',
      );
    case 'resource-exhausted':
      return value(
        tr: 'Çok fazla istek gönderildi',
        en: 'Too many requests were sent',
        de: 'Zu viele Anfragen wurden gesendet',
      );
    default:
      return value(
        tr: 'Sunucu güvenlik doğrulaması başarısız',
        en: 'Server security verification failed',
        de: 'Sicherheitsprüfung auf dem Server fehlgeschlagen',
      );
  }
}

SecurityCheckFailureDiagnostic buildSecurityCheckFailureDiagnosticFromParts({
  required String? rawCode,
  required String? rawMessage,
  required AppLanguage language,
  String callableName = 'checkDeletedPhone',
}) {
  final String code = normalizeFunctionsErrorCode(rawCode);
  final String sanitized = sanitizeFunctionsErrorMessage(
    rawMessage,
    code: code,
  );
  final String safeReason = safeSecurityCheckReasonForCode(code, language);
  final bool hasRedaction = sanitized.contains('[redacted]');
  final String safeMessage = sanitized.isNotEmpty && !hasRedaction
      ? sanitized
      : safeReason;

  final String userMessage = switch (language) {
    AppLanguage.turkish =>
      'Güvenlik kontrolü tamamlanamadı ($code: $safeMessage). Lütfen tekrar deneyin.',
    AppLanguage.english =>
      'Security check could not be completed ($code: $safeMessage). Please try again.',
    AppLanguage.german =>
      'Die Sicherheitsprüfung konnte nicht abgeschlossen werden ($code: $safeMessage). Bitte versuche es erneut.',
  };

  final String safeCallable = normalizeFunctionsErrorCode(callableName);
  final String logLine =
      'securityCheck[$safeCallable] failed: code=$code reason=$safeMessage';

  return SecurityCheckFailureDiagnostic(
    callableName: safeCallable,
    code: code,
    safeMessage: safeMessage,
    userMessage: userMessage,
    logLine: logLine,
  );
}

SecurityCheckFailureDiagnostic buildSecurityCheckFailureDiagnostic(
  FirebaseFunctionsException error, {
  required AppLanguage language,
  String callableName = 'checkDeletedPhone',
}) {
  return buildSecurityCheckFailureDiagnosticFromParts(
    rawCode: error.code,
    rawMessage: error.message,
    language: language,
    callableName: callableName,
  );
}
