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

    final bool flagged = data['plus'] == true || data['isPlus'] == true;
    if (!flagged) {
      return false;
    }

    final DateTime? expiry = _date(
      data['plusExpiresAt'] ?? data['subscriptionExpiresAt'],
    );
    if (expiry == null || !expiry.isAfter(now ?? DateTime.now())) {
      return false;
    }

    final String state = data['plusSubscriptionState']?.toString().trim() ?? '';
    if (state.isEmpty) {
      return true;
    }

    return entitledStates.contains(state);
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
