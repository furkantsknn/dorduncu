import 'dart:math';

import 'tile_rules.dart';

/// Standard backgammon for two players, without a doubling cube.
///
/// White (seat 0) moves toward point 1 and bears off from points 1–6.
/// Black (seat 1) moves toward point 24 and bears off from points 19–24.
/// A checker on the bar must enter before any other move. A blot may be
/// hit. Landing on a point with two or more opposing checkers is illegal.
/// A normal win scores 1, a gammon 2 and a backgammon 3.
class TavlaMatch {
  const TavlaMatch({
    required this.points,
    required this.bar,
    required this.off,
    required this.turn,
    required this.dice,
    required this.finished,
    required this.winner,
    required this.stake,
  });

  /// Positive counts are white. Negative counts are black.
  final List<int> points;
  final List<int> bar;
  final List<int> off;
  final int turn;
  final List<int> dice;
  final bool finished;
  final int? winner;
  final int stake;

  factory TavlaMatch.initial({List<int> dice = const <int>[]}) {
    final points = List<int>.filled(24, 0);
    points[23] = 2;
    points[12] = 5;
    points[7] = 3;
    points[5] = 5;
    points[0] = -2;
    points[11] = -5;
    points[16] = -3;
    points[18] = -5;
    return TavlaMatch(
      points: points,
      bar: const <int>[0, 0],
      off: const <int>[0, 0],
      turn: 0,
      dice: dice,
      finished: false,
      winner: null,
      stake: 1,
    );
  }

  TavlaMatch roll(int first, int second) {
    if (finished) {
      throw const RuleException('finished', 'Oyun bitti.');
    }
    if (dice.isNotEmpty) {
      throw const RuleException(
        'dice_open',
        'Açık zar varken yeniden atılmaz.',
      );
    }
    if (first < 1 || first > 6 || second < 1 || second > 6) {
      throw const RuleException('illegal_move', 'Zar 1 ile 6 arasında olmalı.');
    }
    final rolled = first == second
        ? <int>[first, first, first, first]
        : <int>[first, second];
    return _copy(dice: rolled);
  }

  List<TavlaStep> legalSteps() {
    if (finished || dice.isEmpty) {
      return const <TavlaStep>[];
    }
    final raw = _rawSteps(this);
    if (dice.length <= 1 || raw.isEmpty) {
      return raw;
    }
    final completable = <TavlaStep>[];
    for (final step in raw) {
      final next = _apply(this, step);
      if (_canUseAll(next)) {
        completable.add(step);
      }
    }
    if (completable.isNotEmpty) {
      return completable;
    }
    final larger = dice.reduce(max);
    final largerSteps = raw.where((step) => step.die == larger).toList();
    if (largerSteps.isNotEmpty && dice.toSet().length > 1) {
      return largerSteps;
    }
    return raw;
  }

  TavlaMatch passStuck() {
    if (finished) {
      throw const RuleException('finished', 'Oyun bitti.');
    }
    if (legalSteps().isNotEmpty) {
      throw const RuleException(
        'illegal_move',
        'Oynanacak hamle varken pas geçilmez.',
      );
    }
    return _copy(dice: const <int>[], turn: 1 - turn);
  }

  TavlaMatch apply(int seat, TavlaStep step) {
    if (finished) {
      throw const RuleException('finished', 'Oyun bitti.');
    }
    if (seat != turn) {
      throw const RuleException('not_your_turn', 'Sıra sende değil.');
    }
    final allowed = legalSteps();
    if (!allowed.contains(step)) {
      throw const RuleException('illegal_move', 'Bu hamle kurallara uymuyor.');
    }
    final next = _apply(this, step);
    if (next.off[turn] == 15) {
      return next._won(turn);
    }
    if (next.legalSteps().isEmpty) {
      return next._copy(dice: const <int>[], turn: 1 - turn);
    }
    return next;
  }

  TavlaMatch _won(int seat) {
    final other = 1 - seat;
    var stake = 1;
    if (off[other] == 0) {
      stake = 2;
      final enemyTrapped = seat == 0
          ? points.take(6).any((count) => count < 0) || bar[1] > 0
          : points.skip(18).any((count) => count > 0) || bar[0] > 0;
      if (enemyTrapped) {
        stake = 3;
      }
    }
    return _copy(
      points: points,
      bar: bar,
      off: off,
      dice: const <int>[],
      finished: true,
      winner: seat,
      stake: stake,
    );
  }
}

class TavlaStep {
  const TavlaStep({required this.from, required this.die, required this.to});

  /// 24 is the bar. -1 is bearing off.
  final int from;
  final int die;
  final int to;

  @override
  bool operator ==(Object other) {
    return other is TavlaStep &&
        other.from == from &&
        other.die == die &&
        other.to == to;
  }

  @override
  int get hashCode => Object.hash(from, die, to);
}

List<TavlaStep> _rawSteps(TavlaMatch match) {
  final seat = match.turn;
  final direction = seat == 0 ? -1 : 1;
  final steps = <TavlaStep>[];
  final dice = match.dice.toSet();
  for (final die in dice) {
    if (match.bar[seat] > 0) {
      final entry = seat == 0 ? 24 - die : die - 1;
      if (_canLand(match, seat, entry)) {
        steps.add(TavlaStep(from: 24, die: die, to: entry));
      }
      continue;
    }
    for (var index = 0; index < 24; index++) {
      if (!_owns(match, seat, index)) {
        continue;
      }
      final destination = index + (direction * die);
      if (destination >= 0 && destination < 24) {
        if (_canLand(match, seat, destination)) {
          steps.add(TavlaStep(from: index, die: die, to: destination));
        }
        continue;
      }
      if (_canBearOff(match, seat, index, die)) {
        steps.add(TavlaStep(from: index, die: die, to: -1));
      }
    }
  }
  return steps;
}

bool _owns(TavlaMatch match, int seat, int index) {
  final count = match.points[index];
  return seat == 0 ? count > 0 : count < 0;
}

bool _canLand(TavlaMatch match, int seat, int index) {
  final count = match.points[index];
  if (seat == 0) {
    return count >= -1;
  }
  return count <= 1;
}

bool _canBearOff(TavlaMatch match, int seat, int index, int die) {
  if (match.bar[seat] > 0 || !_allHome(match, seat)) {
    return false;
  }
  final pointNumber = seat == 0 ? index + 1 : 24 - index;
  if (die == pointNumber) {
    return true;
  }
  if (die < pointNumber) {
    return false;
  }
  if (seat == 0) {
    return !match.points.sublist(index + 1, 6).any((count) => count > 0);
  }
  return !match.points.sublist(18, index).any((count) => count < 0);
}

bool _allHome(TavlaMatch match, int seat) {
  if (match.bar[seat] > 0) {
    return false;
  }
  if (seat == 0) {
    return match.points.skip(6).every((count) => count <= 0);
  }
  return match.points.take(18).every((count) => count >= 0);
}

TavlaMatch _apply(TavlaMatch match, TavlaStep step) {
  final seat = match.turn;
  final points = List<int>.from(match.points);
  final bar = List<int>.from(match.bar);
  final off = List<int>.from(match.off);
  final sign = seat == 0 ? 1 : -1;
  if (step.from == 24) {
    bar[seat] -= 1;
  } else {
    points[step.from] -= sign;
  }
  if (step.to == -1) {
    off[seat] += 1;
  } else {
    final occupied = points[step.to];
    if (occupied != 0 && occupied.sign != sign) {
      bar[1 - seat] += 1;
      points[step.to] = sign;
    } else {
      points[step.to] += sign;
    }
  }
  final dice = List<int>.from(match.dice);
  dice.remove(step.die);
  return match._copy(points: points, bar: bar, off: off, dice: dice);
}

bool _canUseAll(TavlaMatch match) {
  if (match.dice.isEmpty) {
    return true;
  }
  final steps = _rawSteps(match);
  if (steps.isEmpty) {
    return false;
  }
  final seen = <TavlaStep>{};
  for (final step in steps) {
    if (!seen.add(step)) {
      continue;
    }
    if (_canUseAll(_apply(match, step))) {
      return true;
    }
  }
  return false;
}

extension on TavlaMatch {
  TavlaMatch _copy({
    List<int>? points,
    List<int>? bar,
    List<int>? off,
    int? turn,
    List<int>? dice,
    bool? finished,
    int? winner,
    int? stake,
  }) {
    return TavlaMatch(
      points: points ?? this.points,
      bar: bar ?? this.bar,
      off: off ?? this.off,
      turn: turn ?? this.turn,
      dice: dice ?? this.dice,
      finished: finished ?? this.finished,
      winner: winner ?? this.winner,
      stake: stake ?? this.stake,
    );
  }
}
