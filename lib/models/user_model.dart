import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/game_catalog.dart';

class UserGameSkill {
  const UserGameSkill({
    required this.gameId,
    required this.gameName,
    required this.categoryId,
    required this.categoryName,
    required this.level,
    required this.levelLabel,
  });

  final String gameId;
  final String gameName;
  final String categoryId;
  final String categoryName;

  /// Kullanıcının seçtiği sade seviye yüzdesi:
  /// Başlangıç: 30, Orta: 60, İleri: 90.
  final int level;
  final String levelLabel;

  double get progress => (level.clamp(0, 100)) / 100;

  GameDefinition? get catalogGame => GameCatalog.gameById(gameId);

  GameCategoryDefinition? get catalogCategory =>
      GameCatalog.categoryById(categoryId);

  factory UserGameSkill.fromMap(
      Map<String, dynamic> map, {
        String fallbackGameId = '',
      }) {
    final storedGameId = _firstString(
      map,
      const <String>[
        'gameId',
        'oyunId',
        'id',
      ],
      fallback: fallbackGameId,
    );

    final legacyGameName = _firstString(
      map,
      const <String>[
        'gameName',
        'oyunAdi',
        'name',
        'oyun',
      ],
    );

    final catalogGame =
        GameCatalog.gameById(storedGameId) ??
            GameCatalog.gameByLegacyValue(legacyGameName);

    final resolvedGameId =
    storedGameId.isNotEmpty ? storedGameId : catalogGame?.id ?? '';

    final resolvedGameName =
    legacyGameName.isNotEmpty
        ? legacyGameName
        : catalogGame?.name ?? '';

    final storedCategoryId = _firstString(
      map,
      const <String>[
        'categoryId',
        'kategoriId',
      ],
    );

    final catalogCategory =
        GameCatalog.categoryById(storedCategoryId) ??
            GameCatalog.categoryForGame(resolvedGameId);

    final resolvedCategoryId =
    storedCategoryId.isNotEmpty
        ? storedCategoryId
        : catalogCategory?.id ?? '';

    final resolvedCategoryName = _firstString(
      map,
      const <String>[
        'categoryName',
        'kategoriAdi',
        'kategori',
      ],
      fallback: catalogCategory?.name ?? '',
    );

    final rawLevel = _firstInt(
      map,
      const <String>[
        'level',
        'seviye',
        'levelPercent',
        'seviyeYuzdesi',
      ],
      fallback: 30,
    );

    final skillLevel = GameCatalog.skillLevelForValue(rawLevel);

    return UserGameSkill(
      gameId: resolvedGameId,
      gameName: resolvedGameName,
      categoryId: resolvedCategoryId,
      categoryName: resolvedCategoryName,
      level: skillLevel.value,
      levelLabel: _firstString(
        map,
        const <String>[
          'levelLabel',
          'seviyeAdi',
        ],
        fallback: skillLevel.label,
      ),
    );
  }

  factory UserGameSkill.fromLegacyGame(String value) {
    final catalogGame = GameCatalog.gameByLegacyValue(value);
    final category =
    GameCatalog.categoryById(catalogGame?.categoryId);

    return UserGameSkill(
      gameId: catalogGame?.id ?? GameCatalog.normalizeId(value),
      gameName: catalogGame?.name ?? value,
      categoryId: category?.id ?? '',
      categoryName: category?.name ?? '',
      level: 30,
      levelLabel: 'Başlangıç',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'gameId': gameId,
      'gameName': gameName,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'level': level,
      'levelLabel': levelLabel,
    };
  }

  UserGameSkill copyWith({
    String? gameId,
    String? gameName,
    String? categoryId,
    String? categoryName,
    int? level,
    String? levelLabel,
  }) {
    final resolvedLevel = level ?? this.level;
    final resolvedDefinition =
    GameCatalog.skillLevelForValue(resolvedLevel);

    return UserGameSkill(
      gameId: gameId ?? this.gameId,
      gameName: gameName ?? this.gameName,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      level: resolvedDefinition.value,
      levelLabel:
      levelLabel ?? resolvedDefinition.label,
    );
  }

  static dynamic _firstValue(
      Map<String, dynamic> map,
      List<String> keys,
      ) {
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
}

class UserModel {
  const UserModel({
    required this.uid,
    required this.ad,
    required this.soyad,
    required this.profilAdi,
    required this.telefon,
    required this.sehir,
    required this.latitude,
    required this.longitude,
    required this.puan,
    required this.plus,
    required this.oyunlar,
    this.plusPlan = '',
    this.plusExpiresAt,
    this.ilce = '',
    this.aktifSehir = '',
    this.profilFotografi = '',
    this.avatarUrl = '',
    this.hakkimda = '',
    this.email = '',
    this.verified = false,
    this.verificationStatus = '',
    this.oyuncuRozeti = false,
    this.accountStatus = 'active',
    this.lastLoginPlatform = '',
    this.lastLoginAppVersion = '',
    this.lastDeviceId = '',
    this.activeSessionId = '',
    this.favoriEtkinlikler = const <String>[],
    this.gameSkills = const <String, UserGameSkill>{},
    this.badges = const <String>[],
    this.completedEventCount = 0,
    this.ratingCount = 0,
    this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
  });

  final String uid;

  final String ad;
  final String soyad;
  final String profilAdi;

  /// Özel bilgidir. Herkese açık profil haritasına yazılmaz.
  final String telefon;

  /// Özel bilgidir. Herkese açık profil haritasına yazılmaz.
  final String email;

  final String sehir;
  final String aktifSehir;
  final String ilce;

  final String profilFotografi;
  final String avatarUrl;
  final String hakkimda;

  final double latitude;
  final double longitude;

  final double puan;
  final int ratingCount;
  final int completedEventCount;

  final bool plus;
  final String plusPlan;
  final DateTime? plusExpiresAt;
  final bool verified;
  final String verificationStatus;
  final bool oyuncuRozeti;

  final String accountStatus;
  final String lastLoginPlatform;
  final String lastLoginAppVersion;
  final String lastDeviceId;
  final String activeSessionId;

  /// Eski ekranlar ve Firestore arrayContains sorguları için korunur.
  ///
  /// Yeni kodlarda oyun kontrolü [gameSkills] üzerinden yapılmalıdır.
  final List<String> oyunlar;

  /// Anahtar merkezi katalogdaki gameId değeridir.
  final Map<String, UserGameSkill> gameSkills;

  final List<String> badges;
  final List<String> favoriEtkinlikler;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;

  bool get isPlusActive {
    final DateTime? expiry = plusExpiresAt;

    if (!plus || expiry == null) {
      return false;
    }

    return expiry.isAfter(DateTime.now());
  }

  int get plusRemainingDays {
    final DateTime? expiry = plusExpiresAt;

    if (!isPlusActive || expiry == null) {
      return 0;
    }

    final Duration difference = expiry.difference(DateTime.now());
    return difference.inHours <= 0
        ? 0
        : (difference.inHours / 24).ceil();
  }

  String get plusPlanLabel {
    switch (plusPlan.trim().toLowerCase()) {
      case 'monthly':
        return '1 Aylık Plus';
      case 'quarterly':
        return '3 Aylık Plus';
      default:
        return 'Dört. Plus';
    }
  }

  bool get isActive => accountStatus == 'active';
  bool get isPendingProfile => accountStatus == 'pendingProfile';
  bool get isSuspended => accountStatus == 'suspended';
  bool get isBanned => accountStatus == 'banned';
  bool get isDeletionRequested => accountStatus == 'deletionRequested';
  bool get isDeleted => accountStatus == 'deleted';
  bool get canAccessApp => isActive;

  String get fullName {
    return <String>[ad.trim(), soyad.trim()]
        .where((part) => part.isNotEmpty)
        .join(' ');
  }

  String get displayName {
    if (profilAdi.trim().isNotEmpty) {
      return profilAdi.trim();
    }

    if (fullName.isNotEmpty) {
      return fullName;
    }

    return 'Kullanıcı';
  }

  String get resolvedCity {
    if (aktifSehir.trim().isNotEmpty) {
      return aktifSehir.trim();
    }
    return sehir.trim();
  }

  bool get hasProfilePhoto =>
      profilFotografi.trim().isNotEmpty;

  bool get hasAvatar => avatarUrl.trim().isNotEmpty;

  bool get hasProfileImage => hasProfilePhoto || hasAvatar;

  bool get hasPublicGameProfile => gameSkills.isNotEmpty;

  List<UserGameSkill> get sortedGameSkills {
    final values = gameSkills.values.toList();
    values.sort(
          (a, b) => a.gameName.compareTo(b.gameName),
    );
    return values;
  }

  List<String> get gameIds => gameSkills.keys.toList();

  bool hasGame(String gameIdOrName) {
    final catalogGame =
        GameCatalog.gameById(gameIdOrName) ??
            GameCatalog.gameByLegacyValue(gameIdOrName);

    if (catalogGame != null &&
        gameSkills.containsKey(catalogGame.id)) {
      return true;
    }

    final normalizedValue =
    GameCatalog.normalizeId(gameIdOrName);

    return oyunlar.any((legacyGame) {
      final resolved =
      GameCatalog.gameByLegacyValue(legacyGame);

      if (catalogGame != null && resolved != null) {
        return resolved.id == catalogGame.id;
      }

      return GameCatalog.normalizeId(legacyGame) ==
          normalizedValue;
    });
  }

  bool canApplyToGame(String gameIdOrName) {
    return hasGame(gameIdOrName);
  }

  UserGameSkill? skillForGame(String gameIdOrName) {
    final catalogGame =
        GameCatalog.gameById(gameIdOrName) ??
            GameCatalog.gameByLegacyValue(gameIdOrName);

    if (catalogGame != null) {
      final directSkill = gameSkills[catalogGame.id];
      if (directSkill != null) {
        return directSkill;
      }
    }

    final normalizedValue =
    GameCatalog.normalizeId(gameIdOrName);

    for (final skill in gameSkills.values) {
      if (skill.gameId == normalizedValue ||
          GameCatalog.normalizeId(skill.gameName) ==
              normalizedValue) {
        return skill;
      }
    }

    if (hasGame(gameIdOrName)) {
      return UserGameSkill.fromLegacyGame(gameIdOrName);
    }

    return null;
  }

  factory UserModel.fromDocument(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    return UserModel.fromMap(
      document.data() ?? const <String, dynamic>{},
      documentId: document.id,
    );
  }

  factory UserModel.fromMap(
      Map<String, dynamic> map, {
        String documentId = '',
      }) {
    final legacyGames = _firstStringList(
      map,
      const <String>[
        'oyunlar',
        'games',
      ],
    );

    final parsedSkills = _parseGameSkills(
      _firstValue(
        map,
        const <String>[
          'gameSkills',
          'oyunSeviyeleri',
          'sporSeviyeleri',
        ],
      ),
    );

    /// Eski kullanıcı kayıtlarında yalnızca "oyunlar" listesi varsa
    /// onları Başlangıç (%30) seviyesinde yeni yapıya taşır.
    for (final legacyGame in legacyGames) {
      final skill =
      UserGameSkill.fromLegacyGame(legacyGame);

      if (skill.gameId.isNotEmpty) {
        parsedSkills.putIfAbsent(
          skill.gameId,
              () => skill,
        );
      }
    }

    final resolvedLegacyGames = <String>{
      ...legacyGames,
      ...parsedSkills.values.map((skill) => skill.gameName),
    }.where((value) => value.trim().isNotEmpty).toList();

    return UserModel(
      uid: _firstString(
        map,
        const <String>[
          'uid',
          'userId',
        ],
        fallback: documentId,
      ),
      ad: _firstString(
        map,
        const <String>[
          'ad',
          'firstName',
        ],
      ),
      soyad: _firstString(
        map,
        const <String>[
          'soyad',
          'lastName',
        ],
      ),
      profilAdi: _firstString(
        map,
        const <String>[
          'profilAdi',
          'profileName',
          'displayName',
        ],
      ),
      telefon: _firstString(
        map,
        const <String>[
          'telefon',
          'phone',
          'phoneNumber',
        ],
      ),
      email: _firstString(
        map,
        const <String>[
          'email',
          'eposta',
        ],
      ),
      sehir: _firstString(
        map,
        const <String>[
          'sehir',
          'city',
        ],
      ),
      aktifSehir: _firstString(
        map,
        const <String>[
          'aktifSehir',
          'activeCity',
        ],
      ),
      ilce: _firstString(
        map,
        const <String>[
          'ilce',
          'district',
        ],
      ),
      profilFotografi: _firstString(
        map,
        const <String>[
          'profilFotografi',
          'profilePhoto',
          'profilePhotoUrl',
          'photoUrl',
        ],
      ),
      avatarUrl: _firstString(
        map,
        const <String>[
          'avatarUrl',
          'avatar',
          'profileAvatarUrl',
        ],
      ),
      hakkimda: _firstString(
        map,
        const <String>[
          'hakkimda',
          'about',
          'bio',
        ],
      ),
      latitude: _firstDouble(
        map,
        const <String>[
          'latitude',
          'enlem',
        ],
      ),
      longitude: _firstDouble(
        map,
        const <String>[
          'longitude',
          'boylam',
        ],
      ),
      puan: _firstDouble(
        map,
        const <String>[
          'puan',
          'rating',
          'ratingAverage',
        ],
      ),
      ratingCount: _firstInt(
        map,
        const <String>[
          'ratingCount',
          'puanSayisi',
          'degerlendirmeSayisi',
        ],
      ),
      completedEventCount: _firstInt(
        map,
        const <String>[
          'completedEventCount',
          'tamamlananEtkinlikSayisi',
        ],
      ),
      plus: _firstBool(
        map,
        const <String>[
          'plus',
          'isPlus',
        ],
      ),
      plusPlan: _firstString(
        map,
        const <String>[
          'plusPlan',
          'subscriptionPlan',
        ],
      ),
      plusExpiresAt: _nullableDate(
        _firstValue(
          map,
          const <String>[
            'plusExpiresAt',
            'subscriptionExpiresAt',
          ],
        ),
      ),
      verified: _firstBool(
        map,
        const <String>[
          'verified',
          'dogrulanmis',
        ],
      ),
      verificationStatus: _firstString(
        map,
        const <String>[
          'verificationStatus',
          'dogrulamaDurumu',
        ],
      ),
      oyuncuRozeti: _firstBool(
        map,
        const <String>[
          'oyuncuRozeti',
          'playerBadge',
        ],
      ),
      accountStatus: _firstString(
        map,
        const <String>[
          'accountStatus',
          'hesapDurumu',
        ],
        fallback: 'active',
      ),
      lastLoginPlatform: _firstString(
        map,
        const <String>[
          'lastLoginPlatform',
          'sonGirisPlatformu',
        ],
      ),
      lastLoginAppVersion: _firstString(
        map,
        const <String>[
          'lastLoginAppVersion',
          'sonGirisUygulamaSurumu',
        ],
      ),
      lastDeviceId: _firstString(
        map,
        const <String>[
          'lastDeviceId',
          'sonCihazId',
        ],
      ),
      activeSessionId: _firstString(
        map,
        const <String>[
          'activeSessionId',
          'aktifOturumId',
        ],
      ),
      oyunlar: resolvedLegacyGames,
      gameSkills: parsedSkills,
      badges: _firstStringList(
        map,
        const <String>[
          'badges',
          'rozetler',
        ],
      ),
      favoriEtkinlikler: _firstStringList(
        map,
        const <String>[
          'favoriEtkinlikler',
          'favoriteEventIds',
        ],
      ),
      createdAt: _nullableDate(
        _firstValue(
          map,
          const <String>[
            'olusturmaTarihi',
            'createdAt',
          ],
        ),
      ),
      updatedAt: _nullableDate(
        _firstValue(
          map,
          const <String>[
            'guncellemeTarihi',
            'updatedAt',
          ],
        ),
      ),
      lastLoginAt: _nullableDate(
        _firstValue(
          map,
          const <String>[
            'lastLoginAt',
            'sonGirisTarihi',
          ],
        ),
      ),
    );
  }

  /// Kullanıcının kendi belgesine yazılacak tam veri.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
      'ad': ad,
      'soyad': soyad,
      'profilAdi': profilAdi,
      'telefon': telefon,
      'email': email,
      'sehir': sehir,
      'aktifSehir':
      aktifSehir.trim().isNotEmpty ? aktifSehir : sehir,
      'ilce': ilce,
      'profilFotografi': profilFotografi,
      'avatarUrl': avatarUrl,
      'hakkimda': hakkimda,
      'latitude': latitude,
      'longitude': longitude,
      'puan': puan,
      'ratingCount': ratingCount,
      'completedEventCount': completedEventCount,
      'plus': plus,
      'isPlus': plus,
      'plusPlan': plusPlan,
      if (plusExpiresAt != null)
        'plusExpiresAt': Timestamp.fromDate(plusExpiresAt!),
      'verified': verified,
      'verificationStatus': verificationStatus,
      'oyuncuRozeti': oyuncuRozeti,
      'accountStatus': accountStatus,
      'lastLoginPlatform': lastLoginPlatform,
      'lastLoginAppVersion': lastLoginAppVersion,
      'lastDeviceId': lastDeviceId,
      'activeSessionId': activeSessionId,

      // Eski arrayContains sorgularının çalışmaya devam etmesi için.
      'oyunlar': gameSkills.isNotEmpty
          ? gameSkills.values
          .map((skill) => skill.gameName)
          .toSet()
          .toList()
          : oyunlar,

      // Yeni seviye sistemi.
      'gameIds': gameSkills.keys.toList(),
      'gameSkills': <String, dynamic>{
        for (final entry in gameSkills.entries)
          entry.key: entry.value.toMap(),
      },

      'badges': badges,
      'favoriEtkinlikler': favoriEtkinlikler,

      if (createdAt != null)
        'olusturmaTarihi': Timestamp.fromDate(createdAt!),
      if (updatedAt != null)
        'guncellemeTarihi': Timestamp.fromDate(updatedAt!),
      if (lastLoginAt != null)
        'lastLoginAt': Timestamp.fromDate(lastLoginAt!),
    };
  }

  /// Başka kullanıcıların görebileceği güvenli profil verisi.
  ///
  /// Telefon, e-posta, koordinat ve özel hesap bilgileri dahil edilmez.
  Map<String, dynamic> toPublicMap() {
    return <String, dynamic>{
      'uid': uid,
      'profilAdi': displayName,
      'profilFotografi': profilFotografi,
      'avatarUrl': avatarUrl,
      'sehir': resolvedCity,
      'hakkimda': hakkimda,
      'puan': puan,
      'ratingCount': ratingCount,
      'completedEventCount': completedEventCount,
      'plus': isPlusActive,
      'isPlus': isPlusActive,
      'plusPlan': plusPlan,
      if (plusExpiresAt != null)
        'plusExpiresAt': Timestamp.fromDate(plusExpiresAt!),
      'verified': verified,
      'oyuncuRozeti': oyuncuRozeti,
      'gameSkills': <String, dynamic>{
        for (final entry in gameSkills.entries)
          entry.key: entry.value.toMap(),
      },
      'badges': badges,
    };
  }

  UserModel copyWith({
    String? uid,
    String? ad,
    String? soyad,
    String? profilAdi,
    String? telefon,
    String? email,
    String? sehir,
    String? aktifSehir,
    String? ilce,
    String? profilFotografi,
    String? avatarUrl,
    String? hakkimda,
    double? latitude,
    double? longitude,
    double? puan,
    int? ratingCount,
    int? completedEventCount,
    bool? plus,
    String? plusPlan,
    DateTime? plusExpiresAt,
    bool? verified,
    String? verificationStatus,
    bool? oyuncuRozeti,
    String? accountStatus,
    String? lastLoginPlatform,
    String? lastLoginAppVersion,
    String? lastDeviceId,
    String? activeSessionId,
    List<String>? oyunlar,
    Map<String, UserGameSkill>? gameSkills,
    List<String>? badges,
    List<String>? favoriEtkinlikler,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      ad: ad ?? this.ad,
      soyad: soyad ?? this.soyad,
      profilAdi: profilAdi ?? this.profilAdi,
      telefon: telefon ?? this.telefon,
      email: email ?? this.email,
      sehir: sehir ?? this.sehir,
      aktifSehir: aktifSehir ?? this.aktifSehir,
      ilce: ilce ?? this.ilce,
      profilFotografi:
      profilFotografi ?? this.profilFotografi,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      hakkimda: hakkimda ?? this.hakkimda,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      puan: puan ?? this.puan,
      ratingCount: ratingCount ?? this.ratingCount,
      completedEventCount:
      completedEventCount ?? this.completedEventCount,
      plus: plus ?? this.plus,
      plusPlan: plusPlan ?? this.plusPlan,
      plusExpiresAt: plusExpiresAt ?? this.plusExpiresAt,
      verified: verified ?? this.verified,
      verificationStatus:
      verificationStatus ?? this.verificationStatus,
      oyuncuRozeti: oyuncuRozeti ?? this.oyuncuRozeti,
      accountStatus: accountStatus ?? this.accountStatus,
      lastLoginPlatform:
      lastLoginPlatform ?? this.lastLoginPlatform,
      lastLoginAppVersion:
      lastLoginAppVersion ?? this.lastLoginAppVersion,
      lastDeviceId: lastDeviceId ?? this.lastDeviceId,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      oyunlar: oyunlar ?? this.oyunlar,
      gameSkills: gameSkills ?? this.gameSkills,
      badges: badges ?? this.badges,
      favoriEtkinlikler:
      favoriEtkinlikler ?? this.favoriEtkinlikler,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  static Map<String, UserGameSkill> _parseGameSkills(
      dynamic value,
      ) {
    final result = <String, UserGameSkill>{};

    if (value is Map) {
      value.forEach((rawKey, rawValue) {
        final key = rawKey.toString();

        if (rawValue is Map) {
          final skill = UserGameSkill.fromMap(
            Map<String, dynamic>.from(rawValue),
            fallbackGameId: key,
          );

          if (skill.gameId.isNotEmpty) {
            result[skill.gameId] = skill;
          }
        }
      });

      return result;
    }

    if (value is List) {
      for (final rawValue in value) {
        if (rawValue is! Map) {
          continue;
        }

        final skill = UserGameSkill.fromMap(
          Map<String, dynamic>.from(rawValue),
        );

        if (skill.gameId.isNotEmpty) {
          result[skill.gameId] = skill;
        }
      }
    }

    return result;
  }

  static dynamic _firstValue(
      Map<String, dynamic> map,
      List<String> keys,
      ) {
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

    return double.tryParse(value?.toString() ?? '') ??
        fallback;
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

    final normalized =
        value?.toString().trim().toLowerCase() ?? '';

    if (normalized == 'true' ||
        normalized == '1' ||
        normalized == 'evet') {
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