import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dorduncu/admin/legacy_notification_cancel_action.dart';

void main() {
  testWidgets(
    'only old pending jobs show cancellation, with a required reason',
    (tester) async {
      Future<void> show(Map<String, dynamic> data) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LegacyNotificationCancelAction(
              notificationId: 'local',
              data: data,
            ),
          ),
        ),
      );
      await show({'status': 'processing'});
      expect(find.byType(OutlinedButton), findsNothing);
      await show({'status': 'pending', 'dispatchVersion': 1});
      expect(find.byType(OutlinedButton), findsNothing);
      await show({'status': 'pending'});
      expect(find.byType(OutlinedButton), findsOneWidget);
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), 'Do not send this job');
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}
