import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminAuditLogsScreen extends StatefulWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  State<AdminAuditLogsScreen> createState() =>
      _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends State<AdminAuditLogsScreen> {
  final TextEditingController _searchController =
  TextEditingController();

  String _searchText = '';
  String _selectedType = 'all';

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
          'Admin İşlem Kayıtları',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collectionGroup('admin_actions')
            .orderBy('createdAt', descending: true)
            .limit(500)
            .snapshots(),
        builder: (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Admin işlem kayıtları yüklenirken bir hata oluştu.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final List<QueryDocumentSnapshot<Map<String, dynamic>>> logs =
          snapshot.data!.docs.where((document) {
            final Map<String, dynamic> data = document.data();

            final String action =
                data['action']?.toString().trim() ?? '';

            final String type = _actionType(action);

            if (_selectedType != 'all' &&
                type != _selectedType) {
              return false;
            }

            if (_searchText.isEmpty) {
              return true;
            }

            final String query = _searchText.toLowerCase();

            final String adminId =
                data['adminId']?.toString().toLowerCase() ??
                    data['performedByUid']
                        ?.toString()
                        .toLowerCase() ??
                    '';

            final String targetUserId =
                data['targetUserId']
                    ?.toString()
                    .toLowerCase() ??
                    '';

            final String eventId =
                data['eventId']?.toString().toLowerCase() ?? '';

            final String reason =
                data['reason']?.toString().toLowerCase() ?? '';

            return action.toLowerCase().contains(query) ||
                adminId.contains(query) ||
                targetUserId.contains(query) ||
                eventId.contains(query) ||
                reason.contains(query) ||
                document.id.toLowerCase().contains(query);
          }).toList();

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  12,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (String value) {
                    setState(() {
                      _searchText = value.trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText:
                    'Admin, kullanıcı, etkinlik veya işlem ara',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchText.isEmpty
                        ? null
                        : IconButton(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    _buildFilter('all', 'Tümü'),
                    _buildFilter('account', 'Hesap'),
                    _buildFilter('membership', 'Üyelik'),
                    _buildFilter('event', 'Etkinlik'),
                    _buildFilter('role', 'Yetki'),
                    _buildFilter('wallet', 'Cüzdan'),
                    _buildFilter('system', 'Sistem'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: logs.isEmpty
                    ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Bu filtreye uygun işlem kaydı bulunamadı.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                    : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    32,
                  ),
                  itemCount: logs.length,
                  separatorBuilder: (
                      BuildContext context,
                      int index,
                      ) {
                    return const SizedBox(height: 10);
                  },
                  itemBuilder: (
                      BuildContext context,
                      int index,
                      ) {
                    final QueryDocumentSnapshot<
                        Map<String, dynamic>> document =
                    logs[index];

                    return _AuditLogCard(
                      logId: document.id,
                      data: document.data(),
                      path: document.reference.path,
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

  Widget _buildFilter(
      String value,
      String label,
      ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _selectedType == value,
        onSelected: (_) {
          setState(() {
            _selectedType = value;
          });
        },
      ),
    );
  }

  static String _actionType(String action) {
    final String normalized = action.toLowerCase();

    if (normalized.contains('account')) {
      return 'account';
    }

    if (normalized.contains('plus') ||
        normalized.contains('membership') ||
        normalized.contains('badge')) {
      return 'membership';
    }

    if (normalized.contains('event')) {
      return 'event';
    }

    if (normalized.contains('role') ||
        normalized.contains('admin') ||
        normalized.contains('moderator')) {
      return 'role';
    }

    if (normalized.contains('wallet') ||
        normalized.contains('balance') ||
        normalized.contains('point') ||
        normalized.contains('credit') ||
        normalized.contains('debit')) {
      return 'wallet';
    }

    if (normalized.contains('system') ||
        normalized.contains('settings')) {
      return 'system';
    }

    return 'other';
  }
}

class _AuditLogCard extends StatelessWidget {
  const _AuditLogCard({
    required this.logId,
    required this.data,
    required this.path,
  });

  final String logId;
  final Map<String, dynamic> data;
  final String path;

  @override
  Widget build(BuildContext context) {
    final String action =
        data['action']?.toString().trim() ?? '';

    final String reason =
        data['reason']?.toString().trim() ?? '';

    final String adminId =
        data['adminId']?.toString().trim() ??
            data['performedByUid']?.toString().trim() ??
            '';

    final String targetUserId =
        data['targetUserId']?.toString().trim() ?? '';

    final String eventId =
        data['eventId']?.toString().trim() ?? '';

    final String oldStatus =
        data['oldStatus']?.toString().trim() ??
            data['oldRole']?.toString().trim() ??
            '';

    final String newStatus =
        data['newStatus']?.toString().trim() ??
            data['newRole']?.toString().trim() ??
            '';

    final DateTime? createdAt =
    _dateFromValue(data['createdAt']);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(
              child: Icon(
                _actionIcon(action),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _actionTitle(action),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (reason.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 7),
                    Text(reason),
                  ],
                  if (oldStatus.isNotEmpty ||
                      newStatus.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 9),
                    Text(
                      '${oldStatus.isEmpty ? '—' : oldStatus}'
                          ' → '
                          '${newStatus.isEmpty ? '—' : newStatus}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: <Widget>[
                      if (createdAt != null)
                        _InfoLabel(
                          text: _formatDate(createdAt),
                          icon: Icons.schedule_outlined,
                        ),
                      if (adminId.isNotEmpty)
                        _InfoLabel(
                          text: 'Admin: $adminId',
                          icon: Icons
                              .admin_panel_settings_outlined,
                        ),
                      if (targetUserId.isNotEmpty)
                        _InfoLabel(
                          text: 'Kullanıcı: $targetUserId',
                          icon: Icons.person_outline,
                        ),
                      if (eventId.isNotEmpty)
                        _InfoLabel(
                          text: 'Etkinlik: $eventId',
                          icon: Icons.event_outlined,
                        ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  SelectableText(
                    path,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 3),
                  SelectableText(
                    logId,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _actionTitle(String action) {
    switch (action.toLowerCase()) {
      case 'account_status_changed':
        return 'Hesap durumu değiştirildi';
      case 'plus_membership_granted':
        return 'Plus üyelik verildi';
      case 'plus_membership_removed':
        return 'Plus üyelik kaldırıldı';
      case 'event_status_changed':
        return 'Etkinlik durumu değiştirildi';
      case 'user_role_changed':
        return 'Kullanıcı rolü değiştirildi';
      case 'system_settings_updated':
        return 'Sistem ayarları güncellendi';
      case 'admin_credit':
        return 'Admin bakiye ekledi';
      case 'admin_debit':
        return 'Admin bakiye düşürdü';
      case 'admin_point_credit':
        return 'Admin puan ekledi';
      case 'admin_point_debit':
        return 'Admin puan düşürdü';
      default:
        return action.isEmpty ? 'Admin işlemi' : action;
    }
  }

  static IconData _actionIcon(String action) {
    final String normalized = action.toLowerCase();

    if (normalized.contains('account')) {
      return Icons.manage_accounts_outlined;
    }

    if (normalized.contains('plus') ||
        normalized.contains('membership')) {
      return Icons.workspace_premium_outlined;
    }

    if (normalized.contains('event')) {
      return Icons.event_note_outlined;
    }

    if (normalized.contains('role')) {
      return Icons.admin_panel_settings_outlined;
    }

    if (normalized.contains('wallet') ||
        normalized.contains('balance') ||
        normalized.contains('credit') ||
        normalized.contains('debit') ||
        normalized.contains('point')) {
      return Icons.account_balance_wallet_outlined;
    }

    if (normalized.contains('system') ||
        normalized.contains('settings')) {
      return Icons.settings_outlined;
    }

    return Icons.history_outlined;
  }

  static DateTime? _dateFromValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  static String _formatDate(DateTime value) {
    final String day =
    value.day.toString().padLeft(2, '0');

    final String month =
    value.month.toString().padLeft(2, '0');

    final String year = value.year.toString();

    final String hour =
    value.hour.toString().padLeft(2, '0');

    final String minute =
    value.minute.toString().padLeft(2, '0');

    return '$day.$month.$year $hour:$minute';
  }
}

class _InfoLabel extends StatelessWidget {
  const _InfoLabel({
    required this.text,
    required this.icon,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color:
        Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}