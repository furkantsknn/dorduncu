import 'package:flutter/material.dart';

/// Dört. Plus'ın tek, vektör tabanlı işareti.
///
/// Oyun rozetlerinden ve doğrulama tikinden bilinçli olarak ayrıdır.
class PlusMark extends StatelessWidget {
  const PlusMark({
    this.size = 28,
    this.semanticLabel = 'Dört. Plus',
    super.key,
  });

  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            children: <Widget>[
              Positioned(
                left: size * 0.07,
                top: size * 0.20,
                width: size * 0.537,
                height: size * 0.58,
                child: Image.asset(
                  'assets/branding/dort_d_mark_source.png',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              ),
              Positioned(
                left: size * 0.737,
                top: size * 0.65,
                width: size * 0.13,
                height: size * 0.13,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xffFF9800),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlusWordmark extends StatelessWidget {
  const PlusWordmark({
    this.markSize = 28,
    this.textStyle,
    this.compact = false,
    super.key,
  });

  final double markSize;
  final TextStyle? textStyle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final TextStyle resolved =
        Theme.of(context).textTheme.titleLarge?.copyWith(
          color: const Color(0xffF4F1EA),
          fontWeight: FontWeight.w800,
          height: 1.1,
        ) ??
        const TextStyle(
          color: Color(0xffF4F1EA),
          fontSize: 20,
          fontWeight: FontWeight.w800,
        );
    return Semantics(
      label: 'Dört. Plus',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PlusMark(size: markSize),
            SizedBox(width: compact ? 6 : 9),
            Text.rich(
              const TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: 'Dört. '),
                  TextSpan(
                    text: 'Plus',
                    style: TextStyle(color: Color(0xffE9AE62)),
                  ),
                ],
              ),
              style: resolved.merge(textStyle),
            ),
          ],
        ),
      ),
    );
  }
}

/// Eski çağrı noktalarının da aynı tek işareti kullanmasını sağlar.
@Deprecated('Use PlusMark')
class PlusEmblem extends PlusMark {
  const PlusEmblem({super.size, super.key});
}
