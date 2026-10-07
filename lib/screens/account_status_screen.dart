import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/session_service.dart';
import 'login_screen.dart';
import 'support_home_screen.dart';

String _accountStatusText(
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


class AccountStatusScreen extends StatefulWidget {
  const AccountStatusScreen({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  State<AccountStatusScreen> createState() => _AccountStatusScreenState();
}

class _AccountStatusScreenState extends State<AccountStatusScreen> {
  bool isLoggingOut = false;

  Future<void> _logout() async {
    if (isLoggingOut) return;

    setState(() => isLoggingOut = true);

    try {
      await SessionService.clearSession();
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => isLoggingOut = false);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _accountStatusText(context, tr: 'Oturum kapatılamadı. İnternet bağlantını kontrol edip tekrar dene.', en: 'Could not sign out. Check your internet connection and try again.', de: 'Abmeldung fehlgeschlagen. Prüfe deine Internetverbindung und versuche es erneut.'),
            ),
          ),
        );
    }
  }

  void _openSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupportHomeScreen(accountStatus: widget.title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xff0F1115),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.vertical -
                    48,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Icon(
                          widget.icon,
                          color: Colors.orange,
                          size: 58,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _accountStatusText(context, tr: 'Bu durumun hatalı olduğunu düşünüyorsan destek ekibimize talep gönderebilirsin.', en: 'If you think this status is incorrect, you can send a request to our support team.', de: 'Wenn du diesen Status für falsch hältst, kannst du eine Anfrage an unser Support-Team senden.'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: isLoggingOut ? null : _openSupport,
                          icon: const Icon(Icons.support_agent_outlined),
                          label: const Text('Destek Merkezi'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: const BorderSide(color: Colors.orange),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: isLoggingOut ? null : _logout,
                          icon: isLoggingOut
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2.5,
                            ),
                          )
                              : const Icon(Icons.logout),
                          label: Text(
                            isLoggingOut
                                ? _accountStatusText(context, tr: 'Oturum Kapatılıyor...', en: 'Signing out...', de: 'Abmeldung läuft...')
                                : 'Oturumu Kapat',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            disabledBackgroundColor:
                            Colors.orange.withValues(alpha: 0.55),
                            foregroundColor: Colors.black,
                            disabledForegroundColor: Colors.black54,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
