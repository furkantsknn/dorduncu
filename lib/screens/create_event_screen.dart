import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../l10n/app_localizations.dart';
import '../services/user_service.dart';
import '../utils/game_catalog.dart';
import 'map_location_picker_screen.dart';

import '../models/event_model.dart';
import '../services/event_service.dart';


String _createEventCategoryName(
    BuildContext context,
    GameCategoryDefinition category,
    ) {
  final languageCode =
  Localizations.localeOf(context).languageCode.toLowerCase();

  switch (category.id) {
    case 'masa_oyunlari':
      return languageCode == 'en'
          ? 'Board Games'
          : languageCode == 'de'
          ? 'Brettspiele'
          : 'Masa Oyunları';
    case 'konsol_oyunlari':
      return languageCode == 'en'
          ? 'Console Games'
          : languageCode == 'de'
          ? 'Konsolenspiele'
          : 'Konsol Oyunları';
    case 'raket_sporlari':
      return languageCode == 'en'
          ? 'Racket Sports'
          : languageCode == 'de'
          ? 'Schlägersportarten'
          : 'Raket Sporları';
    case 'takim_sporlari':
      return languageCode == 'en'
          ? 'Team Sports'
          : languageCode == 'de'
          ? 'Mannschaftssportarten'
          : 'Takım Sporları';
    case 'premium_sporlar':
      return languageCode == 'en'
          ? 'Premium Sports'
          : languageCode == 'de'
          ? 'Premium-Sportarten'
          : 'Premium Sporlar';
    default:
      return category.name;
  }
}

String _createEventGameName(
    BuildContext context,
    GameDefinition game,
    ) {
  final languageCode =
  Localizations.localeOf(context).languageCode.toLowerCase();

  if (languageCode == 'tr') {
    return game.name;
  }

  switch (game.id) {
    case 'tavla':
      return 'Backgammon';
    case 'satranc':
      return languageCode == 'de' ? 'Schach' : 'Chess';
    case 'bric':
      return 'Bridge';
    case 'tombala':
      return 'Bingo';
    case 'tenis':
      return 'Tennis';
    case 'masa_tenisi':
      return languageCode == 'de' ? 'Tischtennis' : 'Table Tennis';
    case 'futbol':
      return languageCode == 'de' ? 'Fußball' : 'Football';
    case 'basketbol':
      return 'Basketball';
    case 'voleybol':
      return 'Volleyball';
    case 'hentbol':
      return 'Handball';
    case 'yelken':
      return languageCode == 'de' ? 'Segeln' : 'Sailing';
    case 'kurek':
      return languageCode == 'de' ? 'Rudern' : 'Rowing';
    case 'binicilik':
      return languageCode == 'de' ? 'Reiten' : 'Horse Riding';
    case 'kayak':
      return languageCode == 'de' ? 'Skifahren' : 'Skiing';
    default:
      return game.name;
  }
}

String _createEventGameDisplayName(
    BuildContext context,
    GameDefinition game,
    ) {
  return '${game.emoji} ${_createEventGameName(context, game)}';
}

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final districtController = TextEditingController();
  final neighborhoodController = TextEditingController();
  final descriptionController = TextEditingController();
  final neighborhoodFocusNode = FocusNode();

  Map<String, dynamic> profile = <String, dynamic>{};
  String activeCity = '';
  int? selectedDistrictId;
  String selectedCategoryId = GameCatalog.categories.first.id;
  String selectedGameId = GameCatalog.categories.first.games.first.id;
  int selectedPlayerCount = 1;
  String selectedMemberPreference = 'Herkes';
  DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay selectedStartTime = const TimeOfDay(hour: 20, minute: 30);
  TimeOfDay selectedEndTime = const TimeOfDay(hour: 21, minute: 30);
  double latitude = 0;
  double longitude = 0;
  String _coordinateAddressKey = '';
  bool busy = false;
  bool profileLoading = true;
  bool districtLoading = false;
  bool neighborhoodLoading = false;
  List<_District> districts = const [];
  List<String> neighborhoodSuggestions = const [];
  Timer? _neighborhoodTimer;

  static const memberPreferences = <String>[
    'Herkes',
    'Normal Üye',
    'Plus Üye',
  ];

  static const playerOptions = <int>[1, 2, 3, 4];

  static const provinceIds = <String, int>{
    'Adana': 1,
    'Adıyaman': 2,
    'Afyonkarahisar': 3,
    'Ağrı': 4,
    'Amasya': 5,
    'Ankara': 6,
    'Antalya': 7,
    'Artvin': 8,
    'Aydın': 9,
    'Balıkesir': 10,
    'Bilecik': 11,
    'Bingöl': 12,
    'Bitlis': 13,
    'Bolu': 14,
    'Burdur': 15,
    'Bursa': 16,
    'Çanakkale': 17,
    'Çankırı': 18,
    'Çorum': 19,
    'Denizli': 20,
    'Diyarbakır': 21,
    'Edirne': 22,
    'Elazığ': 23,
    'Erzincan': 24,
    'Erzurum': 25,
    'Eskişehir': 26,
    'Gaziantep': 27,
    'Giresun': 28,
    'Gümüşhane': 29,
    'Hakkâri': 30,
    'Hatay': 31,
    'Isparta': 32,
    'Mersin': 33,
    'İstanbul': 34,
    'İzmir': 35,
    'Kars': 36,
    'Kastamonu': 37,
    'Kayseri': 38,
    'Kırklareli': 39,
    'Kırşehir': 40,
    'Kocaeli': 41,
    'Konya': 42,
    'Kütahya': 43,
    'Malatya': 44,
    'Manisa': 45,
    'Kahramanmaraş': 46,
    'Mardin': 47,
    'Muğla': 48,
    'Muş': 49,
    'Nevşehir': 50,
    'Niğde': 51,
    'Ordu': 52,
    'Rize': 53,
    'Sakarya': 54,
    'Samsun': 55,
    'Siirt': 56,
    'Sinop': 57,
    'Sivas': 58,
    'Tekirdağ': 59,
    'Tokat': 60,
    'Trabzon': 61,
    'Tunceli': 62,
    'Şanlıurfa': 63,
    'Uşak': 64,
    'Van': 65,
    'Yozgat': 66,
    'Zonguldak': 67,
    'Aksaray': 68,
    'Bayburt': 69,
    'Karaman': 70,
    'Kırıkkale': 71,
    'Batman': 72,
    'Şırnak': 73,
    'Bartın': 74,
    'Ardahan': 75,
    'Iğdır': 76,
    'Yalova': 77,
    'Karabük': 78,
    'Kilis': 79,
    'Osmaniye': 80,
    'Düzce': 81,
  };

  @override
  void initState() {
    super.initState();
    _loadProfile();
    neighborhoodController.addListener(_onNeighborhoodChanged);
  }

  @override
  void dispose() {
    _neighborhoodTimer?.cancel();
    neighborhoodController.removeListener(_onNeighborhoodChanged);
    districtController.dispose();
    neighborhoodController.dispose();
    descriptionController.dispose();
    neighborhoodFocusNode.dispose();
    super.dispose();
  }

  bool get isPlus => profile['plus'] == true;

  int get playerCount => selectedPlayerCount;

  GameCategoryDefinition get selectedCategory =>
      GameCatalog.categoryById(selectedCategoryId) ??
          GameCatalog.categories.first;

  GameDefinition get selectedGame {
    return GameCatalog.gameById(selectedGameId) ??
        selectedCategory.games.first;
  }

  DateTime get startAt => DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
    selectedStartTime.hour,
    selectedStartTime.minute,
  );

  DateTime get endAt => DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
    selectedEndTime.hour,
    selectedEndTime.minute,
  );

  int get durationMinutes => endAt.difference(startAt).inMinutes;

  double get durationFactor =>
      GameCatalog.durationFactorForMinutes(durationMinutes);

  double get totalPrice => GameCatalog.calculateTotalPrice(
    gameId: selectedGameId,
    playerCount: playerCount,
    durationMinutes: durationMinutes,
  );

  Future<void> _loadProfile() async {
    try {
      final data = await UserService.getProfileData();

      if (!mounted) return;

      profile = data;

      final selected = data['aktifSehir']?.toString().trim() ?? '';
      final profileCity = data['sehir']?.toString().trim() ?? '';

      activeCity = selected.isNotEmpty ? selected : profileCity;

      if (activeCity.isEmpty) {
        activeCity = 'İstanbul';
      }

      await _loadDistricts();
    } catch (error) {
      if (!mounted) return;

      _message(
        AppLocalizations.of(context)!.profileInfoLoadFailed('$error'),
      );
    } finally {
      if (mounted) {
        setState(() => profileLoading = false);
      }
    }
  }

  Future<void> _loadDistricts() async {
    final provinceId = provinceIds[activeCity];
    if (provinceId == null || districtLoading) return;

    setState(() => districtLoading = true);
    try {
      final uri = Uri.parse(
        'https://api.turkiyeapi.dev/v2/provinces/$provinceId/districts?limit=100',
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('İlçe servisi yanıt vermedi.');
      }
      final decoded = jsonDecode(response.body);
      final rawData = decoded is Map<String, dynamic> ? decoded['data'] : null;
      if (rawData is! List) throw Exception('İlçe listesi okunamadı.');

      final parsed = rawData
          .whereType<Map<String, dynamic>>()
          .map(_District.fromMap)
          .where((item) => item.name.isNotEmpty)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      if (!mounted) return;
      setState(() => districts = parsed);
    } catch (error) {
      if (mounted) {
        _message(AppLocalizations.of(context)!.districtsLoadFailed);
      }
    } finally {
      if (mounted) setState(() => districtLoading = false);
    }
  }

  void _onNeighborhoodChanged() {
    _neighborhoodTimer?.cancel();
    final query = neighborhoodController.text.trim();
    if (query.length < 2 || districtController.text.trim().isEmpty) {
      if (mounted && neighborhoodSuggestions.isNotEmpty) {
        setState(() => neighborhoodSuggestions = const []);
      }
      return;
    }
    _neighborhoodTimer = Timer(
      const Duration(milliseconds: 500),
          () => _searchNeighborhoods(query),
    );
  }

  Future<void> _searchNeighborhoods(String query) async {
    if (neighborhoodLoading) return;
    setState(() => neighborhoodLoading = true);
    try {
      final fullQuery =
          '$query, ${districtController.text.trim()}, $activeCity, Türkiye';
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': fullQuery,
        'format': 'jsonv2',
        'limit': '8',
        'countrycodes': 'tr',
        'accept-language': 'tr',
        'addressdetails': '1',
      });
      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'Dorduncu/1.0 (address autocomplete)',
        },
      );
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return;

      final suggestions = <String>{};
      for (final raw in decoded.whereType<Map<String, dynamic>>()) {
        final addressRaw = raw['address'];
        if (addressRaw is! Map) continue;
        final address = Map<String, dynamic>.from(addressRaw);
        final candidate = _firstValue(address, [
          'neighbourhood',
          'suburb',
          'quarter',
          'village',
          'road',
          'pedestrian',
        ]);
        if (candidate.isNotEmpty) suggestions.add(candidate);
      }

      if (!mounted || neighborhoodController.text.trim() != query) return;
      setState(() => neighborhoodSuggestions = suggestions.toList());
    } catch (_) {
      // Öneri servisi geçici olarak çalışmazsa kullanıcı yazmaya devam edebilir.
    } finally {
      if (mounted) setState(() => neighborhoodLoading = false);
    }
  }

  String _firstValue(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  Future<void> _chooseDistrict() async {
    if (districtLoading) return;
    if (districts.isEmpty) await _loadDistricts();
    if (!mounted) return;

    final searchController = TextEditingController();
    final selected = await showModalBottomSheet<_District>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final query = _normalize(searchController.text);
            final visible = districts
                .where((item) => _normalize(item.name).contains(query))
                .toList();
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * .72,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        onChanged: (_) => setSheetState(() {}),
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context)!.searchDistrictsInCity(activeCity),
                          prefixIcon: const Icon(Icons.search),
                        ),
                      ),
                    ),
                    Expanded(
                      child: visible.isEmpty
                          ? Center(child: Text(AppLocalizations.of(context)!.districtNotFound))
                          : ListView.separated(
                        itemCount: visible.length,
                        separatorBuilder: (_, _) =>
                        const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final item = visible[index];
                          return ListTile(
                            leading: const Icon(Icons.apartment_outlined),
                            title: Text(item.name),
                            trailing: districtController.text == item.name
                                ? const Icon(Icons.check_circle)
                                : null,
                            onTap: () => Navigator.pop(sheetContext, item),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    // Bottom sheet kapanış animasyonu sırasında TextField hâlâ bu
    // controller'a erişebildiği için hemen dispose etmek kırmızı ekrana
    // neden olabiliyor. Animasyon bittikten sonra güvenle temizle.
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      searchController.dispose();
    });

    if (selected != null && mounted) {
      setState(() {
        selectedDistrictId = selected.id;
        districtController.text = selected.name;
        neighborhoodController.clear();
        neighborhoodSuggestions = const [];
        latitude = 0;
        longitude = 0;
        _coordinateAddressKey = '';
      });
      neighborhoodFocusNode.requestFocus();
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final first = DateTime(today.year, today.month, today.day);
    final last = isPlus
        ? first.add(const Duration(days: 365))
        : first.add(const Duration(days: 1));
    var initial = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (value != null && mounted) setState(() => selectedDate = value);
  }

  Future<void> _pickStartTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: selectedStartTime,
    );
    if (value == null || !mounted) return;

    setState(() {
      selectedStartTime = value;
      final suggestedEnd = _minutesOfDay(value) + 60;
      if (_minutesOfDay(selectedEndTime) <= _minutesOfDay(value)) {
        selectedEndTime = _timeFromMinutes(suggestedEnd);
      }
    });
  }

  Future<void> _pickEndTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: selectedEndTime,
    );
    if (value != null && mounted) {
      setState(() => selectedEndTime = value);
    }
  }

  int _minutesOfDay(TimeOfDay value) => value.hour * 60 + value.minute;

  TimeOfDay _timeFromMinutes(int minutes) {
    final safeMinutes = minutes.clamp(0, (24 * 60) - 1);
    return TimeOfDay(
      hour: safeMinutes ~/ 60,
      minute: safeMinutes % 60,
    );
  }


  String _playerOptionText(int count) {
    final languageCode = Localizations.localeOf(context).languageCode;

    switch (languageCode) {
      case 'en':
        return count == 1 ? '$count Player' : '$count Players';
      case 'de':
        return '$count Spieler';
      default:
        return '$count Oyuncu';
    }
  }

  String _memberPreferenceText(String preference) {
    final String languageCode =
    Localizations.localeOf(context).languageCode.toLowerCase();

    switch (preference) {
      case 'Normal Üye':
        switch (languageCode) {
          case 'en':
            return 'Normal Member';
          case 'de':
            return 'Normales Mitglied';
          default:
            return 'Normal Üye';
        }
      case 'Plus Üye':
        switch (languageCode) {
          case 'en':
            return 'Plus Member';
          case 'de':
            return 'Plus-Mitglied';
          default:
            return 'Plus Üye';
        }
      case 'Herkes':
      default:
        switch (languageCode) {
          case 'en':
            return 'Everyone';
          case 'de':
            return 'Alle';
          default:
            return 'Herkes';
        }
    }
  }

  String _durationText() {
    if (durationMinutes <= 0) return '-';
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    if (minutes == 0) return AppLocalizations.of(context)!.durationHours(hours);
    if (hours == 0) return AppLocalizations.of(context)!.durationMinutesOnly(minutes);
    return AppLocalizations.of(context)!.durationHoursMinutes(hours, minutes);
  }

  String _money(double value) {
    final digits = value.round().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[index]);
    }
    return AppLocalizations.of(context)!.currencyAmount(buffer.toString());
  }

  Future<void> _pickFromMap({bool currentLocation = false}) async {
    setState(() => busy = true);
    try {
      double initialLat = latitude;
      double initialLng = longitude;
      if (currentLocation) {
        if (!await Geolocator.isLocationServiceEnabled()) {
          if (!mounted) return;

          _message(AppLocalizations.of(context)!.enableLocationServices);
          return;
        }
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (!mounted) return;

          _message(AppLocalizations.of(context)!.locationPermissionDenied);
          return;
        }
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        initialLat = position.latitude;
        initialLng = position.longitude;
      }

      if (!mounted) return;
      final result = await Navigator.push<PickedLocation>(
        context,
        MaterialPageRoute(
          builder: (_) => MapLocationPickerScreen(
            initialLatitude: initialLat,
            initialLongitude: initialLng,
            activeCity: activeCity,
            initialSearchText: [
              neighborhoodController.text.trim(),
              districtController.text.trim(),
              activeCity,
            ].where((e) => e.isNotEmpty).join(', '),
          ),
        ),
      );

      if (result != null && mounted) {
        final mapCity = _normalize(result.city);
        final selectedCity = _normalize(activeCity);
        if (mapCity.isNotEmpty &&
            selectedCity.isNotEmpty &&
            !mapCity.contains(selectedCity) &&
            !selectedCity.contains(mapCity)) {
          _message(
            AppLocalizations.of(context)!.locationOutsideActiveCity(activeCity),
          );
          return;
        }

        _District? matchingDistrict;
        for (final item in districts) {
          final a = _normalize(item.name);
          final b = _normalize(result.district);
          if (b.isNotEmpty &&
              (a == b || a.contains(b) || b.contains(a))) {
            matchingDistrict = item;
            break;
          }
        }

        setState(() {
          latitude = result.latitude;
          longitude = result.longitude;
          if (result.district.trim().isNotEmpty) {
            districtController.text = matchingDistrict?.name ?? result.district;
            selectedDistrictId = matchingDistrict?.id;
          }
          if (result.neighborhood.trim().isNotEmpty) {
            neighborhoodController.text = result.neighborhood;
          }
          neighborhoodSuggestions = const [];
          _coordinateAddressKey = _currentAddressKey();
        });

        if (districtController.text.trim().isEmpty ||
            neighborhoodController.text.trim().isEmpty) {
          _message(
            AppLocalizations.of(context)!.locationSelectedCompleteAddress,
          );
        }
      }
    } catch (error) {
      if (!mounted) return;

      _message(AppLocalizations.of(context)!.mapCouldNotOpen('$error'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('\u0307', '')
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .trim();


  String _currentAddressKey() => _normalize([
    neighborhoodController.text.trim(),
    districtController.text.trim(),
    activeCity,
  ].where((part) => part.isNotEmpty).join('|'));

  bool _addressMatches(String candidate, String expected) {
    final a = _normalize(candidate);
    final b = _normalize(expected);
    if (a.isEmpty || b.isEmpty) return false;
    return a == b || a.contains(b) || b.contains(a);
  }

  Future<bool> _resolveTypedAddressCoordinates() async {
    final neighborhood = neighborhoodController.text.trim();
    final district = districtController.text.trim();
    final addressKey = _currentAddressKey();

    if (latitude != 0 &&
        longitude != 0 &&
        _coordinateAddressKey == addressKey) {
      return true;
    }

    final query = '$neighborhood, $district, $activeCity, Türkiye';
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'jsonv2',
        'limit': '10',
        'countrycodes': 'tr',
        'accept-language': 'tr',
        'addressdetails': '1',
      });
      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'Dorduncu/1.0 (event address geocoding)',
        },
      );
      if (response.statusCode != 200) return false;

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return false;

      Map<String, dynamic>? best;
      Map<String, dynamic>? cityFallback;
      for (final raw in decoded.whereType<Map<String, dynamic>>()) {
        final lat = double.tryParse(raw['lat']?.toString() ?? '') ?? 0;
        final lon = double.tryParse(raw['lon']?.toString() ?? '') ?? 0;
        if (lat == 0 || lon == 0) continue;

        final addressRaw = raw['address'];
        final address = addressRaw is Map
            ? Map<String, dynamic>.from(addressRaw)
            : const <String, dynamic>{};
        final resultCity = _firstValue(address, [
          'province',
          'state',
          'city',
        ]);
        final resultDistrict = _firstValue(address, [
          'city_district',
          'town',
          'municipality',
          'district',
          'county',
        ]);
        final cityMatches = _addressMatches(resultCity, activeCity) ||
            _normalize(raw['display_name']?.toString() ?? '')
                .contains(_normalize(activeCity));
        if (!cityMatches) continue;

        cityFallback ??= raw;
        if (_addressMatches(resultDistrict, district) ||
            _normalize(raw['display_name']?.toString() ?? '')
                .contains(_normalize(district))) {
          best = raw;
          break;
        }
      }

      final selected = best ?? cityFallback;
      if (selected == null) return false;
      final resolvedLat =
          double.tryParse(selected['lat']?.toString() ?? '') ?? 0;
      final resolvedLon =
          double.tryParse(selected['lon']?.toString() ?? '') ?? 0;
      if (resolvedLat == 0 || resolvedLon == 0) return false;

      latitude = resolvedLat;
      longitude = resolvedLon;
      _coordinateAddressKey = addressKey;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _publish() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (startAt.isBefore(DateTime.now())) {
      _message(AppLocalizations.of(context)!.cannotSelectPastDateTime);
      return;
    }
    if (durationMinutes < GameCatalog.minimumDurationMinutes) {
      _message(AppLocalizations.of(context)!.eventDurationMinOneHour);
      return;
    }
    if (durationMinutes > GameCatalog.maximumDurationMinutes) {
      _message(AppLocalizations.of(context)!.eventDurationMaxSixHours);
      return;
    }
    if (durationMinutes % GameCatalog.durationStepMinutes != 0) {
      _message(AppLocalizations.of(context)!.eventDurationThirtyMinuteSteps);
      return;
    }
    if (!isPlus && playerCount > 1) {
      _message(AppLocalizations.of(context)!.plusRequiredForMultiplePlayers);
      return;
    }

    final now = DateTime.now();
    final normalLastDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    final selectedDay = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    if (!isPlus && selectedDay.isAfter(normalLastDay)) {
      _message(AppLocalizations.of(context)!.normalMembersTomorrowOnly);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _message(AppLocalizations.of(context)!.sessionNotFoundPleaseLogin);
      return;
    }

    setState(() => busy = true);
    try {
      final coordinatesReady = await _resolveTypedAddressCoordinates();

      if (!mounted) return;

      if (!coordinatesReady) {
        _message(
          AppLocalizations.of(context)!.addressNotFoundOnMap,
        );
        return;
      }

      final latestProfile = await UserService.getProfileData();

      final event = EventModel(
        id: '',
        game: selectedGame.displayName,
        categoryId: selectedCategory.id,
        categoryName: selectedCategory.name,
        gameId: selectedGame.id,
        gameName: selectedGame.name,
        playerCount: playerCount,
        playerCountText: '$playerCount Oyuncu',
        memberPreference: selectedMemberPreference,
        description: descriptionController.text.trim(),
        city: activeCity,
        district: districtController.text.trim(),
        neighborhood: neighborhoodController.text.trim(),
        address:
        '${neighborhoodController.text.trim()}, ${districtController.text.trim()}, $activeCity',
        latitude: latitude,
        longitude: longitude,
        eventDate: startAt,
        startAt: startAt,
        endAt: endAt,
        creatorId: user.uid,
        creatorProfileName:
        latestProfile['profilAdi']?.toString() ?? '',
        creatorProfilePhoto:
        latestProfile['profilFotografi']?.toString() ?? '',
        creatorPlus: latestProfile['plus'] == true,
        creatorVerified:
        latestProfile['verified'] == true ||
            latestProfile['verificationStatus'] == 'approved',
        participantIds: [user.uid],
        chatMemberIds: [user.uid],
        selectedPlayerIds: const [],
        favoriteCount: 0,
        status: 'aktif',
        createdAt: DateTime.now(),
        paymentRequired: true,
        paymentStatus: 'notCreated',
        paymentId: '',
        basePricePerPlayer: selectedCategory.basePricePerPlayer,
        durationFactor: durationFactor,
        customerTotal: totalPrice,
        playerGrossEarning: 0,
        platformShare: 0,
        pricingVersion: 'v2',
        durationMinutes: durationMinutes,
      );

      await EventService().createEvent(event);

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } on FirebaseException catch (error) {
      _message(
        AppLocalizations.of(context)!.eventCreateFailedWithCode(error.code, error.message ?? ''),
      );
    } catch (error) {
      _message(AppLocalizations.of(context)!.eventCreateFailed('$error'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.createEvent),
        centerTitle: true,
      ),
      body: profileLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
          children: [
            _title(AppLocalizations.of(context)!.eventInformation),
            DropdownButtonFormField<String>(
              initialValue: selectedCategoryId,
              isExpanded: true,
              items: GameCatalog.categories
                  .map(
                    (category) => DropdownMenuItem<String>(
                  value: category.id,
                  child: Text(
                    '${category.emoji} '
                        '${_createEventCategoryName(context, category)}',
                  ),
                ),
              )
                  .toList(),
              onChanged: busy
                  ? null
                  : (value) {
                if (value == null) return;
                final category = GameCatalog.categoryById(value);
                if (category == null || category.games.isEmpty) return;
                setState(() {
                  selectedCategoryId = category.id;
                  selectedGameId = category.games.first.id;
                });
              },
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.category),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedGameId,
              isExpanded: true,
              items: selectedCategory.games
                  .map(
                    (game) => DropdownMenuItem<String>(
                  value: game.id,
                  child: Text(_createEventGameDisplayName(context, game)),
                ),
              )
                  .toList(),
              onChanged: busy
                  ? null
                  : (value) {
                if (value != null) {
                  setState(() => selectedGameId = value);
                }
              },
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.gameOrSport),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: selectedPlayerCount,
              isExpanded: true,
              items: playerOptions
                  .map(
                    (playerOption) => DropdownMenuItem<int>(
                  value: playerOption,
                  child: Text(_playerOptionText(playerOption)),
                ),
              )
                  .toList(),
              onChanged: busy
                  ? null
                  : (value) {
                if (value == null) return;
                if (!isPlus && value != 1) {
                  _message(
                    AppLocalizations.of(context)!
                        .plusRequiredForMultiplePlayers,
                  );
                  return;
                }
                setState(() => selectedPlayerCount = value);
              },
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.searchedPlayer,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedMemberPreference,
              isExpanded: true,
              items: memberPreferences
                  .map(
                    (preference) => DropdownMenuItem<String>(
                  value: preference,
                  child: Text(_memberPreferenceText(preference)),
                ),
              )
                  .toList(),
              onChanged: busy
                  ? null
                  : (value) => setState(
                    () => selectedMemberPreference =
                    value ?? selectedMemberPreference,
              ),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.preferredMemberType,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                isPlus
                    ? AppLocalizations.of(context)!.plusMemberBenefits
                    : AppLocalizations.of(context)!.normalMemberLimits,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy ? null : _pickDate,
              icon: const Icon(Icons.calendar_month),
              label: Text(
                '${selectedDate.day}.${selectedDate.month}.${selectedDate.year}',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : _pickStartTime,
                    icon: const Icon(Icons.play_circle_outline),
                    label: Text(
                      AppLocalizations.of(context)!.startTimeLabel(selectedStartTime.format(context)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : _pickEndTime,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(
                      AppLocalizations.of(context)!.endTimeLabel(selectedEndTime.format(context)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPriceSummary(),
            const SizedBox(height: 24),
            _title(AppLocalizations.of(context)!.locationInformation),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_city_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.activeCity,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          activeCity,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.lock_outline, size: 19),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: districtController,
              readOnly: true,
              onTap: busy ? null : _chooseDistrict,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.district,
                hintText: districtLoading
                    ? AppLocalizations.of(context)!.districtsLoading
                    : AppLocalizations.of(context)!.selectFromCityDistricts(activeCity),
                prefixIcon: const Icon(Icons.apartment_outlined),
                suffixIcon: districtLoading
                    ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child:
                    CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
                    : const Icon(Icons.keyboard_arrow_down_rounded),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? AppLocalizations.of(context)!.mustSelectDistrict
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: neighborhoodController,
              focusNode: neighborhoodFocusNode,
              enabled: districtController.text.trim().isNotEmpty,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.neighborhoodStreet,
                hintText: districtController.text.trim().isEmpty
                    ? AppLocalizations.of(context)!.selectDistrictFirst
                    : AppLocalizations.of(context)!.startTypingNeighborhoodHint,
                prefixIcon: const Icon(Icons.signpost_outlined),
                suffixIcon: neighborhoodLoading
                    ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child:
                    CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
                    : null,
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? AppLocalizations.of(context)!.neighborhoodRequired
                  : null,
            ),
            if (neighborhoodSuggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: neighborhoodSuggestions
                      .map(
                        (suggestion) => ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.location_on_outlined,
                      ),
                      title: Text(suggestion),
                      onTap: () {
                        neighborhoodController.text = suggestion;
                        neighborhoodFocusNode.unfocus();
                        setState(
                              () => neighborhoodSuggestions = const [],
                        );
                      },
                    ),
                  )
                      .toList(),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => _pickFromMap(currentLocation: true),
                    icon: const Icon(Icons.my_location),
                    label: Text(AppLocalizations.of(context)!.myLocation),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : _pickFromMap,
                    icon: const Icon(Icons.map_outlined),
                    label: Text(AppLocalizations.of(context)!.searchOnMap),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              latitude == 0 || longitude == 0
                  ? AppLocalizations.of(context)!.mapSelectionOptional
                  : AppLocalizations.of(context)!.meetingPointSelected,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            _title(AppLocalizations.of(context)!.descriptionSection),
            TextFormField(
              controller: descriptionController,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.eventDetails,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: busy ? null : _publish,
              icon: busy
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.publish_rounded),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Text(AppLocalizations.of(context)!.publishEvent),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildPriceSummary() {
    final validDuration = durationMinutes >= GameCatalog.minimumDurationMinutes &&
        durationMinutes <= GameCatalog.maximumDurationMinutes;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.livePriceSummary,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          _summaryRow(AppLocalizations.of(context)!.category, selectedCategory.name),
          _summaryRow(AppLocalizations.of(context)!.gameOrSport, selectedGame.name),
          _summaryRow(AppLocalizations.of(context)!.searchedPlayer, '$playerCount'),
          _summaryRow(AppLocalizations.of(context)!.duration, _durationText()),
          _summaryRow(
            AppLocalizations.of(context)!.durationFactor,
            validDuration ? 'x${durationFactor.toStringAsFixed(2)}' : '-',
          ),
          _summaryRow(
            AppLocalizations.of(context)!.basePricePerPlayer,
            _money(selectedCategory.basePricePerPlayer),
          ),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.totalFee,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                validDuration ? _money(totalPrice) : '-',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          if (!validDuration) ...[
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.durationRangeHint),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(fontWeight: FontWeight.w900),
    ),
  );
}

class _District {
  final int id;
  final String name;

  const _District({required this.id, required this.name});

  factory _District.fromMap(Map<String, dynamic> map) {
    return _District(
      id: int.tryParse(map['id']?.toString() ?? '') ?? 0,
      name: map['name']?.toString().trim() ?? '',
    );
  }
}