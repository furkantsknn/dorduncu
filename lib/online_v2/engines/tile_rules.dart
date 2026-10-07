import 'dart:math';

class RuleException implements Exception {
  const RuleException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class OkeyTile {
  const OkeyTile({
    required this.id,
    required this.color,
    required this.number,
    required this.fakeJoker,
  });

  final int id;

  /// 0 red, 1 yellow, 2 blue, 3 black. Fake jokers use -1 until revealed.
  final int color;
  final int number;
  final bool fakeJoker;

  String get label {
    if (fakeJoker) {
      return 'SJ$id';
    }
    const colors = <String>['K', 'S', 'M', 'Y'];
    return '${colors[color]}$number#$id';
  }
}

class LogicTile {
  const LogicTile({
    required this.id,
    required this.color,
    required this.number,
    required this.wild,
  });

  final int id;
  final int? color;
  final int? number;
  final bool wild;
}

class TileContext {
  const TileContext({
    required this.indicator,
    required this.okeyColor,
    required this.okeyNumber,
  });

  final OkeyTile indicator;
  final int okeyColor;
  final int okeyNumber;

  int get indicatorColor => indicator.color;
  int get indicatorNumber => indicator.number;
}

List<OkeyTile> buildOkeyDeck() {
  final tiles = <OkeyTile>[];
  var id = 0;
  for (var copy = 0; copy < 2; copy++) {
    for (var color = 0; color < 4; color++) {
      for (var number = 1; number <= 13; number++) {
        tiles.add(
          OkeyTile(id: id++, color: color, number: number, fakeJoker: false),
        );
      }
    }
  }
  tiles.add(OkeyTile(id: id++, color: -1, number: 0, fakeJoker: true));
  tiles.add(OkeyTile(id: id, color: -1, number: 0, fakeJoker: true));
  return tiles;
}

List<OkeyTile> shuffledDeck(int seed) {
  final tiles = buildOkeyDeck();
  final random = Random(seed);
  for (var index = tiles.length - 1; index > 0; index--) {
    final swap = random.nextInt(index + 1);
    final tile = tiles[index];
    tiles[index] = tiles[swap];
    tiles[swap] = tile;
  }
  return tiles;
}

TileContext contextFromIndicator(OkeyTile indicator) {
  if (indicator.fakeJoker || indicator.number < 1) {
    throw const RuleException('bad_indicator', 'Gösterge sahte okey olamaz.');
  }
  final okeyNumber = indicator.number == 13 ? 1 : indicator.number + 1;
  return TileContext(
    indicator: indicator,
    okeyColor: indicator.color,
    okeyNumber: okeyNumber,
  );
}

LogicTile toLogic(OkeyTile tile, TileContext context) {
  if (tile.fakeJoker) {
    return LogicTile(
      id: tile.id,
      color: context.indicatorColor,
      number: context.indicatorNumber,
      wild: false,
    );
  }
  final wild =
      tile.color == context.okeyColor && tile.number == context.okeyNumber;
  return LogicTile(
    id: tile.id,
    color: wild ? null : tile.color,
    number: wild ? null : tile.number,
    wild: wild,
  );
}

int tilePenalty(OkeyTile tile, TileContext context) {
  final logic = toLogic(tile, context);
  if (logic.wild) {
    return context.okeyNumber;
  }
  return logic.number ?? 0;
}

bool canFinishHand(List<OkeyTile> tiles, TileContext context) {
  if (tiles.length != 14) {
    return false;
  }
  return _canPartition(tiles.map((tile) => toLogic(tile, context)).toList());
}

bool _canPartition(List<LogicTile> tiles) {
  final memo = <String, bool>{};

  bool search(List<LogicTile> current) {
    if (current.isEmpty) {
      return true;
    }
    final key = (current.map((tile) => tile.id).toList()..sort()).join(',');
    final cached = memo[key];
    if (cached != null) {
      return cached;
    }
    final anchorIndex = current.indexWhere((tile) => !tile.wild);
    final anchor = anchorIndex == -1 ? current.first : current[anchorIndex];
    if (anchor.wild) {
      memo[key] = false;
      return false;
    }
    for (final meld in _meldsAnchored(anchor, current)) {
      final used = meld.map((tile) => tile.id).toSet();
      final rest = current.where((tile) => !used.contains(tile.id)).toList();
      if (search(rest)) {
        memo[key] = true;
        return true;
      }
    }
    memo[key] = false;
    return false;
  }

  return search(tiles);
}

List<List<LogicTile>> _meldsAnchored(LogicTile anchor, List<LogicTile> tiles) {
  final melds = <List<LogicTile>>[];
  melds.addAll(_groupsAnchored(anchor, tiles));
  melds.addAll(_runsAnchored(anchor, tiles));
  return melds;
}

List<List<LogicTile>> _groupsAnchored(LogicTile anchor, List<LogicTile> tiles) {
  final number = anchor.number;
  final color = anchor.color;
  if (number == null || color == null) {
    return const <List<LogicTile>>[];
  }
  final companions = <LogicTile>[];
  final seen = <int>{color};
  for (final tile in tiles) {
    if (tile.wild || tile.id == anchor.id || tile.number != number) {
      continue;
    }
    final tileColor = tile.color;
    if (tileColor == null || seen.contains(tileColor)) {
      continue;
    }
    seen.add(tileColor);
    companions.add(tile);
  }
  final wilds = tiles.where((tile) => tile.wild).toList();
  final results = <List<LogicTile>>[];

  void walk(int index, List<LogicTile> picked) {
    final naturalCount = 1 + picked.length;
    for (var usedWilds = 0; usedWilds <= wilds.length; usedWilds++) {
      final size = naturalCount + usedWilds;
      if (size >= 3 && size <= 4) {
        results.add(<LogicTile>[anchor, ...picked, ...wilds.take(usedWilds)]);
      }
    }
    for (var next = index; next < companions.length; next++) {
      walk(next + 1, <LogicTile>[...picked, companions[next]]);
    }
  }

  walk(0, const <LogicTile>[]);
  return results;
}

List<List<LogicTile>> _runsAnchored(LogicTile anchor, List<LogicTile> tiles) {
  final color = anchor.color;
  final number = anchor.number;
  if (color == null || number == null) {
    return const <List<LogicTile>>[];
  }
  final sameColor = tiles.where((tile) {
    return !tile.wild && tile.color == color && tile.id != anchor.id;
  }).toList();
  final wilds = tiles.where((tile) => tile.wild).toList();
  final byNumber = <int, LogicTile>{};
  for (final tile in sameColor) {
    byNumber.putIfAbsent(tile.number!, () => tile);
  }
  final results = <List<LogicTile>>[];
  for (var length = 3; length <= 13; length++) {
    for (var start = 1; start <= 14 - length; start++) {
      final end = start + length - 1;
      if (number < start || number > end) {
        continue;
      }
      final picked = <LogicTile>[anchor];
      var wildsNeeded = 0;
      var possible = true;
      for (var value = start; value <= end; value++) {
        if (value == number) {
          continue;
        }
        final tile = byNumber[value];
        if (tile != null && !picked.any((item) => item.id == tile.id)) {
          picked.add(tile);
        } else {
          wildsNeeded += 1;
        }
      }
      if (!possible || wildsNeeded > wilds.length) {
        continue;
      }
      results.add(<LogicTile>[...picked, ...wilds.take(wildsNeeded)]);
    }
  }
  return results;
}

bool isSingleMeld(List<LogicTile> meld, TileContext context) {
  if (meld.length < 3 || meld.length > 13) {
    return false;
  }
  if (meldPoints(meld, context) <= 0) {
    return false;
  }
  final naturals = meld.where((tile) => !tile.wild).toList();
  final sameNumber = naturals.every(
    (tile) => tile.number == naturals.first.number,
  );
  if (!sameNumber) {
    return true;
  }
  return meld.length <= 4 &&
      naturals.map((tile) => tile.color).toSet().length == naturals.length;
}

int meldPoints(List<LogicTile> meld, TileContext context) {
  if (meld.isEmpty) {
    return 0;
  }
  final naturals = meld.where((tile) => !tile.wild).toList();
  if (naturals.isEmpty) {
    return 0;
  }
  final sameNumber = naturals.every(
    (tile) => tile.number == naturals.first.number,
  );
  if (sameNumber &&
      naturals.map((tile) => tile.color).toSet().length == naturals.length) {
    return (naturals.first.number ?? 0) * meld.length;
  }
  final color = naturals.first.color;
  final numbers = naturals.map((tile) => tile.number!).toList()..sort();
  if (naturals.any((tile) => tile.color != color)) {
    return 0;
  }
  var low = numbers.first;
  var high = numbers.last;
  final missing = (high - low + 1) - numbers.toSet().length;
  final wildCount = meld.where((tile) => tile.wild).length;
  if (missing > wildCount) {
    return 0;
  }
  var extra = wildCount - missing;
  while (extra > 0 && low > 1) {
    low -= 1;
    extra -= 1;
  }
  while (extra > 0 && high < 13) {
    high += 1;
    extra -= 1;
  }
  if (extra > 0) {
    return 0;
  }
  var total = 0;
  for (var value = low; value <= high; value++) {
    total += value;
  }
  return total;
}

List<List<LogicTile>>? findOpeningMelds(
  List<OkeyTile> hand,
  TileContext context, {
  required int minimum,
}) {
  final tiles = hand.map((tile) => toLogic(tile, context)).toList();
  List<List<LogicTile>>? found;

  bool search(List<LogicTile> rest, List<List<LogicTile>> chosen, int points) {
    if (points >= minimum && chosen.isNotEmpty) {
      found = chosen
          .map((meld) => List<LogicTile>.from(meld))
          .toList(growable: false);
      return true;
    }
    if (rest.length < 3) {
      return false;
    }
    final anchorIndex = rest.indexWhere((tile) => !tile.wild);
    if (anchorIndex == -1) {
      return false;
    }
    final anchor = rest[anchorIndex];
    for (final meld in _meldsAnchored(anchor, rest)) {
      final score = meldPoints(meld, context);
      if (score <= 0) {
        continue;
      }
      final used = meld.map((tile) => tile.id).toSet();
      final next = rest.where((tile) => !used.contains(tile.id)).toList();
      if (search(next, <List<LogicTile>>[...chosen, meld], points + score)) {
        return true;
      }
    }
    return false;
  }

  search(tiles, const <List<LogicTile>>[], 0);
  return found;
}

bool tilesExtendMeld(List<LogicTile> meld, LogicTile addition) {
  final combined = <LogicTile>[...meld, addition];
  if (combined.length > 13) {
    return false;
  }
  final naturals = combined.where((tile) => !tile.wild).toList();
  if (naturals.isEmpty) {
    return false;
  }
  final sameNumber = naturals.every(
    (tile) => tile.number == naturals.first.number,
  );
  if (sameNumber) {
    final colors = naturals.map((tile) => tile.color).toList();
    if (colors.toSet().length != colors.length) {
      return false;
    }
    return combined.length <= 4 && combined.length >= 3;
  }
  final color = naturals.first.color;
  if (naturals.any((tile) => tile.color != color)) {
    return false;
  }
  final numbers = naturals.map((tile) => tile.number!).toList()..sort();
  if (numbers.toSet().length != numbers.length) {
    return false;
  }
  final span = numbers.last - numbers.first + 1;
  final wilds = combined.where((tile) => tile.wild).length;
  if (span > numbers.length + wilds) {
    return false;
  }
  final covered = numbers.length + wilds;
  return covered >= 3 && numbers.last <= 13 && numbers.first >= 1;
}
