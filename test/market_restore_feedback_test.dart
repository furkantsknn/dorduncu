import 'package:dorduncu/screens/market_screen.dart';
import 'package:dorduncu/services/digital_restore.dart';
import 'package:dorduncu/services/purchase_flow_reconcile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('geri yükleme sonucu Plus penceresindeki metinde kalır', (
    WidgetTester tester,
  ) async {
    final ValueNotifier<MarketRestoreFeedback> feedback =
        ValueNotifier<MarketRestoreFeedback>(
          const MarketRestoreFeedback.none(),
        );
    addTearDown(feedback.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MarketRestoreFeedbackBanner(feedback: feedback)),
      ),
    );

    expect(find.text('Checking purchases'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);

    feedback.value = const MarketRestoreFeedback.running();
    await tester.pump();
    expect(find.text('Checking purchases'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    feedback.value = const MarketRestoreFeedback.notFound();
    await tester.pump();
    expect(find.text('No purchases were found to restore.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    feedback.value = const MarketRestoreFeedback.failed(
      'Satın alma doğrulanamadı. Tekrar kontrol et.',
    );
    await tester.pump();
    expect(
      find.text('Satın alma doğrulanamadı. Tekrar kontrol et.'),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);

    feedback.value = const MarketRestoreFeedback.blocked(
      MarketRestoreReason.verifying,
    );
    await tester.pump();
    expect(
      find.text(
        'Verification is still running. Restore stays closed until it finishes.',
      ),
      findsOneWidget,
    );
  });
}
