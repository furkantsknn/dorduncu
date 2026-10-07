import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

String _adminRolesText(
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
        title: Text(
          _adminRolesText(context, tr: 'Admin ve Yetki Yönetimi', en: 'Admin and Role Management', de: 'Admin- und Rollenverwaltung'),
          style: TextStyle(fontWeight: FontWeight.w900),
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
                        hintText:
                            'Kullanıcı, telefon veya kullanıcı kimliği ara',
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
                        ? Center(
                            child: Text(
                              _adminRolesText(context, tr: 'Kullanıcı bulunamadı.', en: 'User not found.', de: 'Nutzer nicht gefunden.'),
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                            itemCount: users.length,
                            separatorBuilder:
                                (BuildContext context, int index) {
                                  return const SizedBox(height: 10);
                                },
                            itemBuilder: (BuildContext context, int index) {
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
    final String profileName = data['profilAdi']?.toString().trim() ?? '';

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
  const _UserRoleCard({required this.userId, required this.data});

  final String userId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final String displayName = _displayName(data);

    final String phone =
        data['telefon']?.toString().trim() ??
        data['phoneNumber']?.toString().trim() ??
        '';

    final String photoUrl = data['profilFotografi']?.toString().trim() ?? '';

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
                    if (phone.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(phone, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 8),
                    _RoleLabel(role: role),
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
    final String profileName = data['profilAdi']?.toString().trim() ?? '';

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

    if (<String>{
      'moderator',
      'verification_officer',
      'support_officer',
      'finance_officer',
      'content_manager',
      'analyst',
    }.contains(role)) {
      return role;
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
  State<_AdminRoleEditorScreen> createState() => _AdminRoleEditorScreenState();
}

class _AdminRoleEditorScreenState extends State<_AdminRoleEditorScreen> {
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

    if (_selectedRole == widget.currentRole) {
      _showMessage('Yeni bir rol seç.');
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
          title: Text('Rol Değişikliğini Onayla'),
          content: Text(
            '${widget.displayName}\n\n'
            '${_roleTitle(widget.currentRole)} → '
            '${_roleTitle(_selectedRole)}\n\n'
            'Açıklama: $reason\n\n'
            'Güvenlik nedeniyle kullanıcının mevcut oturumları '
            'kapatılacaktır.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(_adminRolesText(context, tr: 'Vazgeç', en: 'Cancel', de: 'Abbrechen')),
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
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('setUserRole');

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
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _roleTitle(String role) {
    switch (role) {
      case 'super_admin':
        return _adminRolesText(context, tr: 'Süper Admin', en: 'Super Admin', de: 'Super-Admin');
      case 'admin':
        return 'Admin';
      case 'moderator':
        return _adminRolesText(context, tr: 'Moderatör', en: 'Moderator', de: 'Moderator');
      case 'verification_officer':
        return 'Belge Doğrulama Görevlisi';
      case 'support_officer':
        return _adminRolesText(context, tr: 'Destek Görevlisi', en: 'Support Agent', de: 'Support-Mitarbeiter');
      case 'finance_officer':
        return _adminRolesText(context, tr: 'Finans Görevlisi', en: 'Finance Agent', de: 'Finanz-Mitarbeiter');
      case 'content_manager':
        return _adminRolesText(context, tr: 'İçerik Yöneticisi', en: 'Content Manager', de: 'Content-Manager');
      case 'analyst':
        return 'Salt Okunur Analist';
      default:
        return _adminRolesText(context, tr: 'Kullanıcı', en: 'User', de: 'Nutzer');
    }
  }

  static String _roleDescription(String role) {
    switch (role) {
      case 'super_admin':
        return 'Tüm yönetim işlemlerine erişebilir.';
      case 'admin':
        return 'Kullanıcı, etkinlik, destek ve finans işlemlerini yönetebilir.';
      case 'moderator':
        return 'Kullanıcı, etkinlik ve moderasyon işlemlerini yönetebilir.';
      case 'verification_officer':
        return 'Kendisine atanan doğrulama taleplerini inceleyebilir.';
      case 'support_officer':
        return 'Destek taleplerini inceleyebilir ve yanıtlayabilir.';
      case 'finance_officer':
        return 'Cüzdan, ödeme, iade ve finans işlemlerini yönetebilir.';
      case 'content_manager':
        return 'Katalog, görsel, duyuru ve yönetilebilir içerikleri düzenleyebilir.';
      case 'analyst':
        return 'İstatistik ve raporları yalnızca görüntüleyebilir.';
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
      case 'verification_officer':
        return Icons.verified_user_outlined;
      case 'support_officer':
        return Icons.support_agent_outlined;
      case 'finance_officer':
        return Icons.account_balance_wallet_outlined;
      case 'content_manager':
        return Icons.edit_note_outlined;
      case 'analyst':
        return Icons.analytics_outlined;
      default:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _adminRolesText(context, tr: 'Rol ve Yetki Düzenle', en: 'Edit Role and Permissions', de: 'Rolle und Berechtigungen bearbeiten'),
          style: TextStyle(fontWeight: FontWeight.w900),
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
                          'verification_officer',
                          'support_officer',
                          'finance_officer',
                          'content_manager',
                          'analyst',
                          'admin',
                          'super_admin',
                        ])
                          RadioListTile<String>(
                            value: role,
                            contentPadding: EdgeInsets.zero,
                            secondary: Icon(_roleIcon(role)),
                            title: Text(
                              _roleTitle(role),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(_roleDescription(role)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(Icons.security_outlined),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Admin paneli rolleri yalnızca doğrulanmış '
                              'e-posta/parola hesabına atanabilir. Rol '
                              'değiştiğinde mevcut oturumlar güvenlik '
                              'nedeniyle kapatılır.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _reasonController,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: _adminRolesText(context, tr: 'İşlem açıklaması', en: 'Action description', de: 'Aktionsbeschreibung'),
                      hintText: 'Örnek: Moderasyon ekibine dahil edildi',
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          _saving ? 'Kaydediliyor...' : _adminRolesText(context, tr: 'Rolü Güncelle', en: 'Update Role', de: 'Rolle aktualisieren'),
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
  const _RoleLabel({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final String title;
    final IconData icon;

    switch (role) {
      case 'super_admin':
        title = _adminRolesText(context, tr: 'Süper Admin', en: 'Super Admin', de: 'Super-Admin');
        icon = Icons.security_rounded;
        break;
      case 'admin':
        title = 'Admin';
        icon = Icons.admin_panel_settings_outlined;
        break;
      case 'moderator':
        title = _adminRolesText(context, tr: 'Moderatör', en: 'Moderator', de: 'Moderator');
        icon = Icons.shield_outlined;
        break;
      case 'verification_officer':
        title = 'Belge Doğrulama';
        icon = Icons.verified_user_outlined;
        break;
      case 'support_officer':
        title = 'Destek';
        icon = Icons.support_agent_outlined;
        break;
      case 'finance_officer':
        title = 'Finans';
        icon = Icons.account_balance_wallet_outlined;
        break;
      case 'content_manager':
        title = 'İçerik';
        icon = Icons.edit_note_outlined;
        break;
      case 'analyst':
        title = 'Analist';
        icon = Icons.analytics_outlined;
        break;
      default:
        title = _adminRolesText(context, tr: 'Kullanıcı', en: 'User', de: 'Nutzer');
        icon = Icons.person_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
