import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../services/language_controller.dart';

import 'create_profile_screen.dart';
import 'account_status_screen.dart';
import 'home_screen.dart';
import '../services/user_service.dart';
import 'verify_screen.dart';
import 'support_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController phoneController = TextEditingController();

  bool loading = false;
  bool kvkkAccepted = false;
  bool termsAccepted = false;

  String selectedCountryCode = "+90";

  _LoginText get text => _LoginText(LanguageController.language.value);

  List<Map<String, String>> get countries => <Map<String, String>>[
    <String, String>{
      "name": text.turkey,
      "flag": "🇹🇷",
      "code": "+90",
    },
    <String, String>{
      "name": text.germany,
      "flag": "🇩🇪",
      "code": "+49",
    },
    <String, String>{
      "name": text.netherlands,
      "flag": "🇳🇱",
      "code": "+31",
    },
    <String, String>{
      "name": text.france,
      "flag": "🇫🇷",
      "code": "+33",
    },
    <String, String>{
      "name": text.unitedKingdom,
      "flag": "🇬🇧",
      "code": "+44",
    },
    <String, String>{
      "name": text.unitedStates,
      "flag": "🇺🇸",
      "code": "+1",
    },
  ];

  bool get canContinue {
    return phoneController.text.trim().isNotEmpty &&
        kvkkAccepted &&
        termsAccepted &&
        !loading;
  }

  Future<void> sendCode() async {
    if (loading) {
      return;
    }

    if (!kvkkAccepted || !termsAccepted) {
      _showMessage(
        text.acceptAgreementsWarning,
      );
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

    FocusScope.of(context).unfocus();

    setState(() {
      loading = true;
    });

    try {
      await FirebaseAuth.instance.setSettings(
        forceRecaptchaFlow: false,
      );
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final UserCredential result =
            await FirebaseAuth.instance.signInWithCredential(credential);
            final User? user = result.user;
            if (user == null || !mounted) {
              return;
            }
            await _routeAfterSignIn(user);
          } on FirebaseAuthException catch (error) {
            if (!mounted) return;
            setState(() {
              loading = false;
            });
            _showMessage(_authErrorMessage(error));
          }
        },
        verificationFailed: (FirebaseAuthException error) {
          debugPrint('========== TELEFON DOĞRULAMA HATASI ==========');
          debugPrint('Kod: ${error.code}');
          debugPrint('Mesaj: ${error.message}');
          debugPrint('Telefon: ${error.phoneNumber}');
          debugPrint('Plugin: ${error.plugin}');
          debugPrint('==============================================');

          if (!mounted) return;

          setState(() {
            loading = false;
          });

          _showMessage(
            '${_authErrorMessage(error)}\n\n'
                'Hata kodu: ${error.code}',
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;

          setState(() {
            loading = false;
          });

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VerifyScreen(
                phoneNumber: phoneNumber,
                verificationId: verificationId,
                resendToken: resendToken,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
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

Future<void> _routeAfterSignIn(User user) async {
  try {
    final HttpsCallable callable = FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    ).httpsCallable('checkDeletedPhone');

    final HttpsCallableResult<dynamic> result =
        await callable.call<dynamic>();

    final Map<String, dynamic> data =
        Map<String, dynamic>.from(result.data as Map);

    final bool blocked = data['blocked'] == true;

    if (blocked) {
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

    final AuthDestination destination =
        await UserService.getAuthDestination(user: user);

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => _destinationScreen(destination),
      ),
      (route) => false,
    );
  } on FirebaseFunctionsException catch (_) {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    setState(() {
      loading = false;
    });

    _showMessage(
      'Güvenlik kontrolü tamamlanamadı. Lütfen tekrar deneyin.',
    );
  }
}

  Widget _destinationScreen(AuthDestination destination) {
    switch (destination.type) {
      case AuthDestinationType.login:
        return const LoginScreen();
      case AuthDestinationType.createProfile:
        return const CreateProfileScreen();
      case AuthDestinationType.home:
        return HomeScreen(userName: destination.profileName);
      case AuthDestinationType.suspended:
        return AccountStatusScreen(
          title: text.accountSuspended,
          message:
          text.accountSuspendedMessage,
          icon: Icons.pause_circle_outline,
        );
      case AuthDestinationType.banned:
        return AccountStatusScreen(
          title: text.accountBanned,
          message:
          text.accountBannedMessage,
          icon: Icons.block,
        );
      case AuthDestinationType.deletionRequested:
        return AccountStatusScreen(
          title: text.deletionPending,
          message:
          text.deletionPendingMessage,
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
            child: Text(
              text.sessionEnded,
              textAlign: TextAlign.center,
            ),
          ),
        );
    }
  }


  String _authErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case "invalid-phone-number":
        return text.invalidPhone;
      case "too-many-requests":
        return text.tooManyRequests;
      case "quota-exceeded":
        return text.quotaExceeded;
      case "network-request-failed":
        return text.networkError;
      case "captcha-check-failed":
        return text.captchaFailed;
      case "app-not-authorized":
      case "invalid-app-credential":
        return text.appNotAuthorized;
      case "operation-not-allowed":
        return text.operationNotAllowed;
      case "billing-not-enabled":
        return text.billingNotEnabled;
      case "missing-client-identifier":
        return text.missingClientIdentifier;
      default:
        final String message = error.message?.trim() ?? "";
        return message.isNotEmpty
            ? message
            : text.phoneVerificationError;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  void _showLegalDocument({
    required String title,
    required String content,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff171A20),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.85,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: _languageSelector(),
                ),
                const SizedBox(height: 18),
                Container(
                  width: 45,
                  height: 5,
                  margin: const EdgeInsets.only(
                    top: 12,
                    bottom: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(
                  color: Colors.white12,
                  height: 1,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      content,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
                  padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height -
                          MediaQuery.of(context).padding.vertical -
                          48,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [

                        const _LoginBrandLogo(),
                        const SizedBox(height: 74),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 115,
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedCountryCode,
                                dropdownColor: const Color(0xff23262D),
                                iconEnabledColor: Colors.orange,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xff171A20),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 18,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                selectedItemBuilder: (context) {
                                  return countries.map((country) {
                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        country["code"] == selectedCountryCode
                                            ? _selectedCountryLabel()
                                            : "",
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
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _agreementRow(
                          value: kvkkAccepted,
                          onChanged: loading
                              ? null
                              : (bool? value) {
                            setState(() {
                              kvkkAccepted = value ?? false;
                            });
                          },
                          leadingText: "",
                          linkText: text.kvkkTitle,
                          trailingText: text.readAndAccept,
                          onLinkTap: () {
                            _showLegalDocument(
                              title: text.kvkkTitle,
                              content: text.kvkkText,
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        _agreementRow(
                          value: termsAccepted,
                          onChanged: loading
                              ? null
                              : (bool? value) {
                            setState(() {
                              termsAccepted = value ?? false;
                            });
                          },
                          leadingText: "",
                          linkText: text.termsTitle,
                          trailingText: text.readAndAccept,
                          onLinkTap: () {
                            _showLegalDocument(
                              title: text.termsTitle,
                              content: text.termsText,
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () {
                              _showLegalDocument(
                                title: text.privacyTitle,
                                content: text.privacyText,
                              );
                            },
                            child: Text(
                              text.viewPrivacyPolicy,
                              style: TextStyle(
                                color: Colors.orange,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.orange,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
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
                            icon: const Icon(Icons.support_agent_outlined),
                            label: Text(text.supportCenter),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
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
                ),

                Positioned(
                  top: 48,
                  right: 24,
                  child: _languageSelector(),
                ),
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

  Widget _agreementRow({
    required bool value,
    required ValueChanged<bool?>? onChanged,
    required String leadingText,
    required String linkText,
    required String trailingText,
    required VoidCallback onLinkTap,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 42,
          height: 42,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.orange,
            checkColor: Colors.black,
            side: const BorderSide(
              color: Colors.white54,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              children: [
                Text(
                  leadingText,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                GestureDetector(
                  onTap: onLinkTap,
                  child: Text(
                    linkText,
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.orange,
                    ),
                  ),
                ),
                Text(
                  trailingText,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }


  @override
  void dispose() {
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
  const _PhoneNumberFormatter({
    required this.countryCode,
  });

  final String countryCode;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String digits =
        newValue.text.replaceAll(RegExp(r'\D'), '');

    if (countryCode == '+90') {
      final String limited =
          digits.length > 10 ? digits.substring(0, 10) : digits;

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
        selection: TextSelection.collapsed(
          offset: formatted.length,
        ),
      );
    }

    final String limited =
        digits.length > 15 ? digits.substring(0, 15) : digits;

    return TextEditingValue(
      text: limited,
      selection: TextSelection.collapsed(
        offset: limited.length,
      ),
    );
  }
}
class _LoginText {
  const _LoginText(this.currentLanguage);

  final AppLanguage currentLanguage;

  String value({
    required String tr,
    required String en,
    required String de,
  }) {
    switch (currentLanguage) {
      case AppLanguage.turkish:
        return tr;
      case AppLanguage.english:
        return en;
      case AppLanguage.german:
        return de;
    }
  }

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
  String get readAndAccept => value(
    tr: ' metnini okudum ve kabul ediyorum.',
    en: ' — I have read and accept it.',
    de: ' — ich habe sie gelesen und akzeptiere sie.',
  );
  String get viewPrivacyPolicy => value(
    tr: 'Gizlilik Politikasını Görüntüle',
    en: 'View Privacy Policy',
    de: 'Datenschutzerklärung anzeigen',
  );
  String get sendVerificationCode => value(
    tr: 'Onay Kodu Gönder',
    en: 'Send Verification Code',
    de: 'Bestätigungscode senden',
  );
  String get supportCenter => value(
    tr: 'Destek Merkezi',
    en: 'Support Center',
    de: 'Support-Center',
  );
  String get notLoggedIn => value(
    tr: 'Giriş yapılmadı',
    en: 'Not signed in',
    de: 'Nicht angemeldet',
  );
  String get ageRequirement => value(
    tr: 'Dördüncü uygulamasına yalnızca 18 yaşını doldurmuş kişiler kayıt olabilir.',
    en: 'Only people aged 18 or older may register for Dördüncü.',
    de: 'Bei Dördüncü dürfen sich nur Personen ab 18 Jahren registrieren.',
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
  String get unitedStates => value(
    tr: 'Amerika',
    en: 'United States',
    de: 'Vereinigte Staaten',
  );

  String get acceptAgreementsWarning => value(
    tr: 'Devam etmek için KVKK metnini ve kullanım koşullarını kabul etmelisin.',
    en: 'You must accept the personal data notice and the terms of use to continue.',
    de: 'Du musst den Datenschutzhinweis und die Nutzungsbedingungen akzeptieren, um fortzufahren.',
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

  String get accountSuspended =>
      value(tr: 'Hesap Askıya Alındı', en: 'Account Suspended', de: 'Konto gesperrt');
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

  String get kvkkText => value(
    tr: 'KVKK AYDINLATMA METNİ\n\nBu alan geçici örnek metindir.\n\nDördüncü kapsamında telefon numarası, profil ve konum bilgileri üyelik, güvenlik ve hizmetlerin sunulması amacıyla işlenebilir.\n\nUygulama yayınlanmadan önce bu metin bir hukuk uzmanı tarafından hazırlanmalı ve onaylanmalıdır.',
    en: 'PERSONAL DATA NOTICE\n\nThis is temporary sample text.\n\nPhone numbers, profile details and location data may be processed for membership, security and service delivery.\n\nThis text must be prepared and approved by a legal professional before publication.',
    de: 'DATENSCHUTZHINWEIS\n\nDies ist ein vorläufiger Beispieltext.\n\nTelefonnummern, Profil- und Standortdaten können für Registrierung, Sicherheit und die Bereitstellung der Dienste verarbeitet werden.\n\nDieser Text muss vor der Veröffentlichung von einer juristischen Fachperson erstellt und genehmigt werden.',
  );
  String get termsText => value(
    tr: 'KULLANIM KOŞULLARI\n\nBu alan geçici örnek metindir.\n\nDördüncü uygulamasını kullanabilmek için 18 yaşını doldurmuş olmak gerekir. Taciz, tehdit, dolandırıcılık ve sahte profil oluşturma yasaktır.\n\nUygulama yayınlanmadan önce bu metin bir hukuk uzmanı tarafından hazırlanmalı ve onaylanmalıdır.',
    en: 'TERMS OF USE\n\nThis is temporary sample text.\n\nUsers must be at least 18 years old. Harassment, threats, fraud and fake profiles are prohibited.\n\nThis text must be prepared and approved by a legal professional before publication.',
    de: 'NUTZUNGSBEDINGUNGEN\n\nDies ist ein vorläufiger Beispieltext.\n\nNutzer müssen mindestens 18 Jahre alt sein. Belästigung, Drohungen, Betrug und gefälschte Profile sind verboten.\n\nDieser Text muss vor der Veröffentlichung von einer juristischen Fachperson erstellt und genehmigt werden.',
  );
  String get privacyText => value(
    tr: 'GİZLİLİK POLİTİKASI\n\nBu alan geçici örnek metindir.\n\nKullanıcı verileri yalnızca uygulamanın çalışması, güvenlik süreçleri ve hizmet kalitesinin geliştirilmesi için kullanılmalıdır.\n\nUygulama yayınlanmadan önce bu metin bir hukuk uzmanı tarafından hazırlanmalı ve onaylanmalıdır.',
    en: 'PRIVACY POLICY\n\nThis is temporary sample text.\n\nUser data should be used only to operate the app, manage security and improve service quality.\n\nThis text must be prepared and approved by a legal professional before publication.',
    de: 'DATENSCHUTZERKLÄRUNG\n\nDies ist ein vorläufiger Beispieltext.\n\nNutzerdaten dürfen nur für den Betrieb der App, Sicherheitsprozesse und die Verbesserung der Servicequalität verwendet werden.\n\nDieser Text muss vor der Veröffentlichung von einer juristischen Fachperson erstellt und genehmigt werden.',
  );
}
