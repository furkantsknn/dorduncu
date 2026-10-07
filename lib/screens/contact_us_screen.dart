import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'faq_screen.dart';
import 'support_screen.dart';

String _contactText(
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

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({
    super.key,
    required this.accountStatus,
  });

  final String accountStatus;

  @override
  Widget build(BuildContext context) {
    final bool signedIn = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      backgroundColor: const Color(0xff0F1115),
      appBar: AppBar(
        title: Text(_contactText(context, tr: 'Bize Ulaşın', en: 'Contact Us', de: 'Kontakt')),
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
                  Icon(
                    Icons.contact_support_outlined,
                    color: Colors.orange,
                    size: 58,
                  ),
                  SizedBox(height: 14),
                  Text(
                    _contactText(context, tr: 'Yardım için doğru kanalı seç', en: 'Choose the right support channel', de: 'Wähle den richtigen Support-Kanal'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _contactText(context, tr: 'Hesap veya uygulama sorunlarında destek talebi oluştur. Genel sorular için önce sık sorulan sorulara göz at.', en: 'Create a support request for account or app issues. For general questions, check the FAQ first.', de: 'Erstelle bei Konto- oder App-Problemen eine Support-Anfrage. Bei allgemeinen Fragen sieh zuerst in die FAQ.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _ContactCard(
              icon: Icons.edit_note_outlined,
              title: _contactText(context, tr: 'Destek Talebi Oluştur', en: 'Create Support Request', de: 'Support-Anfrage erstellen'),
              description:
              signedIn
                  ? _contactText(context, tr: 'Sorununu destek ekibine güvenli şekilde ilet.', en: 'Send your issue securely to the support team.', de: 'Sende dein Problem sicher an das Support-Team.')
                  : _contactText(context, tr: 'Talep oluşturmak için telefon numaranla giriş yapmalısın.', en: 'You must sign in with your phone number to create a request.', de: 'Du musst dich mit deiner Telefonnummer anmelden, um eine Anfrage zu erstellen.'),
              buttonText: signedIn ? _contactText(context, tr: 'Talep Oluştur', en: 'Create Request', de: 'Anfrage erstellen') : _contactText(context, tr: 'Önce Giriş Yap', en: 'Sign In First', de: 'Zuerst anmelden'),
              enabled: signedIn,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SupportScreen(
                      accountStatus: accountStatus,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            _ContactCard(
              icon: Icons.help_outline,
              title: _contactText(context, tr: 'Sık Sorulan Sorular', en: 'Frequently Asked Questions', de: 'Häufig gestellte Fragen'),
              description:
              _contactText(context, tr: 'SMS, giriş, hesap kısıtlamaları ve güvenlik konularındaki hızlı yanıtları görüntüle.', en: 'View quick answers about SMS, sign-in, account restrictions and security.', de: 'Sieh dir schnelle Antworten zu SMS, Anmeldung, Kontobeschränkungen und Sicherheit an.'),
              buttonText: _contactText(context, tr: 'Soruları Görüntüle', en: 'View Questions', de: 'Fragen anzeigen'),
              enabled: true,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FaqScreen()),
                );
              },
            ),
            const SizedBox(height: 22),
            Text(
              _contactText(context, tr: 'Güvenliğin için SMS doğrulama kodunu, ödeme bilgilerini veya özel şifrelerini hiçbir destek görevlisiyle paylaşma.', en: 'For your security, never share SMS verification codes, payment information or private passwords with any support representative.', de: 'Teile zu deiner Sicherheit niemals SMS-Bestätigungscodes, Zahlungsinformationen oder private Passwörter mit Support-Mitarbeitern.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonText;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xff171A20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.orange),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            description,
            style: const TextStyle(color: Colors.white60, height: 1.45),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: enabled ? onPressed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white12,
                disabledForegroundColor: Colors.white38,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
