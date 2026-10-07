import 'dart:math';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../bots/online_bots.dart';
import '../engines/batak_match.dart';
import '../engines/okey101_match.dart';
import '../engines/okey_match.dart';
import '../engines/tavla_match.dart';
import '../engines/tile_rules.dart';

enum OnlineTableKind { okey, okey101, batak, tavla }

class LocalTableScreen extends StatefulWidget {
  const LocalTableScreen({super.key, required this.kind});

  final OnlineTableKind kind;

  @override
  State<LocalTableScreen> createState() => _LocalTableScreenState();
}

class _LocalTableScreenState extends State<LocalTableScreen> {
  final Random _random = Random();
  late OkeyMatch _okey;
  late Okey101Match _okey101;
  late BatakMatch _batak;
  late TavlaMatch _tavla;
  String? _error;
  final List<int> _selected = <int>[];
  final List<List<int>> _groups = <List<int>>[];

  @override
  void initState() {
    super.initState();
    final seed = _random.nextInt(1 << 30);
    _okey = OkeyMatch.deal(seed);
    _okey101 = Okey101Match.deal(seed);
    _batak = BatakMatch.deal(seed);
    _tavla = TavlaMatch.initial();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runBots());
  }

  bool get _finished {
    switch (widget.kind) {
      case OnlineTableKind.okey:
        return _okey.finished;
      case OnlineTableKind.okey101:
        return _okey101.finished;
      case OnlineTableKind.batak:
        return _batak.finished;
      case OnlineTableKind.tavla:
        return _tavla.finished;
    }
  }

  int get _turn {
    switch (widget.kind) {
      case OnlineTableKind.okey:
        return _okey.turn;
      case OnlineTableKind.okey101:
        return _okey101.turn;
      case OnlineTableKind.batak:
        return _batak.turn;
      case OnlineTableKind.tavla:
        return _tavla.turn;
    }
  }

  void _runBots() {
    if (!mounted || _finished) {
      return;
    }
    try {
      var guard = 0;
      while (_turn != 0 && !_finished && guard < 40) {
        _playOneBot();
        guard++;
      }
    } on RuleException catch (error) {
      _error = error.message;
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _playOneBot() {
    switch (widget.kind) {
      case OnlineTableKind.okey:
        _okey = playOkeyBot(_okey);
      case OnlineTableKind.okey101:
        _okey101 = playOkey101Bot(_okey101);
      case OnlineTableKind.batak:
        _batak = playBatakBot(_batak);
      case OnlineTableKind.tavla:
        _tavla = playTavlaBot(_tavla, _random);
    }
  }

  void _act(void Function() action) {
    try {
      action();
      _error = null;
      _selected.clear();
      setState(() {});
      _runBots();
    } on RuleException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final title = switch (widget.kind) {
      OnlineTableKind.okey => 'Okey',
      OnlineTableKind.okey101 => '101',
      OnlineTableKind.batak => 'Batak',
      OnlineTableKind.tavla => 'Tavla',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.sensors, size: 18),
                label: Text(text.localSession),
              ),
              Chip(
                label: Text(
                  _turn == 0 ? text.yourTurnLabel : text.botTurnLabel,
                ),
              ),
              for (var seat = 0; seat < _playerCount; seat++)
                Chip(
                  avatar: CircleAvatar(
                    child: Text(
                      seat == 0 ? 'S' : 'B',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  label: Text(_seatLabel(text, seat)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 12),
          if (_finished) _result(text) else _board(text),
        ],
      ),
    );
  }

  int get _playerCount => widget.kind == OnlineTableKind.tavla ? 2 : 4;

  String _seatLabel(AppLocalizations text, int seat) {
    if (seat == 0) {
      return text.youLabel;
    }
    return 'Bot ${seat + 1}';
  }

  Widget _result(AppLocalizations text) {
    final lines = switch (widget.kind) {
      OnlineTableKind.okey => [
        for (var seat = 0; seat < 4; seat++)
          '${_seatLabel(text, seat)}: ${_okey.penalties[seat]}',
      ],
      OnlineTableKind.okey101 => [
        for (var seat = 0; seat < 4; seat++)
          '${_seatLabel(text, seat)}: ${_okey101.penalties[seat]}',
      ],
      OnlineTableKind.batak => [
        for (var seat = 0; seat < 4; seat++)
          '${_seatLabel(text, seat)}: ${_batak.scores[seat]}',
      ],
      OnlineTableKind.tavla => [
        '${_seatLabel(text, _tavla.winner ?? 0)} × ${_tavla.stake}',
      ],
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text.finishedTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final line in lines) Text(line),
          ],
        ),
      ),
    );
  }

  Widget _board(AppLocalizations text) {
    switch (widget.kind) {
      case OnlineTableKind.okey:
        return _okeyBoard(text);
      case OnlineTableKind.okey101:
        return _okey101Board(text);
      case OnlineTableKind.batak:
        return _batakBoard(text);
      case OnlineTableKind.tavla:
        return _tavlaBoard(text);
    }
  }

  Widget _okeyBoard(AppLocalizations text) {
    final view = _okey.viewFor(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_indicator(view.context)),
        Text('${text.drawWallAction}: ${view.wallCount}'),
        const SizedBox(height: 8),
        if (!view.awaitingDiscard && view.turn == 0)
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: () =>
                    _act(() => _okey = _okey.apply(0, const DrawWall())),
                child: Text(text.drawWallAction),
              ),
              FilledButton(
                onPressed: view.discard.isEmpty
                    ? null
                    : () => _act(
                        () => _okey = _okey.apply(0, const DrawDiscard()),
                      ),
                child: Text(text.takeDiscardAction),
              ),
            ],
          ),
        if (view.discard.isNotEmpty)
          Text(_tileFace(view.discard.last, view.context)),
        const SizedBox(height: 8),
        _tileWrap(view.hand, view.context, (tile) {
          if (view.turn != 0 || !view.awaitingDiscard) {
            return;
          }
          _act(() => _okey = _okey.apply(0, DiscardTile(tile.id)));
        }),
      ],
    );
  }

  Widget _okey101Board(AppLocalizations text) {
    final hand = _okey101.hands[0];
    final mine = _okey101.turn == 0 && _okey101.drawn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_indicator(_okey101.context)),
        if (_okey101.turn == 0 && !_okey101.drawn)
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: () => _act(
                  () => _okey101 = _okey101.apply(0, const DrawWall101()),
                ),
                child: Text(text.drawWallAction),
              ),
              FilledButton(
                onPressed: _okey101.discard.isEmpty
                    ? null
                    : () => _act(
                        () => _okey101 = _okey101.apply(
                          0,
                          const DrawDiscard101(),
                        ),
                      ),
                child: Text(text.takeDiscardAction),
              ),
            ],
          ),
        if (_okey101.discard.isNotEmpty)
          Text(_tileFace(_okey101.discard.last, _okey101.context)),
        const SizedBox(height: 8),
        _tileWrap(hand, _okey101.context, (tile) {
          setState(() {
            if (_selected.contains(tile.id)) {
              _selected.remove(tile.id);
            } else {
              _selected.add(tile.id);
            }
          });
        }, selected: _selected),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: !mine || _selected.length < 3
                  ? null
                  : () {
                      setState(() {
                        _groups.add(List<int>.from(_selected));
                        _selected.clear();
                      });
                    },
              child: Text('${text.openAction} +'),
            ),
            FilledButton(
              onPressed: !mine || _groups.isEmpty
                  ? null
                  : () => _act(() {
                      _okey101 = _okey101.apply(
                        0,
                        OpenMelds(List<List<int>>.from(_groups)),
                      );
                      _groups.clear();
                    }),
              child: Text(text.openAction),
            ),
            for (var index = 0; index < _okey101.melds[0].length; index++)
              OutlinedButton(
                onPressed: !mine || _selected.length != 1
                    ? null
                    : () => _act(() {
                        _okey101 = _okey101.apply(
                          0,
                          AddToOwnMeld(index, _selected.first),
                        );
                      }),
                child: Text('${text.addMeldAction} ${index + 1}'),
              ),
            FilledButton(
              onPressed: !mine || _selected.length != 1
                  ? null
                  : () => _act(() {
                      _okey101 = _okey101.apply(
                        0,
                        DiscardTile101(_selected.first),
                      );
                    }),
              child: Text(text.discardAction),
            ),
          ],
        ),
        if (_okey101.melds[0].isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _okey101.melds[0]
                  .map(
                    (meld) => meld
                        .map((tile) => _tileFace(tile, _okey101.context))
                        .join(' '),
                  )
                  .join(' | '),
            ),
          ),
      ],
    );
  }

  Widget _batakBoard(AppLocalizations text) {
    final hand = _batak.hands[0];
    final legal = _batak.legalCards(0).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_phaseName()),
        if (_batak.trump != null) Text(_suitName(_batak.trump!)),
        const SizedBox(height: 8),
        if (_batak.phase == BatakPhase.auction && _batak.turn == 0)
          Wrap(
            spacing: 8,
            children: [
              for (final bid in _batak.legalBids())
                FilledButton(
                  onPressed: () =>
                      _act(() => _batak = _batak.apply(0, BidAction(bid))),
                  child: Text('$bid'),
                ),
              OutlinedButton(
                onPressed: () =>
                    _act(() => _batak = _batak.apply(0, const PassBid())),
                child: Text(text.passAction),
              ),
            ],
          ),
        if (_batak.phase == BatakPhase.trump && _batak.turn == 0)
          Wrap(
            spacing: 8,
            children: [
              for (final suit in BatakSuit.values)
                FilledButton(
                  onPressed: () =>
                      _act(() => _batak = _batak.apply(0, ChooseTrump(suit))),
                  child: Text(_suitName(suit)),
                ),
            ],
          ),
        Wrap(
          spacing: 8,
          children: [
            for (final card in hand)
              FilledButton(
                onPressed: legal.contains(card)
                    ? () => _act(() => _batak = _batak.apply(0, PlayCard(card)))
                    : null,
                child: Text(_cardFace(card)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _tavlaBoard(AppLocalizations text) {
    final steps = _tavla.turn == 0 ? _tavla.legalSteps() : const <TavlaStep>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bar ${_tavla.bar[0]}/${_tavla.bar[1]}  Off ${_tavla.off[0]}/${_tavla.off[1]}',
        ),
        Text(_tavla.dice.isEmpty ? '—' : _tavla.dice.join(' ')),
        const SizedBox(height: 8),
        Text(_tavla.points.map((count) => '$count').join(' ')),
        const SizedBox(height: 8),
        if (_tavla.turn == 0 && _tavla.dice.isEmpty)
          FilledButton(
            onPressed: () => _act(() {
              _tavla = _tavla.roll(
                _random.nextInt(6) + 1,
                _random.nextInt(6) + 1,
              );
            }),
            child: Text(text.rollDice),
          ),
        if (steps.isEmpty && _tavla.turn == 0 && _tavla.dice.isNotEmpty)
          FilledButton(
            onPressed: () => _act(() => _tavla = _tavla.passStuck()),
            child: Text(text.passAction),
          ),
        Wrap(
          spacing: 8,
          children: [
            for (final step in steps)
              FilledButton(
                onPressed: () => _act(() => _tavla = _tavla.apply(0, step)),
                child: Text(_stepLabel(step)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _tileWrap(
    List<OkeyTile> hand,
    TileContext context,
    void Function(OkeyTile tile) onTap, {
    List<int> selected = const <int>[],
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tile in hand)
          FilterChip(
            selected: selected.contains(tile.id),
            label: Text(_tileFace(tile, context)),
            onSelected: (_) => onTap(tile),
          ),
      ],
    );
  }

  String _indicator(TileContext tileContext) {
    return _tileFace(tileContext.indicator, tileContext);
  }

  String _tileFace(OkeyTile tile, TileContext tileContext) {
    final logic = toLogic(tile, tileContext);
    if (logic.wild) {
      return 'Okey';
    }
    final language = Localizations.localeOf(context).languageCode;
    final color = logic.color ?? tile.color;
    final number = logic.number ?? tile.number;
    return '${_colorName(language, color)} $number';
  }

  String _colorName(String language, int color) {
    const names = <String, List<String>>{
      'tr': <String>['Kırmızı', 'Sarı', 'Mavi', 'Siyah'],
      'de': <String>['Rot', 'Gelb', 'Blau', 'Schwarz'],
      'en': <String>['Red', 'Yellow', 'Blue', 'Black'],
    };
    final words = names[language] ?? names['en']!;
    if (color < 0 || color >= words.length) {
      return '?';
    }
    return words[color];
  }

  String _phaseName() {
    final language = Localizations.localeOf(context).languageCode;
    const names = <String, List<String>>{
      'tr': <String>['İhale', 'Koz', 'Oyun', 'Bitti'],
      'en': <String>['Auction', 'Trump', 'Play', 'Done'],
      'de': <String>['Reizen', 'Trumpf', 'Spiel', 'Fertig'],
    };
    return (names[language] ?? names['en']!)[_batak.phase.index];
  }

  String _suitName(BatakSuit suit) {
    final language = Localizations.localeOf(context).languageCode;
    const names = <String, List<String>>{
      'tr': <String>['Sinek', 'Karo', 'Kupa', 'Maça'],
      'de': <String>['Kreuz', 'Karo', 'Herz', 'Pik'],
      'en': <String>['Clubs', 'Diamonds', 'Hearts', 'Spades'],
    };
    return (names[language] ?? names['en']!)[suit.index];
  }

  String _cardFace(BatakCard card) {
    final rank = switch (card.rank) {
      11 => 'J',
      12 => 'Q',
      13 => 'K',
      14 => 'A',
      _ => '${card.rank}',
    };
    return '${_suitName(card.suit)} $rank';
  }

  String _stepLabel(TavlaStep step) {
    final from = step.from == 24 ? 'Bar' : '${step.from + 1}';
    final to = step.to < 0 ? 'Off' : '${step.to + 1}';
    return '$from → $to (${step.die})';
  }
}
