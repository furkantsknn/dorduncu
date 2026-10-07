import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/market_badge_display.dart';
import '../widgets/market_badge_strip.dart';

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

class UserBadgesScreen extends StatelessWidget {
  const UserBadgesScreen({
    super.key,
    required this.userId,
    this.isOwnProfile = false,
  });

  final String userId;
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isOwnProfile ? 'Rozetlerim' : 'Rozetleri',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('owned_badges')
            .orderBy('purchasedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _BadgesError();
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final documents =
              snapshot.data?.docs ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          if (documents.isEmpty) {
            return _EmptyBadges(isOwnProfile: isOwnProfile);
          }

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            itemCount: documents.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.88,
            ),
            itemBuilder: (context, index) {
              return _BadgeCollectionCard(
                badge: MarketBadgeDisplay.fromOwnedDocument(documents[index]),
              );
            },
          );
        },
      ),
    );
  }
}

class _BadgeCollectionCard extends StatelessWidget {
  const _BadgeCollectionCard({required this.badge});

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
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.75),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Container(
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: CatalogBadgeEmblem(badge: badge, size: 72),
              ),
            ),
            const SizedBox(height: 12),
            if (badge.gameName.isNotEmpty) ...<Widget>[
              Text(
                badge.gameName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xffC97A10),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 4),
            ],
            MarketBadgeTitle(
              badge: badge,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _dateText(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBadges extends StatelessWidget {
  const _EmptyBadges({required this.isOwnProfile});

  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium_outlined,
              size: 74,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgesError extends StatelessWidget {
  const _BadgesError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          _userBadgesText(
            context,
            tr: 'Rozetler yüklenemedi.',
            en: 'Badges could not be loaded.',
            de: 'Abzeichen konnten nicht geladen werden.',
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
