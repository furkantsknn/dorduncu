import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SupportRequestDetailScreen extends StatelessWidget {
  const SupportRequestDetailScreen({
    super.key,
    required this.requestId,
  });

  final String requestId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F1115),
      appBar: AppBar(
        title: const Text('Talep Detayı'),
        backgroundColor: const Color(0xff0F1115),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('support_requests')
            .doc(requestId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _StateMessage(
              icon: Icons.error_outline,
              title: 'Talep yüklenemedi',
              message: 'İnternet bağlantını kontrol edip tekrar dene.',
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          }

          final data = snapshot.data?.data();
          if (data == null) {
            return const _StateMessage(
              icon: Icons.search_off_outlined,
              title: 'Talep bulunamadı',
              message: 'Bu talep silinmiş veya erişime kapatılmış olabilir.',
            );
          }

          final status = (data['status'] as String?) ?? 'open';
          final adminReply = (data['adminReply'] as String?)?.trim() ?? '';
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
          final closedAt = (data['closedAt'] as Timestamp?)?.toDate();
          final priority = (data['priority'] as String?)?.trim() ?? '';

          return ListView(
            padding: const EdgeInsets.all(22),
            children: [
              _StatusHeader(status: status),
              const SizedBox(height: 16),
              _Section(
                icon: Icons.category_outlined,
                title: 'Konu',
                value: (data['category'] as String?) ?? 'Destek Talebi',
              ),
              _Section(
                icon: Icons.chat_bubble_outline,
                title: 'Mesajım',
                value: (data['message'] as String?) ?? '-',
              ),
              _Section(
                icon: Icons.support_agent_outlined,
                title: 'Destek Ekibinin Yanıtı',
                value: adminReply.isEmpty
                    ? 'Destek ekibinin cevabı henüz eklenmedi.'
                    : adminReply,
                highlighted: adminReply.isNotEmpty,
              ),
              if (priority.isNotEmpty)
                _Section(
                  icon: Icons.flag_outlined,
                  title: 'Öncelik',
                  value: _priorityLabel(priority),
                ),
              _Section(
                icon: Icons.calendar_today_outlined,
                title: 'Oluşturulma Tarihi',
                value: _formatDateTime(createdAt),
              ),
              _Section(
                icon: Icons.update_outlined,
                title: 'Son Güncelleme',
                value: _formatDateTime(updatedAt),
              ),
              if (closedAt != null)
                _Section(
                  icon: Icons.lock_outline,
                  title: 'Kapatılma Tarihi',
                  value: _formatDateTime(closedAt),
                ),
              const SizedBox(height: 4),
              const Text(
                'Talep durumundaki ve destek yanıtındaki değişiklikler bu ekrana otomatik olarak yansır.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(_statusIcon(status), color: color, size: 30),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Talep Durumu',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  _statusLabel(status),
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.value,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: highlighted
            ? Colors.orange.withValues(alpha: 0.08)
            : const Color(0xff171A20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted
              ? Colors.orange.withValues(alpha: 0.35)
              : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: highlighted ? Colors.orange : Colors.white54,
              ),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  color: highlighted ? Colors.orange : Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          SelectableText(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.orange, size: 62),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'reviewing':
      return 'İnceleniyor';
    case 'waiting_user':
      return 'Kullanıcı Yanıtı Bekleniyor';
    case 'resolved':
      return 'Çözüldü';
    case 'rejected':
      return 'Reddedildi';
    case 'closed':
      return 'Kapatıldı';
    case 'open':
    default:
      return 'Açık';
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'resolved':
      return Colors.green;
    case 'rejected':
    case 'closed':
      return Colors.redAccent;
    case 'reviewing':
    case 'waiting_user':
      return Colors.amber;
    case 'open':
    default:
      return Colors.orange;
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'resolved':
      return Icons.check_circle_outline;
    case 'rejected':
      return Icons.cancel_outlined;
    case 'closed':
      return Icons.lock_outline;
    case 'reviewing':
      return Icons.manage_search_outlined;
    case 'waiting_user':
      return Icons.mark_chat_unread_outlined;
    case 'open':
    default:
      return Icons.schedule_outlined;
  }
}

String _priorityLabel(String priority) {
  switch (priority) {
    case 'urgent':
      return 'Acil';
    case 'high':
      return 'Yüksek';
    case 'low':
      return 'Düşük';
    case 'normal':
    default:
      return 'Normal';
  }
}

String _formatDateTime(DateTime? date) {
  if (date == null) return 'Tarih bekleniyor';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day.$month.${date.year} $hour:$minute';
}
