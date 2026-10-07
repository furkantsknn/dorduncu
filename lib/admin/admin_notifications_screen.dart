import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

String _adminNotificationsText(
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


class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _messageController = TextEditingController();

  final TextEditingController _targetValueController = TextEditingController();

  String _selectedTarget = 'all';
  String _selectedPriority = 'normal';

  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _targetValueController.dispose();
    super.dispose();
  }

  bool get _requiresTargetValue {
    return _selectedTarget == 'city' || _selectedTarget == 'user';
  }

  Future<void> _createNotification() async {
    if (_saving) {
      return;
    }

    final String title = _titleController.text.trim();
    final String message = _messageController.text.trim();
    final String targetValue = _targetValueController.text.trim();

    if (title.length < 3) {
      _showMessage('Bildirim başlığını yaz.');
      return;
    }

    if (message.length < 5) {
      _showMessage('Bildirim mesajını yaz.');
      return;
    }

    if (_requiresTargetValue && targetValue.isEmpty) {
      _showMessage(
        _selectedTarget == 'city'
            ? 'Hedef şehri yaz.'
            : 'Hedef kullanıcı kimliğini yaz.',
      );
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(_adminNotificationsText(context, tr: 'Bildirimi Oluştur', en: 'Create Notification', de: 'Benachrichtigung erstellen')),
          content: Text(
            'Hedef: ${_targetTitle(_selectedTarget)}\n\n'
            'Başlık: $title\n\n'
            'Mesaj: $message',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(_adminNotificationsText(context, tr: 'Vazgeç', en: 'Cancel', de: 'Abbrechen')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(_adminNotificationsText(context, tr: 'Oluştur', en: 'Create', de: 'Erstellen')),
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
      ).httpsCallable('adminCreateNotification');

      await callable.call(<String, dynamic>{
        'title': title,
        'message': message,
        'targetType': _selectedTarget,
        'targetValue': _requiresTargetValue ? targetValue : '',
        'priority': _selectedPriority,
      });

      if (!mounted) {
        return;
      }

      _titleController.clear();
      _messageController.clear();
      _targetValueController.clear();

      setState(() {
        _selectedTarget = 'all';
        _selectedPriority = 'normal';
      });

      _showMessage('Bildirim gönderim kuyruğuna eklendi.');
    } on FirebaseFunctionsException catch (error) {
      _showMessage(error.message ?? 'Bildirim oluşturulamadı.');
    } catch (error) {
      _showMessage('Bildirim oluşturulamadı: $error');
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

  String _targetTitle(String value) {
    switch (value) {
      case 'plus':
        return 'Plus üyeler';
      case 'player':
        return 'Oyuncu rozetli kullanıcılar';
      case 'city':
        return _adminNotificationsText(context, tr: 'Şehir', en: 'City', de: 'Stadt');
      case 'user':
        return 'Belirli kullanıcı';
      default:
        return _adminNotificationsText(context, tr: 'Tüm kullanıcılar', en: 'All users', de: 'Alle Nutzer');
    }
  }

  String _priorityTitle(String value) {
    switch (value) {
      case 'high':
        return 'Yüksek';
      case 'critical':
        return 'Kritik';
      default:
        return 'Normal';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bildirim Merkezi',
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
                    'Yeni Bildirim',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedTarget,
                    decoration: InputDecoration(
                      labelText: 'Hedef kitle',
                      border: OutlineInputBorder(),
                    ),
                    items: <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'all',
                        child: Text(_adminNotificationsText(context, tr: 'Tüm kullanıcılar', en: 'All users', de: 'Alle Nutzer')),
                      ),
                      DropdownMenuItem<String>(
                        value: 'plus',
                        child: Text('Plus üyeler'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'player',
                        child: Text('Oyuncu rozetli kullanıcılar'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'city',
                        child: Text('Şehir bazlı'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'user',
                        child: Text('Belirli kullanıcı'),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (String? value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _selectedTarget = value;
                              _targetValueController.clear();
                            });
                          },
                  ),
                  if (_requiresTargetValue) ...<Widget>[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _targetValueController,
                      enabled: !_saving,
                      decoration: InputDecoration(
                        labelText: _selectedTarget == 'city'
                            ? _adminNotificationsText(context, tr: 'Şehir', en: 'City', de: 'Stadt')
                            : 'Kullanıcı kimliği',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPriority,
                    decoration: InputDecoration(
                      labelText: _adminNotificationsText(context, tr: 'Öncelik', en: 'Priority', de: 'Priorität'),
                      border: OutlineInputBorder(),
                    ),
                    items: <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'normal',
                        child: Text('Normal'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'high',
                        child: Text('Yüksek'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'critical',
                        child: Text('Kritik'),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (String? value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _selectedPriority = value;
                            });
                          },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _titleController,
                    enabled: !_saving,
                    maxLength: 80,
                    decoration: InputDecoration(
                      labelText: _adminNotificationsText(context, tr: 'Bildirim başlığı', en: 'Notification title', de: 'Benachrichtigungstitel'),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _messageController,
                    enabled: !_saving,
                    minLines: 4,
                    maxLines: 7,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: _adminNotificationsText(context, tr: 'Bildirim mesajı', en: 'Notification message', de: 'Benachrichtigungstext'),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _createNotification,
                      icon: _saving
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          _saving ? 'Kaydediliyor...' : 'Bildirim Oluştur',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _NotificationHistory(
            targetTitle: _targetTitle,
            priorityTitle: _priorityTitle,
          ),
        ],
      ),
    );
  }
}

class _NotificationHistory extends StatelessWidget {
  const _NotificationHistory({
    required this.targetTitle,
    required this.priorityTitle,
  });

  final String Function(String value) targetTitle;
  final String Function(String value) priorityTitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _adminNotificationsText(context, tr: 'Bildirim Geçmişi', en: 'Notification History', de: 'Benachrichtigungsverlauf'),
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('admin_notifications')
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
                  ) {
                    if (snapshot.hasError) {
                      return const Text('Bildirim geçmişi yüklenemedi.');
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    documents = snapshot.data!.docs;

                    if (documents.isEmpty) {
                      return const Text('Henüz oluşturulmuş bildirim yok.');
                    }

                    return Column(
                      children: <Widget>[
                        for (
                          int index = 0;
                          index < documents.length;
                          index++
                        ) ...<Widget>[
                          if (index > 0) const Divider(height: 26),
                          _NotificationRow(
                            data: documents[index].data(),
                            targetTitle: targetTitle,
                            priorityTitle: priorityTitle,
                          ),
                        ],
                      ],
                    );
                  },
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.data,
    required this.targetTitle,
    required this.priorityTitle,
  });

  final Map<String, dynamic> data;
  final String Function(String value) targetTitle;
  final String Function(String value) priorityTitle;

  @override
  Widget build(BuildContext context) {
    final String title = data['title']?.toString().trim() ?? '';

    final String message = data['message']?.toString().trim() ?? '';

    final String targetType = data['targetType']?.toString() ?? 'all';

    final String priority = data['priority']?.toString() ?? 'normal';

    final String status = data['status']?.toString() ?? 'pending';

    final Timestamp? createdAt = data['createdAt'] is Timestamp
        ? data['createdAt'] as Timestamp
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title.isEmpty ? 'Başlıksız bildirim' : title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        if (message.isNotEmpty) ...<Widget>[
          const SizedBox(height: 5),
          Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 9),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: <Widget>[
            _Label(text: targetTitle(targetType), icon: Icons.groups_outlined),
            _Label(
              text: priorityTitle(priority),
              icon: Icons.priority_high_outlined,
            ),
            _Label(text: _statusTitle(context, status), icon: Icons.info_outline),
            if (createdAt != null)
              _Label(
                text: _formatDate(createdAt.toDate()),
                icon: Icons.schedule_outlined,
              ),
          ],
        ),
      ],
    );
  }

  String _statusTitle(BuildContext context, String value) {
    switch (value) {
      case 'processing':
        return 'Gönderiliyor';
      case 'sent':
        return _adminNotificationsText(context, tr: 'Gönderildi', en: 'Sent', de: 'Gesendet');
      case 'failed':
        return _adminNotificationsText(context, tr: 'Başarısız', en: 'Failed', de: 'Fehlgeschlagen');
      case 'cancelled':
        return _adminNotificationsText(context, tr: 'İptal edildi', en: 'Cancelled', de: 'Abgebrochen');
      default:
        return 'Bekliyor';
    }
  }

  String _formatDate(DateTime value) {
    final String day = value.day.toString().padLeft(2, '0');

    final String month = value.month.toString().padLeft(2, '0');

    final String year = value.year.toString();

    final String hour = value.hour.toString().padLeft(2, '0');

    final String minute = value.minute.toString().padLeft(2, '0');

    return '$day.$month.$year $hour:$minute';
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
