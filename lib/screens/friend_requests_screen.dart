import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/friend_service.dart';
import 'public_profile_screen.dart';

String _friendRequestsText(
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


class FriendRequestsScreen extends StatelessWidget {
  const FriendRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Arkadaşlık İstekleri",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FriendService.instance.incomingRequests(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final requests = snapshot.data!.docs;

          if (requests.isEmpty) {
            return const Center(
              child: Text("Bekleyen arkadaşlık isteğin yok."),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];

              final senderId = request["senderId"];

              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection("public_profiles")
                    .doc(senderId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const SizedBox();
                  }

                  if (!userSnapshot.data!.exists) {
                    return const SizedBox();
                  }

                  final user = UserModel.fromMap(
                    userSnapshot.data!.data()!,
                    documentId: senderId,
                  );
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user.profilFotografi.isNotEmpty
                            ? NetworkImage(user.profilFotografi)
                            : null,
                        child: user.profilFotografi.isEmpty
                            ? Text(user.displayName[0])
                            : null,
                      ),
                      title: Text(
                        user.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        user.resolvedCity.isEmpty
                            ? "Şehir belirtilmemiş"
                            : user.resolvedCity,
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PublicProfileScreen(
                              userId: user.uid,
                              initialUser: user,
                            ),
                          ),
                        );
                      },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.red,
                            ),
                            onPressed: () async {
                              try {
                                await FriendService.instance.acceptRequest(
                                  user.uid,
                                );

                                if (!context.mounted) {
                                  return;
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _friendRequestsText(context, tr: 'Arkadaşlık isteği kabul edildi.', en: 'Friend request accepted.', de: 'Freundschaftsanfrage angenommen.'),
                                    ),
                                  ),
                                );
                              } on FirebaseFunctionsException catch (error) {
                                if (!context.mounted) {
                                  return;
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Hata: ${error.code}\n${error.message ?? ''}',
                                    ),
                                  ),
                                );
                              } catch (error) {
                                if (!context.mounted) {
                                  return;
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Beklenmeyen hata: $error'),
                                  ),
                                );
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.check_rounded,
                              color: Colors.green,
                            ),
                            onPressed: () async {
                              await FriendService.instance.acceptRequest(
                                user.uid,
                              );
                            },
                          ),
                        ],
                      ),
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
