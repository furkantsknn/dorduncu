import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/language_controller.dart';
import '../widgets/game_catalog_icon.dart';
import 'event_detail_screen.dart';
import 'public_profile_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  Future<void> _removeFavorite(
    BuildContext context,
    String eventId,
    _FavoritesText text,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'favoriEtkinlikler': FieldValue.arrayRemove([eventId]),
      'guncellemeTarihi': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(text.removedFromFavorites)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageController.language,
      builder: (context, language, _) {
        final text = _FavoritesText(language);
        final user = FirebaseAuth.instance.currentUser;

        return Scaffold(
          appBar: AppBar(title: Text(text.favorites)),
          body: user == null
              ? Center(child: Text(text.loginRequired))
              : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .snapshots(),
                  builder: (context, userSnapshot) {
                    final ids = List<String>.from(
                      userSnapshot.data?.data()?['favoriEtkinlikler'] ??
                          const [],
                    );

                    if (ids.isEmpty) {
                      return _EmptyState(text: text);
                    }

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('events')
                          .snapshots(),
                      builder: (context, eventSnapshot) {
                        if (eventSnapshot.hasError) {
                          return Center(
                            child: Text(text.favoritesCouldNotBeLoaded),
                          );
                        }

                        if (!eventSnapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final docs = eventSnapshot.data!.docs
                            .where((doc) => ids.contains(doc.id))
                            .toList();

                        if (docs.isEmpty) {
                          return _EmptyState(text: text);
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: docs.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data();
                            final game = data['oyun']?.toString() ?? text.event;
                            final city = data['sehir']?.toString() ?? '';
                            final district = data['ilce']?.toString() ?? '';

                            return Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(14),
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xffFF9800),
                                  child: GameCatalogIcon(
                                    gameIdOrName: game,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  _clean(game),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      [district, city]
                                          .where((item) => item.isNotEmpty)
                                          .join(', '),
                                    ),
                                    const SizedBox(height: 4),
                                    InkWell(
                                      onTap: () {
                                        final uid =
                                            data['olusturanUid']?.toString() ??
                                            '';

                                        if (uid.isEmpty) return;

                                        Navigator.push(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (_) => PublicProfileScreen(
                                              userId: uid,
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        'Profili Gör',
                                        style: TextStyle(
                                          color: Color(0xffFF9800),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  tooltip: text.removeFromFavorites,
                                  onPressed: () =>
                                      _removeFavorite(context, doc.id, text),
                                  icon: const Icon(
                                    Icons.favorite,
                                    color: Colors.redAccent,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EventDetailScreen(
                                        eventId: doc.id,
                                        initialData: data,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
        );
      },
    );
  }

  static String _clean(String value) {
    return value.replaceFirst(RegExp(r'^[^A-Za-zÇĞİÖŞÜçğıöşü0-9]+\s*'), '');
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});

  final _FavoritesText text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite_border, size: 62),
            const SizedBox(height: 14),
            Text(
              text.noFavoriteEvents,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesText {
  const _FavoritesText(this.language);

  final AppLanguage language;

  String _value(String tr, String en, String de) {
    switch (language) {
      case AppLanguage.turkish:
        return tr;
      case AppLanguage.english:
        return en;
      case AppLanguage.german:
        return de;
    }
  }

  String get favorites => _value('Favoriler', 'Favorites', 'Favoriten');

  String get loginRequired => _value(
    'Giriş yapmalısın.',
    'You need to sign in.',
    'Du musst dich anmelden.',
  );

  String get favoritesCouldNotBeLoaded => _value(
    'Favoriler yüklenemedi.',
    'Favorites could not be loaded.',
    'Favoriten konnten nicht geladen werden.',
  );

  String get removeFromFavorites => _value(
    'Favoriden kaldır',
    'Remove from favorites',
    'Aus Favoriten entfernen',
  );

  String get removedFromFavorites => _value(
    'Favorilerden kaldırıldı.',
    'Removed from favorites.',
    'Aus den Favoriten entfernt.',
  );

  String get noFavoriteEvents => _value(
    'Henüz favori etkinliğin yok.',
    'You do not have any favorite events yet.',
    'Du hast noch keine favorisierten Veranstaltungen.',
  );

  String get event => _value('Etkinlik', 'Event', 'Veranstaltung');
}
