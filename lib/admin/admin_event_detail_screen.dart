import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_event_status_screen.dart';
import 'admin_event_actions_screen.dart';
import 'admin_permission_gate.dart';
import 'admin_access.dart';

String _locText(
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


class AdminEventDetailScreen extends StatelessWidget {
  const AdminEventDetailScreen({super.key, required this.eventId});

  final String eventId;

  DocumentReference<Map<String, dynamic>> get _eventReference {
    return FirebaseFirestore.instance.collection('events').doc(eventId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _eventReference.snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (snapshot.hasError) {
              return Scaffold(
                appBar: AppBar(title: Text(_locText(context, tr: 'Etkinlik Detayı', en: 'Event Details', de: 'Veranstaltungsdetails'))),
                body: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Etkinlik bilgileri yüklenirken bir hata oluştu.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return Scaffold(
                appBar: AppBar(title: Text(_locText(context, tr: 'Etkinlik Detayı', en: 'Event Details', de: 'Veranstaltungsdetails'))),
                body: const Center(child: CircularProgressIndicator()),
              );
            }

            final DocumentSnapshot<Map<String, dynamic>> document =
                snapshot.data!;

            final Map<String, dynamic>? data = document.data();

            if (!document.exists || data == null) {
              return Scaffold(
                appBar: AppBar(title: Text(_locText(context, tr: 'Etkinlik Detayı', en: 'Event Details', de: 'Veranstaltungsdetails'))),
                body: Center(child: Text(_locText(context, tr: 'Etkinlik bulunamadı.', en: 'Event not found.', de: 'Veranstaltung nicht gefunden.'))),
              );
            }

            final String title = _firstString(data, <String>[
              'title',
              'baslik',
              'başlık',
              'eventTitle',
              'name',
              'etkinlikAdi',
            ]);

            final String description = _firstString(data, <String>[
              'description',
              'aciklama',
              'açıklama',
              'details',
            ]);

            final String city = _firstString(data, <String>[
              'city',
              'sehir',
              'şehir',
            ]);

            final String district = _firstString(data, <String>[
              'district',
              'ilce',
              'ilçe',
            ]);

            final String address = _firstString(data, <String>[
              'address',
              'adres',
              'locationText',
            ]);

            final String ownerId = _firstString(data, <String>[
              'ownerId',
              'creatorId',
              'userId',
              'hostId',
              'olusturanId',
            ]);

            final String category = _firstString(data, <String>[
              'category',
              'kategori',
              'game',
              'oyun',
            ]);

            final String status = _normalizeStatus(
              _firstString(data, <String>['status', 'durum']),
            );

            final DateTime? eventDate = _firstDate(data, <String>[
              'eventDate',
              'date',
              'startAt',
              'startsAt',
              'tarih',
            ]);

            final DateTime? createdAt = _firstDate(data, <String>[
              'createdAt',
              'olusturulmaTarihi',
            ]);

            final int participantLimit = _firstInt(data, <String>[
              'participantLimit',
              'maxParticipants',
              'capacity',
              'kisiSayisi',
              'kontenjan',
            ]);

            final int participantCount = _listCount(data, <String>[
              'participants',
              'participantIds',
              'katilimcilar',
            ]);

            final int applicationCount = _listCount(data, <String>[
              'applications',
              'applicantIds',
              'basvurular',
            ]);

            final bool isPaid = _firstBool(data, <String>[
              'isPaid',
              'paid',
              'ucretli',
            ]);

            final int priceKurus = _firstInt(data, <String>[
              'priceKurus',
              'amountKurus',
              'ucretKurus',
            ]);

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  _locText(context, tr: 'Etkinlik Detayı', en: 'Event Details', de: 'Veranstaltungsdetails'),
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: <Widget>[
                  _HeaderCard(
                    title: title.isEmpty ? _locText(context, tr: 'İsimsiz etkinlik', en: 'Untitled event', de: 'Unbenannte Veranstaltung') : title,
                    status: status,
                    category: category,
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Etkinlik Bilgileri',
                    icon: Icons.event_note_outlined,
                    children: <Widget>[
                      _InformationRow(
                        label: 'Etkinlik kimliği',
                        value: eventId,
                      ),
                      const Divider(height: 24),
                      _InformationRow(
                        label: 'Oluşturan kullanıcı',
                        value: ownerId.isEmpty ? 'Bilgi bulunamadı' : ownerId,
                      ),
                      const Divider(height: 24),
                      _InformationRow(
                        label: 'Durum',
                        value: _statusTitle(context, status),
                      ),
                      const Divider(height: 24),
                      _InformationRow(
                        label: 'Kategori / oyun',
                        value: category.isEmpty ? 'Bilgi bulunamadı' : category,
                      ),
                      if (eventDate != null) ...<Widget>[
                        const Divider(height: 24),
                        _InformationRow(
                          label: 'Etkinlik tarihi',
                          value: _formatDate(eventDate),
                        ),
                      ],
                      if (createdAt != null) ...<Widget>[
                        const Divider(height: 24),
                        _InformationRow(
                          label: 'Oluşturulma tarihi',
                          value: _formatDate(createdAt),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Konum',
                    icon: Icons.location_on_outlined,
                    children: <Widget>[
                      _InformationRow(
                        label: _locText(context, tr: 'Şehir', en: 'City', de: 'Stadt'),
                        value: city.isEmpty ? 'Bilgi bulunamadı' : city,
                      ),
                      const Divider(height: 24),
                      _InformationRow(
                        label: 'İlçe',
                        value: district.isEmpty ? 'Bilgi bulunamadı' : district,
                      ),
                      const Divider(height: 24),
                      _InformationRow(
                        label: 'Adres',
                        value: address.isEmpty ? 'Bilgi bulunamadı' : address,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Katılım Bilgileri',
                    icon: Icons.groups_outlined,
                    children: <Widget>[
                      _InformationRow(
                        label: 'Katılımcı sayısı',
                        value: '$participantCount',
                      ),
                      const Divider(height: 24),
                      _InformationRow(
                        label: 'Başvuru sayısı',
                        value: '$applicationCount',
                      ),
                      const Divider(height: 24),
                      _InformationRow(
                        label: 'Kontenjan',
                        value: participantLimit <= 0
                            ? 'Belirtilmemiş'
                            : '$participantLimit',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Ödeme Bilgileri',
                    icon: Icons.payments_outlined,
                    children: <Widget>[
                      _InformationRow(
                        label: 'Etkinlik türü',
                        value: isPaid ? 'Ücretli' : 'Ücretsiz',
                      ),
                      if (isPaid) ...<Widget>[
                        const Divider(height: 24),
                        _InformationRow(
                          label: 'Ücret',
                          value: _money(priceKurus),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: _locText(context, tr: 'Açıklama', en: 'Description', de: 'Beschreibung'),
                    icon: Icons.description_outlined,
                    children: <Widget>[
                      Text(
                        description.isEmpty
                            ? 'Açıklama bulunmuyor.'
                            : description,
                        style: const TextStyle(height: 1.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Admin İşlemleri',
                    icon: Icons.admin_panel_settings_outlined,
                    children: <Widget>[
                      AdminPermissionGate(
                        permission: AdminPermission.eventsModerate,
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.push<bool>(
                                context,
                                MaterialPageRoute<bool>(
                                  builder: (BuildContext context) {
                                    return AdminEventStatusScreen(
                                      eventId: eventId,
                                      currentStatus: status,
                                    );
                                  },
                                ),
                              );
                            },
                            icon: const Icon(Icons.manage_history_outlined),
                            label: const Text('Etkinlik Durumunu Yönet'),
                          ),
                        ),
                      ),
                      AdminPermissionGate(
                        permission: AdminPermission.eventsModerate,
                        child: const SizedBox(height: 10),
                      ),
                      AdminPermissionGate(
                        permission: AdminPermission.auditRead,
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (BuildContext context) {
                                    return AdminEventActionsScreen(
                                      eventId: eventId,
                                    );
                                  },
                                ),
                              );
                            },
                            icon: const Icon(Icons.history_outlined),
                            label: const Text('Admin İşlem Geçmişini Gör'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
    );
  }

  static String _firstString(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = data[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
  }

  static int _firstInt(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = data[key];

      if (value is num) {
        return value.toInt();
      }

      if (value is String) {
        final int? parsed = int.tryParse(value);

        if (parsed != null) {
          return parsed;
        }
      }
    }

    return 0;
  }

  static bool _firstBool(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = data[key];

      if (value is bool) {
        return value;
      }

      if (value is String) {
        if (value.toLowerCase() == 'true') {
          return true;
        }

        if (value.toLowerCase() == 'false') {
          return false;
        }
      }
    }

    return false;
  }

  static int _listCount(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = data[key];

      if (value is List<dynamic>) {
        return value.length;
      }

      if (value is Map<dynamic, dynamic>) {
        return value.length;
      }

      if (value is num) {
        return value.toInt();
      }
    }

    return 0;
  }

  static DateTime? _firstDate(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = data[key];

      if (value is Timestamp) {
        return value.toDate();
      }

      if (value is DateTime) {
        return value;
      }

      if (value is String) {
        final DateTime? parsed = DateTime.tryParse(value);

        if (parsed != null) {
          return parsed;
        }
      }

      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
    }

    return null;
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

  static String _statusTitle(BuildContext context, String value) {
    switch (value) {
      case 'completed':
        return _locText(context, tr: 'Tamamlandı', en: 'Completed', de: 'Abgeschlossen');
      case 'cancelled':
        return _locText(context, tr: 'İptal edildi', en: 'Cancelled', de: 'Abgesagt');
      case 'hidden':
        return 'Gizli';
      default:
        return 'Aktif';
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

  static String _money(int amountKurus) {
    return '${(amountKurus / 100).toStringAsFixed(2)} TL';
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.title,
    required this.status,
    required this.category,
  });

  final String title;
  final String status;
  final String category;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _Label(
                  text: AdminEventDetailScreen._statusTitle(context, status),
                  icon: Icons.circle,
                ),
                if (category.isNotEmpty)
                  _Label(text: category, icon: Icons.sports_esports_outlined),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon),
                const SizedBox(width: 9),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
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

class _InformationRow extends StatelessWidget {
  const _InformationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          child: SelectableText(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
