import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/player_service.dart';
import '../utils/game_catalog.dart';
import 'public_profile_screen.dart';

class FindPlayerScreen extends StatefulWidget {
  const FindPlayerScreen({
    super.key,
  });

  @override
  State<FindPlayerScreen> createState() =>
      _FindPlayerScreenState();
}

class _FindPlayerScreenState
    extends State<FindPlayerScreen> {
  final PlayerService _playerService =
  PlayerService();
  final TextEditingController _cityController =
  TextEditingController();

  String _selectedCategoryId =
      GameCatalog.categories.first.id;
  String _selectedGameId =
      GameCatalog.categories.first.games.first.id;

  int? _minimumSkillLevel;
  bool _onlyVerified = false;
  bool _filterExpanded = false;

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  GameCategoryDefinition get _selectedCategory {
    return GameCatalog.categoryById(
      _selectedCategoryId,
    ) ??
        GameCatalog.categories.first;
  }

  GameDefinition get _selectedGame {
    return GameCatalog.gameById(
      _selectedGameId,
    ) ??
        _selectedCategory.games.first;
  }

  Stream<List<UserModel>> _playersStream() {
    return _playerService.watchPlayersByGame(
      _selectedGameId,
      city: _cityController.text.trim().isEmpty
          ? null
          : _cityController.text.trim(),
      minimumSkillLevel: _minimumSkillLevel,
      onlyWithPlayerBadge: true,
      onlyVerified: _onlyVerified,
    );
  }

  void _selectCategory(
      String? categoryId,
      ) {
    if (categoryId == null) {
      return;
    }

    final GameCategoryDefinition? category =
    GameCatalog.categoryById(categoryId);

    if (category == null ||
        category.games.isEmpty) {
      return;
    }

    setState(() {
      _selectedCategoryId = category.id;
      _selectedGameId = category.games.first.id;
    });
  }

  void _selectGame(
      String? gameId,
      ) {
    if (gameId == null) {
      return;
    }

    setState(() {
      _selectedGameId = gameId;
    });
  }

  void _clearFilters() {
    setState(() {
      _minimumSkillLevel = null;
      _onlyVerified = false;
      _cityController.clear();
    });
  }

  void _openPublicProfile(
      UserModel player,
      ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicProfileScreen(
          userId: player.uid,
          initialUser: player,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors =
        Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text(
          'Oyuncu Bul',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: <Widget>[
          _SearchHeader(
            selectedCategoryId:
            _selectedCategoryId,
            selectedGameId: _selectedGameId,
            selectedCategory:
            _selectedCategory,
            selectedGame: _selectedGame,
            cityController: _cityController,
            minimumSkillLevel:
            _minimumSkillLevel,
            onlyVerified: _onlyVerified,
            filterExpanded: _filterExpanded,
            onCategoryChanged:
            _selectCategory,
            onGameChanged: _selectGame,
            onCitySubmitted: (_) {
              setState(() {});
            },
            onToggleFilters: () {
              setState(() {
                _filterExpanded =
                !_filterExpanded;
              });
            },
            onSkillChanged: (int? level) {
              setState(() {
                _minimumSkillLevel = level;
              });
            },
            onVerifiedChanged: (bool value) {
              setState(() {
                _onlyVerified = value;
              });
            },
            onClearFilters: _clearFilters,
          ),
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: _playersStream(),
              builder: (
                  BuildContext context,
                  AsyncSnapshot<List<UserModel>>
                  snapshot,
                  ) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child:
                    CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return _PlayersError(
                    onRetry: () {
                      setState(() {});
                    },
                  );
                }

                final List<UserModel> players =
                    snapshot.data ??
                        <UserModel>[];

                if (players.isEmpty) {
                  return _PlayersEmpty(
                    selectedGame: _selectedGame,
                    hasFilters:
                    _minimumSkillLevel != null ||
                        _onlyVerified ||
                        _cityController.text
                            .trim()
                            .isNotEmpty,
                    onClearFilters: _clearFilters,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                    await Future<void>.delayed(
                      const Duration(
                        milliseconds: 350,
                      ),
                    );
                  },
                  child: ListView.separated(
                    physics:
                    const AlwaysScrollableScrollPhysics(),
                    padding:
                    const EdgeInsets.fromLTRB(
                      16,
                      14,
                      16,
                      28,
                    ),
                    itemCount: players.length + 1,
                    separatorBuilder: (
                        BuildContext context,
                        int index,
                        ) {
                      return const SizedBox(
                        height: 11,
                      );
                    },
                    itemBuilder: (
                        BuildContext context,
                        int index,
                        ) {
                      if (index == 0) {
                        return _ResultSummary(
                          playerCount:
                          players.length,
                          game:
                          _selectedGame,
                        );
                      }

                      final UserModel player =
                      players[index - 1];

                      return _PlayerCard(
                        player: player,
                        selectedGame:
                        _selectedGame,
                        onOpenProfile: () {
                          _openPublicProfile(
                            player,
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.selectedCategoryId,
    required this.selectedGameId,
    required this.selectedCategory,
    required this.selectedGame,
    required this.cityController,
    required this.minimumSkillLevel,
    required this.onlyVerified,
    required this.filterExpanded,
    required this.onCategoryChanged,
    required this.onGameChanged,
    required this.onCitySubmitted,
    required this.onToggleFilters,
    required this.onSkillChanged,
    required this.onVerifiedChanged,
    required this.onClearFilters,
  });

  final String selectedCategoryId;
  final String selectedGameId;
  final GameCategoryDefinition
  selectedCategory;
  final GameDefinition selectedGame;
  final TextEditingController cityController;
  final int? minimumSkillLevel;
  final bool onlyVerified;
  final bool filterExpanded;

  final ValueChanged<String?>
  onCategoryChanged;
  final ValueChanged<String?> onGameChanged;
  final ValueChanged<String> onCitySubmitted;
  final VoidCallback onToggleFilters;
  final ValueChanged<int?> onSkillChanged;
  final ValueChanged<bool> onVerifiedChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors =
        Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16,
          10,
          16,
          14,
        ),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child:
                  DropdownButtonFormField<String>(
                    initialValue:
                    selectedCategoryId,
                    isExpanded: true,
                    decoration:
                    const InputDecoration(
                      labelText: 'Kategori',
                      prefixIcon: Icon(
                        Icons.category_outlined,
                      ),
                    ),
                    items: GameCatalog.categories
                        .map(
                          (
                          GameCategoryDefinition
                          category,
                          ) {
                        return DropdownMenuItem<
                            String>(
                          value: category.id,
                          child: Text(
                            '${category.emoji} ${category.name}',
                            overflow:
                            TextOverflow
                                .ellipsis,
                          ),
                        );
                      },
                    )
                        .toList(),
                    onChanged:
                    onCategoryChanged,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child:
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>(
                      selectedCategoryId,
                    ),
                    initialValue: selectedGameId,
                    isExpanded: true,
                    decoration:
                    const InputDecoration(
                      labelText: 'Oyun / spor',
                      prefixIcon: Icon(
                        Icons
                            .sports_esports_outlined,
                      ),
                    ),
                    items: selectedCategory.games
                        .map(
                          (GameDefinition game) {
                        return DropdownMenuItem<
                            String>(
                          value: game.id,
                          child: Text(
                            game.displayName,
                            overflow:
                            TextOverflow
                                .ellipsis,
                          ),
                        );
                      },
                    )
                        .toList(),
                    onChanged: onGameChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: cityController,
                    textInputAction:
                    TextInputAction.search,
                    decoration:
                    const InputDecoration(
                      labelText:
                      'Şehir (isteğe bağlı)',
                      prefixIcon: Icon(
                        Icons.location_city_outlined,
                      ),
                      hintText: 'Örn. İstanbul',
                    ),
                    onSubmitted:
                    onCitySubmitted,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip:
                  'Gelişmiş filtreler',
                  onPressed: onToggleFilters,
                  icon: Icon(
                    filterExpanded
                        ? Icons
                        .filter_list_off_rounded
                        : Icons
                        .filter_list_rounded,
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              duration: const Duration(
                milliseconds: 220,
              ),
              crossFadeState: filterExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild:
              const SizedBox.shrink(),
              secondChild: Padding(
                padding:
                const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Minimum seviye',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: <Widget>[
                        ChoiceChip(
                          label:
                          const Text('Tümü'),
                          selected:
                          minimumSkillLevel ==
                              null,
                          onSelected: (_) {
                            onSkillChanged(null);
                          },
                        ),
                        ...GameCatalog.skillLevels.map(
                              (
                              SkillLevelDefinition
                              level,
                              ) {
                            return ChoiceChip(
                              label: Text(
                                '${level.label} · %${level.value}',
                              ),
                              selected:
                              minimumSkillLevel ==
                                  level.value,
                              onSelected: (_) {
                                onSkillChanged(
                                  level.value,
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding:
                      EdgeInsets.zero,
                      title: const Text(
                        'Yalnızca doğrulanmış oyuncular',
                        style: TextStyle(
                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        'Doğrulama işlemi tamamlanan profilleri gösterir.',
                      ),
                      value: onlyVerified,
                      onChanged:
                      onVerifiedChanged,
                    ),
                    Align(
                      alignment:
                      Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed:
                        onClearFilters,
                        icon: const Icon(
                          Icons
                              .restart_alt_rounded,
                        ),
                        label: const Text(
                          'Filtreleri temizle',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({
    required this.playerCount,
    required this.game,
  });

  final int playerCount;
  final GameDefinition game;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .secondaryContainer,
            borderRadius:
            BorderRadius.circular(14),
          ),
          child: Text(
            game.emoji,
            style: const TextStyle(
              fontSize: 22,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${game.name} oyuncuları',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  fontWeight:
                  FontWeight.w900,
                ),
              ),
              Text(
                '$playerCount uygun oyuncu bulundu',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                  fontSize: 12,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.player,
    required this.selectedGame,
    required this.onOpenProfile,
  });

  final UserModel player;
  final GameDefinition selectedGame;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final UserGameSkill? skill =
    player.skillForGame(selectedGame.id);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenProfile,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  _PlayerAvatar(player: player),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                player.displayName,
                                maxLines: 1,
                                overflow:
                                TextOverflow
                                    .ellipsis,
                                style: Theme.of(
                                  context,
                                )
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                  fontWeight:
                                  FontWeight
                                      .w900,
                                ),
                              ),
                            ),
                            if (player.verified) ...[
                              const SizedBox(
                                width: 5,
                              ),
                              const Icon(
                                Icons
                                    .verified_rounded,
                                size: 18,
                                color:
                                Color(0xff2563EB),
                              ),
                            ],
                            if (player.plus) ...[
                              const SizedBox(
                                width: 5,
                              ),
                              const Icon(
                                Icons
                                    .workspace_premium_rounded,
                                size: 18,
                                color:
                                Color(0xffFF9800),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.star_rounded,
                              size: 17,
                              color:
                              Color(0xffFF9800),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              player.puan > 0
                                  ? player.puan
                                  .toStringAsFixed(
                                1,
                              )
                                  : 'Yeni',
                              style:
                              const TextStyle(
                                fontWeight:
                                FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              Icons
                                  .emoji_events_outlined,
                              size: 16,
                              color: Theme.of(
                                context,
                              )
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                '${player.completedEventCount} tamamlanan etkinlik',
                                maxLines: 1,
                                overflow:
                                TextOverflow
                                    .ellipsis,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  )
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 12,
                                  fontWeight:
                                  FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _InfoPill(
                      icon: Icons
                          .location_on_outlined,
                      text: player
                          .resolvedCity
                          .isEmpty
                          ? 'Konum eklenmedi'
                          : player.resolvedCity,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SkillPill(
                    skill: skill,
                  ),
                ],
              ),
              if (skill != null) ...[
                const SizedBox(height: 11),
                ClipRRect(
                  borderRadius:
                  BorderRadius.circular(99),
                  child:
                  LinearProgressIndicator(
                    value: skill.progress,
                    minHeight: 8,
                    backgroundColor:
                    Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child:
                FilledButton.tonalIcon(
                  onPressed: onOpenProfile,
                  icon: const Icon(
                    Icons
                        .account_circle_outlined,
                  ),
                  label: const Text(
                    'Herkese açık profili gör',
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

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({
    required this.player,
  });

  final UserModel player;

  @override
  Widget build(BuildContext context) {
    final String photoUrl =
    player.profilFotografi.trim();

    return CircleAvatar(
      radius: 29,
      backgroundColor:
      Theme.of(context).colorScheme.primary,
      foregroundImage: photoUrl.isEmpty
          ? null
          : NetworkImage(photoUrl),
      child: Text(
        player.displayName.trim().isEmpty
            ? '?'
            : player.displayName
            .trim()[0]
            .toUpperCase(),
        style: TextStyle(
          color: Theme.of(context)
              .colorScheme
              .onPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            icon,
            size: 17,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillPill extends StatelessWidget {
  const _SkillPill({
    required this.skill,
  });

  final UserGameSkill? skill;

  @override
  Widget build(BuildContext context) {
    final int level = skill?.level ?? 30;
    final String label =
        skill?.levelLabel ?? 'Başlangıç';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: _background(level),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label · %$level',
        style: TextStyle(
          color: _foreground(level),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Color _background(int level) {
    if (level >= 90) {
      return const Color(0xffDCFCE7);
    }
    if (level >= 60) {
      return const Color(0xffDBEAFE);
    }
    return const Color(0xffFEF3C7);
  }

  Color _foreground(int level) {
    if (level >= 90) {
      return const Color(0xff166534);
    }
    if (level >= 60) {
      return const Color(0xff1E40AF);
    }
    return const Color(0xff92400E);
  }
}

class _PlayersEmpty extends StatelessWidget {
  const _PlayersEmpty({
    required this.selectedGame,
    required this.hasFilters,
    required this.onClearFilters,
  });

  final GameDefinition selectedGame;
  final bool hasFilters;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              selectedGame.emoji,
              style:
              const TextStyle(fontSize: 56),
            ),
            const SizedBox(height: 12),
            Text(
              '${selectedGame.name} için oyuncu bulunamadı',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              hasFilters
                  ? 'Seçtiğin filtrelere uygun, Oyuncu Rozeti bulunan bir profil yok.'
                  : 'Bu oyun için Oyuncu Rozeti bulunan bir profil henüz yok.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
                height: 1.4,
              ),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(
                  Icons.restart_alt_rounded,
                ),
                label: const Text(
                  'Filtreleri temizle',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlayersError extends StatelessWidget {
  const _PlayersError({
    required this.onRetry,
  });

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
              size: 54,
            ),
            const SizedBox(height: 12),
            const Text(
              'Oyuncular yüklenirken bir hata oluştu.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label:
              const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}