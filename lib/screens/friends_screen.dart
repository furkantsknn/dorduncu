import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/friend_service.dart';
import 'public_profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final TextEditingController _searchController =
  TextEditingController();

  String _searchText = '';

  final Set<String> _busyUserIds = <String>{};

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 3,
      vsync: this,
    );

    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final String value =
    _searchController.text.trim().toLowerCase();

    if (_searchText == value) {
      return;
    }

    setState(() {
      _searchText = value;
    });
  }

  void _openProfile(UserModel user) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicProfileScreen(
          userId: user.uid,
          initialUser: user,
        ),
      ),
    );
  }

  Future<void> _runAction({
    required String userId,
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    if (_busyUserIds.contains(userId)) {
      return;
    }

    setState(() {
      _busyUserIds.add(userId);
    });

    try {
      await action();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(successMessage),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'İşlem tamamlanamadı: $error',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _busyUserIds.remove(userId);
        });
      }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Arkadaşlar',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Widget>[
            Tab(
              icon: Icon(Icons.people_alt_outlined),
              text: 'Arkadaşlar',
            ),
            Tab(
              icon: Icon(Icons.person_add_alt_1_outlined),
              text: 'Gelen',
            ),
            Tab(
              icon: Icon(Icons.schedule_send_outlined),
              text: 'Gönderilen',
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              14,
              16,
              8,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Kullanıcı ara',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                ),
                suffixIcon: _searchText.isEmpty
                    ? null
                    : IconButton(
                  onPressed: _searchController.clear,
                  icon: const Icon(
                    Icons.close_rounded,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                _buildFriendsTab(),
                _buildIncomingTab(),
                _buildOutgoingTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildFriendsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FriendService.instance.friends(),
      builder: (
          BuildContext context,
          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return const _FriendsEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Arkadaşlar yüklenemedi',
            message: 'Arkadaş listesi şu anda görüntülenemiyor.',
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        if (docs.isEmpty) {
          return const _FriendsEmptyState(
            icon: Icons.people_outline_rounded,
            title: 'Henüz arkadaşın yok',
            message: 'Arkadaş eklediğinde burada görünecek.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (BuildContext context, int index) {
            final String userId = docs[index].id;

            return _UserCard(
              userId: userId,
              searchText: _searchText,
              busy: _busyUserIds.contains(userId),
              actionBuilder: (
                  BuildContext context,
                  UserModel user,
                  ) {
                return PopupMenuButton<String>(
                  onSelected: (String value) async {
                    if (value != 'remove') {
                      return;
                    }

                    final bool confirmed = await _confirm(
                      title: 'Arkadaşlıktan Çıkar',
                      message:
                      '${user.displayName} arkadaş listesinden çıkarılsın mı?',
                      confirmText: 'Çıkar',
                    );

                    if (!confirmed) {
                      return;
                    }

                    await _runAction(
                      userId: user.uid,
                      action: () {
                        return FriendService.instance.removeFriend(user.uid);
                      },
                      successMessage:
                      '${user.displayName} arkadaş listesinden çıkarıldı.',
                    );
                  },
                  itemBuilder: (BuildContext context) {
                    return const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'remove',
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.person_remove_outlined),
                            SizedBox(width: 10),
                            Text('Arkadaşlıktan Çıkar'),
                          ],
                        ),
                      ),
                    ];
                  },
                );
              },
              onTap: _openProfile,
            );
          },
        );
      },
    );
  }

  Widget _buildIncomingTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FriendService.instance.incomingRequests(),
      builder: (
          BuildContext context,
          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return const _FriendsEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'İstekler yüklenemedi',
            message: 'Gelen arkadaşlık istekleri görüntülenemiyor.',
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        if (docs.isEmpty) {
          return const _FriendsEmptyState(
            icon: Icons.mark_email_read_outlined,
            title: 'Bekleyen istek yok',
            message: 'Yeni arkadaşlık istekleri burada görünecek.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (BuildContext context, int index) {
            final Map<String, dynamic> requestData = docs[index].data();
            final String userId =
                requestData['senderId']?.toString().trim() ?? '';

            if (userId.isEmpty) {
              return const SizedBox.shrink();
            }

            return _UserCard(
              userId: userId,
              searchText: _searchText,
              busy: _busyUserIds.contains(userId),
              actionBuilder: (
                  BuildContext context,
                  UserModel user,
                  ) {
                final bool busy = _busyUserIds.contains(user.uid);

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Reddet',
                      onPressed: busy
                          ? null
                          : () {
                        _runAction(
                          userId: user.uid,
                          action: () {
                            return FriendService.instance
                                .rejectRequest(user.uid);
                          },
                          successMessage:
                          '${user.displayName} isteği reddedildi.',
                        );
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                      ),
                    ),
                    IconButton.filled(
                      tooltip: 'Kabul Et',
                      onPressed: busy
                          ? null
                          : () {
                        _runAction(
                          userId: user.uid,
                          action: () {
                            return FriendService.instance
                                .acceptRequest(user.uid);
                          },
                          successMessage:
                          '${user.displayName} arkadaş olarak eklendi.',
                        );
                      },
                      icon: busy
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(
                        Icons.check_rounded,
                      ),
                    ),
                  ],
                );
              },
              onTap: _openProfile,
            );
          },
        );
      },
    );
  }
  Widget _buildOutgoingTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FriendService.instance.outgoingRequests(),
      builder: (
          BuildContext context,
          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs =
            snapshot.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        if (docs.isEmpty) {
          return const _FriendsEmptyState(
            icon: Icons.send_rounded,
            title: 'Gönderilen istek yok',
            message: 'Gönderdiğin arkadaşlık istekleri burada görünecek.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: docs.length,
          separatorBuilder: (_, _) =>
          const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = docs[index].data();

            final String userId =
                data['receiverId']?.toString() ?? '';

            return _UserCard(
              userId: userId,
              searchText: _searchText,
              busy: _busyUserIds.contains(userId),
              onTap: _openProfile,
              actionBuilder: (context, user) {
                return FilledButton.tonalIcon(
                  onPressed: _busyUserIds.contains(user.uid)
                      ? null
                      : () async {
                    final ok = await _confirm(
                      title: 'İsteği Geri Çek',
                      message:
                      '${user.displayName} kullanıcısına gönderdiğin arkadaşlık isteği geri çekilsin mi?',
                      confirmText: 'Geri Çek',
                    );

                    if (!ok) return;

                    await _runAction(
                      userId: user.uid,
                      action: () => FriendService.instance
                          .cancelRequest(user.uid),
                      successMessage:
                      'Arkadaşlık isteği geri çekildi.',
                    );
                  },
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Geri Çek'),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.userId,
    required this.searchText,
    required this.busy,
    required this.actionBuilder,
    required this.onTap,
  });

  final String userId;
  final String searchText;
  final bool busy;
  final Widget Function(
      BuildContext context,
      UserModel user,
      ) actionBuilder;
  final ValueChanged<UserModel> onTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('public_profiles')
          .doc(userId)
          .snapshots(),
      builder: (
          BuildContext context,
          AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final DocumentSnapshot<Map<String, dynamic>> document =
        snapshot.data!;

        if (!document.exists || document.data() == null) {
          return const SizedBox.shrink();
        }

        final UserModel user = UserModel.fromMap(
          document.data()!,
          documentId: document.id,
        );

        final String searchable = <String>[
          user.displayName,
          user.fullName,
          user.resolvedCity,
        ].join(' ').toLowerCase();

        if (searchText.isNotEmpty &&
            !searchable.contains(searchText)) {
          return const SizedBox.shrink();
        }

        final String initial = user.displayName.trim().isEmpty
            ? '?'
            : user.displayName.trim()[0].toUpperCase();

        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            onTap: busy ? null : () => onTap(user),
            leading: CircleAvatar(
              radius: 25,
              backgroundImage:
              user.profilFotografi.trim().isNotEmpty
                  ? NetworkImage(
                user.profilFotografi.trim(),
              )
                  : null,
              child: user.profilFotografi.trim().isEmpty
                  ? Text(
                initial,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              )
                  : null,
            ),
            title: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (user.verified) ...<Widget>[
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.verified_rounded,
                    size: 17,
                    color: Colors.blue,
                  ),
                ],
                if (user.plus) ...<Widget>[
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.diamond_rounded,
                    size: 16,
                    color: Color(0xffFF9800),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              user.resolvedCity.trim().isEmpty
                  ? 'Şehir belirtilmemiş'
                  : user.resolvedCity.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: busy
                ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : actionBuilder(context, user),
          ),
        );
      },
    );
  }
}

class _FriendsEmptyState extends StatelessWidget {
  const _FriendsEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 68,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}