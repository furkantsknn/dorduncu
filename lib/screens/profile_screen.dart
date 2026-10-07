import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/friend_service.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'market_screen.dart';
import 'friends_screen.dart';
import 'friend_requests_screen.dart';
import 'user_search_screen.dart';
import 'public_profile_screen.dart';
import 'my_events_screen.dart';
import 'settings_screen.dart';
import 'verification_screen.dart';
import '../widgets/app_admin_menu_entry.dart';
import '../widgets/market_badge_strip.dart';
import 'user_badges_screen.dart';

String _profileText(
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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  String? _errorMessage;
  Map<String, dynamic> _profileData = <String, dynamic>{};
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final Map<String, dynamic> data = await UserService.getProfileData();

      if (!mounted) {
        return;
      }

      final User? firebaseUser = FirebaseAuth.instance.currentUser;

      if (firebaseUser == null) {
        throw StateError(
          _profileText(
            context,
            tr: 'Profil bilgilerini görüntülemek için giriş yapmalısın.',
            en: 'You must sign in to view your profile information.',
            de: 'Du musst dich anmelden, um deine Profilinformationen anzuzeigen.',
          ),
        );
      }

      final UserModel user = UserModel.fromMap(
        data,
        documentId: firebaseUser.uid,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _profileData = data;
        _user = user;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage =
            '${_profileText(context, tr: 'Profil bilgileri yüklenemedi', en: 'Profile information could not be loaded', de: 'Profilinformationen konnten nicht geladen werden')}: $error';
      });
    }
  }

  Future<void> _openEditProfile() async {
    final bool? updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EditProfileScreen(initialData: _profileData),
      ),
    );

    if (updated == true) {
      await _loadProfile();
    }
  }

  Future<void> _openVerification() async {
    final bool? updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const VerificationScreen()),
    );

    if (updated == true) {
      await _loadProfile();
    }
  }

  void _openPublicProfile() {
    final UserModel? user = _user;

    if (user == null) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PublicProfileScreen(userId: user.uid, initialUser: user),
      ),
    );
  }

  Future<void> _openFriends() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const FriendsScreen()),
    );
    if (mounted) {
      await _loadProfile();
    }
  }

  Future<void> _openFriendRequests() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const FriendRequestsScreen()),
    );
    if (mounted) {
      await _loadProfile();
    }
  }

  Future<void> _openUserSearch() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const UserSearchScreen()),
    );
    if (mounted) {
      await _loadProfile();
    }
  }

  Future<void> _openMarket() async {
    final UserModel? user = _user;

    if (user == null) {
      return;
    }

    if (user.isPlusActive) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (BuildContext sheetContext) {
          return _PlusDetailsSheet(user: user);
        },
      );
      return;
    }

    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const MarketScreen()));

    if (mounted) {
      await _loadProfile();
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
    if (mounted) {
      await _loadProfile();
    }
  }

  Future<void> _openBadges() async {
    final UserModel? user = _user;

    if (user == null) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => UserBadgesScreen(userId: user.uid, isOwnProfile: true),
      ),
    );
    if (mounted) {
      await _loadProfile();
    }
  }

  Future<void> _logout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            _profileText(
              context,
              tr: 'Çıkış yap',
              en: 'Sign out',
              de: 'Abmelden',
            ),
          ),
          content: Text(
            _profileText(
              context,
              tr: 'Hesabından çıkış yapmak istediğine emin misin?',
              en: 'Are you sure you want to sign out of your account?',
              de: 'Möchtest du dich wirklich von deinem Konto abmelden?',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(
                _profileText(
                  context,
                  tr: 'Vazgeç',
                  en: 'Cancel',
                  de: 'Abbrechen',
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text(
                _profileText(
                  context,
                  tr: 'Çıkış yap',
                  en: 'Sign out',
                  de: 'Abmelden',
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await FirebaseAuth.instance.signOut();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null || _user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            _profileText(
              context,
              tr: 'Profilim',
              en: 'My Profile',
              de: 'Mein Profil',
            ),
          ),
          centerTitle: true,
        ),
        body: _ProfileLoadError(
          message:
              _errorMessage ??
              _profileText(
                context,
                tr: 'Profil bulunamadı.',
                en: 'Profile not found.',
                de: 'Profil nicht gefunden.',
              ),
          onRetry: _loadProfile,
        ),
      );
    }

    final UserModel user = _user!;

    return Scaffold(
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surface.withValues(alpha: 1.0),
      appBar: AppBar(
        title: Text(
          _profileText(
            context,
            tr: 'Profilim',
            en: 'My Profile',
            de: 'Mein Profil',
          ),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: _profileText(
              context,
              tr: 'Ayarlar',
              en: 'Settings',
              de: 'Einstellungen',
            ),
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
          children: <Widget>[
            _ProfileHeader(user: user, onEdit: _openEditProfile),
            const SizedBox(height: 10),
            _StatisticsRow(user: user),
            const SizedBox(height: 14),
            _ProfileMenuCard(
              children: <Widget>[
                _ProfileMenuTile(
                  icon: Icons.people_alt_rounded,
                  title: _profileText(
                    context,
                    tr: 'Arkadaşlarım',
                    en: 'My Friends',
                    de: 'Meine Freunde',
                  ),
                  subtitle: _profileText(
                    context,
                    tr: 'Arkadaş listesini görüntüle',
                    en: 'View your friends list',
                    de: 'Freundesliste anzeigen',
                  ),
                  onTap: _openFriends,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person_add_alt_1_rounded),
                  title: Text(
                    _profileText(
                      context,
                      tr: 'Arkadaşlık İstekleri',
                      en: 'Friend Requests',
                      de: 'Freundschaftsanfragen',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    _profileText(
                      context,
                      tr: 'Bekleyen istekleri görüntüle',
                      en: 'View pending requests',
                      de: 'Ausstehende Anfragen anzeigen',
                    ),
                  ),
                  trailing: StreamBuilder<int>(
                    stream: FriendService.instance.pendingRequestCount(),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      if (count == 0) {
                        return const Icon(Icons.chevron_right_rounded);
                      }
                      return Badge(
                        label: Text('$count'),
                        child: const Icon(Icons.chevron_right_rounded),
                      );
                    },
                  ),
                  onTap: _openFriendRequests,
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppAdminMenuEntry(
              builder: (BuildContext context, VoidCallback openAdminPanel) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ProfileMenuCard(
                    children: <Widget>[
                      _ProfileMenuTile(
                        icon: Icons.admin_panel_settings_outlined,
                        title: AppAdminMenuEntry.label(context),
                        subtitle: _profileText(
                          context,
                          tr: 'Yönetim araçlarını aç',
                          en: 'Open management tools',
                          de: 'Verwaltungswerkzeuge öffnen',
                        ),
                        onTap: openAdminPanel,
                      ),
                    ],
                  ),
                );
              },
            ),
            _ProfileSectionTitle(
              title: _profileText(
                context,
                tr: 'Hesap',
                en: 'Account',
                de: 'Konto',
              ),
            ),
            const SizedBox(height: 8),
            _PlusMembershipCard(user: user, onTap: _openMarket),
            const SizedBox(height: 14),
            _MembershipCard(user: user, onVerify: _openVerification),
            const SizedBox(height: 14),
            _ProfileCompletionCard(user: user),
            const SizedBox(height: 14),
            _ProfileSectionTitle(
              title: _profileText(
                context,
                tr: 'Profil ve keşfet',
                en: 'Profile & discover',
                de: 'Profil & Entdecken',
              ),
            ),
            const SizedBox(height: 8),
            _ProfileMenuCard(
              children: <Widget>[
                _ProfileMenuTile(
                  icon: Icons.search_rounded,
                  title: 'Oyuncu Ara',
                  subtitle: _profileText(
                    context,
                    tr: 'Kullanıcı adı ile oyuncu ara',
                    en: 'Search players by username',
                    de: 'Spieler nach Benutzernamen suchen',
                  ),
                  onTap: _openUserSearch,
                ),
                const Divider(height: 1),
                _ProfileMenuTile(
                  icon: Icons.workspace_premium_outlined,
                  title: _profileText(
                    context,
                    tr: 'Rozetlerim',
                    en: 'My badges',
                    de: 'Meine Abzeichen',
                  ),
                  subtitle: _profileText(
                    context,
                    tr: 'Satın aldığın oyun rozetlerini görüntüle',
                    en: 'View your purchased game badges',
                    de: 'Sieh dir deine gekauften Spielabzeichen an',
                  ),
                  onTap: _openBadges,
                ),
                const Divider(height: 1),
                _ProfileMenuTile(
                  icon: Icons.public_outlined,
                  title: _profileText(
                    context,
                    tr: 'Herkese açık profilim',
                    en: 'My public profile',
                    de: 'Mein öffentliches Profil',
                  ),
                  subtitle: _profileText(
                    context,
                    tr: 'Diğer oyuncuların gördüğü profilini incele',
                    en: 'View the profile other players can see',
                    de: 'Sieh dir dein Profil aus Sicht anderer Spieler an',
                  ),
                  onTap: _openPublicProfile,
                ),
              ],
            ),
            if (user.hakkimda.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _AboutCard(text: user.hakkimda.trim()),
            ],
            const SizedBox(height: 14),
            _ProfileSectionTitle(
              title: _profileText(
                context,
                tr: 'Oyunlar',
                en: 'Games',
                de: 'Spiele',
              ),
            ),
            const SizedBox(height: 8),
            _GamesPreviewCard(user: user, onEdit: _openEditProfile),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
              label: Text(
                _profileText(
                  context,
                  tr: 'Hesaptan çıkış yap',
                  en: 'Sign out of account',
                  de: 'Vom Konto abmelden',
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSectionTitle extends StatelessWidget {
  const _ProfileSectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: 0.9,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user, required this.onEdit});

  final UserModel user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[const Color(0xff2B1B0B), const Color(0xff5A330C)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              _ProfileAvatar(user: user),
              Positioned(
                right: -4,
                bottom: -4,
                child: IconButton.filled(
                  tooltip: _profileText(
                    context,
                    tr: 'Profili düzenle',
                    en: 'Edit profile',
                    de: 'Profil bearbeiten',
                  ),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            user.displayName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (user.fullName.isNotEmpty &&
              user.fullName != user.displayName) ...[
            const SizedBox(height: 3),
            Text(
              user.fullName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (user.sehir.trim().isNotEmpty) ...[
            const SizedBox(height: 9),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.location_on_outlined, size: 17, color: Colors.white),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    user.ilce.trim().isEmpty
                        ? user.sehir.trim()
                        : '${user.ilce.trim()}, ${user.sehir.trim()}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 13),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              if (user.oyuncuRozeti)
                _HeaderChip(
                  icon: Icons.sports_esports_rounded,
                  text: _profileText(
                    context,
                    tr: 'Oyuncu',
                    en: 'Player',
                    de: 'Spieler',
                  ),
                ),
              if (user.isPlusActive)
                const _HeaderChip(
                  icon: Icons.workspace_premium_rounded,
                  text: 'Plus',
                ),
              if (user.verified)
                _HeaderChip(
                  icon: Icons.verified_rounded,
                  text: _profileText(
                    context,
                    tr: 'Doğrulanmış',
                    en: 'Verified',
                    de: 'Verifiziert',
                  ),
                ),
            ],
          ),
          MarketBadgeStrip(userId: user.uid),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final String photoUrl = user.profilFotografi.trim();
    final String avatarUrl = user.avatarUrl.trim();
    final String imageUrl = photoUrl.isNotEmpty ? photoUrl : avatarUrl;

    return Container(
      width: 92,
      height: 92,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.surface,
      ),
      child: ClipOval(
        child: imageUrl.isEmpty
            ? _AvatarFallback(name: user.displayName)
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder:
                    (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) {
                      return _AvatarFallback(name: user.displayName);
                    },
              ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final String initial = name.trim().isEmpty
        ? '?'
        : name.trim()[0].toUpperCase();

    return Container(
      alignment: Alignment.center,
      color: Theme.of(context).colorScheme.primary,
      child: Text(
        initial,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontSize: 40,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _StatisticsRow extends StatelessWidget {
  const _StatisticsRow({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatisticCard(
            icon: Icons.star_rounded,
            value: user.puan > 0 ? user.puan.toStringAsFixed(1) : '—',
            label: _profileText(
              context,
              tr: 'Puan',
              en: 'Rating',
              de: 'Bewertung',
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const MyEventsScreen()),
              );
            },
            child: _StatisticCard(
              icon: Icons.emoji_events_outlined,
              value: '${user.completedEventCount}',
              label: _profileText(
                context,
                tr: 'Etkinlik',
                en: 'Events',
                de: 'Events',
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _StatisticCard(
            icon: Icons.sports_esports_outlined,
            value: '${user.gameSkills.length}',
            label: _profileText(context, tr: 'Oyun', en: 'Games', de: 'Spiele'),
          ),
        ),
      ],
    );
  }
}

class _StatisticCard extends StatelessWidget {
  const _StatisticCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          children: <Widget>[
            Icon(icon, color: const Color(0xffFF9800)),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlusDetailsSheet extends StatelessWidget {
  const _PlusDetailsSheet({required this.user});

  final UserModel user;

  String _dateText(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final DateTime? expiry = user.plusExpiresAt;
    const Color plusColor = Color(0xffF59E0B);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 68,
                  height: 68,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: plusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    size: 38,
                    color: plusColor,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  'Dört. Plus',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  _profileText(
                    context,
                    tr: 'Üyeliğin aktif ve ayrıcalıkların kullanıma hazır.',
                    en: 'Your membership is active and your benefits are ready to use.',
                    de: 'Deine Mitgliedschaft ist aktiv und deine Vorteile sind verfügbar.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0xff23180B), Color(0xff4A2C0A)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            user.plusPlanLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            expiry == null
                                ? 'Aktif üyelik'
                                : 'Bitiş: ${_dateText(expiry)} · '
                                      '${user.plusRemainingDays} gün kaldı',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xff22C55E).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text(
                        'AKTİF',
                        style: TextStyle(
                          color: Color(0xff86EFAC),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Plus ayrıcalıkların',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              const _PlusBenefitTile(
                icon: Icons.event_available_rounded,
                title: 'Etkinlikleri ileri tarihe planla',
                subtitle:
                    'Etkinliklerini daha ileri tarihler için oluşturup planlayabilirsin.',
              ),
              const SizedBox(height: 10),
              const _PlusBenefitTile(
                icon: Icons.groups_rounded,
                title: 'Birden fazla oyuncu için etkinlik oluştur',
                subtitle:
                    'Daha geniş katılımlı etkinlikler oluşturmak için Plus ayrıcalıklarını kullanabilirsin.',
              ),
              const SizedBox(height: 10),
              const _PlusBenefitTile(
                icon: Icons.workspace_premium_rounded,
                title: 'Profilinde Plus ayrıcalığını göster',
                subtitle:
                    'Plus üyeliğin kendi profilinde ve diğer oyuncuların gördüğü profilde görünür.',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Tamam',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlusBenefitTile extends StatelessWidget {
  const _PlusBenefitTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xffF59E0B).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 22, color: const Color(0xffF59E0B)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.35,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlusMembershipCard extends StatelessWidget {
  const _PlusMembershipCard({required this.user, required this.onTap});

  final UserModel user;
  final VoidCallback onTap;

  String _dateText(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final bool active = user.isPlusActive;
    final DateTime? expiry = user.plusExpiresAt;
    const Color plusColor = Color(0xffF59E0B);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0xff23180B), Color(0xff4A2C0A)],
                  )
                : null,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active
                      ? plusColor.withValues(alpha: 0.18)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: active
                      ? plusColor
                      : Theme.of(context).colorScheme.primary,
                  size: 29,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            active ? user.plusPlanLabel : 'Dört. Plus',
                            style: TextStyle(
                              color: active ? Colors.white : null,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(
                                    0xff22C55E,
                                  ).withValues(alpha: 0.18)
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            active ? 'AKTİF' : 'AKTİF DEĞİL',
                            style: TextStyle(
                              color: active
                                  ? const Color(0xff86EFAC)
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      active && expiry != null
                          ? 'Bitiş: ${_dateText(expiry)} · '
                                '${user.plusRemainingDays} gün kaldı'
                          : 'Plus ayrıcalıklarını incele ve üyeliğini başlat.',
                      style: TextStyle(
                        color: active
                            ? Colors.white70
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: active ? Colors.white70 : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({required this.user, required this.onVerify});

  final UserModel user;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final String status = user.verificationStatus.toLowerCase();

    final String title;
    final String subtitle;
    final IconData icon;
    final Color color;

    if (user.verified) {
      title = _profileText(
        context,
        tr: 'Doğrulanmış hesap',
        en: 'Verified account',
        de: 'Verifiziertes Konto',
      );
      subtitle = _profileText(
        context,
        tr: 'Kimlik doğrulaman tamamlandı.',
        en: 'Your identity verification is complete.',
        de: 'Deine Identitätsprüfung ist abgeschlossen.',
      );
      icon = Icons.verified_rounded;
      color = const Color(0xff2563EB);
    } else if (status == 'pending') {
      title = _profileText(
        context,
        tr: 'Doğrulama inceleniyor',
        en: 'Verification under review',
        de: 'Verifizierung wird geprüft',
      );
      subtitle = _profileText(
        context,
        tr: 'Başvurun kontrol ediliyor.',
        en: 'Your application is being reviewed.',
        de: 'Dein Antrag wird geprüft.',
      );
      icon = Icons.hourglass_top_rounded;
      color = const Color(0xffD97706);
    } else if (status == 'rejected') {
      title = _profileText(
        context,
        tr: 'Doğrulama reddedildi',
        en: 'Verification rejected',
        de: 'Verifizierung abgelehnt',
      );
      subtitle = _profileText(
        context,
        tr: 'Bilgilerini kontrol ederek yeniden başvur.',
        en: 'Review your information and apply again.',
        de: 'Prüfe deine Angaben und stelle den Antrag erneut.',
      );
      icon = Icons.cancel_outlined;
      color = Theme.of(context).colorScheme.error;
    } else {
      title = _profileText(
        context,
        tr: 'Hesabını doğrula',
        en: 'Verify your account',
        de: 'Konto verifizieren',
      );
      subtitle = _profileText(
        context,
        tr: 'Güven rozetini kazan ve profilini güçlendir.',
        en: 'Earn the trust badge and strengthen your profile.',
        de: 'Erhalte das Vertrauensabzeichen und stärke dein Profil.',
      );
      icon = Icons.verified_user_outlined;
      color = Theme.of(context).colorScheme.primary;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onVerify,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCompletionCard extends StatelessWidget {
  const _ProfileCompletionCard({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final List<bool> checks = <bool>[
      user.displayName.trim().isNotEmpty,
      user.profilFotografi.trim().isNotEmpty,
      user.hakkimda.trim().isNotEmpty,
      user.resolvedCity.trim().isNotEmpty,
      user.gameSkills.isNotEmpty,
      user.oyuncuRozeti,
    ];

    final int completed = checks.where((bool value) => value).length;
    final double progress = completed / checks.length;
    final int percent = (progress * 100).round();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.account_circle_outlined,
                  color: Color(0xffFF9800),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _profileText(
                      context,
                      tr: 'Profil tamamlanma durumu',
                      en: 'Profile completion',
                      de: 'Profilfortschritt',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  '%$percent',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 9,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuCard extends StatelessWidget {
  const _ProfileMenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.person_outline_rounded,
                  color: Color(0xffFF9800),
                ),
                const SizedBox(width: 8),
                Text(
                  _profileText(
                    context,
                    tr: 'Hakkımda',
                    en: 'About me',
                    de: 'Über mich',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(text, style: const TextStyle(height: 1.45)),
          ],
        ),
      ),
    );
  }
}

class _GamesPreviewCard extends StatelessWidget {
  const _GamesPreviewCard({required this.user, required this.onEdit});

  final UserModel user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final List<UserGameSkill> skills = user.sortedGameSkills;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.sports_esports_outlined,
                  color: Color(0xffFF9800),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _profileText(
                      context,
                      tr: 'Oyunlarım',
                      en: 'My games',
                      de: 'Meine Spiele',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                TextButton(
                  onPressed: onEdit,
                  child: Text(
                    _profileText(
                      context,
                      tr: 'Düzenle',
                      en: 'Edit',
                      de: 'Bearbeiten',
                    ),
                  ),
                ),
              ],
            ),
            if (skills.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _profileText(
                  context,
                  tr: 'Henüz oyun eklenmemiş. Etkinliklere başvurabilmek için oynadığın oyunları profiline ekle.',
                  en: 'No games have been added yet. Add the games you play to your profile to apply for events.',
                  de: 'Noch keine Spiele hinzugefügt. Füge deine Spiele zum Profil hinzu, um dich für Events zu bewerben.',
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              ...skills.take(5).map((UserGameSkill skill) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          skill.gameName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '${skill.levelLabel} · %${skill.level}',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSecondaryContainer,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (skills.length > 5)
                Text(
                  '+${skills.length - 5} ${_profileText(context, tr: 'oyun daha', en: 'more games', de: 'weitere Spiele')}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline_rounded, size: 56),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                _profileText(
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
