import 'package:flutter/material.dart';

import '../services/session_service.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() =>
      _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  SessionMetadata? _metadata;
  bool _loading = true;
  bool _signingOutOtherDevices = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final SessionMetadata metadata =
      await SessionService.getCurrentDeviceInfo();

      if (!mounted) {
        return;
      }

      setState(() {
        _metadata = metadata;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage = 'Oturum bilgileri yüklenemedi.';
      });
    }
  }

  Future<void> _signOutOtherDevices() async {
    if (_signingOutOtherDevices) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Diğer oturumları kapat'),
          content: const Text(
            'Bu cihazdaki oturumun açık kalır. Hesabın diğer cihazlarda '
                'açıksa o oturumlar kapatılır.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Oturumları kapat'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _signingOutOtherDevices = true;
    });

    try {
      await SessionService.signOutOtherDevices();
      final SessionMetadata metadata =
      await SessionService.getCurrentDeviceInfo();

      if (!mounted) {
        return;
      }

      setState(() {
        _metadata = metadata;
      });

      _showMessage('Diğer cihazlardaki oturumlar kapatıldı.');
    } catch (_) {
      _showMessage('Diğer oturumlar kapatılamadı.');
    } finally {
      if (mounted) {
        setState(() {
          _signingOutOtherDevices = false;
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
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _platformLabel(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return 'Android';
      case 'ios':
        return 'iPhone / iPad';
      case 'windows':
        return 'Windows';
      case 'macos':
        return 'macOS';
      case 'linux':
        return 'Linux';
      case 'web':
        return 'Web';
      default:
        return 'Bilinmeyen platform';
    }
  }

  IconData _platformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return Icons.android_outlined;
      case 'ios':
        return Icons.phone_iphone_outlined;
      case 'windows':
      case 'macos':
      case 'linux':
        return Icons.computer_outlined;
      case 'web':
        return Icons.language_outlined;
      default:
        return Icons.devices_other_outlined;
    }
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Bilgi bulunamadı';
    }

    final DateTime local = dateTime.toLocal();

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(local.day)}.${twoDigits(local.month)}.${local.year} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  String _shortDeviceId(String deviceId) {
    if (deviceId.length <= 16) {
      return deviceId;
    }

    return '${deviceId.substring(0, 8)}...'
        '${deviceId.substring(deviceId.length - 6)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oturum ve Cihazlar'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.error_outline,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadSession,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      );
    }

    final SessionMetadata metadata = _metadata!;
    final SessionInfo session = metadata.session;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          Text(
            'Bu cihaz',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: Icon(
                    _platformIcon(session.platform),
                    size: 30,
                  ),
                  title: Text(_platformLabel(session.platform)),
                  subtitle: const Text('Mevcut aktif oturum'),
                  trailing: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.fingerprint_outlined),
                  title: const Text('Cihaz kimliği'),
                  subtitle: Text(_shortDeviceId(session.deviceId)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.apps_outlined),
                  title: const Text('Uygulama sürümü'),
                  subtitle: Text(
                    session.appVersion == 'unknown'
                        ? 'Bilinmiyor'
                        : session.appVersion,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.login_outlined),
                  title: const Text('Oturum başlangıcı'),
                  subtitle: Text(_formatDate(metadata.createdAt)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('Son etkinlik'),
                  subtitle: Text(_formatDate(metadata.lastSeenAt)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Güvenlik',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: _signingOutOtherDevices
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                    ),
                  )
                      : const Icon(Icons.phonelink_erase_outlined),
                  title: const Text('Diğer cihazlardaki oturumları kapat'),
                  subtitle: const Text(
                    'Bu cihaz açık kalır, diğer aktif oturumlar kapatılır.',
                  ),
                  trailing: _signingOutOtherDevices
                      ? null
                      : const Icon(Icons.chevron_right),
                  onTap: _signingOutOtherDevices
                      ? null
                      : _signOutOtherDevices,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.info_outline),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Hesabına başka bir cihazdan giriş yapıldığında mevcut '
                          'oturum güvenlik amacıyla otomatik olarak kapatılabilir.',
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
