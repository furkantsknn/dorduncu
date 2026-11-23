import 'package:dorduncu/services/event_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Plus oyuncu sınırı kodu istemciye ayırt edilir', () {
    expect(
      isPlusPlayerLimitFailure(
        details: <String, String>{'code': plusPlayerLimitErrorCode},
        message: '2 veya daha fazla oyuncu için Plus üyelik gerekir.',
      ),
      isTrue,
    );
    expect(
      isPlusPlayerLimitFailure(
        details: null,
        message: '2 veya daha fazla oyuncu için Plus üyelik gerekir.',
      ),
      isTrue,
    );
    expect(
      isPlusPlayerLimitFailure(
        details: null,
        message: 'Oyuncu sayısı 1 ile 4 arasında olmalıdır.',
      ),
      isFalse,
    );
  });
}
