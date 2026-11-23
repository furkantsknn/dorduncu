import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../screens/gift_flow_screen.dart' show giftText;

import 'admin_access.dart';
import 'admin_user_number.dart';

class AdminGiftOperationsScreen extends StatelessWidget {
  const AdminGiftOperationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: AdminAccess.currentClaims(forceRefresh: true),
      builder: (context, snapshot) {
        final bool allowed = AdminAccess.hasPermission(
          snapshot.data,
          AdminPermission.financeManage,
        );
        if (!snapshot.hasData &&
            snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!allowed) {
          return const Scaffold(
            body: Center(child: Text('Bu sayfaya erişim yetkin yok.')),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Hediye işlemleri')),
          body: ListView(
            children: const <Widget>[
              ListTile(title: Text('İnceleme bekleyenler')),
              _ReviewList(),
              ListTile(title: Text('Teslimatlar')),
              _DeliveryList(),
            ],
          ),
        );
      },
    );
  }
}

class _ReviewList extends StatelessWidget {
  const _ReviewList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('gift_reviews')
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const ListTile(title: Text('İncelemeler yüklenemedi.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const ListTile(title: Text('İnceleme kaydı yok.'));
        }
        return Column(
          children: docs
              .map(
                (document) => _detail(
                  context,
                  document.id,
                  document.data(),
                  review: true,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _DeliveryList extends StatelessWidget {
  const _DeliveryList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('gift_deliveries')
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const ListTile(title: Text('Teslimatlar yüklenemedi.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const ListTile(title: Text('Teslimat kaydı yok.'));
        }
        return Column(
          children: docs
              .map((document) => _detail(context, document.id, document.data()))
              .toList(),
        );
      },
    );
  }
}

Widget _detail(
  BuildContext context,
  String id,
  Map<String, dynamic> data, {
  bool review = false,
}) {
  final String recipientUid = data['recipientUid']?.toString() ?? '';
  final String buyerUid = data['buyerUid']?.toString() ?? '';
  final String text = <String>[
    'Durum: ${data['status'] ?? data['kind'] ?? ''}',
    'Sebep: ${data['reason'] ?? '—'}',
    'Ürün: ${data['productId'] ?? ''}',
    'Tür: ${data['kind'] ?? ''}',
  ].join('\n');
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(text),
          if (buyerUid.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            const Text(
              'Gönderen',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            AdminUserIdentity(uid: buyerUid, compact: true),
          ],
          if (recipientUid.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            const Text('Alıcı', style: TextStyle(fontWeight: FontWeight.bold)),
            AdminUserIdentity(uid: recipientUid, compact: true),
          ],
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Teknik ayrıntılar'),
            children: <Widget>[
              SelectableText('Kayıt: ${data['giftIntentId'] ?? ''}'),
              SelectableText('Play order: ${data['providerOrderId'] ?? '—'}'),
              Text('Consume: ${data['consumed'] ?? '—'}'),
            ],
          ),
          if (review) ...[
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _reviewAction(context, id, 'note'),
                  child: Text(
                    giftText(
                      context,
                      tr: 'Not ekle',
                      en: 'Add note',
                      de: 'Notiz hinzufügen',
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: data['status'] == 'refunded_verified'
                      ? null
                      : () => _reviewAction(context, id, 'verify_refund'),
                  child: Text(
                    giftText(
                      context,
                      tr: 'Play iadesini doğrula',
                      en: 'Verify Play refund',
                      de: 'Play-Erstattung prüfen',
                    ),
                  ),
                ),
              ],
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('gift_reviews')
                  .doc(id)
                  .collection('history')
                  .orderBy('createdAt', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, snapshot) => Column(
                children: [
                  for (final row
                      in snapshot.data?.docs ??
                          <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    ListTile(
                      title: Text(row.data()['action']?.toString() ?? ''),
                      subtitle: Text(row.data()['reason']?.toString() ?? ''),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

Future<void> _reviewAction(
  BuildContext context,
  String id,
  String action,
) async {
  final controller = TextEditingController();
  final orderController = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        giftText(
          context,
          tr: 'İnceleme işlemi',
          en: 'Review action',
          de: 'Prüfaktion',
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (action == 'verify_refund')
            Text(
              giftText(
                context,
                tr: 'Bu işlem iade başlatmaz. Yalnız sağlayıcının doğruladığı tam iadeyi kaydeder; doğrulanamazsa inceleme açık kalır.',
                en: 'This does not issue a refund. Only a provider-confirmed full refund can close the review.',
                de: 'Dies löst keine Erstattung aus. Nur eine bestätigte vollständige Erstattung schließt die Prüfung.',
              ),
            ),
          TextField(
            controller: controller,
            maxLength: 1000,
            decoration: InputDecoration(
              labelText: giftText(
                context,
                tr: 'Gerekçe',
                en: 'Reason',
                de: 'Begründung',
              ),
            ),
          ),
          if (action == 'verify_refund')
            TextField(
              controller: orderController,
              maxLength: 194,
              decoration: InputDecoration(
                labelText: giftText(
                  context,
                  tr: 'Play sipariş kimliği (eski kayıt için arama)',
                  en: 'Play order ID (legacy record lookup)',
                  de: 'Play-Bestell-ID (Suche für Alteintrag)',
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            giftText(context, tr: 'Vazgeç', en: 'Cancel', de: 'Abbrechen'),
          ),
        ),
        FilledButton(
          onPressed: () {
            if (controller.text.trim().length >= 3) {
              Navigator.pop(ctx, controller.text.trim());
            }
          },
          child: Text(
            giftText(
              context,
              tr: 'Doğrula / Kaydet',
              en: 'Verify / Save',
              de: 'Prüfen / Speichern',
            ),
          ),
        ),
      ],
    ),
  );
  final orderId = orderController.text.trim();
  controller.dispose();
  orderController.dispose();
  if (reason == null || !context.mounted) return;
  try {
    await FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    ).httpsCallable('adminResolveGiftReview').call({
      'reviewId': id,
      'reason': reason,
      'action': action,
      if (orderId.isNotEmpty) 'orderId': orderId,
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            giftText(
              context,
              tr: 'İşlem doğrulandı ve kaydedildi.',
              en: 'Action verified and saved.',
              de: 'Aktion geprüft und gespeichert.',
            ),
          ),
        ),
      );
    }
  } on FirebaseFunctionsException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'İşlem doğrulanamadı.')),
      );
    }
  }
}
