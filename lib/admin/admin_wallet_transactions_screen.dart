import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminWalletTransactionsScreen extends StatelessWidget {
  const AdminWalletTransactionsScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cüzdan Hareketleri',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('wallets')
            .doc(userId)
            .collection('transactions')
            .orderBy('createdAt', descending: true)
            .limit(200)
            .snapshots(),
        builder: (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Cüzdan hareketleri yüklenirken bir hata oluştu.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final List<QueryDocumentSnapshot<Map<String, dynamic>>> documents =
              snapshot.data!.docs;

          if (documents.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Bu kullanıcıya ait cüzdan hareketi bulunmuyor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: documents.length,
            separatorBuilder: (
                BuildContext context,
                int index,
                ) {
              return const SizedBox(height: 10);
            },
            itemBuilder: (
                BuildContext context,
                int index,
                ) {
              final QueryDocumentSnapshot<Map<String, dynamic>> document =
              documents[index];

              return _TransactionCard(
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

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.transactionId,
    required this.data,
  });

  final String transactionId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final String type = data['type']?.toString().trim() ?? 'unknown';

    final String status = data['status']?.toString().trim() ?? '';

    final String description =
        data['description']?.toString().trim() ?? '';

    final String eventTitle =
        data['eventTitle']?.toString().trim() ?? '';

    final String adminId =
        data['adminId']?.toString().trim() ??
            data['performedByUid']?.toString().trim() ??
            '';

    final int amountKurus =
        (data['amountKurus'] as num?)?.toInt() ?? 0;

    final DateTime? createdAt = _dateFromValue(data['createdAt']);

    final bool isNegative = _isNegativeTransaction(type, amountKurus);

    final String amountText = isNegative
        ? '-${_money(amountKurus.abs())}'
        : '+${_money(amountKurus.abs())}';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(
              child: Icon(_transactionIcon(type)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _transactionTitle(type),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        amountText,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: isNegative
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  if (description.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(description),
                  ],
                  if (eventTitle.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 5),
                    Text(
                      eventTitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: <Widget>[
                      _InfoLabel(
                        text: status.isEmpty
                            ? 'Durum yok'
                            : _statusTitle(status),
                        icon: Icons.info_outline,
                      ),
                      if (createdAt != null)
                        _InfoLabel(
                          text: _formatDate(createdAt),
                          icon: Icons.schedule_outlined,
                        ),
                      if (adminId.isNotEmpty)
                        _InfoLabel(
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

  static bool _isNegativeTransaction(
      String type,
      int amountKurus,
      ) {
    if (amountKurus < 0) {
      return true;
    }

    final String normalized = type.toLowerCase();

    return normalized.contains('debit') ||
        normalized.contains('withdraw') ||
        normalized.contains('purchase') ||
        normalized.contains('spent') ||
        normalized.contains('deduct') ||
        normalized.contains('payment');
  }

  static IconData _transactionIcon(String type) {
    final String normalized = type.toLowerCase();

    if (normalized.contains('refund')) {
      return Icons.currency_exchange_outlined;
    }

    if (normalized.contains('withdraw')) {
      return Icons.account_balance_outlined;
    }

    if (normalized.contains('purchase') ||
        normalized.contains('payment')) {
      return Icons.shopping_bag_outlined;
    }

    if (normalized.contains('admin') ||
        normalized.contains('manual') ||
        normalized.contains('bonus')) {
      return Icons.admin_panel_settings_outlined;
    }

    if (normalized.contains('pending')) {
      return Icons.hourglass_top_outlined;
    }

    return Icons.receipt_long_outlined;
  }

  static String _transactionTitle(String type) {
    switch (type.toLowerCase()) {
      case 'pending_credit':
        return 'Bekleyen kazanç';
      case 'earning_released':
        return 'Kazanç serbest bırakıldı';
      case 'pending_reversed':
        return 'Bekleyen kazanç geri alındı';
      case 'refund_credit':
        return 'İade bakiyesi';
      case 'admin_credit':
        return 'Admin bakiye ekledi';
      case 'admin_debit':
        return 'Admin bakiye düşürdü';
      case 'admin_point_credit':
        return 'Admin puan ekledi';
      case 'admin_point_debit':
        return 'Admin puan düşürdü';
      case 'market_purchase':
        return 'Market satın alımı';
      default:
        return type.isEmpty ? 'Cüzdan işlemi' : type;
    }
  }

  static String _statusTitle(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
        return 'Tamamlandı';
      case 'pending':
        return 'Bekliyor';
      case 'failed':
        return 'Başarısız';
      case 'cancelled':
        return 'İptal edildi';
      default:
        return status;
    }
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

  static String _money(int amountKurus) {
    return '${(amountKurus / 100).toStringAsFixed(2)} TL';
  }
}

class _InfoLabel extends StatelessWidget {
  const _InfoLabel({
    required this.text,
    required this.icon,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
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
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}