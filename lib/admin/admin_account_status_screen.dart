import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class AdminAccountStatusScreen extends StatefulWidget {
  const AdminAccountStatusScreen({
    super.key,
    required this.userId,
    required this.currentStatus,
  });

  final String userId;
  final String currentStatus;

  @override
  State<AdminAccountStatusScreen> createState() =>
      _AdminAccountStatusScreenState();
}

class _AdminAccountStatusScreenState
    extends State<AdminAccountStatusScreen> {
  final TextEditingController _reasonController =
  TextEditingController();

  late String _selectedStatus;
  bool _saving = false;
  int _suspensionDays = 3;

  @override
  void initState() {
    super.initState();
    _selectedStatus = _normalizeStatus(widget.currentStatus);
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

    if (_selectedStatus != 'active' && reason.length < 3) {
      _showMessage(
        'Hesabı kısıtlamak için açıklama yazmalısın.',
      );
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Hesap Durumunu Güncelle'),
          content: Text(
            'Yeni durum: ${_statusTitle(_selectedStatus)}'
                '${reason.isEmpty ? '' : '\n\nAçıklama: $reason'}',
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
      FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('processAccountStatus');

      await callable.call(<String, dynamic>{
        'uid': widget.userId,
        'status': _selectedStatus,
        'reason': reason,
        'suspensionDays':
        _selectedStatus == 'suspended'
            ? _suspensionDays
            : null,
      });

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      _showMessage(
        'Hesap durumu güncellenemedi: $error',
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

  static String _normalizeStatus(String value) {
    switch (value.toLowerCase()) {
      case 'blocked':
      case 'banned':
        return 'blocked';
      case 'suspended':
        return 'suspended';
      case 'disabled':
        return 'disabled';
      default:
        return 'active';
    }
  }

  static String _statusTitle(String value) {
    switch (value) {
      case 'blocked':
        return 'Kalıcı Engelle (Ban)';
      case 'suspended':
        return 'Askıya Al';
      case 'disabled':
        return 'Pasif Yap';
      default:
        return 'Aktif Et';
    }
  }

  static IconData _statusIcon(String value) {
    switch (value) {
      case 'blocked':
        return Icons.block;
      case 'suspended':
        return Icons.pause_circle_outline;
      case 'disabled':
        return Icons.person_off_outlined;
      default:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hesap Durumu',
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
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Yeni hesap durumu',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  RadioGroup<String>(
                    groupValue: _selectedStatus,
                    onChanged: (String? value) {
                      if (_saving || value == null) {
                        return;
                      }

                      setState(() {
                        _selectedStatus = value;
                      });
                    },
                    child: Column(
                      children: <Widget>[
                        for (final String status in <String>[
                          'active',
                          'suspended',
                          'disabled',
                          'blocked',
                        ])
                          RadioListTile<String>(
                            value: status,
                            secondary: Icon(
                              _statusIcon(status),
                            ),
                            title: Text(
                              status == 'active' &&
                                  _normalizeStatus(widget.currentStatus) != 'active'
                                  ? 'Tekrar Aktif Et'
                                  : _statusTitle(status),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  if (_selectedStatus == 'suspended') ...<Widget>[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _suspensionDays,
                      decoration: const InputDecoration(
                        labelText: 'Askıya alma süresi',
                        border: OutlineInputBorder(),
                      ),
                      items: const <DropdownMenuItem<int>>[
                        DropdownMenuItem<int>(
                          value: 3,
                          child: Text('3 gün'),
                        ),
                        DropdownMenuItem<int>(
                          value: 7,
                          child: Text('7 gün'),
                        ),
                        DropdownMenuItem<int>(
                          value: 15,
                          child: Text('15 gün'),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (int? value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _suspensionDays = value;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reasonController,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'İşlem açıklaması',
                      hintText:
                      'Örnek: Topluluk kurallarının ihlali',
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
                        child:
                        CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(
                        Icons.save_outlined,
                      ),
                      label: Padding(
                        padding:
                        const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        child: Text(
                          _saving
                              ? 'Kaydediliyor...'
                              : 'Hesap Durumunu Güncelle',
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