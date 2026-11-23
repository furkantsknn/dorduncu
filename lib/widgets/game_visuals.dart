import 'package:flutter/material.dart';

import '../utils/game_catalog.dart';

class GameVisual {
  const GameVisual({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
  });

  final String id;
  final String name;
  final String emoji;
  final Color color;
}

abstract final class GameVisuals {
  static GameVisual resolve(String? gameIdOrName) {
    final raw = gameIdOrName?.trim() ?? '';
    final game =
        GameCatalog.gameById(raw) ?? GameCatalog.gameByLegacyValue(raw);
    final id = game?.id ?? GameCatalog.normalizeId(cleanName(raw));
    final name = game?.name ?? cleanName(raw);
    final badgeEmoji =
        _marketBadgeEmoji[id] ??
        _marketBadgeEmoji[GameCatalog.normalizeId(name)];
    final emoji = badgeEmoji ?? game?.emoji ?? _fallbackEmoji(id, name);

    return GameVisual(
      id: id,
      name: name.isEmpty ? 'Etkinlik' : name,
      emoji: emoji,
      color: _colorFor(id, name),
    );
  }

  static String emoji(String? gameIdOrName) => resolve(gameIdOrName).emoji;

  static String name(String? gameIdOrName) => resolve(gameIdOrName).name;

  static Color color(String? gameIdOrName) => resolve(gameIdOrName).color;

  static String cleanName(String value) {
    return value
        .replaceFirst(RegExp(r'^[^A-Za-zÇĞİÖŞÜçğıöşü0-9]+\s*'), '')
        .trim();
  }

  static Color _colorFor(String id, String name) {
    final value =
        '${GameCatalog.normalizeId(id)} '
        '${GameCatalog.normalizeId(name)}';

    if (value.contains('futbol')) return const Color(0xff22C55E);
    if (value.contains('basketbol')) return const Color(0xffF97316);
    if (value.contains('tenis') ||
        value.contains('badminton') ||
        value.contains('squash') ||
        value.contains('pickleball')) {
      return const Color(0xff3B82F6);
    }
    if (value.contains('voleybol')) return const Color(0xff8B5CF6);
    if (value.contains('batak')) return const Color(0xff111827);
    if (value.contains('satranc')) return const Color(0xff6B7280);
    if (value.contains('bilardo')) return const Color(0xff059669);
    if (value.contains('okey') ||
        value.contains('tavla') ||
        value.contains('bric') ||
        value.contains('king') ||
        value.contains('monopoly') ||
        value.contains('uno') ||
        value.contains('jenga') ||
        value.contains('scrabble') ||
        value.contains('tombala')) {
      return const Color(0xffFF9800);
    }
    if (value.contains('ea_fc') ||
        value.contains('efootball') ||
        value.contains('tekken')) {
      return const Color(0xff7C3AED);
    }
    if (value.contains('golf') ||
        value.contains('yelken') ||
        value.contains('kurek') ||
        value.contains('binicilik') ||
        value.contains('kayak') ||
        value.contains('snowboard')) {
      return const Color(0xff0F766E);
    }

    return const Color(0xffFF9800);
  }

  static String _fallbackEmoji(String id, String name) {
    final value =
        '${GameCatalog.normalizeId(id)} '
        '${GameCatalog.normalizeId(name)}';

    if (value.contains('futbol')) return '⚽';
    if (value.contains('basketbol')) return '🏀';
    if (value.contains('voleybol')) return '🏐';
    if (value.contains('masa_tenisi')) return '🏓';
    if (value.contains('badminton')) return '🏸';
    if (value.contains('tenis')) return '🎾';
    if (value.contains('batak')) return '♠️';
    if (value.contains('okey_101') || value.contains('101')) return '🀄';
    if (value.contains('okey')) return '🎴';
    if (value.contains('tavla')) return '🎲';
    if (value.contains('satranc')) return '♟️';
    if (value.contains('tombala')) return '🔢';
    if (value.contains('bilardo')) return '🎱';
    if (value.contains('konsol') ||
        value.contains('ea_fc') ||
        value.contains('efootball') ||
        value.contains('tekken')) {
      return '🎮';
    }

    return '🎯';
  }
}

/// Market `seedBadgeProducts` ile aynı emoji. Görsel dosya yok.
const Map<String, String> _marketBadgeEmoji = <String, String>{
  'okey': '🎴',
  'okey_101': '🀄',
  'paintball': '🎯',
  'batak': '♠️',
  'tavla': '🎲',
  'satranc': '♟️',
  'bric': '🃏',
  'king': '👑',
  'monopoly': '🏠',
  'bilardo': '🎱',
  'bowling': '🎳',
  'dart': '🎯',
  'langirt': '⚽',
  'playstation': '🎮',
  'futbol': '⚽',
  'basketbol': '🏀',
  'voleybol': '🏐',
  'hentbol': '🤾',
  'tenis': '🎾',
  'masa_tenisi': '🏓',
  'badminton': '🏸',
  'squash': '🎾',
  'kosu': '🏃',
  'bisiklet': '🚴',
  'yuzme': '🏊',
  'golf': '⛳',
  'yelken': '⛵',
  'kurek': '🚣',
  'binicilik': '🏇',
  'kayak': '⛷️',
  'snowboard': '🏂',
};
