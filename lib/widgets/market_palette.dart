import 'package:flutter/material.dart';

/// Market yüzeyleri. Koyu temada antrasit mağaza, açık temada sıcak kâğıt.
/// Turuncu yalnızca fiyat, seçili filtre ve ana eylemde kullanılır.
class MarketPalette {
  const MarketPalette({
    required this.dark,
    required this.background,
    required this.surface,
    required this.raised,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.line,
    required this.owned,
  });

  final bool dark;
  final Color background;
  final Color surface;
  final Color raised;
  final Color ink;
  final Color muted;
  final Color accent;
  final Color onAccent;
  final Color line;
  final Color owned;

  static MarketPalette of(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return const MarketPalette(
        dark: true,
        background: Color(0xff121418),
        surface: Color(0xff1C2028),
        raised: Color(0xff262B34),
        ink: Color(0xffF4F1EA),
        muted: Color(0xffB7BDC8),
        accent: Color(0xffFF9800),
        onAccent: Color(0xff1B1408),
        line: Color(0xff343A46),
        owned: Color(0xff3DDC84),
      );
    }
    return const MarketPalette(
      dark: false,
      background: Color(0xffF3F1EC),
      surface: Color(0xffFFFcf8),
      raised: Color(0xffE7E3DA),
      ink: Color(0xff1B1E24),
      muted: Color(0xff5C6370),
      accent: Color(0xffE07A00),
      onAccent: Color(0xff1B1408),
      line: Color(0xffE0DBD1),
      owned: Color(0xff157A3A),
    );
  }
}
