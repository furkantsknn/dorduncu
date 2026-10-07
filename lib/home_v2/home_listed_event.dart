import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event_model.dart';
import '../services/language_controller.dart';
import '../utils/game_catalog.dart';
import '../utils/game_cover_assets.dart';

/// Ana ekran ve haritaların gösterdiği gerçek etkinlik.
/// Açık adres, mekan ve ücret bu görünümde yok.
class HomeListedEvent {
  const HomeListedEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.city,
    required this.district,
    required this.latitude,
    required this.longitude,
    required this.imageAsset,
    required this.participantCount,
    required this.maxParticipants,
    required this.hostName,
    required this.source,
  });

  final String id;
  final String title;
  final DateTime date;
  final String time;
  final String city;
  final String district;
  final double latitude;
  final double longitude;
  final String? imageAsset;
  final int participantCount;
  final int maxParticipants;
  final String hostName;
  final Map<String, dynamic> source;

  bool get hasPublicPoint => latitude != 0 && longitude != 0;

  String get locationLabel {
    if (district.isEmpty) {
      return city;
    }
    if (city.isEmpty) {
      return district;
    }
    return '$district · $city';
  }

  factory HomeListedEvent.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return HomeListedEvent.fromMap(document.id, document.data());
  }

  factory HomeListedEvent.fromMap(String id, Map<String, dynamic> data) {
    final EventModel model = EventModel.fromMap(data, documentId: id);
    final GameDefinition? game =
        GameCatalog.gameById(model.resolvedGameId) ??
        GameCatalog.gameById(model.resolvedGameName) ??
        GameCatalog.gameByLegacyValue(model.game);
    final String title = game?.name ?? _plainName(model.resolvedGameName);
    final String imageKey = game?.id ?? model.resolvedGameId;
    final DateTime start = model.resolvedStartAt;
    final int joined = model.participantIds
        .where((String uid) => uid != model.creatorId)
        .length;

    return HomeListedEvent(
      id: id.isNotEmpty ? id : model.id,
      title: title,
      date: start,
      time: _clock(start),
      city: model.city.trim(),
      district: model.district.trim(),
      latitude: _coord(data, const <String>[
        'approxLatitude',
        'latitude',
        'enlem',
      ]),
      longitude: _coord(data, const <String>[
        'approxLongitude',
        'longitude',
        'boylam',
      ]),
      imageAsset: GameCoverAssets.pathFor(
        imageKey.isNotEmpty ? imageKey : title,
      ),
      participantCount: joined,
      maxParticipants: model.playerCount,
      hostName: model.creatorProfileName.trim(),
      source: data,
    );
  }

  String dateLabel(AppLanguage language) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime target = DateTime(date.year, date.month, date.day);
    final int diff = target.difference(today).inDays;
    if (diff == 0) {
      return _v(language, 'Bugün', 'Today', 'Heute');
    }
    if (diff == 1) {
      return _v(language, 'Yarın', 'Tomorrow', 'Morgen');
    }
    const List<String> monthsTr = <String>[
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    const List<String> monthsEn = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const List<String> monthsDe = <String>[
      'Jan',
      'Feb',
      'Mär',
      'Apr',
      'Mai',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Okt',
      'Nov',
      'Dez',
    ];
    final List<String> months = switch (language) {
      AppLanguage.turkish => monthsTr,
      AppLanguage.english => monthsEn,
      AppLanguage.german => monthsDe,
    };
    return '${date.day} ${months[date.month - 1]}';
  }

  String participantLabel(AppLanguage language) {
    return _v(
      language,
      '$participantCount/$maxParticipants kişi',
      '$participantCount/$maxParticipants players',
      '$participantCount/$maxParticipants Spieler',
    );
  }

  static String _plainName(String value) {
    return value
        .replaceAll(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '')
        .trim();
  }

  static String _clock(DateTime value) {
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static double _coord(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      final Object? value = data[key];
      if (value is num && value != 0) {
        return value.toDouble();
      }
    }
    return 0;
  }

  static String _v(AppLanguage language, String tr, String en, String de) {
    switch (language) {
      case AppLanguage.turkish:
        return tr;
      case AppLanguage.english:
        return en;
      case AppLanguage.german:
        return de;
    }
  }
}
