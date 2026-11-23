import 'package:flutter/material.dart';

import 'market_palette.dart';

TextStyle profileMenuTitleStyle(BuildContext context) {
  final MarketPalette palette = MarketPalette.of(context);
  return (Theme.of(context).textTheme.titleMedium ?? const TextStyle())
      .copyWith(fontWeight: FontWeight.w700, color: palette.ink, height: 1.25);
}

TextStyle profileMenuSubtitleStyle(BuildContext context) {
  final MarketPalette palette = MarketPalette.of(context);
  return (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
    fontWeight: FontWeight.w400,
    color: palette.muted,
    height: 1.35,
  );
}

class ProfileMenuTile extends StatelessWidget {
  const ProfileMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final MarketPalette palette = MarketPalette.of(context);
    return ListTile(
      onTap: onTap,
      minVerticalPadding: 12,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: palette.accent, size: 22),
      title: Text(title, style: profileMenuTitleStyle(context)),
      subtitle: Text(subtitle, style: profileMenuSubtitleStyle(context)),
      trailing:
          trailing ?? Icon(Icons.chevron_right_rounded, color: palette.muted),
    );
  }
}

class ProfileHeading extends StatelessWidget {
  const ProfileHeading({super.key, required this.title, this.icon});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final MarketPalette palette = MarketPalette.of(context);
    return Row(
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, color: palette.accent, size: 22),
          const SizedBox(width: 8),
        ],
        Expanded(child: Text(title, style: profileMenuTitleStyle(context))),
      ],
    );
  }
}
