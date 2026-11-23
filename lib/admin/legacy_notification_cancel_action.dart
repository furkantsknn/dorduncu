import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class LegacyNotificationCancelAction extends StatefulWidget {
  const LegacyNotificationCancelAction({
    super.key,
    required this.notificationId,
    required this.data,
  });

  final String notificationId;
  final Map<String, dynamic> data;

  @override
  State<LegacyNotificationCancelAction> createState() =>
      _LegacyNotificationCancelActionState();
}

class _LegacyNotificationCancelActionState
    extends State<LegacyNotificationCancelAction> {
  bool _busy = false;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String _text(String tr, String en, String de) =>
      switch (Localizations.localeOf(context).languageCode) {
        'en' => en,
        'de' => de,
        _ => tr,
      };

  Future<void> _cancel() async {
    final controller = _reason..clear();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => AlertDialog(
          title: Text(
            _text(
              'Göndermeden iptal et',
              'Cancel without sending',
              'Ohne Versand abbrechen',
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _text(
                  'Yalnız gönderim izi olmayan eski bekleyen iş iptal edilir.',
                  'Only an old pending job with no sending evidence can be cancelled.',
                  'Nur ein alter wartender Auftrag ohne Versandnachweis kann abgebrochen werden.',
                ),
              ),
              TextField(
                controller: controller,
                maxLength: 500,
                onChanged: (_) => refresh(() {}),
                decoration: InputDecoration(
                  labelText: _text('Gerekçe', 'Reason', 'Begründung'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_text('Vazgeç', 'Back', 'Zurück')),
            ),
            FilledButton(
              onPressed: controller.text.trim().length < 3
                  ? null
                  : () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(
                _text(
                  'İptali onayla',
                  'Confirm cancellation',
                  'Abbruch bestätigen',
                ),
              ),
            ),
          ],
        ),
      ),
    );
    // The dialog route can still animate while the controller is in use.
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('adminCancelLegacyNotification')
          .call({'notificationId': widget.notificationId, 'reason': reason});
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.message ??
                  _text(
                    'İptal edilemedi.',
                    'Cancellation failed.',
                    'Abbruch fehlgeschlagen.',
                  ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (data['status'] != 'pending' ||
        ![null, 0].contains(data['dispatchVersion'])) {
      return const SizedBox.shrink();
    }
    return OutlinedButton(
      onPressed: _busy ? null : _cancel,
      child: Text(
        _text(
          'Göndermeden iptal et',
          'Cancel without sending',
          'Ohne Versand abbrechen',
        ),
      ),
    );
  }
}
