import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'create_profile_screen.dart';
import 'account_status_screen.dart';
import 'home_screen.dart';
import '../legal/legal_service.dart';
import '../services/language_controller.dart';
import '../services/user_service.dart';

class VerifyScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final int? resendToken;

  const VerifyScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    this.resendToken,
  });

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  _VerifyText get text => _VerifyText(LanguageController.language.value);

  final TextEditingController codeController = TextEditingController();

  bool loading = false;
  bool resending = false;
  int remainingSeconds = 60;
  Timer? countdownTimer;
  late String verificationId;
  int? resendToken;

  bool get canVerify {
    return !loading && !resending && codeController.text.trim().length == 6;
  }

  bool get canResend {
    return !loading && !resending && remainingSeconds == 0;
  }

  @override
  void initState() {
    super.initState();
    verificationId = widget.verificationId;
    resendToken = widget.resendToken;
    _startCountdown();
  }

  void _startCountdown() {
    countdownTimer?.cancel();
    setState(() {
      remainingSeconds = 60;
    });

    countdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          remainingSeconds = 0;
        });
      } else {
        setState(() {
          remainingSeconds--;
        });
      }
    });
  }

  Future<void> verifyCode() async {
    if (!canVerify) {
      return;
    }

    final String smsCode = codeController.text.trim();

    FocusScope.of(context).unfocus();

    setState(() {
      loading = true;
    });

    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      final User? user = userCredential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: "user-not-found",
          message: text.userSessionCouldNotBeCreated,
        );
      }

      await _routeAfterSignIn(user);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      _showMessage(_authErrorMessage(error));
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      _showMessage(text.unexpectedSignInError);
    }
  }

  Future<void> resendCode() async {
    if (!canResend) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      resending = true;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final UserCredential result = await FirebaseAuth.instance
                .signInWithCredential(credential);
            final User? user = result.user;
            if (user == null || !mounted) {
              return;
            }
            await _routeAfterSignIn(user);
          } on FirebaseAuthException catch (error) {
            if (!mounted) return;
            setState(() {
              resending = false;
            });
            _showMessage(_authErrorMessage(error));
          }
        },
        verificationFailed: (FirebaseAuthException error) {
          if (!mounted) return;

          setState(() {
            resending = false;
          });

          _showMessage(_authErrorMessage(error));
        },
        codeSent: (String newVerificationId, int? newResendToken) {
          if (!mounted) return;

          verificationId = newVerificationId;
          resendToken = newResendToken;
          codeController.clear();

          setState(() {
            resending = false;
          });

          _startCountdown();
          _showMessage(text.newCodeSent);
        },
        codeAutoRetrievalTimeout: (String newVerificationId) {
          verificationId = newVerificationId;
          if (!mounted) return;
          setState(() {
            resending = false;
          });
        },
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      setState(() {
        resending = false;
      });

      _showMessage(_authErrorMessage(error));
    } catch (_) {
      if (!mounted) return;

      setState(() {
        resending = false;
      });

      _showMessage(text.resendFailed);
    }
  }

  Future<void> _routeAfterSignIn(User user) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('checkDeletedPhone');

      final HttpsCallableResult<dynamic> result = await callable
          .call<dynamic>();

      final Map<String, dynamic> data = Map<String, dynamic>.from(
        result.data as Map,
      );

      if (data['blocked'] == true) {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AccountStatusScreen(
              title: text.accountDeleted,
              message: text.accountDeletedMessage,
              icon: Icons.person_off_outlined,
            ),
          ),
          (route) => false,
        );

        return;
      }

      await UserService.registerSuccessfulLogin(user);

      try {
        await LegalService.recordOnboardingAcceptances(
          userId: user.uid,
          locale: LanguageController.locale.value.languageCode,
        );
      } catch (error) {
        debugPrint('legal acceptance record failed: $error');
      }

      final AuthDestination destination = await UserService.getAuthDestination(
        user: user,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => _destinationScreen(destination),
        ),
        (route) => false,
      );
    } on FirebaseFunctionsException {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      setState(() {
        loading = false;
      });

      _showMessage('Güvenlik kontrolü tamamlanamadı. Lütfen tekrar deneyin.');
    }
  }

  Widget _destinationScreen(AuthDestination destination) {
    switch (destination.type) {
      case AuthDestinationType.login:
        return const CreateProfileScreen();
      case AuthDestinationType.createProfile:
        return const CreateProfileScreen();
      case AuthDestinationType.home:
        return HomeScreen(userName: destination.profileName);
      case AuthDestinationType.suspended:
        return AccountStatusScreen(
          title: text.accountSuspended,
          message: text.accountSuspendedMessage,
          icon: Icons.pause_circle_outline,
        );
      case AuthDestinationType.sessionExpired:
        return Scaffold(
          body: Center(
            child: Text(text.sessionEnded, textAlign: TextAlign.center),
          ),
        );
      case AuthDestinationType.banned:
        return AccountStatusScreen(
          title: text.accountBanned,
          message: text.accountBannedMessage,
          icon: Icons.block,
        );
      case AuthDestinationType.deletionRequested:
        return AccountStatusScreen(
          title: text.deletionPending,
          message: text.deletionPendingMessage,
          icon: Icons.hourglass_top,
        );
      case AuthDestinationType.deleted:
        return AccountStatusScreen(
          title: text.accountDeleted,
          message: text.accountDeletedMessage,
          icon: Icons.person_off_outlined,
        );
    }
  }

  String _authErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case "invalid-verification-code":
        return text.invalidVerificationCode;
      case "session-expired":
        return text.sessionExpired;
      case "too-many-requests":
        return text.tooManyRequests;
      case "quota-exceeded":
        return text.quotaExceeded;
      case "network-request-failed":
        return text.networkError;
      case "captcha-check-failed":
        return text.captchaFailed;
      case "invalid-app-credential":
      case "app-not-authorized":
        return text.appNotAuthorized;
      case "invalid-phone-number":
        return text.invalidPhoneNumber;
      default:
        final String message = error.message?.trim() ?? "";
        return message.isNotEmpty ? message : text.verificationFailed;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageController.language,
      builder:
          (BuildContext context, AppLanguage selectedLanguage, Widget? child) {
            final _VerifyText currentText = _VerifyText(selectedLanguage);

            return PopScope(
              canPop: !loading && !resending,
              child: Scaffold(
                backgroundColor: const Color(0xff0F1115),
                appBar: AppBar(
                  backgroundColor: const Color(0xff0F1115),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  title: Text(currentText.phoneVerification),
                ),
                body: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            MediaQuery.of(context).size.height -
                            MediaQuery.of(context).padding.vertical -
                            kToolbarHeight -
                            48,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.45),
                              ),
                            ),
                            child: const Icon(
                              Icons.sms_outlined,
                              color: Colors.orange,
                              size: 54,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            currentText.verificationCode,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            currentText.enterSixDigitCode(widget.phoneNumber),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 34),
                          TextField(
                            controller: codeController,
                            enabled: !loading && !resending,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            textAlign: TextAlign.center,
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            onChanged: (value) {
                              setState(() {});

                              if (value.trim().length == 6) {
                                FocusScope.of(context).unfocus();
                              }
                            },
                            onSubmitted: (_) {
                              if (canVerify) {
                                verifyCode();
                              }
                            },
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              letterSpacing: 10,
                            ),
                            decoration: InputDecoration(
                              hintText: "000000",
                              hintStyle: const TextStyle(color: Colors.white24),
                              counterText: "",
                              filled: true,
                              fillColor: const Color(0xff171A20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.white12,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.orange,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: canVerify ? verifyCode : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                disabledBackgroundColor: Colors.white12,
                                foregroundColor: Colors.black,
                                disabledForegroundColor: Colors.white38,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: loading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.black,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      currentText.verifyAndContinue,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (resending)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.orange,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  currentText.sendingNewCode,
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            )
                          else if (remainingSeconds > 0)
                            Text(
                              currentText.resendCountdown(remainingSeconds),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            )
                          else
                            TextButton.icon(
                              onPressed: canResend ? resendCode : null,
                              icon: const Icon(Icons.refresh),
                              label: Text(currentText.resendCode),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.orange,
                              ),
                            ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: loading || resending
                                ? null
                                : () {
                                    Navigator.pop(context);
                                  },
                            child: Text(
                              currentText.changePhoneNumber,
                              style: TextStyle(
                                color: Colors.white70,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.white70,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            currentText.retrySameCodeInformation,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
    );
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    codeController.dispose();
    super.dispose();
  }
}

class _VerifyText {
  const _VerifyText(this.currentLanguage);

  final AppLanguage currentLanguage;

  String _value({required String tr, required String en, required String de}) {
    switch (currentLanguage) {
      case AppLanguage.turkish:
        return tr;
      case AppLanguage.english:
        return en;
      case AppLanguage.german:
        return de;
    }
  }

  String get phoneVerification => _value(
    tr: 'Telefon Doğrulama',
    en: 'Phone Verification',
    de: 'Telefonverifizierung',
  );
  String get verificationCode => _value(
    tr: 'Doğrulama Kodu',
    en: 'Verification Code',
    de: 'Bestätigungscode',
  );

  String enterSixDigitCode(String phoneNumber) => _value(
    tr: '$phoneNumber numarasına gönderilen 6 haneli kodu gir.',
    en: 'Enter the 6-digit code sent to $phoneNumber.',
    de: 'Gib den 6-stelligen Code ein, der an $phoneNumber gesendet wurde.',
  );

  String get verifyAndContinue => _value(
    tr: 'Doğrula ve Devam Et',
    en: 'Verify and Continue',
    de: 'Bestätigen und fortfahren',
  );
  String get sendingNewCode => _value(
    tr: 'Yeni kod gönderiliyor...',
    en: 'Sending a new code...',
    de: 'Ein neuer Code wird gesendet...',
  );

  String resendCountdown(int seconds) => _value(
    tr: 'Yeni kodu $seconds saniye sonra isteyebilirsin.',
    en: 'You can request a new code in $seconds seconds.',
    de: 'Du kannst in $seconds Sekunden einen neuen Code anfordern.',
  );

  String get resendCode => _value(
    tr: 'Kodu Yeniden Gönder',
    en: 'Resend Code',
    de: 'Code erneut senden',
  );
  String get changePhoneNumber => _value(
    tr: 'Telefon Numarasını Değiştir',
    en: 'Change Phone Number',
    de: 'Telefonnummer ändern',
  );

  String get retrySameCodeInformation => _value(
    tr: 'Kod yanlışsa yeni SMS istemeden aynı kod alanında tekrar deneyebilirsin.',
    en: 'If the code is incorrect, you can try again in the same field without requesting a new SMS.',
    de: 'Wenn der Code falsch ist, kannst du ihn im selben Feld erneut eingeben, ohne eine neue SMS anzufordern.',
  );

  String get userSessionCouldNotBeCreated => _value(
    tr: 'Kullanıcı oturumu oluşturulamadı.',
    en: 'The user session could not be created.',
    de: 'Die Benutzersitzung konnte nicht erstellt werden.',
  );
  String get unexpectedSignInError => _value(
    tr: 'Giriş sırasında beklenmeyen bir hata oluştu.',
    en: 'An unexpected error occurred while signing in.',
    de: 'Bei der Anmeldung ist ein unerwarteter Fehler aufgetreten.',
  );
  String get newCodeSent => _value(
    tr: 'Yeni doğrulama kodu gönderildi.',
    en: 'A new verification code has been sent.',
    de: 'Ein neuer Bestätigungscode wurde gesendet.',
  );
  String get resendFailed => _value(
    tr: 'Kod yeniden gönderilemedi. Tekrar dene.',
    en: 'The code could not be resent. Please try again.',
    de: 'Der Code konnte nicht erneut gesendet werden. Bitte versuche es noch einmal.',
  );
  String get invalidVerificationCode => _value(
    tr: 'Girdiğin doğrulama kodu hatalı. Yeni kod istemeden tekrar deneyebilirsin.',
    en: 'The verification code you entered is incorrect. You can try again without requesting a new code.',
    de: 'Der eingegebene Bestätigungscode ist falsch. Du kannst es erneut versuchen, ohne einen neuen Code anzufordern.',
  );
  String get sessionExpired => _value(
    tr: 'Doğrulama oturumunun süresi doldu. Yeni kod iste.',
    en: 'The verification session has expired. Request a new code.',
    de: 'Die Verifizierungssitzung ist abgelaufen. Fordere einen neuen Code an.',
  );
  String get tooManyRequests => _value(
    tr: 'Bu cihazdan kısa sürede çok fazla işlem yapıldı. Güvenlik nedeniyle yeni istek geçici olarak durduruldu. Daha sonra tekrar dene.',
    en: 'Too many attempts were made from this device in a short time. New requests are temporarily blocked for security reasons. Try again later.',
    de: 'Von diesem Gerät wurden in kurzer Zeit zu viele Versuche unternommen. Neue Anfragen sind aus Sicherheitsgründen vorübergehend gesperrt. Versuche es später erneut.',
  );
  String get quotaExceeded => _value(
    tr: 'SMS gönderim kotası doldu. Lütfen daha sonra tekrar dene.',
    en: 'The SMS sending quota has been reached. Please try again later.',
    de: 'Das SMS-Sendelimit wurde erreicht. Bitte versuche es später erneut.',
  );
  String get networkError => _value(
    tr: 'İnternet bağlantını kontrol edip tekrar dene.',
    en: 'Check your internet connection and try again.',
    de: 'Prüfe deine Internetverbindung und versuche es erneut.',
  );
  String get captchaFailed => _value(
    tr: 'Güvenlik doğrulaması tamamlanamadı. Tekrar dene.',
    en: 'Security verification could not be completed. Please try again.',
    de: 'Die Sicherheitsprüfung konnte nicht abgeschlossen werden. Bitte versuche es erneut.',
  );
  String get appNotAuthorized => _value(
    tr: 'Uygulama doğrulanamadı. Güncel APK ile tekrar dene.',
    en: 'The app could not be verified. Try again with the latest APK.',
    de: 'Die App konnte nicht verifiziert werden. Versuche es mit der aktuellen APK erneut.',
  );
  String get invalidPhoneNumber => _value(
    tr: 'Telefon numarası geçersiz.',
    en: 'The phone number is invalid.',
    de: 'Die Telefonnummer ist ungültig.',
  );
  String get verificationFailed => _value(
    tr: 'Kod doğrulanamadı.',
    en: 'The code could not be verified.',
    de: 'Der Code konnte nicht bestätigt werden.',
  );
  String get accountSuspended => _value(
    tr: 'Hesap Askıya Alındı',
    en: 'Account Suspended',
    de: 'Konto gesperrt',
  );
  String get accountSuspendedMessage => _value(
    tr: 'Hesabın geçici olarak askıya alındı. İnceleme tamamlanana kadar uygulamayı kullanamazsın.',
    en: 'Your account has been temporarily suspended. You cannot use the app until the review is complete.',
    de: 'Dein Konto wurde vorübergehend gesperrt. Du kannst die App bis zum Abschluss der Prüfung nicht verwenden.',
  );
  String get sessionEnded => _value(
    tr: 'Oturumunuz başka bir cihazda açıldığı için sonlandırıldı.',
    en: 'Your session was ended because your account was opened on another device.',
    de: 'Deine Sitzung wurde beendet, weil dein Konto auf einem anderen Gerät geöffnet wurde.',
  );
  String get accountBanned => _value(
    tr: 'Hesap Engellendi',
    en: 'Account Banned',
    de: 'Konto dauerhaft gesperrt',
  );
  String get accountBannedMessage => _value(
    tr: 'Hesabın kullanım kurallarının ihlali nedeniyle engellendi.',
    en: 'Your account has been banned for violating the terms of use.',
    de: 'Dein Konto wurde wegen eines Verstoßes gegen die Nutzungsregeln gesperrt.',
  );
  String get deletionPending => _value(
    tr: 'Hesap Silme İşlemi Bekliyor',
    en: 'Account Deletion Pending',
    de: 'Kontolöschung ausstehend',
  );
  String get deletionPendingMessage => _value(
    tr: 'Hesabın için silme talebi oluşturulmuş. İşlem tamamlanana kadar uygulamayı kullanamazsın.',
    en: 'A deletion request has been created for your account. You cannot use the app until the process is complete.',
    de: 'Für dein Konto wurde eine Löschanfrage erstellt. Du kannst die App bis zum Abschluss des Vorgangs nicht verwenden.',
  );
  String get accountDeleted =>
      _value(tr: 'Hesap Silindi', en: 'Account Deleted', de: 'Konto gelöscht');
  String get accountDeletedMessage => _value(
    tr: 'Bu hesap silinmiş ve artık kullanılamaz.',
    en: 'This account has been deleted and can no longer be used.',
    de: 'Dieses Konto wurde gelöscht und kann nicht mehr verwendet werden.',
  );
}
