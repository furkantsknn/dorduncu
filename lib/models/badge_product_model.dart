import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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
    this.googlePlayPurchaseOptionId = '',
    this.appleProductId = '',
    this.giftGooglePlayProductId = '',
    this.giftGooglePlayPurchaseOptionId = '',
    this.plusGooglePlayOfferId = '',
    this.plusPriceKurus = 39900,
  });

  final String id;
  final String gameId;
  final String gameName;
  final String title;
  final String description;
  final String emoji;
  final String imageUrl;
  final String googlePlayProductId;
  final String googlePlayPurchaseOptionId;
  final String appleProductId;
  final String giftGooglePlayProductId;
  final String giftGooglePlayPurchaseOptionId;
  final String plusGooglePlayOfferId;
  final int plusPriceKurus;
  final int priceKurus;
  final bool active;
  final int sortOrder;
  final DateTime? createdAt;

  String storeProductIdFor(TargetPlatform platform) {
    if (platform == TargetPlatform.iOS) {
      return appleProductId.trim();
    }
    return googlePlayProductId.trim();
  }

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
      googlePlayProductId: data['googlePlayProductId']?.toString().trim() ?? '',
      googlePlayPurchaseOptionId:
          data['googlePlayPurchaseOptionId']?.toString().trim() ?? '',
      appleProductId: data['appleProductId']?.toString().trim() ?? '',
      giftGooglePlayProductId:
          data['giftGooglePlayProductId']?.toString().trim() ?? '',
      giftGooglePlayPurchaseOptionId:
          data['giftGooglePlayPurchaseOptionId']?.toString().trim() ?? '',
      plusGooglePlayOfferId:
          data['plusGooglePlayOfferId']?.toString().trim() ?? '',
      plusPriceKurus: _toInt(data['plusPriceKurus']) == 0
          ? 39900
          : _toInt(data['plusPriceKurus']),
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
