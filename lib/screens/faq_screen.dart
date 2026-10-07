import 'package:flutter/material.dart';

String _faqText(
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

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  List<Map<String, String>> _items(BuildContext context) => [
        {
          'question': _faqText(context, tr: 'SMS doğrulama kodu gelmiyor', en: 'SMS verification code is not arriving', de: 'Der SMS-Bestätigungscode kommt nicht an'),
          'answer': _faqText(context, tr: 'Telefon numaranı ve ülke kodunu kontrol et. Kod isteme işlemini kısa sürede çok fazla tekrarladıysan güvenlik nedeniyle bir süre beklemen gerekebilir.', en: 'Check your phone number and country code. If you requested the code too many times in a short period, you may need to wait for security reasons.', de: 'Prüfe deine Telefonnummer und Ländervorwahl. Wenn du den Code zu oft in kurzer Zeit angefordert hast, musst du aus Sicherheitsgründen möglicherweise etwas warten.'),
        },
        {
          'question': _faqText(context, tr: 'Hesabım neden askıya alındı?', en: 'Why was my account suspended?', de: 'Warum wurde mein Konto gesperrt?'),
          'answer': _faqText(context, tr: 'Topluluk kurallarına aykırı davranış, sahte profil, spam, güvenlik riski veya kullanıcı şikâyeti inceleme sürecini başlatabilir. Kararın hatalı olduğunu düşünüyorsan destek talebi oluştur.', en: 'Community rule violations, fake profiles, spam, security risks or user reports may trigger a review. If you believe the decision is incorrect, create a support request.', de: 'Verstöße gegen Community-Regeln, gefälschte Profile, Spam, Sicherheitsrisiken oder Nutzerbeschwerden können eine Prüfung auslösen. Wenn du die Entscheidung für falsch hältst, erstelle eine Support-Anfrage.'),
        },
        {
          'question': _faqText(context, tr: 'Telefon numaramı değiştirdim', en: 'I changed my phone number', de: 'Ich habe meine Telefonnummer geändert'),
          'answer': _faqText(context, tr: 'Eski numarana erişemiyorsan Destek Merkezi üzerinden hesabını tanımlayan bilgilerle talep oluşturman gerekir.', en: 'If you no longer have access to your old number, create a request through the Support Center using information that identifies your account.', de: 'Wenn du keinen Zugriff mehr auf deine alte Nummer hast, erstelle im Support-Center eine Anfrage mit Angaben, die dein Konto identifizieren.'),
        },
        {
          'question': _faqText(context, tr: 'Destek talebimi nereden takip ederim?', en: 'Where can I track my support request?', de: 'Wo kann ich meine Support-Anfrage verfolgen?'),
          'answer': _faqText(context, tr: 'Destek Merkezi içindeki “Destek Taleplerim” bölümünden talebin durumunu ve destek ekibinin cevabını görebilirsin.', en: 'You can view the status of your request and the support team response under “My Support Requests” in the Support Center.', de: 'Im Bereich „Meine Support-Anfragen“ des Support-Centers kannst du den Status und die Antwort des Support-Teams sehen.'),
        },
        {
          'question': _faqText(context, tr: 'Destek ekibi hangi bilgileri ister?', en: 'What information does the support team request?', de: 'Welche Informationen benötigt das Support-Team?'),
          'answer': _faqText(context, tr: 'Sorunun anlaşılması için hesap ve işlem bilgileri istenebilir. SMS doğrulama kodunu hiçbir kişiyle paylaşma.', en: 'Account and transaction information may be requested to understand the issue. Never share your SMS verification code with anyone.', de: 'Zur Klärung können Konto- und Transaktionsinformationen angefordert werden. Teile deinen SMS-Bestätigungscode niemals mit anderen.'),
        },
      ];

  @override
  Widget build(BuildContext context) {
    final items = _items(context);
    return Scaffold(
      backgroundColor: const Color(0xff0F1115),
      appBar: AppBar(
        title: Text(_faqText(context, tr: 'Sık Sorulan Sorular', en: 'Frequently Asked Questions', de: 'Häufig gestellte Fragen')),
        backgroundColor: const Color(0xff0F1115),
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return Card(
            color: const Color(0xff171A20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ExpansionTile(
              iconColor: Colors.orange,
              collapsedIconColor: Colors.white54,
              title: Text(item['question']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              children: [
                Text(item['answer']!, style: const TextStyle(color: Colors.white70, height: 1.5)),
              ],
            ),
          );
        },
      ),
    );
  }
}
