import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserBadgesScreen extends StatelessWidget {
  const UserBadgesScreen({
    super.key,
    required this.userId,
    this.isOwnProfile = false,
  });

  final String userId;
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isOwnProfile ? 'Rozetlerim' : 'Rozetleri',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('owned_badges')
            .orderBy('purchasedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _BadgesError();
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final documents = snapshot.data?.docs ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          if (documents.isEmpty) {
            return _EmptyBadges(
              isOwnProfile: isOwnProfile,
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            itemCount: documents.length,
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.88,
            ),
            itemBuilder: (context, index) {
              final data = documents[index].data();

              return _BadgeCollectionCard(
                title: data['title']?.toString().trim().isNotEmpty == true
                    ? data['title'].toString().trim()
                    : 'Oyun Rozeti',
                gameName:
                data['gameName']?.toString().trim() ?? '',
                emoji: data['emoji']?.toString().trim().isNotEmpty == true
                    ? data['emoji'].toString().trim()
                    : '🏅',
                imageUrl:
                data['imageUrl']?.toString().trim() ?? '',
                purchasedAt: data['purchasedAt'],
              );
            },
          );
        },
      ),
    );
  }
}

class _BadgeCollectionCard extends StatelessWidget {
  const _BadgeCollectionCard({
    required this.title,
    required this.gameName,
    required this.emoji,
    required this.imageUrl,
    required this.purchasedAt,
  });

  final String title;
  final String gameName;
  final String emoji;
  final String imageUrl;
  final dynamic purchasedAt;

  String _dateText() {
    if (purchasedAt is! Timestamp) {
      return 'Koleksiyonda';
    }

    final date = (purchasedAt as Timestamp).toDate();

    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.75),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Container(
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: imageUrl.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(22),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Text(
                            emoji,
                            style: const TextStyle(fontSize: 48),
                          ),
                        ),
                      )
                    : Text(
                        emoji,
                        style: const TextStyle(fontSize: 48),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            if (gameName.isNotEmpty) ...<Widget>[
              Text(
                gameName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xffC97A10),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Icon(
                  Icons.workspace_premium_rounded,
                  size: 14,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    _dateText(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBadges extends StatelessWidget {
  const _EmptyBadges({
    required this.isOwnProfile,
  });

  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium_outlined,
              size: 74,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              isOwnProfile
                  ? 'Henüz rozetin yok'
                  : 'Bu kullanıcının henüz rozeti yok',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              isOwnProfile
                  ? 'Marketten aldığın oyun rozetleri burada görünür.'
                  : 'Satın alınan oyun rozetleri burada görünür.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgesError extends StatelessWidget {
  const _BadgesError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Rozetler yüklenemedi.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
