import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/plus_entitlement.dart';
import 'admin_user_detail_screen.dart';
import 'admin_user_number.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key, this.initialFilter = 'all'});

  final String initialFilter;

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  String? _managementUid;
  late String _selectedFilter;
  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialFilter == 'plus'
              ? 'Plus Üyelikler'
              : widget.initialFilter == 'player'
              ? 'Oyuncu Üyeler'
              : widget.initialFilter == 'admin'
              ? 'Admin Kullanıcılar'
              : 'Kullanıcı Yönetimi',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Kullanıcılar yüklenirken bir hata oluştu.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final List<QueryDocumentSnapshot<Map<String, dynamic>>> allUsers =
                  snapshot.data!.docs;

              final List<QueryDocumentSnapshot<Map<String, dynamic>>>
              visibleUsers = allUsers.where((document) {
                final Map<String, dynamic> data = document.data();

                final String role =
                    data['role']?.toString().toLowerCase() ?? '';

                final bool isAdmin =
                    data['admin'] == true ||
                    role == 'admin' ||
                    role == 'super_admin' ||
                    role == 'moderator';

                final bool isPlus = PlusEntitlement.isActive(data);

                final bool isPlayer =
                    data['oyuncuRozeti'] == true || data['verified'] == true;

                switch (_selectedFilter) {
                  case 'normal':
                    if (isAdmin || isPlus) {
                      return false;
                    }
                  case 'plus':
                    if (!isPlus) {
                      return false;
                    }
                  case 'player':
                    if (!isPlayer) {
                      return false;
                    }
                  case 'admin':
                    if (!isAdmin) {
                      return false;
                    }
                  case 'all':
                    break;
                }

                if (_searchText.isEmpty) {
                  return true;
                }

                if (_searchText.toUpperCase().startsWith('U-')) {
                  return document.id == _managementUid;
                }

                final String query = _searchText.toLowerCase();

                final String profileName =
                    data['profilAdi']?.toString().toLowerCase() ?? '';

                final String name = data['ad']?.toString().toLowerCase() ?? '';

                final String surname =
                    data['soyad']?.toString().toLowerCase() ?? '';

                final String phone =
                    data['telefon']?.toString().toLowerCase() ??
                    data['phoneNumber']?.toString().toLowerCase() ??
                    '';

                final String city =
                    data['sehir']?.toString().toLowerCase() ?? '';

                final String uid = document.id.toLowerCase();

                return profileName.contains(query) ||
                    name.contains(query) ||
                    surname.contains(query) ||
                    '$name $surname'.contains(query) ||
                    phone.contains(query) ||
                    city.contains(query) ||
                    uid.contains(query);
              }).toList();

              visibleUsers.sort((a, b) {
                final Timestamp? aTimestamp = _timestampFromData(a.data());

                final Timestamp? bTimestamp = _timestampFromData(b.data());

                final DateTime aDate = aTimestamp?.toDate() ?? DateTime(1970);

                final DateTime bDate = bTimestamp?.toDate() ?? DateTime(1970);

                return bDate.compareTo(aDate);
              });

              return Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: _buildStatistics(allUsers),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (String value) async {
                        final normalized = value.trim();
                        final uid = await findUidByManagementNumber(normalized);
                        if (!mounted ||
                            _searchController.text.trim() != normalized) {
                          return;
                        }
                        setState(() {
                          _searchText = normalized;
                          _managementUid = uid;
                        });
                      },
                      decoration: InputDecoration(
                        hintText:
                            'Ad, profil adı, telefon, şehir veya kullanıcı ara',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchText.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Aramayı temizle',
                                onPressed: () {
                                  _searchController.clear();

                                  setState(() {
                                    _searchText = '';
                                  });
                                },
                                icon: const Icon(Icons.close),
                              ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      children: <Widget>[
                        _buildFilter('all', 'Tümü'),
                        _buildFilter('normal', 'Normal'),
                        _buildFilter('plus', 'Plus'),
                        _buildFilter('player', 'Oyuncu'),
                        _buildFilter('admin', 'Admin'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: visibleUsers.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Bu filtreye uygun kullanıcı bulunamadı.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                            itemCount: visibleUsers.length,
                            separatorBuilder:
                                (BuildContext context, int index) {
                                  return const SizedBox(height: 10);
                                },
                            itemBuilder: (BuildContext context, int index) {
                              return _buildUserCard(
                                context,
                                visibleUsers[index],
                              );
                            },
                          ),
                  ),
                ],
              );
            },
      ),
    );
  }

  Widget _buildStatistics(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> users,
  ) {
    int plusCount = 0;
    int playerCount = 0;
    int adminCount = 0;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document in users) {
      final Map<String, dynamic> data = document.data();

      if (PlusEntitlement.isActive(data)) {
        plusCount++;
      }

      if (data['oyuncuRozeti'] == true || data['verified'] == true) {
        playerCount++;
      }

      final String role = data['role']?.toString().toLowerCase() ?? '';

      if (data['admin'] == true ||
          role == 'admin' ||
          role == 'super_admin' ||
          role == 'moderator') {
        adminCount++;
      }
    }

    return Row(
      children: <Widget>[
        Expanded(
          child: _StatisticCard(
            title: 'Toplam',
            count: users.length,
            icon: Icons.people_alt_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatisticCard(
            title: 'Plus',
            count: plusCount,
            icon: Icons.workspace_premium_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatisticCard(
            title: 'Oyuncu',
            count: playerCount,
            icon: Icons.verified_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatisticCard(
            title: 'Admin',
            count: adminCount,
            icon: Icons.admin_panel_settings_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildFilter(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _selectedFilter == value,
        onSelected: (_) {
          setState(() {
            _selectedFilter = value;
          });
        },
      ),
    );
  }

  Widget _buildUserCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data();

    final String profileName = data['profilAdi']?.toString().trim() ?? '';

    final String name = data['ad']?.toString().trim() ?? '';

    final String surname = data['soyad']?.toString().trim() ?? '';

    final String fullName = '$name $surname'.trim();

    final String displayName = profileName.isNotEmpty
        ? profileName
        : fullName.isNotEmpty
        ? fullName
        : 'İsimsiz kullanıcı';

    final String city = data['sehir']?.toString().trim() ?? '';

    final String photoUrl = data['profilFotografi']?.toString().trim() ?? '';

    final bool isPlus = PlusEntitlement.isActive(data);

    final bool isPlayer =
        data['oyuncuRozeti'] == true || data['verified'] == true;

    final String role = data['role']?.toString().toLowerCase() ?? '';

    final bool isAdmin =
        data['admin'] == true ||
        role == 'admin' ||
        role == 'super_admin' ||
        role == 'moderator';

    final String accountStatus =
        data['hesapDurumu']?.toString().trim() ??
        data['accountStatus']?.toString().trim() ??
        'active';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (BuildContext context) {
                return AdminUserDetailScreen(userId: document.id);
              },
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 27,
                backgroundImage: photoUrl.isEmpty
                    ? null
                    : NetworkImage(photoUrl),
                child: photoUrl.isEmpty
                    ? const Icon(Icons.person_outline)
                    : null,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    if (fullName.isNotEmpty &&
                        fullName != displayName) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    AdminUserNumber(uid: document.id),
                    const SizedBox(height: 6),
                    _UserLabel(
                      text: _accountStatusTitle(accountStatus),
                      icon: _accountStatusIcon(accountStatus),
                    ),
                    if (isPlus || isPlayer || isAdmin) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        <String>[
                          if (isPlus) 'Plus',
                          if (isPlayer) 'Oyuncu',
                          if (isAdmin) 'Admin',
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (city.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 7),
                      Text(
                        <String>[if (city.isNotEmpty) city].join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  static Timestamp? _timestampFromData(Map<String, dynamic> data) {
    final dynamic value = data['createdAt'] ?? data['kayitTarihi'];

    return value is Timestamp ? value : null;
  }

  static String _accountStatusTitle(String value) {
    switch (value.toLowerCase()) {
      case 'blocked':
      case 'banned':
        return 'Engelli';
      case 'suspended':
        return 'Askıda';
      case 'disabled':
        return 'Pasif';
      case 'deletionrequested':
        return 'Silme talebi';
      default:
        return 'Aktif';
    }
  }

  static IconData _accountStatusIcon(String value) {
    switch (value.toLowerCase()) {
      case 'blocked':
      case 'banned':
        return Icons.block;
      case 'suspended':
        return Icons.pause_circle_outline;
      case 'disabled':
        return Icons.person_off_outlined;
      case 'deletionrequested':
        return Icons.delete_outline;
      default:
        return Icons.check_circle_outline;
    }
  }
}

class _StatisticCard extends StatelessWidget {
  const _StatisticCard({
    required this.title,
    required this.count,
    required this.icon,
  });

  final String title;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          children: <Widget>[
            Icon(icon),
            const SizedBox(height: 5),
            Text(
              '$count',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            Text(
              title,
              maxLines: 1,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserLabel extends StatelessWidget {
  const _UserLabel({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
