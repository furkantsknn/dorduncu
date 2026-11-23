import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/badge_product_model.dart';
import '../models/market_badge_display.dart';
import '../widgets/premium_badge_assets.dart';

bool isTargetPremiumBadgeProduct(BadgeProductModel product) {
  final String id = product.id.trim();
  final String gameId = product.gameId.trim();
  return id == gameId && premiumBadgeAssets.containsKey(id);
}

class MarketService {
  MarketService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _badgeProducts {
    return _firestore.collection('badge_products');
  }

  Stream<List<BadgeProductModel>> watchActiveBadgeProducts({int limit = 200}) {
    return _badgeProducts
        .where('active', isEqualTo: true)
        .orderBy('sortOrder')
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(BadgeProductModel.fromDocument)
              .where(
                (product) =>
                    isTargetPremiumBadgeProduct(product) &&
                    product.gameId.isNotEmpty &&
                    product.title.isNotEmpty &&
                    product.priceKurus > 0,
              )
              .toList(),
        );
  }

  Stream<Set<String>> watchOwnedBadgeIds(String uid) {
    final String normalizedUid = uid.trim();

    if (normalizedUid.isEmpty) {
      return Stream<Set<String>>.value(<String>{});
    }

    return _firestore
        .collection('users')
        .doc(normalizedUid)
        .collection('owned_badges')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .where((document) => ownedBadgeIsEntitled(document.data()))
              .map((document) => document.id)
              .toSet(),
        );
  }

  Stream<Set<String>> watchAdminBlockedBadgeIds(String uid) {
    final String normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return Stream<Set<String>>.value(<String>{});
    return _firestore
        .collection('users')
        .doc(normalizedUid)
        .collection('owned_badges')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .where((document) => ownedBadgeIsAdminBlocked(document.data()))
              .map((document) => document.id)
              .toSet(),
        );
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchWallet(String uid) {
    final String normalizedUid = uid.trim();

    return _firestore.collection('wallets').doc(normalizedUid).snapshots();
  }
}
