/// Contains no provider message, request payload, user id, or token.
class EventOperationFailure implements Exception {
  const EventOperationFailure({required this.code, required this.stage});

  final String code;
  final String stage;

  String get safeCode => RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(code)
      ? code.toLowerCase().replaceAll('_', '-')
      : 'unknown';

  /// A failed create response can be ambiguous on older servers. Never offer
  /// an automatic retry until the event list or an idempotent server confirms it.
  bool get canRetryAutomatically => false;

  @override
  String toString() => 'EventOperationFailure($stage/$safeCode)';
}
