import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/market_palette.dart';

String adminText(
  BuildContext context, {
  required String tr,
  required String en,
  required String de,
}) {
  switch (Localizations.localeOf(context).languageCode.toLowerCase()) {
    case 'en':
      return en;
    case 'de':
      return de;
    default:
      return tr;
  }
}

class AdminPageIntro extends StatelessWidget {
  const AdminPageIntro({
    required this.title,
    required this.description,
    this.icon,
    super.key,
  });

  final String title;
  final String description;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final MarketPalette palette = MarketPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(icon, color: palette.accent, size: 22),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminSectionCard extends StatelessWidget {
  const AdminSectionCard({
    required this.title,
    required this.child,
    this.description,
    this.icon,
    this.trailing,
    super.key,
  });

  final String title;
  final String? description;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MarketPalette palette = MarketPalette.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 20, color: palette.accent),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (trailing case final Widget widget) Flexible(child: widget),
              ],
            ),
            if (description != null) ...<Widget>[
              const SizedBox(height: 5),
              Text(
                description!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.muted,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class AdminStatusBadge extends StatelessWidget {
  const AdminStatusBadge({
    required this.label,
    this.tone = AdminStatusTone.neutral,
    this.icon,
    super.key,
  });

  final String label;
  final AdminStatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (tone) {
      AdminStatusTone.success => const Color(0xff258A50),
      AdminStatusTone.warning => const Color(0xffD87800),
      AdminStatusTone.danger => Theme.of(context).colorScheme.error,
      AdminStatusTone.neutral => Theme.of(context).colorScheme.outline,
    };
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .13),
          border: Border.all(color: color.withValues(alpha: .45)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon ?? Icons.circle,
              size: icon == null ? 8 : 14,
              color: color,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum AdminStatusTone { neutral, success, warning, danger }

class AdminCopyableId extends StatelessWidget {
  const AdminCopyableId({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Tooltip(
            message: value,
            child: Text(
              '$label: $value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: adminText(
            context,
            tr: 'Kimliği kopyala',
            en: 'Copy identifier',
            de: 'Kennung kopieren',
          ),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  adminText(
                    context,
                    tr: 'Kimlik kopyalandı.',
                    en: 'Identifier copied.',
                    de: 'Kennung kopiert.',
                  ),
                ),
              ),
            );
          },
          icon: const Icon(Icons.copy_outlined, size: 18),
        ),
      ],
    );
  }
}
