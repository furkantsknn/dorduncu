import 'package:dorduncu/services/phone_verification_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late PhoneVerificationSession<String> session;

  setUp(() {
    PhoneVerificationGate.reset();
    session = PhoneVerificationSession<String>();
  });

  test('geciken SMS kodu timeout sonrası da geçerli kalır', () {
    final int attempt = session.startAttempt();

    expect(
      session.codeSent(attempt, 'verification-1', 7).pushCodeScreen,
      isTrue,
    );

    session.autoTimeout(attempt, 'verification-1');

    expect(session.verificationId, 'verification-1');
    expect(session.pendingErrorCode, isNull);
    expect(session.beginManualSignIn(attempt), isTrue);
  });

  test('otomatik doğrulama ve manuel giriş tek sign-in ister', () {
    final int attempt = session.startAttempt();
    session.codeSent(attempt, 'verification-1', null);

    expect(session.autoCredential(attempt, 'auto-credential').signIn, isTrue);
    expect(session.takeAutoCredential(attempt), 'auto-credential');
    expect(session.beginManualSignIn(attempt), isFalse);
    expect(session.autoCredential(attempt, 'again').signIn, isFalse);
  });

  test('başarılı girişten sonra eski hata gösterilmez', () {
    final int attempt = session.startAttempt();
    session.codeSent(attempt, 'verification-1', null);
    session.beginManualSignIn(attempt);

    expect(session.claimNavigation(attempt), isTrue);
    expect(session.signInFailed(attempt), isFalse);
    expect(session.fail(attempt, 'session-expired'), isFalse);
    expect(session.claimNavigation(attempt), isFalse);
  });

  test('yeniden gönderilen kod eski callback ile değişmez', () {
    final int attempt = session.startAttempt();
    session.codeSent(attempt, 'verification-1', 3);
    final int resent = session.beginResend(attempt);

    session.autoTimeout(attempt, 'verification-1');
    session.codeSent(attempt, 'verification-old', 3);
    expect(session.autoCredential(attempt, 'old-auto').signIn, isFalse);

    expect(resent, isNot(0));
    expect(
      session.codeSent(resent, 'verification-2', 4).pushCodeScreen,
      isFalse,
    );
    expect(session.verificationId, 'verification-2');
    expect(session.resendToken, 4);
    expect(session.beginManualSignIn(resent), isTrue);
  });

  test('numara değiştirme geciken callback ve navigasyonu düşürür', () {
    final int attempt = session.startAttempt();
    session.codeSent(attempt, 'verification-1', null);
    expect(PhoneVerificationGate.codeEntryOpen.value, isTrue);

    session.abandon();

    expect(session.autoCredential(attempt, 'late').signIn, isFalse);
    expect(session.fail(attempt, 'session-expired'), isFalse);
    expect(session.claimNavigation(attempt), isFalse);
    expect(session.isCurrent(attempt), isFalse);

    session.releaseCodeGate();
    expect(PhoneVerificationGate.codeEntryOpen.value, isFalse);
  });

  test('Firebase hata kodları ham mesaja düşmez', () {
    expect(
      classifyPhoneAuthError('invalid-verification-code'),
      PhoneAuthFailureKind.invalidCode,
    );
    expect(
      classifyPhoneAuthError('session-expired'),
      PhoneAuthFailureKind.sessionExpired,
    );
    expect(
      classifyPhoneAuthError('invalid-verification-id'),
      PhoneAuthFailureKind.sessionExpired,
    );
    expect(
      classifyPhoneAuthError('quota-exceeded'),
      PhoneAuthFailureKind.quotaExceeded,
    );
    expect(
      classifyPhoneAuthError('network-request-failed'),
      PhoneAuthFailureKind.network,
    );
    expect(
      classifyPhoneAuthError('too-many-requests'),
      PhoneAuthFailureKind.tooManyRequests,
    );
    expect(
      classifyPhoneAuthError('internal-error'),
      PhoneAuthFailureKind.generic,
    );
  });
}
