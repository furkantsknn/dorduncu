import '../models/gift_recipient_profile.dart';
import 'friend_service.dart';
import 'user_service.dart';

class GiftRecipientService {
  GiftRecipientService({UserService? users}) : _users = users ?? UserService();

  final UserService _users;

  Future<GiftRecipientProfile?> load(String uid) async {
    final normalized = uid.trim();
    if (normalized.isEmpty) return null;
    final user = await _users.getUser(normalized);
    if (user == null || user.displayName.trim().isEmpty) return null;
    return GiftRecipientProfile(
      uid: normalized,
      displayName: user.displayName.trim(),
      avatarUrl: user.profilFotografi.trim().isNotEmpty
          ? user.profilFotografi.trim()
          : user.avatarUrl.trim(),
    );
  }

  Future<List<GiftRecipientProfile>> loadFriends() async {
    final ids = await FriendService.instance.friendIds();
    final resolved = await Future.wait(ids.map(load));
    return resolved.whereType<GiftRecipientProfile>().toList(growable: false);
  }
}
