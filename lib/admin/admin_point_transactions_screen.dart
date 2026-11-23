import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminPointTransactionsScreen extends StatelessWidget {
  const AdminPointTransactionsScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Puan Hareketleri',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('point_transactions')
            .orderBy('createdAt', descending: true)
            .limit(200)
            .snapshots(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Puan hareketleri yüklenirken bir hata oluştu.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final List<QueryDocumentSnapshot<Map<String, dynamic>>>
              documents = snapshot.data!.docs;

              if (documents.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Bu kullanıcıya ait puan hareketi bulunmuyor.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: documents.length,
                separatorBuilder: (BuildContext context, int index) {
                  return const SizedBox(height: 10);
                },
                itemBuilder: (BuildContext context, int index) {
                  final QueryDocumentSnapshot<Map<String, dynamic>> document =
                      documents[index];

                  return _PointTransactionCard(
                    transactionId: document.id,
                    data: document.data(),
                  );
                },
              );
            },
      ),
    );
  }
}

class _PointTransactionCard extends StatelessWidget {
  const _PointTransactionCard({
    required this.transactionId,
    required this.data,
  });

  final String transactionId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final String type = data['type']?.toString().trim() ?? '';

    final String description = data['description']?.toString().trim() ?? '';

    final String adminId = data['adminId']?.toString().trim() ?? '';

    final double amount = (data['amount'] as num?)?.toDouble() ?? 0;

    final double previousPoints =
        (data['previousPoints'] as num?)?.toDouble() ?? 0;

    final double newPoints = (data['newPoints'] as num?)?.toDouble() ?? 0;

    final DateTime? createdAt = _dateFromValue(data['createdAt']);

    final bool isNegative = amount < 0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(
              child: Icon(
                isNegative ? Icons.remove_rounded : Icons.add_rounded,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _typeTitle(type),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '${isNegative ? '' : '+'}${_formatPoints(amount)}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: isNegative ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  if (description.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 7),
                    Text(description),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    '${_formatPoints(previousPoints)} → '
                    '${_formatPoints(newPoints)} puan',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: <Widget>[
                      if (createdAt != null)
                        _InfoLabel(
                          text: _formatDate(createdAt),
                          icon: Icons.schedule_outlined,
                        ),
                      if (adminId.isNotEmpty)
                        const _InfoLabel(
                          text: 'Admin işlemi',
                          icon: Icons.admin_panel_settings_outlined,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    transactionId,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _typeTitle(String value) {
    switch (value.toLowerCase()) {
      case 'admin_point_credit':
        return 'Admin puan ekledi';
      case 'admin_point_debit':
        return 'Admin puan düşürdü';
      case 'event_reward':
        return 'Etkinlik ödülü';
      case 'market_purchase':
        return 'Market harcaması';
      default:
        return value.isEmpty ? 'Puan işlemi' : value;
    }
  }

  static String _formatPoints(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  static DateTime? _dateFromValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
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

class _InfoLabel extends StatelessWidget {
  const _InfoLabel({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
