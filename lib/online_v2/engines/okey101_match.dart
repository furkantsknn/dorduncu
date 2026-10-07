import 'okey_match.dart';
import 'tile_rules.dart';

/// 101 Okey, four players, one documented variant.
///
/// Opening requires one or more melds worth at least 101.
/// A player may add tiles only to their own melds.
/// The discard pile may be taken only when that tile is played
/// onto a meld before the turn ends. An unopened hand is penalized
/// 202. An opened hand pays the pip sum of tiles still held.
class Okey101Match {
  const Okey101Match({
    required this.hands,
    required this.wall,
    required this.discard,
    required this.context,
    required this.melds,
    required this.opened,
    required this.turn,
    required this.drawn,
    required this.pendingDiscardId,
    required this.winner,
    required this.penalties,
    required this.finished,
  });

  final List<List<OkeyTile>> hands;
  final List<OkeyTile> wall;
  final List<OkeyTile> discard;
  final TileContext context;
  final List<List<List<OkeyTile>>> melds;
  final List<bool> opened;
  final int turn;
  final bool drawn;
  final int? pendingDiscardId;
  final int? winner;
  final List<int> penalties;
  final bool finished;

  factory Okey101Match.deal(int seed) {
    final classic = OkeyMatch.deal(seed);
    return Okey101Match(
      hands: classic.hands,
      wall: classic.wall,
      discard: classic.discard,
      context: classic.context,
      melds: List<List<List<OkeyTile>>>.generate(4, (_) => <List<OkeyTile>>[]),
      opened: const <bool>[false, false, false, false],
      turn: 0,
      drawn: true,
      pendingDiscardId: null,
      winner: null,
      penalties: const <int>[0, 0, 0, 0],
      finished: false,
    );
  }

  Okey101Match apply(int seat, Okey101Action action) {
    if (finished) {
      throw const RuleException('finished', 'Oyun bitti.');
    }
    if (seat != turn) {
      throw const RuleException('not_your_turn', 'Sıra sende değil.');
    }
    if (action is DrawWall101) {
      return _drawWall();
    }
    if (action is DrawDiscard101) {
      return _drawDiscard();
    }
    if (action is OpenMelds) {
      return _open(action.groups);
    }
    if (action is AddToOwnMeld) {
      return _add(action.meldIndex, action.tileId);
    }
    if (action is DiscardTile101) {
      return _discard(action.tileId);
    }
    throw const RuleException('illegal_move', 'Bu hamle yok.');
  }

  Okey101Match _drawWall() {
    _requireDraw();
    if (wall.isEmpty) {
      return _finishRound();
    }
    final nextHands = _copyHands();
    final nextWall = List<OkeyTile>.from(wall);
    nextHands[turn].add(nextWall.removeLast());
    return _copy(hands: nextHands, wall: nextWall, drawn: true);
  }

  Okey101Match _drawDiscard() {
    _requireDraw();
    if (discard.isEmpty) {
      throw const RuleException('no_discard', 'Alınacak atık taş yok.');
    }
    final hands = _copyHands();
    final pile = List<OkeyTile>.from(discard);
    final tile = pile.removeLast();
    hands[turn].add(tile);
    return _copy(
      hands: hands,
      discard: pile,
      drawn: true,
      pendingDiscardId: tile.id,
    );
  }

  Okey101Match _open(List<List<int>> groups) {
    if (!drawn) {
      throw const RuleException('draw_first', 'Önce taş çekmelisin.');
    }
    if (opened[turn]) {
      throw const RuleException('already_open', 'Bu elde zaten açtın.');
    }
    if (groups.isEmpty) {
      throw const RuleException('open_short', 'Açmak için per gerekir.');
    }
    final hand = List<OkeyTile>.from(hands[turn]);
    final played = <List<OkeyTile>>[];
    var points = 0;
    final used = <int>{};
    for (final group in groups) {
      if (group.length < 3) {
        throw const RuleException('illegal_meld', 'Per en az üç taş olmalı.');
      }
      final tiles = <OkeyTile>[];
      for (final id in group) {
        if (!used.add(id)) {
          throw const RuleException(
            'illegal_meld',
            'Aynı taş iki pere giremez.',
          );
        }
        final index = hand.indexWhere((tile) => tile.id == id);
        if (index == -1) {
          throw const RuleException('missing_tile', 'Bu taş elinde yok.');
        }
        tiles.add(hand.removeAt(index));
      }
      final logic = tiles.map((tile) => toLogic(tile, context)).toList();
      if (!isSingleMeld(logic, context)) {
        throw const RuleException('illegal_meld', 'Bu taşlar per olmuyor.');
      }
      points += meldPoints(logic, context);
      played.add(tiles);
    }
    if (points < 101) {
      throw const RuleException(
        'open_short',
        'Açmak için en az 101 puan gerekir.',
      );
    }
    final nextOpened = List<bool>.from(opened);
    nextOpened[turn] = true;
    final nextMelds = _copyMelds();
    nextMelds[turn] = played;
    final next = _copy(
      hands: _replaceHand(hand),
      opened: nextOpened,
      melds: nextMelds,
    );
    if (hand.isEmpty) {
      return next._finishWin();
    }
    return next;
  }

  Okey101Match _add(int meldIndex, int tileId) {
    if (!drawn) {
      throw const RuleException('draw_first', 'Önce taş çekmelisin.');
    }
    if (!opened[turn]) {
      throw const RuleException('not_open', 'Eklemeden önce açmalısın.');
    }
    if (meldIndex < 0 || meldIndex >= melds[turn].length) {
      throw const RuleException('illegal_meld', 'Bu per senin değil.');
    }
    final hand = List<OkeyTile>.from(hands[turn]);
    final index = hand.indexWhere((tile) => tile.id == tileId);
    if (index == -1) {
      throw const RuleException('missing_tile', 'Bu taş elinde yok.');
    }
    final tile = hand.removeAt(index);
    final meld = melds[turn][meldIndex];
    final logicMeld = meld.map((item) => toLogic(item, context)).toList();
    if (!tilesExtendMeld(logicMeld, toLogic(tile, context))) {
      throw const RuleException('illegal_meld', 'Bu taş o pere eklenemez.');
    }
    final nextMelds = _copyMelds();
    nextMelds[turn][meldIndex] = <OkeyTile>[...meld, tile];
    final next = _copy(hands: _replaceHand(hand), melds: nextMelds);
    if (hand.isEmpty) {
      return next._finishWin();
    }
    return next;
  }

  Okey101Match _discard(int tileId) {
    if (!drawn) {
      throw const RuleException('draw_first', 'Önce taş çekmelisin.');
    }
    final pending = pendingDiscardId;
    if (pending != null && hands[turn].any((tile) => tile.id == pending)) {
      throw const RuleException(
        'discard_must_be_played',
        'Atık tan aldığın taşı bu tur perde kullanmalısın.',
      );
    }
    final hand = List<OkeyTile>.from(hands[turn]);
    final index = hand.indexWhere((tile) => tile.id == tileId);
    if (index == -1) {
      throw const RuleException('missing_tile', 'Bu taş elinde yok.');
    }
    final tile = hand.removeAt(index);
    final pile = <OkeyTile>[...discard, tile];
    if (hand.isEmpty) {
      return _copy(hands: _replaceHand(hand), discard: pile)._finishWin();
    }
    return _copy(
      hands: _replaceHand(hand),
      discard: pile,
      turn: (turn + 1) % 4,
      drawn: false,
      clearPending: true,
    );
  }

  void _requireDraw() {
    if (drawn) {
      throw const RuleException('already_drawn', 'Bu tur zaten taş çektin.');
    }
  }

  Okey101Match _finishWin() {
    return _copy(
      winner: turn,
      penalties: _penalties(),
      finished: true,
      drawn: false,
    );
  }

  Okey101Match _finishRound() {
    return _copy(penalties: _penalties(), finished: true, drawn: false);
  }

  List<int> _penalties() {
    return List<int>.generate(4, (seat) {
      if (winner == seat || (winner == null && false)) {
        return 0;
      }
      if (seat == turn && hands[seat].isEmpty) {
        return 0;
      }
      if (!opened[seat]) {
        return 202;
      }
      return hands[seat].fold<int>(
        0,
        (sum, tile) => sum + tilePenalty(tile, context),
      );
    });
  }

  List<List<OkeyTile>> _copyHands() {
    return hands.map(List<OkeyTile>.from).toList();
  }

  List<List<OkeyTile>> _replaceHand(List<OkeyTile> hand) {
    final hands = _copyHands();
    hands[turn] = hand;
    return hands;
  }

  List<List<List<OkeyTile>>> _copyMelds() {
    return melds
        .map(
          (player) => player.map((meld) => List<OkeyTile>.from(meld)).toList(),
        )
        .toList();
  }

  Okey101Match _copy({
    List<List<OkeyTile>>? hands,
    List<OkeyTile>? wall,
    List<OkeyTile>? discard,
    List<List<List<OkeyTile>>>? melds,
    List<bool>? opened,
    int? turn,
    bool? drawn,
    int? pendingDiscardId,
    bool clearPending = false,
    int? winner,
    List<int>? penalties,
    bool? finished,
  }) {
    return Okey101Match(
      hands: hands ?? this.hands,
      wall: wall ?? this.wall,
      discard: discard ?? this.discard,
      context: context,
      melds: melds ?? this.melds,
      opened: opened ?? this.opened,
      turn: turn ?? this.turn,
      drawn: drawn ?? this.drawn,
      pendingDiscardId: clearPending
          ? null
          : (pendingDiscardId ?? this.pendingDiscardId),
      winner: winner ?? this.winner,
      penalties: penalties ?? this.penalties,
      finished: finished ?? this.finished,
    );
  }
}

sealed class Okey101Action {
  const Okey101Action();
}

class DrawWall101 extends Okey101Action {
  const DrawWall101();
}

class DrawDiscard101 extends Okey101Action {
  const DrawDiscard101();
}

class OpenMelds extends Okey101Action {
  const OpenMelds(this.groups);

  final List<List<int>> groups;
}

class AddToOwnMeld extends Okey101Action {
  const AddToOwnMeld(this.meldIndex, this.tileId);

  final int meldIndex;
  final int tileId;
}

class DiscardTile101 extends Okey101Action {
  const DiscardTile101(this.tileId);

  final int tileId;
}
