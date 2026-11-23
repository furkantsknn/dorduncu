import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../models/market_badge_display.dart';
import 'game_badge_emblem.dart';

class MarketBadgeStrip extends StatelessWidget {
  const MarketBadgeStrip({
    required this.userId,
    this.projected = const <MarketBadgeDisplay>[],
    super.key,
  });

  final String userId;
  final List<MarketBadgeDisplay> projected;

  @override
  Widget build(BuildContext context) {
    final bool viewerIsOwner =
        Firebase.apps.isNotEmpty &&
        FirebaseAuth.instance.currentUser?.uid == userId &&
        userId.isNotEmpty;

    if (!viewerIsOwner) {
      return ProfileBadgeRow(badges: projected, ownsBadges: false);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('owned_badges')
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final List<MarketBadgeDisplay> owned =
                (snapshot.data?.docs ??
                        const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    .where((
                      QueryDocumentSnapshot<Map<String, dynamic>> document,
                    ) {
                      return ownedBadgeIsEntitled(document.data());
                    })
                    .map(MarketBadgeDisplay.fromOwnedDocument)
                    .toList(growable: false);
            return ProfileBadgeRow(badges: owned, ownsBadges: true);
          },
    );
  }
}

class ProfileBadgeRow extends StatelessWidget {
  const ProfileBadgeRow({
    required this.badges,
    required this.ownsBadges,
    super.key,
  });

  final List<MarketBadgeDisplay> badges;
  final bool ownsBadges;

  static const double emblemSize = 48;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          const double gap = 12;
          final double content =
              badges.length * emblemSize + (badges.length - 1) * gap;
          final List<Widget> marks = <Widget>[
            for (int index = 0; index < badges.length; index++)
              _ProfileBadgeButton(badge: badges[index], ownsBadges: ownsBadges),
          ];
          if (content <= constraints.maxWidth) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (int index = 0; index < marks.length; index++) ...<Widget>[
                  if (index > 0) const SizedBox(width: gap),
                  marks[index],
                ],
              ],
            );
          }
          return SizedBox(
            height: emblemSize,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: marks.length,
              separatorBuilder: (BuildContext context, int index) {
                return const SizedBox(width: gap);
              },
              itemBuilder: (BuildContext context, int index) => marks[index],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileBadgeButton extends StatelessWidget {
  const _ProfileBadgeButton({required this.badge, required this.ownsBadges});

  final MarketBadgeDisplay badge;
  final bool ownsBadges;

  @override
  Widget build(BuildContext context) {
    final String name = profileBadgeName(badge);
    return Semantics(
      button: true,
      label: name,
      child: InkWell(
        onTap: () =>
            showOwnedBadgeDetail(context, badge: badge, ownsBadges: ownsBadges),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: ProfileBadgeRow.emblemSize,
          height: ProfileBadgeRow.emblemSize,
          child: ExcludeSemantics(
            child: CatalogBadgeEmblem(
              badge: badge,
              size: ProfileBadgeRow.emblemSize,
            ),
          ),
        ),
      ),
    );
  }
}

String profileBadgeName(MarketBadgeDisplay badge) {
  final String gameName = badge.gameName.trim();
  if (gameName.isNotEmpty) {
    return gameName;
  }
  return badge.title.trim();
}

void showOwnedBadgeDetail(
  BuildContext context, {
  required MarketBadgeDisplay badge,
  required bool ownsBadges,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) {
      return OwnedBadgeDetail(badge: badge, ownsBadges: ownsBadges);
    },
  );
}

class OwnedBadgeDetail extends StatelessWidget {
  const OwnedBadgeDetail({
    required this.badge,
    required this.ownsBadges,
    super.key,
  });

  final MarketBadgeDisplay badge;
  final bool ownsBadges;

  @override
  Widget build(BuildContext context) {
    final String name = profileBadgeName(badge);
    final DateTime? purchasedAt = badge.purchasedAt;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CatalogBadgeEmblem(badge: badge, size: 176),
          const SizedBox(height: 16),
          Text(
            name,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            ownsBadges
                ? _badgeStripText(
                    context,
                    tr: 'Bu rozet sende.',
                    en: 'You own this badge.',
                    de: 'Dieses Abzeichen gehört dir.',
                  )
                : _badgeStripText(
                    context,
                    tr: 'Bu oyuncunun rozeti.',
                    en: 'This player’s badge.',
                    de: 'Abzeichen dieses Spielers.',
                  ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (purchasedAt != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              MaterialLocalizations.of(context).formatMediumDate(purchasedAt),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

String _badgeStripText(
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

class MarketBadgeTitle extends StatelessWidget {
  const MarketBadgeTitle({
    required this.badge,
    this.style,
    this.maxLines = 2,
    super.key,
  });

  final MarketBadgeDisplay badge;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    if (!badge.needsCatalogTitle) {
      return _title(badge.title);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('badge_products')
          .doc(badge.catalogId)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            return _title(badge.mergeCatalog(snapshot.data?.data()).title);
          },
    );
  }

  Widget _title(String title) {
    return Text(
      title,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

class CatalogBadgeEmblem extends StatelessWidget {
  const CatalogBadgeEmblem({
    required this.badge,
    required this.size,
    super.key,
  });

  final MarketBadgeDisplay badge;
  final double size;

  @override
  Widget build(BuildContext context) {
    return _CatalogBadgeEmblem(badge: badge, size: size);
  }
}

class _CatalogBadgeEmblem extends StatelessWidget {
  const _CatalogBadgeEmblem({required this.badge, required this.size});

  final MarketBadgeDisplay badge;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (badge.gameId.trim().isNotEmpty || badge.gameName.trim().isNotEmpty) {
      return _emblem(badge);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('badge_products')
          .doc(badge.catalogId)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            return _emblem(badge.mergeCatalog(snapshot.data?.data()));
          },
    );
  }

  Widget _emblem(MarketBadgeDisplay resolved) {
    return Tooltip(
      message: resolved.title,
      child: GameBadgeEmblem(
        emoji: '',
        imageUrl: resolved.imageUrl,
        gameId: resolved.gameId,
        gameName: resolved.gameName.isNotEmpty
            ? resolved.gameName
            : resolved.title,
        size: size,
      ),
    );
  }
}
