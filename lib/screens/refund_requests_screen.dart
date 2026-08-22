import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RefundRequestsScreen extends StatelessWidget {
  const RefundRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Oturum bulunamadı.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('İade Taleplerim')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('refundRequests')
            .where('userUid', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('İade talepleri yüklenemedi.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('Henüz bir iade talebin yok.'));
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
                    data['eventTitle']?.toString() ?? 'İade talebi',
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
