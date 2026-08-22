import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final TextEditingController _maintenanceMessageController =
  TextEditingController();

  final TextEditingController _minimumVersionController =
  TextEditingController();

  final TextEditingController _latestVersionController =
  TextEditingController();

  final TextEditingController _supportEmailController =
  TextEditingController();

  final TextEditingController _termsUrlController =
  TextEditingController();

  final TextEditingController _privacyUrlController =
  TextEditingController();

  bool _maintenanceMode = false;
  bool _forceUpdateEnabled = false;
  bool _registrationEnabled = true;
  bool _eventCreationEnabled = true;
  bool _eventApplicationsEnabled = true;
  bool _supportEnabled = true;
  bool _paymentsEnabled = true;
  bool _marketEnabled = true;

  bool _loading = true;
  bool _saving = false;

  DocumentReference<Map<String, dynamic>> get _settingsReference {
    return FirebaseFirestore.instance
        .collection('system_settings')
        .doc('global');
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _maintenanceMessageController.dispose();
    _minimumVersionController.dispose();
    _latestVersionController.dispose();
    _supportEmailController.dispose();
    _termsUrlController.dispose();
    _privacyUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> document =
      await _settingsReference.get();

      final Map<String, dynamic> data =
          document.data() ?? <String, dynamic>{};

      _maintenanceMessageController.text =
          data['maintenanceMessage']?.toString() ?? '';

      _minimumVersionController.text =
          data['minimumVersion']?.toString() ?? '';

      _latestVersionController.text =
          data['latestVersion']?.toString() ?? '';

      _supportEmailController.text =
          data['supportEmail']?.toString() ?? '';

      _termsUrlController.text =
          data['termsUrl']?.toString() ?? '';

      _privacyUrlController.text =
          data['privacyUrl']?.toString() ?? '';

      if (!mounted) {
        return;
      }

      setState(() {
        _maintenanceMode = data['maintenanceMode'] == true;
        _forceUpdateEnabled = data['forceUpdateEnabled'] == true;
        _registrationEnabled = data['registrationEnabled'] != false;
        _eventCreationEnabled =
            data['eventCreationEnabled'] != false;
        _eventApplicationsEnabled =
            data['eventApplicationsEnabled'] != false;
        _supportEnabled = data['supportEnabled'] != false;
        _paymentsEnabled = data['paymentsEnabled'] != false;
        _marketEnabled = data['marketEnabled'] != false;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });

      _showMessage(
        'Sistem ayarları yüklenemedi: $error',
      );
    }
  }

  Future<void> _saveSettings() async {
    if (_saving) {
      return;
    }

    final String adminId =
        FirebaseAuth.instance.currentUser?.uid ?? '';

    if (adminId.isEmpty) {
      _showMessage('Admin oturumu bulunamadı.');
      return;
    }

    final String minimumVersion =
    _minimumVersionController.text.trim();

    final String latestVersion =
    _latestVersionController.text.trim();

    final String supportEmail =
    _supportEmailController.text.trim();

    if (_forceUpdateEnabled && minimumVersion.isEmpty) {
      _showMessage(
        'Zorunlu güncelleme için minimum sürümü yaz.',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final FirebaseFirestore firestore =
          FirebaseFirestore.instance;

      final DocumentReference<Map<String, dynamic>>
      actionReference = firestore
          .collection('admin_system_actions')
          .doc();

      final WriteBatch batch = firestore.batch();

      batch.set(
        _settingsReference,
        <String, dynamic>{
          'maintenanceMode': _maintenanceMode,
          'maintenanceMessage':
          _maintenanceMessageController.text.trim(),
          'forceUpdateEnabled': _forceUpdateEnabled,
          'minimumVersion': minimumVersion,
          'latestVersion': latestVersion,
          'registrationEnabled': _registrationEnabled,
          'eventCreationEnabled': _eventCreationEnabled,
          'eventApplicationsEnabled':
          _eventApplicationsEnabled,
          'supportEnabled': _supportEnabled,
          'paymentsEnabled': _paymentsEnabled,
          'marketEnabled': _marketEnabled,
          'supportEmail': supportEmail,
          'termsUrl': _termsUrlController.text.trim(),
          'privacyUrl': _privacyUrlController.text.trim(),
          'updatedBy': adminId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      batch.set(
        actionReference,
        <String, dynamic>{
          'action': 'system_settings_updated',
          'adminId': adminId,
          'performedByUid': adminId,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      _showMessage('Sistem ayarları kaydedildi.');
    } catch (error) {
      _showMessage(
        'Sistem ayarları kaydedilemedi: $error',
      );
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Sistem Ayarları'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sistem Ayarları',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          32,
        ),
        children: <Widget>[
          _SettingsCard(
            title: 'Sistem Durumu',
            icon: Icons.settings_suggest_outlined,
            children: <Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Bakım modu'),
                subtitle: const Text(
                  'Uygulamanın kullanıcı erişimini geçici olarak sınırlar.',
                ),
                value: _maintenanceMode,
                onChanged: _saving
                    ? null
                    : (bool value) {
                  setState(() {
                    _maintenanceMode = value;
                  });
                },
              ),
              if (_maintenanceMode) ...<Widget>[
                const SizedBox(height: 10),
                TextField(
                  controller:
                  _maintenanceMessageController,
                  enabled: !_saving,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Bakım mesajı',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const Divider(height: 28),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Yeni kayıtlar açık'),
                value: _registrationEnabled,
                onChanged: _saving
                    ? null
                    : (bool value) {
                  setState(() {
                    _registrationEnabled = value;
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Etkinlik oluşturma açık',
                ),
                value: _eventCreationEnabled,
                onChanged: _saving
                    ? null
                    : (bool value) {
                  setState(() {
                    _eventCreationEnabled = value;
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Etkinlik başvuruları açık',
                ),
                value: _eventApplicationsEnabled,
                onChanged: _saving
                    ? null
                    : (bool value) {
                  setState(() {
                    _eventApplicationsEnabled = value;
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Destek sistemi açık'),
                value: _supportEnabled,
                onChanged: _saving
                    ? null
                    : (bool value) {
                  setState(() {
                    _supportEnabled = value;
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ödemeler açık'),
                value: _paymentsEnabled,
                onChanged: _saving
                    ? null
                    : (bool value) {
                  setState(() {
                    _paymentsEnabled = value;
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Market açık'),
                value: _marketEnabled,
                onChanged: _saving
                    ? null
                    : (bool value) {
                  setState(() {
                    _marketEnabled = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingsCard(
            title: 'Uygulama Sürümü',
            icon: Icons.system_update_outlined,
            children: <Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Zorunlu güncelleme',
                ),
                value: _forceUpdateEnabled,
                onChanged: _saving
                    ? null
                    : (bool value) {
                  setState(() {
                    _forceUpdateEnabled = value;
                  });
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _minimumVersionController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Minimum sürüm',
                  hintText: 'Örnek: 1.2.0',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _latestVersionController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Güncel sürüm',
                  hintText: 'Örnek: 1.4.0',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingsCard(
            title: 'İletişim ve Yasal Bağlantılar',
            icon: Icons.policy_outlined,
            children: <Widget>[
              TextField(
                controller: _supportEmailController,
                enabled: !_saving,
                keyboardType:
                TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Destek e-posta adresi',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _termsUrlController,
                enabled: !_saving,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText:
                  'Kullanım koşulları bağlantısı',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _privacyUrlController,
                enabled: !_saving,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText:
                  'Gizlilik politikası bağlantısı',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
              _saving ? null : _saveSettings,
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
                      : 'Ayarları Kaydet',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon),
                const SizedBox(width: 9),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}