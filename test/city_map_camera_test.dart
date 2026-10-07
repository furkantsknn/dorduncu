import 'package:dorduncu/utils/city_map_camera.dart';
import 'package:dorduncu/utils/turkey_city_centers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('İstanbul ve Ankara mevcut il merkezine çözülür', () {
    expect(turkeyCityCenter('İstanbul'), const LatLng(41.0082, 28.9784));
    expect(turkeyCityCenter('Ankara'), const LatLng(39.9334, 32.8597));
    expect(turkeyCityCenter('İzmir'), isNotNull);
    expect(turkeyCityCenter(''), isNull);
  });

  test('etkinlik olmasa da son seçilen şehir kameraya yazılır', () {
    final CityMapCamera camera = CityMapCamera()..ready = true;

    final CityCameraCommand? command = camera.choose('Ankara');

    expect(command?.center, turkeyCityCenter('Ankara'));
    expect(command?.zoom, 11.5);
  });

  test('controller hazır değilken son şehir bekler', () {
    final CityMapCamera camera = CityMapCamera();

    expect(camera.choose('İstanbul'), isNull);
    expect(camera.choose('Ankara'), isNull);

    final CityCameraCommand? ready = camera.controllerReady();

    expect(ready?.cityKey, turkeyCityKey('Ankara'));
    expect(camera.complete(ready!), isTrue);
    expect(camera.appliedCityKey, turkeyCityKey('Ankara'));
  });

  test('hızlı seçimde eski kamera komutu son şehri ezmez', () {
    final CityMapCamera camera = CityMapCamera()..ready = true;
    final CityCameraCommand istanbul = camera.choose('İstanbul')!;
    final CityCameraCommand ankara = camera.choose('Ankara')!;

    expect(camera.complete(istanbul), isFalse);
    expect(camera.appliedCityKey, isNull);
    expect(camera.complete(ankara), isTrue);
    expect(camera.appliedCityKey, turkeyCityKey('Ankara'));
  });

  test('aynı şehir yeniden çizimde kamerayı tekrar istemez', () {
    final CityMapCamera camera = CityMapCamera()..ready = true;
    final CityCameraCommand? first = camera.choose('İzmir');
    expect(camera.complete(first!), isTrue);

    expect(camera.choose('İzmir'), isNull);
    expect(camera.choose('izmir'), isNull);
  });
}
