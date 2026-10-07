import 'package:flutter/material.dart';

import 'game_visuals.dart';

/// Market rozet kartındaki daire görsel. imageUrl yoksa Market ile aynı emoji.
class GameBadgeEmblem extends StatelessWidget {
  const GameBadgeEmblem({
    required this.emoji,
    required this.imageUrl,
    required this.gameName,
    this.size = 64,
    super.key,
  });

  final String emoji;
  final String imageUrl;
  final String gameName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final double scale = size / 64;
    final double inner = 54 * scale;
    final double pad = 10 * scale;
    final double fontSize = 28 * scale;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: <Color>[Color(0xff2B2B2B), Color(0xff141414)],
        ),
        border: Border.all(width: 2, color: const Color(0xffC98A2E)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            blurRadius: 12 * scale,
            offset: Offset(0, 5 * scale),
            color: const Color(0xffC98A2E).withValues(alpha: 0.16),
          ),
        ],
      ),
      child: Container(
        width: inner,
        height: inner,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xffE1B86C).withValues(alpha: 0.55),
          ),
        ),
        child: imageUrl.isNotEmpty
            ? ClipOval(
                child: Padding(
                  padding: EdgeInsets.all(pad),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Text(
                      emoji.isEmpty ? GameVisuals.emoji(gameName) : emoji,
                      style: TextStyle(fontSize: fontSize),
                    ),
                  ),
                ),
              )
            : Text(
                emoji.isEmpty ? GameVisuals.emoji(gameName) : emoji,
                style: TextStyle(fontSize: fontSize),
              ),
      ),
    );
  }
}
