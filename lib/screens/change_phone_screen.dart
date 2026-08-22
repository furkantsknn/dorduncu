import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String _changePhoneText(
    BuildContext context, {
      required String tr,
      required String en,
      required String de,
    }) {
  switch (Localizations.localeOf(context).languageCode.toLowerCase()) {
    case 'en':
      return en;
    case 'de':
      return de;
    default:
      return tr;
  }
}

class ChangePhoneScreen extends StatefulWidget {
  const ChangePhoneScreen({super.key});

  @override
  State<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends State<ChangePhoneScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _selectedCountryCode = '+90';
  String? _verificationId;
  int? _resendToken;

  bool _sendingCode = false;
  bool _verifyingCode = false;
  bool _codeSent = false;

  int _remainingSeconds = 0;
  Timer? _timer;

  static const int _resendWaitSeconds = 60;

  final List<_CountryOption> _countries = const <_CountryOption>[
    _CountryOption(name: 'Türkiye', flag: '🇹🇷', code: '+90'),
    _CountryOption(name: 'Almanya', flag: '🇩🇪', code: '+49'),
    _CountryOption(name: 'Hollanda', flag: '🇳🇱', code: '+31'),
    _CountryOption(name: 'Fransa', flag: '🇫🇷', code: '+33'),
    _CountryOption(name: 'Birleşik Krallık', flag: '🇬🇧', code: '+44'),
    _CountryOption(name: 'Amerika', flag: '🇺🇸', code: '+1'),
  ];

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  User get _requiredUser {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw _ChangePhoneException(
        _changePhoneText(
          context,
          tr: 'Telefon numaranı değiştirmek için giriş yapmalısın.',
          en: 'You must sign in to change your phone number.',
          de: 'Du musst angemeldet sein, um deine Telefonnummer zu ändern.',
        ),
      );
    }

    return user;
  }

  String _normalizedPhoneNumber() {
    String value = _phoneController.text
        .trim()
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .replaceAll('(', '')
        .replaceAll(')', '');

    if (value.startsWith('+')) {
      if (!value.startsWith(_selectedCountryCode)) {
        throw _ChangePhoneException(
          _changePhoneText(
            context,
            tr: 'Telefon numarasını ülke kodu olmadan gir.',
            en: 'Enter the phone number without the country code.',
            de: 'Gib die Telefonnummer ohne Ländervorwahl ein.',
          ),
        );
      }

      value = value.substring(_selectedCountryCode.length);
    }

    if (_selectedCountryCode == '+90' && value.startsWith('0')) {
      value = value.substring(1);
    }

    if (value.isEmpty) {
      throw _ChangePhoneException(
        _changePhoneText(
          context,
          tr: 'Yeni telefon numaranı gir.',
          en: 'Enter your new phone number.',
          de: 'Gib deine neue Telefonnummer ein.',
        ),
      );
    }

    if (!RegExp(r'^\d+$').hasMatch(value)) {
      throw _ChangePhoneException(
        _changePhoneText(
          context,
          tr: 'Telefon numarası yalnızca rakamlardan oluşmalıdır.',
          en: 'The phone number must contain digits only.',
          de: 'Die Telefonnummer darf nur aus Ziffern bestehen.',
        ),
      );
    }

    if (_selectedCountryCode == '+90' && value.length != 10) {
      throw _ChangePhoneException(
        _changePhoneText(
          context,
          tr: 'Türkiye için 10 haneli telefon numarası gir.',
          en: 'Enter a 10-digit phone number for Türkiye.',
          de: 'Gib für die Türkei eine 10-stellige Telefonnummer ein.',
        ),
      );
    }

    final String fullNumber = '$_selectedCountryCode$value';

    if (fullNumber.length < 8 || fullNumber.length > 16) {
      throw _ChangePhoneException(
        _changePhoneText(
          context,
          tr: 'Geçerli bir telefon numarası gir.',
          en: 'Enter a valid phone number.',
          de: 'Gib eine gültige Telefonnummer ein.',
        ),
      );
    }

    return fullNumber;
  }

  void _startTimer() {
    _timer?.cancel();

    setState(() {
      _remainingSeconds = _resendWaitSeconds;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
        });
        return;
      }

      setState(() {
        _remainingSeconds--;
      });
    });
  }

  Future<void> _sendCode({bool forceResend = false}) async {
    if (_sendingCode || _verifyingCode) {
      return;
    }

    if (forceResend && _remainingSeconds > 0) {
      return;
    }

    try {
      final User user = _requiredUser;
      final String phoneNumber = _normalizedPhoneNumber();
      final String currentPhone = user.phoneNumber?.trim() ?? '';

      if (phoneNumber == currentPhone) {
        throw _ChangePhoneException(
          _changePhoneText(
            context,
            tr: 'Yeni telefon numarası mevcut numaranla aynı olamaz.',
            en: 'The new phone number cannot be the same as your current number.',
            de: 'Die neue Telefonnummer darf nicht mit deiner aktuellen Nummer übereinstimmen.',
          ),
        );
      }

      setState(() {
        _sendingCode = true;
      });

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: forceResend ? _resendToken : null,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (!mounted) {
            return;
          }

          await _completePhoneChange(
            credential: credential,
            newPhoneNumber: phoneNumber,
          );
        },
        verificationFailed: (FirebaseAuthException error) {
          _logFirebaseAuthError(
            stage: 'verifyPhoneNumber.verificationFailed',
            error: error,
          );

          if (!mounted) {
            return;
          }

          setState(() {
            _sendingCode = false;
          });

          _showMessage(_firebaseDiagnosticMessage(error));
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) {
            return;
          }

          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _codeSent = true;
            _sendingCode = false;
            _codeController.clear();
          });

          _startTimer();
          _showMessage(
            _changePhoneText(
              context,
              tr: 'Doğrulama kodu yeni telefon numarana gönderildi.',
              en: 'The verification code was sent to your new phone number.',
              de: 'Der Bestätigungscode wurde an deine neue Telefonnummer gesendet.',
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!mounted) {
            return;
          }

          setState(() {
            _verificationId = verificationId;
            _sendingCode = false;
          });
        },
      );
    } on _ChangePhoneException catch (error) {
      _showMessage(error.message);
    } on FirebaseAuthException catch (error) {
      _logFirebaseAuthError(
        stage: '_completePhoneChange',
        error: error,
      );

      if (!mounted) return;

      _showMessage(_firebaseDiagnosticMessage(error));
    } catch (error, stackTrace) {
      debugPrint('ChangePhoneScreen _sendCode beklenmeyen hata: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      _showMessage(
        _changePhoneText(
          context,
          tr: 'Beklenmeyen hata: ${error.runtimeType}\n$error',
          en: 'Unexpected error: ${error.runtimeType}\n$error',
          de: 'Unerwarteter Fehler: ${error.runtimeType}\n$error',
        ),
      );
    } finally {
      if (mounted && _sendingCode && !_codeSent) {
        setState(() {
          _sendingCode = false;
        });
      }
    }
  }

  Future<void> _verifyCode() async {
    if (_verifyingCode || _sendingCode) {
      return;
    }

    final String verificationId = _verificationId?.trim() ?? '';
    final String smsCode = _codeController.text.trim();

    if (verificationId.isEmpty) {
      _showMessage(
        _changePhoneText(
          context,
          tr: 'Önce yeni telefon numarana doğrulama kodu gönder.',
          en: 'Send a verification code to your new phone number first.',
          de: 'Sende zuerst einen Bestätigungscode an deine neue Telefonnummer.',
        ),
      );
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(smsCode)) {
      _showMessage(
        _changePhoneText(
          context,
          tr: '6 haneli doğrulama kodunu gir.',
          en: 'Enter the 6-digit verification code.',
          de: 'Gib den 6-stelligen Bestätigungscode ein.',
        ),
      );
      return;
    }

    try {
      final String newPhoneNumber = _normalizedPhoneNumber();

      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      await _completePhoneChange(
        credential: credential,
        newPhoneNumber: newPhoneNumber,
      );
    } on _ChangePhoneException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _completePhoneChange({
    required PhoneAuthCredential credential,
    required String newPhoneNumber,
  }) async {
    if (_verifyingCode) {
      return;
    }

    setState(() {
      _verifyingCode = true;
    });

    try {
      final User user = _requiredUser;

      await user.updatePhoneNumber(credential);
      await user.reload();

      await _firestore.collection('users').doc(user.uid).set(
        <String, dynamic>{
          'telefon': newPhoneNumber,
          'phoneNumber': newPhoneNumber,
          'phoneChangedAt': FieldValue.serverTimestamp(),
          'guncellemeTarihi': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) {
        return;
      }

      _timer?.cancel();

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.verified_outlined,
              size: 52,
              color: Colors.green,
            ),
            title: Text(
              _changePhoneText(
                dialogContext,
                tr: 'Telefon numarası değiştirildi',
                en: 'Phone number changed',
                de: 'Telefonnummer geändert',
              ),
            ),
            content: Text(
              _changePhoneText(
                dialogContext,
                tr: 'Hesabının telefon numarası $newPhoneNumber olarak güncellendi.',
                en: 'Your account phone number has been updated to $newPhoneNumber.',
                de: 'Die Telefonnummer deines Kontos wurde auf $newPhoneNumber aktualisiert.',
              ),
              textAlign: TextAlign.center,
            ),
            actions: <Widget>[
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  _changePhoneText(
                    dialogContext,
                    tr: 'Tamam',
                    en: 'OK',
                    de: 'OK',
                  ),
                ),
              ),
            ],
          );
        },
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } on FirebaseAuthException catch (error) {
      _logFirebaseAuthError(
        stage: '_completePhoneChange',
        error: error,
      );
      _showMessage(_firebaseDiagnosticMessage(error));
    } on FirebaseException catch (error) {
      if (!mounted) return;

      _showMessage(
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : _changePhoneText(
          context,
          tr: 'Telefon numarası profil bilgilerine kaydedilemedi.',
          en: 'The phone number could not be saved to your profile.',
          de: 'Die Telefonnummer konnte nicht in deinem Profil gespeichert werden.',
        ),
      );
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        _changePhoneText(
          context,
          tr: 'Telefon numarası değiştirilemedi.',
          en: 'The phone number could not be changed.',
          de: 'Die Telefonnummer konnte nicht geändert werden.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _verifyingCode = false;
        });
      }
    }
  }

  void _changeNumber() {
    if (_sendingCode || _verifyingCode) {
      return;
    }

    _timer?.cancel();

    setState(() {
      _codeSent = false;
      _verificationId = null;
      _resendToken = null;
      _remainingSeconds = 0;
      _codeController.clear();
    });
  }


  void _logFirebaseAuthError({
    required String stage,
    required FirebaseAuthException error,
  }) {
    debugPrint('========== FIREBASE AUTH HATASI ==========');
    debugPrint('Aşama: $stage');
    debugPrint('Kod: ${error.code}');
    debugPrint('Mesaj: ${error.message}');
    debugPrint('Plugin: ${error.plugin}');
    debugPrint('Telefon: ${error.phoneNumber}');
    debugPrint('E-posta: ${error.email}');
    debugPrint('==========================================');
  }

  String _firebaseDiagnosticMessage(FirebaseAuthException error) {
    final String rawMessage = error.message?.trim() ?? '';
    final String friendlyMessage = _firebaseErrorMessage(error);

    return _changePhoneText(
      context,
      tr: 'Firebase hata kodu: ${error.code}\n'
          'Firebase mesajı: ${rawMessage.isEmpty ? "Mesaj bulunamadı" : rawMessage}\n\n'
          '$friendlyMessage',
      en: 'Firebase error code: ${error.code}\n'
          'Firebase message: ${rawMessage.isEmpty ? "No message available" : rawMessage}\n\n'
          '$friendlyMessage',
      de: 'Firebase-Fehlercode: ${error.code}\n'
          'Firebase-Nachricht: ${rawMessage.isEmpty ? "Keine Nachricht verfügbar" : rawMessage}\n\n'
          '$friendlyMessage',
    );
  }

  String _firebaseErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-phone-number':
        return _changePhoneText(
          context,
          tr: 'Telefon numarası geçersiz.',
          en: 'The phone number is invalid.',
          de: 'Die Telefonnummer ist ungültig.',
        );
      case 'invalid-verification-code':
        return _changePhoneText(
          context,
          tr: 'Doğrulama kodu yanlış.',
          en: 'The verification code is incorrect.',
          de: 'Der Bestätigungscode ist falsch.',
        );
      case 'session-expired':
      case 'code-expired':
        return _changePhoneText(
          context,
          tr: 'Doğrulama kodunun süresi doldu. Yeni kod iste.',
          en: 'The verification code has expired. Request a new code.',
          de: 'Der Bestätigungscode ist abgelaufen. Fordere einen neuen Code an.',
        );
      case 'credential-already-in-use':
      case 'phone-number-already-exists':
        return _changePhoneText(
          context,
          tr: 'Bu telefon numarası başka bir hesap tarafından kullanılıyor.',
          en: 'This phone number is already used by another account.',
          de: 'Diese Telefonnummer wird bereits von einem anderen Konto verwendet.',
        );
      case 'too-many-requests':
        return _changePhoneText(
          context,
          tr: 'Çok fazla deneme yapıldı. Bir süre bekleyip tekrar dene.',
          en: 'Too many attempts were made. Wait a while and try again.',
          de: 'Es wurden zu viele Versuche unternommen. Warte eine Weile und versuche es erneut.',
        );
      case 'quota-exceeded':
        return _changePhoneText(
          context,
          tr: 'SMS gönderim kotası doldu. Daha sonra tekrar dene.',
          en: 'The SMS sending quota has been reached. Try again later.',
          de: 'Das SMS-Sendekontingent ist erreicht. Versuche es später erneut.',
        );
      case 'network-request-failed':
        return _changePhoneText(
          context,
          tr: 'İnternet bağlantını kontrol edip tekrar dene.',
          en: 'Check your internet connection and try again.',
          de: 'Überprüfe deine Internetverbindung und versuche es erneut.',
        );
      case 'captcha-check-failed':
        return _changePhoneText(
          context,
          tr: 'Güvenlik doğrulaması tamamlanamadı. Tekrar dene.',
          en: 'Security verification could not be completed. Try again.',
          de: 'Die Sicherheitsprüfung konnte nicht abgeschlossen werden. Versuche es erneut.',
        );
      case 'requires-recent-login':
        return _changePhoneText(
          context,
          tr: 'Güvenlik nedeniyle önce çıkış yapıp mevcut telefon numaranla tekrar giriş yapmalısın.',
          en: 'For security, sign out and sign in again with your current phone number.',
          de: 'Melde dich aus Sicherheitsgründen ab und mit deiner aktuellen Telefonnummer erneut an.',
        );
      case 'user-disabled':
        return _changePhoneText(
          context,
          tr: 'Bu hesap devre dışı bırakılmış.',
          en: 'This account has been disabled.',
          de: 'Dieses Konto wurde deaktiviert.',
        );
      case 'user-not-found':
        return _changePhoneText(
          context,
          tr: 'Kullanıcı hesabı bulunamadı.',
          en: 'The user account could not be found.',
          de: 'Das Benutzerkonto wurde nicht gefunden.',
        );
      default:
        final String message = error.message?.trim() ?? '';
        return message.isNotEmpty
            ? message
            : _changePhoneText(
          context,
          tr: 'Telefon numarası değiştirilemedi.',
          en: 'The phone number could not be changed.',
          de: 'Die Telefonnummer konnte nicht geändert werden.',
        );
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;
    final String currentPhone = user?.phoneNumber?.trim().isNotEmpty == true
        ? user!.phoneNumber!.trim()
        : _changePhoneText(
      context,
      tr: 'Telefon numarası bulunamadı',
      en: 'Phone number not found',
      de: 'Telefonnummer nicht gefunden',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _changePhoneText(
            context,
            tr: 'Telefon Numarasını Değiştir',
            en: 'Change Phone Number',
            de: 'Telefonnummer ändern',
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: <Widget>[
            Icon(
              Icons.phone_android_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            Text(
              _changePhoneText(
                context,
                tr: 'Yeni numaranı doğrula',
                en: 'Verify your new number',
                de: 'Bestätige deine neue Nummer',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _changePhoneText(
                context,
                tr: 'Yeni telefon numarana SMS kodu göndereceğiz. Kod doğrulandığında giriş numaran değiştirilecek.',
                en: 'We will send an SMS code to your new phone number. Once verified, your sign-in number will be changed.',
                de: 'Wir senden einen SMS-Code an deine neue Telefonnummer. Nach der Bestätigung wird deine Anmeldenummer geändert.',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.phone_in_talk_outlined),
                title: Text(
                  _changePhoneText(
                    context,
                    tr: 'Mevcut telefon numarası',
                    en: 'Current phone number',
                    de: 'Aktuelle Telefonnummer',
                  ),
                ),
                subtitle: Text(currentPhone),
              ),
            ),
            const SizedBox(height: 18),
            if (!_codeSent) ...<Widget>[
              DropdownButtonFormField<String>(
                initialValue: _selectedCountryCode,
                decoration: InputDecoration(
                  labelText: _changePhoneText(
                    context,
                    tr: 'Ülke',
                    en: 'Country',
                    de: 'Land',
                  ),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.public_outlined),
                ),
                items: _countries.map((_CountryOption country) {
                  return DropdownMenuItem<String>(
                    value: country.code,
                    child: Text(
                      '${country.flag}  ${country.name} (${country.code})',
                    ),
                  );
                }).toList(growable: false),
                onChanged: _sendingCode
                    ? null
                    : (String? value) {
                  if (value != null) {
                    setState(() {
                      _selectedCountryCode = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _phoneController,
                enabled: !_sendingCode,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9\s\-\(\)]'),
                  ),
                  LengthLimitingTextInputFormatter(20),
                ],
                decoration: InputDecoration(
                  labelText: _changePhoneText(
                    context,
                    tr: 'Yeni telefon numarası',
                    en: 'New phone number',
                    de: 'Neue Telefonnummer',
                  ),
                  hintText: _selectedCountryCode == '+90'
                      ? '5XX XXX XX XX'
                      : _changePhoneText(
                    context,
                    tr: 'Telefon numarası',
                    en: 'Phone number',
                    de: 'Telefonnummer',
                  ),
                  prefixText: '$_selectedCountryCode ',
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _sendCode(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _sendingCode ? null : () => _sendCode(),
                  icon: _sendingCode
                      ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.sms_outlined),
                  label: Text(
                    _sendingCode
                        ? _changePhoneText(
                      context,
                      tr: 'Kod gönderiliyor...',
                      en: 'Sending code...',
                      de: 'Code wird gesendet...',
                    )
                        : _changePhoneText(
                      context,
                      tr: 'Kod Gönder',
                      en: 'Send Code',
                      de: 'Code senden',
                    ),
                  ),
                ),
              ),
            ] else ...<Widget>[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: Text(
                    _changePhoneText(
                      context,
                      tr: 'Kod gönderilen numara',
                      en: 'Number the code was sent to',
                      de: 'Nummer, an die der Code gesendet wurde',
                    ),
                  ),
                  subtitle: Text(_normalizedPhoneNumber()),
                  trailing: TextButton(
                    onPressed: _changeNumber,
                    child: Text(
                      _changePhoneText(
                        context,
                        tr: 'Değiştir',
                        en: 'Change',
                        de: 'Ändern',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _codeController,
                enabled: !_verifyingCode,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                maxLength: 6,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  labelText: _changePhoneText(
                    context,
                    tr: '6 haneli doğrulama kodu',
                    en: '6-digit verification code',
                    de: '6-stelliger Bestätigungscode',
                  ),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.password_outlined),
                  counterText: '',
                ),
                onSubmitted: (_) => _verifyCode(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _verifyingCode ? null : _verifyCode,
                  icon: _verifyingCode
                      ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.verified_outlined),
                  label: Text(
                    _verifyingCode
                        ? _changePhoneText(
                      context,
                      tr: 'Doğrulanıyor...',
                      en: 'Verifying...',
                      de: 'Wird bestätigt...',
                    )
                        : _changePhoneText(
                      context,
                      tr: 'Numarayı Değiştir',
                      en: 'Change Number',
                      de: 'Nummer ändern',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _remainingSeconds == 0 &&
                    !_sendingCode &&
                    !_verifyingCode
                    ? () => _sendCode(forceResend: true)
                    : null,
                child: Text(
                  _remainingSeconds > 0
                      ? _changePhoneText(
                    context,
                    tr: 'Tekrar gönder ($_remainingSeconds sn)',
                    en: 'Resend ($_remainingSeconds sec)',
                    de: 'Erneut senden ($_remainingSeconds Sek.)',
                  )
                      : _sendingCode
                      ? _changePhoneText(
                    context,
                    tr: 'Kod gönderiliyor...',
                    en: 'Sending code...',
                    de: 'Code wird gesendet...',
                  )
                      : _changePhoneText(
                    context,
                    tr: 'Kodu tekrar gönder',
                    en: 'Resend code',
                    de: 'Code erneut senden',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.security_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _changePhoneText(
                          context,
                          tr: 'Güvenliğin için SMS doğrulama kodunu hiç kimseyle paylaşma. Destek ekibi bu kodu senden istemez.',
                          en: 'For your security, never share the SMS verification code with anyone. The support team will never ask you for this code.',
                          de: 'Teile den SMS-Bestätigungscode zu deiner Sicherheit niemals mit anderen. Das Support-Team wird dich nie nach diesem Code fragen.',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryOption {
  const _CountryOption({
    required this.name,
    required this.flag,
    required this.code,
  });

  final String name;
  final String flag;
  final String code;
}

class _ChangePhoneException implements Exception {
  const _ChangePhoneException(this.message);

  final String message;
}
