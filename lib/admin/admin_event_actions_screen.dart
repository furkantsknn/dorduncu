import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminEventActionsScreen extends StatelessWidget {
  const AdminEventActionsScreen({required this.eventId, super.key});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Etkinlik Admin Geçmişi',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('audit_logs')
            .where('metadata.eventId', isEqualTo: eventId)
            .snapshots(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.hasError) {
                return const Center(child: Text('İşlem geçmişi yüklenemedi.'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final List<QueryDocumentSnapshot<Map<String, dynamic>>> logs =
                  snapshot.data!.docs.toList()..sort((
                    QueryDocumentSnapshot<Map<String, dynamic>> first,
                    QueryDocumentSnapshot<Map<String, dynamic>> second,
                  ) {
                    final DateTime firstDate = _createdAt(first.data());
                    final DateTime secondDate = _createdAt(second.data());

                    return secondDate.compareTo(firstDate);
                  });

              if (logs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Bu etkinlik için merkezi admin işlem kaydı bulunamadı.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: logs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (BuildContext context, int index) {
                  final QueryDocumentSnapshot<Map<String, dynamic>> document =
                      logs[index];
                  final Map<String, dynamic> data = document.data();
                  final Map<String, dynamic> metadata = _metadata(
                    data['metadata'],
                  );

                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.event_note_outlined),
                      ),
                      title: Text(
                        data['action']?.toString() ?? 'admin_event_action',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(_details(data, metadata)),
                      isThreeLine: true,
                    ),
                  );
                },
              );
            },
      ),
    );
  }

  static DateTime _createdAt(Map<String, dynamic> data) {
    final dynamic value = data['createdAt'];

    if (value is Timestamp) {
      return value.toDate();
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static Map<String, dynamic> _metadata(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map(
        (dynamic key, dynamic item) => MapEntry(key.toString(), item),
      );
    }

    return <String, dynamic>{};
  }

  static String _details(
    Map<String, dynamic> data,
    Map<String, dynamic> metadata,
  ) {
    final List<String> parts = <String>[
      if ((data['performedBy']?.toString() ?? '').isNotEmpty)
        'Admin: ${data['performedBy']}',
      if ((metadata['performedByRole']?.toString() ?? '').isNotEmpty)
        'Rol: ${metadata['performedByRole']}',
      if ((metadata['status']?.toString() ?? '').isNotEmpty)
        'Durum: ${metadata['status']}',
      if ((metadata['reason']?.toString() ?? '').isNotEmpty)
        'Açıklama: ${metadata['reason']}',
      if (data['createdAt'] is Timestamp)
        'Tarih: ${_formatDate((data['createdAt'] as Timestamp).toDate())}',
    ];

    return parts.join('\n');
  }

  static String _formatDate(DateTime value) {
    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String year = value.year.toString();
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');

    return '$day.$month.$year $hour:$minute';
  }
}
