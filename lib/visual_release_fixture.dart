import 'package:flutter/material.dart';

import 'home_v2/home_listed_event.dart';
import 'home_v2/home_screen_v2.dart';
import 'utils/game_cover_assets.dart';
import 'widgets/home_bottom_navigation.dart';

// Local-only release visual fixture. It does not initialize Firebase or write data.
void main() {
  runApp(const _VisualReleaseFixture());
}

class _VisualReleaseFixture extends StatelessWidget {
  const _VisualReleaseFixture();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xffFF9800),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xff0F1115),
        useMaterial3: true,
      ),
      home: const _FixtureHome(),
    );
  }
}

class _FixtureHome extends StatelessWidget {
  const _FixtureHome();

  static final List<HomeListedEvent> _events = <HomeListedEvent>[
    HomeListedEvent(
      id: 'local-okey',
      title: 'Okey',
      date: DateTime(2026, 10, 17, 19, 30),
      time: '19:30',
      city: 'Istanbul',
      district: 'Kadikoy',
      latitude: 40.9900,
      longitude: 29.0280,
      imageAsset: GameCoverAssets.byId['okey'],
      participantCount: 2,
      maxParticipants: 4,
      hostName: 'Yerel fixture',
      source: const <String, dynamic>{},
    ),
    HomeListedEvent(
      id: 'local-satranc',
      title: 'Satranc',
      date: DateTime(2026, 10, 18, 18),
      time: '18:00',
      city: 'Istanbul',
      district: 'Kadikoy',
      latitude: 40.9920,
      longitude: 29.0320,
      imageAsset: GameCoverAssets.byId['satranc'],
      participantCount: 1,
      maxParticipants: 2,
      hostName: 'Yerel fixture',
      source: const <String, dynamic>{},
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: HomeScreenV2(
          greeting: 'Release gorsel dogrulama',
          cityLabel: 'Istanbul',
          categories: const <String>['Tum oyunlar', 'Okey', 'Satranc'],
          selectedCategory: 'Tum oyunlar',
          onCategorySelected: (_) {},
          onSelectCity: () {},
          onCreateEvent: () {},
          onExplore: () {},
          events: _events,
          activeEvents: _events,
        ),
      ),
      bottomNavigationBar: HomeBottomNavigation(
        messageTooltip: 'Mesajlar',
        profileTooltip: 'Profil',
        onMessages: () {},
        onCreateEvent: () {},
        onProfile: () {},
      ),
    );
  }
}
