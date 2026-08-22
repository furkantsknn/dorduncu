import 'package:flutter/material.dart';

class PaymentPolicyScreen extends StatelessWidget {
  const PaymentPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ödeme ve İptal Koşulları')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
        children: const [
          _PolicyCard(
            icon: Icons.lock_outline,
            title: 'Ödeme ve güvence',
            text:
            'Etkinlik, kabul edilen oyuncular için çevrim içi ödeme tamamlandığında kesinleşir. Kart bilgileri uygulamada saklanmaz. Tahsilat ve iade işlemleri seçilecek lisanslı ödeme sağlayıcısı üzerinden yürütülür.',
          ),
          _PolicyCard(
            icon: Icons.price_check_outlined,
            title: 'Fiyatlandırma',
            text:
            'Toplam ücret; oyuncu sayısı, etkinlik süresi, oyun türü ve yürürlükteki fiyat tarifesine göre hesaplanır. Oyuncu sayısı arttıkça toplam ücret aynı oranda artar. Ödeme öncesinde gösterilen nihai fiyat etkinlik için kilitlenir.',
          ),
          _PolicyCard(
            icon: Icons.event_busy_outlined,
            title: 'Müşteri iptali',
            text:
            'Müşteri iptalinde toplam ödemenin %40’ı kesilir ve %60’ı iade hakkı olarak oluşur. Kullanıcı iadeyi Dördüncü bakiyesine veya uygun olduğu ölçüde ödeme yaptığı karta isteyebilir. Kart iadeleri ödeme sağlayıcısı ve banka süreçlerine bağlıdır; hedef işlem süresi 3 iş günüdür.',
          ),
          _PolicyCard(
            icon: Icons.sports_outlined,
            title: 'Oyuncu iptal tazminatı',
            text:
            'Müşteri tarafından iptal edilen kesinleşmiş etkinlikte, oyuncunun kilitlenmiş normal kazancının %30’u iptal tazminatı olarak oyuncunun bekleyen kazancına yansıtılır. Bu tutar inceleme veya ödeme sağlayıcısı kurallarına tabi olabilir.',
          ),
          _PolicyCard(
            icon: Icons.person_off_outlined,
            title: 'Oyuncunun gelmemesi',
            text:
            'Oyuncunun etkinliğe gelmediği kanıtlanırsa müşterinin ilgili oyuncu için ödediği tutar iade edilir. Oyuncuya kazanç yazılmaz; güvenilirlik puanı düşürülebilir, başvuru kısıtı uygulanabilir ve sözleşmede açıkça kabul edilmişse oluşan borç mevcut veya gelecekteki kazançlarından mahsup edilebilir.',
          ),
          _PolicyCard(
            icon: Icons.task_alt_outlined,
            title: 'Etkinliğin tamamlanması',
            text:
            'Planlanan bitişten sonra taraflar etkinliğin gerçekleştiğini onaylar veya sorun bildirir. Oyuncu onayladıktan sonra müşteri 12 saat içinde itiraz ya da şikâyet oluşturmazsa etkinlik sunucu tarafında otomatik tamamlanabilir. Şikâyet varsa ödeme incelemeye alınır.',
          ),
          _PolicyCard(
            icon: Icons.cloud_outlined,
            title: 'Hava, tesis ve mücbir sebep',
            text:
            'Tahmini olumsuz hava tek başına otomatik tam iade nedeni değildir. Tesis kapanması doğrulanabilir kanıtla incelenir. Deprem, sel, tahliye, resmî yasaklama veya benzeri mücbir sebepte taraflara kusur yüklenmez; tam iade veya özel çözüm yönetici incelemesiyle uygulanabilir.',
          ),
          _PolicyCard(
            icon: Icons.report_outlined,
            title: 'Şikâyet ve kanıt',
            text:
            'Şikâyetlerde kategori, açıklama ve kanıt istenir. Fotoğraf, belge, tesis bildirimi, sohbet kaydı ve sistem zaman kayıtları değerlendirilebilir. Yüklenen içerik tek başına kesin ispat sayılmaz; kayıtlar yönetici incelemesine tabidir.',
          ),
          _PolicyCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Dördüncü bakiyesi',
            text:
            'İade ve kullanılabilir kazançlar uygulamada bakiye olarak gösterilebilir ve sonraki etkinlik ödemelerinde kullanılabilir. Bakiye yükleme yalnızca desteklenen çevrim içi ödeme yöntemleriyle yapılır. Nakit veya uygulama dışı ödeme kabul edilmez.',
          ),
          SizedBox(height: 10),
          Text(
            'Taslak sürüm 1 • Gerçek ödeme açılmadan önce hukuk, vergi, muhasebe ve ödeme kuruluşu sözleşmelerine göre son hâli verilmelidir.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700),
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
