import 'package:latlong2/latlong.dart';

import 'turkey_city_centers.dart';

class CityCameraCommand {
  const CityCameraCommand({
    required this.generation,
    required this.cityKey,
    required this.center,
    required this.zoom,
  });

  final int generation;
  final String cityKey;
  final LatLng center;
  final double zoom;
}

/// Decides when a map may move to the selected city.
///
/// A newer city selection replaces an older one. The move is held until the
/// map controller is ready, and a repeated build of the same city does not
/// produce another move.
class CityMapCamera {
  CityMapCamera({this.zoom = 11.5});

  final double zoom;
  int generation = 0;
  bool ready = false;
  String? appliedCityKey;
  CityCameraCommand? pending;

  CityCameraCommand? choose(String city) {
    final LatLng? center = turkeyCityCenter(city);
    final String key = turkeyCityKey(city);
    if (center == null || key.isEmpty) {
      return null;
    }
    generation += 1;
    final CityCameraCommand command = CityCameraCommand(
      generation: generation,
      cityKey: key,
      center: center,
      zoom: zoom,
    );
    if (appliedCityKey == key) {
      pending = null;
      return null;
    }
    pending = command;
    if (!ready) {
      return null;
    }
    return command;
  }

  CityCameraCommand? controllerReady() {
    ready = true;
    final CityCameraCommand? command = pending;
    if (command == null || command.generation != generation) {
      return null;
    }
    if (appliedCityKey == command.cityKey) {
      return null;
    }
    return command;
  }

  bool complete(CityCameraCommand command) {
    if (command.generation != generation) {
      return false;
    }
    appliedCityKey = command.cityKey;
    pending = null;
    return true;
  }
}
