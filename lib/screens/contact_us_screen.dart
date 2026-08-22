import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'faq_screen.dart';
import 'support_screen.dart';

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
        title: const Text('Bize Ulaşın'),
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
              child: const Column(
                children: [
                  Icon(
                    Icons.contact_support_outlined,
                    color: Colors.orange,
                    size: 58,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Yardım için doğru kanalı seç',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Hesap veya uygulama sorunlarında destek talebi oluştur. Genel sorular için önce sık sorulan sorulara göz at.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _ContactCard(
              icon: Icons.edit_note_outlined,
              title: 'Destek Talebi Oluştur',
              description:
              signedIn
                  ? 'Sorununu destek ekibine güvenli şekilde ilet.'
                  : 'Talep oluşturmak için telefon numaranla giriş yapmalısın.',
              buttonText: signedIn ? 'Talep Oluştur' : 'Önce Giriş Yap',
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
              title: 'Sık Sorulan Sorular',
              description:
              'SMS, giriş, hesap kısıtlamaları ve güvenlik konularındaki hızlı yanıtları görüntüle.',
              buttonText: 'Soruları Görüntüle',
              enabled: true,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FaqScreen()),
                );
              },
            ),
            const SizedBox(height: 22),
            const Text(
              'Güvenliğin için SMS doğrulama kodunu, ödeme bilgilerini veya özel şifrelerini hiçbir destek görevlisiyle paylaşma.',
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
