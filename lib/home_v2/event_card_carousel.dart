import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'home_listed_event.dart';
import 'featured_event_card.dart';

/// Ana sayfa kartının ölçüsü etkinlik sayısından bağımsızdır: iki tam kart ve
/// üçüncü sütunun bir bölümü görünür. Büyük yazıda yalnız kart uzar/hafif
/// genişler.
@visibleForTesting
Size homeEventCardSize(double viewport, TextScaler textScaler) {
  const double leftInset = 16;
  const double columnGap = 10;
  const double nextColumnPeek = 48;
  const double baseHeight = 175;

  final double textScale = textScaler.scale(14) / 14;
  final double baseWidth =
      (viewport - leftInset - columnGap - nextColumnPeek) / 2;
  final double width = math.min(
    baseWidth * textScale.clamp(1.0, 1.35),
    viewport - leftInset - nextColumnPeek,
  );

  double infoHeight(TextScaler scaler) {
    const double lineHeight = 1.3;
    return 29 +
        scaler.scale(15) * lineHeight +
        3 * math.max(13.0, scaler.scale(11) * lineHeight);
  }

  final double extra = math.max(
    0.0,
    infoHeight(textScaler) - infoHeight(TextScaler.noScaling),
  );
  return Size(width, baseHeight + extra);
}

class EventCardCarousel extends StatelessWidget {
  const EventCardCarousel({
    required this.events,
    required this.onEventTap,
    super.key,
  });

  final List<HomeListedEvent> events;
  final ValueChanged<HomeListedEvent> onEventTap;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const SizedBox.shrink();
    }

    const double gap = 10;
    final Size card = homeEventCardSize(
      MediaQuery.sizeOf(context).width,
      MediaQuery.textScalerOf(context),
    );

    if (events.length <= 2) {
      return SizedBox(
        height: card.height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: events.length,
          separatorBuilder: (BuildContext context, int index) =>
              const SizedBox(width: gap),
          itemBuilder: (BuildContext context, int index) {
            final HomeListedEvent event = events[index];
            return SizedBox(
              width: card.width,
              child: FeaturedEventCard(
                event: event,
                onTap: () => onEventTap(event),
              ),
            );
          },
        ),
      );
    }

    final int columns = (events.length / 2).ceil();

    return SizedBox(
      height: card.height * 2 + gap,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: columns,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: gap),
        itemBuilder: (BuildContext context, int index) {
          final HomeListedEvent top = events[index * 2];
          final int bottomIndex = index * 2 + 1;
          final HomeListedEvent? bottom = bottomIndex < events.length
              ? events[bottomIndex]
              : null;

          return SizedBox(
            width: card.width,
            child: Column(
              children: <Widget>[
                Expanded(
                  child: FeaturedEventCard(
                    event: top,
                    onTap: () => onEventTap(top),
                  ),
                ),
                const SizedBox(height: gap),
                Expanded(
                  child: bottom == null
                      ? const SizedBox.shrink()
                      : FeaturedEventCard(
                          event: bottom,
                          onTap: () => onEventTap(bottom),
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
