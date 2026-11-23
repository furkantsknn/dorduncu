import 'package:dorduncu/utils/game_experience.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy experience values map safely', () {
    expect(normalizeGameExperience(30), 30);
    expect(normalizeGameExperience('60'), 60);
    expect(normalizeGameExperience('%90'), 90);
    expect(normalizeGameExperience(100), isNull);
    expect(normalizeGameExperience('unknown'), isNull);
  });
}
