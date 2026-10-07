import 'dart:math';

import '../engines/batak_match.dart';
import '../engines/okey101_match.dart';
import '../engines/okey_match.dart';
import '../engines/tavla_match.dart';
import '../engines/tile_rules.dart';

/// Bots see only the acting seat's hand and the public table.
OkeyMatch playOkeyBot(OkeyMatch match) {
  final seat = match.turn;
  final view = match.viewFor(seat);
  if (!view.awaitingDiscard) {
    if (view.wallCount == 0 && view.discard.isEmpty) {
      return match.apply(seat, const DrawWall());
    }
    if (view.discard.isNotEmpty) {
      final trial = match.apply(seat, const DrawDiscard());
      final winning = _winningDiscard(trial, seat);
      if (winning != null) {
        return trial.apply(seat, DiscardTile(winning));
      }
    }
    if (view.wallCount == 0) {
      final trial = match.apply(seat, const DrawDiscard());
      return trial.apply(seat, DiscardTile(_chooseOkeyDiscard(trial, seat)));
    }
    final drawn = match.apply(seat, const DrawWall());
    return drawn.apply(seat, DiscardTile(_chooseOkeyDiscard(drawn, seat)));
  }
  return match.apply(seat, DiscardTile(_chooseOkeyDiscard(match, seat)));
}

int _chooseOkeyDiscard(OkeyMatch match, int seat) {
  return _winningDiscard(match, seat) ??
      (_highestLooseTile(match.hands[seat])?.id ?? match.hands[seat].first.id);
}

int? _winningDiscard(OkeyMatch match, int seat) {
  for (final tile in match.hands[seat]) {
    final rest = match.hands[seat].where((item) => item.id != tile.id);
    if (canFinishHand(rest.toList(), match.context)) {
      return tile.id;
    }
  }
  return null;
}

OkeyTile? _highestLooseTile(List<OkeyTile> hand) {
  final counts = <String, int>{};
  for (final tile in hand) {
    final key = '${tile.color}:${tile.number}:${tile.fakeJoker}';
    counts[key] = (counts[key] ?? 0) + 1;
  }
  OkeyTile? chosen;
  for (final tile in hand) {
    final key = '${tile.color}:${tile.number}:${tile.fakeJoker}';
    final loose = (counts[key] ?? 0) == 1;
    if (!loose) {
      continue;
    }
    if (chosen == null || tile.number > chosen.number) {
      chosen = tile;
    }
  }
  chosen ??= hand.reduce(
    (best, tile) => tile.number >= best.number ? tile : best,
  );
  return chosen;
}

Okey101Match playOkey101Bot(Okey101Match match) {
  final seat = match.turn;
  var current = match;
  if (!current.drawn) {
    if (current.wall.isEmpty) {
      return current.apply(seat, const DrawWall101());
    }
    current = current.apply(seat, const DrawWall101());
  }
  if (!current.opened[seat]) {
    final opening = findOpeningMelds(
      current.hands[seat],
      current.context,
      minimum: 101,
    );
    if (opening != null &&
        opening.fold<int>(0, (sum, meld) => sum + meld.length) <
            current.hands[seat].length) {
      current = current.apply(
        seat,
        OpenMelds(
          opening.map((meld) => meld.map((tile) => tile.id).toList()).toList(),
        ),
      );
      if (current.finished) {
        return current;
      }
    }
  }
  final pending = current.pendingDiscardId;
  if (pending != null &&
      current.hands[seat].any((tile) => tile.id == pending)) {
    for (var index = 0; index < current.melds[seat].length; index++) {
      try {
        final added = current.apply(seat, AddToOwnMeld(index, pending));
        current = added;
        break;
      } on RuleException {
        continue;
      }
    }
  }
  if (current.finished) {
    return current;
  }
  if (current.hands[seat].isEmpty) {
    return current;
  }
  final discard = _highestLooseTile(current.hands[seat])!;
  if (pending != null && discard.id == pending) {
    final other = current.hands[seat].firstWhere(
      (tile) => tile.id != pending,
      orElse: () => discard,
    );
    return current.apply(seat, DiscardTile101(other.id));
  }
  return current.apply(seat, DiscardTile101(discard.id));
}

BatakMatch playBatakBot(BatakMatch match) {
  final seat = match.turn;
  if (match.phase == BatakPhase.auction) {
    final bid = _batakBid(match.hands[seat]);
    if (match.legalBids().contains(bid)) {
      return match.apply(seat, BidAction(bid));
    }
    return match.apply(seat, const PassBid());
  }
  if (match.phase == BatakPhase.trump) {
    return match.apply(seat, ChooseTrump(_longestSuit(match.hands[seat])));
  }
  final legal = match.legalCards(seat);
  legal.sort();
  final card = _batakCard(match, legal);
  return match.apply(seat, PlayCard(card));
}

int _batakBid(List<BatakCard> hand) {
  final aces = hand.where((card) => card.rank == 14).length;
  final kings = hand.where((card) => card.rank == 13).length;
  return aces + kings >= 5 ? aces + kings : 0;
}

BatakSuit _longestSuit(List<BatakCard> hand) {
  var best = BatakSuit.spades;
  var count = -1;
  for (final suit in BatakSuit.values) {
    final suitCount = hand.where((card) => card.suit == suit).length;
    if (suitCount > count) {
      count = suitCount;
      best = suit;
    }
  }
  return best;
}

BatakCard _batakCard(BatakMatch match, List<BatakCard> legal) {
  if (match.trick.isEmpty) {
    return legal.first;
  }
  final winning = legal.where((card) {
    final trial = <BatakPlay>[...match.trick, BatakPlay(match.turn, card)];
    return _wouldWin(match, trial);
  }).toList();
  if (winning.isEmpty) {
    return legal.first;
  }
  winning.sort();
  return winning.first;
}

bool _wouldWin(BatakMatch match, List<BatakPlay> trick) {
  if (trick.length < 4) {
    return trick.last.card.rank ==
            trick.map((play) => play.card.rank).reduce(max) &&
        trick.last.card.suit == trick.first.card.suit;
  }
  return false;
}

TavlaMatch playTavlaBot(TavlaMatch match, Random random) {
  var current = match;
  if (current.dice.isEmpty) {
    current = current.roll(random.nextInt(6) + 1, random.nextInt(6) + 1);
  }
  final steps = current.legalSteps();
  if (steps.isEmpty) {
    return current.passStuck();
  }
  TavlaStep? best;
  var bestScore = -1 << 30;
  for (final step in steps) {
    final next = _peekTavla(current, step);
    final score =
        next.off[current.turn] * 100 +
        next.bar[1 - current.turn] * 25 -
        _pip(next, current.turn);
    if (score > bestScore) {
      bestScore = score;
      best = step;
    }
  }
  return current.apply(current.turn, best!);
}

TavlaMatch _peekTavla(TavlaMatch match, TavlaStep step) {
  try {
    return match.apply(match.turn, step);
  } on RuleException {
    return match;
  }
}

int _pip(TavlaMatch match, int seat) {
  var total = match.bar[seat] * 25;
  for (var index = 0; index < 24; index++) {
    final count = match.points[index];
    final owned = seat == 0 ? count > 0 : count < 0;
    if (!owned) {
      continue;
    }
    final distance = seat == 0 ? index + 1 : 24 - index;
    total += distance * count.abs();
  }
  return total;
}
