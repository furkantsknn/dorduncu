import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/event_closure.dart';
import 'package:flutter/services.dart';
import 'admin_event_detail_screen.dart';
import 'admin_user_number.dart';

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

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  String _selectedStatus = 'all';

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
          'Etkinlik Yönetimi',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('events').snapshots(),
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
                      'Etkinlikler yüklenirken bir hata oluştu.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final List<QueryDocumentSnapshot<Map<String, dynamic>>>
              allDocuments = snapshot.data!.docs;

              final List<QueryDocumentSnapshot<Map<String, dynamic>>>
              filteredDocuments = allDocuments.where((document) {
                final Map<String, dynamic> data = document.data();

                final String status = _eventStatus(data);

                if (_selectedStatus != 'all' && status != _selectedStatus) {
                  return false;
                }

                if (_searchText.isEmpty) {
                  return true;
                }

                final String query = _searchText.toLowerCase();

                final String title = _eventTitle(data).toLowerCase();

                final String city = _stringValue(data, <String>[
                  'city',
                  'sehir',
                  'şehir',
                ]).toLowerCase();

                final String ownerId = _stringValue(data, <String>[
                  'ownerId',
                  'creatorId',
                  'userId',
                  'hostId',
                  'olusturanId',
                ]).toLowerCase();

                final String eventId = document.id.toLowerCase();

                return title.contains(query) ||
                    city.contains(query) ||
                    ownerId.contains(query) ||
                    eventId.contains(query);
              }).toList();

              filteredDocuments.sort((a, b) {
                final DateTime aDate = _eventDate(a.data()) ?? DateTime(1970);

                final DateTime bDate = _eventDate(b.data()) ?? DateTime(1970);

                return bDate.compareTo(aDate);
              });

              return Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: _buildStatistics(allDocuments),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (String value) {
                        setState(() {
                          _searchText = value.trim();
                        });
                      },
                      decoration: InputDecoration(
                        hintText:
                            'Etkinlik, şehir, kullanıcı veya etkinlik no ara',
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
                        _buildFilter('active', 'Aktif'),
                        _buildFilter(
                          'completed',
                          _locText(
                            context,
                            tr: 'Tamamlandı',
                            en: 'Completed',
                            de: 'Abgeschlossen',
                          ),
                        ),
                        _buildFilter('cancelled', 'İptal'),
                        _buildFilter('hidden', 'Gizli'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filteredDocuments.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Bu filtreye uygun etkinlik bulunamadı.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                            itemCount: filteredDocuments.length,
                            separatorBuilder:
                                (BuildContext context, int index) {
                                  return const SizedBox(height: 10);
                                },
                            itemBuilder: (BuildContext context, int index) {
                              final QueryDocumentSnapshot<Map<String, dynamic>>
                              document = filteredDocuments[index];

                              return _buildEventCard(context, document);
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
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    int activeCount = 0;
    int completedCount = 0;
    int cancelledCount = 0;
    int hiddenCount = 0;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in documents) {
      switch (_eventStatus(document.data())) {
        case 'expired':
        case 'legacy_closed':
          break;
        case 'completed':
          completedCount++;
          break;
        case 'cancelled':
          cancelledCount++;
          break;
        case 'hidden':
          hiddenCount++;
          break;
        default:
          activeCount++;
      }
    }

    return Row(
      children: <Widget>[
        Expanded(
          child: _StatisticCard(
            title: 'Aktif',
            count: activeCount,
            icon: Icons.event_available_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatisticCard(
            title: 'Bitti',
            count: completedCount,
            icon: Icons.task_alt_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatisticCard(
            title: 'İptal',
            count: cancelledCount,
            icon: Icons.event_busy_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatisticCard(
            title: 'Gizli',
            count: hiddenCount,
            icon: Icons.visibility_off_outlined,
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
        selected: _selectedStatus == value,
        onSelected: (_) {
          setState(() {
            _selectedStatus = value;
          });
        },
      ),
    );
  }

  Widget _buildEventCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data();

    final String title = _eventTitle(data);
    final String status = _eventStatus(data);

    final String city = _stringValue(data, <String>['city', 'sehir', 'şehir']);

    final String ownerId = _stringValue(data, <String>[
      'ownerId',
      'creatorId',
      'userId',
      'hostId',
      'olusturanId',
    ]);

    final DateTime? eventDate = _eventDate(data);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (BuildContext context) {
                    return AdminEventDetailScreen(eventId: document.id);
                  },
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CircleAvatar(radius: 27, child: Icon(_statusIcon(status))),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: <Widget>[
                            _InfoLabel(
                              text: _statusTitle(status),
                              icon: _statusIcon(status),
                            ),
                            if (city.isNotEmpty)
                              _InfoLabel(
                                text: city,
                                icon: Icons.location_on_outlined,
                              ),
                            if (eventDate != null)
                              _InfoLabel(
                                text: _formatDate(eventDate),
                                icon: Icons.schedule_outlined,
                              ),
                          ],
                        ),
                        if (ownerId.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 8),
                          AdminUserIdentity(uid: ownerId, compact: true),
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
          const Divider(height: 1),
          ExpansionTile(
            key: PageStorageKey<String>('event-technical-${document.id}'),
            tilePadding: const EdgeInsets.symmetric(horizontal: 15),
            childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 14),
            dense: true,
            title: const Text('Teknik ayrıntılar'),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(document.id, overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    tooltip: 'Etkinlik kimliğini kopyala',
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: document.id)),
                    icon: const Icon(Icons.copy_outlined),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _eventTitle(Map<String, dynamic> data) {
    final String title = _stringValue(data, <String>[
      'title',
      'baslik',
      'başlık',
      'eventTitle',
      'name',
      'etkinlikAdi',
    ]);

    if (title.isNotEmpty) return title;
    final String game = _stringValue(data, <String>[
      'gameName',
      'oyun',
      'game',
      'categoryName',
    ]);
    final String city = _stringValue(data, <String>['city', 'sehir', 'şehir']);
    if (game.isNotEmpty && city.isNotEmpty) return '$game · $city';
    if (game.isNotEmpty) return game;
    if (city.isNotEmpty) return 'Etkinlik · $city';
    return 'Başlıksız etkinlik';
  }

  static String _eventStatus(Map<String, dynamic> data) {
    final closure = eventClosure(data);
    if (closure == EventClosure.expired) return 'expired';
    if (closure == EventClosure.legacyClosed) return 'legacy_closed';
    final String value = _stringValue(data, <String>[
      'status',
      'durum',
    ]).toLowerCase();

    switch (value) {
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

  static DateTime? _eventDate(Map<String, dynamic> data) {
    for (final String key in <String>[
      'eventDate',
      'date',
      'startAt',
      'startsAt',
      'tarih',
      'createdAt',
    ]) {
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
    }

    return null;
  }

  static String _stringValue(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = data[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
  }

  String _statusTitle(String value) {
    switch (value) {
      case 'expired':
        return _locText(
          context,
          tr: 'Tarihi geçti',
          en: 'Expired',
          de: 'Abgelaufen',
        );
      case 'legacy_closed':
        return _locText(
          context,
          tr: 'Geçmiş kayıt',
          en: 'Past record',
          de: 'Vergangener Eintrag',
        );
      case 'completed':
        return _locText(
          context,
          tr: 'Tamamlandı',
          en: 'Completed',
          de: 'Abgeschlossen',
        );
      case 'cancelled':
        return _locText(
          context,
          tr: 'İptal edildi',
          en: 'Cancelled',
          de: 'Abgesagt',
        );
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

  String _formatDate(DateTime value) {
    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String year = value.year.toString();
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');

    return '$day.$month.$year $hour:$minute';
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 12),
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

class _InfoLabel extends StatelessWidget {
  const _InfoLabel({required this.text, required this.icon});

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
