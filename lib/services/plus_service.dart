import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/plus_product_model.dart';

class PlusService {
  PlusService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(
              region: 'europe-west1',
            );

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Stream<List<PlusProductModel>> watchActiveProducts() {
    return _firestore
        .collection('plus_products')
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final List<PlusProductModel> products = snapshot.docs
          .map(PlusProductModel.fromDocument)
          .where((product) {
        return product.priceKurus > 0 &&
            product.durationDays > 0;
      }).toList();

      products.sort(
            (a, b) => a.sortOrder.compareTo(b.sortOrder),
      );

      return products;
    });
  }

  Future<DateTime> purchasePlus({
    required String productId,
    required String paymentSource,
  }) async {
    final HttpsCallable callable =
    _functions.httpsCallable('purchasePlus');

    final HttpsCallableResult<dynamic> result =
    await callable.call(<String, dynamic>{
      'productId': productId,
      'paymentSource': paymentSource,
    });

    final dynamic rawData = result.data;

    if (rawData is! Map) {
      throw const PlusServiceException(
        'Plus satın alma sonucu okunamadı.',
      );
    }

    final String rawExpiry =
        rawData['plusExpiresAt']?.toString().trim() ?? '';

    final DateTime? expiry = DateTime.tryParse(rawExpiry);

    if (expiry == null) {
      throw const PlusServiceException(
        'Plus bitiş tarihi alınamadı.',
      );
    }

    return expiry;
  }
}

class PlusServiceException implements Exception {
  const PlusServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
