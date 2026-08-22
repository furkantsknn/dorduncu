import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminEventStatusScreen extends StatefulWidget {
  const AdminEventStatusScreen({
    super.key,
    required this.eventId,
    required this.currentStatus,
  });

  final String eventId;
  final String currentStatus;

  @override
  State<AdminEventStatusScreen> createState() =>
      _AdminEventStatusScreenState();
}

class _AdminEventStatusScreenState
    extends State<AdminEventStatusScreen> {
  final TextEditingController _reasonController =
  TextEditingController();

  late String _selectedStatus;
  bool _saving = false;

  DocumentReference<Map<String, dynamic>> get _eventReference {
    return FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId);
  }

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
      _showMessage('İşlem açıklamasını yaz.');
      return;
    }

    final String adminId =
        FirebaseAuth.instance.currentUser?.uid ?? '';

    if (adminId.isEmpty) {
      _showMessage('Admin oturumu bulunamadı.');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Etkinlik Durumunu Güncelle'),
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
      await _eventReference.update(
        <String, dynamic>{
          'status': _selectedStatus,
          'durum': _selectedStatus,
          'adminStatusReason': reason,
          'adminStatusUpdatedAt':
          FieldValue.serverTimestamp(),
          'adminStatusUpdatedBy': adminId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      _showMessage(
        'Etkinlik durumu güncellenemedi: $error',
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
      case 'completed':
      case 'finished':
      case 'tamamlandi':
      case 'tamamlandı':
        return 'completed';

      case 'cancelled':
      case 'canceled':
      case 'iptal':
      case 'cancelled_by_host':
        return 'cancelled';

      case 'hidden':
      case 'removed':
      case 'gizli':
        return 'hidden';

      default:
        return 'active';
    }
  }

  static String _statusTitle(String value) {
    switch (value) {
      case 'completed':
        return 'Tamamlandı';

      case 'cancelled':
        return 'İptal edildi';

      case 'hidden':
        return 'Gizli';

      default:
        return 'Aktif';
    }
  }

  static IconData _statusIcon(String value) {
    switch (value) {
      case 'completed':
        return Icons.task_alt_outlined;

      case 'cancelled':
        return Icons.event_busy_outlined;

      case 'hidden':
        return Icons.visibility_off_outlined;

      default:
        return Icons.event_available_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Etkinlik Durumu',
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
                    'Yeni durum',
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
                          'completed',
                          'cancelled',
                          'hidden',
                        ])
                          RadioListTile<String>(
                            value: status,
                            secondary: Icon(
                              _statusIcon(status),
                            ),
                            title: Text(
                              _statusTitle(status),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reasonController,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'İşlem açıklaması',
                      hintText:
                      'Örnek: Kural ihlali nedeniyle gizlendi',
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
                              : 'Etkinlik Durumunu Güncelle',
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