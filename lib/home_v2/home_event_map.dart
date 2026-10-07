import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/language_controller.dart';
import '../utils/city_map_camera.dart';
import '../utils/turkey_city_centers.dart';
import 'home_listed_event.dart';

class HomeEventMap extends StatefulWidget {
  const HomeEventMap({
    required this.city,
    required this.events,
    required this.onEventTap,
    super.key,
  });

  final String city;
  final List<HomeListedEvent> events;
  final ValueChanged<HomeListedEvent> onEventTap;

  @override
  State<HomeEventMap> createState() => _HomeEventMapState();
}

class _HomeEventMapState extends State<HomeEventMap> {
  final MapController _mapController = MapController();
  final CityMapCamera _camera = CityMapCamera();

  List<HomeListedEvent> get _points {
    return widget.events
        .where((HomeListedEvent event) => event.hasPublicPoint)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _camera.choose(widget.city);
  }

  @override
  void didUpdateWidget(covariant HomeEventMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (turkeyCityKey(oldWidget.city) == turkeyCityKey(widget.city)) {
      return;
    }
    _move(_camera.choose(widget.city));
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _onMapReady() {
    _move(_camera.controllerReady());
  }

  void _move(CityCameraCommand? command) {
    if (command == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || command.generation != _camera.generation) {
        return;
      }
      try {
        _mapController.move(command.center, command.zoom);
        _camera.complete(command);
      } catch (_) {
        // The controller attaches in onMapReady. The pending city stays.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<HomeListedEvent> points = _points;

    return Container(
      height: 286,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(30),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: turkeyCityCenter(widget.city) ?? turkeyMapFallback,
          initialZoom: _camera.zoom,
          minZoom: 4,
          maxZoom: 18,
          keepAlive: true,
          onMapReady: _onMapReady,
        ),
        children: <Widget>[
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.dortapp.dort',
            maxNativeZoom: 20,
          ),
          MarkerLayer(
            markers: <Marker>[
              for (final HomeListedEvent event in points)
                Marker(
                  point: LatLng(event.latitude, event.longitude),
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onTap: () => widget.onEventTap(event),
                    child: HomeEventPhotoMarker(assetPath: event.imageAsset),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class HomeEventPhotoMarker extends StatelessWidget {
  const HomeEventPhotoMarker({required this.assetPath, super.key});

  final String? assetPath;

  @override
  Widget build(BuildContext context) {
    final String? path = assetPath;

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xffFF9800), width: 2),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: path == null
            ? const ColoredBox(
                color: Color(0xff1B2433),
                child: Icon(
                  Icons.place_rounded,
                  color: Color(0xffFF9800),
                  size: 18,
                ),
              )
            : Image.asset(
                path,
                fit: BoxFit.cover,
                errorBuilder:
                    (BuildContext context, Object error, StackTrace? stack) {
                      return const ColoredBox(
                        color: Color(0xff1B2433),
                        child: Icon(
                          Icons.place_rounded,
                          color: Color(0xffFF9800),
                          size: 18,
                        ),
                      );
                    },
              ),
      ),
    );
  }
}

void showHomeEventPreview(
  BuildContext context,
  HomeListedEvent event, {
  VoidCallback? onOpenDetail,
}) {
  final AppLanguage language = LanguageController.language.value;
  final bool isDark = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: isDark ? const Color(0xff161D2B) : Colors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (BuildContext sheetContext) {
      final ColorScheme scheme = Theme.of(sheetContext).colorScheme;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (event.imageAsset != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  event.imageAsset!,
                  height: 132,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (BuildContext context, Object error, StackTrace? stack) {
                        return const SizedBox.shrink();
                      },
                ),
              ),
            if (event.imageAsset != null) const SizedBox(height: 14),
            Text(
              event.title,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _PreviewLine(
              icon: Icons.calendar_today_rounded,
              label: event.dateLabel(language),
            ),
            const SizedBox(height: 6),
            _PreviewLine(icon: Icons.schedule_rounded, label: event.time),
            if (event.locationLabel.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              _PreviewLine(
                icon: Icons.location_on_rounded,
                label: event.locationLabel,
              ),
            ],
            const SizedBox(height: 6),
            _PreviewLine(
              icon: Icons.group_outlined,
              label: event.participantLabel(language),
              accent: true,
            ),
            if (event.hostName.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              _PreviewLine(
                icon: Icons.person_outline_rounded,
                label: event.hostName,
              ),
            ],
            if (onOpenDetail != null) ...<Widget>[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    onOpenDetail();
                  },
                  child: Text(
                    _v(
                      language,
                      'Etkinlik detayını aç',
                      'Open event details',
                      'Veranstaltungsdetails öffnen',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({
    required this.icon,
    required this.label,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final Color color = accent
        ? const Color(0xffFF9800)
        : Theme.of(context).colorScheme.onSurface;

    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

String _v(AppLanguage language, String tr, String en, String de) {
  switch (language) {
    case AppLanguage.turkish:
      return tr;
    case AppLanguage.english:
      return en;
    case AppLanguage.german:
      return de;
  }
}
