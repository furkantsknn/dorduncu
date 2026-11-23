import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bir oyun rozetinin emaye rengi ve özgün simgesi.
class BadgeArtSpec {
  const BadgeArtSpec({required this.enamel, required this.draw});

  final Color enamel;
  final void Function(Canvas canvas, double s) draw;
}

BadgeArtSpec? badgeArtSpec(String gameId) => _specs[gameId];

/// V1 kataloğu, ardından satın alma geçmişinde kalan eski kimlikler.
const List<String> badgeArtGameIds = <String>[
  'okey',
  'okey_101',
  'batak',
  'tavla',
  'satranc',
  'bric',
  'king',
  'monopoly',
  'uno',
  'jenga',
  'scrabble',
  'tombala',
  'ea_fc',
  'efootball',
  'tekken',
  'tenis',
  'masa_tenisi',
  'badminton',
  'squash',
  'pickleball',
  'futbol',
  'basketbol',
  'voleybol',
  'hentbol',
  'golf',
  'yelken',
  'kurek',
  'binicilik',
  'kayak',
  'snowboard',
  'paintball',
  'bilardo',
  'bowling',
  'dart',
  'langirt',
  'playstation',
  'kosu',
  'bisiklet',
  'yuzme',
];

const Map<String, String> badgeArtLabels = <String, String>{
  'okey': 'Okey',
  'okey_101': '101',
  'batak': 'Batak',
  'tavla': 'Tavla',
  'satranc': 'Satranç',
  'bric': 'Briç',
  'king': 'King',
  'monopoly': 'Monopoly',
  'uno': 'Uno',
  'jenga': 'Jenga',
  'scrabble': 'Scrabble',
  'tombala': 'Tombala',
  'ea_fc': 'EA FC',
  'efootball': 'eFootball',
  'tekken': 'Tekken',
  'tenis': 'Tenis',
  'masa_tenisi': 'Masa Tenisi',
  'badminton': 'Badminton',
  'squash': 'Squash',
  'pickleball': 'Pickleball',
  'futbol': 'Futbol',
  'basketbol': 'Basketbol',
  'voleybol': 'Voleybol',
  'hentbol': 'Hentbol',
  'golf': 'Golf',
  'yelken': 'Yelken',
  'kurek': 'Kürek',
  'binicilik': 'Binicilik',
  'kayak': 'Kayak',
  'snowboard': 'Snowboard',
  'paintball': 'Paintball',
  'bilardo': 'Bilardo',
  'bowling': 'Bowling',
  'dart': 'Dart',
  'langirt': 'Langırt',
  'playstation': 'PlayStation',
  'kosu': 'Koşu',
  'bisiklet': 'Bisiklet',
  'yuzme': 'Yüzme',
};

final Map<String, BadgeArtSpec> _specs = <String, BadgeArtSpec>{
  'okey': BadgeArtSpec(enamel: const Color(0xff3E4C38), draw: _okey),
  'okey_101': BadgeArtSpec(enamel: const Color(0xff1E3A5F), draw: _okey101),
  'batak': BadgeArtSpec(enamel: const Color(0xff1B2433), draw: _batak),
  'tavla': BadgeArtSpec(enamel: const Color(0xff6B2D2D), draw: _tavla),
  'satranc': BadgeArtSpec(enamel: const Color(0xffE7E1D6), draw: _satranc),
  'bric': BadgeArtSpec(enamel: const Color(0xff1C3D34), draw: _bric),
  'king': BadgeArtSpec(enamel: const Color(0xff243056), draw: _king),
  'monopoly': BadgeArtSpec(enamel: const Color(0xff1B5C40), draw: _monopoly),
  'uno': BadgeArtSpec(enamel: const Color(0xff1A1C22), draw: _uno),
  'jenga': BadgeArtSpec(enamel: const Color(0xff4A3424), draw: _jenga),
  'scrabble': BadgeArtSpec(enamel: const Color(0xff214438), draw: _scrabble),
  'tombala': BadgeArtSpec(enamel: const Color(0xff7A1E2C), draw: _tombala),
  'ea_fc': BadgeArtSpec(enamel: const Color(0xff142033), draw: _eaFc),
  'efootball': BadgeArtSpec(enamel: const Color(0xff0E2A22), draw: _efootball),
  'tekken': BadgeArtSpec(enamel: const Color(0xff3A1218), draw: _tekken),
  'tenis': BadgeArtSpec(enamel: const Color(0xff1B4D3E), draw: _tenis),
  'masa_tenisi': BadgeArtSpec(
    enamel: const Color(0xff163A5C),
    draw: _masaTenisi,
  ),
  'badminton': BadgeArtSpec(enamel: const Color(0xff2C3344), draw: _badminton),
  'squash': BadgeArtSpec(enamel: const Color(0xff3A3228), draw: _squash),
  'pickleball': BadgeArtSpec(
    enamel: const Color(0xff1A4638),
    draw: _pickleball,
  ),
  'futbol': BadgeArtSpec(enamel: const Color(0xff17351C), draw: _futbol),
  'basketbol': BadgeArtSpec(enamel: const Color(0xff3A2616), draw: _basketbol),
  'voleybol': BadgeArtSpec(enamel: const Color(0xff243044), draw: _voleybol),
  'hentbol': BadgeArtSpec(enamel: const Color(0xff3A2844), draw: _hentbol),
  'golf': BadgeArtSpec(enamel: const Color(0xff1A4A30), draw: _golf),
  'yelken': BadgeArtSpec(enamel: const Color(0xff16344A), draw: _yelken),
  'kurek': BadgeArtSpec(enamel: const Color(0xff163440), draw: _kurek),
  'binicilik': BadgeArtSpec(enamel: const Color(0xff3A2C22), draw: _binicilik),
  'kayak': BadgeArtSpec(enamel: const Color(0xff24384C), draw: _kayak),
  'snowboard': BadgeArtSpec(enamel: const Color(0xff1E3040), draw: _snowboard),
  'paintball': BadgeArtSpec(enamel: const Color(0xff24242A), draw: _paintball),
  'bilardo': BadgeArtSpec(enamel: const Color(0xff143528), draw: _bilardo),
  'bowling': BadgeArtSpec(enamel: const Color(0xff3A241C), draw: _bowling),
  'dart': BadgeArtSpec(enamel: const Color(0xff2A241C), draw: _dart),
  'langirt': BadgeArtSpec(enamel: const Color(0xff1E3A28), draw: _langirt),
  'playstation': BadgeArtSpec(enamel: const Color(0xff242833), draw: _gamepad),
  'kosu': BadgeArtSpec(enamel: const Color(0xff2E3340), draw: _kosu),
  'bisiklet': BadgeArtSpec(enamel: const Color(0xff1C3040), draw: _bisiklet),
  'yuzme': BadgeArtSpec(enamel: const Color(0xff163A55), draw: _yuzme),
};

const Color _ivory = Color(0xffF6E7C4);
const Color _ink = Color(0xff1B1E24);
const Color _red = Color(0xffD23B3B);
const Color _blue = Color(0xff2A62C2);
const Color _green = Color(0xff1E8A4A);
const Color _cream = Color(0xffF4F0E6);

void _rr(
  Canvas canvas,
  double s,
  double x,
  double y,
  double w,
  double h,
  double radius,
  Color color,
) {
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(s * x, s * y, s * w, s * h),
      Radius.circular(s * radius),
    ),
    Paint()..color = color,
  );
}

void _dot(Canvas canvas, double s, double x, double y, double r, Color color) {
  canvas.drawCircle(Offset(s * x, s * y), s * r, Paint()..color = color);
}

void _line(
  Canvas canvas,
  double s,
  double x1,
  double y1,
  double x2,
  double y2,
  Color color,
  double width,
) {
  canvas.drawLine(
    Offset(s * x1, s * y1),
    Offset(s * x2, s * y2),
    Paint()
      ..color = color
      ..strokeWidth = s * width
      ..strokeCap = StrokeCap.round,
  );
}

void _okey(Canvas canvas, double s) {
  _rr(canvas, s, 0.30, 0.24, 0.40, 0.50, 0.05, const Color(0xff8A7352));
  _rr(canvas, s, 0.24, 0.20, 0.40, 0.50, 0.05, _ivory);
  const List<Color> pips = <Color>[_red, _blue, _ink, _green];
  for (var i = 0; i < pips.length; i++) {
    _dot(
      canvas,
      s,
      0.34 + (i % 2) * 0.18,
      0.34 + (i ~/ 2) * 0.22,
      0.045,
      pips[i],
    );
  }
}

void _okey101(Canvas canvas, double s) {
  _rr(canvas, s, 0.30, 0.20, 0.40, 0.60, 0.05, const Color(0xff6E5A40));
  _rr(canvas, s, 0.28, 0.18, 0.40, 0.60, 0.05, _ivory);
  _dot(canvas, s, 0.36, 0.26, 0.028, _red);
  _digit1(canvas, s, 0.36, 0.36, 0.22);
  _digit0(canvas, s, 0.44, 0.36, 0.22);
  _digit1(canvas, s, 0.58, 0.36, 0.22);
}

void _digit1(Canvas canvas, double s, double x, double y, double h) {
  _rr(canvas, s, x, y, 0.045, h, 0.02, _ink);
}

void _digit0(Canvas canvas, double s, double x, double y, double h) {
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(s * x, s * y, s * 0.12, s * h),
      Radius.circular(s * 0.05),
    ),
    Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.035,
  );
}

void _batak(Canvas canvas, double s) {
  _rr(canvas, s, 0.34, 0.20, 0.34, 0.58, 0.04, const Color(0xffC5CDD8));
  _rr(canvas, s, 0.30, 0.18, 0.34, 0.58, 0.04, _cream);
  _spade(canvas, s, 0.47, 0.40, 0.11, _ink);
}

void _spade(
  Canvas canvas,
  double s,
  double x,
  double y,
  double r,
  Color color,
) {
  final Path path = Path()
    ..moveTo(s * x, s * (y - r))
    ..cubicTo(
      s * (x - r * 1.3),
      s * y,
      s * (x - r),
      s * (y + r),
      s * x,
      s * (y + r * 0.35),
    )
    ..cubicTo(
      s * (x + r),
      s * (y + r),
      s * (x + r * 1.3),
      s * y,
      s * x,
      s * (y - r),
    )
    ..close();
  canvas.drawPath(path, Paint()..color = color);
  _rr(canvas, s, x - 0.02, y + r * 0.15, 0.04, r * 0.7, 0.01, color);
}

void _tavla(Canvas canvas, double s) {
  _rr(canvas, s, 0.22, 0.28, 0.56, 0.44, 0.04, const Color(0xffF3E6C8));
  for (var i = 0; i < 4; i++) {
    final double x = 0.28 + i * 0.12;
    final Path tooth = Path()
      ..moveTo(s * x, s * 0.30)
      ..lineTo(s * (x + 0.09), s * 0.30)
      ..lineTo(s * (x + 0.045), s * 0.48)
      ..close();
    canvas.drawPath(
      tooth,
      Paint()
        ..color = i.isEven ? const Color(0xff8C2F2F) : const Color(0xff1B1E24),
    );
  }
  _dot(canvas, s, 0.34, 0.58, 0.035, _cream);
  _dot(canvas, s, 0.42, 0.58, 0.035, _cream);
  _dot(canvas, s, 0.62, 0.62, 0.035, _ink);
  _dot(canvas, s, 0.70, 0.62, 0.035, _ink);
}

void _satranc(Canvas canvas, double s) {
  final Path knight = Path()
    ..moveTo(s * 0.38, s * 0.74)
    ..lineTo(s * 0.66, s * 0.74)
    ..lineTo(s * 0.66, s * 0.66)
    ..lineTo(s * 0.56, s * 0.64)
    ..lineTo(s * 0.62, s * 0.50)
    ..lineTo(s * 0.72, s * 0.44)
    ..lineTo(s * 0.66, s * 0.34)
    ..lineTo(s * 0.54, s * 0.30)
    ..lineTo(s * 0.50, s * 0.38)
    ..lineTo(s * 0.42, s * 0.34)
    ..lineTo(s * 0.36, s * 0.46)
    ..lineTo(s * 0.34, s * 0.62)
    ..close();
  canvas.drawPath(knight, Paint()..color = _ink);
  _dot(canvas, s, 0.58, 0.40, 0.018, _cream);
}

void _bric(Canvas canvas, double s) {
  canvas.save();
  canvas.translate(s * 0.42, s * 0.48);
  canvas.rotate(-0.35);
  _rr(canvas, s, -0.16, -0.26, 0.30, 0.48, 0.04, _cream);
  canvas.restore();
  _heart(canvas, s, 0.36, 0.46, 0.06);
  canvas.save();
  canvas.translate(s * 0.58, s * 0.50);
  canvas.rotate(0.28);
  _rr(canvas, s, -0.14, -0.26, 0.30, 0.48, 0.04, _cream);
  canvas.restore();
  _club(canvas, s, 0.60, 0.50, 0.045);
}

void _heart(Canvas canvas, double s, double x, double y, double r) {
  final Path path = Path()
    ..moveTo(s * x, s * (y + r))
    ..cubicTo(
      s * (x - r * 1.6),
      s * (y - r * 0.2),
      s * (x - r * 0.7),
      s * (y - r * 1.3),
      s * x,
      s * (y - r * 0.35),
    )
    ..cubicTo(
      s * (x + r * 0.7),
      s * (y - r * 1.3),
      s * (x + r * 1.6),
      s * (y - r * 0.2),
      s * x,
      s * (y + r),
    )
    ..close();
  canvas.drawPath(path, Paint()..color = _red);
}

void _club(Canvas canvas, double s, double x, double y, double r) {
  _dot(canvas, s, x - r * 0.7, y, r, _ink);
  _dot(canvas, s, x + r * 0.7, y, r, _ink);
  _dot(canvas, s, x, y - r * 0.9, r, _ink);
  _rr(canvas, s, x - 0.012, y, 0.024, r, 0.01, _ink);
}

void _king(Canvas canvas, double s) {
  final Path crown = Path()
    ..moveTo(s * 0.26, s * 0.62)
    ..lineTo(s * 0.30, s * 0.38)
    ..lineTo(s * 0.40, s * 0.52)
    ..lineTo(s * 0.50, s * 0.30)
    ..lineTo(s * 0.60, s * 0.52)
    ..lineTo(s * 0.70, s * 0.38)
    ..lineTo(s * 0.74, s * 0.62)
    ..close();
  canvas.drawPath(crown, Paint()..color = const Color(0xffF2C14E));
  _rr(canvas, s, 0.26, 0.60, 0.48, 0.08, 0.02, const Color(0xffF2C14E));
  _dot(canvas, s, 0.50, 0.40, 0.03, _red);
  _dot(canvas, s, 0.36, 0.50, 0.022, _blue);
  _dot(canvas, s, 0.64, 0.50, 0.022, _green);
}

void _monopoly(Canvas canvas, double s) {
  _rr(canvas, s, 0.26, 0.46, 0.48, 0.26, 0.03, const Color(0xffD7E8D4));
  final Path roof = Path()
    ..moveTo(s * 0.34, s * 0.50)
    ..lineTo(s * 0.50, s * 0.32)
    ..lineTo(s * 0.66, s * 0.50)
    ..close();
  canvas.drawPath(roof, Paint()..color = _cream);
  _rr(canvas, s, 0.40, 0.50, 0.20, 0.16, 0.015, const Color(0xffF4F0E6));
  _rr(canvas, s, 0.46, 0.56, 0.08, 0.10, 0.01, const Color(0xff1B5C40));
  _rr(canvas, s, 0.58, 0.36, 0.05, 0.12, 0.01, _cream);
}

void _uno(Canvas canvas, double s) {
  void card(double angle, Color color) {
    canvas.save();
    canvas.translate(s * 0.50, s * 0.50);
    canvas.rotate(angle);
    _rr(canvas, s, -0.11, -0.24, 0.22, 0.34, 0.03, color);
    canvas.restore();
  }

  card(-0.7, _red);
  card(-0.22, const Color(0xffF2C14E));
  card(0.22, _green);
  card(0.7, _blue);
}

void _jenga(Canvas canvas, double s) {
  const Color wood = Color(0xffE2B56A);
  const Color edge = Color(0xff8A5A28);
  _rr(canvas, s, 0.30, 0.58, 0.40, 0.08, 0.015, wood);
  _rr(canvas, s, 0.34, 0.48, 0.08, 0.08, 0.01, edge);
  _rr(canvas, s, 0.46, 0.48, 0.08, 0.08, 0.01, wood);
  _rr(canvas, s, 0.58, 0.48, 0.08, 0.08, 0.01, edge);
  _rr(canvas, s, 0.30, 0.38, 0.40, 0.08, 0.015, wood);
  _rr(canvas, s, 0.62, 0.28, 0.14, 0.08, 0.015, const Color(0xffF0D7A0));
}

void _scrabble(Canvas canvas, double s) {
  void tile(double x, double y, void Function() letter) {
    _rr(canvas, s, x, y, 0.18, 0.18, 0.03, _cream);
    letter();
  }

  tile(0.28, 0.30, () => _line(canvas, s, 0.32, 0.44, 0.37, 0.34, _ink, 0.02));
  tile(0.50, 0.30, () {
    canvas.drawCircle(
      Offset(s * 0.59, s * 0.39),
      s * 0.04,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.02,
    );
  });
  tile(0.28, 0.52, () => _rr(canvas, s, 0.34, 0.58, 0.06, 0.06, 0.01, _ink));
  tile(0.50, 0.52, () => _line(canvas, s, 0.54, 0.56, 0.64, 0.66, _ink, 0.02));
}

void _tombala(Canvas canvas, double s) {
  _rr(canvas, s, 0.22, 0.30, 0.56, 0.40, 0.04, _cream);
  for (var row = 0; row < 3; row++) {
    for (var col = 0; col < 5; col++) {
      final bool marked = (row + col) % 3 == 0;
      _dot(
        canvas,
        s,
        0.30 + col * 0.10,
        0.38 + row * 0.12,
        0.028,
        marked ? _red : const Color(0xffC8C2B6),
      );
    }
  }
}

void _eaFc(Canvas canvas, double s) {
  _rr(canvas, s, 0.24, 0.26, 0.52, 0.36, 0.04, const Color(0xff0B1220));
  _rr(canvas, s, 0.28, 0.30, 0.44, 0.28, 0.03, const Color(0xff16351C));
  _ball(canvas, s, 0.50, 0.44, 0.08);
  _rr(canvas, s, 0.42, 0.62, 0.16, 0.04, 0.01, const Color(0xff9AA3B2));
}

void _efootball(Canvas canvas, double s) {
  _rr(canvas, s, 0.22, 0.30, 0.56, 0.40, 0.03, const Color(0xff1E6B3A));
  _line(canvas, s, 0.50, 0.32, 0.50, 0.68, _cream, 0.015);
  canvas.drawCircle(
    Offset(s * 0.50, s * 0.50),
    s * 0.08,
    Paint()
      ..color = _cream
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.015,
  );
  _dot(canvas, s, 0.66, 0.42, 0.035, _cream);
  _rr(canvas, s, 0.30, 0.58, 0.12, 0.07, 0.02, const Color(0xff1B1E24));
}

void _tekken(Canvas canvas, double s) {
  _fist(canvas, s, 0.34, 0.50, false);
  _fist(canvas, s, 0.66, 0.50, true);
  _dot(canvas, s, 0.50, 0.48, 0.02, const Color(0xffF2C14E));
}

void _fist(Canvas canvas, double s, double x, double y, bool flip) {
  canvas.save();
  canvas.translate(s * x, s * y);
  if (flip) {
    canvas.scale(-1, 1);
  }
  _rr(canvas, s, -0.12, -0.10, 0.22, 0.18, 0.06, const Color(0xffF0C9A0));
  _rr(canvas, s, -0.10, -0.16, 0.05, 0.08, 0.02, const Color(0xffF0C9A0));
  _rr(canvas, s, -0.04, -0.18, 0.05, 0.08, 0.02, const Color(0xffF0C9A0));
  _rr(canvas, s, 0.02, -0.16, 0.05, 0.08, 0.02, const Color(0xffF0C9A0));
  canvas.restore();
}

void _tenis(Canvas canvas, double s) {
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(s * 0.46, s * 0.42),
      width: s * 0.28,
      height: s * 0.36,
    ),
    Paint()..color = const Color(0xffF4F0E6),
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(s * 0.46, s * 0.42),
      width: s * 0.28,
      height: s * 0.36,
    ),
    Paint()
      ..color = const Color(0xff1B4D3E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.02,
  );
  _line(canvas, s, 0.46, 0.28, 0.46, 0.56, const Color(0xff1B4D3E), 0.012);
  _line(canvas, s, 0.34, 0.42, 0.58, 0.42, const Color(0xff1B4D3E), 0.012);
  _rr(canvas, s, 0.43, 0.58, 0.06, 0.16, 0.02, const Color(0xffC9843A));
  _dot(canvas, s, 0.68, 0.36, 0.045, const Color(0xffD6F25A));
}

void _masaTenisi(Canvas canvas, double s) {
  _dot(canvas, s, 0.46, 0.46, 0.16, _red);
  _rr(canvas, s, 0.42, 0.58, 0.08, 0.14, 0.02, const Color(0xff1B1E24));
  _dot(canvas, s, 0.70, 0.36, 0.045, _cream);
  _line(canvas, s, 0.24, 0.70, 0.76, 0.70, _cream, 0.012);
}

void _badminton(Canvas canvas, double s) {
  _dot(canvas, s, 0.50, 0.66, 0.07, const Color(0xffE8D2A8));
  final Path cone = Path()
    ..moveTo(s * 0.50, s * 0.58)
    ..lineTo(s * 0.32, s * 0.28)
    ..lineTo(s * 0.68, s * 0.28)
    ..close();
  canvas.drawPath(cone, Paint()..color = _cream);
  for (var i = 0; i < 4; i++) {
    _line(
      canvas,
      s,
      0.38 + i * 0.08,
      0.30,
      0.50,
      0.56,
      const Color(0xffC8C2B6),
      0.012,
    );
  }
}

void _squash(Canvas canvas, double s) {
  _rr(canvas, s, 0.24, 0.26, 0.52, 0.48, 0.04, const Color(0xffE7D7B8));
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.24, s * 0.26, s * 0.52, s * 0.48),
      Radius.circular(s * 0.04),
    ),
    Paint()
      ..color = const Color(0xff3A3228)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.02,
  );
  _line(canvas, s, 0.24, 0.42, 0.76, 0.42, const Color(0xff3A3228), 0.012);
  _dot(canvas, s, 0.58, 0.52, 0.04, const Color(0xff1B1E24));
}

void _pickleball(Canvas canvas, double s) {
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(s * 0.46, s * 0.46),
      width: s * 0.26,
      height: s * 0.34,
    ),
    Paint()..color = const Color(0xff7DDA4A),
  );
  _dot(canvas, s, 0.42, 0.40, 0.018, const Color(0xff1A4638));
  _dot(canvas, s, 0.50, 0.40, 0.018, const Color(0xff1A4638));
  _dot(canvas, s, 0.42, 0.50, 0.018, const Color(0xff1A4638));
  _dot(canvas, s, 0.50, 0.50, 0.018, const Color(0xff1A4638));
  _rr(canvas, s, 0.42, 0.60, 0.08, 0.12, 0.02, const Color(0xff245C40));
  _dot(canvas, s, 0.70, 0.38, 0.05, const Color(0xffD7F5A8));
}

void _ball(Canvas canvas, double s, double x, double y, double r) {
  _dot(canvas, s, x, y, r, _cream);
  final Path pentagon = Path();
  for (var i = 0; i < 5; i++) {
    final double angle = -math.pi / 2 + i * math.pi * 2 / 5;
    final Offset point = Offset(
      s * x + math.cos(angle) * s * r * 0.45,
      s * y + math.sin(angle) * s * r * 0.45,
    );
    if (i == 0) {
      pentagon.moveTo(point.dx, point.dy);
    } else {
      pentagon.lineTo(point.dx, point.dy);
    }
  }
  pentagon.close();
  canvas.drawPath(pentagon, Paint()..color = _ink);
}

void _futbol(Canvas canvas, double s) => _ball(canvas, s, 0.50, 0.50, 0.18);

void _basketbol(Canvas canvas, double s) {
  _dot(canvas, s, 0.50, 0.50, 0.18, const Color(0xffE07020));
  canvas.drawCircle(
    Offset(s * 0.50, s * 0.50),
    s * 0.18,
    Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.015,
  );
  _line(canvas, s, 0.50, 0.32, 0.50, 0.68, _ink, 0.015);
  canvas.drawArc(
    Rect.fromCenter(
      center: Offset(s * 0.50, s * 0.50),
      width: s * 0.20,
      height: s * 0.32,
    ),
    -1.2,
    2.4,
    false,
    Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.015,
  );
}

void _voleybol(Canvas canvas, double s) {
  _dot(canvas, s, 0.50, 0.50, 0.18, _cream);
  canvas.drawArc(
    Rect.fromCircle(center: Offset(s * 0.42, s * 0.50), radius: s * 0.16),
    -1.2,
    2.2,
    false,
    Paint()
      ..color = const Color(0xff2A62C2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.03,
  );
  canvas.drawArc(
    Rect.fromCircle(center: Offset(s * 0.58, s * 0.46), radius: s * 0.14),
    1.4,
    2.0,
    false,
    Paint()
      ..color = const Color(0xffF2C14E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.03,
  );
}

void _hentbol(Canvas canvas, double s) {
  _dot(canvas, s, 0.56, 0.50, 0.14, const Color(0xffF4F0E6));
  final Path hand = Path()
    ..moveTo(s * 0.30, s * 0.58)
    ..quadraticBezierTo(s * 0.28, s * 0.40, s * 0.42, s * 0.36)
    ..lineTo(s * 0.44, s * 0.28)
    ..lineTo(s * 0.50, s * 0.36)
    ..lineTo(s * 0.52, s * 0.26)
    ..lineTo(s * 0.58, s * 0.38)
    ..quadraticBezierTo(s * 0.48, s * 0.62, s * 0.34, s * 0.64)
    ..close();
  canvas.drawPath(hand, Paint()..color = const Color(0xffF0C9A0));
}

void _golf(Canvas canvas, double s) {
  _line(canvas, s, 0.42, 0.28, 0.42, 0.68, _cream, 0.02);
  final Path flag = Path()
    ..moveTo(s * 0.42, s * 0.28)
    ..lineTo(s * 0.66, s * 0.36)
    ..lineTo(s * 0.42, s * 0.44)
    ..close();
  canvas.drawPath(flag, Paint()..color = _red);
  _dot(canvas, s, 0.64, 0.64, 0.045, _cream);
}

void _yelken(Canvas canvas, double s) {
  _rr(canvas, s, 0.28, 0.62, 0.44, 0.08, 0.04, _cream);
  _line(canvas, s, 0.48, 0.28, 0.48, 0.64, _cream, 0.015);
  final Path sail = Path()
    ..moveTo(s * 0.48, s * 0.30)
    ..lineTo(s * 0.48, s * 0.58)
    ..lineTo(s * 0.68, s * 0.58)
    ..close();
  canvas.drawPath(sail, Paint()..color = const Color(0xffF4F0E6));
  final Path jib = Path()
    ..moveTo(s * 0.48, s * 0.34)
    ..lineTo(s * 0.48, s * 0.56)
    ..lineTo(s * 0.32, s * 0.56)
    ..close();
  canvas.drawPath(jib, Paint()..color = const Color(0xffD5DEE8));
}

void _kurek(Canvas canvas, double s) {
  _rr(canvas, s, 0.30, 0.46, 0.40, 0.10, 0.05, _cream);
  _line(canvas, s, 0.22, 0.36, 0.42, 0.50, const Color(0xffD7A15A), 0.02);
  _line(canvas, s, 0.78, 0.36, 0.58, 0.50, const Color(0xffD7A15A), 0.02);
  _rr(canvas, s, 0.18, 0.32, 0.08, 0.05, 0.01, const Color(0xffE7D3A4));
  _rr(canvas, s, 0.74, 0.32, 0.08, 0.05, 0.01, const Color(0xffE7D3A4));
}

void _binicilik(Canvas canvas, double s) {
  final Path head = Path()
    ..moveTo(s * 0.34, s * 0.58)
    ..quadraticBezierTo(s * 0.30, s * 0.40, s * 0.46, s * 0.34)
    ..quadraticBezierTo(s * 0.40, s * 0.24, s * 0.50, s * 0.28)
    ..quadraticBezierTo(s * 0.62, s * 0.22, s * 0.70, s * 0.40)
    ..quadraticBezierTo(s * 0.78, s * 0.48, s * 0.66, s * 0.52)
    ..quadraticBezierTo(s * 0.74, s * 0.62, s * 0.58, s * 0.66)
    ..quadraticBezierTo(s * 0.44, s * 0.72, s * 0.34, s * 0.58)
    ..close();
  canvas.drawPath(head, Paint()..color = const Color(0xffC9843A));
  _dot(canvas, s, 0.58, 0.42, 0.015, _ink);
  _rr(canvas, s, 0.28, 0.40, 0.06, 0.16, 0.02, const Color(0xff8A5A2B));
}

void _kayak(Canvas canvas, double s) {
  canvas.save();
  canvas.translate(s * 0.50, s * 0.50);
  canvas.rotate(-0.4);
  _rr(canvas, s, -0.16, -0.28, 0.06, 0.56, 0.03, _cream);
  _rr(canvas, s, 0.06, -0.28, 0.06, 0.56, 0.03, const Color(0xffD5DEE8));
  canvas.restore();
  _line(canvas, s, 0.30, 0.30, 0.38, 0.70, const Color(0xffF2C14E), 0.015);
  _line(canvas, s, 0.70, 0.30, 0.62, 0.70, const Color(0xffF2C14E), 0.015);
}

void _snowboard(Canvas canvas, double s) {
  canvas.save();
  canvas.translate(s * 0.50, s * 0.50);
  canvas.rotate(0.5);
  _rr(canvas, s, -0.10, -0.30, 0.20, 0.60, 0.08, const Color(0xffF4F0E6));
  _rr(canvas, s, -0.05, -0.12, 0.10, 0.08, 0.02, const Color(0xff1E3040));
  _rr(canvas, s, -0.05, 0.06, 0.10, 0.08, 0.02, const Color(0xff1E3040));
  canvas.restore();
}

void _paintball(Canvas canvas, double s) {
  _dot(canvas, s, 0.50, 0.50, 0.22, const Color(0xffF4F0E6));
  _dot(canvas, s, 0.50, 0.50, 0.16, const Color(0xffFF7A1A));
  _dot(canvas, s, 0.50, 0.50, 0.10, const Color(0xff20B8D8));
  _dot(canvas, s, 0.50, 0.50, 0.04, const Color(0xffE91E78));
  _dot(canvas, s, 0.30, 0.33, 0.045, const Color(0xff20B8D8));
  _dot(canvas, s, 0.72, 0.38, 0.055, const Color(0xffE91E78));
  _dot(canvas, s, 0.32, 0.70, 0.035, const Color(0xffFF7A1A));
}

void _bilardo(Canvas canvas, double s) {
  _rr(canvas, s, 0.20, 0.32, 0.60, 0.36, 0.04, const Color(0xff1E8A4A));
  _dot(canvas, s, 0.26, 0.38, 0.03, _ink);
  _dot(canvas, s, 0.74, 0.38, 0.03, _ink);
  _dot(canvas, s, 0.26, 0.62, 0.03, _ink);
  _dot(canvas, s, 0.74, 0.62, 0.03, _ink);
  _dot(canvas, s, 0.42, 0.50, 0.045, _cream);
  _dot(canvas, s, 0.56, 0.50, 0.045, _ink);
  _dot(canvas, s, 0.56, 0.50, 0.015, _cream);
}

void _bowling(Canvas canvas, double s) {
  _rr(canvas, s, 0.46, 0.26, 0.10, 0.28, 0.05, _cream);
  _dot(canvas, s, 0.51, 0.32, 0.035, _cream);
  _rr(canvas, s, 0.36, 0.34, 0.08, 0.20, 0.04, const Color(0xffE7E1D6));
  _rr(canvas, s, 0.58, 0.36, 0.08, 0.18, 0.04, const Color(0xffE7E1D6));
  _dot(canvas, s, 0.36, 0.64, 0.08, const Color(0xff2A62C2));
}

void _dart(Canvas canvas, double s) {
  _dot(canvas, s, 0.48, 0.50, 0.18, _red);
  _dot(canvas, s, 0.48, 0.50, 0.12, _cream);
  _dot(canvas, s, 0.48, 0.50, 0.07, _ink);
  _dot(canvas, s, 0.48, 0.50, 0.03, _red);
  _line(canvas, s, 0.62, 0.36, 0.78, 0.24, const Color(0xffC9843A), 0.02);
  _rr(canvas, s, 0.74, 0.20, 0.08, 0.04, 0.01, const Color(0xffF4F0E6));
}

void _langirt(Canvas canvas, double s) {
  _line(canvas, s, 0.18, 0.50, 0.82, 0.50, const Color(0xffC8C2B6), 0.02);
  for (final double x in <double>[0.34, 0.50, 0.66]) {
    _dot(canvas, s, x, 0.42, 0.035, const Color(0xffF0C9A0));
    _rr(canvas, s, x - 0.03, 0.46, 0.06, 0.10, 0.02, _red);
  }
}

void _gamepad(Canvas canvas, double s) {
  _rr(canvas, s, 0.22, 0.36, 0.56, 0.28, 0.10, const Color(0xff2C3344));
  _line(canvas, s, 0.34, 0.50, 0.46, 0.50, _cream, 0.02);
  _line(canvas, s, 0.40, 0.44, 0.40, 0.56, _cream, 0.02);
  _dot(canvas, s, 0.60, 0.46, 0.028, _red);
  _dot(canvas, s, 0.68, 0.54, 0.028, _blue);
}

void _kosu(Canvas canvas, double s) {
  final Path shoe = Path()
    ..moveTo(s * 0.24, s * 0.58)
    ..quadraticBezierTo(s * 0.40, s * 0.40, s * 0.70, s * 0.42)
    ..quadraticBezierTo(s * 0.82, s * 0.44, s * 0.78, s * 0.54)
    ..lineTo(s * 0.24, s * 0.62)
    ..close();
  canvas.drawPath(shoe, Paint()..color = const Color(0xffF4F0E6));
  _rr(canvas, s, 0.24, 0.58, 0.56, 0.06, 0.03, const Color(0xffFF9800));
  _line(canvas, s, 0.40, 0.48, 0.48, 0.54, _ink, 0.012);
  _line(canvas, s, 0.50, 0.46, 0.58, 0.54, _ink, 0.012);
}

void _bisiklet(Canvas canvas, double s) {
  canvas.drawCircle(
    Offset(s * 0.36, s * 0.58),
    s * 0.12,
    Paint()
      ..color = _cream
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.02,
  );
  canvas.drawCircle(
    Offset(s * 0.66, s * 0.58),
    s * 0.12,
    Paint()
      ..color = _cream
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.02,
  );
  _line(canvas, s, 0.36, 0.58, 0.50, 0.40, _cream, 0.018);
  _line(canvas, s, 0.50, 0.40, 0.66, 0.58, _cream, 0.018);
  _line(canvas, s, 0.50, 0.40, 0.62, 0.34, _cream, 0.018);
  _line(canvas, s, 0.36, 0.58, 0.48, 0.64, const Color(0xffFF9800), 0.016);
}

void _yuzme(Canvas canvas, double s) {
  _dot(canvas, s, 0.40, 0.40, 0.06, const Color(0xffF0C9A0));
  _line(canvas, s, 0.46, 0.44, 0.66, 0.36, const Color(0xffF0C9A0), 0.03);
  _line(canvas, s, 0.34, 0.50, 0.58, 0.56, const Color(0xff7EB6E8), 0.025);
  _line(canvas, s, 0.28, 0.62, 0.72, 0.62, _cream, 0.018);
  _line(canvas, s, 0.32, 0.70, 0.70, 0.70, const Color(0xff9CC7EA), 0.015);
}
