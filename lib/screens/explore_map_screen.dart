import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/event_service.dart';
import 'event_detail_screen.dart';

class ExploreMapScreen extends StatefulWidget {
  final String selectedCity;

  const ExploreMapScreen({
    super.key,
    this.selectedCity = '',
  });

  @override
  State<ExploreMapScreen> createState() => _ExploreMapScreenState();
}

class _ExploreMapScreenState extends State<ExploreMapScreen> {
  final MapController controller = MapController();

  Position? userPosition;
  double radiusKm = 0;
  String category = 'Tümü';
  bool locating = false;

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
      final serviceEnabled =
      await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showMessage('Telefonun konum servisi kapalı.');
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
        _showMessage(
          'Konum izni kalıcı olarak kapatılmış. '
              'Telefon ayarlarından izin verebilirsin.',
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
      });

      controller.move(
        LatLng(value.latitude, value.longitude),
        13,
      );
    } catch (_) {
      if (mounted) {
        _showMessage('Konum alınamadı.');
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
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Haritada Keşfet'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: locating ? null : _locate,
            icon: locating
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(Icons.my_location),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: EventService.getEvents(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Etkinlikler yüklenemedi.'),
            );
          }

          final allDocs = snapshot.data?.docs ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          final docs = allDocs
              .where(_hasValidCoordinates)
              .where(_matches)
              .toList();

          final center = userPosition == null
              ? _center(docs)
              : LatLng(
            userPosition!.latitude,
            userPosition!.longitude,
          );

          return Stack(
            children: [
              FlutterMap(
                mapController: controller,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 11.5,
                  minZoom: 4,
                  maxZoom: 19,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                    'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.dorduncu.app',
                    maxNativeZoom: 20,
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
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: docs.map((doc) {
                      final data = doc.data();
                      final point = _point(data);
                      final game =
                          data['oyun']?.toString() ?? '';

                      return Marker(
                        point: point,
                        width: 68,
                        height: 72,
                        child: GestureDetector(
                          onTap: () => _preview(doc.id, data),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: _color(game),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _emoji(game),
                                  style: const TextStyle(
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_drop_down,
                                color: _color(game),
                                size: 16,
                              ),
                            ],
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
                        height: 48,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          separatorBuilder: (_, _) =>
                          const SizedBox(width: 6),
                          itemBuilder: (_, index) {
                            final value = categories[index];

                            return ChoiceChip(
                              label: Text(value),
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
                      const SizedBox(height: 8),
                      Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [0, 3, 5, 10, 25].map((value) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                right: 6,
                              ),
                              child: ChoiceChip(
                                label: Text(
                                  value == 0
                                      ? 'Tüm şehir'
                                      : '$value km',
                                ),
                                selected:
                                radiusKm == value.toDouble(),
                                onSelected: (_) {
                                  setState(() {
                                    radiusKm =
                                        value.toDouble();
                                  });

                                  if (value > 0 &&
                                      userPosition == null) {
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
                    avatar: const Icon(
                      Icons.place,
                      size: 18,
                    ),
                    label: Text(
                      '${docs.length} etkinlik',
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _hasValidCoordinates(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final point = _point(doc.data());

    return point.latitude != 0 && point.longitude != 0;
  }

  bool _matches(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data();
    final game = data['oyun']?.toString() ?? '';

    final status = data['durum']?.toString().toLowerCase() ?? 'aktif';
    if (status != 'aktif') return false;

    final timestamp = data['tarih'];
    if (timestamp is! Timestamp || !timestamp.toDate().isAfter(DateTime.now())) {
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

  void _preview(
      String id,
      Map<String, dynamic> data,
      ) {
    final game = data['oyun']?.toString() ?? 'Etkinlik';
    final district = data['ilce']?.toString().trim() ?? '';
    final city = data['sehir']?.toString().trim() ?? '';
    final cityLine = [
      district,
      city,
    ].where((value) => value.isNotEmpty).join(', ');

    // Harita önizlemesinde yalnızca genel konum gösterilir.
    final locationText = cityLine;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              0,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _clean(game),
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (locationText.isNotEmpty)
                  Text(
                    '📍 $locationText',
                    textAlign: TextAlign.center,
                  ),
                if (locationText.isEmpty)
                  const Text(
                    'Konum bilgisi belirtilmedi',
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventDetailScreen(
                            eventId: id,
                            initialData: data,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'Etkinlik detayını aç',
                    ),
                  ),
                ),
              ],
            ),
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

  LatLng _center(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    final validPoints = docs
        .map((doc) => _point(doc.data()))
        .where(
          (point) =>
      point.latitude != 0 && point.longitude != 0,
    )
        .toList();

    if (validPoints.isEmpty) {
      return const LatLng(41.0082, 28.9784);
    }

    final latitudeAverage =
        validPoints.map((point) => point.latitude).reduce(
              (a, b) => a + b,
        ) /
            validPoints.length;

    final longitudeAverage =
        validPoints.map((point) => point.longitude).reduce(
              (a, b) => a + b,
        ) /
            validPoints.length;

    return LatLng(
      latitudeAverage,
      longitudeAverage,
    );
  }

  String _emoji(String value) {
    final trimmed = value.trim();

    return trimmed.isEmpty
        ? '🎯'
        : trimmed.split(' ').first;
  }

  String _clean(String value) {
    return value.replaceFirst(
      RegExp(r'^[^A-Za-zÇĞİÖŞÜçğıöşü0-9]+\s*'),
      '',
    );
  }

  Color _color(String value) {
    final normalized = value.toLowerCase();

    if (normalized.contains('futbol')) {
      return Colors.green;
    }

    if (normalized.contains('basket')) {
      return Colors.orange;
    }

    if (normalized.contains('tenis')) {
      return Colors.blue;
    }

    if (normalized.contains('batak')) {
      return const Color(0xff111827);
    }

    if (normalized.contains('voley')) {
      return Colors.purple;
    }

    return const Color(0xffFF9800);
  }
}
