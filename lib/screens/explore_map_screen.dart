import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../home_v2/home_event_map.dart';
import '../home_v2/home_listed_event.dart';
import '../services/event_service.dart';
import '../utils/city_map_camera.dart';
import '../utils/turkey_city_centers.dart';
import 'event_detail_screen.dart';

String _mapText(
  BuildContext context, {
  required String tr,
  required String en,
  required String de,
}) {
  switch (Localizations.localeOf(context).languageCode.toLowerCase()) {
    case 'en':
      return en;
    case 'de':
      return de;
    default:
      return tr;
  }
}

class ExploreMapScreen extends StatefulWidget {
  final String selectedCity;

  const ExploreMapScreen({super.key, this.selectedCity = ''});

  @override
  State<ExploreMapScreen> createState() => _ExploreMapScreenState();
}

class _ExploreMapScreenState extends State<ExploreMapScreen> {
  final MapController controller = MapController();
  final CityMapCamera _camera = CityMapCamera();

  Position? userPosition;
  double radiusKm = 0;
  String category = 'Tümü';
  bool locating = false;
  bool _userLocated = false;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _events;

  @override
  void initState() {
    super.initState();
    _events = EventService.watchListedEvents(city: widget.selectedCity);
    _camera.choose(widget.selectedCity);
  }

  @override
  void didUpdateWidget(covariant ExploreMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (turkeyCityKey(oldWidget.selectedCity) ==
        turkeyCityKey(widget.selectedCity)) {
      return;
    }
    _userLocated = false;
    _moveCity(_camera.choose(widget.selectedCity));
  }

  void _onMapReady() {
    if (_userLocated) {
      _camera.ready = true;
      return;
    }
    _moveCity(_camera.controllerReady());
  }

  void _moveCity(CityCameraCommand? command) {
    if (command == null || _userLocated) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _userLocated ||
          command.generation != _camera.generation) {
        return;
      }
      try {
        controller.move(command.center, command.zoom);
        _camera.complete(command);
      } catch (_) {}
    });
  }

  static const List<String> categories = [
    'Tümü',
    '⚽ Futbol',
    '🏀 Basketbol',
    '🎾 Tenis',
    '♠️ Batak',
    '🏐 Voleybol',
  ];

  Future<void> _locate() async {
    if (locating) return;

    setState(() {
      locating = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!mounted) return;
      if (!serviceEnabled) {
        _showMessage(
          _mapText(
            context,
            tr: 'Telefonun konum servisi kapalı.',
            en: 'Location services are turned off.',
            de: 'Die Standortdienste sind deaktiviert.',
          ),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showMessage('Konum izni verilmedi.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        _showMessage(
          'Konum izni kalıcı olarak kapatılmış. ${_mapText(context, tr: 'Telefon ayarlarından izin verebilirsin.', en: 'You can grant permission from your phone settings.', de: 'Du kannst die Berechtigung in den Telefoneinstellungen erteilen.')}',
        );
        return;
      }

      final value = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        userPosition = value;
        _userLocated = true;
      });

      controller.move(LatLng(value.latitude, value.longitude), 13);
    } catch (_) {
      if (mounted) {
        _showMessage(
          _mapText(
            context,
            tr: 'Konum alınamadı.',
            en: 'Location could not be obtained.',
            de: 'Standort konnte nicht ermittelt werden.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          locating = false;
        });
      }
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _mapText(
            context,
            tr: 'Haritada Keşfet',
            en: 'Explore on Map',
            de: 'Auf Karte entdecken',
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: locating ? null : _locate,
            icon: locating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _events,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                _mapText(
                  context,
                  tr: 'Etkinlikler yüklenemedi.',
                  en: 'Events could not be loaded.',
                  de: 'Veranstaltungen konnten nicht geladen werden.',
                ),
              ),
            );
          }

          final allDocs =
              snapshot.data?.docs ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          final docs = allDocs
              .where(_hasValidCoordinates)
              .where(_matches)
              .toList();

          final LatLng opening =
              turkeyCityCenter(widget.selectedCity) ?? turkeyMapFallback;

          return Stack(
            children: [
              FlutterMap(
                mapController: controller,
                options: MapOptions(
                  initialCenter: opening,
                  initialZoom: _camera.zoom,
                  minZoom: 4,
                  maxZoom: 19,
                  keepAlive: true,
                  onMapReady: _onMapReady,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.dortapp.dort',
                    maxNativeZoom: 19,
                  ),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                  if (userPosition != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(
                            userPosition!.latitude,
                            userPosition!.longitude,
                          ),
                          width: 28,
                          height: 28,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              border: Border.all(color: Colors.white, width: 3),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: docs.map((doc) {
                      final HomeListedEvent event =
                          HomeListedEvent.fromDocument(doc);
                      final point = _point(doc.data());

                      return Marker(
                        point: point,
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        child: GestureDetector(
                          onTap: () => _preview(event),
                          child: HomeEventPhotoMarker(
                            assetPath: event.imageAsset,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              Positioned(
                left: 12,
                right: 12,
                top: 12,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 6),
                          itemBuilder: (_, index) {
                            final value = categories[index];

                            return ChoiceChip(
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                value == 'Tümü'
                                    ? _mapText(
                                        context,
                                        tr: 'Tümü',
                                        en: 'All',
                                        de: 'Alle',
                                      )
                                    : value,
                              ),
                              selected: category == value,
                              onSelected: (_) {
                                setState(() {
                                  category = value;
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [0, 3, 5, 10, 25].map((value) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                label: Text(
                                  value == 0
                                      ? _mapText(
                                          context,
                                          tr: 'Tüm şehir',
                                          en: 'Entire city',
                                          de: 'Ganze Stadt',
                                        )
                                      : '$value km',
                                ),
                                selected: radiusKm == value.toDouble(),
                                onSelected: (_) {
                                  setState(() {
                                    radiusKm = value.toDouble();
                                  });

                                  if (value > 0 && userPosition == null) {
                                    _locate();
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                bottom: 20,
                child: SafeArea(
                  top: false,
                  child: Chip(
                    avatar: const Icon(Icons.place, size: 18),
                    label: Text('${docs.length} etkinlik'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _hasValidCoordinates(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final point = _point(doc.data());

    return point.latitude != 0 && point.longitude != 0;
  }

  bool _matches(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final game = data['oyun']?.toString() ?? '';

    final status = data['durum']?.toString().toLowerCase() ?? 'aktif';
    if (status != 'aktif') return false;

    final timestamp = data['tarih'];
    if (timestamp is! Timestamp ||
        !timestamp.toDate().isAfter(DateTime.now())) {
      return false;
    }

    final needed = (data['oyuncuSayisi'] as num?)?.toInt() ?? 1;
    final participants = List<dynamic>.from(data['katilanlar'] ?? const []);
    final creatorUid = data['olusturanUid']?.toString() ?? '';
    final joinedWithoutCreator = participants
        .where((uid) => uid.toString() != creatorUid)
        .length;
    if (joinedWithoutCreator >= needed) return false;

    final selectedCity = _normalize(widget.selectedCity);
    final eventCity = _normalize(data['sehir']?.toString() ?? '');
    if (selectedCity.isNotEmpty && eventCity != selectedCity) return false;

    if (category != 'Tümü') {
      final selectedCategory = _normalize(_clean(category));
      final eventGame = _normalize(_clean(game));

      if (!eventGame.contains(selectedCategory)) return false;
    }

    if (radiusKm <= 0 || userPosition == null) return true;

    final point = _point(data);
    final meters = Geolocator.distanceBetween(
      userPosition!.latitude,
      userPosition!.longitude,
      point.latitude,
      point.longitude,
    );

    return meters <= radiusKm * 1000;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .trim();
  }

  void _preview(HomeListedEvent event) {
    showHomeEventPreview(
      context,
      event,
      onOpenDetail: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                EventDetailScreen(eventId: event.id, initialData: event.source),
          ),
        );
      },
    );
  }

  LatLng _point(Map<String, dynamic> data) {
    final double latitude =
        (data['approxLatitude'] as num?)?.toDouble() ??
        (data['latitude'] as num?)?.toDouble() ??
        0.0;
    final double longitude =
        (data['approxLongitude'] as num?)?.toDouble() ??
        (data['longitude'] as num?)?.toDouble() ??
        0.0;

    if (latitude == 0 || longitude == 0) {
      return const LatLng(0, 0);
    }

    return LatLng(latitude, longitude);
  }

  String _clean(String value) {
    return value.replaceFirst(RegExp(r'^[^A-Za-zÇĞİÖŞÜçğıöşü0-9]+\s*'), '');
  }
}
