class GameCategoryDefinition {
  const GameCategoryDefinition({
    required this.id,
    required this.name,
    required this.emoji,
    required this.basePricePerPlayer,
    required this.games,
  });

  final String id;
  final String name;
  final String emoji;

  /// Bir oyuncu için ilk saatin taban fiyatı.
  final double basePricePerPlayer;

  final List<GameDefinition> games;
}

class GameDefinition {
  const GameDefinition({
    required this.id,
    required this.name,
    required this.emoji,
    required this.categoryId,
  });

  final String id;
  final String name;
  final String emoji;
  final String categoryId;

  String get displayName => '$emoji $name';
}

class SkillLevelDefinition {
  const SkillLevelDefinition({required this.value, required this.label});

  /// Profilde ve bar üzerinde kullanılacak yüzde değeri.
  final int value;
  final String label;
}

/// Uygulamadaki oyun, spor, kategori, seviye ve fiyatlandırma
/// bilgilerinin tek merkezidir.
///
/// Etkinlik oluşturma, profil düzenleme, ana sayfa, harita,
/// filtreleme ve başvuru kontrolleri bu dosyadaki kimlikleri
/// kullanmalıdır.
abstract final class GameCatalog {
  static const List<SkillLevelDefinition> skillLevels = [
    SkillLevelDefinition(value: 30, label: 'Acemi'),
    SkillLevelDefinition(value: 60, label: 'Orta'),
    SkillLevelDefinition(value: 90, label: 'Usta'),
  ];

  static const List<GameCategoryDefinition> categories = [
    GameCategoryDefinition(
      id: 'masa_oyunlari',
      name: 'Masa Oyunları',
      emoji: '🎲',
      basePricePerPlayer: 800,
      games: [
        GameDefinition(
          id: 'okey',
          name: 'Okey',
          emoji: '🎴',
          categoryId: 'masa_oyunlari',
        ),
        GameDefinition(
          id: 'okey_101',
          name: '101',
          emoji: '🀄',
          categoryId: 'masa_oyunlari',
        ),
        GameDefinition(
          id: 'batak',
          name: 'Batak',
          emoji: '♠️',
          categoryId: 'masa_oyunlari',
        ),
        GameDefinition(
          id: 'tavla',
          name: 'Tavla',
          emoji: '🎲',
          categoryId: 'masa_oyunlari',
        ),
        GameDefinition(
          id: 'satranc',
          name: 'Satranç',
          emoji: '♟️',
          categoryId: 'masa_oyunlari',
        ),
        GameDefinition(
          id: 'bric',
          name: 'Briç',
          emoji: '🃏',
          categoryId: 'masa_oyunlari',
        ),
        GameDefinition(
          id: 'king',
          name: 'King',
          emoji: '👑',
          categoryId: 'masa_oyunlari',
        ),
        GameDefinition(
          id: 'monopoly',
          name: 'Monopoly',
          emoji: '🏠',
          categoryId: 'masa_oyunlari',
        ),
        GameDefinition(
          id: 'uno',
          name: 'Uno',
          emoji: '🟥',
          categoryId: 'masa_oyunlari',
        ),
        GameDefinition(
          id: 'jenga',
          name: 'Jenga',
          emoji: '🧱',
          categoryId: 'masa_oyunlari',
        ),
        GameDefinition(
          id: 'scrabble',
          name: 'Scrabble',
          emoji: '🔤',
          categoryId: 'masa_oyunlari',
        ),
        GameDefinition(
          id: 'tombala',
          name: 'Tombala',
          emoji: '🔢',
          categoryId: 'masa_oyunlari',
        ),
      ],
    ),
    GameCategoryDefinition(
      id: 'konsol_oyunlari',
      name: 'Konsol Oyunları',
      emoji: '🎮',
      basePricePerPlayer: 1000,
      games: [
        GameDefinition(
          id: 'ea_fc',
          name: 'EA FC',
          emoji: '⚽',
          categoryId: 'konsol_oyunlari',
        ),
        GameDefinition(
          id: 'efootball',
          name: 'eFootball',
          emoji: '🎮',
          categoryId: 'konsol_oyunlari',
        ),
        GameDefinition(
          id: 'tekken',
          name: 'Tekken',
          emoji: '🥊',
          categoryId: 'konsol_oyunlari',
        ),
      ],
    ),
    GameCategoryDefinition(
      id: 'raket_sporlari',
      name: 'Raket Sporları',
      emoji: '🎾',
      basePricePerPlayer: 1300,
      games: [
        GameDefinition(
          id: 'tenis',
          name: 'Tenis',
          emoji: '🎾',
          categoryId: 'raket_sporlari',
        ),
        GameDefinition(
          id: 'masa_tenisi',
          name: 'Masa Tenisi',
          emoji: '🏓',
          categoryId: 'raket_sporlari',
        ),
        GameDefinition(
          id: 'badminton',
          name: 'Badminton',
          emoji: '🏸',
          categoryId: 'raket_sporlari',
        ),
        GameDefinition(
          id: 'squash',
          name: 'Squash',
          emoji: '🎾',
          categoryId: 'raket_sporlari',
        ),
        GameDefinition(
          id: 'pickleball',
          name: 'Pickleball',
          emoji: '🏓',
          categoryId: 'raket_sporlari',
        ),
      ],
    ),
    GameCategoryDefinition(
      id: 'takim_sporlari',
      name: 'Takım Sporları',
      emoji: '🏆',
      basePricePerPlayer: 1600,
      games: [
        GameDefinition(
          id: 'futbol',
          name: 'Futbol',
          emoji: '⚽',
          categoryId: 'takim_sporlari',
        ),
        GameDefinition(
          id: 'basketbol',
          name: 'Basketbol',
          emoji: '🏀',
          categoryId: 'takim_sporlari',
        ),
        GameDefinition(
          id: 'voleybol',
          name: 'Voleybol',
          emoji: '🏐',
          categoryId: 'takim_sporlari',
        ),
        GameDefinition(
          id: 'hentbol',
          name: 'Hentbol',
          emoji: '🤾',
          categoryId: 'takim_sporlari',
        ),
      ],
    ),
    GameCategoryDefinition(
      id: 'premium_sporlar',
      name: 'Premium Sporlar',
      emoji: '⛳',
      basePricePerPlayer: 2500,
      games: [
        GameDefinition(
          id: 'golf',
          name: 'Golf',
          emoji: '⛳',
          categoryId: 'premium_sporlar',
        ),
        GameDefinition(
          id: 'yelken',
          name: 'Yelken',
          emoji: '⛵',
          categoryId: 'premium_sporlar',
        ),
        GameDefinition(
          id: 'kurek',
          name: 'Kürek',
          emoji: '🚣',
          categoryId: 'premium_sporlar',
        ),
        GameDefinition(
          id: 'binicilik',
          name: 'Binicilik',
          emoji: '🏇',
          categoryId: 'premium_sporlar',
        ),
        GameDefinition(
          id: 'kayak',
          name: 'Kayak',
          emoji: '⛷️',
          categoryId: 'premium_sporlar',
        ),
        GameDefinition(
          id: 'snowboard',
          name: 'Snowboard',
          emoji: '🏂',
          categoryId: 'premium_sporlar',
        ),
        GameDefinition(
          id: 'paintball',
          name: 'Paintball',
          emoji: '🎯',
          categoryId: 'premium_sporlar',
        ),
      ],
    ),
  ];

  /// Süre uzadıkça saat başına düşen ek ücret azalır.
  ///
  /// 1 saat: x1.00
  /// 2 saat: x1.70
  /// 3 saat: x2.30
  /// 4 saat: x2.80
  /// 5 saat: x3.20
  /// 6 saat: x3.50
  static const Map<int, double> durationFactors = {
    1: 1.00,
    2: 1.70,
    3: 2.30,
    4: 2.80,
    5: 3.20,
    6: 3.50,
  };

  static const int minimumDurationMinutes = 60;
  static const int maximumDurationMinutes = 360;
  static const int durationStepMinutes = 30;

  static List<GameDefinition> get allGames => [
    for (final category in categories) ...category.games,
  ];

  static GameCategoryDefinition? categoryById(String? categoryId) {
    if (categoryId == null || categoryId.trim().isEmpty) {
      return null;
    }

    final normalizedId = normalizeId(categoryId);
    for (final category in categories) {
      if (category.id == normalizedId ||
          normalizeId(category.name) == normalizedId) {
        return category;
      }
    }
    return null;
  }

  static GameDefinition? gameById(String? gameId) {
    if (gameId == null || gameId.trim().isEmpty) {
      return null;
    }

    final normalizedId = normalizeId(gameId);
    for (final game in allGames) {
      if (game.id == normalizedId ||
          normalizeId(game.name) == normalizedId ||
          normalizeId(game.displayName) == normalizedId) {
        return game;
      }
    }
    return null;
  }

  static GameDefinition? gameByLegacyValue(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final normalizedValue = normalizeId(value);

    const aliases = <String, String>{
      '101_okey': 'okey_101',
      'konsol_oyunu': 'ea_fc',
      'konsol_oyunlari': 'ea_fc',
      'kutu_oyunu': 'monopoly',
      'kutu_oyunlari': 'monopoly',
    };

    final aliasId = aliases[normalizedValue];
    if (aliasId != null) {
      return gameById(aliasId);
    }

    for (final game in allGames) {
      if (normalizedValue == game.id ||
          normalizedValue == normalizeId(game.name) ||
          normalizedValue == normalizeId(game.displayName)) {
        return game;
      }
    }

    return null;
  }

  static GameCategoryDefinition? categoryForGame(String? gameIdOrName) {
    final game = gameById(gameIdOrName) ?? gameByLegacyValue(gameIdOrName);
    if (game == null) {
      return null;
    }
    return categoryById(game.categoryId);
  }

  static SkillLevelDefinition skillLevelForValue(int? value) {
    final resolved = value ?? 30;

    if (resolved >= 75) {
      return skillLevels[2];
    }
    if (resolved >= 45) {
      return skillLevels[1];
    }
    return skillLevels[0];
  }

  static double durationFactorForMinutes(int durationMinutes) {
    if (durationMinutes <= 0) {
      return 0;
    }

    final clampedMinutes = durationMinutes.clamp(
      minimumDurationMinutes,
      maximumDurationMinutes,
    );

    final exactHours = clampedMinutes / 60;
    final lowerHour = exactHours.floor().clamp(1, 6);
    final upperHour = exactHours.ceil().clamp(1, 6);

    final lowerFactor = durationFactors[lowerHour] ?? 1;
    final upperFactor = durationFactors[upperHour] ?? lowerFactor;

    if (lowerHour == upperHour) {
      return lowerFactor;
    }

    final progress = exactHours - lowerHour;
    return lowerFactor + ((upperFactor - lowerFactor) * progress);
  }

  static double calculateTotalPrice({
    required String gameId,
    required int playerCount,
    required int durationMinutes,
  }) {
    final game = gameById(gameId) ?? gameByLegacyValue(gameId);
    if (game == null || playerCount <= 0 || durationMinutes <= 0) {
      return 0;
    }

    final category = categoryById(game.categoryId);
    if (category == null) {
      return 0;
    }

    final durationFactor = durationFactorForMinutes(durationMinutes);
    final rawTotal = category.basePricePerPlayer * playerCount * durationFactor;

    /// Kullanıcıya temiz rakam göstermek için en yakın 10 TL'ye yuvarlanır.
    return (rawTotal / 10).round() * 10;
  }

  static String normalizeId(String value) {
    var text = value.trim().toLowerCase();

    const replacements = <String, String>{
      'ç': 'c',
      'ğ': 'g',
      'ı': 'i',
      'ö': 'o',
      'ş': 's',
      'ü': 'u',
    };

    replacements.forEach((source, target) {
      text = text.replaceAll(source, target);
    });

    text = text.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    text = text.replaceAll(RegExp(r'_+'), '_');
    text = text.replaceAll(RegExp(r'^_|_$'), '');

    return text;
  }
}
