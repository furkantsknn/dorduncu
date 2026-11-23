import 'game_catalog.dart';

/// `game_image_mapping.csv` ile aynı: GameCatalog internal id → kapak.
/// Eşleşme tam kimliktir. Okey / 101 / Tavla / Satranç birbirine düşmez.
abstract final class GameCoverAssets {
  static const Map<String, String> byId = <String, String>{
    'okey': 'assets/images/games/okey.jpg',
    'okey_101': 'assets/images/games/okey_101.jpg',
    'batak': 'assets/images/games/batak.jpg',
    'tavla': 'assets/images/games/tavla.jpg',
    'satranc': 'assets/images/games/satranc.jpg',
    'bric': 'assets/images/games/bric.jpg',
    'king': 'assets/images/games/king.jpg',
    'monopoly': 'assets/images/games/monopoly.jpg',
    'uno': 'assets/images/games/uno.jpg',
    'jenga': 'assets/images/games/jenga.jpg',
    'scrabble': 'assets/images/games/scrabble.jpg',
    'tombala': 'assets/images/games/tombala.jpg',
    'ea_fc': 'assets/images/games/ea_fc.jpg',
    'efootball': 'assets/images/games/efootball.jpg',
    'tekken': 'assets/images/games/tekken.jpg',
    'tenis': 'assets/images/games/tenis.jpg',
    'masa_tenisi': 'assets/images/games/masa_tenisi.jpg',
    'badminton': 'assets/images/games/badminton.jpg',
    'squash': 'assets/images/games/squash.jpg',
    'pickleball': 'assets/images/games/pickleball.jpg',
    'futbol': 'assets/images/games/futbol.jpg',
    'basketbol': 'assets/images/games/basketbol.jpg',
    'voleybol': 'assets/images/games/voleybol.jpg',
    'hentbol': 'assets/images/games/hentbol.jpg',
    'golf': 'assets/images/games/golf.jpg',
    'yelken': 'assets/images/games/yelken.jpg',
    'kurek': 'assets/images/games/kurek.jpg',
    'binicilik': 'assets/images/games/binicilik.jpg',
    'kayak': 'assets/images/games/kayak.jpg',
    'snowboard': 'assets/images/games/snowboard.jpg',
    'paintball': 'assets/images/games/paintball.png',
  };

  static String? pathFor(String? gameType) {
    if (gameType == null || gameType.trim().isEmpty) {
      return null;
    }

    final game =
        GameCatalog.gameById(gameType) ??
        GameCatalog.gameByLegacyValue(gameType);
    if (game != null) {
      return byId[game.id];
    }

    return byId[GameCatalog.normalizeId(gameType)];
  }
}
