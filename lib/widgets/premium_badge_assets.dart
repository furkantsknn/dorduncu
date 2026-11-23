/// Onaylanan premium rozet PNG'leri. Eşleme yalnızca exact game id ile yapılır.
const Map<String, String> premiumBadgeAssets = <String, String>{
  'okey': 'assets/images/badges/premium_v1/okey.png',
  'okey_101': 'assets/images/badges/premium_v1/okey_101.png',
  'batak': 'assets/images/badges/premium_v1/batak.png',
  'tavla': 'assets/images/badges/premium_v1/tavla.png',
  'paintball': 'assets/images/badges/premium_v1/paintball.png',
  'satranc': 'assets/images/badges/premium_v1/satranc.png',
  'bric': 'assets/images/badges/premium_v1/bric.png',
  'king': 'assets/images/badges/premium_v1/king.png',
  'monopoly': 'assets/images/badges/premium_v1/monopoly.png',
  'uno': 'assets/images/badges/premium_v1/uno.png',
  'jenga': 'assets/images/badges/premium_v1/jenga.png',
  'scrabble': 'assets/images/badges/premium_v1/scrabble.png',
  'tombala': 'assets/images/badges/premium_v1/tombala.png',
  'ea_fc': 'assets/images/badges/premium_v1/ea_fc.png',
  'efootball': 'assets/images/badges/premium_v1/efootball.png',
  'tekken': 'assets/images/badges/premium_v1/tekken.png',
  'tenis': 'assets/images/badges/premium_v1/tenis.png',
  'masa_tenisi': 'assets/images/badges/premium_v1/masa_tenisi.png',
  'badminton': 'assets/images/badges/premium_v1/badminton.png',
  'squash': 'assets/images/badges/premium_v1/squash.png',
  'pickleball': 'assets/images/badges/premium_v1/pickleball.png',
  'futbol': 'assets/images/badges/premium_v1/futbol.png',
  'basketbol': 'assets/images/badges/premium_v1/basketbol.png',
  'voleybol': 'assets/images/badges/premium_v1/voleybol.png',
  'hentbol': 'assets/images/badges/premium_v1/hentbol.png',
  'golf': 'assets/images/badges/premium_v1/golf.png',
  'yelken': 'assets/images/badges/premium_v1/yelken.png',
  'kurek': 'assets/images/badges/premium_v1/kurek.png',
  'binicilik': 'assets/images/badges/premium_v1/binicilik.png',
  'kayak': 'assets/images/badges/premium_v1/kayak.png',
  'snowboard': 'assets/images/badges/premium_v1/snowboard.png',
};

String? premiumBadgeAsset(String gameId) => premiumBadgeAssets[gameId];

/// Kaynak PNG’de opak rozetin kapladığı en uzun kenar oranı.
/// Ölçüm her iki pikselde, alfa 12 eşiğiyle alındı; 0.02 pay kenar tırtığını korur.
const Map<String, double> premiumBadgeOpaqueFraction = <String, double>{
  'okey': 0.808,
  'okey_101': 0.795,
  'batak': 0.819,
  'tavla': 0.795,
  'paintball': 0.9,
};

double premiumBadgeDrawScale(String gameId) {
  final double? fraction = premiumBadgeOpaqueFraction[gameId];
  if (fraction == null || fraction <= 0 || fraction > 1) {
    return 1;
  }
  return 1 / fraction;
}
