import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminRolesScreen extends StatefulWidget {
  const AdminRolesScreen({super.key});

  @override
  State<AdminRolesScreen> createState() => _AdminRolesScreenState();
}

class _AdminRolesScreenState extends State<AdminRolesScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin ve Yetki Yönetimi',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (
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
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final List<QueryDocumentSnapshot<Map<String, dynamic>>> users =
          snapshot.data!.docs.where((document) {
            final Map<String, dynamic> data = document.data();

            if (_searchText.isEmpty) {
              return true;
            }

            final String query = _searchText.toLowerCase();

            final String profileName =
                data['profilAdi']?.toString().toLowerCase() ?? '';

            final String name =
                data['ad']?.toString().toLowerCase() ?? '';

            final String surname =
                data['soyad']?.toString().toLowerCase() ?? '';

            final String phone =
                data['telefon']?.toString().toLowerCase() ??
                    data['phoneNumber']?.toString().toLowerCase() ??
                    '';

            return profileName.contains(query) ||
                name.contains(query) ||
                surname.contains(query) ||
                '$name $surname'.contains(query) ||
                phone.contains(query) ||
                document.id.toLowerCase().contains(query);
          }).toList();

          users.sort((a, b) {
            final bool aAdmin = _isAdmin(a.data());
            final bool bAdmin = _isAdmin(b.data());

            if (aAdmin != bAdmin) {
              return aAdmin ? -1 : 1;
            }

            final String aName = _displayName(a.data()).toLowerCase();
            final String bName = _displayName(b.data()).toLowerCase();

            return aName.compareTo(bName);
          });

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: (String value) {
                    setState(() {
                      _searchText = value.trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Kullanıcı, telefon veya kullanıcı kimliği ara',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchText.isEmpty
                        ? null
                        : IconButton(
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
              Expanded(
                child: users.isEmpty
                    ? const Center(
                  child: Text(
                    'Kullanıcı bulunamadı.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
                    : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  itemCount: users.length,
                  separatorBuilder: (
                      BuildContext context,
                      int index,
                      ) {
                    return const SizedBox(height: 10);
                  },
                  itemBuilder: (
                      BuildContext context,
                      int index,
                      ) {
                    final QueryDocumentSnapshot<Map<String, dynamic>>
                    document = users[index];

                    return _UserRoleCard(
                      userId: document.id,
                      data: document.data(),
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

  static bool _isAdmin(Map<String, dynamic> data) {
    return data['admin'] == true ||
        data['role'] == 'admin' ||
        data['role'] == 'super_admin' ||
        data['role'] == 'moderator';
  }

  static String _displayName(Map<String, dynamic> data) {
    final String profileName =
        data['profilAdi']?.toString().trim() ?? '';

    if (profileName.isNotEmpty) {
      return profileName;
    }

    final String name = data['ad']?.toString().trim() ?? '';
    final String surname = data['soyad']?.toString().trim() ?? '';

    final String fullName = '$name $surname'.trim();

    return fullName.isEmpty ? 'İsimsiz kullanıcı' : fullName;
  }
}

class _UserRoleCard extends StatelessWidget {
  const _UserRoleCard({
    required this.userId,
    required this.data,
  });

  final String userId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final String displayName = _displayName(data);

    final String phone =
        data['telefon']?.toString().trim() ??
            data['phoneNumber']?.toString().trim() ??
            '';

    final String photoUrl =
        data['profilFotografi']?.toString().trim() ?? '';

    final String role = _normalizedRole(data);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (BuildContext context) {
                return _AdminRoleEditorScreen(
                  userId: userId,
                  displayName: displayName,
                  currentRole: role,
                );
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
                backgroundImage:
                photoUrl.isEmpty ? null : NetworkImage(photoUrl),
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
                    if (phone.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    _RoleLabel(
                      role: role,
                    ),
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

  static String _displayName(Map<String, dynamic> data) {
    final String profileName =
        data['profilAdi']?.toString().trim() ?? '';

    if (profileName.isNotEmpty) {
      return profileName;
    }

    final String name = data['ad']?.toString().trim() ?? '';
    final String surname = data['soyad']?.toString().trim() ?? '';

    final String fullName = '$name $surname'.trim();

    return fullName.isEmpty ? 'İsimsiz kullanıcı' : fullName;
  }

  static String _normalizedRole(Map<String, dynamic> data) {
    final String role = data['role']?.toString().toLowerCase() ?? '';

    if (role == 'super_admin') {
      return 'super_admin';
    }

    if (role == 'admin' || data['admin'] == true) {
      return 'admin';
    }

    if (role == 'moderator') {
      return 'moderator';
    }

    return 'user';
  }
}

class _AdminRoleEditorScreen extends StatefulWidget {
  const _AdminRoleEditorScreen({
    required this.userId,
    required this.displayName,
    required this.currentRole,
  });

  final String userId;
  final String displayName;
  final String currentRole;

  @override
  State<_AdminRoleEditorScreen> createState() =>
      _AdminRoleEditorScreenState();
}

class _AdminRoleEditorScreenState
    extends State<_AdminRoleEditorScreen> {
  final TextEditingController _reasonController = TextEditingController();

  late String _selectedRole;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.currentRole;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    final String reason = _reasonController.text.trim();

    if (reason.length < 3) {
      _showMessage('İşlem açıklamasını yaz.');
      return;
    }

    final User? currentAdmin = FirebaseAuth.instance.currentUser;

    if (currentAdmin == null) {
      _showMessage('Admin oturumu bulunamadı.');
      return;
    }

    if (currentAdmin.uid == widget.userId &&
        _selectedRole != widget.currentRole) {
      _showMessage('Kendi admin yetkini bu ekrandan değiştiremezsin.');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Rol Değişikliğini Onayla'),
          content: Text(
            '${widget.displayName}\n\n'
                '${_roleTitle(widget.currentRole)} → '
                '${_roleTitle(_selectedRole)}\n\n'
                'Açıklama: $reason',
          ),
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
              child: const Text('Onayla'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {


      final HttpsCallable callable =
      FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('setUserRole');

      await callable.call(<String, dynamic>{
        'uid': widget.userId,
        'role': _selectedRole,
        'reason': reason,
      });

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (error) {
      _showMessage('Rol güncellenemedi: $error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  static String _roleTitle(String role) {
    switch (role) {
      case 'super_admin':
        return 'Süper Admin';
      case 'admin':
        return 'Admin';
      case 'moderator':
        return 'Moderatör';
      default:
        return 'Kullanıcı';
    }
  }

  static String _roleDescription(String role) {
    switch (role) {
      case 'super_admin':
        return 'Tüm yönetim işlemlerine erişebilir.';
      case 'admin':
        return 'Kullanıcı, etkinlik, destek ve finans işlemlerini yönetebilir.';
      case 'moderator':
        return 'Şikâyet, destek ve içerik moderasyonu yapabilir.';
      default:
        return 'Admin paneline erişemez.';
    }
  }

  static IconData _roleIcon(String role) {
    switch (role) {
      case 'super_admin':
        return Icons.security_rounded;
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      case 'moderator':
        return Icons.shield_outlined;
      default:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Rol ve Yetki Düzenle',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.displayName,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  SelectableText(widget.userId),
                  const SizedBox(height: 18),
                  RadioGroup<String>(
                    groupValue: _selectedRole,
                    onChanged: (String? value) {
                      if (_saving || value == null) {
                        return;
                      }

                      setState(() {
                        _selectedRole = value;
                      });
                    },
                    child: Column(
                      children: <Widget>[
                        for (final String role in <String>[
                          'user',
                          'moderator',
                          'admin',
                          'super_admin',
                        ])
                          RadioListTile<String>(
                            value: role,
                            contentPadding: EdgeInsets.zero,
                            secondary: Icon(
                              _roleIcon(role),
                            ),
                            title: Text(
                              _roleTitle(role),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              _roleDescription(role),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _reasonController,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'İşlem açıklaması',
                      hintText:
                      'Örnek: Moderasyon ekibine dahil edildi',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.save_outlined),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        child: Text(
                          _saving
                              ? 'Kaydediliyor...'
                              : 'Rolü Güncelle',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleLabel extends StatelessWidget {
  const _RoleLabel({
    required this.role,
  });

  final String role;

  @override
  Widget build(BuildContext context) {
    final String title;
    final IconData icon;

    switch (role) {
      case 'super_admin':
        title = 'Süper Admin';
        icon = Icons.security_rounded;
        break;
      case 'admin':
        title = 'Admin';
        icon = Icons.admin_panel_settings_outlined;
        break;
      case 'moderator':
        title = 'Moderatör';
        icon = Icons.shield_outlined;
        break;
      default:
        title = 'Kullanıcı';
        icon = Icons.person_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15),
          const SizedBox(width: 5),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}