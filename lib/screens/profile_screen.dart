import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../models/market_badge_display.dart';
import '../models/user_model.dart';
import '../services/language_controller.dart';
import '../services/notification_push_service.dart';
import '../utils/verification_reason.dart';
import '../services/user_service.dart';
import '../services/digital_purchase_service.dart';
import '../services/friend_service.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'market_screen.dart';
import 'friends_screen.dart';
import 'gift_history_screen.dart';
import 'friend_requests_screen.dart';
import 'user_search_screen.dart';
import 'public_profile_screen.dart';
import 'my_events_screen.dart';
import 'settings_screen.dart';
import 'verification_screen.dart';
import '../utils/profile_completion.dart';
import '../utils/game_experience.dart';
import '../widgets/app_admin_menu_entry.dart';
import '../widgets/market_badge_strip.dart';
import '../widgets/market_palette.dart';
import '../widgets/plus_emblem.dart';
import '../widgets/plus_membership_label.dart';
import '../widgets/plus_surface.dart';
import '../widgets/profile_menu_tile.dart';
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

  Future<void> _openEditProfile([ProfileCompletionField? focus]) async {
    final bool? updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            EditProfileScreen(initialData: _profileData, focus: focus),
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

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const MarketScreen(openPlusDetails: true),
      ),
    );

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

    await NotificationPushService.unregisterCurrentToken();
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

    return ProfileScreenView(
      user: user,
      onRefresh: _loadProfile,
      onEdit: _openEditProfile,
      onSettings: _openSettings,
      onFriends: _openFriends,
      onFriendRequests: _openFriendRequests,
      onUserSearch: _openUserSearch,
      onMarket: _openMarket,
      onVerify: _openVerification,
      onBadges: _openBadges,
      onPublicProfile: _openPublicProfile,
      onLogout: _logout,
      onEditField: (ProfileCompletionField field) {
        _openEditProfile(field);
      },
    );
  }
}

class ProfileScreenView extends StatelessWidget {
  const ProfileScreenView({
    required this.user,
    required this.onRefresh,
    required this.onEdit,
    required this.onSettings,
    required this.onFriends,
    required this.onFriendRequests,
    required this.onUserSearch,
    required this.onMarket,
    required this.onVerify,
    required this.onBadges,
    required this.onPublicProfile,
    required this.onLogout,
    this.onEditField,
    this.badges = const <MarketBadgeDisplay>[],
    super.key,
  });

  final UserModel user;
  final Future<void> Function() onRefresh;
  final VoidCallback onEdit;
  final VoidCallback onSettings;
  final VoidCallback onFriends;
  final VoidCallback onFriendRequests;
  final VoidCallback onUserSearch;
  final VoidCallback onMarket;
  final VoidCallback onVerify;
  final VoidCallback onBadges;
  final VoidCallback onPublicProfile;
  final VoidCallback onLogout;
  final ValueChanged<ProfileCompletionField>? onEditField;
  final List<MarketBadgeDisplay> badges;

  @override
  Widget build(BuildContext context) {
    final MarketPalette palette = MarketPalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          _profileText(
            context,
            tr: 'Profilim',
            en: 'My Profile',
            de: 'Mein Profil',
          ),
          style: profileMenuTitleStyle(context),
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
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
          children: <Widget>[
            _ProfileHeader(user: user, onEdit: onEdit, badges: badges),
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
                  onTap: onFriends,
                ),
                if (kGiftActionsEnabled) ...<Widget>[
                  const _MenuDivider(),
                  _ProfileMenuTile(
                    icon: Icons.card_giftcard_outlined,
                    title: _profileText(
                      context,
                      tr: 'Hediyeler',
                      en: 'Gifts',
                      de: 'Geschenke',
                    ),
                    subtitle: _profileText(
                      context,
                      tr: 'Gönderilen ve alınan hediyeler',
                      en: 'Sent and received gifts',
                      de: 'Gesendete und erhaltene Geschenke',
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const GiftHistoryScreen(),
                        ),
                      );
                    },
                  ),
                ],
                const _MenuDivider(),
                _ProfileMenuTile(
                  icon: Icons.person_add_alt_1_rounded,
                  title: _profileText(
                    context,
                    tr: 'Arkadaşlık İstekleri',
                    en: 'Friend Requests',
                    de: 'Freundschaftsanfragen',
                  ),
                  subtitle: _profileText(
                    context,
                    tr: 'Bekleyen istekleri görüntüle',
                    en: 'View pending requests',
                    de: 'Ausstehende Anfragen anzeigen',
                  ),
                  trailing: Firebase.apps.isEmpty
                      ? null
                      : StreamBuilder<int>(
                          stream: FriendService.instance.pendingRequestCount(),
                          builder: (context, snapshot) {
                            final int count = snapshot.data ?? 0;
                            final MarketPalette palette = MarketPalette.of(
                              context,
                            );
                            if (count == 0) {
                              return Icon(
                                Icons.chevron_right_rounded,
                                color: palette.muted,
                              );
                            }
                            return Badge(
                              label: Text('$count'),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                color: palette.muted,
                              ),
                            );
                          },
                        ),
                  onTap: onFriendRequests,
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
            PlusMembershipCard(user: user, onTap: onMarket),
            const SizedBox(height: 14),
            _MembershipCard(user: user, onVerify: onVerify),
            const SizedBox(height: 14),
            _ProfileCompletionCard(
              user: user,
              onEditField: (ProfileCompletionField field) {
                if (onEditField != null) {
                  onEditField!(field);
                  return;
                }
                onEdit();
              },
            ),
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
                  title: _profileText(
                    context,
                    tr: 'Oyuncu Ara',
                    en: 'Find a player',
                    de: 'Spieler suchen',
                  ),
                  subtitle: _profileText(
                    context,
                    tr: 'Kullanıcı adı ile oyuncu ara',
                    en: 'Search players by username',
                    de: 'Spieler nach Benutzernamen suchen',
                  ),
                  onTap: onUserSearch,
                ),
                const _MenuDivider(),
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
                  onTap: onBadges,
                ),
                const _MenuDivider(),
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
                  onTap: onPublicProfile,
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
            _GamesPreviewCard(user: user, onEdit: onEdit),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onLogout,
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
    final MarketPalette palette = MarketPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: palette.muted,
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.onEdit,
    required this.badges,
  });

  final UserModel user;
  final VoidCallback onEdit;
  final List<MarketBadgeDisplay> badges;

  @override
  Widget build(BuildContext context) {
    final MarketPalette palette = MarketPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.line),
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
                  style: IconButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor: palette.onAccent,
                  ),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          ProfileNameRow(
            name: user.displayName,
            plusActive: user.isPlusActive,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (user.fullName.isNotEmpty &&
              user.fullName != user.displayName) ...[
            const SizedBox(height: 3),
            Text(
              user.fullName,
              textAlign: TextAlign.center,
              style: profileMenuSubtitleStyle(context),
            ),
          ],
          if (user.sehir.trim().isNotEmpty) ...[
            const SizedBox(height: 9),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.location_on_outlined,
                  size: 17,
                  color: palette.accent,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    user.ilce.trim().isEmpty
                        ? user.sehir.trim()
                        : '${user.ilce.trim()}, ${user.sehir.trim()}',
                    overflow: TextOverflow.ellipsis,
                    style: profileMenuSubtitleStyle(
                      context,
                    ).copyWith(color: palette.ink),
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
          MarketBadgeStrip(userId: user.uid, projected: badges),
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
        color: MarketPalette.of(context).raised,
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
    final MarketPalette palette = MarketPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: palette.raised,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: palette.accent),
          const SizedBox(width: 5),
          Text(
            text,
            style: profileMenuSubtitleStyle(
              context,
            ).copyWith(color: palette.ink),
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

// ignore: unused_element
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
    final DateTime? expiry = user.effectivePlusExpiresAt;

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
                child: SizedBox(
                  width: 68,
                  height: 68,
                  child: const Center(child: PlusMark(size: 40)),
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
                _profileText(
                  context,
                  tr: 'Plus ayrıcalıkların',
                  en: 'Your Plus benefits',
                  de: 'Deine Plus-Vorteile',
                ),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              _PlusBenefitTile(
                icon: Icons.event_available_rounded,
                title: _profileText(
                  context,
                  tr: 'Planını önceden yap',
                  en: 'Plan ahead',
                  de: 'Plane voraus',
                ),
                subtitle: _profileText(
                  context,
                  tr: 'Aktif Plus, bugün ile 7 takvim günü sonrası dahil etkinlik açabilir.',
                  en: 'Active Plus can open an event from today through 7 calendar days later, including both days.',
                  de: 'Aktives Plus kann ein Event von heute bis einschließlich 7 Kalendertage später öffnen.',
                ),
              ),
              const SizedBox(height: 10),
              _PlusBenefitTile(
                icon: Icons.groups_rounded,
                title: _profileText(
                  context,
                  tr: 'Birden fazla oyuncuyla etkinlik oluştur',
                  en: 'Create events with multiple players',
                  de: 'Erstelle Events mit mehreren Spielern',
                ),
                subtitle: _profileText(
                  context,
                  tr: 'Aranan sayı etkinlik sahibini içermez.',
                  en: 'The number sought does not include the host.',
                  de: 'Die gesuchte Zahl enthält den Gastgeber nicht.',
                ),
              ),
              const SizedBox(height: 10),
              _PlusBenefitTile(
                icon: Icons.workspace_premium_rounded,
                title: _profileText(
                  context,
                  tr: 'Profilinde Plus rozeti',
                  en: 'Plus badge on your profile',
                  de: 'Plus-Abzeichen im Profil',
                ),
                subtitle: _profileText(
                  context,
                  tr: 'Aktif Plus, herkese açık profilde Plus rozeti olarak görünür.',
                  en: 'Active Plus appears as a Plus badge on the public profile.',
                  de: 'Aktives Plus erscheint als Plus-Abzeichen im öffentlichen Profil.',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _profileText(
                  context,
                  tr: 'Ücretsiz: yalnızca bugün ve 1 oyuncu.',
                  en: 'Free: today only and 1 player.',
                  de: 'Kostenlos: nur heute und 1 Spieler.',
                ),
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

class PlusMembershipCard extends StatelessWidget {
  const PlusMembershipCard({
    super.key,
    required this.user,
    required this.onTap,
  });

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
    final DateTime? expiry = user.effectivePlusExpiresAt;
    final MarketPalette palette = MarketPalette.of(context);
    final bool roomy = MediaQuery.textScalerOf(context).scale(1) >= 1.3;
    final bool canceled =
        user.plusSubscriptionState == 'SUBSCRIPTION_STATE_CANCELED';
    final String activeDateText = expiry == null
        ? _profileText(
            context,
            tr: 'Plus üyeliğin aktif',
            en: 'Your Plus membership is active',
            de: 'Deine Plus-Mitgliedschaft ist aktiv',
          )
        : canceled
        ? _profileText(
            context,
            tr: 'Şu tarihe kadar aktif: ${_dateText(expiry)}',
            en: 'Active until: ${_dateText(expiry)}',
            de: 'Aktiv bis: ${_dateText(expiry)}',
          )
        : _profileText(
            context,
            tr: 'Geçerlilik: ${_dateText(expiry)}',
            en: 'Valid through: ${_dateText(expiry)}',
            de: 'Gültig bis: ${_dateText(expiry)}',
          );
    final Widget statusPill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: active ? palette.owned.withValues(alpha: 0.16) : palette.raised,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        _profileText(
          context,
          tr: 'Plus üyeliğin aktif',
          en: 'Plus membership active',
          de: 'Plus-Mitgliedschaft aktiv',
        ),
        style: profileMenuSubtitleStyle(context).copyWith(
          color: active ? palette.owned : palette.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return PlusSurface(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(child: PlusMark(size: 30)),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (roomy)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Dört. Plus',
                              style: profileMenuTitleStyle(
                                context,
                              ).copyWith(color: PlusSurface.ink),
                            ),
                            if (active) ...<Widget>[
                              const SizedBox(height: 6),
                              statusPill,
                            ],
                          ],
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'Dört. Plus',
                                style: profileMenuTitleStyle(
                                  context,
                                ).copyWith(color: PlusSurface.ink),
                              ),
                            ),
                            if (active) ...<Widget>[
                              const SizedBox(width: 8),
                              statusPill,
                            ],
                          ],
                        ),
                      const SizedBox(height: 6),
                      Text(
                        active
                            ? activeDateText
                            : _profileText(
                                context,
                                tr: 'Oyuna daha çok yer aç.',
                                en: 'Make more room for play.',
                                de: 'Schaffe mehr Raum fürs Spiel.',
                              ),
                        style: profileMenuSubtitleStyle(
                          context,
                        ).copyWith(color: PlusSurface.muted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        active
                            ? _profileText(
                                context,
                                tr: 'Üyeliği yönet',
                                en: 'Manage membership',
                                de: 'Mitgliedschaft verwalten',
                              )
                            : _profileText(
                                context,
                                tr: 'Birden fazla oyuncu · ileri tarih planı',
                                en: 'Multiple players · plan future dates',
                                de: 'Mehrere Spieler · zukünftige Termine',
                              ),
                        style: profileMenuSubtitleStyle(context).copyWith(
                          color: PlusSurface.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (!active) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          _profileText(
                            context,
                            tr: "Plus'ı keşfet",
                            en: 'Explore Plus',
                            de: 'Plus entdecken',
                          ),
                          style: const TextStyle(
                            color: PlusSurface.accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: PlusSurface.muted,
                ),
              ],
            ),
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
    final String languageCode = switch (LanguageController.language.value) {
      AppLanguage.english => 'en',
      AppLanguage.german => 'de',
      AppLanguage.turkish => 'tr',
    };
    final VerificationDisplay verificationDisplay = presentVerificationStatus(
      status: user.verified
          ? 'approved'
          : user.verificationStatus.toLowerCase(),
      reasonCode: user.verificationReasonCode,
      decisionReason: user.verificationRejectionReason,
      decisionSource: user.verificationDecisionSource,
      languageCode: languageCode,
    );

    final String title;
    final String subtitle;
    final IconData icon;
    final Color color;

    if (verificationDisplay.kind == VerificationDisplayKind.approved) {
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
    } else if (verificationDisplay.kind == VerificationDisplayKind.pending) {
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
    } else if (verificationDisplay.showRejected) {
      title = verificationStatusTitle(
        kind: VerificationDisplayKind.rejected,
        languageCode: languageCode,
      );
      subtitle = verificationDisplay.reason;
      icon = Icons.cancel_outlined;
      color = Theme.of(context).colorScheme.error;
    } else if (verificationDisplay.kind == VerificationDisplayKind.unknown) {
      title = verificationStatusTitle(
        kind: VerificationDisplayKind.unknown,
        languageCode: languageCode,
      );
      subtitle = verificationDisplay.reason;
      icon = Icons.help_outline_rounded;
      color = const Color(0xffD97706);
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

    final MarketPalette palette = MarketPalette.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onVerify,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    Text(title, style: profileMenuTitleStyle(context)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: profileMenuSubtitleStyle(context)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCompletionCard extends StatelessWidget {
  const _ProfileCompletionCard({required this.user, required this.onEditField});

  final UserModel user;
  final ValueChanged<ProfileCompletionField> onEditField;

  String _label(BuildContext context, ProfileCompletionField field) {
    return switch (field) {
      ProfileCompletionField.name => _profileText(
        context,
        tr: 'İsim',
        en: 'Name',
        de: 'Name',
      ),
      ProfileCompletionField.photo => _profileText(
        context,
        tr: 'Profil fotoğrafı',
        en: 'Profile photo',
        de: 'Profilfoto',
      ),
      ProfileCompletionField.about => _profileText(
        context,
        tr: 'Hakkımda',
        en: 'About me',
        de: 'Über mich',
      ),
      ProfileCompletionField.city => _profileText(
        context,
        tr: 'Şehir',
        en: 'City',
        de: 'Stadt',
      ),
      ProfileCompletionField.games => _profileText(
        context,
        tr: 'Oyunlar',
        en: 'Games',
        de: 'Spiele',
      ),
    };
  }

  IconData _icon(ProfileCompletionField field) {
    return switch (field) {
      ProfileCompletionField.name => Icons.person_outline_rounded,
      ProfileCompletionField.photo => Icons.photo_camera_outlined,
      ProfileCompletionField.about => Icons.notes_rounded,
      ProfileCompletionField.city => Icons.location_city_outlined,
      ProfileCompletionField.games => Icons.sports_esports_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ProfileCompletion completion = profileCompletionOf(user);
    final MarketPalette palette = MarketPalette.of(context);
    final List<ProfileCompletionField> missing = completion.missingActions;

    return Card(
      margin: EdgeInsets.zero,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.account_circle_outlined,
                  color: palette.accent,
                  size: 22,
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
                    style: profileMenuTitleStyle(context),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '%${completion.percent}',
                  style: profileMenuTitleStyle(
                    context,
                  ).copyWith(color: palette.accent),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: completion.percent / 100,
                minHeight: 6,
                color: palette.accent,
                backgroundColor: palette.raised,
              ),
            ),
            if (missing.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              for (final ProfileCompletionField field in missing)
                ProfileMenuTile(
                  icon: _icon(field),
                  title: _label(context, field),
                  subtitle: _profileText(
                    context,
                    tr: 'Profili düzenle',
                    en: 'Edit profile',
                    de: 'Profil bearbeiten',
                  ),
                  onTap: () => onEditField(field),
                ),
            ] else
              const SizedBox(height: 8),
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
    final MarketPalette palette = MarketPalette.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: palette.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.line),
      ),
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
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ProfileMenuTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: trailing,
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: MarketPalette.of(context).line,
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final MarketPalette palette = MarketPalette.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ProfileHeading(
              icon: Icons.person_outline_rounded,
              title: _profileText(
                context,
                tr: 'Hakkımda',
                en: 'About me',
                de: 'Über mich',
              ),
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
    final MarketPalette palette = MarketPalette.of(context);

    return Card(
      margin: EdgeInsets.zero,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: ProfileHeading(
                    icon: Icons.sports_esports_outlined,
                    title: _profileText(
                      context,
                      tr: 'Oyunlarım',
                      en: 'My games',
                      de: 'Meine Spiele',
                    ),
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
                        child: Tooltip(
                          message: selfDeclaredExperienceText(
                            context,
                            skill.level,
                          ),
                          child: Text(
                            gameExperienceLabel(context, skill.level),
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
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
