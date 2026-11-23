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

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  State<AdminLoginScreen> createState() => _State();
}

class _State extends State<AdminLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  MultiFactorResolver? _resolver;
  String? _verificationId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final String authLanguage = Localizations.localeOf(context).languageCode;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on FirebaseAuthMultiFactorException catch (e) {
      _resolver = e.resolver;
      final hints = e.resolver.hints;
      if (hints.isEmpty || hints.first is! PhoneMultiFactorInfo) {
        setState(() {
          _busy = false;
          _error = _adminWebText(
            context,
            tr: 'SMS ikinci faktörü bulunamadı.',
            en: 'SMS second factor was not found.',
            de: 'SMS als zweiter Faktor wurde nicht gefunden.',
          );
        });
        return;
      }
      await applyFirebaseAuthLanguage(
        FirebaseAuth.instance,
        authLanguage,
      );
      await FirebaseAuth.instance.verifyPhoneNumber(
        multiFactorSession: e.resolver.session,
        multiFactorInfo: hints.first as PhoneMultiFactorInfo,
        verificationCompleted: (c) => _resolve(c),
        verificationFailed: (x) {
          if (mounted) {
            setState(() {
              _busy = false;
              _error = x.message;
            });
          }
        },
        codeSent: (id, token) {
          if (mounted) {
            setState(() {
              _verificationId = id;
              _busy = false;
            });
          }
        },
        codeAutoRetrievalTimeout: (id) => _verificationId = id,
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
    final id = _verificationId;
    if (id == null) {
      return;
    }
    await _resolve(
      PhoneAuthProvider.credential(
        verificationId: id,
        smsCode: _code.text.trim(),
      ),
    );
  }

  Future<void> _resolve(PhoneAuthCredential credential) async {
    try {
      final resolver = _resolver;
      if (resolver == null) {
        return;
      }
      final assertion = PhoneMultiFactorGenerator.getAssertion(credential);
      await resolver.resolveSignIn(assertion);
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
    final bool mfa = _verificationId != null;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.admin_panel_settings_outlined, size: 54),
                  const SizedBox(height: 18),
                  Text(
                    _adminWebText(
                      context,
                      tr: 'Dört. Yönetim',
                      en: 'Dört. Admin',
                      de: 'Dört. Admin',
                    ),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  if (!mfa) ...[
                    TextField(
                      controller: _email,
                      decoration: InputDecoration(
                        labelText: 'E-posta',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: _adminWebText(
                          context,
                          tr: 'Şifre',
                          en: 'Password',
                          de: 'Passwort',
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else
                    TextField(
                      controller: _code,
                      decoration: InputDecoration(
                        labelText: 'SMS kodu',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : mfa
                        ? _verify
                        : _login,
                    child: Text(
                      mfa
                          ? _adminWebText(
                              context,
                              tr: 'Doğrula',
                              en: 'Verify',
                              de: 'Bestätigen',
                            )
                          : _adminWebText(
                              context,
                              tr: 'Giriş yap',
                              en: 'Sign in',
                              de: 'Anmelden',
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
