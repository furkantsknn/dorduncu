import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String _refundRequestsText(
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


class RefundRequestsScreen extends StatelessWidget {
  const RefundRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(body: Center(child: Text(_refundRequestsText(context, tr: 'Oturum bulunamadı.', en: 'Session not found.', de: 'Sitzung nicht gefunden.'))));
    }

    return Scaffold(
      appBar: AppBar(title: Text(_refundRequestsText(context, tr: 'İade Taleplerim', en: 'My Refund Requests', de: 'Meine Erstattungsanfragen'))),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('refundRequests')
            .where('userUid', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(_refundRequestsText(context, tr: 'İade talepleri yüklenemedi.', en: 'Refund requests could not be loaded.', de: 'Erstattungsanfragen konnten nicht geladen werden.')));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(child: Text(_refundRequestsText(context, tr: 'Henüz bir iade talebin yok.', en: 'You have no refund requests yet.', de: 'Du hast noch keine Erstattungsanfragen.')));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final amount = (data['refundAmountKurus'] as num?)?.toInt() ?? 0;
              final createdAt = data['createdAt'] is Timestamp
                  ? (data['createdAt'] as Timestamp).toDate()
                  : null;

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.currency_exchange)),
                  title: Text(
                    data['eventTitle']?.toString() ?? _refundRequestsText(context, tr: 'İade talebi', en: 'Refund request', de: 'Erstattungsanfrage'),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text([
                    'Tutar: ${(amount / 100).toStringAsFixed(2)} ₺',
                    'Durum: ${data['status']?.toString() ?? 'pending'}',
                    if (createdAt != null)
                      DateFormat('dd.MM.yyyy • HH:mm').format(createdAt),
                  ].join('\n')),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
