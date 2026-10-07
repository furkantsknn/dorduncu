import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../online_games_v2_config.dart';
import 'local_table_screen.dart';

class OnlinePlayHub extends StatelessWidget {
  const OnlinePlayHub({super.key});

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final games = <_GameCard>[
      _GameCard(OnlineTableKind.okey, 'Okey', text.okeyRule),
      _GameCard(OnlineTableKind.okey101, '101', text.okey101Rule),
      _GameCard(OnlineTableKind.batak, 'Batak', text.batakRule),
      _GameCard(OnlineTableKind.tavla, 'Tavla', text.tavlaRule),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(text.onlinePlay)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(text.onlinePlayIntro),
          const SizedBox(height: 16),
          for (final game in games) ...[
            _GamePanel(game: game, text: text),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      onlineGamesV2MultiplayerAvailable
                          ? text.multiplayerUnverified
                          : text.multiplayerClosed,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameCard {
  const _GameCard(this.kind, this.title, this.rule);

  final OnlineTableKind kind;
  final String title;
  final String rule;
}

class _GamePanel extends StatelessWidget {
  const _GamePanel({required this.game, required this.text});

  final _GameCard game;
  final AppLocalizations text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(game.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(game.rule),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => LocalTableScreen(kind: game.kind),
                  ),
                );
              },
              child: Text(text.playWithBots),
            ),
          ],
        ),
      ),
    );
  }
}
