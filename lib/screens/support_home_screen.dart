import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'account_recovery_screen.dart';
import 'contact_us_screen.dart';
import 'faq_screen.dart';
import 'support_requests_screen.dart';
import 'support_screen.dart';

class SupportHomeScreen extends StatelessWidget {
  const SupportHomeScreen({
    super.key,
    this.accountStatus = 'Aktif',
  });

  final String accountStatus;

  bool get _isSignedIn => FirebaseAuth.instance.currentUser != null;

  void _openProtectedScreen(
      BuildContext context,
      Widget screen,
      _SupportHomeText text,
      ) {
    if (!_isSignedIn) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(text.signInRequired)),
        );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final _SupportHomeText text = _SupportHomeText.of(context);

    return Scaffold(
      backgroundColor: const Color(0xff0F1115),
      appBar: AppBar(
        title: Text(l10n.supportCenter),
        backgroundColor: const Color(0xff0F1115),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.support_agent_outlined,
                    color: Colors.orange,
                    size: 58,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    text.howCanWeHelp,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    text.introduction,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _SupportTile(
              icon: Icons.add_comment_outlined,
              title: l10n.newSupportRequest,
              subtitle: text.newRequestSubtitle,
              onTap: () => _openProtectedScreen(
                context,
                SupportScreen(accountStatus: accountStatus),
                text,
              ),
            ),
            _SupportTile(
              icon: Icons.receipt_long_outlined,
              title: l10n.mySupportRequests,
              subtitle: text.myRequestsSubtitle,
              onTap: () => _openProtectedScreen(
                context,
                const SupportRequestsScreen(),
                text,
              ),
            ),
            _SupportTile(
              icon: Icons.lock_open_outlined,
              title: l10n.recoverMyAccount,
              subtitle: text.accountRecoverySubtitle,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AccountRecoveryScreen(
                      accountStatus: accountStatus,
                    ),
                  ),
                );
              },
            ),
            _SupportTile(
              icon: Icons.help_outline,
              title: l10n.frequentlyAskedQuestions,
              subtitle: text.faqSubtitle,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FaqScreen()),
                );
              },
            ),
            _SupportTile(
              icon: Icons.contact_support_outlined,
              title: l10n.contactUs,
              subtitle: text.contactSubtitle,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ContactUsScreen(
                      accountStatus: accountStatus,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Text(
              l10n.supportSecurityWarning,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportTile extends StatelessWidget {
  const _SupportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xff171A20),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.orange),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(color: Colors.white54, height: 1.35),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      ),
    );
  }
}

class _SupportHomeText {
  const _SupportHomeText({
    required this.howCanWeHelp,
    required this.introduction,
    required this.newRequestSubtitle,
    required this.myRequestsSubtitle,
    required this.accountRecoverySubtitle,
    required this.faqSubtitle,
    required this.contactSubtitle,
    required this.signInRequired,
  });

  final String howCanWeHelp;
  final String introduction;
  final String newRequestSubtitle;
  final String myRequestsSubtitle;
  final String accountRecoverySubtitle;
  final String faqSubtitle;
  final String contactSubtitle;
  final String signInRequired;

  factory _SupportHomeText.of(BuildContext context) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'en':
        return const _SupportHomeText(
          howCanWeHelp: 'How can we help you?',
          introduction:
          'Create a new request, track your existing requests, or browse frequently asked questions.',
          newRequestSubtitle: 'Tell the support team about your issue',
          myRequestsSubtitle: 'View request statuses and responses',
          accountRecoverySubtitle:
          'Learn about suspension and account restriction processes',
          faqSubtitle: 'Get help with login, account, and security topics',
          contactSubtitle: 'Choose the right support channel',
          signInRequired:
          'You must sign in with your phone number before managing support requests.',
        );
      case 'de':
        return const _SupportHomeText(
          howCanWeHelp: 'Wie können wir dir helfen?',
          introduction:
          'Erstelle eine neue Anfrage, verfolge bestehende Anfragen oder sieh dir häufig gestellte Fragen an.',
          newRequestSubtitle: 'Sende dein Anliegen an das Support-Team',
          myRequestsSubtitle: 'Status und Antworten deiner Anfragen anzeigen',
          accountRecoverySubtitle:
          'Informationen zu Sperrung und Kontoeinschränkungen',
          faqSubtitle: 'Hilfe zu Anmeldung, Konto und Sicherheit',
          contactSubtitle: 'Wähle den passenden Support-Kanal',
          signInRequired:
          'Du musst dich zuerst mit deiner Telefonnummer anmelden, um Supportanfragen zu verwalten.',
        );
      default:
        return const _SupportHomeText(
          howCanWeHelp: 'Sana nasıl yardımcı olabiliriz?',
          introduction:
          'Yeni talep oluşturabilir, mevcut taleplerini takip edebilir veya sık sorulan sorulara göz atabilirsin.',
          newRequestSubtitle: 'Sorununu destek ekibine ilet',
          myRequestsSubtitle:
          'Taleplerinin durumunu ve cevapları görüntüle',
          accountRecoverySubtitle:
          'Askıya alma ve engelleme sürecini öğren',
          faqSubtitle: 'Giriş, hesap ve güvenlik konularında yardım al',
          contactSubtitle: 'Doğru destek kanalını seç',
          signInRequired:
          'Destek talebi işlemleri için önce telefon numaranla giriş yapmalısın.',
        );
    }
  }
}
