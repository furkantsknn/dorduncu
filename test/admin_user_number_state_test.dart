import 'package:dorduncu/admin/admin_user_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('admin user number state', () {
    test('does not present a missing number while the read is loading', () {
      expect(
        resolveAdminUserNumberState(
          hasData: false,
          hasError: false,
          documentExists: false,
          number: '',
        ),
        AdminUserNumberState.loading,
      );
    });

    test('keeps read errors distinct from a missing number', () {
      expect(
        resolveAdminUserNumberState(
          hasData: false,
          hasError: true,
          documentExists: false,
          number: '',
        ),
        AdminUserNumberState.error,
      );
    });

    test('reports missing only after a successful document read', () {
      expect(
        resolveAdminUserNumberState(
          hasData: true,
          hasError: false,
          documentExists: true,
          number: '',
        ),
        AdminUserNumberState.missing,
      );
    });

    test('reports an assigned management number as available', () {
      expect(
        resolveAdminUserNumberState(
          hasData: true,
          hasError: false,
          documentExists: true,
          number: 'U-000001',
        ),
        AdminUserNumberState.available,
      );
    });
  });
}
