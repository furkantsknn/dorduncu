import 'dart:io';

import 'package:dorduncu/utils/game_catalog.dart';
import 'package:dorduncu/utils/game_cover_assets.dart';
import 'package:dorduncu/widgets/premium_badge_assets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Paintball has one exact catalog entry and separate visuals', () {
    final matches = GameCatalog.allGames
        .where((game) => game.id == 'paintball')
        .toList();

    expect(matches, hasLength(1));
    expect(matches.single.name, 'Paintball');
    expect(matches.single.categoryId, 'premium_sporlar');
    expect(GameCatalog.gameById('paint_ball'), isNull);

    const cover = 'assets/images/games/paintball.png';
    const badge = 'assets/images/badges/premium_v1/paintball.png';
    expect(GameCoverAssets.pathFor('paintball'), cover);
    expect(premiumBadgeAsset('paintball'), badge);
    expect(cover, isNot(badge));
    expect(File(cover).existsSync(), isTrue);
    expect(File(badge).existsSync(), isTrue);
  });
}
