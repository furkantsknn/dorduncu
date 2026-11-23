import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/game_catalog.dart';

class EventModel {
  const EventModel({
    required this.id,
    required this.game,
    required this.playerCount,
    required this.playerCountText,
    required this.memberPreference,
    required this.description,
    required this.city,
    required this.district,
    required this.neighborhood,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.eventDate,
    required this.creatorId,
    required this.creatorProfileName,
    required this.creatorProfilePhoto,
    required this.creatorPlus,
    required this.creatorVerified,
    required this.participantIds,
    required this.chatMemberIds,
    required this.favoriteCount,
    required this.status,
    required this.createdAt,
    required this.paymentRequired,
    required this.paymentStatus,
    required this.customerTotal,
    required this.playerGrossEarning,
    required this.platformShare,
    required this.pricingVersion,
    required this.selectedPlayerIds,
    this.categoryId = '',
    this.categoryName = '',
    this.gameId = '',
    this.gameName = '',
    this.startAt,
    this.endAt,
    this.basePricePerPlayer = 0,
    this.durationFactor = 0,
    this.paymentId = '',
    this.accessModel = '',
    this.durationMinutes = 0,
    this.updatedAt,
    this.cancelledAt,
    this.cancellationReason = '',
  });

  final String id;

  /// Eski ekranlarla uyumluluk için tutulan gösterim değeri.
  ///
  /// Yeni kodlarda mümkün olduğunca [gameId] ve [gameName] kullanılmalıdır.
  final String game;

  /// Merkezi katalogdaki sabit kategori kimliği.
  final String categoryId;

  /// Kullanıcıya gösterilecek kategori adı.
  final String categoryName;

  /// Merkezi katalogdaki sabit oyun/spor kimliği.
  final String gameId;

  /// Kullanıcıya gösterilecek oyun/spor adı.
  final String gameName;

  final int playerCount;
  final String playerCountText;
  final String memberPreference;
  final String description;

  final String city;
  final String district;
  final String neighborhood;
  final String address;

  final double latitude;
  final double longitude;

  /// Eski kayıtlar ve mevcut ekranlarla uyumluluk için etkinliğin başlangıcı.
  final DateTime eventDate;

  /// Yeni fiyatlandırma ve saat aralığı sisteminin başlangıç zamanı.
  final DateTime? startAt;

  /// Yeni fiyatlandırma ve saat aralığı sisteminin bitiş zamanı.
  final DateTime? endAt;

  final String creatorId;
  final String creatorProfileName;
  final String creatorProfilePhoto;
  final bool creatorPlus;
  final bool creatorVerified;

  final List<String> participantIds;
  final List<String> chatMemberIds;
  final List<String> selectedPlayerIds;

  final int favoriteCount;
  final String status;

  final DateTime createdAt;
  final DateTime? updatedAt;

  final bool paymentRequired;
  final String paymentStatus;
  final String accessModel;
  final String paymentId;

  /// Bir oyuncunun ilk saat için kategori taban fiyatı.
  final double basePricePerPlayer;

  /// Seçilen süreye uygulanan azalan süre katsayısı.
  final double durationFactor;

  /// Müşterinin ödeyeceği toplam tutar.
  final double customerTotal;

  final double playerGrossEarning;
  final double platformShare;
  final String pricingVersion;

  final int durationMinutes;

  final DateTime? cancelledAt;
  final String cancellationReason;

  bool get isActive => status == 'aktif' || status == 'active';

  bool get isCancelled =>
      status == 'iptal' ||
      status == 'cancelled' ||
      status == 'cancelledByCustomer' ||
      status == 'cancelledByPlayer' ||
      status == 'forceMajeure';

  bool get isCompleted => status == 'tamamlandi' || status == 'completed';

  bool get hasLocation => latitude != 0 && longitude != 0;

  bool get isFreeAccessEvent =>
      accessModel == 'free' &&
      !paymentRequired &&
      paymentStatus.trim().toLowerCase() == 'not_required';

  bool get hasPayment =>
      !isFreeAccessEvent &&
      (paymentRequired ||
          paymentId.isNotEmpty ||
          (_normalizedPaymentStatus != 'notrequired' &&
              _normalizedPaymentStatus != 'not_required' &&
              _normalizedPaymentStatus != 'notcreated' &&
              _normalizedPaymentStatus != 'not_created' &&
              _normalizedPaymentStatus.isNotEmpty));

  String get _normalizedPaymentStatus =>
      paymentStatus.trim().toLowerCase().replaceAll('_', '');

  static bool mapIsFreeAccess(Map<String, dynamic> data) {
    final String payment =
        data['paymentStatus']?.toString().trim().toLowerCase() ?? '';
    return data['accessModel']?.toString() == 'free' &&
        data['paymentRequired'] == false &&
        payment == 'not_required';
  }

  static bool mapIsTerminal(Map<String, dynamic> data) {
    final String status = (data['durum'] ?? data['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return status == 'iptal' ||
        status == 'expired' ||
        status == 'cancelled' ||
        status == 'completed' ||
        status == 'tamamlandi' ||
        status == 'tamamlandı';
  }

  static DateTime? mapEndAt(Map<String, dynamic> data) {
    DateTime? read(Object? value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      return null;
    }

    final DateTime? explicitEnd =
        read(data['endAt']) ??
        read(data['bitisTarihi']) ??
        read(data['eventEndDate']);
    if (explicitEnd != null) {
      return explicitEnd;
    }

    final DateTime? start = read(data['startAt']) ?? read(data['tarih']);
    if (start == null) {
      return null;
    }

    final int minutes = (data['durationMinutes'] as num?)?.toInt() ?? 0;
    if (minutes > 0) {
      return start.add(Duration(minutes: minutes));
    }

    return start.add(const Duration(hours: 1));
  }

  static bool mapHasEnded(Map<String, dynamic> data) {
    final DateTime? end = mapEndAt(data);
    if (end == null) {
      return false;
    }
    return !end.isAfter(DateTime.now());
  }

  static bool mapIsInactive(Map<String, dynamic> data) {
    return mapIsTerminal(data) || mapHasEnded(data);
  }

  DateTime get resolvedStartAt => startAt ?? eventDate;

  DateTime get resolvedEndAt {
    if (endAt != null) {
      return endAt!;
    }

    if (durationMinutes > 0) {
      return resolvedStartAt.add(Duration(minutes: durationMinutes));
    }

    return resolvedStartAt;
  }

  int get resolvedDurationMinutes {
    if (durationMinutes > 0) {
      return durationMinutes;
    }

    final difference = resolvedEndAt.difference(resolvedStartAt).inMinutes;
    return difference > 0 ? difference : 0;
  }

  double get resolvedDurationFactor {
    if (durationFactor > 0) {
      return durationFactor;
    }

    return GameCatalog.durationFactorForMinutes(resolvedDurationMinutes);
  }

  String get resolvedGameId {
    if (gameId.trim().isNotEmpty) {
      return gameId;
    }

    return GameCatalog.gameByLegacyValue(game)?.id ?? '';
  }

  String get resolvedGameName {
    if (gameName.trim().isNotEmpty) {
      return gameName;
    }

    final catalogGame =
        GameCatalog.gameById(resolvedGameId) ??
        GameCatalog.gameByLegacyValue(game);

    return catalogGame?.name ?? game;
  }

  String get resolvedCategoryId {
    if (categoryId.trim().isNotEmpty) {
      return categoryId;
    }

    return GameCatalog.categoryForGame(resolvedGameId)?.id ?? '';
  }

  String get resolvedCategoryName {
    if (categoryName.trim().isNotEmpty) {
      return categoryName;
    }

    return GameCatalog.categoryById(resolvedCategoryId)?.name ?? '';
  }

  double get resolvedBasePricePerPlayer {
    if (basePricePerPlayer > 0) {
      return basePricePerPlayer;
    }

    return GameCatalog.categoryById(resolvedCategoryId)?.basePricePerPlayer ??
        0;
  }

  double get resolvedCustomerTotal {
    if (customerTotal > 0) {
      return customerTotal;
    }

    return GameCatalog.calculateTotalPrice(
      gameId: resolvedGameId,
      playerCount: playerCount,
      durationMinutes: resolvedDurationMinutes,
    );
  }

  String get durationText {
    final minutes = resolvedDurationMinutes;
    if (minutes <= 0) {
      return '';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours == 0) {
      return '$remainingMinutes dakika';
    }

    if (remainingMinutes == 0) {
      return '$hours saat';
    }

    return '$hours saat $remainingMinutes dakika';
  }

  int get joinedPlayerCount {
    return participantIds.where((userId) => userId != creatorId).length;
  }

  int get remainingPlayerCount {
    final remaining = playerCount - joinedPlayerCount;
    return remaining < 0 ? 0 : remaining;
  }

  bool containsParticipant(String userId) {
    return participantIds.contains(userId);
  }

  bool isCreator(String userId) {
    return creatorId == userId;
  }

  factory EventModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return EventModel.fromMap(
      document.data() ?? const <String, dynamic>{},
      documentId: document.id,
    );
  }

  factory EventModel.fromMap(
    Map<String, dynamic> map, {
    String documentId = '',
  }) {
    final resolvedId = _firstString(map, const <String>[
      'eventId',
      'id',
    ], fallback: documentId);

    final legacyGameValue = _firstString(map, const <String>[
      'oyun',
      'game',
    ], fallback: '🎯 Etkinlik');

    final storedGameId = _firstString(map, const <String>['gameId', 'oyunId']);

    final catalogGame =
        GameCatalog.gameById(storedGameId) ??
        GameCatalog.gameByLegacyValue(legacyGameValue);

    final resolvedGameId = storedGameId.isNotEmpty
        ? storedGameId
        : catalogGame?.id ?? '';

    final resolvedGameName = _firstString(map, const <String>[
      'gameName',
      'oyunAdi',
    ], fallback: catalogGame?.name ?? legacyGameValue);

    final storedCategoryId = _firstString(map, const <String>[
      'categoryId',
      'kategoriId',
    ]);

    final catalogCategory =
        GameCatalog.categoryById(storedCategoryId) ??
        GameCatalog.categoryForGame(resolvedGameId);

    final resolvedCategoryId = storedCategoryId.isNotEmpty
        ? storedCategoryId
        : catalogCategory?.id ?? '';

    final resolvedCategoryName = _firstString(map, const <String>[
      'categoryName',
      'kategoriAdi',
      'kategori',
    ], fallback: catalogCategory?.name ?? '');

    final resolvedPlayerCount = _firstInt(map, const <String>[
      'oyuncuSayisi',
      'playerCount',
      'arananOyuncuSayisi',
    ], fallback: 1).clamp(1, 20);

    final legacyEventDate = _firstDate(map, const <String>[
      'tarih',
      'eventDate',
      'etkinlikTarihi',
    ]);

    final resolvedStartAt =
        _nullableDate(
          _firstValue(map, const <String>[
            'startAt',
            'baslangicTarihi',
            'baslangicZamani',
          ]),
        ) ??
        legacyEventDate;

    final storedDurationMinutes = _firstInt(map, const <String>[
      'durationMinutes',
      'sureDakika',
    ]);

    final storedEndAt = _nullableDate(
      _firstValue(map, const <String>['endAt', 'bitisTarihi', 'bitisZamani']),
    );

    final resolvedEndAt =
        storedEndAt ??
        (storedDurationMinutes > 0
            ? resolvedStartAt.add(Duration(minutes: storedDurationMinutes))
            : null);

    final calculatedDurationMinutes = storedDurationMinutes > 0
        ? storedDurationMinutes
        : resolvedEndAt?.difference(resolvedStartAt).inMinutes ?? 0;

    final storedBasePrice = _firstDouble(map, const <String>[
      'basePricePerPlayer',
      'kisiBasiTabanFiyat',
      'tabanFiyat',
    ]);

    final resolvedBasePrice = storedBasePrice > 0
        ? storedBasePrice
        : catalogCategory?.basePricePerPlayer ?? 0;

    final storedDurationFactor = _firstDouble(map, const <String>[
      'durationFactor',
      'sureKatsayisi',
    ]);

    final resolvedDurationFactor = storedDurationFactor > 0
        ? storedDurationFactor
        : GameCatalog.durationFactorForMinutes(calculatedDurationMinutes);

    final storedCustomerTotal = _firstDouble(map, const <String>[
      'customerTotal',
      'musteriToplami',
      'toplamFiyat',
      'totalPrice',
    ]);

    final calculatedCustomerTotal = storedCustomerTotal > 0
        ? storedCustomerTotal
        : GameCatalog.calculateTotalPrice(
            gameId: resolvedGameId,
            playerCount: resolvedPlayerCount,
            durationMinutes: calculatedDurationMinutes,
          );

    return EventModel(
      id: resolvedId,
      game: legacyGameValue,
      categoryId: resolvedCategoryId,
      categoryName: resolvedCategoryName,
      gameId: resolvedGameId,
      gameName: resolvedGameName,
      playerCount: resolvedPlayerCount,
      playerCountText: _firstString(map, const <String>[
        'oyuncuSayisiMetni',
        'playerCountText',
      ], fallback: '$resolvedPlayerCount Oyuncu'),
      memberPreference: _firstString(map, const <String>[
        'uyeTercihi',
        'memberPreference',
      ], fallback: 'Herkes'),
      description: _firstString(map, const <String>['aciklama', 'description']),
      city: _firstString(map, const <String>['sehir', 'city']),
      district: _firstString(map, const <String>['ilce', 'district']),
      neighborhood: _firstString(map, const <String>[
        'semt',
        'mahalle',
        'neighborhood',
      ]),
      address: _firstString(map, const <String>['adres', 'address']),
      latitude: _firstDouble(map, const <String>['latitude', 'enlem']),
      longitude: _firstDouble(map, const <String>['longitude', 'boylam']),
      eventDate: resolvedStartAt,
      startAt: resolvedStartAt,
      endAt: resolvedEndAt,
      creatorId: _firstString(map, const <String>[
        'olusturanUid',
        'creatorId',
        'olusturanId',
      ]),
      creatorProfileName: _firstString(map, const <String>[
        'olusturanProfilAdi',
        'creatorProfileName',
        'creatorName',
      ]),
      creatorProfilePhoto: _firstString(map, const <String>[
        'olusturanProfilFotografi',
        'creatorProfilePhoto',
        'creatorPhotoUrl',
      ]),
      creatorPlus: _firstBool(map, const <String>[
        'olusturanPlus',
        'creatorPlus',
      ]),
      creatorVerified: _firstBool(map, const <String>[
        'olusturanDogrulanmis',
        'creatorVerified',
      ]),
      participantIds: _firstStringList(map, const <String>[
        'katilanlar',
        'participantIds',
      ]),
      chatMemberIds: _firstStringList(map, const <String>[
        'chatMemberUids',
        'chatMemberIds',
      ]),
      favoriteCount: _firstInt(map, const <String>[
        'favoriSayisi',
        'favoriteCount',
      ]),
      status: _firstString(map, const <String>[
        'durum',
        'status',
      ], fallback: 'aktif'),
      createdAt: _firstDate(map, const <String>[
        'olusturmaTarihi',
        'createdAt',
      ]),
      updatedAt: _nullableDate(
        _firstValue(map, const <String>['guncellemeTarihi', 'updatedAt']),
      ),
      accessModel: _firstString(map, const <String>['accessModel']),
      paymentRequired: _firstBool(map, const <String>[
        'paymentRequired',
        'odemeGerekli',
      ]),
      paymentStatus: _firstString(map, const <String>[
        'paymentStatus',
        'odemeDurumu',
      ], fallback: 'notRequired'),
      paymentId: _firstString(map, const <String>['paymentId', 'odemeId']),
      basePricePerPlayer: resolvedBasePrice,
      durationFactor: resolvedDurationFactor,
      customerTotal: calculatedCustomerTotal,
      playerGrossEarning: _firstDouble(map, const <String>[
        'playerGrossEarning',
        'oyuncuBrutKazanci',
      ]),
      platformShare: _firstDouble(map, const <String>[
        'platformShare',
        'platformPayi',
      ]),
      pricingVersion: _firstString(map, const <String>[
        'pricingVersion',
        'fiyatlandirmaVersiyonu',
      ], fallback: 'v2'),
      selectedPlayerIds: _firstStringList(map, const <String>[
        'selectedPlayerIds',
        'secilenOyuncuIds',
      ]),
      durationMinutes: calculatedDurationMinutes,
      cancelledAt: _nullableDate(
        _firstValue(map, const <String>['cancelledAt', 'iptalTarihi']),
      ),
      cancellationReason: _firstString(map, const <String>[
        'cancellationReason',
        'iptalNedeni',
      ]),
    );
  }

  Map<String, dynamic> toMap() {
    final safeStartAt = resolvedStartAt;
    final safeEndAt = resolvedEndAt;
    final safeDurationMinutes = resolvedDurationMinutes;
    final safeDurationFactor = resolvedDurationFactor;
    final safeCustomerTotal = resolvedCustomerTotal;
    final safeGameId = resolvedGameId;
    final safeGameName = resolvedGameName;
    final safeCategoryId = resolvedCategoryId;
    final safeCategoryName = resolvedCategoryName;
    final safeBasePrice = resolvedBasePricePerPlayer;

    return <String, dynamic>{
      'eventId': id,

      // Yeni merkezi katalog alanları.
      'categoryId': safeCategoryId,
      'categoryName': safeCategoryName,
      'gameId': safeGameId,
      'gameName': safeGameName,

      // Eski ekran ve kayıtlarla uyumluluk.
      'oyun': safeGameName.isNotEmpty ? safeGameName : game,
      'oyuncuSayisi': playerCount,
      'oyuncuSayisiMetni': '$playerCount Oyuncu',
      'uyeTercihi': memberPreference,
      'aciklama': description,

      'sehir': city,
      'ilce': district,
      'privateLocationAvailable': hasLocation,
      'approxLatitude': latitude,
      'approxLongitude': longitude,

      // Yeni başlangıç / bitiş sistemi.
      'startAt': Timestamp.fromDate(safeStartAt),
      'endAt': Timestamp.fromDate(safeEndAt),
      'durationMinutes': safeDurationMinutes,

      // Eski sorguların çalışmaya devam etmesi için başlangıç
      // zamanı tarih alanına da yazılır.
      'tarih': Timestamp.fromDate(safeStartAt),

      'olusturanUid': creatorId,
      'olusturanProfilAdi': creatorProfileName,
      'olusturanProfilFotografi': creatorProfilePhoto,
      'olusturanPlus': creatorPlus,
      'olusturanDogrulanmis': creatorVerified,

      'katilanlar': participantIds,
      'chatMemberUids': chatMemberIds,
      'selectedPlayerIds': selectedPlayerIds,

      'favoriSayisi': favoriteCount,
      'durum': status,
      'olusturmaTarihi': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),

      'paymentRequired': paymentRequired,
      'paymentStatus': paymentStatus,
      'paymentId': paymentId,

      // Yeni fiyatlandırma alanları.
      'basePricePerPlayer': safeBasePrice,
      'durationFactor': safeDurationFactor,
      'customerTotal': safeCustomerTotal,
      'playerGrossEarning': playerGrossEarning,
      'platformShare': platformShare,
      'pricingVersion': pricingVersion,

      if (cancelledAt != null) 'cancelledAt': Timestamp.fromDate(cancelledAt!),
      'cancellationReason': cancellationReason,
    };
  }

  EventModel copyWith({
    String? id,
    String? game,
    String? categoryId,
    String? categoryName,
    String? gameId,
    String? gameName,
    int? playerCount,
    String? playerCountText,
    String? memberPreference,
    String? description,
    String? city,
    String? district,
    String? neighborhood,
    String? address,
    double? latitude,
    double? longitude,
    DateTime? eventDate,
    DateTime? startAt,
    DateTime? endAt,
    String? creatorId,
    String? creatorProfileName,
    String? creatorProfilePhoto,
    bool? creatorPlus,
    bool? creatorVerified,
    List<String>? participantIds,
    List<String>? chatMemberIds,
    List<String>? selectedPlayerIds,
    int? favoriteCount,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? paymentRequired,
    String? paymentStatus,
    String? accessModel,
    String? paymentId,
    double? basePricePerPlayer,
    double? durationFactor,
    double? customerTotal,
    double? playerGrossEarning,
    double? platformShare,
    String? pricingVersion,
    int? durationMinutes,
    DateTime? cancelledAt,
    String? cancellationReason,
  }) {
    return EventModel(
      id: id ?? this.id,
      game: game ?? this.game,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      gameId: gameId ?? this.gameId,
      gameName: gameName ?? this.gameName,
      playerCount: playerCount ?? this.playerCount,
      playerCountText: playerCountText ?? this.playerCountText,
      memberPreference: memberPreference ?? this.memberPreference,
      description: description ?? this.description,
      city: city ?? this.city,
      district: district ?? this.district,
      neighborhood: neighborhood ?? this.neighborhood,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      eventDate: eventDate ?? this.eventDate,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      creatorId: creatorId ?? this.creatorId,
      creatorProfileName: creatorProfileName ?? this.creatorProfileName,
      creatorProfilePhoto: creatorProfilePhoto ?? this.creatorProfilePhoto,
      creatorPlus: creatorPlus ?? this.creatorPlus,
      creatorVerified: creatorVerified ?? this.creatorVerified,
      participantIds: participantIds ?? this.participantIds,
      chatMemberIds: chatMemberIds ?? this.chatMemberIds,
      selectedPlayerIds: selectedPlayerIds ?? this.selectedPlayerIds,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paymentRequired: paymentRequired ?? this.paymentRequired,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      accessModel: accessModel ?? this.accessModel,
      paymentId: paymentId ?? this.paymentId,
      basePricePerPlayer: basePricePerPlayer ?? this.basePricePerPlayer,
      durationFactor: durationFactor ?? this.durationFactor,
      customerTotal: customerTotal ?? this.customerTotal,
      playerGrossEarning: playerGrossEarning ?? this.playerGrossEarning,
      platformShare: platformShare ?? this.platformShare,
      pricingVersion: pricingVersion ?? this.pricingVersion,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }

  static dynamic _firstValue(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      if (map.containsKey(key) && map[key] != null) {
        return map[key];
      }
    }

    return null;
  }

  static String _firstString(
    Map<String, dynamic> map,
    List<String> keys, {
    String fallback = '',
  }) {
    final value = _firstValue(map, keys);

    if (value == null) {
      return fallback;
    }

    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static int _firstInt(
    Map<String, dynamic> map,
    List<String> keys, {
    int fallback = 0,
  }) {
    final value = _firstValue(map, keys);

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _firstDouble(
    Map<String, dynamic> map,
    List<String> keys, {
    double fallback = 0,
  }) {
    final value = _firstValue(map, keys);

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static bool _firstBool(
    Map<String, dynamic> map,
    List<String> keys, {
    bool fallback = false,
  }) {
    final value = _firstValue(map, keys);

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final normalized = value?.toString().trim().toLowerCase() ?? '';

    if (normalized == 'true' || normalized == '1' || normalized == 'evet') {
      return true;
    }

    if (normalized == 'false' ||
        normalized == '0' ||
        normalized == 'hayir' ||
        normalized == 'hayır') {
      return false;
    }

    return fallback;
  }

  /// Kabul edilmiş oyuncu sayısı. Organizatör `katilanlar` içinde
  /// durabilir; kadro kaynağı `selectedPlayerIds` olduğu için sayıma girmez.
  static int acceptedPlayerCount(Map<String, dynamic> data) {
    final String creator = (data['olusturanUid'] ?? data['creatorUid'] ?? '')
        .toString()
        .trim();
    return _firstStringList(data, const <String>[
      'selectedPlayerIds',
    ]).where((String uid) => uid != creator).length;
  }

  static List<String> _firstStringList(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    final value = _firstValue(map, keys);

    if (value is! List) {
      return const <String>[];
    }

    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  static DateTime _firstDate(Map<String, dynamic> map, List<String> keys) {
    return _nullableDate(_firstValue(map, keys)) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime? _nullableDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}
