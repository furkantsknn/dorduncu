import 'package:dorduncu/screens/public_profile_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public profil sahipliği yalnız UID ile belirlenir', () {
    expect(
      isOwnPublicProfile(signedInUid: 'user-1', profileUid: 'user-1'),
      isTrue,
    );
    expect(
      isOwnPublicProfile(signedInUid: 'user-1', profileUid: 'user-2'),
      isFalse,
    );
    expect(
      isOwnPublicProfile(signedInUid: null, profileUid: 'user-1'),
      isFalse,
    );
  });
}
