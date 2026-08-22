import 'package:flutter/material.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const List<Map<String, String>> _items = [
    {
      'question': 'SMS doğrulama kodu gelmiyor',
      'answer':
      'Telefon numaranı ve ülke kodunu kontrol et. Kod isteme işlemini kısa sürede çok fazla tekrarladıysan güvenlik nedeniyle bir süre beklemen gerekebilir.',
    },
    {
      'question': 'Hesabım neden askıya alındı?',
      'answer':
      'Topluluk kurallarına aykırı davranış, sahte profil, spam, güvenlik riski veya kullanıcı şikâyeti inceleme sürecini başlatabilir. Kararın hatalı olduğunu düşünüyorsan destek talebi oluştur.',
    },
    {
      'question': 'Telefon numaramı değiştirdim',
      'answer':
      'Eski numarana erişemiyorsan Destek Merkezi üzerinden hesabını tanımlayan bilgilerle talep oluşturman gerekir.',
    },
    {
      'question': 'Destek talebimi nereden takip ederim?',
      'answer':
      'Destek Merkezi içindeki “Destek Taleplerim” bölümünden talebin durumunu ve destek ekibinin cevabını görebilirsin.',
    },
    {
      'question': 'Destek ekibi hangi bilgileri ister?',
      'answer':
      'Sorunun anlaşılması için hesap ve işlem bilgileri istenebilir. SMS doğrulama kodunu hiçbir kişiyle paylaşma.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F1115),
      appBar: AppBar(
        title: const Text('Sık Sorulan Sorular'),
        backgroundColor: const Color(0xff0F1115),
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = _items[index];
          return Card(
            color: const Color(0xff171A20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ExpansionTile(
              iconColor: Colors.orange,
              collapsedIconColor: Colors.white54,
              title: Text(
                item['question']!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              children: [
                Text(
                  item['answer']!,
                  style: const TextStyle(color: Colors.white70, height: 1.5),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
