import 'package:flutter/material.dart';

import '../utils/game_catalog.dart';
import 'game_badge_symbols.dart';

/// Exact game id → rozet çizimi. İsim yalnızca kimlik boşsa çözülür.
String resolveBadgeGameId({required String gameId, required String gameName}) {
  final String direct = GameCatalog.normalizeId(gameId);
  if (badgeArtSpec(direct) != null) {
    return direct;
  }

  final String fromId = _catalogArtId(gameId);
  if (fromId.isNotEmpty) {
    return fromId;
  }
  if (direct.isNotEmpty) {
    return direct;
  }
  return _catalogArtId(gameName);
}

String _catalogArtId(String value) {
  final String raw = value.trim();
  if (raw.isEmpty) {
    return '';
  }
  final game = GameCatalog.gameById(raw);
  if (game != null && badgeArtSpec(game.id) != null) {
    return game.id;
  }
  final String normalized = GameCatalog.normalizeId(raw);
  if (badgeArtSpec(normalized) != null) {
    return normalized;
  }
  return '';
}

bool hasGameBadgeArt(String gameId) => badgeArtSpec(gameId) != null;

class GameBadgeArt extends StatelessWidget {
  const GameBadgeArt({
    required this.gameId,
    required this.size,
    this.label = '',
    super.key,
  });

  final String gameId;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    final BadgeArtSpec? spec = badgeArtSpec(gameId);
    final Widget mark = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _EnamelBadgePainter(enamel: spec?.enamel, draw: spec?.draw),
      ),
    );
    if (label.trim().isEmpty) {
      return mark;
    }
    return Semantics(image: true, label: label, child: mark);
  }
}

class _EnamelBadgePainter extends CustomPainter {
  const _EnamelBadgePainter({required this.enamel, required this.draw});

  final Color? enamel;
  final void Function(Canvas canvas, double s)? draw;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    final Offset center = Offset(s / 2, s / 2);
    final double radius = s * 0.46;
    final Color fill = enamel ?? const Color(0xff2A303A);

    canvas.drawCircle(
      center + Offset(0, s * 0.012),
      radius,
      Paint()..color = const Color(0x33000000),
    );
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xff8E97A6));
    canvas.drawCircle(center, radius * 0.88, Paint()..color = fill);
    canvas.drawCircle(
      center,
      radius * 0.88,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.012
        ..color = const Color(0x55FFFFFF),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.62),
      -2.6,
      1.05,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * 0.028
        ..color = const Color(0x46FFFFFF),
    );

    final void Function(Canvas canvas, double s)? symbol = draw;
    if (symbol == null) {
      return;
    }
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius * 0.82)),
    );
    symbol(canvas, s);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EnamelBadgePainter oldDelegate) {
    return oldDelegate.enamel != enamel || oldDelegate.draw != draw;
  }
}
