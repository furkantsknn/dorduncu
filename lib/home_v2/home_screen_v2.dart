import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/event_detail_screen.dart';
import '../screens/notification_center_screen.dart';
import '../services/language_controller.dart';
import 'event_card_carousel.dart';
import 'home_event_map.dart';
import 'home_events_empty.dart';
import 'home_listed_event.dart';
import 'home_map_section.dart';

class HomeScreenV2 extends StatelessWidget {
  const HomeScreenV2({
    required this.greeting,
    required this.cityLabel,
    required this.profilePhotoUrl,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onSelectCity,
    required this.onCreateEvent,
    required this.onExplore,
    required this.events,
    required this.activeEvents,
    super.key,
  });

  final String greeting;
  final String cityLabel;
  final String profilePhotoUrl;
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onSelectCity;
  final VoidCallback onCreateEvent;
  final VoidCallback onExplore;
  final List<HomeListedEvent> events;
  final List<HomeListedEvent> activeEvents;

  @override
  Widget build(BuildContext context) {
    final _V2Copy copy = _V2Copy(LanguageController.language.value);
    final List<HomeListedEvent> visible = events;
    final List<String> heroCovers = activeEvents
        .map((HomeListedEvent event) => event.imageAsset)
        .whereType<String>()
        .take(3)
        .toList();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: _GreetingBar(
            greeting: greeting,
            cityLabel: cityLabel,
            profilePhotoUrl: profilePhotoUrl,
            onSelectCity: onSelectCity,
          ),
        ),
        SliverToBoxAdapter(
          child: _CategoryPills(
            categories: categories,
            selectedCategory: selectedCategory,
            onSelected: onCategorySelected,
          ),
        ),
        SliverToBoxAdapter(
          child: _HeroPanel(
            eyebrow: copy.today,
            title: copy.heroTitle,
            subtitle: copy.activeEvents(activeEvents.length),
            covers: heroCovers,
          ),
        ),
        SliverToBoxAdapter(
          child: _SectionTitle(
            title: copy.eventsForYou,
            action: copy.seeAll,
            onAction: onExplore,
          ),
        ),
        SliverToBoxAdapter(
          child: visible.isEmpty
              ? HomeEventsEmpty(
                  title: activeEvents.isEmpty
                      ? copy.noActiveTitle
                      : copy.emptyTitle,
                  body: copy.emptyBody,
                  createLabel: copy.createEvent,
                  exploreLabel: copy.explore,
                  onCreate: onCreateEvent,
                  onExplore: onExplore,
                )
              : EventCardCarousel(
                  events: visible,
                  onEventTap: (HomeListedEvent event) =>
                      _openPreview(context, event),
                ),
        ),
        SliverToBoxAdapter(
          child: MapSection(
            title: copy.exploreOnMap,
            actionLabel: copy.explore,
            onAction: onExplore,
            map: HomeEventMap(
              city: cityLabel,
              events: visible,
              onEventTap: (HomeListedEvent event) =>
                  _openPreview(context, event),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }

  void _openPreview(BuildContext context, HomeListedEvent event) {
    showHomeEventPreview(
      context,
      event,
      onOpenDetail: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                EventDetailScreen(eventId: event.id, initialData: event.source),
          ),
        );
      },
    );
  }
}

class _GreetingBar extends StatelessWidget {
  const _GreetingBar({
    required this.greeting,
    required this.cityLabel,
    required this.profilePhotoUrl,
    required this.onSelectCity,
  });

  final String greeting;
  final String cityLabel;
  final String profilePhotoUrl;
  final VoidCallback onSelectCity;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: <Widget>[
          InkWell(
            onTap: () => Scaffold.of(context).openDrawer(),
            customBorder: const CircleBorder(),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xff1B2433),
              backgroundImage: profilePhotoUrl.isEmpty
                  ? null
                  : NetworkImage(profilePhotoUrl),
              child: profilePhotoUrl.isEmpty
                  ? const Icon(Icons.person_rounded, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                InkWell(
                  onTap: onSelectCity,
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xffFF9800),
                        size: 16,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          cityLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const _NotificationButton(),
        ],
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton();

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: user == null
          ? null
          : FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('notifications')
                .where('read', isEqualTo: false)
                .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final int count = snapshot.data?.docs.length ?? 0;

            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const NotificationCenterScreen(),
                      ),
                    );
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
                if (count > 0)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: const BoxDecoration(
                        color: Color(0xffFF9800),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: const TextStyle(
                          color: Color(0xff111827),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
    );
  }
}

class _CategoryPills extends StatelessWidget {
  const _CategoryPills({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
        itemCount: categories.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final String category = categories[index];
          final bool selected = category == selectedCategory;

          return Material(
            color: selected ? const Color(0xffFF9800) : scheme.surface,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: () => onSelected(category),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected
                        ? const Color(0xffFF9800)
                        : scheme.outlineVariant,
                  ),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xff111827)
                        : scheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.covers,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final List<String> covers;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xff1C2636), Color(0xff10141C)],
        ),
        border: Border.all(color: const Color(0x33FF9800)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xffFF9800).withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xffFF9800).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    eyebrow.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xffFF9800),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xffD1D5DB),
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _CoverStack(covers: covers),
        ],
      ),
    );
  }
}

class _CoverStack extends StatelessWidget {
  const _CoverStack({required this.covers});

  final List<String> covers;

  @override
  Widget build(BuildContext context) {
    final List<String> shown = covers.take(3).toList();
    if (shown.isEmpty) {
      return Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          color: const Color(0xffFF9800).withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          Icons.sports_esports_rounded,
          color: Color(0xffFF9800),
          size: 28,
        ),
      );
    }

    return SizedBox(
      width: 86,
      height: 74,
      child: Stack(
        children: <Widget>[
          for (int index = 0; index < shown.length; index++)
            Positioned(
              left: index * 18,
              child: Container(
                width: 52,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xff10141C), width: 2),
                  image: DecorationImage(
                    image: AssetImage(shown[shown.length - 1 - index]),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.action,
    required this.onAction,
  });

  final String title;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: onAction,
            child: Text(
              action,
              style: const TextStyle(
                color: Color(0xffFF9800),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _V2Copy {
  const _V2Copy(this.language);

  final AppLanguage language;

  String v(String tr, String en, String de) {
    switch (language) {
      case AppLanguage.turkish:
        return tr;
      case AppLanguage.english:
        return en;
      case AppLanguage.german:
        return de;
    }
  }

  String get today => v('Bugün', 'Today', 'Heute');

  String get heroTitle => v(
    'Bugün ne oynamak istersin?',
    'What do you want to play today?',
    'Was möchtest du heute spielen?',
  );

  String activeEvents(int count) => v(
    '$count aktif etkinlik seni bekliyor.',
    '$count active events are waiting for you.',
    '$count aktive Events warten auf dich.',
  );

  String get eventsForYou =>
      v('Senin için etkinlikler', 'Events for you', 'Events für dich');

  String get seeAll => v('Tümünü gör', 'See all', 'Alle anzeigen');

  String get noActiveTitle => v(
    'Şu anda aktif etkinlik yok',
    'No active events right now',
    'Gerade keine aktiven Events',
  );

  String get emptyTitle => v(
    'Bu kategoride henüz etkinlik yok',
    'No events in this category yet',
    'In dieser Kategorie gibt es noch keine Events',
  );

  String get emptyBody => v(
    'Kendi masanı aç veya haritada çevrendeki oyunlara bak.',
    'Open your own table or look for games around you on the map.',
    'Eröffne deinen eigenen Tisch oder schau auf der Karte nach Spielen in der Nähe.',
  );

  String get createEvent =>
      v('Etkinlik oluştur', 'Create event', 'Event erstellen');

  String get explore => v('Keşfet', 'Explore', 'Entdecken');

  String get exploreOnMap =>
      v('Haritada keşfet', 'Explore on map', 'Auf der Karte entdecken');
}
