import 'package:dorduncu/utils/game_catalog.dart';
import 'package:dorduncu/widgets/game_badge_art.dart';
import 'package:dorduncu/widgets/game_badge_symbols.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V1 ve eski katalog kimliklerinin her birinin özgün çizimi var', () {
    final Set<String> seen = <String>{};
    for (final String id in badgeArtGameIds) {
      expect(hasGameBadgeArt(id), isTrue, reason: id);
      expect(seen.add(id), isTrue, reason: id);
      expect(badgeArtLabels[id], isNotNull, reason: id);
    }

    for (final game in GameCatalog.allGames) {
      expect(resolveBadgeGameId(gameId: game.id, gameName: game.name), game.id);
    }

    expect(
      resolveBadgeGameId(gameId: 'okey_101', gameName: '101'),
      isNot(resolveBadgeGameId(gameId: 'okey', gameName: 'Okey')),
    );
    expect(resolveBadgeGameId(gameId: '', gameName: '101'), 'okey_101');
    expect(resolveBadgeGameId(gameId: 'hali', gameName: 'Halı Saha'), 'hali');
    expect(badgeArtGameIds.length, 39);
  });
}
