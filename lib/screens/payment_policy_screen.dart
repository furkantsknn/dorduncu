import 'package:flutter/material.dart';

String _policyText(
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

class PaymentPolicyScreen extends StatelessWidget {
  const PaymentPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String title, String text})>[
      (
        icon: Icons.lock_outline,
        title: _policyText(context, tr: 'Ödeme ve güvence', en: 'Payment and security', de: 'Zahlung und Sicherheit'),
        text: _policyText(context, tr: 'Etkinlik, kabul edilen oyuncular için çevrim içi ödeme tamamlandığında kesinleşir. Kart bilgileri uygulamada saklanmaz. Tahsilat ve iade işlemleri seçilecek lisanslı ödeme sağlayıcısı üzerinden yürütülür.', en: 'The event is confirmed when online payment for accepted players is completed. Card details are not stored in the app. Charges and refunds are processed through the selected licensed payment provider.', de: 'Die Veranstaltung wird bestätigt, sobald die Online-Zahlung für akzeptierte Spieler abgeschlossen ist. Kartendaten werden nicht in der App gespeichert. Zahlungen und Erstattungen erfolgen über den ausgewählten lizenzierten Zahlungsanbieter.'),
      ),
      (
        icon: Icons.price_check_outlined,
        title: _policyText(context, tr: 'Fiyatlandırma', en: 'Pricing', de: 'Preisgestaltung'),
        text: _policyText(context, tr: 'Toplam ücret; oyuncu sayısı, etkinlik süresi, oyun türü ve yürürlükteki fiyat tarifesine göre hesaplanır. Oyuncu sayısı arttıkça toplam ücret aynı oranda artar. Ödeme öncesinde gösterilen nihai fiyat etkinlik için kilitlenir.', en: 'The total fee is calculated from player count, event duration, game type and the current price schedule. The final price shown before payment is locked for the event.', de: 'Der Gesamtpreis wird anhand der Spielerzahl, Veranstaltungsdauer, Spielart und der aktuellen Preisliste berechnet. Der vor der Zahlung angezeigte Endpreis wird für die Veranstaltung festgeschrieben.'),
      ),
      (
        icon: Icons.event_busy_outlined,
        title: _policyText(context, tr: 'Müşteri iptali', en: 'Customer cancellation', de: 'Stornierung durch den Kunden'),
        text: _policyText(context, tr: 'Müşteri iptalinde toplam ödemenin %40’ı kesilir ve %60’ı iade hakkı olarak oluşur. Kullanıcı iadeyi Dördüncü bakiyesine veya uygun olduğu ölçüde ödeme yaptığı karta isteyebilir. Kart iadeleri ödeme sağlayıcısı ve banka süreçlerine bağlıdır; hedef işlem süresi 3 iş günüdür.', en: 'For a customer cancellation, 40% of the total payment is deducted and 60% becomes refundable. The user may request the refund to Dördüncü balance or, where eligible, to the original card. Card refunds depend on provider and bank processing.', de: 'Bei einer Stornierung durch den Kunden werden 40 % der Gesamtzahlung einbehalten und 60 % erstattungsfähig. Die Erstattung kann auf das Dördüncü-Guthaben oder, sofern möglich, auf die ursprüngliche Karte erfolgen.'),
      ),
      (
        icon: Icons.sports_outlined,
        title: _policyText(context, tr: 'Oyuncu iptal tazminatı', en: 'Player cancellation compensation', de: 'Entschädigung bei Stornierung'),
        text: _policyText(context, tr: 'Müşteri tarafından iptal edilen kesinleşmiş etkinlikte, oyuncunun kilitlenmiş normal kazancının %30’u iptal tazminatı olarak oyuncunun bekleyen kazancına yansıtılır. Bu tutar inceleme veya ödeme sağlayıcısı kurallarına tabi olabilir.', en: 'If a confirmed event is cancelled by the customer, 30% of the player’s locked normal earnings is reflected as cancellation compensation in pending earnings. This may be subject to review or payment-provider rules.', de: 'Wird eine bestätigte Veranstaltung vom Kunden storniert, werden 30 % des gesperrten regulären Verdienstes des Spielers als Stornoentschädigung vorgemerkt.'),
      ),
      (
        icon: Icons.person_off_outlined,
        title: _policyText(context, tr: 'Oyuncunun gelmemesi', en: 'Player no-show', de: 'Nichterscheinen des Spielers'),
        text: _policyText(context, tr: 'Oyuncunun etkinliğe gelmediği kanıtlanırsa müşterinin ilgili oyuncu için ödediği tutar iade edilir. Oyuncuya kazanç yazılmaz; güvenilirlik puanı düşürülebilir, başvuru kısıtı uygulanabilir ve sözleşmede açıkça kabul edilmişse oluşan borç mevcut veya gelecekteki kazançlarından mahsup edilebilir.', en: 'If a player’s no-show is verified, the amount paid for that player is refunded. No earnings are credited to the player; the reliability score may be reduced, application restrictions may apply, and if explicitly accepted in the agreement, resulting debt may be offset against current or future earnings.', de: 'Wird das Nichterscheinen eines Spielers bestätigt, wird der für diesen Spieler gezahlte Betrag erstattet. Dem Spieler wird kein Verdienst gutgeschrieben; die Zuverlässigkeitsbewertung kann sinken, Bewerbungsbeschränkungen können gelten und ausdrücklich vereinbarte Schulden können mit aktuellen oder künftigen Einnahmen verrechnet werden.'),
      ),
      (
        icon: Icons.task_alt_outlined,
        title: _policyText(context, tr: 'Etkinliğin tamamlanması', en: 'Event completion', de: 'Abschluss der Veranstaltung'),
        text: _policyText(context, tr: 'Planlanan bitişten sonra taraflar etkinliğin gerçekleştiğini onaylar veya sorun bildirir. Oyuncu onayladıktan sonra müşteri 12 saat içinde itiraz ya da şikâyet oluşturmazsa etkinlik sunucu tarafında otomatik tamamlanabilir. Şikâyet varsa ödeme incelemeye alınır.', en: 'After the scheduled end, the parties confirm that the event took place or report an issue. After the player confirms, if the customer does not object or file a complaint within 12 hours, the event may be completed automatically on the server. If there is a complaint, the payment is placed under review.', de: 'Nach dem geplanten Ende bestätigen die Parteien die Durchführung oder melden ein Problem. Nach der Bestätigung durch den Spieler kann die Veranstaltung serverseitig automatisch abgeschlossen werden, wenn der Kunde innerhalb von 12 Stunden keinen Einspruch oder keine Beschwerde einreicht. Bei einer Beschwerde wird die Zahlung geprüft.'),
      ),
      (
        icon: Icons.cloud_outlined,
        title: _policyText(context, tr: 'Hava, tesis ve mücbir sebep', en: 'Weather, venue and force majeure', de: 'Wetter, Veranstaltungsort und höhere Gewalt'),
        text: _policyText(context, tr: 'Tahmini olumsuz hava tek başına otomatik tam iade nedeni değildir. Tesis kapanması doğrulanabilir kanıtla incelenir. Deprem, sel, tahliye, resmî yasaklama veya benzeri mücbir sebepte taraflara kusur yüklenmez; tam iade veya özel çözüm yönetici incelemesiyle uygulanabilir.', en: 'Forecast bad weather alone does not automatically qualify for a full refund. Venue closure is reviewed with verifiable evidence. In earthquakes, floods, evacuations, official prohibitions or similar force-majeure cases, neither party is considered at fault; a full refund or special resolution may be applied after administrative review.', de: 'Eine ungünstige Wettervorhersage allein führt nicht automatisch zu einer vollständigen Erstattung. Eine Schließung des Veranstaltungsorts wird anhand überprüfbarer Nachweise geprüft. Bei Erdbeben, Überschwemmungen, Evakuierungen, behördlichen Verboten oder ähnlicher höherer Gewalt wird keiner Partei ein Verschulden zugerechnet; eine vollständige Erstattung oder Sonderlösung kann nach administrativer Prüfung erfolgen.'),
      ),
      (
        icon: Icons.report_outlined,
        title: _policyText(context, tr: 'Şikâyet ve kanıt', en: 'Complaints and evidence', de: 'Beschwerden und Nachweise'),
        text: _policyText(context, tr: 'Şikâyetlerde kategori, açıklama ve kanıt istenir. Fotoğraf, belge, tesis bildirimi, sohbet kaydı ve sistem zaman kayıtları değerlendirilebilir. Yüklenen içerik tek başına kesin ispat sayılmaz; kayıtlar yönetici incelemesine tabidir.', en: 'Complaints require a category, description and evidence. Photos, documents, venue notices, chat records and system timestamps may be reviewed. Uploaded content alone is not considered conclusive proof; records are subject to administrative review.', de: 'Bei Beschwerden werden Kategorie, Beschreibung und Nachweise verlangt. Fotos, Dokumente, Hinweise des Veranstaltungsorts, Chatverläufe und Systemzeitstempel können geprüft werden. Hochgeladene Inhalte gelten allein nicht als endgültiger Beweis; die Unterlagen unterliegen einer administrativen Prüfung.'),
      ),
      (
        icon: Icons.account_balance_wallet_outlined,
        title: _policyText(context, tr: 'Dördüncü bakiyesi', en: 'Dördüncü balance', de: 'Dördüncü-Guthaben'),
        text: _policyText(context, tr: 'İade ve kullanılabilir kazançlar uygulamada bakiye olarak gösterilebilir ve sonraki etkinlik ödemelerinde kullanılabilir. Bakiye yükleme yalnızca desteklenen çevrim içi ödeme yöntemleriyle yapılır. Nakit veya uygulama dışı ödeme kabul edilmez.', en: 'Refunds and available earnings may be shown as app balance and used for later event payments. Balance top-ups are made only through supported online payment methods. Cash or off-app payments are not accepted.', de: 'Erstattungen und verfügbare Einnahmen können als App-Guthaben angezeigt und für spätere Veranstaltungszahlungen verwendet werden. Guthaben kann nur über unterstützte Online-Zahlungsmethoden aufgeladen werden. Bar- oder externe Zahlungen werden nicht akzeptiert.'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_policyText(context, tr: 'Ödeme ve İptal Koşulları', en: 'Payment and Cancellation Terms', de: 'Zahlungs- und Stornobedingungen')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
        children: [
          ...items.map((item) => _PolicyCard(icon: item.icon, title: item.title, text: item.text)),
          const SizedBox(height: 10),
          Text(
            _policyText(context, tr: 'Taslak sürüm 1 • Gerçek ödeme açılmadan önce hukuk, vergi, muhasebe ve ödeme kuruluşu sözleşmelerine göre son hâli verilmelidir.', en: 'Draft version 1 • Before real payments are enabled, this text must be finalized according to legal, tax, accounting and payment-provider agreements.', de: 'Entwurf Version 1 • Vor Aktivierung echter Zahlungen muss dieser Text gemäß Rechts-, Steuer-, Buchhaltungs- und Zahlungsanbietervereinbarungen finalisiert werden.'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _PolicyCard({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(text, style: const TextStyle(height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
