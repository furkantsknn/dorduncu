import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../services/language_controller.dart';

class PickedLocation {
  final double latitude;
  final double longitude;
  final String displayName;
  final String city;
  final String district;
  final String neighborhood;

  const PickedLocation(
      this.latitude,
      this.longitude, {
        this.displayName = '',
        this.city = '',
        this.district = '',
        this.neighborhood = '',
      });
}

class MapLocationPickerScreen extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final String initialSearchText;
  final String activeCity;

  const MapLocationPickerScreen({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    this.initialSearchText = '',
    this.activeCity = '',
  });

  @override
  State<MapLocationPickerScreen> createState() =>
      _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  late LatLng center;
  bool moving = false;
  bool searching = false;
  bool resolving = false;
  String selectedDisplayName = '';
  _AddressParts selectedAddress = const _AddressParts();
  List<_SearchResult> results = const [];

  @override
  void initState() {
    super.initState();
    center = LatLng(
      widget.initialLatitude == 0 ? 41.0082 : widget.initialLatitude,
      widget.initialLongitude == 0 ? 28.9784 : widget.initialLongitude,
    );
    _searchController.text = widget.initialSearchText;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    var query = _searchController.text.trim();
    if (query.length < 3 || searching) return;

    if (widget.activeCity.trim().isNotEmpty &&
        !query.toLowerCase().contains(widget.activeCity.toLowerCase())) {
      query = '$query, ${widget.activeCity}, Türkiye';
    }

    FocusScope.of(context).unfocus();
    setState(() {
      searching = true;
      results = const [];
    });

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'jsonv2',
        'limit': '8',
        'countrycodes': 'tr',
        'accept-language': 'tr',
        'addressdetails': '1',
      });

      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'Dorduncu/1.0 (location search)',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(_text.searchServiceUnavailable);
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return;

      final parsed = decoded
          .whereType<Map<String, dynamic>>()
          .map(_SearchResult.fromMap)
          .where((item) => item.latitude != 0 && item.longitude != 0)
          .where((item) {
        final active = _normalize(widget.activeCity);
        if (active.isEmpty) return true;
        return _normalize(item.address.city) == active ||
            _normalize(item.displayName).contains(active);
      })
          .toList();

      if (!mounted) return;
      setState(() => results = parsed);

      if (parsed.isEmpty) {
        _message(_text.noResultsFoundInSelectedCity);
      }
    } catch (_) {
      if (mounted) {
        _message(_text.locationSearchFailed);
      }
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  void _selectResult(_SearchResult result) {
    final point = LatLng(result.latitude, result.longitude);
    setState(() {
      center = point;
      selectedDisplayName = result.displayName;
      selectedAddress = result.address;
      results = const [];
      moving = false;
    });
    _mapController.move(point, 17);
    FocusScope.of(context).unfocus();
  }

  Future<void> _confirm() async {
    if (moving || resolving) return;

    var address = selectedAddress;
    var displayName = selectedDisplayName;

    if (address.district.isEmpty || address.neighborhood.isEmpty) {
      setState(() => resolving = true);
      try {
        final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
          'lat': center.latitude.toString(),
          'lon': center.longitude.toString(),
          'format': 'jsonv2',
          'accept-language': 'tr',
          'addressdetails': '1',
          'zoom': '18',
        });
        final response = await http.get(
          uri,
          headers: const {
            'User-Agent': 'Dorduncu/1.0 (reverse geocoding)',
          },
        );
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            address = _AddressParts.fromMap(
              decoded['address'] is Map
                  ? Map<String, dynamic>.from(decoded['address'] as Map)
                  : const <String, dynamic>{},
            );
            displayName = decoded['display_name']?.toString() ?? displayName;
          }
        }
      } catch (_) {
        // Koordinat yine de döndürülür; formda kullanıcı eksik alanı seçebilir.
      } finally {
        if (mounted) setState(() => resolving = false);
      }
    }

    if (!mounted) return;
    Navigator.pop(
      context,
      PickedLocation(
        center.latitude,
        center.longitude,
        displayName: displayName,
        city: address.city,
        district: address.district,
        neighborhood: address.neighborhood,
      ),
    );
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .trim();

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  _MapLocationText get _text =>
      _MapLocationText(LanguageController.language.value);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageController.language,
      builder: (context, language, _) {
        final text = _MapLocationText(language);
        return Scaffold(
          appBar: AppBar(
            title: Text(text.selectMeetingPoint),
            centerTitle: true,
          ),
          body: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 16,
                  minZoom: 5,
                  maxZoom: 19,
                  onPositionChanged: (position, hasGesture) {
                    center = position.center;
                    if (hasGesture) {
                      selectedDisplayName = '';
                      selectedAddress = const _AddressParts();
                      if (!moving) setState(() => moving = true);
                    }
                  },
                  onMapEvent: (event) {
                    if (event is MapEventMoveEnd && moving) {
                      setState(() => moving = false);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.dorduncu',
                  ),
                  RichAttributionWidget(
                    attributions: const [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
              Positioned(
                left: 14,
                right: 14,
                top: 12,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      Material(
                        elevation: 5,
                        borderRadius: BorderRadius.circular(18),
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _search(),
                          decoration: InputDecoration(
                            hintText: widget.activeCity.isEmpty
                                ? text.searchStreetPlaceAddress
                                : text.searchStreetOrPlaceInCity(widget.activeCity),
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: searching
                                ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                                : IconButton(
                              onPressed: _search,
                              icon: const Icon(Icons.arrow_forward_rounded),
                            ),
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      if (results.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          constraints: const BoxConstraints(maxHeight: 300),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 14),
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: results.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final item = results[index];
                              return ListTile(
                                leading: const Icon(Icons.location_on_outlined),
                                title: Text(
                                  item.displayName,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => _selectResult(item),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              IgnorePointer(
                child: Center(
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.only(bottom: moving ? 65 : 44),
                    child: const Icon(
                      Icons.location_pin,
                      size: 64,
                      color: Color(0xffFF9800),
                      shadows: [Shadow(blurRadius: 12, color: Colors.black38)],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 20,
                child: SafeArea(
                  top: false,
                  child: FilledButton.icon(
                    onPressed: moving || resolving ? null : _confirm,
                    icon: resolving
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.check_circle_outline),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: Text(
                        moving
                            ? text.determiningLocation
                            : resolving
                            ? text.retrievingAddress
                            : text.selectThisLocation,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MapLocationText {
  const _MapLocationText(this.language);

  final AppLanguage language;

  String value(String tr, String en, String de) {
    switch (language) {
      case AppLanguage.turkish:
        return tr;
      case AppLanguage.english:
        return en;
      case AppLanguage.german:
        return de;
    }
  }

  String get searchServiceUnavailable => value(
    'Arama servisi yanıt vermedi.',
    'The search service did not respond.',
    'Der Suchdienst hat nicht geantwortet.',
  );

  String get noResultsFoundInSelectedCity => value(
    'Seçili şehirde sonuç bulunamadı. İlçe, sokak veya mekan adıyla tekrar dene.',
    'No results were found in the selected city. Try again with a district, street, or place name.',
    'In der ausgewählten Stadt wurden keine Ergebnisse gefunden. Versuche es erneut mit einem Bezirks-, Straßen- oder Ortsnamen.',
  );

  String get locationSearchFailed => value(
    'Konum aranamadı. İnternet bağlantını kontrol et.',
    'The location could not be searched. Check your internet connection.',
    'Der Standort konnte nicht gesucht werden. Prüfe deine Internetverbindung.',
  );

  String get selectMeetingPoint => value(
    'Buluşma noktasını seç',
    'Select meeting point',
    'Treffpunkt auswählen',
  );

  String get searchStreetPlaceAddress => value(
    'Sokak, mekan, park veya adres ara',
    'Search for a street, place, park, or address',
    'Straße, Ort, Park oder Adresse suchen',
  );

  String searchStreetOrPlaceInCity(String city) => value(
    '$city içinde sokak veya mekan ara',
    'Search for a street or place in $city',
    'Straße oder Ort in $city suchen',
  );

  String get determiningLocation => value(
    'Konum belirleniyor...',
    'Determining location...',
    'Standort wird bestimmt...',
  );

  String get retrievingAddress => value(
    'Adres bilgisi alınıyor...',
    'Retrieving address...',
    'Adressdaten werden abgerufen...',
  );

  String get selectThisLocation => value(
    'Bu konumu seç',
    'Select this location',
    'Diesen Standort auswählen',
  );
}

class _SearchResult {
  final double latitude;
  final double longitude;
  final String displayName;
  final _AddressParts address;

  const _SearchResult({
    required this.latitude,
    required this.longitude,
    required this.displayName,
    required this.address,
  });

  factory _SearchResult.fromMap(Map<String, dynamic> map) {
    final rawAddress = map['address'];
    return _SearchResult(
      latitude: double.tryParse(map['lat']?.toString() ?? '') ?? 0,
      longitude: double.tryParse(map['lon']?.toString() ?? '') ?? 0,
      displayName: map['display_name']?.toString() ?? '',
      address: _AddressParts.fromMap(
        rawAddress is Map
            ? Map<String, dynamic>.from(rawAddress)
            : const <String, dynamic>{},
      ),
    );
  }
}

class _AddressParts {
  final String city;
  final String district;
  final String neighborhood;

  const _AddressParts({
    this.city = '',
    this.district = '',
    this.neighborhood = '',
  });

  factory _AddressParts.fromMap(Map<String, dynamic> map) {
    String first(List<String> keys) {
      for (final key in keys) {
        final value = map[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    return _AddressParts(
      city: first(['province', 'state', 'city']),
      district: first([
        'city_district',
        'town',
        'municipality',
        'district',
        'county',
      ]),
      neighborhood: first([
        'neighbourhood',
        'suburb',
        'quarter',
        'village',
        'road',
        'pedestrian',
      ]),
    );
  }
}
