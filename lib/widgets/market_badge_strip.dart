import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
        FirebaseAuth.instance.currentUser?.uid == userId && userId.isNotEmpty;

    if (!viewerIsOwner) {
      return _MarketBadgeWrap(badges: projected);
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
                      return document.data()['googlePlayEntitled'] != false;
                    })
                    .map(MarketBadgeDisplay.fromOwnedDocument)
                    .toList(growable: false);
            return _MarketBadgeWrap(badges: owned);
          },
    );
  }
}

class _MarketBadgeWrap extends StatelessWidget {
  const _MarketBadgeWrap({required this.badges});

  final List<MarketBadgeDisplay> badges;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          const double emblemSize = 32;
          const double gap = 8;
          final int fit = ((constraints.maxWidth + gap) / (emblemSize + gap))
              .floor();
          final int slots = fit.clamp(1, 4).toInt();
          final bool overflow = badges.length > 3 || badges.length > slots;
          final int visibleCount = overflow
              ? (slots - 1).clamp(1, 3).toInt()
              : badges.length.clamp(0, 3).toInt();
          final int hidden = badges.length - visibleCount;

          return InkWell(
            onTap: () => _showMarketBadgeSheet(context, badges),
            borderRadius: BorderRadius.circular(20),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: gap,
              runSpacing: gap,
              children: <Widget>[
                for (int index = 0; index < visibleCount; index++)
                  _CatalogBadgeEmblem(badge: badges[index], size: emblemSize),
                if (hidden > 0)
                  Container(
                    width: emblemSize,
                    height: emblemSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xff141414),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xffC98A2E),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '+$hidden',
                      style: const TextStyle(
                        color: Color(0xffE1B86C),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

void _showMarketBadgeSheet(
  BuildContext context,
  List<MarketBadgeDisplay> badges,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) {
      final ColorScheme colors = Theme.of(sheetContext).colorScheme;
      final double height = MediaQuery.sizeOf(sheetContext).height * 0.62;
      return SizedBox(
        height: height,
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemCount: badges.length,
          itemBuilder: (BuildContext context, int index) {
            final MarketBadgeDisplay badge = badges[index];
            return Column(
              children: <Widget>[
                CatalogBadgeEmblem(badge: badge, size: 58),
                const SizedBox(height: 8),
                MarketBadgeTitle(
                  badge: badge,
                  maxLines: 2,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
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
    if (!badge.needsCatalogTitle && badge.emoji.isNotEmpty) {
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
        emoji: resolved.emoji,
        imageUrl: resolved.imageUrl,
        gameName: resolved.gameName.isNotEmpty
            ? resolved.gameName
            : resolved.title,
        size: size,
      ),
    );
  }
}
