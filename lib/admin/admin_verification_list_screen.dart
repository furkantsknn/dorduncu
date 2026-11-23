import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_user_number.dart';
import 'admin_verification_detail_screen.dart';

class AdminVerificationListScreen extends StatefulWidget {
  const AdminVerificationListScreen({
    super.key,
    this.initialStatus = 'all',
    this.embedded = false,
  });
  final String initialStatus;
  final bool embedded;

  @override
  State<AdminVerificationListScreen> createState() =>
      _AdminVerificationListScreenState();
}

class _AdminVerificationListScreenState
    extends State<AdminVerificationListScreen> {
  final TextEditingController _searchController = TextEditingController();

  late String _selectedStatus;
  String _searchText = '';
  String? _managementUid;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatus;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text(
                'Oyuncu Başvuruları',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('verification_requests')
            .orderBy('createdAt', descending: true)
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
                      'Oyuncu başvuruları yüklenirken bir hata oluştu.',
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

                final String status = data['status']?.toString() ?? 'pending';

                if (_selectedStatus != 'all' && status != _selectedStatus) {
                  return false;
                }

                if (_searchText.isEmpty) {
                  return true;
                }

                if (_searchText.toUpperCase().startsWith('U-')) {
                  return document.id == _managementUid;
                }

                final String query = _searchText.toLowerCase();

                final String name = data['ad']?.toString().toLowerCase() ?? '';

                final String surname =
                    data['soyad']?.toString().toLowerCase() ?? '';

                final String phone =
                    data['telefon']?.toString().toLowerCase() ?? '';

                final String uid =
                    data['uid']?.toString().toLowerCase() ??
                    document.id.toLowerCase();

                return name.contains(query) ||
                    surname.contains(query) ||
                    '$name $surname'.contains(query) ||
                    phone.contains(query) ||
                    uid.contains(query);
              }).toList();

              return CustomScrollView(
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
                        onChanged: (String value) async {
                          final normalized = value.trim();
                          final uid = await findUidByManagementNumber(
                            normalized,
                          );
                          if (!mounted ||
                              _searchController.text.trim() != normalized) {
                            return;
                          }
                          setState(() {
                            _searchText = normalized;
                            _managementUid = uid;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Ad, soyad, telefon veya kullanıcı ara',
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
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        children: <Widget>[
                          _buildStatusFilter(value: 'all', label: 'Tümü'),
                          _buildStatusFilter(
                            value: 'pending',
                            label: 'Bekleyen',
                          ),
                          _buildStatusFilter(
                            value: 'approved',
                            label: 'Onaylanan',
                          ),
                          _buildStatusFilter(
                            value: 'revision',
                            label: 'Revizyon',
                          ),
                          _buildStatusFilter(
                            value: 'rejected',
                            label: 'Reddedilen',
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
                                Icons.verified_user_outlined,
                                size: 54,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Bu filtreye uygun oyuncu başvurusu bulunamadı.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w700),
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
                        separatorBuilder: (BuildContext context, int index) {
                          return const SizedBox(height: 12);
                        },
                        itemBuilder: (BuildContext context, int index) {
                          return _buildApplicationCard(
                            context: context,
                            document: filteredDocuments[index],
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

  Widget _buildStatistics(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    int pendingCount = 0;
    int approvedCount = 0;
    int revisionCount = 0;
    int rejectedCount = 0;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in documents) {
      final String status = document.data()['status']?.toString() ?? 'pending';

      switch (status) {
        case 'approved':
          approvedCount++;
          break;
        case 'revision':
          revisionCount++;
          break;
        case 'rejected':
          rejectedCount++;
          break;
        case 'pending':
        default:
          pendingCount++;
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
              title: 'Bekleyen',
              count: pendingCount,
              icon: Icons.hourglass_top_rounded,
              color: Colors.orange,
              onTap: () {
                setState(() {
                  _selectedStatus = 'pending';
                });
              },
            ),
            _StatisticCard(
              width: itemWidth,
              title: 'Onaylanan',
              count: approvedCount,
              icon: Icons.verified_rounded,
              color: Colors.green,
              onTap: () {
                setState(() {
                  _selectedStatus = 'approved';
                });
              },
            ),
            _StatisticCard(
              width: itemWidth,
              title: 'Revizyon',
              count: revisionCount,
              icon: Icons.edit_note_rounded,
              color: Colors.deepOrange,
              onTap: () {
                setState(() {
                  _selectedStatus = 'revision';
                });
              },
            ),
            _StatisticCard(
              width: itemWidth,
              title: 'Reddedilen',
              count: rejectedCount,
              icon: Icons.cancel_outlined,
              color: Colors.red,
              onTap: () {
                setState(() {
                  _selectedStatus = 'rejected';
                });
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusFilter({required String value, required String label}) {
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

  Widget _buildApplicationCard({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> document,
  }) {
    final Map<String, dynamic> data = document.data();

    final String userId =
        data['uid']?.toString().trim() ??
        data['userId']?.toString().trim() ??
        document.id;

    final String status = data['status']?.toString() ?? 'pending';

    final Timestamp? createdAt = data['createdAt'] is Timestamp
        ? data['createdAt'] as Timestamp
        : null;

    final Color statusColor = _statusColor(status);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  AdminVerificationDetailScreen(requestId: document.id),
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
                  Expanded(child: AdminUserIdentity(uid: userId)),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _StatusLabel(label: _statusTitle(status), color: statusColor),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Belge ve iletişim ayrıntıları detay ekranında',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
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
            ],
          ),
        ),
      ),
    );
  }

  String _statusTitle(String status) {
    switch (status) {
      case 'approved':
        return 'Onaylandı';
      case 'revision':
        return 'Revizyon istendi';
      case 'rejected':
        return 'Reddedildi';
      case 'expired':
        return 'Süresi Doldu';
      case 'pending':
      default:
        return 'Bekliyor';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'revision':
        return Colors.deepOrange;
      case 'rejected':
        return Colors.red;
      case 'expired':
        return Colors.grey;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  String _formatDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');

    final String month = date.month.toString().padLeft(2, '0');

    final String hour = date.hour.toString().padLeft(2, '0');

    final String minute = date.minute.toString().padLeft(2, '0');

    return '$day.$month.${date.year} $hour:$minute';
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

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 6),
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
