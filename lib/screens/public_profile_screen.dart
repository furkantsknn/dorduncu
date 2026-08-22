import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/friend_service.dart';
import '../utils/game_catalog.dart';
import '../utils/support_categories.dart';
import 'create_support_request_screen.dart';

class PublicProfileScreen extends StatelessWidget {
  const PublicProfileScreen({
    super.key,
    required this.userId,
    this.initialUser,
  });

  final String userId;
  final UserModel? initialUser;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Oyuncu Profili',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'report_user':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateSupportRequestScreen(
                        category: SupportCategory.userReport,
                        relatedUserId: userId,
                      ),
                    ),
                  );
                  break;

                case 'report_photo':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateSupportRequestScreen(
                        category: SupportCategory.inappropriateImage,
                        relatedUserId: userId,
                      ),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'report_user',
                child: Row(
                  children: [
                    Icon(Icons.person_off_outlined),
                    SizedBox(width: 12),
                    Text('Kullanıcıyı Şikâyet Et'),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'report_photo',
                child: Row(
                  children: [
                    Icon(Icons.image_not_supported_outlined),
                    SizedBox(width: 12),
                    Text('Profil Fotoğrafını Şikâyet Et'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        initialData: initialUser?.toMap(),
        stream: UserService.watchUser(userId),
        builder: (
            BuildContext context,
            AsyncSnapshot<Map<String, dynamic>?> snapshot,
            ) {
          if (snapshot.connectionState ==
              ConnectionState.waiting &&
              snapshot.data == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _PublicProfileError(
              message:
              'Oyuncu profili yüklenirken bir hata oluştu.',
              onRetry: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => PublicProfileScreen(
                      userId: userId,
                      initialUser: initialUser,
                    ),
                  ),
                );
              },
            );
          }

          final UserModel? user =
          snapshot.data == null
              ? null
              : UserModel.fromMap(
            snapshot.data!,
            documentId: userId,
          );

          if (user == null) {
            return const _PublicProfileEmpty();
          }

          return _PublicProfileBody(user: user);
        },
      ),
    );
  }
}

class _PublicProfileBody extends StatelessWidget {
  const _PublicProfileBody({
    required this.user,
  });

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final List<_GameCategoryGroup> groups =
    _groupSkills(user.sortedGameSkills);

    return RefreshIndicator(
      onRefresh: () async {
        await Future<void>.delayed(
          const Duration(milliseconds: 400),
        );
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              28,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                <Widget>[
                  _ProfileHero(user: user),
                  const SizedBox(height: 14),
                  _ProfileStatistics(user: user),
                  const SizedBox(height: 16),
                  _FriendActionCard(user: user),
                  const SizedBox(height: 14),
                  if (user.hakkimda.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _AboutCard(text: user.hakkimda.trim()),
                  ],
                  const SizedBox(height: 18),
                  const _SectionHeader(
                    title: 'Oyunlar ve seviyeler',
                    subtitle:
                    'Oyuncunun profiline eklediği oyun ve spor deneyimleri',
                  ),
                  const SizedBox(height: 10),
                  if (groups.isEmpty)
                    const _NoGamesCard()
                  else
                    ...groups.map(
                          (group) => Padding(
                        padding:
                        const EdgeInsets.only(bottom: 12),
                        child: _GameCategoryCard(
                          group: group,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  _OwnedBadgesCollection(
                    userId: user.uid,
                  ),
                  const SizedBox(height: 18),
                  const _PrivacyNotice(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_GameCategoryGroup> _groupSkills(
      List<UserGameSkill> skills,
      ) {
    final Map<String, List<UserGameSkill>> grouped =
    <String, List<UserGameSkill>>{};

    for (final UserGameSkill skill in skills) {
      final String categoryId =
      skill.categoryId.trim().isNotEmpty
          ? skill.categoryId
          : 'diger';

      grouped
          .putIfAbsent(
        categoryId,
            () => <UserGameSkill>[],
      )
          .add(skill);
    }

    final List<_GameCategoryGroup> result =
    grouped.entries.map((entry) {
      final GameCategoryDefinition? category =
      GameCatalog.categoryById(entry.key);

      final List<UserGameSkill> sortedSkills =
      List<UserGameSkill>.from(entry.value)
        ..sort(
              (a, b) =>
              a.gameName.compareTo(b.gameName),
        );

      return _GameCategoryGroup(
        categoryId: entry.key,
        categoryName: category?.name ??
            (sortedSkills.first.categoryName.trim().isNotEmpty
                ? sortedSkills.first.categoryName
                : 'Diğer'),
        categoryEmoji: category?.emoji ?? '🎯',
        skills: sortedSkills,
      );
    }).toList();

    result.sort((a, b) {
      final int aIndex = GameCatalog.categories
          .indexWhere(
            (category) => category.id == a.categoryId,
      );
      final int bIndex = GameCatalog.categories
          .indexWhere(
            (category) => category.id == b.categoryId,
      );

      final int normalizedA =
      aIndex == -1 ? 999 : aIndex;
      final int normalizedB =
      bIndex == -1 ? 999 : bIndex;

      return normalizedA.compareTo(normalizedB);
    });

    return result;
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.user,
  });

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors =
        Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            colors.primaryContainer,
            colors.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: <Widget>[
          _ProfileAvatar(user: user),
          const SizedBox(height: 14),
          Text(
            user.displayName,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(
              fontWeight: FontWeight.w900,
              color: colors.onPrimaryContainer,
            ),
          ),
          if (user.fullName.isNotEmpty &&
              user.fullName != user.displayName) ...[
            const SizedBox(height: 4),
            Text(
              user.fullName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onPrimaryContainer
                    .withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (user.resolvedCity.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: colors.onPrimaryContainer,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    user.resolvedCity,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (user.oyuncuRozeti)
                const _ProfileChip(
                  label: 'Oyuncu Rozeti',
                  icon: Icons.sports_esports_rounded,
                ),
              if (user.isPlusActive)
                const _ProfileChip(
                  label: 'Plus Üye',
                  icon: Icons.workspace_premium_rounded,
                ),
              if (user.verified)
                const _ProfileChip(
                  label: 'Doğrulanmış',
                  icon: Icons.verified_rounded,
                ),
              StreamBuilder<FriendRequestStatus>(
                stream: FriendService.instance.statusStream(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.data != FriendRequestStatus.friends) {
                    return const SizedBox.shrink();
                  }

                  return const _ProfileChip(
                    label: 'Arkadaş',
                    icon: Icons.people_alt_rounded,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.user,
  });

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final String photoUrl =
    user.profilFotografi.trim();

    return Container(
      width: 112,
      height: 112,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.surface,
        boxShadow: <BoxShadow>[
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: Colors.black.withValues(alpha: 0.14),
          ),
        ],
      ),
      child: ClipOval(
        child: photoUrl.isEmpty
            ? _AvatarFallback(
          displayName: user.displayName,
        )
            : Image.network(
          photoUrl,
          fit: BoxFit.cover,
          errorBuilder: (
              BuildContext context,
              Object error,
              StackTrace? stackTrace,
              ) {
            return _AvatarFallback(
              displayName: user.displayName,
            );
          },
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({
    required this.displayName,
  });

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final String initial = displayName.trim().isEmpty
        ? '?'
        : displayName.trim()[0].toUpperCase();

    return Container(
      color: Theme.of(context).colorScheme.primary,
      alignment: Alignment.center,
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

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors =
        Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: 16,
            color: colors.primary,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStatistics extends StatelessWidget {
  const _ProfileStatistics({
    required this.user,
  });

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatisticCard(
            icon: Icons.star_rounded,
            value: user.puan > 0
                ? user.puan.toStringAsFixed(1)
                : 'Yeni',
            label: user.ratingCount > 0
                ? '${user.ratingCount} değerlendirme'
                : 'Henüz puan yok',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatisticCard(
            icon: Icons.emoji_events_outlined,
            value: '${user.completedEventCount}',
            label: 'Tamamlanan etkinlik',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatisticCard(
            icon: Icons.sports_esports_outlined,
            value: '${user.gameSkills.length}',
            label: 'Profil oyunu',
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
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 14,
        ),
        child: Column(
          children: <Widget>[
            Icon(
              icon,
              color: const Color(0xffFF9800),
              size: 25,
            ),
            const SizedBox(height: 7),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
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
                  'Hakkında',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              text,
              style: const TextStyle(
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _GameCategoryCard extends StatelessWidget {
  const _GameCategoryCard({
    required this.group,
  });

  final _GameCategoryGroup group;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  group.categoryEmoji,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    group.categoryName,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
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
                    color: Theme.of(context)
                        .colorScheme
                        .secondaryContainer,
                    borderRadius:
                    BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${group.skills.length} oyun',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSecondaryContainer,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...group.skills.map(
                  (UserGameSkill skill) => Padding(
                padding:
                const EdgeInsets.only(bottom: 14),
                child: _GameSkillTile(skill: skill),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameSkillTile extends StatelessWidget {
  const _GameSkillTile({
    required this.skill,
  });

  final UserGameSkill skill;

  @override
  Widget build(BuildContext context) {
    final GameDefinition? game =
        GameCatalog.gameById(skill.gameId) ??
            GameCatalog.gameByLegacyValue(skill.gameName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 39,
              height: 39,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                game?.emoji ?? '🎯',
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                skill.gameName,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: _skillBackground(skill.level),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '${skill.levelLabel} · %${skill.level}',
                style: TextStyle(
                  color: _skillForeground(skill.level),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: skill.progress,
            minHeight: 8,
            backgroundColor: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest,
          ),
        ),
      ],
    );
  }

  Color _skillBackground(int level) {
    if (level >= 90) {
      return const Color(0xffDCFCE7);
    }
    if (level >= 60) {
      return const Color(0xffDBEAFE);
    }
    return const Color(0xffFEF3C7);
  }

  Color _skillForeground(int level) {
    if (level >= 90) {
      return const Color(0xff166534);
    }
    if (level >= 60) {
      return const Color(0xff1E40AF);
    }
    return const Color(0xff92400E);
  }
}

class _NoGamesCard extends StatelessWidget {
  const _NoGamesCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.sports_esports_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            const Text(
              'Henüz oyun eklenmemiş',
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Bu oyuncu herkese açık oyun seviyelerini henüz paylaşmadı.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _OwnedBadgesCollection extends StatelessWidget {
  const _OwnedBadgesCollection({
    required this.userId,
  });

  final String userId;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('owned_badges')
          .orderBy('purchasedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final documents = snapshot.data?.docs ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        if (documents.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionHeader(
              title: 'Rozet Koleksiyonu',
              subtitle: 'Oyuncunun marketten edindiği oyun rozetleri',
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 164,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: documents.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final data = documents[index].data();
                  final String title =
                      data['title']?.toString().trim().isNotEmpty == true
                          ? data['title'].toString().trim()
                          : 'Oyun Rozeti';
                  final String gameName =
                      data['gameName']?.toString().trim() ?? '';
                  final String emoji =
                      data['emoji']?.toString().trim().isNotEmpty == true
                          ? data['emoji'].toString().trim()
                          : '🏅';
                  final String imageUrl =
                      data['imageUrl']?.toString().trim() ?? '';

                  return Container(
                    width: 138,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: imageUrl.isNotEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Image.network(
                                      imageUrl,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, _, _) => Text(
                                        emoji,
                                        style: const TextStyle(fontSize: 36),
                                      ),
                                    ),
                                  )
                                : Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 36),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 9),
                        if (gameName.isNotEmpty)
                          Text(
                            gameName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xffC97A10),
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.lock_outline_rounded,
            size: 20,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Gizlilik nedeniyle e-posta, telefon, kullanıcı kimliği, ödeme ve açık adres bilgileri bu profilde gösterilmez.',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicProfileEmpty extends StatelessWidget {
  const _PublicProfileEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.person_off_outlined,
              size: 58,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              'Profil bulunamadı',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Bu oyuncunun herkese açık profiline şu anda ulaşılamıyor.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicProfileError extends StatelessWidget {
  const _PublicProfileError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.error_outline_rounded,
              size: 58,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCategoryGroup {
  const _GameCategoryGroup({
    required this.categoryId,
    required this.categoryName,
    required this.categoryEmoji,
    required this.skills,
  });

  final String categoryId;
  final String categoryName;
  final String categoryEmoji;
  final List<UserGameSkill> skills;
}

class _FriendActionCard extends StatelessWidget {
  const _FriendActionCard({
    required this.user,
  });

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FriendRequestStatus>(
      stream: FriendService.instance.statusStream(user.uid),
      builder: (context, snapshot) {
        final FriendRequestStatus status =
            snapshot.data ?? FriendRequestStatus.none;

        String text;
        IconData icon;
        VoidCallback? onPressed;

        switch (status) {
          case FriendRequestStatus.none:
            text = "Arkadaş Ekle";
            icon = Icons.person_add_alt_1_rounded;
            onPressed = () async {
              await FriendService.instance.sendRequest(user.uid);
            };
            break;

          case FriendRequestStatus.sent:
            text = "İsteği Geri Çek";
            icon = Icons.undo_rounded;
            onPressed = () async {
              final bool? cancel = await showDialog<bool>(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    title: const Text('İsteği Geri Çek'),
                    content: const Text(
                      'Gönderdiğin arkadaşlık isteğini geri çekmek istiyor musun?',
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop(false);
                        },
                        child: const Text('Vazgeç'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop(true);
                        },
                        child: const Text('Geri Çek'),
                      ),
                    ],
                  );
                },
              );

              if (cancel == true) {
                await FriendService.instance.cancelRequest(user.uid);
              }
            };
            break;

          case FriendRequestStatus.received:
            return Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await FriendService.instance.rejectRequest(user.uid);
                    },
                    icon: const Icon(Icons.close_rounded),
                    label: const Text("Reddet"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      await FriendService.instance.acceptRequest(user.uid);
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text("Kabul Et"),
                  ),
                ),
              ],
            );

          case FriendRequestStatus.friends:
            text = "Arkadaşsın";
            icon = Icons.people_alt_rounded;
            onPressed = () async {
              final bool? remove = await showDialog<bool>(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    title: const Text('Arkadaşlıktan Çıkar'),
                    content: const Text(
                      'Bu kullanıcıyı arkadaş listesinden çıkarmak istiyor musun?',
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop(false);
                        },
                        child: const Text('Vazgeç'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop(true);
                        },
                        child: const Text('Çıkar'),
                      ),
                    ],
                  );
                },
              );

              if (remove == true) {
                await FriendService.instance.removeFriend(user.uid);
              }
            };
        }

        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: Icon(icon),
            onPressed: onPressed,
            label: Text(text),
          ),
        );
      },
    );
  }
}
