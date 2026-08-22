import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminUserActionsScreen extends StatelessWidget {
  const AdminUserActionsScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin İşlem Geçmişi',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('admin_actions')
            .orderBy('createdAt', descending: true)
            .limit(200)
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
                  'Admin işlem geçmişi yüklenirken bir hata oluştu.',
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

          final List<QueryDocumentSnapshot<Map<String, dynamic>>> documents =
              snapshot.data!.docs;

          if (documents.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Bu kullanıcı için kayıtlı admin işlemi bulunmuyor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: documents.length,
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
              final QueryDocumentSnapshot<Map<String, dynamic>> document =
              documents[index];

              return _AdminActionCard(
                actionId: document.id,
                data: document.data(),
              );
            },
          );
        },
      ),
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  const _AdminActionCard({
    required this.actionId,
    required this.data,
  });

  final String actionId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final String action = data['action']?.toString().trim() ?? '';

    final String reason = data['reason']?.toString().trim() ?? '';

    final String adminId =
        data['adminId']?.toString().trim() ??
            data['performedByUid']?.toString().trim() ??
            '';

    final String oldStatus =
        data['oldStatus']?.toString().trim() ?? '';

    final String newStatus =
        data['newStatus']?.toString().trim() ?? '';

    final DateTime? createdAt = _dateFromValue(data['createdAt']);

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
                  if (oldStatus.isNotEmpty || newStatus.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 9),
                    Text(
                      '${oldStatus.isEmpty ? '—' : _statusTitle(oldStatus)}'
                          ' → '
                          '${newStatus.isEmpty ? '—' : _statusTitle(newStatus)}',
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
                          icon: Icons.admin_panel_settings_outlined,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    actionId,
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

  static String _actionTitle(String value) {
    switch (value.toLowerCase()) {
      case 'account_status_changed':
        return 'Hesap durumu değiştirildi';
      case 'plus_membership_granted':
        return 'Plus üyelik verildi';
      case 'plus_membership_removed':
        return 'Plus üyelik kaldırıldı';
      case 'player_badge_granted':
        return 'Oyuncu rozeti verildi';
      case 'player_badge_removed':
        return 'Oyuncu rozeti kaldırıldı';
      case 'user_warning_added':
        return 'Kullanıcıya uyarı verildi';
      default:
        return value.isEmpty ? 'Admin işlemi' : value;
    }
  }

  static IconData _actionIcon(String value) {
    switch (value.toLowerCase()) {
      case 'account_status_changed':
        return Icons.manage_accounts_outlined;
      case 'plus_membership_granted':
        return Icons.workspace_premium_outlined;
      case 'plus_membership_removed':
        return Icons.remove_circle_outline;
      case 'player_badge_granted':
        return Icons.verified_outlined;
      case 'player_badge_removed':
        return Icons.verified_user_outlined;
      case 'user_warning_added':
        return Icons.warning_amber_outlined;
      default:
        return Icons.history_outlined;
    }
  }

  static String _statusTitle(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return 'Aktif';
      case 'blocked':
      case 'banned':
        return 'Engelli';
      case 'suspended':
        return 'Askıda';
      case 'disabled':
        return 'Pasif';
      default:
        return value;
    }
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
    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String year = value.year.toString();
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');

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
        color: Theme.of(context).colorScheme.secondaryContainer,
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