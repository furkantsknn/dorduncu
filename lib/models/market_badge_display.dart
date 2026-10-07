import 'package:cloud_firestore/cloud_firestore.dart';

class MarketBadgeDisplay {
  const MarketBadgeDisplay({
    required this.badgeId,
    required this.productId,
    required this.title,
    required this.gameId,
    required this.gameName,
    required this.emoji,
    required this.imageUrl,
    this.purchasedAt,
  });

  final String badgeId;
  final String productId;
  final String title;
  final String gameId;
  final String gameName;
  final String emoji;
  final String imageUrl;
  final DateTime? purchasedAt;

  String get catalogId => productId.isNotEmpty ? productId : badgeId;

  bool get needsCatalogTitle => isGenericBadgeTitle(title);

  MarketBadgeDisplay mergeCatalog(Map<String, dynamic>? product) {
    if (product == null) {
      return this;
    }

    final String catalogTitle = _text(product['title']);
    final String catalogGameName = _text(product['gameName']);
    final String catalogEmoji = _text(product['emoji']);
    final String catalogImage = _text(product['imageUrl']);
    final String catalogGameId = _text(product['gameId']);

    final String resolvedTitle = !isGenericBadgeTitle(catalogTitle)
        ? catalogTitle
        : (!isGenericBadgeTitle(title)
              ? title
              : (catalogGameName.isNotEmpty
                    ? catalogGameName
                    : (gameName.isNotEmpty ? gameName : title)));

    return MarketBadgeDisplay(
      badgeId: badgeId,
      productId: productId,
      title: resolvedTitle,
      gameId: gameId.isNotEmpty ? gameId : catalogGameId,
      gameName: gameName.isNotEmpty ? gameName : catalogGameName,
      emoji: emoji.isNotEmpty ? emoji : catalogEmoji,
      imageUrl: imageUrl.isNotEmpty ? imageUrl : catalogImage,
      purchasedAt: purchasedAt,
    );
  }

  static List<MarketBadgeDisplay> listFrom(dynamic value) {
    if (value is! List) {
      return const <MarketBadgeDisplay>[];
    }

    return value
        .whereType<Map>()
        .map(
          (Map item) =>
              fromMap(Map<String, dynamic>.from(item), documentId: ''),
        )
        .where((MarketBadgeDisplay badge) => badge.badgeId.isNotEmpty)
        .toList(growable: false);
  }

  static MarketBadgeDisplay fromOwnedDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return fromMap(
      document.data() ?? const <String, dynamic>{},
      documentId: document.id,
    );
  }

  static MarketBadgeDisplay fromMap(
    Map<String, dynamic> data, {
    required String documentId,
  }) {
    final String badgeId = _firstText(data, <String>[
      'badgeId',
      'productId',
    ], documentId);
    final String productId = _firstText(data, <String>[
      'productId',
      'badgeId',
    ], badgeId);
    final String gameName = _text(data['gameName']);
    final String rawTitle = _text(data['title']);
    final String title = !isGenericBadgeTitle(rawTitle)
        ? rawTitle
        : (gameName.isNotEmpty ? gameName : rawTitle);

    return MarketBadgeDisplay(
      badgeId: badgeId,
      productId: productId,
      title: title,
      gameId: _text(data['gameId']),
      gameName: gameName,
      emoji: _text(data['emoji']),
      imageUrl: _text(data['imageUrl']),
      purchasedAt: _date(data['purchasedAt']),
    );
  }

  static bool isGenericBadgeTitle(String value) {
    final String normalized = value.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'oyun rozeti' ||
        normalized == 'oyun rozet';
  }

  static String _firstText(
    Map<String, dynamic> data,
    List<String> keys,
    String fallback,
  ) {
    for (final String key in keys) {
      final String value = _text(data[key]);
      if (value.isNotEmpty) {
        return value;
      }
    }
    return fallback.trim();
  }

  static String _text(dynamic value) {
    return value?.toString().trim() ?? '';
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
