import 'package:dorduncu/services/plus_entitlement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('explicit admin grant is active without a fake expiry', () {
    expect(
      PlusEntitlement.isActive(<String, dynamic>{'plusAdminGranted': true}),
      isTrue,
    );
  });

  test('admin role alone does not grant Plus', () {
    expect(
      PlusEntitlement.isActive(<String, dynamic>{
        'admin': true,
        'role': 'super_admin',
      }),
      isFalse,
    );
  });

  test('removing admin source preserves valid subscription source', () {
    expect(
      PlusEntitlement.isActive(<String, dynamic>{
        'plusAdminGranted': false,
        'plus': true,
        'plusSubscriptionState': 'SUBSCRIPTION_STATE_ACTIVE',
        'plusSubscriptionExpiresAt': DateTime.now().add(
          const Duration(days: 1),
        ),
      }),
      isTrue,
    );
  });
}
