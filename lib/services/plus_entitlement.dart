import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads the server-written Plus entitlement.
///
/// A legacy `plus` flag without a future expiry is not an active subscription.
class PlusEntitlement {
  const PlusEntitlement._();

  static const Set<String> entitledStates = <String>{
    'SUBSCRIPTION_STATE_ACTIVE',
    'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
    'SUBSCRIPTION_STATE_CANCELED',
  };

  static bool isActive(Map<String, dynamic>? data, {DateTime? now}) {
    if (data == null) {
      return false;
    }

    if (data['plusAdminGranted'] == true) {
      return true;
    }

    return expiresAt(data, now: now) != null;
  }

  /// Effective dated sources; an admin grant has no subscription expiry.
  static DateTime? expiresAt(Map<String, dynamic>? data, {DateTime? now}) {
    if (data == null || data['plusAdminGranted'] == true) return null;
    final DateTime clock = now ?? DateTime.now();
    final DateTime? giftExpiry = _date(data['plusGiftExpiresAt']);
    final DateTime? activeGift = giftExpiry != null && giftExpiry.isAfter(clock)
        ? giftExpiry
        : null;

    final bool flagged = data['plus'] == true || data['isPlus'] == true;
    if (!flagged) {
      return activeGift;
    }

    final DateTime? expiry =
        _date(data['plusSubscriptionExpiresAt']) ??
        (giftExpiry == null
            ? _date(data['plusExpiresAt'] ?? data['subscriptionExpiresAt'])
            : null);
    if (expiry == null || !expiry.isAfter(clock)) {
      return activeGift;
    }

    final String state = data['plusSubscriptionState']?.toString().trim() ?? '';
    if (state.isNotEmpty && !entitledStates.contains(state)) return activeGift;
    return activeGift != null && activeGift.isAfter(expiry)
        ? activeGift
        : expiry;
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}
