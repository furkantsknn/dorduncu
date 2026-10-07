import 'package:cloud_firestore/cloud_firestore.dart';

class BadgeProductModel {
  const BadgeProductModel({
    required this.id,
    required this.gameId,
    required this.gameName,
    required this.title,
    required this.description,
    required this.emoji,
    required this.priceKurus,
    required this.active,
    required this.sortOrder,
    required this.createdAt,
    this.imageUrl = '',
    this.googlePlayProductId = '',
  });

  final String id;
  final String gameId;
  final String gameName;
  final String title;
  final String description;
  final String emoji;
  final String imageUrl;
  final String googlePlayProductId;
  final int priceKurus;
  final bool active;
  final int sortOrder;
  final DateTime? createdAt;

  factory BadgeProductModel.fromDocument(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final Map<String, dynamic> data =
        document.data() ?? const <String, dynamic>{};

    return BadgeProductModel(
      id: document.id,
      gameId: data['gameId']?.toString().trim() ?? '',
      gameName: data['gameName']?.toString().trim() ?? '',
      title: data['title']?.toString().trim() ?? '',
      description: data['description']?.toString().trim() ?? '',
      emoji: data['emoji']?.toString().trim() ?? '🏅',
      imageUrl: data['imageUrl']?.toString().trim() ?? '',
      googlePlayProductId:
          data['googlePlayProductId']?.toString().trim() ?? '',
      priceKurus: _toInt(data['priceKurus']),
      active: data['active'] != false,
      sortOrder: _toInt(data['sortOrder']),
      createdAt: _toDate(data['createdAt']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}