import 'package:flutter_test/flutter_test.dart';
import 'package:dorduncu/services/firebase_auth_language.dart';

void main() {
  test('TR EN DE Firebase Auth dili olarak korunur', () {
    expect(normalizeFirebaseAuthLanguage('tr'), 'tr');
    expect(normalizeFirebaseAuthLanguage('EN'), 'en');
    expect(normalizeFirebaseAuthLanguage(' de '), 'de');
  });

  test('desteklenmeyen veya eksik dil güvenli biçimde TR olur', () {
    expect(normalizeFirebaseAuthLanguage(null), 'tr');
    expect(normalizeFirebaseAuthLanguage('fr'), 'tr');
  });
}
