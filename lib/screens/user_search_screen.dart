import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/friend_service.dart';
import '../widgets/plus_emblem.dart';
import 'public_profile_screen.dart';

String _userSearchText(
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

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key, this.selectRecipient = false});

  final bool selectRecipient;

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _controller = TextEditingController();

  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Oyuncu Ara'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: _userSearchText(
                  context,
                  tr: 'Kullanıcı adı ara...',
                  en: 'Search username...',
                  de: 'Benutzernamen suchen...',
                ),
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
                ? Center(
                    child: Text(
                      _userSearchText(
                        context,
                        tr: 'Bir kullanıcı adı yaz.',
                        en: 'Enter a username.',
                        de: 'Gib einen Benutzernamen ein.',
                      ),
                    ),
                  )
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('public_profiles')
                        .orderBy('profilAdi')
                        .startAt([_query])
                        .endAt(['$_query\uf8ff'])
                        .limit(30)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final String currentUserId =
                          FirebaseAuth.instance.currentUser?.uid ?? '';

                      final users = snapshot.data!.docs
                          .where((doc) => doc.id != currentUserId)
                          .toList();

                      if (users.isEmpty) {
                        return Center(
                          child: Text(
                            _userSearchText(
                              context,
                              tr: 'Kullanıcı bulunamadı.',
                              en: 'User not found.',
                              de: 'Nutzer nicht gefunden.',
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final doc = users[index];

                          final user = UserModel.fromMap(
                            doc.data(),
                            documentId: doc.id,
                          );
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user.profilFotografi.isNotEmpty
                                  ? NetworkImage(user.profilFotografi)
                                  : null,
                              child: user.profilFotografi.isEmpty
                                  ? Text(user.displayName[0])
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
                                  const PlusMark(size: 15),
                                ],
                              ],
                            ),
                            subtitle: Text(user.resolvedCity),
                            trailing: StreamBuilder<FriendRequestStatus>(
                              stream: FriendService.instance.statusStream(
                                user.uid,
                              ),
                              builder: (context, state) {
                                final status =
                                    state.data ?? FriendRequestStatus.none;

                                switch (status) {
                                  case FriendRequestStatus.friends:
                                    return Tooltip(
                                      message: _userSearchText(
                                        context,
                                        tr: 'Arkadaş',
                                        en: 'Friend',
                                        de: 'Freund',
                                      ),
                                      child: Icon(
                                        Icons.people_alt_rounded,
                                        color: Colors.green,
                                      ),
                                    );

                                  case FriendRequestStatus.sent:
                                    return Tooltip(
                                      message: _userSearchText(
                                        context,
                                        tr: 'İstek Gönderildi',
                                        en: 'Request Sent',
                                        de: 'Anfrage gesendet',
                                      ),
                                      child: Icon(
                                        Icons.schedule_rounded,
                                        color: Colors.orange,
                                      ),
                                    );

                                  case FriendRequestStatus.received:
                                    return Tooltip(
                                      message: _userSearchText(
                                        context,
                                        tr: 'Sana İstek Gönderdi',
                                        en: 'Sent You a Request',
                                        de: 'Hat dir eine Anfrage gesendet',
                                      ),
                                      child: Icon(
                                        Icons.mark_email_read_rounded,
                                        color: Colors.blue,
                                      ),
                                    );

                                  case FriendRequestStatus.none:
                                    return const Icon(
                                      Icons.person_add_alt_1_rounded,
                                    );
                                }
                              },
                            ),
                            onTap: () {
                              if (widget.selectRecipient) {
                                Navigator.pop(context, user.uid);
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PublicProfileScreen(
                                    userId: user.uid,
                                    initialUser: user,
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
