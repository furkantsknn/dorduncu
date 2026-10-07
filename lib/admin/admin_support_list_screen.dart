import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'admin_access.dart';
import 'admin_support_detail_screen.dart';

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


class AdminSupportListScreen extends StatefulWidget {
  const AdminSupportListScreen({super.key});

  @override
  State<AdminSupportListScreen> createState() => _AdminSupportListScreenState();
}

class _AdminSupportListScreenState extends State<AdminSupportListScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedStatus = 'all';
  String _selectedCategory = 'all';
  String _selectedUrgency = 'all';
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _migrateLegacyPrivateNotes();
  }

  Future<void> _migrateLegacyPrivateNotes() async {
    try {
      final Map<String, dynamic>? claims = await AdminAccess.currentClaims();

      if (AdminAccess.roleFromClaims(claims) != 'super_admin') {
        return;
      }

      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('adminMigrateSupportPrivateNotes');

      await callable.call<void>();
    } catch (_) {
      // Privacy rules already protect legacy non-empty notes.
      // Migration will retry when a super admin opens this screen.
    }
  }

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
          'Destek Talepleri',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('support_requests')
            .orderBy('createdAt', descending: true)
            .limit(250)
            .snapshots(),
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
                      'Destek talepleri yüklenirken bir hata oluştu.',
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
              filteredDocuments = allDocuments.where((
                QueryDocumentSnapshot<Map<String, dynamic>> document,
              ) {
                final Map<String, dynamic> data = document.data();

                final String status = data['status']?.toString() ?? 'new';

                if (_selectedStatus != 'all' && status != _selectedStatus) {
                  return false;
                }

                final String category = data['category']?.toString() ?? '';
                if (_selectedCategory != 'all' &&
                    category != _selectedCategory) {
                  return false;
                }

                final String urgency = data['urgency']?.toString() ?? 'normal';
                if (_selectedUrgency != 'all' && urgency != _selectedUrgency) {
                  return false;
                }

                if (_searchText.isEmpty) {
                  return true;
                }

                final String query = _searchText.toLowerCase();

                final String subject =
                    data['subject']?.toString().toLowerCase() ?? '';

                final String categorySearch =
                    data['category']?.toString().toLowerCase() ?? '';

                final String userId =
                    data['userId']?.toString().toLowerCase() ?? '';

                final String description =
                    data['description']?.toString().toLowerCase() ?? '';

                final String requestId = document.id.toLowerCase();

                return subject.contains(query) ||
                    categorySearch.contains(query) ||
                    userId.contains(query) ||
                    description.contains(query) ||
                    requestId.contains(query);
              }).toList();

              filteredDocuments.sort((
                QueryDocumentSnapshot<Map<String, dynamic>> a,
                QueryDocumentSnapshot<Map<String, dynamic>> b,
              ) {
                final Map<String, dynamic> aData = a.data();
                final Map<String, dynamic> bData = b.data();

                final int aPriority =
                    (aData['priorityScore'] as num?)?.toInt() ?? 0;
                final int bPriority =
                    (bData['priorityScore'] as num?)?.toInt() ?? 0;

                final int priorityCompare = bPriority.compareTo(aPriority);
                if (priorityCompare != 0) {
                  return priorityCompare;
                }

                final Timestamp? aCreated = aData['createdAt'] as Timestamp?;
                final Timestamp? bCreated = bData['createdAt'] as Timestamp?;

                return (bCreated?.millisecondsSinceEpoch ?? 0).compareTo(
                  aCreated?.millisecondsSinceEpoch ?? 0,
                );
              });

              return Column(
                children: <Widget>[
                  Expanded(
                    child: CustomScrollView(
                      slivers: <Widget>[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                            child: _buildStatistics(allDocuments),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
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
                                    'Başlık, kategori, kullanıcı veya talep no ara',
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
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 48,
                            child: ListView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              scrollDirection: Axis.horizontal,
                              children: <Widget>[
                                _buildStatusFilter(value: 'all', label: 'Tümü'),
                                _buildStatusFilter(value: 'new', label: 'Yeni'),
                                _buildStatusFilter(
                                  value: 'reviewing',
                                  label: 'İnceleniyor',
                                ),
                                _buildStatusFilter(
                                  value: 'answered',
                                  label: 'Yanıtlandı',
                                ),
                                _buildStatusFilter(
                                  value: 'closed',
                                  label: 'Kapatıldı',
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedCategory,
                                    decoration: const InputDecoration(
                                      labelText: 'Kategori',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    items: <DropdownMenuItem<String>>[
                                      DropdownMenuItem(
                                        value: 'all',
                                        child: Text('Tümü'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'suggestion',
                                        child: Text('Öneri'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'bug_report',
                                        child: Text('Hata'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'general_support',
                                        child: Text('Genel destek'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'payment_issue',
                                        child: Text('Ödeme'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'account_appeal',
                                        child: Text('Hesap itirazı'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'user_report',
                                        child: Text(_locText(context, tr: 'Kullanıcı', en: 'User', de: 'Nutzer')),
                                      ),
                                      DropdownMenuItem(
                                        value: 'event_report',
                                        child: Text('Etkinlik'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'message_report',
                                        child: Text('Mesaj'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'inappropriate_image',
                                        child: Text('Görsel'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'security_emergency',
                                        child: Text('Güvenlik'),
                                      ),
                                    ],
                                    onChanged: (String? value) {
                                      setState(
                                        () =>
                                            _selectedCategory = value ?? 'all',
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedUrgency,
                                    decoration: const InputDecoration(
                                      labelText: 'Aciliyet',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    items: <DropdownMenuItem<String>>[
                                      DropdownMenuItem(
                                        value: 'all',
                                        child: Text('Tümü'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'low',
                                        child: Text('Düşük'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'normal',
                                        child: Text('Normal'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'high',
                                        child: Text('Yüksek'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'critical',
                                        child: Text('Kritik'),
                                      ),
                                    ],
                                    onChanged: (String? value) {
                                      setState(
                                        () => _selectedUrgency = value ?? 'all',
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 10)),
                        if (filteredDocuments.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.support_agent_outlined,
                                      size: 52,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 14),
                                    const Text(
                                      'Bu filtreye uygun destek talebi bulunamadı.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                            sliver: SliverList.separated(
                              itemCount: filteredDocuments.length,
                              separatorBuilder:
                                  (BuildContext context, int index) {
                                    return const SizedBox(height: 12);
                                  },
                              itemBuilder: (BuildContext context, int index) {
                                final QueryDocumentSnapshot<
                                  Map<String, dynamic>
                                >
                                document = filteredDocuments[index];

                                return _buildSupportCard(
                                  context: context,
                                  document: document,
                                );
                              },
                            ),
                          ),
                      ],
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
    int newCount = 0;
    int reviewingCount = 0;
    int answeredCount = 0;
    int closedCount = 0;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in documents) {
      final String status = document.data()['status']?.toString() ?? 'new';

      switch (status) {
        case 'reviewing':
          reviewingCount++;
          break;
        case 'answered':
          answeredCount++;
          break;
        case 'closed':
          closedCount++;
          break;
        case 'new':
        default:
          newCount++;
      }
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double itemWidth = (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _StatisticCard(
              width: itemWidth,
              title: 'Yeni',
              count: newCount,
              icon: Icons.fiber_new_rounded,
              color: Colors.orange,
              onTap: () {
                setState(() {
                  _selectedStatus = 'new';
                });
              },
            ),
            _StatisticCard(
              width: itemWidth,
              title: 'İnceleniyor',
              count: reviewingCount,
              icon: Icons.manage_search_rounded,
              color: Colors.blue,
              onTap: () {
                setState(() {
                  _selectedStatus = 'reviewing';
                });
              },
            ),
            _StatisticCard(
              width: itemWidth,
              title: 'Yanıtlandı',
              count: answeredCount,
              icon: Icons.mark_email_read_outlined,
              color: Colors.green,
              onTap: () {
                setState(() {
                  _selectedStatus = 'answered';
                });
              },
            ),
            _StatisticCard(
              width: itemWidth,
              title: 'Kapatıldı',
              count: closedCount,
              icon: Icons.check_circle_outline,
              color: Colors.grey,
              onTap: () {
                setState(() {
                  _selectedStatus = 'closed';
                });
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusFilter({required String value, required String label}) {
    final bool selected = _selectedStatus == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _selectedStatus = value;
          });
        },
      ),
    );
  }

  Widget _buildSupportCard({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> document,
  }) {
    final Map<String, dynamic> data = document.data();

    final String status = data['status']?.toString() ?? 'new';

    final String category = data['category']?.toString() ?? '';

    final String subject = data['subject']?.toString() ?? '';

    final String userId = data['userId']?.toString() ?? '';

    final String urgency = data['urgency']?.toString() ?? 'normal';

    final List<dynamic> attachmentUrls = data['attachmentUrls'] is List<dynamic>
        ? data['attachmentUrls'] as List<dynamic>
        : const <dynamic>[];

    final Timestamp? createdAt = data['createdAt'] is Timestamp
        ? data['createdAt'] as Timestamp
        : null;

    final Color statusColor = _statusColor(status);
    final Color urgencyColor = _urgencyColor(urgency);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (BuildContext context) {
                return AdminSupportDetailScreen(requestId: document.id);
              },
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CircleAvatar(
                    backgroundColor: statusColor.withValues(alpha: 0.14),
                    child: Icon(
                      Icons.support_agent_rounded,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          subject.isEmpty ? _categoryTitle(category) : subject,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _categoryTitle(category),
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _SmallLabel(
                    icon: Icons.circle,
                    label: _statusTitle(status),
                    color: statusColor,
                  ),
                  _SmallLabel(
                    icon: Icons.priority_high_rounded,
                    label: _urgencyTitle(urgency),
                    color: urgencyColor,
                  ),
                  if (attachmentUrls.isNotEmpty)
                    _SmallLabel(
                      icon: Icons.attach_file,
                      label: '${attachmentUrls.length} ek dosya',
                      color: Theme.of(context).colorScheme.primary,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      userId.isEmpty
                          ? 'Kullanıcı bilgisi yok'
                          : 'Kullanıcı: $userId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (createdAt != null)
                    Text(
                      _formatDate(createdAt.toDate()),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                'Talep no: ${document.id}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');

    final String month = date.month.toString().padLeft(2, '0');

    final String hour = date.hour.toString().padLeft(2, '0');

    final String minute = date.minute.toString().padLeft(2, '0');

    return '$day.$month.${date.year} $hour:$minute';
  }

  String _categoryTitle(String category) {
    switch (category) {
      case 'suggestion':
        return 'Öneri';
      case 'bugReport':
      case 'bug_report':
        return 'Hata Bildirimi';
      case 'generalSupport':
      case 'general_support':
        return 'Genel Destek';
      case 'paymentIssue':
      case 'payment_issue':
        return 'Ödeme Sorunu';
      case 'accountAppeal':
      case 'account_appeal':
        return 'Hesap İtirazı';
      case 'userReport':
      case 'user_report':
        return 'Kullanıcı Şikâyeti';
      case 'eventReport':
      case 'event_report':
        return 'Etkinlik Şikâyeti';
      case 'messageReport':
      case 'message_report':
        return 'Mesaj Şikâyeti';
      case 'inappropriateImage':
      case 'inappropriate_image':
        return 'Uygunsuz Görsel';
      case 'securityEmergency':
      case 'security_emergency':
        return 'Güvenlik Bildirimi';
      default:
        return category.isEmpty ? 'Destek Talebi' : category;
    }
  }

  String _statusTitle(String status) {
    switch (status) {
      case 'reviewing':
        return 'İnceleniyor';
      case 'answered':
        return 'Yanıtlandı';
      case 'closed':
        return 'Kapatıldı';
      case 'new':
      default:
        return 'Yeni';
    }
  }

  String _urgencyTitle(String urgency) {
    switch (urgency) {
      case 'low':
        return 'Düşük';
      case 'high':
        return 'Yüksek';
      case 'critical':
      case 'emergency':
        return 'Acil';
      case 'normal':
      default:
        return 'Normal';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'reviewing':
        return Colors.blue;
      case 'answered':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      case 'new':
      default:
        return Colors.orange;
    }
  }

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'low':
        return Colors.green;
      case 'high':
        return Colors.deepOrange;
      case 'critical':
      case 'emergency':
        return Colors.red;
      case 'normal':
      default:
        return Colors.blueGrey;
    }
  }
}

class _StatisticCard extends StatelessWidget {
  const _StatisticCard({
    required this.width,
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final double width;
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallLabel extends StatelessWidget {
  const _SmallLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
