import 'package:firebase_analytics/firebase_analytics.dart';

/// Store purchase events. Purchase tokens and order ids are never sent.
class PurchaseAnalytics {
  const PurchaseAnalytics._();

  static Future<void> log({
    required String name,
    required String googlePlayProductId,
    String? internalProductId,
    String? errorCode,
  }) async {
    final Map<String, Object> parameters = <String, Object>{
      'google_play_product_id': _clip(googlePlayProductId),
      'source': 'market',
    };

    final String productId = internalProductId?.trim() ?? '';
    if (productId.isNotEmpty) {
      parameters['internal_product_id'] = _clip(productId);
    }

    final String code = errorCode?.trim() ?? '';
    if (code.isNotEmpty) {
      parameters['error_code'] = _clip(code);
    }

    try {
      await FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (_) {
      // Analytics must not block a Play purchase.
    }
  }

  static String _clip(String value) {
    final String trimmed = value.trim();
    if (trimmed.length <= 100) {
      return trimmed;
    }
    return trimmed.substring(0, 100);
  }
}
