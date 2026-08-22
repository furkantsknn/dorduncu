import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'support_screen.dart';

String _accountRecoveryText(
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

class AccountRecoveryScreen extends StatelessWidget {
  const AccountRecoveryScreen({
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
        title: Text(
          _accountRecoveryText(
            context,
            tr: 'Hesabımı Geri Al',
            en: 'Recover My Account',
            de: 'Mein Konto wiederherstellen',
          ),
        ),
        backgroundColor: const Color(0xff0F1115),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          const Icon(
            Icons.lock_open_outlined,
            color: Colors.orange,
            size: 70,
          ),
          const SizedBox(height: 18),
          Text(
            _accountRecoveryText(
              context,
              tr: 'Hesap inceleme süreci',
              en: 'Account review process',
              de: 'Kontoprüfungsverfahren',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _accountRecoveryText(
              context,
              tr: 'Hesaplar güvenlik riski, sahte profil, spam, taciz, yanıltıcı bilgi veya topluluk kurallarının ihlali nedeniyle kısıtlanabilir.',
              en: 'Accounts may be restricted due to security risks, fake profiles, spam, harassment, misleading information, or violations of community guidelines.',
              de: 'Konten können aufgrund von Sicherheitsrisiken, gefälschten Profilen, Spam, Belästigung, irreführenden Informationen oder Verstößen gegen die Community-Richtlinien eingeschränkt werden.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 26),
          _Step(
            number: '1',
            title: _accountRecoveryText(
              context,
              tr: 'Durumu kontrol et',
              en: 'Check the status',
              de: 'Status prüfen',
            ),
            text: _accountRecoveryText(
              context,
              tr: 'Hesap ekranında gösterilen kısıtlama bilgisini incele.',
              en: 'Review the restriction information shown on the account screen.',
              de: 'Prüfe die auf dem Kontobildschirm angezeigten Einschränkungsinformationen.',
            ),
          ),
          _Step(
            number: '2',
            title: _accountRecoveryText(
              context,
              tr: 'Açıklamanı hazırla',
              en: 'Prepare your explanation',
              de: 'Begründung vorbereiten',
            ),
            text: _accountRecoveryText(
              context,
              tr: 'Kararın neden hatalı olduğunu açık ve ayrıntılı şekilde yaz.',
              en: 'Explain clearly and in detail why you believe the decision is incorrect.',
              de: 'Erkläre klar und ausführlich, warum du die Entscheidung für falsch hältst.',
            ),
          ),
          _Step(
            number: '3',
            title: _accountRecoveryText(
              context,
              tr: 'Talebi takip et',
              en: 'Track your request',
              de: 'Anfrage verfolgen',
            ),
            text: _accountRecoveryText(
              context,
              tr: 'Destek Taleplerim bölümünden durum ve cevapları görüntüle.',
              en: 'View the status and responses in the My Support Requests section.',
              de: 'Sieh dir den Status und die Antworten im Bereich „Meine Supportanfragen“ an.',
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: signedIn
                  ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SupportScreen(
                      accountStatus: accountStatus,
                    ),
                  ),
                );
              }
                  : null,
              icon: const Icon(Icons.edit_note_outlined),
              label: Text(
                signedIn
                    ? _accountRecoveryText(
                  context,
                  tr: 'İtiraz Talebi Oluştur',
                  en: 'Create an Appeal Request',
                  de: 'Einspruchsanfrage erstellen',
                )
                    : _accountRecoveryText(
                  context,
                  tr: 'Talep için önce giriş yap',
                  en: 'Sign in first to submit a request',
                  de: 'Melde dich zuerst an, um eine Anfrage zu senden',
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white12,
                disabledForegroundColor: Colors.white38,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.text,
  });

  final String number;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff171A20),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.orange,
            foregroundColor: Colors.black,
            child: Text(
              number,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white60,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
