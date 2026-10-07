import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/friend_service.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  Future<Map<String, dynamic>?> _loadProfile(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> document =
        await FirebaseFirestore.instance
            .collection('public_profiles')
            .doc(uid)
            .get();

    return document.data();
  }

  Future<void> _unblock(
    BuildContext context,
    String uid,
    String displayName,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Engeli kaldÄ±r'),
          content: Text(
            '$displayName adlÄ± kullanÄ±cÄ±nÄ±n engelini kaldÄ±rmak '
            'istiyor musun?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('VazgeÃ§'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Engeli kaldÄ±r'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await FriendService.instance.unblockUser(uid);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('KullanÄ±cÄ±nÄ±n engeli kaldÄ±rÄ±ldÄ±.')),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Engel kaldÄ±rÄ±lÄ±rken bir sorun oluÅŸtu.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Engellenen kullanÄ±cÄ±lar')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FriendService.instance.blockedUsers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Engellenen kullanÄ±cÄ±lar yÃ¼klenemedi.'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<QueryDocumentSnapshot<Map<String, dynamic>>> documents =
              snapshot.data!.docs;

          if (documents.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'EngellediÄŸin bir kullanÄ±cÄ± yok.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: documents.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final String uid =
                  documents[index].data()['uid']?.toString().trim() ??
                  documents[index].id;

              return FutureBuilder<Map<String, dynamic>?>(
                future: _loadProfile(uid),
                builder: (context, profileSnapshot) {
                  final Map<String, dynamic>? data = profileSnapshot.data;
                  final String displayName =
                      data?['profilAdi']?.toString().trim().isNotEmpty == true
                      ? data!['profilAdi'].toString().trim()
                      : 'KullanÄ±cÄ±';
                  final String photo =
                      data?['profilFotografi']?.toString().trim() ?? '';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: photo.isNotEmpty
                          ? NetworkImage(photo)
                          : null,
                      child: photo.isEmpty
                          ? const Icon(Icons.person_outline)
                          : null,
                    ),
                    title: Text(displayName),
                    subtitle: Text(uid),
                    trailing: TextButton(
                      onPressed: () => _unblock(context, uid, displayName),
                      child: const Text('Engeli kaldÄ±r'),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
