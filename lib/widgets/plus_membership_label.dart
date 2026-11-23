import 'package:flutter/material.dart';

import 'plus_emblem.dart';

/// İsim yanında duran kompakt Plus etiketi.
///
/// Doğrulama tikinden ve oyun rozetinden ayrıdır. Yükseklik yazı ölçeğiyle
/// büyür; sabit bir kutuya kırpılmaz.
class PlusMembershipLabel extends StatelessWidget {
  const PlusMembershipLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Plus',
      child: Container(
        padding: const EdgeInsets.fromLTRB(7, 4, 8, 4),
        decoration: BoxDecoration(
          color: const Color(0xff1B1408),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: const Color(0x99FF9800)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PlusMark(size: 15),
            SizedBox(width: 5),
            Text(
              'PLUS',
              style: TextStyle(
                color: Color(0xffFF9800),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileNameRow extends StatelessWidget {
  const ProfileNameRow({
    required this.name,
    required this.plusActive,
    this.style,
    super.key,
  });

  final String name;
  final bool plusActive;
  final TextStyle? style;

  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final TextStyle nameStyle = DefaultTextStyle.of(context).style.merge(
      style ??
          Theme.of(context).textTheme.headlineSmall ??
          const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
    );
    final Widget nameText = Text(
      name,
      textAlign: TextAlign.center,
      style: nameStyle,
    );
    if (!plusActive) {
      return nameText;
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth;
        final bool besideName =
            maxWidth.isFinite &&
            _nameWidth(context, name, nameStyle) +
                    _gap +
                    _labelWidth(context) <=
                maxWidth;
        if (!besideName) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              nameText,
              const SizedBox(height: 6),
              const PlusMembershipLabel(),
            ],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            nameText,
            const SizedBox(width: _gap),
            const PlusMembershipLabel(),
          ],
        );
      },
    );
  }
}

double _nameWidth(BuildContext context, String name, TextStyle style) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: name, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final double width = painter.width;
  painter.dispose();
  return width;
}

double _labelWidth(BuildContext context) {
  final TextScaler scaler = MediaQuery.textScalerOf(context);
  final TextPainter painter = TextPainter(
    text: const TextSpan(
      text: 'PLUS',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        height: 1.1,
      ),
    ),
    textDirection: Directionality.of(context),
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  final double width = painter.width;
  painter.dispose();
  return width + 15 + 5 + 7 + 8 + 2;
}
