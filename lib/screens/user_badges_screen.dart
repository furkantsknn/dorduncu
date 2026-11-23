import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/market_badge_display.dart';
import '../widgets/market_badge_strip.dart';
import '../widgets/market_palette.dart';
import 'gift_flow_screen.dart';

String _userBadgesText(
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

class UserBadgesScreen extends StatefulWidget {
  const UserBadgesScreen({
    super.key,
    required this.userId,
    this.isOwnProfile = false,
  });

  final String userId;
  final bool isOwnProfile;

  @override
  State<UserBadgesScreen> createState() => _UserBadgesScreenState();
}

class _UserBadgesScreenState extends State<UserBadgesScreen> {
  int _generation = 0;

  @override
  Widget build(BuildContext context) {
    final MarketPalette palette = MarketPalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.ink,
        title: Text(
          widget.isOwnProfile
              ? _userBadgesText(
                  context,
                  tr: 'Rozetlerim',
                  en: 'My badges',
                  de: 'Meine Abzeichen',
                )
              : _userBadgesText(
                  context,
                  tr: 'Rozetleri',
                  en: 'Badges',
                  de: 'Abzeichen',
                ),
          style: TextStyle(color: palette.ink, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        key: ValueKey<int>(_generation),
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('owned_badges')
            .orderBy('purchasedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _BadgesError(onRetry: () => setState(() => _generation++));
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return _BadgesLoading(palette: palette);
          }

          final documents =
              (snapshot.data?.docs ??
                      const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                  .where(
                    (QueryDocumentSnapshot<Map<String, dynamic>> document) =>
                        ownedBadgeIsEntitled(document.data()),
                  )
                  .toList();

          if (documents.isEmpty) {
            return UserBadgesEmpty(isOwnProfile: widget.isOwnProfile);
          }

          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double textScale = MediaQuery.textScalerOf(
                context,
              ).scale(1);
              final bool twoColumns =
                  constraints.maxWidth >= 340 && textScale < 1.3;
              final double cardWidth = twoColumns
                  ? (constraints.maxWidth - 44) / 2
                  : constraints.maxWidth - 32;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: <Widget>[
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      for (final document in documents)
                        SizedBox(
                          width: cardWidth,
                          child: OwnedBadgeCard(
                            badge: MarketBadgeDisplay.fromOwnedDocument(
                              document,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _BadgesLoading extends StatelessWidget {
  const _BadgesLoading({required this.palette});

  final MarketPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircularProgressIndicator(color: palette.accent),
          const SizedBox(height: 12),
          Text(
            _userBadgesText(
              context,
              tr: 'Yükleniyor',
              en: 'Loading',
              de: 'Wird geladen',
            ),
            style: TextStyle(color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class OwnedBadgeCard extends StatelessWidget {
  const OwnedBadgeCard({required this.badge, super.key});

  final MarketBadgeDisplay badge;

  String _dateText(BuildContext context) {
    final DateTime? date = badge.purchasedAt;
    if (date == null) {
      return _userBadgesText(
        context,
        tr: 'Satın alınma tarihi yok',
        en: 'No purchase date',
        de: 'Kein Kaufdatum',
      );
    }

    final String formatted =
        '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
    return _userBadgesText(
      context,
      tr: 'Satın alınma: $formatted',
      en: 'Purchased: $formatted',
      de: 'Gekauft: $formatted',
    );
  }

  @override
  Widget build(BuildContext context) {
    final MarketPalette palette = MarketPalette.of(context);
    final String name = badge.gameName.trim().isNotEmpty
        ? badge.gameName.trim()
        : badge.title;

    return Semantics(
      label: name,
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.line),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(child: CatalogBadgeEmblem(badge: badge, size: 88)),
              const SizedBox(height: 10),
              Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => GiftFlowScreen(
                      kind: GiftKind.badge,
                      productId: badge.catalogId,
                      title: name,
                    ),
                  ),
                ),
                icon: const Icon(Icons.card_giftcard_outlined),
                label: Text(
                  _userBadgesText(
                    context,
                    tr: 'Hediye et',
                    en: 'Send a gift',
                    de: 'Verschenken',
                  ),
                ),
              ),
              Text(
                _dateText(context),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UserBadgesEmpty extends StatelessWidget {
  const UserBadgesEmpty({required this.isOwnProfile, super.key});

  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    final MarketPalette palette = MarketPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.workspace_premium_outlined,
              size: 42,
              color: palette.muted,
            ),
            const SizedBox(height: 14),
            Text(
              isOwnProfile
                  ? _userBadgesText(
                      context,
                      tr: 'Henüz rozetin yok',
                      en: 'You have no badges yet',
                      de: 'Du hast noch keine Abzeichen',
                    )
                  : _userBadgesText(
                      context,
                      tr: 'Bu kullanıcının henüz rozeti yok',
                      en: 'This user has no badges yet',
                      de: 'Dieser Nutzer hat noch keine Abzeichen',
                    ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isOwnProfile
                  ? _userBadgesText(
                      context,
                      tr: 'Marketten aldığın oyun rozetleri burada görünür.',
                      en: 'Game badges you purchase from the store appear here.',
                      de: 'Im Store gekaufte Spielabzeichen erscheinen hier.',
                    )
                  : _userBadgesText(
                      context,
                      tr: 'Satın alınan oyun rozetleri burada görünür.',
                      en: 'Purchased game badges appear here.',
                      de: 'Gekaufte Spielabzeichen erscheinen hier.',
                    ),
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.muted, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgesError extends StatelessWidget {
  const _BadgesError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final MarketPalette palette = MarketPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline_rounded, size: 42, color: palette.muted),
            const SizedBox(height: 12),
            Text(
              _userBadgesText(
                context,
                tr: 'Rozetler yüklenemedi.',
                en: 'Badges could not be loaded.',
                de: 'Abzeichen konnten nicht geladen werden.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.ink),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: Text(
                _userBadgesText(
                  context,
                  tr: 'Tekrar dene',
                  en: 'Try again',
                  de: 'Erneut versuchen',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
