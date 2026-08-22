import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/friend_service.dart';
import 'public_profile_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() =>
      _UserSearchScreenState();
}

class _UserSearchScreenState
    extends State<UserSearchScreen> {
  final TextEditingController _controller =
  TextEditingController();

  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oyuncu Ara'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText:
                'Kullanıcı adı ara...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _query = value.trim();
                });
              },
            ),
          ),
          Expanded(
            child: _query.isEmpty
                ? const Center(
              child: Text(
                'Bir kullanıcı adı yaz.',
              ),
            )
                : StreamBuilder<
                QuerySnapshot<
                    Map<String, dynamic>>>(
              stream: FirebaseFirestore
                  .instance
                  .collection('public_profiles')
                  .orderBy('profilAdi')
                  .startAt([_query])
                  .endAt(['$_query\uf8ff'])
                  .limit(30)
                  .snapshots(),
              builder:
                  (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child:
                    CircularProgressIndicator(),
                  );
                }

                final String currentUserId =
                    FirebaseAuth.instance.currentUser?.uid ?? '';

                final users = snapshot.data!.docs
                    .where((doc) => doc.id != currentUserId)
                    .toList();

                if (users.isEmpty) {
                  return const Center(
                    child: Text(
                      'Kullanıcı bulunamadı.',
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder:
                      (context, index) {
                    final doc =
                    users[index];

                    final user =
                    UserModel.fromMap(
                      doc.data(),
                      documentId:
                      doc.id,
                    );
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user
                            .profilFotografi
                            .isNotEmpty
                            ? NetworkImage(
                          user.profilFotografi,
                        )
                            : null,
                        child: user
                            .profilFotografi
                            .isEmpty
                            ? Text(
                          user.displayName[0],
                        )
                            : null,
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (user.verified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: Colors.blue,
                            ),
                          ],
                          if (user.plus) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.diamond_rounded,
                              size: 15,
                              color: Color(0xFFFF9800),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        user.resolvedCity,
                      ),
                      trailing:
                      StreamBuilder<
                          FriendRequestStatus>(
                        stream: FriendService
                            .instance
                            .statusStream(
                          user.uid,
                        ),
                        builder: (
                            context,
                            state,
                            ) {
                          final status =
                              state.data ??
                                  FriendRequestStatus
                                      .none;

                          switch (status) {
                            case FriendRequestStatus
                                .friends:
                              return const Tooltip(
                                message: 'Arkadaş',
                                child: Icon(
                                  Icons.people_alt_rounded,
                                  color: Colors.green,
                                ),
                              );

                            case FriendRequestStatus
                                .sent:
                              return const Tooltip(
                                message: 'İstek Gönderildi',
                                child: Icon(
                                  Icons.schedule_rounded,
                                  color: Colors.orange,
                                ),
                              );

                            case FriendRequestStatus
                                .received:
                              return const Tooltip(
                                message: 'Sana İstek Gönderdi',
                                child: Icon(
                                  Icons.mark_email_read_rounded,
                                  color: Colors.blue,
                                ),
                              );

                            case FriendRequestStatus
                                .none:
                              return const Icon(
                                Icons
                                    .person_add_alt_1_rounded,
                              );
                          }
                        },
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PublicProfileScreen(
                                  userId:
                                  user.uid,
                                  initialUser:
                                  user,
                                ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}