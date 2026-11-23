import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Adds or removes the event in `users/{uid}.favoriEtkinlikler`.
///
/// The same list feeds the Favorites screen.
class FavoriteEventButton extends StatefulWidget {
  const FavoriteEventButton({required this.eventId, super.key});

  final String eventId;

  @override
  State<FavoriteEventButton> createState() => _FavoriteEventButtonState();
}

class _FavoriteEventButtonState extends State<FavoriteEventButton> {
  bool _saving = false;

  Future<void> _toggle(String uid, bool favorite) async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        <String, Object>{
          'favoriEtkinlikler': favorite
              ? FieldValue.arrayRemove(<String>[widget.eventId])
              : FieldValue.arrayUnion(<String>[widget.eventId]),
          'guncellemeTarihi': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _favoriteText(
                context,
                tr: 'Favori işlemi kaydedilemedi.',
                en: 'The favorite action could not be saved.',
                de: 'Die Favoritenaktion konnte nicht gespeichert werden.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.eventId.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Object? raw = snapshot.data?.data()?['favoriEtkinlikler'];
            final bool favorite = raw is List && raw.contains(widget.eventId);
            return IconButton(
              tooltip: favorite
                  ? _favoriteText(
                      context,
                      tr: 'Favoriden kaldır',
                      en: 'Remove from favorites',
                      de: 'Aus Favoriten entfernen',
                    )
                  : _favoriteText(
                      context,
                      tr: 'Favorilere ekle',
                      en: 'Add to favorites',
                      de: 'Zu Favoriten hinzufügen',
                    ),
              onPressed: _saving || !snapshot.hasData
                  ? null
                  : () => _toggle(user.uid, favorite),
              icon: Icon(
                favorite ? Icons.favorite : Icons.favorite_border,
                color: favorite ? const Color(0xffFF9800) : null,
              ),
            );
          },
    );
  }
}

String _favoriteText(
  BuildContext context, {
  required String tr,
  required String en,
  required String de,
}) {
  switch (Localizations.localeOf(context).languageCode.toLowerCase()) {
    case 'en':
      return en;
    case 'de':
      return de;
    default:
      return tr;
  }
}
