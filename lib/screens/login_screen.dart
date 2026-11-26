import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../services/firebase_auth_language.dart';

import '../legal/legal_service.dart';
import '../legal/login_legal_consent.dart';
import '../services/language_controller.dart';
import '../services/phone_verification_session.dart';
import '../services/security_check_diagnostics.dart';

import 'create_profile_screen.dart';
import 'account_status_screen.dart';
import 'home_screen.dart';
import '../services/user_service.dart';
import 'verify_screen.dart';
import 'legal_document_screen.dart';
import 'legal_acceptance_screen.dart';
import 'support_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController phoneController = TextEditingController();

  bool loading = false;
  bool termsAccepted = false;
  bool ageDeclared = false;
  final PhoneVerificationSession<PhoneAuthCredential> _phoneSession =
      PhoneVerificationSession<PhoneAuthCredential>();

  String selectedCountryCode = "+90";

  _LoginText get text => _LoginText(LanguageController.language.value);

  List<Map<String, String>> get countries => <Map<String, String>>[
    <String, String>{"name": text.turkey, "flag": "🇹🇷", "code": "+90"},
    <String, String>{"name": text.germany, "flag": "🇩🇪", "code": "+49"},
    <String, String>{"name": text.netherlands, "flag": "🇳🇱", "code": "+31"},
    <String, String>{"name": text.france, "flag": "🇫🇷", "code": "+33"},
    <String, String>{"name": text.unitedKingdom, "flag": "🇬🇧", "code": "+44"},
    <String, String>{"name": text.unitedStates, "flag": "🇺🇸", "code": "+1"},
  ];

  bool get _allMandatoryAccepted => termsAccepted && ageDeclared;

  bool get canContinue {
    return phoneController.text.trim().isNotEmpty &&
        _allMandatoryAccepted &&
        !loading;
  }

  Future<void> sendCode() async {
    if (loading) {
      return;
    }

    if (!_allMandatoryAccepted) {
      _showMessage(text.acceptAgreementsWarning);
      return;
    }

    String rawPhone = phoneController.text
        .trim()
        .replaceAll(" ", "")
        .replaceAll("-", "")
        .replaceAll("(", "")
        .replaceAll(")", "");

    if (rawPhone.isEmpty) {
      _showMessage(text.enterPhone);
      return;
    }

    if (rawPhone.startsWith("+")) {
      if (rawPhone.startsWith(selectedCountryCode)) {
        rawPhone = rawPhone.substring(selectedCountryCode.length);
      } else {
        _showMessage(text.enterWithoutCountryCode);
        return;
      }
    }

    if (selectedCountryCode == "+90" && rawPhone.startsWith("0")) {
      rawPhone = rawPhone.substring(1);
    }

    if (!RegExp(r'^\d+$').hasMatch(rawPhone)) {
      _showMessage(text.phoneDigitsOnly);
      return;
    }

    if (selectedCountryCode == "+90" && rawPhone.length != 10) {
      _showMessage(text.turkeyPhoneLength);
      return;
    }

    if (rawPhone.length < 7 || rawPhone.length > 15) {
      _showMessage(text.validPhone);
      return;
    }

    final String phoneNumber = "$selectedCountryCode$rawPhone";
    final int attempt = _phoneSession.startAttempt();
    if (attempt == 0) {
      _showMessage(
        text.waitBeforeNewCode(_phoneSession.resendRemainingSeconds),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      loading = true;
    });

    try {
      await applyFirebaseAuthLanguage(
        FirebaseAuth.instance,
        Localizations.localeOf(context).languageCode,
      );
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await FirebaseAuth.instance.setSettings(forceRecaptchaFlow: false);
      }
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          final PhoneAuthDecision decision = _phoneSession.autoCredential(
            attempt,
            credential,
          );
          if (!decision.signIn || _phoneSession.codeScreenOpen) return;
          await _signInWithCredential(attempt, credential);
        },
        verificationFailed: (FirebaseAuthException error) {
          final bool showHere = _phoneSession.fail(attempt, error.code);
          if (!showHere || !mounted) return;

          setState(() {
            loading = false;
          });

          _showMessage(_authErrorMessage(error));
        },
        codeSent: (String verificationId, int? resendToken) {
          final PhoneAuthDecision decision = _phoneSession.codeSent(
            attempt,
            verificationId,
            resendToken,
          );
          if (!decision.pushCodeScreen || !mounted) return;

          setState(() {
            loading = false;
          });

          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => VerifyScreen(
                phoneNumber: phoneNumber,
                session: _phoneSession,
                attemptId: attempt,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _phoneSession.autoTimeout(attempt, verificationId);
          if (!mounted) return;
          setState(() {
            loading = false;
          });
        },
      );
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

      _showMessage(text.unexpectedError);
    }
  }

  Future<void> _signInWithCredential(
    int attempt,
    PhoneAuthCredential credential,
  ) async {
    try {
      final UserCredential result = await FirebaseAuth.instance
          .signInWithCredential(credential);
      final User? user = result.user ?? FirebaseAuth.instance.currentUser;
      if (user == null || !_phoneSession.isCurrent(attempt)) {
        _phoneSession.signInFailed(attempt);
        return;
      }
      await _routeAfterSignIn(user, attempt);
    } on FirebaseAuthException catch (error) {
      final User? existing = FirebaseAuth.instance.currentUser;
      if (existing != null && _phoneSession.isCurrent(attempt)) {
        await _routeAfterSignIn(existing, attempt);
        return;
      }
      if (!_phoneSession.signInFailed(attempt) || !mounted) return;
      setState(() {
        loading = false;
      });
      _showMessage(_authErrorMessage(error));
    }
  }

  Future<void> _routeAfterSignIn(User user, int attempt) async {
    if (!_phoneSession.claimNavigation(attempt)) return;
    String activeCallable = 'checkDeletedPhone';
    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('checkDeletedPhone');

      final HttpsCallableResult<dynamic> result = await callable
          .call<dynamic>();

      final Map<String, dynamic> data = Map<String, dynamic>.from(
        result.data as Map,
      );

      final bool blocked = data['blocked'] == true;

      if (!_phoneSession.isCurrent(attempt) || !mounted) return;

      if (blocked) {
        await FirebaseAuth.instance.signOut();

        if (!_phoneSession.isCurrent(attempt) || !mounted) return;

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

      var acceptanceFailed = false;
      try {
        await LegalService.recordOnboardingAcceptances(
          userId: user.uid,
          locale: LanguageController.locale.value.languageCode,
        );
      } catch (error) {
        acceptanceFailed = true;
        debugPrint('legal acceptance record failed: $error');
      }

      activeCallable = 'refreshAccountStatus';
      final AuthDestination destination = acceptanceFailed
          ? const AuthDestination(
              type: AuthDestinationType.legalAcceptanceRequired,
            )
          : await UserService.getAuthDestination(user: user);

      if (!_phoneSession.isCurrent(attempt) || !mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => _destinationScreen(destination),
        ),
        (route) => false,
      );
      _phoneSession.releaseCodeGate();
    } on FirebaseFunctionsException catch (error) {
      final SecurityCheckFailureDiagnostic diagnostic =
          buildSecurityCheckFailureDiagnostic(
            error,
            language: LanguageController.language.value,
            callableName: activeCallable,
          );
      debugPrint(diagnostic.logLine);

      _phoneSession.releaseNavigationClaim(attempt);
      await FirebaseAuth.instance.signOut();

      if (!_phoneSession.isCurrent(attempt) || !mounted) return;

      setState(() {
        loading = false;
      });

      _showMessage(diagnostic.userMessage);
    }
  }

  Widget _destinationScreen(AuthDestination destination) {
    switch (destination.type) {
      case AuthDestinationType.login:
        return const LoginScreen();
      case AuthDestinationType.createProfile:
        return const CreateProfileScreen();
      case AuthDestinationType.legalAcceptanceRequired:
        return const LegalAcceptanceScreen();
      case AuthDestinationType.home:
        return HomeScreen(userName: destination.profileName);
      case AuthDestinationType.suspended:
        return AccountStatusScreen(
          title: text.accountSuspended,
          message: text.accountSuspendedMessage,
          icon: Icons.pause_circle_outline,
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
      case AuthDestinationType.sessionExpired:
        return Scaffold(
          body: Center(
            child: Text(text.sessionEnded, textAlign: TextAlign.center),
          ),
        );
    }
  }

  String _authErrorMessage(FirebaseAuthException error) {
    switch (classifyPhoneAuthError(error.code)) {
      case PhoneAuthFailureKind.invalidPhone:
        return text.invalidPhone;
      case PhoneAuthFailureKind.tooManyRequests:
        return text.tooManyRequests;
      case PhoneAuthFailureKind.quotaExceeded:
        return text.quotaExceeded;
      case PhoneAuthFailureKind.network:
        return text.networkError;
      case PhoneAuthFailureKind.captcha:
        return text.captchaFailed;
      case PhoneAuthFailureKind.appNotAuthorized:
        return text.appNotAuthorized;
      case PhoneAuthFailureKind.operationNotAllowed:
        return text.operationNotAllowed;
      case PhoneAuthFailureKind.billingNotEnabled:
        return text.billingNotEnabled;
      case PhoneAuthFailureKind.missingClientIdentifier:
        return text.missingClientIdentifier;
      case PhoneAuthFailureKind.invalidCode:
      case PhoneAuthFailureKind.sessionExpired:
        return text.phoneVerificationError;
      case PhoneAuthFailureKind.generic:
        // Closed-test diagnostic. Firebase may report code=unknown while
        // the underlying cause is present only in the error message.
        // Avoid exposing phone numbers, OTPs, or bearer/API credentials.
        final String detail = (error.message ?? '')
            .replaceAll(RegExp(r'\+?\d[\d\s().-]{8,}\d'), '[number hidden]')
            .replaceAll(RegExp(r'\b\d{6}\b'), '[code hidden]')
            .replaceAll(
              RegExp(
                r'(token|api[_ -]?key|authorization)\s*[:=]\s*\S+',
                caseSensitive: false,
              ),
              '[credential hidden]',
            )
            .trim();
        final String shortDetail = detail.length > 240
            ? '${detail.substring(0, 240)}...'
            : detail;
        return '${text.phoneVerificationError} (${error.code})'
            '${shortDetail.isEmpty ? '' : '\n$shortDetail'}';
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showLegalDocument({
    required String title,
    required String documentCode,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            LegalDocumentScreen(documentCode: documentCode, title: title),
      ),
    );
  }

  String _selectedCountryLabel() {
    final Map<String, String> country = countries.firstWhere(
      (item) => item["code"] == selectedCountryCode,
    );

    return "${country["flag"]} ${country["code"]}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F1115),
      body: Stack(
        children: [
          SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    MediaQuery.of(context).viewInsets.bottom > 0 ? 24 : 100,
                    24,
                    24,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedScale(
                                scale:
                                    MediaQuery.of(context).viewInsets.bottom > 0
                                    ? 0.78
                                    : 1,
                                duration: const Duration(milliseconds: 180),
                                child: const _LoginBrandLogo(),
                              ),
                              SizedBox(
                                height:
                                    MediaQuery.of(context).viewInsets.bottom > 0
                                    ? 24
                                    : 74,
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 120,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: selectedCountryCode,
                                      isExpanded: true,
                                      dropdownColor: const Color(0xff23262D),
                                      iconEnabledColor: Colors.orange,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                      ),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color(0xff171A20),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 18,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      selectedItemBuilder: (context) {
                                        return countries.map((country) {
                                          return Align(
                                            alignment: Alignment.centerLeft,
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                country["code"] ==
                                                        selectedCountryCode
                                                    ? _selectedCountryLabel()
                                                    : "",
                                                maxLines: 1,
                                                softWrap: false,
                                              ),
                                            ),
                                          );
                                        }).toList();
                                      },
                                      items: countries.map((country) {
                                        return DropdownMenuItem<String>(
                                          value: country["code"],
                                          child: Text(
                                            "${country["flag"]} "
                                            "${country["name"]} "
                                            "${country["code"]}",
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: loading
                                          ? null
                                          : (String? value) {
                                              if (value == null) return;

                                              setState(() {
                                                selectedCountryCode = value;
                                              });
                                            },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: phoneController,
                                      enabled: !loading,
                                      keyboardType: TextInputType.phone,
                                      autofillHints: const <String>[
                                        AutofillHints.telephoneNumber,
                                      ],
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        _PhoneNumberFormatter(
                                          countryCode: selectedCountryCode,
                                        ),
                                      ],
                                      textInputAction: TextInputAction.done,
                                      onChanged: (_) {
                                        setState(() {});
                                      },
                                      onSubmitted: (_) {
                                        FocusScope.of(context).unfocus();

                                        if (canContinue) {
                                          sendCode();
                                        }
                                      },
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: selectedCountryCode == "+90"
                                            ? "555 555 55 55"
                                            : text.phoneNumber,
                                        hintStyle: const TextStyle(
                                          color: Colors.white38,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.phone_outlined,
                                          color: Colors.orange,
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xff171A20),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              LoginLegalConsent(
                                termsAccepted: termsAccepted,
                                ageDeclared: ageDeclared,
                                enabled: !loading,
                                language: LanguageController.language.value,
                                onTermsChanged: (bool value) {
                                  setState(() {
                                    termsAccepted = value;
                                  });
                                },
                                onAgeChanged: (bool value) {
                                  setState(() {
                                    ageDeclared = value;
                                  });
                                },
                                onOpenDocument: (String documentCode) {
                                  _showLegalDocument(
                                    title: text.documentTitle(documentCode),
                                    documentCode: documentCode,
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: canContinue ? sendCode : null,
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
                                          text.sendVerificationCode,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: OutlinedButton.icon(
                                  onPressed: loading
                                      ? null
                                      : () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => SupportHomeScreen(
                                                accountStatus: text.notLoggedIn,
                                              ),
                                            ),
                                          );
                                        },
                                  icon: const Icon(
                                    Icons.support_agent_outlined,
                                  ),
                                  label: Text(text.supportCenter),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orange,
                                    side: const BorderSide(
                                      color: Colors.orange,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                text.ageRequirement,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Positioned(top: 12, right: 20, child: _languageSelector()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _languageSelector() {
    final AppLanguage selectedLanguage = LanguageController.language.value;

    return PopupMenuButton<AppLanguage>(
      enabled: !loading,
      tooltip: text.language,
      color: const Color(0xff23262D),
      onSelected: (AppLanguage language) async {
        await LanguageController.setLanguage(language);
        if (!mounted) return;
        setState(() {});
      },
      itemBuilder: (BuildContext context) {
        return <PopupMenuEntry<AppLanguage>>[
          _languageMenuItem(
            language: AppLanguage.turkish,
            selectedLanguage: selectedLanguage,
            flag: '🇹🇷',
            label: 'Türkçe',
          ),
          _languageMenuItem(
            language: AppLanguage.english,
            selectedLanguage: selectedLanguage,
            flag: '🇬🇧',
            label: 'English',
          ),
          _languageMenuItem(
            language: AppLanguage.german,
            selectedLanguage: selectedLanguage,
            flag: '🇩🇪',
            label: 'Deutsch',
          ),
        ];
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xff171A20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.language, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text(
              _languageLabel(selectedLanguage),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white70,
              size: 19,
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<AppLanguage> _languageMenuItem({
    required AppLanguage language,
    required AppLanguage selectedLanguage,
    required String flag,
    required String label,
  }) {
    final bool selected = language == selectedLanguage;

    return PopupMenuItem<AppLanguage>(
      value: language,
      child: Row(
        children: <Widget>[
          Text(flag, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle, color: Colors.orange, size: 20),
        ],
      ),
    );
  }

  String _languageLabel(AppLanguage language) {
    switch (language) {
      case AppLanguage.turkish:
        return 'Türkçe';
      case AppLanguage.english:
        return 'English';
      case AppLanguage.german:
        return 'Deutsch';
    }
  }

  @override
  void dispose() {
    _phoneSession.dispose();
    phoneController.dispose();
    super.dispose();
  }
}

class _LoginBrandLogo extends StatelessWidget {
  const _LoginBrandLogo();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Dört',
      image: true,
      child: Image.asset(
        'assets/branding/dort_logo_white_orange.png',
        width: 250,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _PhoneNumberFormatter extends TextInputFormatter {
  const _PhoneNumberFormatter({required this.countryCode});

  final String countryCode;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (countryCode == '+90') {
      final String limited = digits.length > 10
          ? digits.substring(0, 10)
          : digits;

      final StringBuffer buffer = StringBuffer();

      for (int i = 0; i < limited.length; i++) {
        if (i == 3 || i == 6 || i == 8) {
          buffer.write(' ');
        }

        buffer.write(limited[i]);
      }

      final String formatted = buffer.toString();

      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    final String limited = digits.length > 15
        ? digits.substring(0, 15)
        : digits;

    return TextEditingValue(
      text: limited,
      selection: TextSelection.collapsed(offset: limited.length),
    );
  }
}

class _LoginText {
  const _LoginText(this.currentLanguage);

  final AppLanguage currentLanguage;

  String value({required String tr, required String en, required String de}) {
    switch (currentLanguage) {
      case AppLanguage.turkish:
        return tr;
      case AppLanguage.english:
        return en;
      case AppLanguage.german:
        return de;
    }
  }

  String waitBeforeNewCode(int seconds) => value(
    tr: 'Yeni kod istemeden önce $seconds saniye bekle.',
    en: 'Wait $seconds seconds before requesting another code.',
    de: 'Warte $seconds Sekunden, bevor du einen neuen Code anforderst.',
  );

  String get language => value(tr: 'Dil', en: 'Language', de: 'Sprache');
  String get slogan => value(
    tr: 'Oyunun eksik oyuncusunu bul',
    en: 'Find the missing player for your game',
    de: 'Finde den fehlenden Spieler für dein Spiel',
  );
  String get continueWithPhone => value(
    tr: 'Telefon numaran ile devam et',
    en: 'Continue with your phone number',
    de: 'Mit deiner Telefonnummer fortfahren',
  );
  String get phoneNumber =>
      value(tr: 'Telefon numarası', en: 'Phone number', de: 'Telefonnummer');
  String get kvkkTitle => value(
    tr: 'KVKK Aydınlatma Metni',
    en: 'Personal Data Notice',
    de: 'Datenschutzhinweis',
  );
  String get termsTitle => value(
    tr: 'Kullanım Koşulları',
    en: 'Terms of Use',
    de: 'Nutzungsbedingungen',
  );
  String get privacyTitle => value(
    tr: 'Gizlilik Politikası',
    en: 'Privacy Policy',
    de: 'Datenschutzerklärung',
  );
  String documentTitle(String documentCode) {
    switch (documentCode) {
      case 'kvkk_notice':
        return kvkkTitle;
      case 'privacy_policy':
        return privacyTitle;
      case 'terms_of_use':
        return termsTitle;
      case 'community_rules':
        return value(
          tr: 'Topluluk Kuralları',
          en: 'Community Rules',
          de: 'Community-Regeln',
        );
      case 'age_declaration':
        return value(
          tr: '18 yaş beyanı',
          en: 'Age declaration (18+)',
          de: 'Alterserklärung (18+)',
        );
      default:
        return documentCode;
    }
  }

  String get sendVerificationCode => value(
    tr: 'Onay Kodu Gönder',
    en: 'Send Verification Code',
    de: 'Bestätigungscode senden',
  );
  String get supportCenter =>
      value(tr: 'Destek Merkezi', en: 'Support Center', de: 'Support-Center');
  String get notLoggedIn =>
      value(tr: 'Giriş yapılmadı', en: 'Not signed in', de: 'Nicht angemeldet');
  String get ageRequirement => value(
    tr: 'Dört. uygulamasına yalnızca 18 yaşını doldurmuş kişiler kayıt olabilir.',
    en: 'Only people aged 18 or older may register for Dört.',
    de: 'Bei Dört. dürfen sich nur Personen ab 18 Jahren registrieren.',
  );

  String get turkey => value(tr: 'Türkiye', en: 'Türkiye', de: 'Türkei');
  String get germany => value(tr: 'Almanya', en: 'Germany', de: 'Deutschland');
  String get netherlands =>
      value(tr: 'Hollanda', en: 'Netherlands', de: 'Niederlande');
  String get france => value(tr: 'Fransa', en: 'France', de: 'Frankreich');
  String get unitedKingdom => value(
    tr: 'Birleşik Krallık',
    en: 'United Kingdom',
    de: 'Vereinigtes Königreich',
  );
  String get unitedStates =>
      value(tr: 'Amerika', en: 'United States', de: 'Vereinigte Staaten');

  String get acceptAgreementsWarning => value(
    tr: 'Devam etmek için her iki kutuyu da işaretle.',
    en: 'Check both boxes to continue.',
    de: 'Markiere beide Kästchen, um fortzufahren.',
  );
  String get enterPhone => value(
    tr: 'Telefon numaranı gir.',
    en: 'Enter your phone number.',
    de: 'Gib deine Telefonnummer ein.',
  );
  String get enterWithoutCountryCode => value(
    tr: 'Telefon numarasını ülke kodu olmadan gir.',
    en: 'Enter the phone number without the country code.',
    de: 'Gib die Telefonnummer ohne Ländervorwahl ein.',
  );
  String get phoneDigitsOnly => value(
    tr: 'Telefon numarası yalnızca rakamlardan oluşmalıdır.',
    en: 'The phone number must contain digits only.',
    de: 'Die Telefonnummer darf nur Ziffern enthalten.',
  );
  String get turkeyPhoneLength => value(
    tr: 'Türkiye için 10 haneli telefon numarası gir.',
    en: 'Enter a 10-digit phone number for Türkiye.',
    de: 'Gib für die Türkei eine 10-stellige Telefonnummer ein.',
  );
  String get validPhone => value(
    tr: 'Geçerli bir telefon numarası gir.',
    en: 'Enter a valid phone number.',
    de: 'Gib eine gültige Telefonnummer ein.',
  );
  String get unexpectedError => value(
    tr: 'Beklenmeyen bir hata oluştu. Tekrar dene.',
    en: 'An unexpected error occurred. Please try again.',
    de: 'Ein unerwarteter Fehler ist aufgetreten. Bitte versuche es erneut.',
  );

  String get accountSuspended => value(
    tr: 'Hesap Askıya Alındı',
    en: 'Account Suspended',
    de: 'Konto gesperrt',
  );
  String get accountSuspendedMessage => value(
    tr: 'Hesabın geçici olarak askıya alındı. İnceleme tamamlanana kadar uygulamayı kullanamazsın.',
    en: 'Your account has been temporarily suspended. You cannot use the app until the review is complete.',
    de: 'Dein Konto wurde vorübergehend gesperrt. Du kannst die App bis zum Abschluss der Prüfung nicht verwenden.',
  );
  String get accountBanned => value(
    tr: 'Hesap Engellendi',
    en: 'Account Banned',
    de: 'Konto dauerhaft gesperrt',
  );
  String get accountBannedMessage => value(
    tr: 'Hesabın kullanım kurallarının ihlali nedeniyle engellendi.',
    en: 'Your account has been banned for violating the terms of use.',
    de: 'Dein Konto wurde wegen eines Verstoßes gegen die Nutzungsregeln gesperrt.',
  );
  String get deletionPending => value(
    tr: 'Hesap Silme İşlemi Bekliyor',
    en: 'Account Deletion Pending',
    de: 'Kontolöschung ausstehend',
  );
  String get deletionPendingMessage => value(
    tr: 'Hesabın için silme talebi oluşturulmuş. İşlem tamamlanana kadar uygulamayı kullanamazsın.',
    en: 'A deletion request has been created for your account. You cannot use the app until the process is complete.',
    de: 'Für dein Konto wurde eine Löschanfrage erstellt. Du kannst die App bis zum Abschluss des Vorgangs nicht verwenden.',
  );
  String get accountDeleted =>
      value(tr: 'Hesap Silindi', en: 'Account Deleted', de: 'Konto gelöscht');
  String get accountDeletedMessage => value(
    tr: 'Bu hesap silinmiş ve artık kullanılamaz.',
    en: 'This account has been deleted and can no longer be used.',
    de: 'Dieses Konto wurde gelöscht und kann nicht mehr verwendet werden.',
  );
  String get sessionEnded => value(
    tr: 'Oturumunuz başka bir cihazda açıldığı için sonlandırıldı.',
    en: 'Your session was ended because your account was opened on another device.',
    de: 'Deine Sitzung wurde beendet, weil dein Konto auf einem anderen Gerät geöffnet wurde.',
  );

  String get invalidPhone => value(
    tr: 'Telefon numarası geçersiz. Ülke kodunu ve numarayı kontrol et.',
    en: 'The phone number is invalid. Check the country code and number.',
    de: 'Die Telefonnummer ist ungültig. Prüfe die Ländervorwahl und die Nummer.',
  );
  String get tooManyRequests => value(
    tr: 'Bu cihazdan kısa sürede çok fazla kod istendi. Güvenlik nedeniyle yeni istek geçici olarak durduruldu. Daha sonra tekrar dene.',
    en: 'Too many codes were requested from this device in a short time. Try again later.',
    de: 'Von diesem Gerät wurden in kurzer Zeit zu viele Codes angefordert. Versuche es später erneut.',
  );
  String get quotaExceeded => value(
    tr: 'SMS gönderim kotası doldu. Lütfen daha sonra tekrar dene.',
    en: 'The SMS sending quota has been reached. Please try again later.',
    de: 'Das SMS-Sendelimit wurde erreicht. Bitte versuche es später erneut.',
  );
  String get networkError => value(
    tr: 'İnternet bağlantını kontrol edip tekrar dene.',
    en: 'Check your internet connection and try again.',
    de: 'Prüfe deine Internetverbindung und versuche es erneut.',
  );
  String get captchaFailed => value(
    tr: 'Güvenlik doğrulaması tamamlanamadı. Tarayıcıyı kapatmadan doğrulamanın bitmesini bekleyip tekrar dene.',
    en: 'Security verification could not be completed. Keep the browser open until it finishes, then try again.',
    de: 'Die Sicherheitsprüfung konnte nicht abgeschlossen werden. Lass den Browser geöffnet und versuche es danach erneut.',
  );
  String get appNotAuthorized => value(
    tr: 'Uygulama doğrulanamadı. Uygulamanın güncel sürümünü kullanıp tekrar dene.',
    en: 'The app could not be verified. Use the latest version and try again.',
    de: 'Die App konnte nicht verifiziert werden. Verwende die neueste Version und versuche es erneut.',
  );
  String get operationNotAllowed => value(
    tr: 'Telefonla giriş şu anda kullanılamıyor.',
    en: 'Phone sign-in is currently unavailable.',
    de: 'Die Anmeldung per Telefon ist derzeit nicht verfügbar.',
  );
  String get billingNotEnabled => value(
    tr: 'Gerçek SMS gönderimi için Firebase faturalandırması etkin değil.',
    en: 'Firebase billing is not enabled for real SMS delivery.',
    de: 'Firebase-Abrechnung ist für den echten SMS-Versand nicht aktiviert.',
  );
  String get missingClientIdentifier => value(
    tr: 'Uygulama güvenlik kimliği doğrulanamadı.',
    en: 'The app security identifier could not be verified.',
    de: 'Die Sicherheitskennung der App konnte nicht verifiziert werden.',
  );
  String get phoneVerificationError => value(
    tr: 'Telefon doğrulaması sırasında bir hata oluştu.',
    en: 'An error occurred during phone verification.',
    de: 'Bei der Telefonverifizierung ist ein Fehler aufgetreten.',
  );
}
