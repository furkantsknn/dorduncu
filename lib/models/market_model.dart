import 'package:cloud_firestore/cloud_firestore.dart';

class MarketModel {
  const MarketModel({
    required this.id,
    required this.name,
    required this.category,
    required this.city,
    required this.district,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.active,
  });

  final String id;
  final String name;
  final String category;
  final String city;
  final String district;
  final String address;
  final double latitude;
  final double longitude;
  final bool active;

  bool get hasLocation => latitude != 0 && longitude != 0;

  factory MarketModel.fromDocument(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data() ?? const <String, dynamic>{};

    return MarketModel(
      id: document.id,
      name: data['name']?.toString().trim() ?? '',
      category: data['category']?.toString().trim() ?? '',
      city: data['city']?.toString().trim() ?? '',
      district: data['district']?.toString().trim() ?? '',
      address: data['address']?.toString().trim() ?? '',
      latitude: _toDouble(data['latitude']),
      longitude: _toDouble(data['longitude']),
      active: data['active'] != false,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}