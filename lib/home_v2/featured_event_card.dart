import 'package:flutter/material.dart';

import 'home_listed_event.dart';
import '../services/language_controller.dart';

class FeaturedEventCard extends StatelessWidget {
  const FeaturedEventCard({
    required this.event,
    required this.onTap,
    super.key,
  });

  final HomeListedEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final AppLanguage language = LanguageController.language.value;

    return Material(
      color: isDark ? const Color(0xff161D2B) : scheme.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0x14FFFFFF) : scheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: _Cover(event: event)),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    _Meta(
                      icon: Icons.calendar_today_rounded,
                      label: '${event.dateLabel(language)} · ${event.time}',
                    ),
                    const SizedBox(height: 3),
                    _Meta(
                      icon: Icons.location_on_rounded,
                      label: event.locationLabel,
                    ),
                    const SizedBox(height: 3),
                    _Meta(
                      icon: Icons.group_outlined,
                      label: event.participantLabel(language),
                      accent: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.event});

  final HomeListedEvent event;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (event.imageAsset == null)
          const ColoredBox(
            color: Color(0xff1B2433),
            child: Icon(Icons.sports_rounded, color: Color(0xffFF9800)),
          )
        else
          Image.asset(
            event.imageAsset!,
            fit: BoxFit.cover,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stack) {
                  return const ColoredBox(
                    color: Color(0xff1B2433),
                    child: Icon(Icons.sports_rounded, color: Color(0xffFF9800)),
                  );
                },
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0x00000000), Color(0x66000000)],
            ),
          ),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label, this.accent = false});

  final IconData icon;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final Color color = accent
        ? const Color(0xffFF9800)
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      children: <Widget>[
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
