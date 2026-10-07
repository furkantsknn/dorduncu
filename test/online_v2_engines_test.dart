import 'dart:math';

import 'package:dorduncu/online_v2/bots/online_bots.dart';
import 'package:dorduncu/online_v2/engines/batak_match.dart';
import 'package:dorduncu/online_v2/engines/okey101_match.dart';
import 'package:dorduncu/online_v2/engines/okey_match.dart';
import 'package:dorduncu/online_v2/engines/tavla_match.dart';
import 'package:dorduncu/online_v2/engines/tile_rules.dart';
import 'package:dorduncu/online_v2/online_games_v2_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V2 bayrağı varsayılan kapalıdır', () {
    expect(kOnlineGamesV2Enabled, isFalse);
    expect(kOnlineGamesV2UseEmulator, isFalse);
  });

  test('klasik okey deste 106 taştır ve 13-1 sarması per değildir', () {
    expect(buildOkeyDeck(), hasLength(106));
    final context = contextFromIndicator(
      const OkeyTile(id: 900, color: 0, number: 13, fakeJoker: false),
    );
    expect(context.okeyNumber, 1);
    expect(
      isSingleMeld(const <LogicTile>[
        LogicTile(id: 1, color: 0, number: 13, wild: false),
        LogicTile(id: 2, color: 0, number: 1, wild: false),
        LogicTile(id: 3, color: 0, number: 2, wild: false),
      ], context),
      isFalse,
    );
    expect(canFinishHand(_finishedOkeyHand(), context), isTrue);
    final wrapped = List<OkeyTile>.from(_finishedOkeyHand());
    wrapped[0] = const OkeyTile(id: 1, color: 0, number: 13, fakeJoker: false);
    expect(canFinishHand(wrapped, context), isFalse);
  });

  test('okey sırası, çift hamle ve kazanma', () {
    final match = OkeyMatch.deal(7);
    expect(match.hands[0], hasLength(15));
    expect(match.hands[1], hasLength(14));
    expect(
      () => match.apply(1, DiscardTile(match.hands[1].first.id)),
      throwsA(
        isA<RuleException>().having(
          (RuleException error) => error.code,
          'code',
          'not_your_turn',
        ),
      ),
    );
    expect(
      () => match.apply(0, const DrawWall()),
      throwsA(
        isA<RuleException>().having(
          (RuleException error) => error.code,
          'code',
          'discard_first',
        ),
      ),
    );
    final once = match.apply(0, DiscardTile(match.hands[0].last.id));
    expect(once.turn == 0, isFalse);
    expect(
      () => once.apply(0, DiscardTile(once.hands[0].first.id)),
      throwsA(isA<RuleException>()),
    );

    final view = match.viewFor(1);
    final seatZeroIds = match.hands[0].map((tile) => tile.id).toSet();
    expect(view.hand.map((tile) => tile.id).any(seatZeroIds.contains), isFalse);

    var current = OkeyMatch.deal(3);
    var guard = 0;
    while (!current.finished && guard < 400) {
      current = playOkeyBot(current);
      guard += 1;
    }
    expect(current.finished, isTrue);
    if (current.winner != null) {
      expect(current.penalties[current.winner!], 0);
      expect(current.penalties.where((value) => value > 0), isNotEmpty);
    }
  });

  test('101 açma eşiği ve başkasının peri', () {
    final context = contextFromIndicator(
      const OkeyTile(id: 900, color: 3, number: 8, fakeJoker: false),
    );
    final hand = <OkeyTile>[
      const OkeyTile(id: 1, color: 0, number: 13, fakeJoker: false),
      const OkeyTile(id: 2, color: 1, number: 13, fakeJoker: false),
      const OkeyTile(id: 3, color: 2, number: 13, fakeJoker: false),
      const OkeyTile(id: 4, color: 0, number: 12, fakeJoker: false),
      const OkeyTile(id: 5, color: 1, number: 12, fakeJoker: false),
      const OkeyTile(id: 6, color: 2, number: 12, fakeJoker: false),
      const OkeyTile(id: 7, color: 0, number: 11, fakeJoker: false),
      const OkeyTile(id: 8, color: 1, number: 11, fakeJoker: false),
      const OkeyTile(id: 9, color: 2, number: 11, fakeJoker: false),
      const OkeyTile(id: 10, color: 0, number: 2, fakeJoker: false),
    ];
    final match = Okey101Match(
      hands: <List<OkeyTile>>[
        hand,
        const <OkeyTile>[],
        const <OkeyTile>[],
        const <OkeyTile>[],
      ],
      wall: const <OkeyTile>[],
      discard: const <OkeyTile>[],
      context: context,
      melds: List<List<List<OkeyTile>>>.generate(4, (_) => <List<OkeyTile>>[]),
      opened: const <bool>[false, false, false, false],
      turn: 0,
      drawn: true,
      pendingDiscardId: null,
      winner: null,
      penalties: const <int>[0, 0, 0, 0],
      finished: false,
    );
    expect(
      () => match.apply(
        0,
        const OpenMelds(<List<int>>[
          <int>[1, 2, 3],
        ]),
      ),
      throwsA(
        isA<RuleException>().having(
          (RuleException error) => error.code,
          'code',
          'open_short',
        ),
      ),
    );
    final opened = match.apply(
      0,
      const OpenMelds(<List<int>>[
        <int>[1, 2, 3],
        <int>[4, 5, 6],
        <int>[7, 8, 9],
      ]),
    );
    expect(opened.opened[0], isTrue);
    expect(opened.hands[0], hasLength(1));
    expect(
      () => opened.apply(0, const AddToOwnMeld(0, 10)),
      throwsA(isA<RuleException>()),
    );

    var live = Okey101Match.deal(11);
    var guard = 0;
    while (!live.finished && guard < 500) {
      live = playOkey101Bot(live);
      guard += 1;
    }
    expect(live.finished, isTrue);
  });

  test('batak ihalesi yükselir, renk uyulur ve el biter', () {
    final dealt = BatakMatch.deal(4);
    expect(
      () => dealt.apply(0, const BidAction(5)),
      throwsA(
        isA<RuleException>().having(
          (RuleException error) => error.code,
          'code',
          'not_your_turn',
        ),
      ),
    );
    final bid = dealt.apply(1, const BidAction(5));
    expect(
      () => bid.apply(2, const BidAction(5)),
      throwsA(
        isA<RuleException>().having(
          (RuleException error) => error.code,
          'code',
          'illegal_bid',
        ),
      ),
    );

    final playing = BatakMatch(
      hands: <List<BatakCard>>[
        <BatakCard>[const BatakCard(BatakSuit.hearts, 10)],
        <BatakCard>[
          const BatakCard(BatakSuit.hearts, 14),
          const BatakCard(BatakSuit.spades, 2),
        ],
        <BatakCard>[const BatakCard(BatakSuit.clubs, 3)],
        <BatakCard>[const BatakCard(BatakSuit.diamonds, 4)],
      ],
      dealer: 0,
      turn: 0,
      bids: const <int?>[7, null, null, null],
      passes: 3,
      declarer: 0,
      trump: BatakSuit.spades,
      trick: const <BatakPlay>[],
      trickLeader: 0,
      tricksWon: const <int>[0, 0, 0, 0],
      scores: const <int>[0, 0, 0, 0],
      phase: BatakPhase.play,
      finished: false,
    );
    final led = playing.apply(
      0,
      const PlayCard(BatakCard(BatakSuit.hearts, 10)),
    );
    expect(
      () => led.apply(1, const PlayCard(BatakCard(BatakSuit.spades, 2))),
      throwsA(
        isA<RuleException>().having(
          (RuleException error) => error.code,
          'code',
          'illegal_card',
        ),
      ),
    );
    expect(
      led.apply(1, const PlayCard(BatakCard(BatakSuit.hearts, 14))).trick,
      hasLength(2),
    );

    var live = BatakMatch.deal(9);
    var guard = 0;
    while (!live.finished && guard < 80) {
      live = playBatakBot(live);
      guard += 1;
    }
    expect(live.finished, isTrue);
    expect(live.tricksWon.fold<int>(0, (sum, value) => sum + value), 13);
  });

  test('tavla bar, erken çıkarma ve kazanma', () {
    final blocked = TavlaMatch(
      points: List<int>.filled(24, 0)..[23] = -2,
      bar: const <int>[1, 0],
      off: const <int>[0, 0],
      turn: 0,
      dice: const <int>[1],
      finished: false,
      winner: null,
      stake: 1,
    );
    expect(blocked.legalSteps(), isEmpty);
    expect(blocked.passStuck().turn, 1);
    expect(
      () => blocked.apply(
        1,
        blocked.passStuck() == blocked
            ? const TavlaStep(from: 0, die: 1, to: 1)
            : const TavlaStep(from: 24, die: 1, to: 23),
      ),
      throwsA(isA<RuleException>()),
    );

    final entry = TavlaMatch(
      points: List<int>.filled(24, 0)..[23] = -1,
      bar: const <int>[1, 0],
      off: const <int>[14, 1],
      turn: 0,
      dice: const <int>[1],
      finished: false,
      winner: null,
      stake: 1,
    );
    final entered = entry.apply(0, const TavlaStep(from: 24, die: 1, to: 23));
    expect(entered.bar[0], 0);
    expect(entered.bar[1], 1);

    final early = TavlaMatch(
      points: List<int>.filled(24, 0)..[10] = 1,
      bar: const <int>[0, 0],
      off: const <int>[14, 1],
      turn: 0,
      dice: const <int>[6],
      finished: false,
      winner: null,
      stake: 1,
    );
    expect(early.legalSteps().any((step) => step.to == -1), isFalse);

    final ready = TavlaMatch(
      points: List<int>.filled(24, 0)..[0] = 1,
      bar: const <int>[0, 0],
      off: const <int>[14, 1],
      turn: 0,
      dice: const <int>[1],
      finished: false,
      winner: null,
      stake: 1,
    );
    final won = ready.apply(0, const TavlaStep(from: 0, die: 1, to: -1));
    expect(won.finished, isTrue);
    expect(won.winner, 0);
    expect(won.stake, 1);

    var live = TavlaMatch.initial();
    final random = Random(5);
    var guard = 0;
    while (!live.finished && guard < 2500) {
      live = playTavlaBot(live, random);
      guard += 1;
    }
    expect(
      live.finished,
      isTrue,
      reason:
          'off=${live.off} bar=${live.bar} turn=${live.turn} '
          'dice=${live.dice} guard=$guard',
    );
    expect(live.winner, isNotNull);
    expect(live.stake, inInclusiveRange(1, 3));
  });
}

List<OkeyTile> _finishedOkeyHand() {
  return const <OkeyTile>[
    OkeyTile(id: 1, color: 0, number: 1, fakeJoker: false),
    OkeyTile(id: 2, color: 0, number: 2, fakeJoker: false),
    OkeyTile(id: 3, color: 0, number: 3, fakeJoker: false),
    OkeyTile(id: 4, color: 0, number: 4, fakeJoker: false),
    OkeyTile(id: 5, color: 0, number: 5, fakeJoker: false),
    OkeyTile(id: 6, color: 0, number: 6, fakeJoker: false),
    OkeyTile(id: 7, color: 0, number: 7, fakeJoker: false),
    OkeyTile(id: 8, color: 1, number: 7, fakeJoker: false),
    OkeyTile(id: 9, color: 2, number: 7, fakeJoker: false),
    OkeyTile(id: 10, color: 3, number: 7, fakeJoker: false),
    OkeyTile(id: 11, color: 1, number: 9, fakeJoker: false),
    OkeyTile(id: 12, color: 1, number: 10, fakeJoker: false),
    OkeyTile(id: 13, color: 1, number: 11, fakeJoker: false),
    OkeyTile(id: 14, color: 1, number: 12, fakeJoker: false),
  ];
}
