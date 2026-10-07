import 'package:latlong2/latlong.dart';

/// Province centers already used by the home map.
///
/// Names are matched after Turkish folding, so "İstanbul" and "istanbul"
/// resolve to the same point.
LatLng? turkeyCityCenter(String city) {
  return _centers[turkeyCityKey(city)];
}

String turkeyCityKey(String city) {
  return city
      .trim()
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');
}

const LatLng turkeyMapFallback = LatLng(39.0, 35.0);

const Map<String, LatLng> _centers = <String, LatLng>{
  'adana': LatLng(37.0, 35.3213),
  'adiyaman': LatLng(37.7648, 38.2786),
  'afyonkarahisar': LatLng(38.7507, 30.5567),
  'agri': LatLng(39.7191, 43.0503),
  'aksaray': LatLng(38.3687, 34.037),
  'amasya': LatLng(40.6499, 35.8353),
  'ankara': LatLng(39.9334, 32.8597),
  'antalya': LatLng(36.8969, 30.7133),
  'ardahan': LatLng(41.1105, 42.7022),
  'artvin': LatLng(41.1828, 41.8183),
  'aydin': LatLng(37.856, 27.8416),
  'balikesir': LatLng(39.6484, 27.8826),
  'bartin': LatLng(41.6344, 32.3375),
  'batman': LatLng(37.8812, 41.1351),
  'bayburt': LatLng(40.2552, 40.2249),
  'bilecik': LatLng(40.0567, 30.0665),
  'bingol': LatLng(38.8854, 40.4966),
  'bitlis': LatLng(38.3938, 42.1232),
  'bolu': LatLng(40.576, 31.5788),
  'burdur': LatLng(37.7203, 30.2908),
  'bursa': LatLng(40.1885, 29.061),
  'canakkale': LatLng(40.1553, 26.4142),
  'cankiri': LatLng(40.6013, 33.6134),
  'corum': LatLng(40.5506, 34.9556),
  'denizli': LatLng(37.7765, 29.0864),
  'diyarbakir': LatLng(37.9144, 40.2306),
  'duzce': LatLng(40.8438, 31.1565),
  'edirne': LatLng(41.6818, 26.5623),
  'elazig': LatLng(38.681, 39.2264),
  'erzincan': LatLng(39.75, 39.5),
  'erzurum': LatLng(39.9, 41.27),
  'eskisehir': LatLng(39.7767, 30.5206),
  'gaziantep': LatLng(37.0662, 37.3833),
  'giresun': LatLng(40.9128, 38.3895),
  'gumushane': LatLng(40.4386, 39.5086),
  'hakkâri': LatLng(37.5744, 43.7408),
  'hatay': LatLng(36.2023, 36.1613),
  'igdir': LatLng(39.888, 44.0048),
  'isparta': LatLng(37.7648, 30.5566),
  'istanbul': LatLng(41.0082, 28.9784),
  'izmir': LatLng(38.4237, 27.1428),
  'kahramanmaras': LatLng(37.5753, 36.9228),
  'karabuk': LatLng(41.2061, 32.6204),
  'karaman': LatLng(37.1759, 33.2287),
  'kars': LatLng(40.6013, 43.0975),
  'kastamonu': LatLng(41.3887, 33.7827),
  'kayseri': LatLng(38.7312, 35.4787),
  'kirikkale': LatLng(39.8468, 33.5153),
  'kirklareli': LatLng(41.7333, 27.2167),
  'kirsehir': LatLng(39.1425, 34.1709),
  'kilis': LatLng(36.7184, 37.1212),
  'kocaeli': LatLng(40.8533, 29.8815),
  'konya': LatLng(37.8667, 32.4833),
  'kutahya': LatLng(39.4167, 29.9833),
  'malatya': LatLng(38.3552, 38.3095),
  'manisa': LatLng(38.6191, 27.4289),
  'mardin': LatLng(37.3212, 40.7245),
  'mersin': LatLng(36.8, 34.6333),
  'mugla': LatLng(37.2153, 28.3636),
  'mus': LatLng(38.9462, 41.7539),
  'nevsehir': LatLng(38.6939, 34.6857),
  'nigde': LatLng(37.9667, 34.6833),
  'ordu': LatLng(40.9839, 37.8764),
  'osmaniye': LatLng(37.0742, 36.2478),
  'rize': LatLng(41.0201, 40.5234),
  'sakarya': LatLng(40.7569, 30.3781),
  'samsun': LatLng(41.2867, 36.33),
  'sanliurfa': LatLng(37.1674, 38.7955),
  'siirt': LatLng(37.9333, 41.95),
  'sinop': LatLng(42.0231, 35.1531),
  'sivas': LatLng(39.7477, 37.0179),
  'sirnak': LatLng(37.4187, 42.4918),
  'tekirdag': LatLng(40.9833, 27.5167),
  'tokat': LatLng(40.3167, 36.55),
  'trabzon': LatLng(41.0015, 39.7178),
  'tunceli': LatLng(39.1079, 39.5401),
  'usak': LatLng(38.6823, 29.4082),
  'van': LatLng(38.4891, 43.4089),
  'yalova': LatLng(40.65, 29.2667),
  'yozgat': LatLng(39.8181, 34.8147),
  'zonguldak': LatLng(41.4564, 31.7987),
};
