import 'package:cloud_firestore/cloud_firestore.dart';

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
    );
  }

  static int _readInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
