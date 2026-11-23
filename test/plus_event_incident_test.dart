import 'package:dorduncu/l10n/app_localizations.dart';
import 'package:dorduncu/models/user_model.dart';
import 'package:dorduncu/services/event_operation_failure.dart';
import 'package:dorduncu/services/plus_entitlement.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resource/rate failure is safe and never offers automatic retry', () {
    const failure = EventOperationFailure(
      code: 'RESOURCE_EXHAUSTED',
      stage: 'create-callable',
    );
    expect(failure.safeCode, 'resource-exhausted');
    expect(failure.canRetryAutomatically, isFalse);
    expect(
      const EventOperationFailure(
        code: 'secret payload!',
        stage: 'create',
      ).safeCode,
      'unknown',
    );
  });

  for (final lang in ['tr', 'en', 'de']) {
    test('localized capacity and uncertain outcome messages: $lang', () async {
      final l10n = await AppLocalizations.delegate.load(Locale(lang));
      final message = l10n.eventServiceBusy('resource-exhausted');
      expect(message, contains('resource-exhausted'));
      expect(message, isNot(contains('Bad state')));
      if (lang == 'tr') expect(message, contains('yoğun'));
      if (lang == 'de') expect(message, contains('Prüfe'));
      expect(l10n.eventCreateUncertain('unavailable'), contains('unavailable'));
    });
  }

  test('profile model and Market policy agree on independent sources', () {
    final future = DateTime.now().add(const Duration(days: 1));
    final past = DateTime.now().subtract(const Duration(days: 1));
    final cases = <Map<String, dynamic>>[
      {'plusAdminGranted': true},
      {'role': 'admin', 'admin': true},
      {
        'plusAdminGranted': false,
        'plus': true,
        'plusSubscriptionExpiresAt': future,
        'plusSubscriptionState': 'SUBSCRIPTION_STATE_ACTIVE',
      },
      {
        'plusAdminGranted': false,
        'plus': true,
        'plusSubscriptionExpiresAt': past,
      },
      {
        'plus': true,
        'plusGiftExpiresAt': future,
        'plusSubscriptionExpiresAt': past,
      },
      {'plus': true, 'plusGiftExpiresAt': past, 'plusExpiresAt': future},
      {
        'plus': true,
        'plusSubscriptionExpiresAt': future,
        'plusSubscriptionState': 'SUBSCRIPTION_STATE_EXPIRED',
      },
    ];
    for (final data in cases) {
      final model = UserModel.fromMap(data, documentId: 'synthetic');
      expect(model.isPlusActive, PlusEntitlement.isActive(data));
      expect(model.copyWith().isPlusActive, model.isPlusActive);
      expect(model.effectivePlusExpiresAt, PlusEntitlement.expiresAt(data));
    }
    expect(PlusEntitlement.isActive(cases[5]), isFalse);
    final legacyFlags = <String, dynamic>{
      'plus': false,
      'isPlus': true,
      'plusSubscriptionExpiresAt': future,
    };
    expect(
      UserModel.fromMap(legacyFlags).isPlusActive,
      PlusEntitlement.isActive(legacyFlags),
    );
  });
}
