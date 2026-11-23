import 'package:flutter/material.dart';

/// Ana ekranda ve yalnız yerel release görsel doğrulama fixture'ında kullanılan
/// tek alt menü bileşeni. Fixture ayrı bir alt menü çizmez.
class HomeBottomNavigation extends StatelessWidget {
  const HomeBottomNavigation({
    required this.messageTooltip,
    required this.profileTooltip,
    required this.onMessages,
    required this.onCreateEvent,
    required this.onProfile,
    super.key,
  });

  final String messageTooltip;
  final String profileTooltip;
  final VoidCallback onMessages;
  final VoidCallback onCreateEvent;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    const Color canvas = Color(0xff0F1115);
    const Color barColor = Color(0xff161D2B);
    const double buttonSize = 56;

    return ColoredBox(
      color: canvas,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: SizedBox(
            height: 78,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 62,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(31),
                          border: Border.all(color: const Color(0x1AFFFFFF)),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x59000000),
                              blurRadius: 16,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 62,
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: _NavItem(
                              icon: Icons.chat_bubble_outline_rounded,
                              tooltip: messageTooltip,
                              onTap: onMessages,
                            ),
                          ),
                          const SizedBox(width: buttonSize + 10),
                          Expanded(
                            child: _NavItem(
                              icon: Icons.person_outline_rounded,
                              tooltip: profileTooltip,
                              onTap: onProfile,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: (constraints.maxWidth - buttonSize) / 2,
                      child: Material(
                        color: const Color(0xffFF9800),
                        elevation: 8,
                        shadowColor: const Color(0x73FF9800),
                        shape: const CircleBorder(
                          side: BorderSide(color: Color(0xff0F1115), width: 4),
                        ),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onCreateEvent,
                          child: const SizedBox(
                            width: buttonSize,
                            height: buttonSize,
                            child: Icon(
                              Icons.add_rounded,
                              color: Color(0xff111827),
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 62,
        child: Icon(icon, color: const Color(0xffE8EDF5), size: 24),
      ),
    ),
  );
}
