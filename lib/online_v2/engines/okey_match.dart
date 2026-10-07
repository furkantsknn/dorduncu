import 'tile_rules.dart';

class OkeyMatch {
  const OkeyMatch({
    required this.hands,
    required this.wall,
    required this.discard,
    required this.context,
    required this.turn,
    required this.awaitingDiscard,
    required this.winner,
    required this.penalties,
    required this.finished,
  });

  final List<List<OkeyTile>> hands;
  final List<OkeyTile> wall;
  final List<OkeyTile> discard;
  final TileContext context;
  final int turn;
  final bool awaitingDiscard;
  final int? winner;
  final List<int> penalties;
  final bool finished;

  bool get drawn => finished && winner == null;

  factory OkeyMatch.deal(int seed) {
    final deck = shuffledDeck(seed);
    var indicator = deck.removeLast();
    while (indicator.fakeJoker) {
      deck.insert(0, indicator);
      indicator = deck.removeLast();
    }
    final context = contextFromIndicator(indicator);
    final hands = List<List<OkeyTile>>.generate(4, (_) => <OkeyTile>[]);
    for (var round = 0; round < 14; round++) {
      for (var seat = 0; seat < 4; seat++) {
        hands[seat].add(deck.removeLast());
      }
    }
    hands[0].add(deck.removeLast());
    return OkeyMatch(
      hands: hands,
      wall: deck,
      discard: const <OkeyTile>[],
      context: context,
      turn: 0,
      awaitingDiscard: true,
      winner: null,
      penalties: const <int>[0, 0, 0, 0],
      finished: false,
    );
  }

  OkeyMatch apply(int seat, OkeyAction action) {
    if (finished) {
      throw const RuleException('finished', 'Oyun bitti.');
    }
    if (seat != turn) {
      throw const RuleException('not_your_turn', 'Sıra sende değil.');
    }
    if (action is DrawWall) {
      return _drawWall();
    }
    if (action is DrawDiscard) {
      return _drawDiscard();
    }
    if (action is DiscardTile) {
      return _discard(action.tileId);
    }
    throw const RuleException('illegal_move', 'Bu hamle yok.');
  }

  OkeyPublicView viewFor(int seat) {
    return OkeyPublicView(
      seat: seat,
      hand: List<OkeyTile>.unmodifiable(hands[seat]),
      handCounts: hands.map((hand) => hand.length).toList(growable: false),
      wallCount: wall.length,
      discard: List<OkeyTile>.unmodifiable(discard),
      context: context,
      turn: turn,
      awaitingDiscard: awaitingDiscard,
      finished: finished,
      winner: winner,
      penalties: penalties,
    );
  }

  OkeyMatch _drawWall() {
    _requireDraw();
    if (wall.isEmpty) {
      if (discard.isNotEmpty) {
        throw const RuleException(
          'wall_empty',
          'Deste bitti. Son atılan taşı alabilirsin.',
        );
      }
      return _finishDraw();
    }
    final nextHands = _copyHands();
    final nextWall = List<OkeyTile>.from(wall);
    nextHands[turn].add(nextWall.removeLast());
    return _copy(hands: nextHands, wall: nextWall, awaitingDiscard: true);
  }

  OkeyMatch _drawDiscard() {
    _requireDraw();
    if (discard.isEmpty) {
      throw const RuleException('no_discard', 'Alınacak atık taş yok.');
    }
    final nextHands = _copyHands();
    final nextDiscard = List<OkeyTile>.from(discard);
    nextHands[turn].add(nextDiscard.removeLast());
    return _copy(hands: nextHands, discard: nextDiscard, awaitingDiscard: true);
  }

  OkeyMatch _discard(int tileId) {
    if (!awaitingDiscard) {
      throw const RuleException('draw_first', 'Önce taş çekmelisin.');
    }
    final hand = hands[turn];
    final index = hand.indexWhere((tile) => tile.id == tileId);
    if (index == -1) {
      throw const RuleException('missing_tile', 'Bu taş elinde yok.');
    }
    final nextHands = _copyHands();
    final tile = nextHands[turn].removeAt(index);
    final nextDiscard = <OkeyTile>[...discard, tile];
    if (canFinishHand(nextHands[turn], context)) {
      return _finishWin(nextHands, nextDiscard);
    }
    return _copy(
      hands: nextHands,
      discard: nextDiscard,
      turn: (turn + 1) % 4,
      awaitingDiscard: false,
    );
  }

  void _requireDraw() {
    if (awaitingDiscard) {
      throw const RuleException('discard_first', 'Önce bir taş atmalısın.');
    }
  }

  OkeyMatch _finishWin(List<List<OkeyTile>> nextHands, List<OkeyTile> pile) {
    final penalties = <int>[];
    for (var seat = 0; seat < 4; seat++) {
      if (seat == turn) {
        penalties.add(0);
      } else {
        penalties.add(
          nextHands[seat].fold<int>(
            0,
            (sum, tile) => sum + tilePenalty(tile, context),
          ),
        );
      }
    }
    return _copy(
      hands: nextHands,
      discard: pile,
      awaitingDiscard: false,
      winner: turn,
      penalties: penalties,
      finished: true,
    );
  }

  OkeyMatch _finishDraw() {
    final penalties = hands
        .map(
          (hand) => hand.fold<int>(
            0,
            (sum, tile) => sum + tilePenalty(tile, context),
          ),
        )
        .toList(growable: false);
    return _copy(penalties: penalties, finished: true, awaitingDiscard: false);
  }

  List<List<OkeyTile>> _copyHands() {
    return hands.map((hand) => List<OkeyTile>.from(hand)).toList();
  }

  OkeyMatch _copy({
    List<List<OkeyTile>>? hands,
    List<OkeyTile>? wall,
    List<OkeyTile>? discard,
    int? turn,
    bool? awaitingDiscard,
    int? winner,
    List<int>? penalties,
    bool? finished,
  }) {
    return OkeyMatch(
      hands: hands ?? this.hands,
      wall: wall ?? this.wall,
      discard: discard ?? this.discard,
      context: context,
      turn: turn ?? this.turn,
      awaitingDiscard: awaitingDiscard ?? this.awaitingDiscard,
      winner: winner ?? this.winner,
      penalties: penalties ?? this.penalties,
      finished: finished ?? this.finished,
    );
  }
}

class OkeyPublicView {
  const OkeyPublicView({
    required this.seat,
    required this.hand,
    required this.handCounts,
    required this.wallCount,
    required this.discard,
    required this.context,
    required this.turn,
    required this.awaitingDiscard,
    required this.finished,
    required this.winner,
    required this.penalties,
  });

  final int seat;
  final List<OkeyTile> hand;
  final List<int> handCounts;
  final int wallCount;
  final List<OkeyTile> discard;
  final TileContext context;
  final int turn;
  final bool awaitingDiscard;
  final bool finished;
  final int? winner;
  final List<int> penalties;
}

sealed class OkeyAction {
  const OkeyAction();
}

class DrawWall extends OkeyAction {
  const DrawWall();
}

class DrawDiscard extends OkeyAction {
  const DrawDiscard();
}

class DiscardTile extends OkeyAction {
  const DiscardTile(this.tileId);

  final int tileId;
}
