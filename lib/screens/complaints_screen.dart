import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ComplaintsScreen extends StatelessWidget {
  const ComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Oturum bulunamadı.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Şikâyetlerim')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('complaints')
            .where('createdByUid', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Şikâyetler yüklenemedi.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final ad = a.data()['createdAt'];
              final bd = b.data()['createdAt'];
              final aDate = ad is Timestamp ? ad.toDate() : DateTime(1970);
              final bDate = bd is Timestamp ? bd.toDate() : DateTime(1970);
              return bDate.compareTo(aDate);
            });

          if (docs.isEmpty) {
            return const Center(child: Text('Henüz bir şikâyet kaydın yok.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final createdAt = data['createdAt'] is Timestamp
                  ? (data['createdAt'] as Timestamp).toDate()
                  : null;
              final status = data['status']?.toString() ?? 'pending';

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.report_problem_outlined),
                  ),
                  title: Text(
                    data['subject']?.toString() ??
                        data['reason']?.toString() ??
                        'Şikâyet',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text([
                    data['description']?.toString() ?? '',
                    'Durum: ${_status(status)}',
                    if (createdAt != null)
                      DateFormat('dd.MM.yyyy • HH:mm').format(createdAt),
                  ].where((e) => e.isNotEmpty).join('\n')),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _status(String value) {
    switch (value.toLowerCase()) {
      case 'resolved':
      case 'cozuldu':
        return 'Çözüldü';
      case 'rejected':
      case 'reddedildi':
        return 'Reddedildi';
      case 'reviewing':
      case 'inceleniyor':
        return 'İnceleniyor';
      default:
        return 'Bekliyor';
    }
  }
}
