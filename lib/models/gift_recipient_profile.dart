class GiftRecipientProfile {
  const GiftRecipientProfile({
    required this.uid,
    required this.displayName,
    this.avatarUrl = '',
  });

  final String uid;
  final String displayName;
  final String avatarUrl;

  bool get isDisplayable =>
      uid.trim().isNotEmpty && displayName.trim().isNotEmpty;
}
