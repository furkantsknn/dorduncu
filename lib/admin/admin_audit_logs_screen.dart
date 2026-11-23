import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_audit_labels.dart';
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

class AdminAuditLogsScreen extends StatefulWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  State<AdminAuditLogsScreen> createState() => _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends State<AdminAuditLogsScreen> {
  final TextEditingController _searchController = TextEditingController();

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
        title: Text(
          _locText(
            context,
            tr: 'Admin İşlem Kayıtları',
            en: 'Admin Audit Logs',
            de: 'Admin-Audit-Protokolle',
          ),
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('audit_logs')
            .orderBy('createdAt', descending: true)
            .limit(500)
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
                      'Admin işlem kayıtları yüklenirken bir hata oluştu.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final List<QueryDocumentSnapshot<Map<String, dynamic>>>
              logs = snapshot.data!.docs.where((document) {
                final Map<String, dynamic> data = document.data();
                final Map<String, dynamic> metadata = _metadata(
                  data['metadata'],
                );

                final String action = data['action']?.toString().trim() ?? '';

                final String type = _actionType(action);

                if (_selectedType != 'all' && type != _selectedType) {
                  return false;
                }

                if (_searchText.isEmpty) {
                  return true;
                }

                final String query = _searchText.toLowerCase();

                final String adminId =
                    data['performedBy']?.toString().toLowerCase() ?? '';

                final String targetUserId =
                    data['targetUid']?.toString().toLowerCase() ?? '';

                final String eventId =
                    metadata['eventId']?.toString().toLowerCase() ?? '';

                final String reason =
                    metadata['reason']?.toString().toLowerCase() ?? '';

                final String role =
                    metadata['performedByRole']?.toString().toLowerCase() ?? '';

                return action.toLowerCase().contains(query) ||
                    adminId.contains(query) ||
                    targetUserId.contains(query) ||
                    eventId.contains(query) ||
                    reason.contains(query) ||
                    role.contains(query) ||
                    document.id.toLowerCase().contains(query);
              }).toList();

              return Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (String value) {
                        setState(() {
                          _searchText = value.trim();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Admin, kullanıcı, etkinlik veya işlem ara',
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      children: <Widget>[
                        _buildFilter('all', 'Tümü'),
                        _buildFilter('account', 'Hesap'),
                        _buildFilter('membership', 'Üyelik'),
                        _buildFilter('event', 'Etkinlik'),
                        _buildFilter('role', 'Yetki'),
                        _buildFilter('wallet', 'Cüzdan'),
                        _buildFilter('support', 'Destek'),
                        _buildFilter('verification', 'Doğrulama'),
                        _buildFilter('content', 'İçerik'),
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
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                            itemCount: logs.length,
                            separatorBuilder:
                                (BuildContext context, int index) {
                                  return const SizedBox(height: 10);
                                },
                            itemBuilder: (BuildContext context, int index) {
                              final QueryDocumentSnapshot<Map<String, dynamic>>
                              document = logs[index];

                              return _AuditLogCard(
                                logId: document.id,
                                data: document.data(),
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

  Widget _buildFilter(String value, String label) {
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

  static Map<String, dynamic> _metadata(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map(
        (dynamic key, dynamic item) => MapEntry(key.toString(), item),
      );
    }

    return <String, dynamic>{};
  }

  static String _actionType(String action) {
    final String normalized = action.toLowerCase();

    if (normalized.contains('support')) {
      return 'support';
    }

    if (normalized.contains('verification') ||
        normalized.contains('document')) {
      return 'verification';
    }

    if (normalized.contains('market') ||
        normalized.contains('notification') ||
        normalized.contains('content')) {
      return 'content';
    }

    if (normalized.contains('wallet') ||
        normalized.contains('withdraw') ||
        normalized.contains('payment')) {
      return 'wallet';
    }

    if (normalized.contains('event')) {
      return 'event';
    }

    if (normalized.contains('role')) {
      return 'role';
    }

    if (normalized.contains('membership') ||
        normalized.contains('badge') ||
        normalized.contains('plus')) {
      return 'membership';
    }

    if (normalized.contains('account') || normalized.contains('user')) {
      return 'account';
    }

    return 'system';
  }
}

class _AuditLogCard extends StatelessWidget {
  const _AuditLogCard({required this.logId, required this.data});

  final String logId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final String action = data['action']?.toString().trim() ?? 'unknown';

    final String performedBy = data['performedBy']?.toString().trim() ?? '';

    final String targetUid = data['targetUid']?.toString().trim() ?? '';

    final Map<String, dynamic> metadata = _AdminAuditLogsScreenState._metadata(
      data['metadata'],
    );

    final String role = metadata['performedByRole']?.toString().trim() ?? '';

    final String reason = metadata['reason']?.toString().trim() ?? '';

    final Timestamp? createdAt = data['createdAt'] is Timestamp
        ? data['createdAt'] as Timestamp
        : null;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.shield_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    adminAuditTitle(context, action),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                if (createdAt != null)
                  Text(
                    _formatDate(createdAt.toDate()),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (performedBy.isNotEmpty)
              AdminUserIdentity(uid: performedBy, compact: true),
            if (role.isNotEmpty) _line('Rol', role),
            if (targetUid.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              AdminUserIdentity(uid: targetUid, compact: true),
            ],
            if (reason.isNotEmpty)
              _line(
                _locText(
                  context,
                  tr: 'Açıklama',
                  en: 'Description',
                  de: 'Beschreibung',
                ),
                reason,
              ),
            if (metadata.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text(
                  'Teknik detaylar',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                children: <Widget>[
                  _line('Ham olay kodu', action),
                  _line('İşlem ID', logId),
                  if (performedBy.isNotEmpty) _line('Aktör UID', performedBy),
                  if (targetUid.isNotEmpty) _line('Hedef UID', targetUid),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(metadata.toString()),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _line(String label, String value) {
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SelectableText('$label: $value'),
    );
  }

  static String _formatDate(DateTime value) {
    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String year = value.year.toString();
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');

    return '$day.$month.$year $hour:$minute';
  }
}
