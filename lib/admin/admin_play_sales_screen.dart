import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_access.dart';

/// Read-only Google Play sales, sale records, and refund lifecycle.
class AdminPlaySalesScreen extends StatelessWidget {
  const AdminPlaySalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: AdminAccess.currentClaims(forceRefresh: true),
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!AdminAccess.hasPermission(
          snapshot.data,
          AdminPermission.financeManage,
        )) {
          return const Scaffold(
            body: Center(child: Text('Bu sayfaya erişim yetkin yok.')),
          );
        }

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Play satışları'),
              bottom: const TabBar(
                isScrollable: true,
                tabs: <Widget>[
                  Tab(text: 'Satışlar'),
                  Tab(text: 'Satış kayıtları'),
                  Tab(text: 'İade ve yaşam döngüsü'),
                ],
              ),
            ),
            body: const TabBarView(
              children: <Widget>[
                _OperationList(),
                _SaleList(),
                _LifecycleList(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OperationList extends StatelessWidget {
  const _OperationList();

  @override
  Widget build(BuildContext context) {
    return _QueryList(
      query: FirebaseFirestore.instance
          .collection('commercial_operations')
          .orderBy('createdAt', descending: true)
          .limit(80),
      itemBuilder: (data, id) {
        final String type = data['type']?.toString() ?? '';
        if (type != 'digital_plus_purchase' &&
            type != 'digital_badge_purchase') {
          return null;
        }
        return _SaleCard(
          title: type == 'digital_plus_purchase' ? 'Plus' : 'Rozet',
          lines: <String>[
            'Kullanıcı: ${_text(data['userUid'])}',
            'Ürün: ${_text(data['relatedProductId'])}',
            'Durum: ${_text(data['state'])}',
            'Sipariş: ${_text(data['providerTransactionId'])}',
            'Tarih: ${_date(data['createdAt'])}',
          ],
        );
      },
    );
  }
}

class _SaleList extends StatelessWidget {
  const _SaleList();

  @override
  Widget build(BuildContext context) {
    return _QueryList(
      query: FirebaseFirestore.instance
          .collection('market_sales')
          .orderBy('createdAt', descending: true)
          .limit(80),
      itemBuilder: (data, id) {
        final String productType = data['productType']?.toString() ?? '';
        final bool plus = productType.contains('plus') || data['plan'] != null;
        return _SaleCard(
          title: plus ? 'Plus' : 'Rozet',
          lines: <String>[
            'Kullanıcı: ${_text(data['uid'])}',
            'Ürün: ${_text(data['productId'])}',
            'Play ürünü: ${_text(data['googlePlayProductId'])}',
            'Durum: ${_text(data['status'])}',
            'Kayıt: ${_text(data['commercialOperationId'])}',
            'Tarih: ${_date(data['createdAt'])}',
          ],
        );
      },
    );
  }
}

class _LifecycleList extends StatelessWidget {
  const _LifecycleList();

  @override
  Widget build(BuildContext context) {
    return _QueryList(
      query: FirebaseFirestore.instance
          .collection('google_play_lifecycle_events')
          .orderBy('createdAt', descending: true)
          .limit(80),
      itemBuilder: (data, id) {
        final String kind = data['kind']?.toString() ?? '';
        final bool revoked = data['entitlementRevoked'] == true;
        final bool lostEntitlement = data['hasEntitlement'] == false;
        return _SaleCard(
          title: kind == 'plus_subscription'
              ? 'Plus yaşam döngüsü'
              : 'Rozet yaşam döngüsü',
          lines: <String>[
            'Kullanıcı: ${_text(data['uid'])}',
            'Ürün: ${_text(data['productId'])}',
            'Play ürünü: ${_text(data['googlePlayProductId'])}',
            'Bildirim: ${_text(data['notificationType'])}',
            'Abonelik: ${_text(data['subscriptionState'])}',
            'İade türü: ${_text(data['refundType'])}',
            'Sipariş: ${_text(data['latestOrderId'] ?? data['orderId'])}',
            if (revoked || lostEntitlement)
              'Sonuç: Play hakkı güncellendi veya kaldırıldı',
            'Tarih: ${_date(data['createdAt'])}',
          ],
        );
      },
    );
  }
}

class _QueryList extends StatelessWidget {
  const _QueryList({required this.query, required this.itemBuilder});

  final Query<Map<String, dynamic>> query;
  final Widget? Function(Map<String, dynamic> data, String id) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Kayıtlar yüklenemedi.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<Widget> cards = <Widget>[];
        for (final QueryDocumentSnapshot<Map<String, dynamic>> document
            in snapshot.data!.docs) {
          final Widget? card = itemBuilder(document.data(), document.id);
          if (card != null) {
            cards.add(card);
          }
        }

        if (cards.isEmpty) {
          return const Center(child: Text('Gösterilecek Play kaydı yok.'));
        }

        return ListView(padding: const EdgeInsets.all(16), children: cards);
      },
    );
  }
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            ...lines.map(
              (String line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _text(dynamic value) {
  final String text = value?.toString().trim() ?? '';
  if (text.isEmpty || text.toLowerCase().contains('token')) {
    return '—';
  }
  return text;
}

String _date(dynamic value) {
  if (value is Timestamp) {
    final DateTime date = value.toDate().toLocal();
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String hour = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.${date.year} $hour:$minute';
  }
  return '—';
}
