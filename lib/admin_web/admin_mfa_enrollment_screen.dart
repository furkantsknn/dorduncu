import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firebase_auth_language.dart';

String _adminWebText(
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

class AdminMfaEnrollmentScreen extends StatefulWidget {
  const AdminMfaEnrollmentScreen({super.key});

  @override
  State<AdminMfaEnrollmentScreen> createState() => _State();
}

class _State extends State<AdminMfaEnrollmentScreen> {
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _code = TextEditingController();

  String? _verificationId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String authLanguage = Localizations.localeOf(context).languageCode;

    if (user == null || _phone.text.trim().isEmpty) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final MultiFactorSession session = await user.multiFactor.getSession();

      await applyFirebaseAuthLanguage(
        FirebaseAuth.instance,
        authLanguage,
      );
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _phone.text.trim(),
        multiFactorSession: session,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _enroll(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() {
              _busy = false;
              _error = e.message;
            });
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _busy = false;
            });
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  Future<void> _verify() async {
    final String? verificationId = _verificationId;
    final String code = _code.text.trim();

    if (verificationId == null || code.length < 6) {
      return;
    }

    final PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: code,
    );

    await _enroll(credential);
  }

  Future<void> _enroll(PhoneAuthCredential credential) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

      final MultiFactorAssertion assertion =
          PhoneMultiFactorGenerator.getAssertion(credential);

      await user.multiFactor.enroll(
        assertion,
        displayName: _adminWebText(
          context,
          tr: 'Dört. Yönetim SMS',
          en: 'Dört. Admin SMS',
          de: 'Dört. Admin-SMS',
        ),
      );

      await user.getIdToken(true);

      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool sent = _verificationId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _adminWebText(
            context,
            tr: 'İki Aşamalı Doğrulama',
            en: 'Two-Factor Authentication',
            de: 'Zwei-Faktor-Authentifizierung',
          ),
        ),
        actions: [
          IconButton(
            onPressed: FirebaseAuth.instance.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _adminWebText(
                      context,
                      tr: 'Yönetim paneli için SMS ikinci faktörü zorunludur.',
                      en: 'SMS as a second factor is required for the admin panel.',
                      de: 'SMS als zweiter Faktor ist für den Admin-Bereich erforderlich.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _phone,
                    enabled: !sent && !_busy,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefon (+90...)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (sent) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _code,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'SMS kodu',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : sent
                        ? _verify
                        : _send,
                    child: Text(
                      sent
                          ? _adminWebText(
                              context,
                              tr: 'Doğrula ve etkinleştir',
                              en: 'Verify and enable',
                              de: 'Bestätigen und aktivieren',
                            )
                          : _adminWebText(
                              context,
                              tr: 'SMS kodu gönder',
                              en: 'Send SMS code',
                              de: 'SMS-Code senden',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
