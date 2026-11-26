import 'package:flutter/material.dart';

import '../utils/game_catalog.dart';
import '../utils/game_experience.dart';

/// High-contrast 3-step game experience selector (`Acemi` / `Orta` / `Usta` in
/// TR, EN, and DE). Avoids Material 3 light-theme `ChoiceChip` surface tint
/// washing out labels on dark onboarding cards and scales cleanly on narrow
/// iPhone/Android screens without text overflow.
class GameLevelSelector extends StatelessWidget {
  const GameLevelSelector({
    super.key,
    required this.selectedLevel,
    required this.onSelected,
    this.enabled = true,
    this.darkSurface = true,
    this.gameId,
  });

  final int selectedLevel;
  final ValueChanged<SkillLevelDefinition> onSelected;
  final bool enabled;
  final bool darkSurface;
  final String? gameId;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final bool useDarkPalette = darkSurface || isDarkTheme;

    final Color selectedBg = useDarkPalette
        ? const Color(0xffFF9800)
        : scheme.primary;
    final Color selectedFg = useDarkPalette
        ? const Color(0xff111318)
        : scheme.onPrimary;
    final Color selectedBorder = useDarkPalette
        ? const Color(0xffFFB74D)
        : scheme.primary;

    final Color unselectedBg = useDarkPalette
        ? const Color(0xff252A34)
        : const Color(0xffEFECE4);
    final Color unselectedFg = useDarkPalette
        ? const Color(0xffF3F4F6)
        : const Color(0xff1F2937);
    final Color unselectedBorder = useDarkPalette
        ? const Color(0xff424958)
        : const Color(0xffCBC5B8);

    final List<SkillLevelDefinition> levels = GameCatalog.skillLevels;

    return Row(
      children: List<Widget>.generate(levels.length, (int index) {
        final SkillLevelDefinition skill = levels[index];
        final bool active = selectedLevel == skill.value;
        final String label = gameExperienceLabel(context, skill.value);

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == levels.length - 1 ? 0 : 8),
            child: Semantics(
              button: true,
              selected: active,
              enabled: enabled,
              label: label,
              child: Material(
                key: gameId == null
                    ? null
                    : ValueKey<String>('game_level_${gameId}_${skill.value}'),
                color: active ? selectedBg : unselectedBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                  side: BorderSide(
                    color: active ? selectedBorder : unselectedBorder,
                    width: active ? 1.5 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: enabled ? () => onSelected(skill) : null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 42),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 9,
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (active) ...<Widget>[
                                Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: selectedFg,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                label,
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  color: active ? selectedFg : unselectedFg,
                                  fontSize: 13,
                                  fontWeight: active
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
