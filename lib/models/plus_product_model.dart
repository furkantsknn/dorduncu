import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class PlusProductModel {
  const PlusProductModel({
    required this.id,
    required this.title,
    required this.plan,
    required this.priceKurus,
    required this.durationDays,
    required this.active,
    required this.sortOrder,
    required this.googlePlayProductId,
    required this.googlePlayBasePlanId,
    this.appleProductId = '',
    this.giftGooglePlayProductId = '',
    this.giftGooglePlayPurchaseOptionId = '',
    this.activeGooglePlayOfferId = '',
    this.activePlusDiscountedPeriods = 0,
  });

  final String id;
  final String title;
  final String plan;
  final int priceKurus;
  final int durationDays;
  final bool active;
  final int sortOrder;
  final String googlePlayProductId;
  final String googlePlayBasePlanId;
  final String appleProductId;
  final String giftGooglePlayProductId;
  final String giftGooglePlayPurchaseOptionId;
  final String activeGooglePlayOfferId;
  final int activePlusDiscountedPeriods;

  /// A plan without a Play product and base plan cannot be sold on Android.
  bool get hasPlayMapping =>
      googlePlayProductId.trim().isNotEmpty &&
      googlePlayBasePlanId.trim().isNotEmpty;

  /// A plan without an App Store product id cannot be sold on iOS.
  bool get hasAppleMapping => appleProductId.trim().isNotEmpty;

  String storeProductIdFor(TargetPlatform platform) {
    if (platform == TargetPlatform.iOS) {
      return appleProductId.trim();
    }
    return googlePlayProductId.trim();
  }

  bool hasStoreMappingFor(TargetPlatform platform) {
    if (platform == TargetPlatform.iOS) {
      return hasAppleMapping;
    }
    return hasPlayMapping;
  }

  factory PlusProductModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data() ?? <String, dynamic>{};

    return PlusProductModel(
      id: document.id,
      title: data['title']?.toString().trim().isNotEmpty == true
          ? data['title'].toString().trim()
          : 'Dört. Plus',
      plan: data['plan']?.toString().trim().isNotEmpty == true
          ? data['plan'].toString().trim()
          : document.id,
      priceKurus: _readInt(data['priceKurus']),
      durationDays: _readInt(data['durationDays']),
      active: data['active'] == true,
      sortOrder: _readInt(data['sortOrder']),
      googlePlayProductId: data['googlePlayProductId']?.toString().trim() ?? '',
      googlePlayBasePlanId:
          data['googlePlayBasePlanId']?.toString().trim() ?? '',
      appleProductId: data['appleProductId']?.toString().trim() ?? '',
      giftGooglePlayProductId:
          data['giftGooglePlayProductId']?.toString().trim() ?? '',
      giftGooglePlayPurchaseOptionId:
          data['giftGooglePlayPurchaseOptionId']?.toString().trim() ?? '',
      activeGooglePlayOfferId:
          data['activeGooglePlayOfferId']?.toString().trim() ?? '',
      activePlusDiscountedPeriods: _readInt(
        data['activePlusDiscountedPeriods'],
      ),
    );
  }

  static int _readInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
