import 'package:flutter/material.dart';

import 'home_listed_event.dart';
import 'featured_event_card.dart';

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

    final double viewport = MediaQuery.sizeOf(context).width;
    const double leftInset = 16;
    const double columnGap = 10;
    const double nextColumnPeek = 48;
    final double cardWidth =
        (viewport - leftInset - columnGap - nextColumnPeek) / 2;

    if (events.length <= 2) {
      return SizedBox(
        height: 214,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: events.length,
          separatorBuilder: (BuildContext context, int index) =>
              const SizedBox(width: 10),
          itemBuilder: (BuildContext context, int index) {
            final HomeListedEvent event = events[index];
            return SizedBox(
              width: viewport * 0.72,
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
      height: 360,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: columns,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: 10),
        itemBuilder: (BuildContext context, int index) {
          final HomeListedEvent top = events[index * 2];
          final int bottomIndex = index * 2 + 1;
          final HomeListedEvent? bottom = bottomIndex < events.length
              ? events[bottomIndex]
              : null;

          return SizedBox(
            width: cardWidth,
            child: Column(
              children: <Widget>[
                Expanded(
                  child: FeaturedEventCard(
                    event: top,
                    onTap: () => onEventTap(top),
                  ),
                ),
                const SizedBox(height: 10),
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
