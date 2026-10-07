import 'package:flutter/material.dart';

class HomeEventsEmpty extends StatelessWidget {
  const HomeEventsEmpty({
    required this.title,
    required this.body,
    required this.createLabel,
    required this.exploreLabel,
    required this.onCreate,
    required this.onExplore,
    super.key,
  });

  final String title;
  final String body;
  final String createLabel;
  final String exploreLabel;
  final VoidCallback onCreate;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xff161D2B) : scheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0x14FFFFFF) : scheme.outlineVariant,
          ),
        ),
        child: Column(
          children: <Widget>[
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xffFF9800).withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sports_esports_rounded,
                color: Color(0xffFF9800),
                size: 26,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: onCreate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffFF9800),
                  foregroundColor: const Color(0xff111827),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  createLabel,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                onPressed: onExplore,
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.onSurface,
                  side: BorderSide(
                    color: isDark
                        ? const Color(0x33FFFFFF)
                        : scheme.outlineVariant,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  exploreLabel,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
