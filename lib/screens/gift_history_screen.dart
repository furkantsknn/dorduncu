import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/gift_recipient_service.dart';
import '../widgets/user_avatar.dart';
import 'gift_flow_screen.dart';
import '../utils/game_catalog.dart';

class GiftHistoryScreen extends StatelessWidget {
  const GiftHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            giftText(context, tr: 'Hediyeler', en: 'Gifts', de: 'Geschenke'),
          ),
          bottom: TabBar(
            tabs: <Widget>[
              Tab(
                text: giftText(
                  context,
                  tr: 'Gönderilen',
                  en: 'Sent',
                  de: 'Gesendet',
                ),
              ),
              Tab(
                text: giftText(
                  context,
                  tr: 'Alınan',
                  en: 'Received',
                  de: 'Erhalten',
                ),
              ),
            ],
          ),
        ),
        body: uid == null
            ? const Center(child: Text('Hediye geçmişi için giriş yap.'))
            : TabBarView(
                children: <Widget>[
                  _GiftList(field: 'buyerUid', uid: uid, outgoing: true),
                  _GiftList(field: 'recipientUid', uid: uid, outgoing: false),
                ],
              ),
      ),
    );
  }
}

class _GiftList extends StatelessWidget {
  const _GiftList({
    required this.field,
    required this.uid,
    required this.outgoing,
  });

  final String field;
  final String uid;
  final bool outgoing;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('gift_deliveries')
          .where(field, isEqualTo: uid)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              giftText(
                context,
                tr: 'Hediyeler yüklenemedi.',
                en: 'Gifts could not be loaded.',
                de: 'Geschenke konnten nicht geladen werden.',
              ),
            ),
          );
        }
        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return Center(
            child: Text(
              giftText(
                context,
                tr: 'Kayıt yok.',
                en: 'No records.',
                de: 'Keine Einträge.',
              ),
            ),
          );
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final Map<String, dynamic> data = docs[index].data();
            final String other = outgoing
                ? data['recipientUid']?.toString() ?? ''
                : data['buyerUid']?.toString() ?? '';
            final String kind = data['kind']?.toString() ?? '';
            final String product = data['productId']?.toString() ?? '';
            return FutureBuilder(
              future: GiftRecipientService().load(other),
              builder: (context, profile) {
                final person = profile.data;
                final name =
                    person?.displayName ?? 'Profil bilgisi kullanılamıyor';
                return ListTile(
                  leading: UserAvatar(
                    displayName: name,
                    imageUrl: person?.avatarUrl ?? '',
                  ),
                  title: Text(
                    kind == 'plus_gift'
                        ? '30 günlük Plus'
                        : GameCatalog.gameById(product)?.name ?? product,
                  ),
                  subtitle: Text(outgoing ? 'Alıcı: $name' : 'Gönderen: $name'),
                  trailing: IconButton(
                    tooltip: giftText(
                      context,
                      tr: 'Yeniden hediye et',
                      en: 'Send another gift',
                      de: 'Erneut verschenken',
                    ),
                    icon: const Icon(Icons.card_giftcard_outlined),
                    onPressed: person == null
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => GiftFlowScreen(
                                kind: kind == 'plus_gift'
                                    ? GiftKind.plus
                                    : GiftKind.badge,
                                productId: product,
                                title: 'Hediye',
                                recipientUid: person.uid,
                                recipientName: person.displayName,
                                recipientAvatarUrl: person.avatarUrl,
                              ),
                            ),
                          ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
