import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../utils/game_catalog.dart';

class PlayerService {
  PlayerService({
    FirebaseFirestore? firestore,
  }) : _firestore =
      firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>>
  get _publicProfilesCollection =>
      _firestore.collection('public_profiles');

  Future<List<UserModel>> getPlayersByGame(
      String gameIdOrName, {
        String? city,
        int? minimumSkillLevel,
        bool onlyWithPlayerBadge = true,
        bool onlyVerified = false,
        int limit = 100,
      }) async {
    final String normalizedGame =
    gameIdOrName.trim();

    if (normalizedGame.isEmpty) {
      return <UserModel>[];
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot =
    await _publicProfilesCollection.limit(limit).get();

    return _filterAndSortPlayers(
      snapshot.docs
          .map(UserModel.fromDocument)
          .toList(),
      gameIdOrName: normalizedGame,
      city: city,
      minimumSkillLevel: minimumSkillLevel,
      onlyWithPlayerBadge: onlyWithPlayerBadge,
      onlyVerified: onlyVerified,
    );
  }

  Stream<List<UserModel>> watchPlayersByGame(
      String gameIdOrName, {
        String? city,
        int? minimumSkillLevel,
        bool onlyWithPlayerBadge = true,
        bool onlyVerified = false,
        int limit = 100,
      }) {
    final String normalizedGame =
    gameIdOrName.trim();

    if (normalizedGame.isEmpty) {
      return Stream<List<UserModel>>.value(
        <UserModel>[],
      );
    }

    return _publicProfilesCollection
        .limit(limit)
        .snapshots()
        .map(
          (
          QuerySnapshot<Map<String, dynamic>>
          snapshot,
          ) {
        return _filterAndSortPlayers(
          snapshot.docs
              .map(UserModel.fromDocument)
              .toList(),
          gameIdOrName: normalizedGame,
          city: city,
          minimumSkillLevel:
          minimumSkillLevel,
          onlyWithPlayerBadge:
          onlyWithPlayerBadge,
          onlyVerified: onlyVerified,
        );
      },
    );
  }

  Future<List<UserModel>> getAllPlayers({
    String? city,
    bool onlyWithPlayerBadge = true,
    bool onlyVerified = false,
    int limit = 100,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
    await _publicProfilesCollection.limit(limit).get();

    return _filterAndSortPlayers(
      snapshot.docs
          .map(UserModel.fromDocument)
          .toList(),
      city: city,
      onlyWithPlayerBadge: onlyWithPlayerBadge,
      onlyVerified: onlyVerified,
    );
  }

  Stream<List<UserModel>> watchAllPlayers({
    String? city,
    bool onlyWithPlayerBadge = true,
    bool onlyVerified = false,
    int limit = 100,
  }) {
    return _publicProfilesCollection
        .limit(limit)
        .snapshots()
        .map(
          (
          QuerySnapshot<Map<String, dynamic>>
          snapshot,
          ) {
        return _filterAndSortPlayers(
          snapshot.docs
              .map(UserModel.fromDocument)
              .toList(),
          city: city,
          onlyWithPlayerBadge:
          onlyWithPlayerBadge,
          onlyVerified: onlyVerified,
        );
      },
    );
  }

  Future<UserModel?> getPlayer(
      String uid,
      ) async {
    final String normalizedUid = uid.trim();

    if (normalizedUid.isEmpty) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>>
    snapshot = await _publicProfilesCollection
        .doc(normalizedUid)
        .get();

    if (!snapshot.exists) {
      return null;
    }

    return UserModel.fromDocument(snapshot);
  }

  Stream<UserModel?> watchPlayer(
      String uid,
      ) {
    final String normalizedUid = uid.trim();

    if (normalizedUid.isEmpty) {
      return Stream<UserModel?>.value(null);
    }

    return _publicProfilesCollection
        .doc(normalizedUid)
        .snapshots()
        .map(
          (
          DocumentSnapshot<Map<String, dynamic>>
          snapshot,
          ) {
        if (!snapshot.exists) {
          return null;
        }

        return UserModel.fromDocument(snapshot);
      },
    );
  }

  List<UserModel> _filterAndSortPlayers(
      List<UserModel> players, {
        String? gameIdOrName,
        String? city,
        int? minimumSkillLevel,
        bool onlyWithPlayerBadge = true,
        bool onlyVerified = false,
      }) {
    final String normalizedCity =
    _normalize(city ?? '');

    final GameDefinition? selectedGame =
    gameIdOrName == null
        ? null
        : GameCatalog.gameById(
      gameIdOrName,
    ) ??
        GameCatalog.gameByLegacyValue(
          gameIdOrName,
        );

    final String resolvedGameIdOrName =
        selectedGame?.id ??
            gameIdOrName?.trim() ??
            '';

    final int? normalizedMinimumSkill =
    minimumSkillLevel == null
        ? null
        : _normalizeSkillLevel(
      minimumSkillLevel,
    );

    final List<UserModel> filtered =
    players.where((UserModel player) {
      if (player.uid.trim().isEmpty) {
        return false;
      }

      if (onlyWithPlayerBadge &&
          !player.oyuncuRozeti) {
        return false;
      }

      if (onlyVerified && !player.verified) {
        return false;
      }

      if (normalizedCity.isNotEmpty &&
          _normalize(player.resolvedCity) !=
              normalizedCity) {
        return false;
      }

      if (resolvedGameIdOrName.isNotEmpty &&
          !player.hasGame(resolvedGameIdOrName)) {
        return false;
      }

      if (normalizedMinimumSkill != null &&
          resolvedGameIdOrName.isNotEmpty) {
        final UserGameSkill? skill =
        player.skillForGame(
          resolvedGameIdOrName,
        );

        if (skill == null ||
            skill.level <
                normalizedMinimumSkill) {
          return false;
        }
      }

      return true;
    }).toList();

    filtered.sort(
          (UserModel a, UserModel b) {
        final int badgeComparison =
        _boolSortValue(b.oyuncuRozeti)
            .compareTo(
          _boolSortValue(a.oyuncuRozeti),
        );

        if (badgeComparison != 0) {
          return badgeComparison;
        }

        final int verifiedComparison =
        _boolSortValue(b.verified).compareTo(
          _boolSortValue(a.verified),
        );

        if (verifiedComparison != 0) {
          return verifiedComparison;
        }

        final int ratingComparison =
        b.puan.compareTo(a.puan);

        if (ratingComparison != 0) {
          return ratingComparison;
        }

        final int completedComparison =
        b.completedEventCount.compareTo(
          a.completedEventCount,
        );

        if (completedComparison != 0) {
          return completedComparison;
        }

        return a.displayName
            .toLowerCase()
            .compareTo(
          b.displayName.toLowerCase(),
        );
      },
    );

    return filtered;
  }

  int _normalizeSkillLevel(
      int level,
      ) {
    if (level >= 90) {
      return 90;
    }

    if (level >= 60) {
      return 60;
    }

    return 30;
  }

  int _boolSortValue(
      bool value,
      ) {
    return value ? 1 : 0;
  }

  String _normalize(
      String value,
      ) {
    return GameCatalog.normalizeId(
      value.trim(),
    );
  }
}