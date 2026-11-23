import 'package:flutter/material.dart';

import 'game_badge_art.dart';
import 'premium_badge_assets.dart';

/// Oyun rozeti. Çizim exact game id ile seçilir; emoji ve kapak kullanılmaz.
class GameBadgeEmblem extends StatelessWidget {
  const GameBadgeEmblem({
    required this.emoji,
    required this.imageUrl,
    required this.gameName,
    this.gameId = '',
    this.size = 64,
    super.key,
  });

  final String emoji;
  final String imageUrl;
  final String gameName;
  final String gameId;
  final double size;

  @override
  Widget build(BuildContext context) {
    assert(emoji.isEmpty || emoji.isNotEmpty);
    assert(imageUrl.isEmpty || imageUrl.isNotEmpty);
    final String resolved = resolveBadgeGameId(
      gameId: gameId,
      gameName: gameName,
    );
    final String label = gameName.trim().isNotEmpty
        ? gameName.trim()
        : resolved;
    final String? asset = premiumBadgeAsset(resolved);
    if (asset != null) {
      return _PremiumBadgeImage(
        asset: asset,
        size: size,
        label: label,
        drawScale: premiumBadgeDrawScale(resolved),
      );
    }
    if (hasGameBadgeArt(resolved)) {
      return GameBadgeArt(gameId: resolved, size: size, label: label);
    }
    return GameBadgeArt(gameId: '', size: size, label: label);
  }
}

class _PremiumBadgeImage extends StatelessWidget {
  const _PremiumBadgeImage({
    required this.asset,
    required this.size,
    required this.label,
    required this.drawScale,
  });

  final String asset;
  final double size;
  final String label;
  final double drawScale;

  @override
  Widget build(BuildContext context) {
    final double drawn = size * drawScale;
    final int cache = _decodePixels(
      drawn,
      MediaQuery.devicePixelRatioOf(context),
    );
    return Semantics(
      image: true,
      label: label,
      child: SizedBox(
        width: size,
        height: size,
        child: ClipRect(
          child: OverflowBox(
            minWidth: drawn,
            maxWidth: drawn,
            minHeight: drawn,
            maxHeight: drawn,
            child: Image.asset(
              asset,
              width: drawn,
              height: drawn,
              fit: BoxFit.fill,
              cacheWidth: cache,
              cacheHeight: cache,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              excludeFromSemantics: true,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stack) {
                    return GameBadgeArt(gameId: '', size: size);
                  },
            ),
          ),
        ),
      ),
    );
  }
}

int _decodePixels(double logical, double devicePixelRatio) {
  final int pixels = (logical * devicePixelRatio).round();
  if (pixels < 1) {
    return 1;
  }
  if (pixels > 1254) {
    return 1254;
  }
  return pixels;
}
