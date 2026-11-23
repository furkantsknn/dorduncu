import 'package:flutter/material.dart';

import '../utils/game_catalog.dart';

/// Uses the bundled Material icon font instead of device emoji fallback.
/// This is a small list/selection icon, not a game cover or Market badge.
class GameCatalogIcon extends StatelessWidget {
  const GameCatalogIcon({
    this.gameIdOrName,
    this.categoryId,
    this.size = 24,
    this.color,
    super.key,
  });

  final String? gameIdOrName;
  final String? categoryId;
  final double size;
  final Color? color;

  static IconData iconFor({String? gameIdOrName, String? categoryId}) {
    final GameDefinition? game =
        GameCatalog.gameById(gameIdOrName) ??
        GameCatalog.gameByLegacyValue(gameIdOrName);
    final String category =
        game?.categoryId ?? GameCatalog.categoryById(categoryId)?.id ?? '';
    return switch (category) {
      'masa_oyunlari' => Icons.casino_outlined,
      'konsol_oyunlari' => Icons.sports_esports_outlined,
      'raket_sporlari' => Icons.sports_tennis_outlined,
      'takim_sporlari' => Icons.groups_outlined,
      'premium_sporlar' => Icons.workspace_premium_outlined,
      _ => Icons.sports_outlined,
    };
  }

  @override
  Widget build(BuildContext context) => Icon(
    iconFor(gameIdOrName: gameIdOrName, categoryId: categoryId),
    size: size,
    color: color,
  );
}
