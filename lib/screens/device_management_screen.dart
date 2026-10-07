import 'package:flutter/material.dart';

import '../services/session_service.dart';

String _deviceText(
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
        _errorMessage = _deviceText(context, tr: 'Oturum bilgileri yüklenemedi.', en: 'Session information could not be loaded.', de: 'Sitzungsinformationen konnten nicht geladen werden.');
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
          title: Text(_deviceText(context, tr: 'Diğer oturumları kapat', en: 'Close other sessions', de: 'Andere Sitzungen schließen')),
          content: Text(
            'Bu cihazdaki oturumun açık kalır. Hesabın diğer cihazlarda '
                'açıksa o oturumlar kapatılır.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_deviceText(context, tr: 'Vazgeç', en: 'Cancel', de: 'Abbrechen')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_deviceText(context, tr: 'Oturumları kapat', en: 'Close sessions', de: 'Sitzungen schließen')),
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

      _showMessage(_deviceText(context, tr: 'Diğer cihazlardaki oturumlar kapatıldı.', en: 'Sessions on other devices were closed.', de: 'Sitzungen auf anderen Geräten wurden geschlossen.'));
    } catch (_) {
      _showMessage(_deviceText(context, tr: 'Diğer oturumlar kapatılamadı.', en: 'Other sessions could not be closed.', de: 'Andere Sitzungen konnten nicht geschlossen werden.'));
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
      return _deviceText(context, tr: 'Bilgi bulunamadı', en: 'Information unavailable', de: 'Information nicht verfügbar');
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
                  subtitle: Text('Mevcut aktif oturum'),
                  trailing: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.fingerprint_outlined),
                  title: Text(_deviceText(context, tr: 'Cihaz kimliği', en: 'Device ID', de: 'Geräte-ID')),
                  subtitle: Text(_shortDeviceId(session.deviceId)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.apps_outlined),
                  title: Text(_deviceText(context, tr: 'Uygulama sürümü', en: 'App version', de: 'App-Version')),
                  subtitle: Text(
                    session.appVersion == 'unknown'
                        ? 'Bilinmiyor'
                        : session.appVersion,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.login_outlined),
                  title: Text(_deviceText(context, tr: 'Oturum başlangıcı', en: 'Session started', de: 'Sitzungsbeginn')),
                  subtitle: Text(_formatDate(metadata.createdAt)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.schedule_outlined),
                  title: Text('Son etkinlik'),
                  subtitle: Text(_formatDate(metadata.lastSeenAt)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            _deviceText(context, tr: 'Güvenlik', en: 'Security', de: 'Sicherheit'),
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
                  title: Text(_deviceText(context, tr: 'Diğer cihazlardaki oturumları kapat', en: 'Close sessions on other devices', de: 'Sitzungen auf anderen Geräten schließen')),
                  subtitle: Text(
                    _deviceText(context, tr: 'Bu cihaz açık kalır, diğer aktif oturumlar kapatılır.', en: 'This device stays signed in while other active sessions are closed.', de: 'Dieses Gerät bleibt angemeldet, während andere aktive Sitzungen geschlossen werden.'),
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
