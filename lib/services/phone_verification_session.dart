import 'package:flutter/foundation.dart';

/// Phone-entry screen stays up while the SMS screen is open, even if
/// auto verification has already signed in. Cleared only when that
/// attempt is abandoned or navigation is claimed.
class PhoneVerificationGate {
  static final ValueNotifier<bool> codeEntryOpen = ValueNotifier<bool>(false);

  static void reset() {
    codeEntryOpen.value = false;
  }
}

class PhoneAuthDecision {
  const PhoneAuthDecision({
    this.signIn = false,
    this.pushCodeScreen = false,
    this.showOnRequestScreen = false,
  });

  final bool signIn;
  final bool pushCodeScreen;
  final bool showOnRequestScreen;

  static const PhoneAuthDecision ignore = PhoneAuthDecision();
}

enum PhoneAuthFailureKind {
  invalidCode,
  sessionExpired,
  tooManyRequests,
  quotaExceeded,
  network,
  captcha,
  appNotAuthorized,
  invalidPhone,
  operationNotAllowed,
  billingNotEnabled,
  missingClientIdentifier,
  generic,
}

PhoneAuthFailureKind classifyPhoneAuthError(String code) {
  switch (code) {
    case 'invalid-verification-code':
      return PhoneAuthFailureKind.invalidCode;
    case 'session-expired':
    case 'invalid-verification-id':
      return PhoneAuthFailureKind.sessionExpired;
    case 'too-many-requests':
      return PhoneAuthFailureKind.tooManyRequests;
    case 'quota-exceeded':
      return PhoneAuthFailureKind.quotaExceeded;
    case 'network-request-failed':
      return PhoneAuthFailureKind.network;
    case 'captcha-check-failed':
      return PhoneAuthFailureKind.captcha;
    case 'invalid-app-credential':
    case 'app-not-authorized':
      return PhoneAuthFailureKind.appNotAuthorized;
    case 'invalid-phone-number':
      return PhoneAuthFailureKind.invalidPhone;
    case 'operation-not-allowed':
      return PhoneAuthFailureKind.operationNotAllowed;
    case 'billing-not-enabled':
      return PhoneAuthFailureKind.billingNotEnabled;
    case 'missing-client-identifier':
      return PhoneAuthFailureKind.missingClientIdentifier;
    default:
      return PhoneAuthFailureKind.generic;
  }
}

/// One phone-auth attempt. A newer attempt or "change number" makes
/// older callbacks unable to sign in, show an error, or navigate.
class PhoneVerificationSession<T> extends ChangeNotifier {
  int _generation = 0;
  bool _signInStarted = false;
  bool _codeScreenOpen = false;
  bool _navigationClaimed = false;
  String? _verificationId;
  int? _resendToken;
  T? _pendingAuto;
  String? _pendingErrorCode;

  int get generation => _generation;

  String? get verificationId => _verificationId;

  int? get resendToken => _resendToken;

  bool get codeScreenOpen => _codeScreenOpen;

  bool get signInStarted => _signInStarted;

  String? get pendingErrorCode => _pendingErrorCode;

  bool isCurrent(int attempt) => attempt == _generation;

  int startAttempt() {
    _generation += 1;
    _signInStarted = false;
    _codeScreenOpen = false;
    _navigationClaimed = false;
    _verificationId = null;
    _resendToken = null;
    _pendingAuto = null;
    _pendingErrorCode = null;
    PhoneVerificationGate.codeEntryOpen.value = false;
    notifyListeners();
    return _generation;
  }

  PhoneAuthDecision codeSent(
    int attempt,
    String verificationId,
    int? resendToken,
  ) {
    if (!isCurrent(attempt) || verificationId.isEmpty) {
      return PhoneAuthDecision.ignore;
    }

    _verificationId = verificationId;
    _resendToken = resendToken;

    if (_signInStarted || _codeScreenOpen) {
      notifyListeners();
      return PhoneAuthDecision.ignore;
    }

    _codeScreenOpen = true;
    PhoneVerificationGate.codeEntryOpen.value = true;
    notifyListeners();
    return const PhoneAuthDecision(pushCodeScreen: true);
  }

  /// Auto-retrieval timed out. The SMS code remains usable.
  void autoTimeout(int attempt, String verificationId) {
    if (!isCurrent(attempt)) return;
    if (_verificationId == null && verificationId.isNotEmpty) {
      _verificationId = verificationId;
      notifyListeners();
    }
  }

  PhoneAuthDecision autoCredential(int attempt, T credential) {
    if (!isCurrent(attempt) || _signInStarted || _navigationClaimed) {
      return PhoneAuthDecision.ignore;
    }

    _signInStarted = true;
    if (_codeScreenOpen) {
      _pendingAuto = credential;
      notifyListeners();
    }
    return const PhoneAuthDecision(signIn: true);
  }

  T? takeAutoCredential(int attempt) {
    if (!isCurrent(attempt)) return null;
    final T? credential = _pendingAuto;
    _pendingAuto = null;
    return credential;
  }

  bool beginManualSignIn(int attempt) {
    if (!isCurrent(attempt) || _signInStarted || _navigationClaimed) {
      return false;
    }
    if (_verificationId == null || _verificationId!.isEmpty) return false;
    _signInStarted = true;
    notifyListeners();
    return true;
  }

  /// Returns false when a stale callback must not show an error.
  bool signInFailed(int attempt) {
    if (!isCurrent(attempt) || _navigationClaimed) return false;
    _signInStarted = false;
    notifyListeners();
    return true;
  }

  bool claimNavigation(int attempt) {
    if (!isCurrent(attempt) || _navigationClaimed) return false;
    _navigationClaimed = true;
    _pendingAuto = null;
    _pendingErrorCode = null;
    notifyListeners();
    return true;
  }

  void releaseNavigationClaim(int attempt) {
    if (!isCurrent(attempt)) return;
    _navigationClaimed = false;
    _signInStarted = false;
    notifyListeners();
  }

  /// Returns true when the phone-number screen should show [code].
  bool fail(int attempt, String code) {
    if (!isCurrent(attempt) || _signInStarted || _navigationClaimed) {
      return false;
    }
    _pendingErrorCode = code;
    notifyListeners();
    return !_codeScreenOpen;
  }

  void clearError() {
    if (_pendingErrorCode == null) return;
    _pendingErrorCode = null;
    notifyListeners();
  }

  /// Starts a resend. Returns 0 when the current attempt must stay.
  int beginResend(int attempt) {
    if (!isCurrent(attempt) || _signInStarted || _navigationClaimed) {
      return 0;
    }
    _generation += 1;
    _verificationId = null;
    _pendingAuto = null;
    _pendingErrorCode = null;
    _signInStarted = false;
    notifyListeners();
    return _generation;
  }

  void abandon() {
    _generation += 1;
    _signInStarted = false;
    _navigationClaimed = false;
    _pendingAuto = null;
    _pendingErrorCode = null;
    _verificationId = null;
    _resendToken = null;
    notifyListeners();
  }

  void releaseCodeGate() {
    _codeScreenOpen = false;
    PhoneVerificationGate.codeEntryOpen.value = false;
    notifyListeners();
  }
}
