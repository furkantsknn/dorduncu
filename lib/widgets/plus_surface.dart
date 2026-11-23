import 'package:flutter/material.dart';

class PlusSurface extends StatelessWidget {
  const PlusSurface({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  static const Color background = Color(0xff15171C);
  static const Color ink = Color(0xffF4F1EA);
  static const Color muted = Color(0xffB4B8C2);
  static const Color accent = Color(0xffFF9800);
  static const double radius = 18;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: ink),
        child: IconTheme.merge(
          data: const IconThemeData(color: accent),
          child: child,
        ),
      ),
    );
  }
}

ButtonStyle plusPrimaryButtonStyle() => FilledButton.styleFrom(
  backgroundColor: PlusSurface.accent,
  foregroundColor: const Color(0xff15120D),
  disabledBackgroundColor: const Color(0xff34373E),
  disabledForegroundColor: const Color(0xffC4C7CE),
  minimumSize: const Size.fromHeight(48),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontWeight: FontWeight.w800),
);
