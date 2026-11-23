import 'package:dorduncu/services/digital_restore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('doğrulanan hak tamamlandı sayılır', () {
    expect(
      classifyDigitalRestore(verifiedForAccount: 1, giftsKeptWithRecipient: 0),
      DigitalRestorePresentation.completed,
    );
  });

  test('hediye gönderene taşınmış gibi tamamlandı sayılmaz', () {
    expect(
      classifyDigitalRestore(verifiedForAccount: 0, giftsKeptWithRecipient: 1),
      DigitalRestorePresentation.giftKept,
    );
  });

  test('yalnızca bekleyen ödeme varsa bulunamadı denmez', () {
    expect(
      classifyDigitalRestore(
        verifiedForAccount: 0,
        giftsKeptWithRecipient: 0,
        pendingPayments: 1,
      ),
      DigitalRestorePresentation.paymentPending,
    );
    expect(
      classifyDigitalRestore(
        verifiedForAccount: 1,
        giftsKeptWithRecipient: 0,
        pendingPayments: 1,
      ),
      DigitalRestorePresentation.completed,
    );
  });

  test('kayıt yoksa bulunamadı', () {
    expect(
      classifyDigitalRestore(verifiedForAccount: 0, giftsKeptWithRecipient: 0),
      DigitalRestorePresentation.notFound,
    );
  });
}
