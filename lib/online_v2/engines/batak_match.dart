import 'dart:math';

import 'tile_rules.dart';

/// One-deal auction Batak for four players.
///
/// Bids run from 5 to 13. A bid must beat the current bid.
/// If everyone passes, the dealer is forced to bid 5 and names trump.
/// Players must follow suit. The highest trump wins a trick, otherwise
/// the highest card of the lead suit. The declarer scores the bid when
/// the tricks are made and loses the bid when they are not. Each
/// defender scores one point per trick.
class BatakMatch {
  const BatakMatch({
    required this.hands,
    required this.dealer,
    required this.turn,
    required this.bids,
    required this.passes,
    required this.declarer,
    required this.trump,
    required this.trick,
    required this.trickLeader,
    required this.tricksWon,
    required this.scores,
    required this.phase,
    required this.finished,
  });

  final List<List<BatakCard>> hands;
  final int dealer;
  final int turn;
  final List<int?> bids;
  final int passes;
  final int? declarer;
  final BatakSuit? trump;
  final List<BatakPlay> trick;
  final int trickLeader;
  final List<int> tricksWon;
  final List<int> scores;
  final BatakPhase phase;
  final bool finished;

  factory BatakMatch.deal(int seed) {
    final deck = <BatakCard>[
      for (final suit in BatakSuit.values)
        for (var rank = 2; rank <= 14; rank++) BatakCard(suit, rank),
    ];
    final random = Random(seed);
    for (var index = deck.length - 1; index > 0; index--) {
      final swap = random.nextInt(index + 1);
      final card = deck[index];
      deck[index] = deck[swap];
      deck[swap] = card;
    }
    final hands = List<List<BatakCard>>.generate(4, (_) => <BatakCard>[]);
    for (var index = 0; index < deck.length; index++) {
      hands[index % 4].add(deck[index]);
    }
    for (final hand in hands) {
      hand.sort();
    }
    return BatakMatch(
      hands: hands,
      dealer: 0,
      turn: 1,
      bids: const <int?>[null, null, null, null],
      passes: 0,
      declarer: null,
      trump: null,
      trick: const <BatakPlay>[],
      trickLeader: 1,
      tricksWon: const <int>[0, 0, 0, 0],
      scores: const <int>[0, 0, 0, 0],
      phase: BatakPhase.auction,
      finished: false,
    );
  }

  BatakMatch apply(int seat, BatakAction action) {
    if (finished) {
      throw const RuleException('finished', 'Oyun bitti.');
    }
    if (seat != turn) {
      throw const RuleException('not_your_turn', 'Sıra sende değil.');
    }
    if (action is BidAction) {
      return _bid(action.tricks);
    }
    if (action is PassBid) {
      return _pass();
    }
    if (action is ChooseTrump) {
      return _trump(action.suit);
    }
    if (action is PlayCard) {
      return _play(action.card);
    }
    throw const RuleException('illegal_move', 'Bu hamle yok.');
  }

  List<int> legalBids() {
    if (phase != BatakPhase.auction) {
      return const <int>[];
    }
    final current = bids.whereType<int>().fold<int>(4, (maxBid, bid) {
      return bid > maxBid ? bid : maxBid;
    });
    return <int>[for (var bid = current + 1; bid <= 13; bid++) bid];
  }

  List<BatakCard> legalCards(int seat) {
    if (phase != BatakPhase.play || seat != turn) {
      return const <BatakCard>[];
    }
    final hand = hands[seat];
    if (trick.isEmpty) {
      return List<BatakCard>.from(hand);
    }
    final lead = trick.first.card.suit;
    final followed = hand.where((card) => card.suit == lead).toList();
    if (followed.isNotEmpty) {
      return followed;
    }
    return List<BatakCard>.from(hand);
  }

  BatakMatch _bid(int tricks) {
    if (phase != BatakPhase.auction || !legalBids().contains(tricks)) {
      throw const RuleException('illegal_bid', 'Bu ihale geçersiz.');
    }
    final nextBids = List<int?>.from(bids);
    nextBids[turn] = tricks;
    return _copy(
      bids: nextBids,
      declarer: turn,
      passes: 0,
      turn: (turn + 1) % 4,
    );
  }

  BatakMatch _pass() {
    if (phase != BatakPhase.auction) {
      throw const RuleException('illegal_bid', 'Şimdi pas geçilemez.');
    }
    final nextPasses = passes + 1;
    final biddingClosed = declarer != null && nextPasses >= 3;
    final everyonePassed = declarer == null && nextPasses >= 4;
    if (everyonePassed) {
      final forced = List<int?>.from(bids);
      forced[dealer] = 5;
      return _copy(
        bids: forced,
        declarer: dealer,
        passes: nextPasses,
        turn: dealer,
        phase: BatakPhase.trump,
      );
    }
    if (biddingClosed) {
      return _copy(
        passes: nextPasses,
        turn: declarer!,
        phase: BatakPhase.trump,
      );
    }
    return _copy(passes: nextPasses, turn: (turn + 1) % 4);
  }

  BatakMatch _trump(BatakSuit suit) {
    if (phase != BatakPhase.trump || turn != declarer) {
      throw const RuleException('illegal_move', 'Kozu ihale sahibi seçer.');
    }
    return _copy(
      trump: suit,
      phase: BatakPhase.play,
      turn: (dealer + 1) % 4,
      trickLeader: (dealer + 1) % 4,
    );
  }

  BatakMatch _play(BatakCard card) {
    final legal = legalCards(turn);
    if (!legal.contains(card)) {
      throw const RuleException('illegal_card', 'Bu kağıt şimdi oynanamaz.');
    }
    final hands = this.hands.map(List<BatakCard>.from).toList();
    hands[turn].remove(card);
    final trick = <BatakPlay>[...this.trick, BatakPlay(turn, card)];
    if (trick.length < 4) {
      return _copy(hands: hands, trick: trick, turn: (turn + 1) % 4);
    }
    final winner = _trickWinner(trick);
    final won = List<int>.from(tricksWon);
    won[winner] += 1;
    final done = won.fold<int>(0, (sum, value) => sum + value) == 13;
    if (!done) {
      return _copy(
        hands: hands,
        trick: const <BatakPlay>[],
        tricksWon: won,
        turn: winner,
        trickLeader: winner,
      );
    }
    return _copy(
      hands: hands,
      trick: const <BatakPlay>[],
      tricksWon: won,
      scores: _score(won),
      finished: true,
      phase: BatakPhase.done,
    );
  }

  int _trickWinner(List<BatakPlay> trick) {
    final lead = trick.first.card.suit;
    var winner = trick.first;
    for (final play in trick.skip(1)) {
      final card = play.card;
      final current = winner.card;
      final cardTrump = card.suit == trump;
      final currentTrump = current.suit == trump;
      if (cardTrump && !currentTrump) {
        winner = play;
      } else if (cardTrump == currentTrump && card.suit == current.suit) {
        if (card.rank > current.rank) {
          winner = play;
        }
      } else if (!cardTrump && !currentTrump && card.suit == lead) {
        if (current.suit != lead || card.rank > current.rank) {
          winner = play;
        }
      }
    }
    return winner.seat;
  }

  List<int> _score(List<int> won) {
    final maker = declarer!;
    final made = won[maker] >= (bids[maker] ?? 0);
    return List<int>.generate(4, (seat) {
      if (seat == maker) {
        return made ? bids[maker]! : -bids[maker]!;
      }
      return won[seat];
    });
  }
}

enum BatakPhase { auction, trump, play, done }

enum BatakSuit { clubs, diamonds, hearts, spades }

class BatakCard implements Comparable<BatakCard> {
  const BatakCard(this.suit, this.rank);

  final BatakSuit suit;
  final int rank;

  @override
  int compareTo(BatakCard other) {
    final suitOrder = suit.index.compareTo(other.suit.index);
    if (suitOrder != 0) {
      return suitOrder;
    }
    return rank.compareTo(other.rank);
  }

  @override
  bool operator ==(Object other) {
    return other is BatakCard && other.suit == suit && other.rank == rank;
  }

  @override
  int get hashCode => Object.hash(suit, rank);
}

class BatakPlay {
  const BatakPlay(this.seat, this.card);

  final int seat;
  final BatakCard card;
}

sealed class BatakAction {
  const BatakAction();
}

class BidAction extends BatakAction {
  const BidAction(this.tricks);

  final int tricks;
}

class PassBid extends BatakAction {
  const PassBid();
}

class ChooseTrump extends BatakAction {
  const ChooseTrump(this.suit);

  final BatakSuit suit;
}

class PlayCard extends BatakAction {
  const PlayCard(this.card);

  final BatakCard card;
}

extension on BatakMatch {
  BatakMatch _copy({
    List<List<BatakCard>>? hands,
    int? turn,
    List<int?>? bids,
    int? passes,
    int? declarer,
    BatakSuit? trump,
    List<BatakPlay>? trick,
    int? trickLeader,
    List<int>? tricksWon,
    List<int>? scores,
    BatakPhase? phase,
    bool? finished,
  }) {
    return BatakMatch(
      hands: hands ?? this.hands,
      dealer: dealer,
      turn: turn ?? this.turn,
      bids: bids ?? this.bids,
      passes: passes ?? this.passes,
      declarer: declarer ?? this.declarer,
      trump: trump ?? this.trump,
      trick: trick ?? this.trick,
      trickLeader: trickLeader ?? this.trickLeader,
      tricksWon: tricksWon ?? this.tricksWon,
      scores: scores ?? this.scores,
      phase: phase ?? this.phase,
      finished: finished ?? this.finished,
    );
  }
}
