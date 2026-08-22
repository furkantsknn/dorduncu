import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'about_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart';

import '../models/event_model.dart';
import '../models/user_model.dart';
import '../utils/game_catalog.dart';
import '../services/event_service.dart';
import '../services/session_service.dart';
import '../services/user_service.dart';
import '../services/language_controller.dart';
import 'account_status_screen.dart';
import 'create_event_screen.dart';
import 'event_detail_screen.dart';
import 'favorites_screen.dart';
import 'messages_screen.dart';
import 'my_events_screen.dart';
import 'notification_center_screen.dart';
import 'explore_map_screen.dart';
import 'login_screen.dart';
import 'market_screen.dart';
import 'profile_screen.dart';
import 'public_profile_screen.dart';
import 'settings_screen.dart';
import 'wallet_screen.dart';
import '../widgets/user_avatar.dart';

class HomeScreen extends StatefulWidget {
  final String userName;

  const HomeScreen({
    super.key,
    required this.userName,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic> profileData = {};

  final Set<String> joiningEventIds = {};
  final Set<String> favoriteEventIds = {};
  final MapController mapController = MapController();

  bool loading = true;
  bool _nearbyMode = false;
  LatLng? _nearbyCenter;
  int selectedNavIndex = 0;
  String selectedCategory = "Tümü";

  List<String> get categories => [
    text.allCategory,
    "⚽ Futbol",
    "🏀 Basketbol",
    "🎾 Tenis",
    "♠️ Batak",
    "🀄 101",
    "🎱 Bilardo",
    "♟️ Satranç",
  ];

  List<String> get allGames => [
    text.allCategory,
    "⚽ Futbol",
    "🏀 Basketbol",
    "🎾 Tenis",
    "🏐 Voleybol",
    "🏓 Masa Tenisi",
    "🏸 Badminton",
    "♠️ Batak",
    "🀄 101",
    "🎴 Okey",
    "🎱 Bilardo",
    "♟️ Satranç",
    "🎮 Konsol Oyunu",
    "🎲 Kutu Oyunu",
    "🎯 Dart",
    "🎮 Diğer",
  ];

  bool _sessionExpiredHandled = false;

  _HomeText get text => _HomeText(LanguageController.language.value);

  void _handleLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    LanguageController.language.addListener(_handleLanguageChanged);
    loadProfile();
    _startSessionListener();
  }

  Future<void> _startSessionListener() async {
    await SessionService.startListening(
      onSessionExpired: _handleSessionExpired,
    );
  }

  void _handleSessionExpired() {
    if (!mounted || _sessionExpiredHandled) {
      return;
    }

    _sessionExpiredHandled = true;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => AccountStatusScreen(
          title: text.sessionEnded,
          message:
          text.sessionEndedMessage,
          icon: Icons.phonelink_erase_rounded,
        ),
      ),
          (route) => false,
    );
  }

  @override
  void dispose() {
    LanguageController.language.removeListener(_handleLanguageChanged);
    SessionService.stopListening();
    super.dispose();
  }

  Future<void> loadProfile() async {
    try {
      final Map<String, dynamic> data = await UserService.getProfileData();

      if (!mounted) return;

      setState(() {
        profileData = data;
        loading = false;
        favoriteEventIds
          ..clear()
          ..addAll(
            List<String>.from(data["favoriEtkinlikler"] ?? const []),
          );
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  Future<void> logout() async {
    await SessionService.clearSession();
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const LoginScreen(),
      ),
          (route) => false,
    );
  }

  Future<void> joinEvent(
      String eventId, {
        String? gameIdOrName,
      }) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        text.loginToApply,
      );
      return;
    }

    if (!_hasPlayerBadge(profileData)) {
      _showMessage(
        text.completePlayerProfile,
      );
      return;
    }

    if (gameIdOrName != null &&
        gameIdOrName.trim().isNotEmpty) {
      final userModel = UserModel.fromMap(
        profileData,
        documentId: user.uid,
      );

      if (!userModel.hasGame(gameIdOrName)) {
        final eventGame =
            GameCatalog.gameById(gameIdOrName) ??
                GameCatalog.gameByLegacyValue(gameIdOrName);

        _showMessage(
          text.addGameBeforeApply(eventGame?.name ?? gameIdOrName),
        );
        return;
      }
    }

    if (joiningEventIds.contains(eventId)) {
      return;
    }

    setState(() {
      joiningEventIds.add(eventId);
    });

    try {
      await EventService().applyToEvent(
        eventId: eventId,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        text.applicationSent,
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.message ??
            text.applicationError,
      );
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.message.toString(),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        text.applicationErrorWith(error),
      );
    } finally {
      if (mounted) {
        setState(() {
          joiningEventIds.remove(eventId);
        });
      }
    }
  }

  Future<void> toggleFavorite(String eventId) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(text.loginToFavorite);
      return;
    }

    final bool currentlyFavorite = favoriteEventIds.contains(eventId);

    setState(() {
      if (currentlyFavorite) {
        favoriteEventIds.remove(eventId);
      } else {
        favoriteEventIds.add(eventId);
      }
    });

    try {
      await FirebaseFirestore.instance.collection("users").doc(user.uid).set(
        {
          "favoriEtkinlikler": currentlyFavorite
              ? FieldValue.arrayRemove([eventId])
              : FieldValue.arrayUnion([eventId]),
          "guncellemeTarihi": FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        if (currentlyFavorite) {
          favoriteEventIds.add(eventId);
        } else {
          favoriteEventIds.remove(eventId);
        }
      });

      _showMessage(text.favoriteSaveFailed);
    }
  }

  void openMessages() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MessagesScreen(),
      ),
    );
  }

  void openFavorites() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FavoritesScreen(),
      ),
    ).then((_) => loadProfile());
  }

  void openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationCenterScreen(),
      ),
    );
  }

  Future<void> openEventDetail(
      String eventId,
      Map<String, dynamic> event,
      ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          eventId: eventId,
          initialData: event,
        ),
      ),
    );

    if (mounted) {
      await loadProfile();
    }
  }

  void openExploreMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExploreMapScreen(selectedCity: _activeCity),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message),
        ),
      );
  }

  String _verificationStatusText() {
    if (profileData["plus"] == true) return text.plusMember;
    return text.normalMember;
  }

  Color _verificationStatusColor() {
    return profileData["plus"] == true
        ? const Color(0xffFF9800)
        : const Color(0xff697386);
  }

  IconData _verificationStatusIcon() {
    return profileData["plus"] == true
        ? Icons.workspace_premium_rounded
        : Icons.person_outline;
  }

  void _showVerificationStatus() {
    Navigator.pop(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final Color statusColor = _verificationStatusColor();

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _verificationStatusIcon(),
                  color: statusColor,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  _verificationStatusText(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _verificationDescription(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: Text(
                      text.ok,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _verificationDescription() {
    final bool verified = profileData["verified"] == true;

    final String status =
        profileData["verificationStatus"]?.toString().toLowerCase() ?? "none";

    if (verified || status == "approved") return text.accountVerified;
    if (status == "pending") {
      return text.documentsPending;
    }
    if (status == "rejected") {
      return text.verificationRejected;
    }

    return text.verificationNotCompleted;
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    final String profilAdi =
    profileData["profilAdi"]?.toString().trim().isNotEmpty == true
        ? profileData["profilAdi"].toString().trim()
        : widget.userName;

    final String sehir = _activeCity.isNotEmpty
        ? _activeCity
        : text.locationNotAdded;

    final String profilFotografi =
        profileData["profilFotografi"]?.toString().trim() ?? "";

    final double puan = (profileData["puan"] as num?)?.toDouble() ?? 0.0;
    final bool plus = profileData["plus"] == true;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: _drawer(
        profilAdi: profilAdi,
        sehir: sehir,
        puan: puan,
        plus: plus,
        profilFotografi: profilFotografi,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: EventService.getEvents(),
        builder: (context, snapshot) {
          final List<QueryDocumentSnapshot<Map<String, dynamic>>> eventDocs =
              snapshot.data?.docs ?? [];

          final List<QueryDocumentSnapshot<Map<String, dynamic>>>
          filteredEvents = _filteredEvents(eventDocs);
          final mapEvents = _nearbyMode
              ? _nearbyEvents(eventDocs)
              : filteredEvents;

          return SafeArea(
            child: RefreshIndicator(
              color: const Color(0xffFF9800),
              onRefresh: loadProfile,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _topBar(
                      profilAdi: profilAdi,
                      sehir: sehir,
                      profilFotografi: profilFotografi,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _categoryStrip(),
                  ),
                  SliverToBoxAdapter(
                    child: _heroPanel(filteredEvents.length),
                  ),
                  SliverToBoxAdapter(
                    child: _sectionTitle(
                      title: text.eventsForYou,
                      action: text.seeAll,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _eventList(
                      eventDocs: filteredEvents,
                      currentUser: currentUser,
                      snapshot: snapshot,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _sectionTitle(
                      title: text.exploreOnMap,
                      action: _nearbyMode ? text.showInCity : text.nearMe,
                      onActionTap: () => _toggleNearby(eventDocs),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _mapPreview(
                      eventDocs: mapEvents,
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 90),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: _bottomNavigationBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateEvent,
        backgroundColor: const Color(0xffFF9800),
        foregroundColor: Colors.black,
        elevation: 3,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }


  Future<void> _openCreateEvent() async {
    try {
      final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const CreateEventScreen(),
        ),
      );
      if (!mounted) return;
      if (created == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(text.eventAdded)),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text.eventScreenOpenFailed(error))),
      );
    }
  }

  Drawer _drawer({
    required String profilAdi,
    required String sehir,
    required double puan,
    required bool plus,
    required String profilFotografi,
  }) {
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        child: Column(
          children: [
            Image.asset(
              'assets/branding/dort_logo_white_orange.png',
              width: 88,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: const Color(0xffFF9800),
                  backgroundImage: (profilFotografi.isNotEmpty ||
                      (profileData['avatarUrl']?.toString().isNotEmpty ?? false))
                      ? NetworkImage(
                    profilFotografi.isNotEmpty
                        ? profilFotografi
                        : profileData['avatarUrl'].toString(),
                  )
                      : null,
                  child: profilFotografi.isEmpty &&
                      (profileData['avatarUrl']?.toString().isEmpty ?? true)
                      ? const Icon(
                    Icons.person,
                    size: 38,
                    color: Colors.black,
                  )
                      : null,
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loading ? text.loading : profilAdi,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Row(
                        children: [
                          Icon(
                            _verificationStatusIcon(),
                            size: 15,
                            color: _verificationStatusColor(),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _verificationStatusText(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _verificationStatusColor(),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 5),

                      Text(
                        "📍 $sehir   •   ⭐ ${puan.toStringAsFixed(1)}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (_hasPlayerBadge(profileData) || plus) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (_hasPlayerBadge(profileData))
                    Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xff2677E8).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color:
                          const Color(0xff2677E8).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.sports_esports_rounded,
                            size: 13,
                            color: Color(0xff2677E8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            text.playerBadge,
                            style: const TextStyle(
                              color: Color(0xff2677E8),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_hasPlayerBadge(profileData) && plus)
                    const SizedBox(width: 8),
                  if (plus) _plusBadge(),
                ],
              ),
            ],
          ],
        ),
      ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _drawerItem(
                    Icons.person_outline,
                    text.myProfile,
                        () {
                      Navigator.pop(context);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      ).then((_) {
                        loadProfile();
                      });
                    },
                  ),
                  _drawerItem(
                    Icons.verified_user_outlined,
                    text.myVerificationStatus,
                    _showVerificationStatus,
                  ),
                  _drawerItem(
                    Icons.event_note_outlined,
                    text.myEvents,
                        () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyEventsScreen(),
                        ),
                      );
                    },
                  ),
                  _drawerItem(
                    Icons.favorite_border,
                    text.favorites,
                        () {
                      Navigator.pop(context);
                      openFavorites();
                    },
                  ),
                  _drawerItem(
                    Icons.chat_bubble_outline,
                    text.messages,
                        () {
                      Navigator.pop(context);
                      openMessages();
                    },
                  ),
                  const Divider(height: 20),
                  _drawerItem(
                    Icons.storefront_outlined,
                    text.market,
                        () {
                      Navigator.pop(context);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MarketScreen(),
                        ),
                      );
                    },
                  ),
                  _drawerItem(
                    Icons.account_balance_wallet_outlined,
                    text.wallet,
                        () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()));
                    },
                  ),
                  _drawerItem(
                    Icons.settings_outlined,
                    text.settings,
                        () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _drawerItem(
                    Icons.support_agent_outlined,
                    text.support,
                        () {
                      Navigator.pop(context);
                      _showMessage(text.supportComingSoon);
                    },
                  ),
                  _drawerItem(
                    Icons.info_outline_rounded,
                    'Hakkında',
                        () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AboutScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: logout,
                  icon: const Icon(Icons.logout),
                  label: Text(text.logout),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffFF9800),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar({
    required String profilAdi,
    required String sehir,
    required String profilFotografi,
  }) {
    final String firstName = profilAdi.split(" ").first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Builder(
            builder: (context) {
              return InkWell(
                onTap: () {
                  Scaffold.of(context).openDrawer();
                },
                borderRadius: BorderRadius.circular(18),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  backgroundImage: profilFotografi.isNotEmpty
                      ? NetworkImage(profilFotografi)
                      : (profileData['avatarUrl']?.toString().trim().isNotEmpty == true
                      ? NetworkImage(profileData['avatarUrl'].toString().trim())
                      : null),
                  child: profilFotografi.isEmpty &&
                      profileData['avatarUrl']?.toString().trim().isNotEmpty != true
                      ? Icon(
                    Icons.person,
                    color: Theme.of(context).colorScheme.onSurface,
                  )
                      : null,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text.hello(firstName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xffFF9800),
                      size: 16,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: InkWell(
                        onTap: _selectActiveCity,
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                sehir,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 17),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseAuth.instance.currentUser == null
                ? null
                : FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser!.uid)
                .collection('notifications')
                .where('read', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: openNotifications,
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                    ),
                    icon: const Icon(Icons.notifications_none),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 0,
                      top: -2,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(count > 99 ? '99+' : '$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _categoryStrip() {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final String category = categories[index];
          final bool selected = category == selectedCategory;

          return ChoiceChip(
            label: Text(category),
            selected: selected,
            showCheckmark: false,
            selectedColor: const Color(0xff111827),
            backgroundColor: Theme.of(context).colorScheme.surface,
            side: BorderSide(
              color: selected
                  ? const Color(0xff111827)
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
            labelStyle: TextStyle(
              color: selected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
            onSelected: (_) {
              if (category == text.allCategory) {
                _showAllGames();
              } else {
                setState(() {
                  selectedCategory = category;
                });
              }
            },
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 9),
        itemCount: categories.length,
      ),
    );
  }

  Widget _heroPanel(int eventCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xff111827),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text.whatPlayToday,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  text.activeEvents(eventCount),
                  style: const TextStyle(
                    color: Color(0xffD1D5DB),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: const Color(0xffFF9800),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.sports_handball_rounded,
              color: Colors.black,
              size: 38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle({
    required String title,
    required String action,
    VoidCallback? onActionTap,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          InkWell(
            onTap: onActionTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: Text(
                action,
                style: const TextStyle(
                  color: Color(0xffFF9800),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventList({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> eventDocs,
    required User? currentUser,
    required AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
  }) {
    if (snapshot.hasError) {
      return _messageCard(text.eventsLoadError);
    }

    if (snapshot.connectionState == ConnectionState.waiting && eventDocs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(
            color: Color(0xffFF9800),
          ),
        ),
      );
    }

    if (eventDocs.isEmpty) {
      return _messageCard(text.noEventsInCategory);
    }

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> firstEvents =
    eventDocs.take(6).toList();

    return SizedBox(
      height: 382,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: firstEvents.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final QueryDocumentSnapshot<Map<String, dynamic>> document =
          firstEvents[index];

          return _eventCard(
            eventId: document.id,
            event: document.data(),
            currentUser: currentUser,
          );
        },
      ),
    );
  }

  Widget _eventCard({
    required String eventId,
    required Map<String, dynamic> event,
    required User? currentUser,
  }) {
    final EventModel eventModel = EventModel.fromMap(
      event,
      documentId: eventId,
    );

    final String game = eventModel.resolvedGameName;
    final String categoryName =
        eventModel.resolvedCategoryName;
    final String gameIdOrName =
    eventModel.resolvedGameId.isNotEmpty
        ? eventModel.resolvedGameId
        : eventModel.resolvedGameName;

    final UserModel? currentUserModel =
    currentUser == null
        ? null
        : UserModel.fromMap(
      profileData,
      documentId: currentUser.uid,
    );

    final bool profileCompatible =
        currentUserModel?.hasGame(gameIdOrName) ?? false;

    final String city = event["sehir"]?.toString().trim() ?? "";
    final String district = event["ilce"]?.toString().trim() ?? "";
    final String locationText = [city, district]
        .where((part) => part.isNotEmpty)
        .join(" - ");

    final String playerText =
    event["oyuncuSayisiMetni"]?.toString().trim().isNotEmpty == true
        ? event["oyuncuSayisiMetni"].toString().trim()
        : text.playerCount(event["oyuncuSayisi"] ?? 1);

    final DateTime eventDate =
        eventModel.resolvedStartAt;

    final String creatorUid = event["olusturanUid"]?.toString() ?? "";
    final List<dynamic> participants = List<dynamic>.from(event["katilanlar"] ?? []);

    final bool isCreator = currentUser?.uid == creatorUid;
    final bool hasJoined =
        currentUser != null && participants.contains(currentUser.uid);
    final bool isJoining = joiningEventIds.contains(eventId);
    final bool isFavorite = favoriteEventIds.contains(eventId);
    final bool plusEvent = event["plus"] == true || event["olusturanPlus"] == true;

    final double cardWidth = min(
      310,
      MediaQuery.sizeOf(context).width - 56,
    );

    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        border: plusEvent
            ? Border.all(
          color: const Color(0xffFFB300),
          width: 1.4,
        )
            : Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            height: 92,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _gameColor(game).withValues(alpha: 0.92),
                  _gameColor(game).withValues(alpha: 0.58),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 18,
                  top: 16,
                  child: Text(
                    _gameEmoji(game),
                    style: const TextStyle(fontSize: 42),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: InkWell(
                    onTap: () => toggleFavorite(eventId),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.90),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.redAccent : const Color(0xff111827),
                        size: 21,
                      ),
                    ),
                  ),
                ),
                if (plusEvent)
                  Positioned(
                    left: 16,
                    bottom: 12,
                    child: _miniPlusBadge(),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _cleanGameName(game),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (categoryName.isNotEmpty)
                        _eventStatusChip(
                          categoryName,
                          Icons.category_outlined,
                          Theme.of(context)
                              .colorScheme
                              .secondaryContainer,
                          Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                      if (!isCreator)
                        _eventStatusChip(
                          profileCompatible
                              ? text.profileCompatible
                              : text.addToProfile,
                          profileCompatible
                              ? Icons.check_circle_outline
                              : Icons.person_add_alt_1_outlined,
                          profileCompatible
                              ? const Color(0xffDCFCE7)
                              : const Color(0xffFEF3C7),
                          profileCompatible
                              ? const Color(0xff166534)
                              : const Color(0xff92400E),
                        ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  _tinyInfo(
                    Icons.location_on_rounded,
                    locationText.isEmpty ? text.locationNotSpecified : locationText,
                  ),
                  const SizedBox(height: 4),
                  _tinyInfo(
                    Icons.schedule_rounded,
                    _formatEventDate(eventDate),
                  ),
                  const SizedBox(height: 4),
                  _tinyInfo(
                    Icons.timelapse_rounded,
                    eventModel.durationText,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "👥 $playerText aranıyor · Katılan: ${participants.length}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xffFF9800),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${eventModel.resolvedCustomerTotal.toStringAsFixed(0)} ₺',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildEventOwnerLine(
                    event,
                    isCreator: isCreator,
                  ),
                  const SizedBox(height: 8),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => openEventDetail(eventId, event),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.onSurface,
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.outlineVariant,
                            ),
                            minimumSize: const Size(0, 42),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Text(text.details),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                          isCreator ||
                              hasJoined ||
                              isJoining
                              ? null
                              : profileCompatible
                              ? () => joinEvent(
                            eventId,
                            gameIdOrName:
                            gameIdOrName,
                          )
                              : () => _showMessage(
                            text.addGameBeforeApply(eventModel.resolvedGameName),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff111827),
                            minimumSize: const Size(0, 42),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            disabledBackgroundColor: const Color(0xffE5E7EB),
                            foregroundColor: Colors.white,
                            disabledForegroundColor: const Color(0xff6B7280),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: isJoining
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : Text(
                            isCreator
                                ? text.yours
                                : hasJoined
                                ? text.applied
                                : profileCompatible
                                ? text.apply
                                : text.addToProfile,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildEventOwnerLine(
      Map<String, dynamic> event, {
        required bool isCreator,
      }) {
    final String creatorUid =
        event['olusturanUid']?.toString().trim() ??
            event['creatorUid']?.toString().trim() ??
            event['ownerUid']?.toString().trim() ??
            '';

    final String fallbackName =
        event['olusturanProfilAdi']?.toString().trim() ??
            event['creatorName']?.toString().trim() ??
            event['ownerName']?.toString().trim() ??
            text.user;

    final String fallbackImageUrl = resolveUserImageUrl(event);

    if (creatorUid.isEmpty) {
      return _buildResolvedEventOwnerLine(
        creatorUid: creatorUid,
        isCreator: isCreator,
        displayName: fallbackName,
        imageUrl: fallbackImageUrl,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('public_profiles')
          .doc(creatorUid)
          .snapshots(),
      builder: (
          BuildContext context,
          AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
        final Map<String, dynamic> profile =
            snapshot.data?.data() ?? <String, dynamic>{};

        final String liveName =
        profile['profilAdi']?.toString().trim().isNotEmpty == true
            ? profile['profilAdi'].toString().trim()
            : profile['displayName']?.toString().trim().isNotEmpty == true
            ? profile['displayName'].toString().trim()
            : fallbackName;

        final String liveImageUrl = resolveUserImageUrl(profile).isNotEmpty
            ? resolveUserImageUrl(profile)
            : fallbackImageUrl;

        return _buildResolvedEventOwnerLine(
          creatorUid: creatorUid,
          isCreator: isCreator,
          displayName: liveName,
          imageUrl: liveImageUrl,
        );
      },
    );
  }

  Widget _buildResolvedEventOwnerLine({
    required String creatorUid,
    required bool isCreator,
    required String displayName,
    required String imageUrl,
  }) {
    final String safeName =
    displayName.trim().isEmpty ? text.user : displayName.trim();

    return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isCreator || creatorUid.isEmpty
            ? null
            : () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PublicProfileScreen(
                userId: creatorUid,
              ),
            ),
          );
        },
        child: Row(
          children: [
        UserAvatar(
          displayName: safeName,
          imageUrl: imageUrl,
          radius: 17,
          backgroundColor:
          Theme.of(context).colorScheme.secondaryContainer,
          foregroundColor:
          Theme.of(context).colorScheme.onSecondaryContainer,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCreator ? text.you : safeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                text.eventOwner,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
          ],
        ),
    );
  }

  Widget _eventStatusChip(
      String text,
      IconData icon,
      Color backgroundColor,
      Color foregroundColor,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: foregroundColor,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapPreview({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> eventDocs,
  }) {
    final LatLng center = _mapCenter(eventDocs);

    return Container(
      height: 330,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 11.5,
              minZoom: 4,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate:
                "https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png",
                userAgentPackageName: "com.dorduncu.app",
                maxNativeZoom: 20,
              ),
              MarkerLayer(
                markers: eventDocs.map((document) {
                  final Map<String, dynamic> event = document.data();
                  final LatLng point = _eventPoint(event, document.id);

                  return Marker(
                    point: point,
                    width: 74,
                    height: 62,
                    child: GestureDetector(
                      onTap: () => _showEventPreview(document.id, event),
                      child: _mapBubble(event),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          Positioned(
            left: 16,
            top: 16,
            right: 16,
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: openExploreMap,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.map_outlined,
                              color: Color(0xff111827),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                text.exploreEventsOnMap,
                                style: TextStyle(
                                  color: Color(0xff111827),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Icon(Icons.arrow_forward_rounded, color: Color(0xff111827)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapBubble(Map<String, dynamic> event) {
    final String game = event["oyun"]?.toString() ?? text.event;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _gameColor(game),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _gameColor(game).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            _gameEmoji(game),
            style: const TextStyle(fontSize: 18),
          ),
        ),
        CustomPaint(
          size: const Size(14, 8),
          painter: _TrianglePainter(color: _gameColor(game)),
        ),
      ],
    );
  }

  Widget _tinyInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xff6B7280),
          size: 15,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniPlusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xffFFF6C7),
            Color(0xffFFB300),
            Color(0xffF57C00),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white,
          width: 1,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.diamond,
            color: Color(0xff3A2200),
            size: 13,
          ),
          SizedBox(width: 4),
          Text(
            "PLUS",
            style: TextStyle(
              color: Color(0xff3A2200),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _plusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xffFFF6C7),
            Color(0xffFFD54F),
            Color(0xffFFB300),
            Color(0xffF57C00),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xffFFF9DE),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xffFFB300).withValues(alpha: 0.45),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.diamond,
            size: 18,
            color: Color(0xff3A2200),
          ),
          SizedBox(width: 7),
          Text(
            "DÖRDÜNCÜ",
            style: TextStyle(
              color: Color(0xff3A2200),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(width: 5),
          Text(
            "PLUS",
            style: TextStyle(
              color: Color(0xff3A2200),
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(
      IconData icon,
      String title,
      VoidCallback onTap,
      ) {
    return ListTile(
      leading: Icon(
        icon,
        color: const Color(0xffFF9800),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _messageCard(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _bottomNavigationBar() {
    return BottomAppBar(
      color: Theme.of(context).colorScheme.surface,
      elevation: 10,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SizedBox(
        height: 66,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(0, Icons.home_rounded, text.home),
            _navItem(1, Icons.explore_outlined, text.explore),
            const SizedBox(width: 42),
            _navItem(2, Icons.chat_bubble_outline, text.message),
            _navItem(3, Icons.person_outline, text.profile),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final bool active = selectedNavIndex == index;

    return InkWell(
      onTap: () {
        if (index == 2) {
          openMessages();
          return;
        }

        if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProfileScreen(),
            ),
          ).then((_) {
            loadProfile();
          });
          return;
        }

        if (index == 1) {
          openExploreMap();
          return;
        }

        setState(() {
          selectedNavIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: active ? const Color(0xffFF9800) : const Color(0xff9CA3AF),
              size: 23,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: active ? const Color(0xffFF9800) : const Color(0xff9CA3AF),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredEvents(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    final now = DateTime.now();
    final activeCity = _normalize(_activeCity);

    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> filtered = docs.where((doc) {
      final data = doc.data();
      final status = data["durum"]?.toString().toLowerCase() ?? "aktif";
      if (status != "aktif") return false;

      final timestamp = data["tarih"];
      if (timestamp is! Timestamp || !timestamp.toDate().isAfter(now)) {
        return false;
      }

      final needed = (data["oyuncuSayisi"] as num?)?.toInt() ?? 1;
      final participants = List<dynamic>.from(data["katilanlar"] ?? const []);
      final creatorUid = data["olusturanUid"]?.toString() ?? "";
      final joinedWithoutCreator = participants.where((uid) => uid.toString() != creatorUid).length;
      if (joinedWithoutCreator >= needed) return false;

      final eventCity = _normalize(data["sehir"]?.toString() ?? "");
      if (activeCity.isNotEmpty && eventCity != activeCity) return false;

      return true;
    });

    if (selectedNavIndex == 1) {
      filtered = filtered.where((doc) => favoriteEventIds.contains(doc.id));
    }

    if (selectedCategory != "Tümü") {
      final category = _normalize(_cleanGameName(selectedCategory));
      filtered = filtered.where((doc) {
        final game = _normalize(_cleanGameName(doc.data()["oyun"]?.toString() ?? ""));
        return game.contains(category) || category.contains(game);
      });
    }

    final result = filtered.toList();
    result.sort((a, b) {
      final aDate = (a.data()["tarih"] as Timestamp).toDate();
      final bDate = (b.data()["tarih"] as Timestamp).toDate();
      return aDate.compareTo(bDate);
    });
    return result;
  }

  String get _activeCity {
    final selected = profileData["aktifSehir"]?.toString().trim() ?? "";
    if (selected.isNotEmpty) return selected;
    return profileData["sehir"]?.toString().trim() ?? "";
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll("\u0307", "")
        .replaceAll("ı", "i")
        .replaceAll("ğ", "g")
        .replaceAll("ü", "u")
        .replaceAll("ş", "s")
        .replaceAll("ö", "o")
        .replaceAll("ç", "c")
        .trim();
  }

  bool _hasPlayerBadge(Map<String, dynamic> profile) {
    return profile["oyuncuRozeti"] == true;
  }

  static const List<String> _turkiyeCities = [
    "Adana",
    "Adıyaman",
    "Afyonkarahisar",
    "Ağrı",
    "Aksaray",
    "Amasya",
    "Ankara",
    "Antalya",
    "Ardahan",
    "Artvin",
    "Aydın",
    "Balıkesir",
    "Bartın",
    "Batman",
    "Bayburt",
    "Bilecik",
    "Bingöl",
    "Bitlis",
    "Bolu",
    "Burdur",
    "Bursa",
    "Çanakkale",
    "Çankırı",
    "Çorum",
    "Denizli",
    "Diyarbakır",
    "Düzce",
    "Edirne",
    "Elazığ",
    "Erzincan",
    "Erzurum",
    "Eskişehir",
    "Gaziantep",
    "Giresun",
    "Gümüşhane",
    "Hakkâri",
    "Hatay",
    "Iğdır",
    "Isparta",
    "İstanbul",
    "İzmir",
    "Kahramanmaraş",
    "Karabük",
    "Karaman",
    "Kars",
    "Kastamonu",
    "Kayseri",
    "Kırıkkale",
    "Kırklareli",
    "Kırşehir",
    "Kilis",
    "Kocaeli",
    "Konya",
    "Kütahya",
    "Malatya",
    "Manisa",
    "Mardin",
    "Mersin",
    "Muğla",
    "Muş",
    "Nevşehir",
    "Niğde",
    "Ordu",
    "Osmaniye",
    "Rize",
    "Sakarya",
    "Samsun",
    "Şanlıurfa",
    "Siirt",
    "Sinop",
    "Sivas",
    "Şırnak",
    "Tekirdağ",
    "Tokat",
    "Trabzon",
    "Tunceli",
    "Uşak",
    "Van",
    "Yalova",
    "Yozgat",
    "Zonguldak"
  ];

  Future<void> _selectActiveCity() async {
    final selectedCity = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.78,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
              itemCount: _turkiyeCities.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final city = _turkiyeCities[index];
                final selected = _normalize(city) == _normalize(_activeCity);
                return ListTile(
                  title: Text(city),
                  leading: const Icon(Icons.location_city_outlined),
                  trailing: selected
                      ? const Icon(Icons.check_circle, color: Color(0xffFF9800))
                      : null,
                  onTap: () => Navigator.pop(sheetContext, city),
                );
              },
            ),
          ),
        );
      },
    );

    if (selectedCity == null || !mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection("users").doc(user.uid).set(
        {
          "aktifSehir": selectedCity,
          "guncellemeTarihi": FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (!mounted) return;
      setState(() {
        profileData["aktifSehir"] = selectedCity;
        _nearbyMode = false;
        _nearbyCenter = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) mapController.move(_cityCenter(selectedCity), 10.5);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text.cityChangeFailed(error))),
      );
    }
  }

  LatLng _cityCenter(String city) {
    const centers = <String, LatLng>{
      "adana": LatLng(37.0, 35.3213),
      "adiyaman": LatLng(37.7648, 38.2786),
      "afyonkarahisar": LatLng(38.7507, 30.5567),
      "agri": LatLng(39.7191, 43.0503),
      "aksaray": LatLng(38.3687, 34.037),
      "amasya": LatLng(40.6499, 35.8353),
      "ankara": LatLng(39.9334, 32.8597),
      "antalya": LatLng(36.8969, 30.7133),
      "ardahan": LatLng(41.1105, 42.7022),
      "artvin": LatLng(41.1828, 41.8183),
      "aydin": LatLng(37.856, 27.8416),
      "balikesir": LatLng(39.6484, 27.8826),
      "bartin": LatLng(41.6344, 32.3375),
      "batman": LatLng(37.8812, 41.1351),
      "bayburt": LatLng(40.2552, 40.2249),
      "bilecik": LatLng(40.0567, 30.0665),
      "bingol": LatLng(38.8854, 40.4966),
      "bitlis": LatLng(38.3938, 42.1232),
      "bolu": LatLng(40.576, 31.5788),
      "burdur": LatLng(37.7203, 30.2908),
      "bursa": LatLng(40.1885, 29.061),
      "canakkale": LatLng(40.1553, 26.4142),
      "cankiri": LatLng(40.6013, 33.6134),
      "corum": LatLng(40.5506, 34.9556),
      "denizli": LatLng(37.7765, 29.0864),
      "diyarbakir": LatLng(37.9144, 40.2306),
      "duzce": LatLng(40.8438, 31.1565),
      "edirne": LatLng(41.6818, 26.5623),
      "elazig": LatLng(38.681, 39.2264),
      "erzincan": LatLng(39.75, 39.5),
      "erzurum": LatLng(39.9, 41.27),
      "eskisehir": LatLng(39.7767, 30.5206),
      "gaziantep": LatLng(37.0662, 37.3833),
      "giresun": LatLng(40.9128, 38.3895),
      "gumushane": LatLng(40.4386, 39.5086),
      "hakkâri": LatLng(37.5744, 43.7408),
      "hatay": LatLng(36.2023, 36.1613),
      "igdir": LatLng(39.888, 44.0048),
      "isparta": LatLng(37.7648, 30.5566),
      "istanbul": LatLng(41.0082, 28.9784),
      "izmir": LatLng(38.4237, 27.1428),
      "kahramanmaras": LatLng(37.5753, 36.9228),
      "karabuk": LatLng(41.2061, 32.6204),
      "karaman": LatLng(37.1759, 33.2287),
      "kars": LatLng(40.6013, 43.0975),
      "kastamonu": LatLng(41.3887, 33.7827),
      "kayseri": LatLng(38.7312, 35.4787),
      "kirikkale": LatLng(39.8468, 33.5153),
      "kirklareli": LatLng(41.7333, 27.2167),
      "kirsehir": LatLng(39.1425, 34.1709),
      "kilis": LatLng(36.7184, 37.1212),
      "kocaeli": LatLng(40.8533, 29.8815),
      "konya": LatLng(37.8667, 32.4833),
      "kutahya": LatLng(39.4167, 29.9833),
      "malatya": LatLng(38.3552, 38.3095),
      "manisa": LatLng(38.6191, 27.4289),
      "mardin": LatLng(37.3212, 40.7245),
      "mersin": LatLng(36.8, 34.6333),
      "mugla": LatLng(37.2153, 28.3636),
      "mus": LatLng(38.9462, 41.7539),
      "nevsehir": LatLng(38.6939, 34.6857),
      "nigde": LatLng(37.9667, 34.6833),
      "ordu": LatLng(40.9839, 37.8764),
      "osmaniye": LatLng(37.0742, 36.2478),
      "rize": LatLng(41.0201, 40.5234),
      "sakarya": LatLng(40.7569, 30.3781),
      "samsun": LatLng(41.2867, 36.33),
      "sanliurfa": LatLng(37.1674, 38.7955),
      "siirt": LatLng(37.9333, 41.95),
      "sinop": LatLng(42.0231, 35.1531),
      "sivas": LatLng(39.7477, 37.0179),
      "sirnak": LatLng(37.4187, 42.4918),
      "tekirdag": LatLng(40.9833, 27.5167),
      "tokat": LatLng(40.3167, 36.55),
      "trabzon": LatLng(41.0015, 39.7178),
      "tunceli": LatLng(39.1079, 39.5401),
      "usak": LatLng(38.6823, 29.4082),
      "van": LatLng(38.4891, 43.4089),
      "yalova": LatLng(40.65, 29.2667),
      "yozgat": LatLng(39.8181, 34.8147),
      "zonguldak": LatLng(41.4564, 31.7987),
    };
    return centers[_normalize(city)] ?? const LatLng(39.0, 35.0);
  }


  Future<void> _toggleNearby(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs,
      ) async {
    if (_nearbyMode) {
      setState(() {
        _nearbyMode = false;
        _nearbyCenter = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) mapController.move(_cityCenter(_activeCity), 10.5);
      });
      return;
    }

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(text.locationPermissionRequired),
          ),
        );
        return;
      }

      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(text.enableLocationServices)),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      final center = LatLng(position.latitude, position.longitude);
      setState(() {
        _nearbyMode = true;
        _nearbyCenter = center;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) mapController.move(center, 12.5);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text.locationFailed(error))),
      );
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _nearbyEvents(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    final center = _nearbyCenter;
    if (center == null) return const [];
    final now = DateTime.now();
    final results = docs.where((doc) {
      final data = doc.data();
      final status = data['durum']?.toString().toLowerCase() ?? 'aktif';
      if (status != 'aktif') return false;
      final timestamp = data['tarih'];
      if (timestamp is! Timestamp || !timestamp.toDate().isAfter(now)) {
        return false;
      }
      final lat =
          (data['approxLatitude'] as num?)?.toDouble() ??
              (data['latitude'] as num?)?.toDouble() ??
              0;
      final lng =
          (data['approxLongitude'] as num?)?.toDouble() ??
              (data['longitude'] as num?)?.toDouble() ??
              0;
      if (lat == 0 || lng == 0) return false;
      final distance = Geolocator.distanceBetween(
        center.latitude,
        center.longitude,
        lat,
        lng,
      );
      return distance <= 50000;
    }).toList();
    results.sort((a, b) {
      final aData = a.data();
      final bData = b.data();
      final aDistance = Geolocator.distanceBetween(
        center.latitude,
        center.longitude,
        ((aData['approxLatitude'] ?? aData['latitude']) as num).toDouble(),
        ((aData['approxLongitude'] ?? aData['longitude']) as num).toDouble(),
      );
      final bDistance = Geolocator.distanceBetween(
        center.latitude,
        center.longitude,
        ((bData['approxLatitude'] ?? bData['latitude']) as num).toDouble(),
        ((bData['approxLongitude'] ?? bData['longitude']) as num).toDouble(),
      );
      return aDistance.compareTo(bDistance);
    });
    return results;
  }

  Future<void> _showAllGames() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          children: [
            const ListTile(
              title: Text(
                "Tüm oyun ve spor dalları",
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
            ),
            ...allGames.map(
                  (game) => ListTile(
                title: Text(game),
                trailing: selectedCategory == game
                    ? const Icon(Icons.check_circle, color: Color(0xffFF9800))
                    : null,
                onTap: () => Navigator.pop(sheetContext, game),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        selectedCategory = selected;
      });
    }
  }

  void _showEventPreview(String eventId, Map<String, dynamic> event) {
    final String game = event["oyun"]?.toString() ?? text.event;
    final String city = event["sehir"]?.toString().trim() ?? "";
    final String district = event["ilce"]?.toString().trim() ?? "";
    final String publicLocation = [city, district]
        .where((part) => part.isNotEmpty)
        .join(" - ");
    final DateTime? eventDate =
    event["tarih"] is Timestamp ? (event["tarih"] as Timestamp).toDate() : null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _cleanGameName(game),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "📍 ${publicLocation.isEmpty ? "Konum belirtilmedi" : publicLocation}\n🕒 ${_formatEventDate(eventDate)}",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        openEventDetail(eventId, event);
                      },
                      child: const Text("Detay"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        joinEvent(eventId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff111827),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Katıl"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  LatLng _mapCenter(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final List<LatLng> points = docs.map((doc) => _eventPoint(doc.data(), doc.id)).toList();

    if (points.isEmpty) return const LatLng(41.0082, 28.9784);

    final double avgLat =
        points.map((point) => point.latitude).reduce((a, b) => a + b) / points.length;

    final double avgLng =
        points.map((point) => point.longitude).reduce((a, b) => a + b) / points.length;

    return LatLng(avgLat, avgLng);
  }

  LatLng _eventPoint(Map<String, dynamic> event, String eventId) {
    final double latitude =
        (event['approxLatitude'] as num?)?.toDouble() ??
            (event['latitude'] as num?)?.toDouble() ??
            0.0;
    final double longitude =
        (event['approxLongitude'] as num?)?.toDouble() ??
            (event['longitude'] as num?)?.toDouble() ??
            0.0;

    if (latitude != 0 && longitude != 0) {
      return LatLng(latitude, longitude);
    }

    return const LatLng(41.0082, 28.9784);
  }

  Color _gameColor(String game) {
    final String lower = game.toLowerCase();

    if (lower.contains("futbol") || lower.contains("halı")) {
      return const Color(0xff22C55E);
    }

    if (lower.contains("basket")) return const Color(0xffF97316);
    if (lower.contains("tenis")) return const Color(0xff3B82F6);
    if (lower.contains("voley")) return const Color(0xff8B5CF6);
    if (lower.contains("batak")) return const Color(0xff111827);
    if (lower.contains("satranç")) return const Color(0xff6B7280);
    if (lower.contains("bilardo")) return const Color(0xff059669);

    return const Color(0xffFF9800);
  }

  String _gameEmoji(String game) {
    final String lower = game.toLowerCase();

    if (lower.contains("futbol") || lower.contains("halı")) return "⚽";
    if (lower.contains("basket")) return "🏀";
    if (lower.contains("tenis")) return "🎾";
    if (lower.contains("voley")) return "🏐";
    if (lower.contains("batak")) return "♠️";
    if (lower.contains("okey")) return "🎴";
    if (lower.contains("101")) return "🀄";
    if (lower.contains("bilardo")) return "🎱";
    if (lower.contains("satranç")) return "♟️";

    return "🎮";
  }

  String _cleanGameName(String game) {
    return game.replaceAll(
      RegExp(r"^[^\p{L}\p{N}]+", unicode: true),
      "",
    ).trim();
  }

  String _formatEventDate(DateTime? date) {
    if (date == null) return "Tarih belirtilmedi";

    final DateTime now = DateTime.now();

    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime eventDay = DateTime(date.year, date.month, date.day);

    final int difference = eventDay.difference(today).inDays;
    final String hour = date.hour.toString().padLeft(2, "0");
    final String minute = date.minute.toString().padLeft(2, "0");

    if (difference == 0) return "Bugün • $hour:$minute";
    if (difference == 1) return "Yarın • $hour:$minute";

    const List<String> months = [
      "Ocak",
      "Şubat",
      "Mart",
      "Nisan",
      "Mayıs",
      "Haziran",
      "Temmuz",
      "Ağustos",
      "Eylül",
      "Ekim",
      "Kasım",
      "Aralık",
    ];

    return "${date.day} ${months[date.month - 1]} • $hour:$minute";
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  const _TrianglePainter({
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;

    final Path path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _HomeText {
  const _HomeText(this.language);
  final AppLanguage language;
  String v(String tr, String en, String de) {
    switch (language) {
      case AppLanguage.turkish: return tr;
      case AppLanguage.english: return en;
      case AppLanguage.german: return de;
    }
  }
  String get sessionEnded => v('Oturum Sonlandırıldı','Session Ended','Sitzung beendet');
  String get sessionEndedMessage => v('Hesabın başka bir cihazda açıldığı için bu cihazdaki oturumun sonlandırıldı.','Your session on this device ended because your account was opened on another device.','Deine Sitzung auf diesem Gerät wurde beendet, weil dein Konto auf einem anderen Gerät geöffnet wurde.');
  String get loginToApply => v('Etkinliğe başvurmak için giriş yapmalısın.','You must sign in to apply to an event.','Du musst dich anmelden, um dich für eine Veranstaltung zu bewerben.');
  String get completePlayerProfile => v('Etkinliklere başvurmak için oyuncu profilini tamamlayıp Oyuncu Rozeti almalısın.','Complete your player profile and earn the Player Badge before applying to events.','Vervollständige dein Spielerprofil und erhalte das Spielerabzeichen, bevor du dich bewirbst.');
  String addGameBeforeApply(Object game) => v('Başvurmadan önce $game oyununu profiline eklemelisin.','Add $game to your profile before applying.','Füge $game deinem Profil hinzu, bevor du dich bewirbst.');
  String get applicationSent => v('Başvurun etkinlik sahibine gönderildi.','Your application was sent to the event owner.','Deine Bewerbung wurde an den Veranstalter gesendet.');
  String get applicationError => v('Etkinliğe başvururken bir hata oluştu.','An error occurred while applying to the event.','Beim Bewerben ist ein Fehler aufgetreten.');
  String applicationErrorWith(Object e) => '$applicationError: $e';
  String get loginToFavorite => v('Favorilere eklemek için giriş yapmalısın.','You must sign in to add favorites.','Du musst dich anmelden, um Favoriten hinzuzufügen.');
  String get favoriteSaveFailed => v('Favori işlemi kaydedilemedi.','The favorite action could not be saved.','Die Favoritenaktion konnte nicht gespeichert werden.');
  String get plusMember => v('Dördüncü Plus Üye','Dördüncü Plus Member','Dördüncü Plus-Mitglied');
  String get normalMember => v('Normal Üye','Standard Member','Standardmitglied');
  String get accountVerified => v('Hesabın doğrulanmış durumda.','Your account is verified.','Dein Konto ist verifiziert.');
  String get documentsPending => v('Belgelerin inceleniyor. Sonuçlandığında hesabında gösterilecek.','Your documents are being reviewed. The result will appear in your account.','Deine Dokumente werden geprüft. Das Ergebnis wird in deinem Konto angezeigt.');
  String get verificationRejected => v('Doğrulama başvurun reddedildi. Belgelerini daha sonra yeniden gönderebilirsin.','Your verification request was rejected. You can submit your documents again later.','Dein Verifizierungsantrag wurde abgelehnt. Du kannst deine Dokumente später erneut senden.');
  String get verificationNotCompleted => v('Oyuncu doğrulamasını henüz tamamlamadın.','You have not completed player verification yet.','Du hast die Spielerverifizierung noch nicht abgeschlossen.');
  String get ok => v('Tamam','OK','OK');
  String get locationNotAdded => v('Konum eklenmedi','Location not added','Standort nicht hinzugefügt');
  String get allCategory => v('Tümü','All','Alle');
  String get eventsForYou => v('Senin için etkinlikler','Events for you','Veranstaltungen für dich');
  String get seeAll => v('Tümünü gör','See all','Alle anzeigen');
  String get exploreOnMap => v('Haritada keşfet','Explore on map','Auf der Karte entdecken');
  String get showInCity => v('Şehirde göster','Show in city','In der Stadt anzeigen');
  String get nearMe => v('Yakınımda','Near me','In meiner Nähe');
  String get eventAdded => v('Etkinlik ana sayfaya eklendi.','The event was added to the home page.','Die Veranstaltung wurde zur Startseite hinzugefügt.');
  String eventScreenOpenFailed(Object e) => v('Etkinlik ekranı açılamadı: $e','Could not open the event screen: $e','Die Veranstaltungsseite konnte nicht geöffnet werden: $e');
  String get loading => v('Yükleniyor...','Loading...','Wird geladen...');
  String get playerBadge => v('OYUNCU','PLAYER','SPIELER');
  String get myProfile => v('Profilim','My Profile','Mein Profil');
  String get myVerificationStatus => v('Doğrulama Durumum','My Verification Status','Mein Verifizierungsstatus');
  String get myEvents => v('Etkinliklerim','My Events','Meine Veranstaltungen');
  String get favorites => v('Favoriler','Favorites','Favoriten');
  String get messages => v('Mesajlar','Messages','Nachrichten');
  String get market => v(
    'Market',
    'Market',
    'Markt',
  );

  String get marketComingSoon => v(
    'Market yakında kullanıma açılacak.',
    'The Market will be available soon.',
    'Der Markt wird bald verfügbar sein.',
  );
  String get wallet => v('Cüzdan','Wallet','Wallet');
  String get settings => v('Ayarlar','Settings','Einstellungen');
  String get support => v('Destek','Support','Support');
  String get supportComingSoon => v('Destek ekranı daha sonra eklenecek.','The support screen will be added later.','Der Support-Bildschirm wird später hinzugefügt.');
  String get logout => v('Çıkış Yap','Sign Out','Abmelden');
  String hello(String name) => v('Merhaba, $name 👋','Hello, $name 👋','Hallo, $name 👋');
  String get whatPlayToday => v('Bugün ne oynamak istersin?','What would you like to play today?','Was möchtest du heute spielen?');
  String activeEvents(int count) => v('$count aktif etkinlik seni bekliyor.','$count active events are waiting for you.','$count aktive Veranstaltungen warten auf dich.');
  String get eventsLoadError => v('Etkinlikler yüklenirken bir hata oluştu.','An error occurred while loading events.','Beim Laden der Veranstaltungen ist ein Fehler aufgetreten.');
  String get noEventsInCategory => v('Bu kategori için henüz etkinlik yok.','There are no events in this category yet.','In dieser Kategorie gibt es noch keine Veranstaltungen.');
  String playerCount(Object count) => v('$count oyuncu','$count players','$count Spieler');
  String get profileCompatible => v('Profilinle uyumlu','Matches your profile','Passt zu deinem Profil');
  String get addToProfile => v('Profiline ekle','Add to profile','Zum Profil hinzufügen');
  String get locationNotSpecified => v('Konum belirtilmedi','Location not specified','Standort nicht angegeben');
  String get details => v('Detay','Details','Details');
  String get yours => v('Senin','Yours','Deins');
  String get applied => v('Başvurdun','Applied','Beworben');
  String get apply => v('Başvur','Apply','Bewerben');
  String get user => v('Kullanıcı','User','Benutzer');
  String get you => v('Sen','You','Du');
  String get eventOwner => v('Etkinlik Sahibi','Event Owner','Veranstalter');
  String get exploreEventsOnMap => v('Etkinlikleri haritada keşfet','Explore events on the map','Veranstaltungen auf der Karte entdecken');
  String get event => v('Etkinlik','Event','Veranstaltung');
  String get home => v('Ana','Home','Start');
  String get explore => v('Keşfet','Explore','Entdecken');
  String get message => v('Mesaj','Message','Nachricht');
  String get profile => v('Profil','Profile','Profil');
  String get locationPermissionRequired => v('Yakındaki etkinlikler için konum izni vermelisin.','Allow location access to see nearby events.','Erlaube den Standortzugriff, um Veranstaltungen in der Nähe zu sehen.');
  String get enableLocationServices => v('Telefonunun konum hizmetini açmalısın.','Turn on location services on your phone.','Aktiviere die Standortdienste deines Telefons.');
  String locationFailed(Object e) => v('Konum alınamadı: $e','Could not get location: $e','Standort konnte nicht ermittelt werden: $e');
  String cityChangeFailed(Object e) => v('Şehir değiştirilemedi: $e','Could not change city: $e','Stadt konnte nicht geändert werden: $e');
}
