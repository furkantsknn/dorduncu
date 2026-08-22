import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'support_request_detail_screen.dart';

class SupportRequestsScreen extends StatefulWidget {
  const SupportRequestsScreen({super.key});

  @override
  State<SupportRequestsScreen> createState() => _SupportRequestsScreenState();
}

class _SupportRequestsScreenState extends State<SupportRequestsScreen> {
  Key _streamKey = UniqueKey();

  Future<void> _refresh() async {
    setState(() => _streamKey = UniqueKey());
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xff0F1115),
      appBar: AppBar(
        title: const Text('Destek Taleplerim'),
        backgroundColor: const Color(0xff0F1115),
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? const _StateMessage(
        icon: Icons.login,
        title: 'Oturum bulunamadı',
        message: 'Taleplerini görmek için telefon numaranla giriş yap.',
      )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        key: _streamKey,
        stream: FirebaseFirestore.instance
            .collection('support_requests')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _StateMessage(
              icon: Icons.error_outline,
              title: 'Talepler yüklenemedi',
              message: 'İnternet bağlantını kontrol edip tekrar dene.',
              actionLabel: 'Tekrar Dene',
              onAction: _refresh,
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          }

          final documents = [...?snapshot.data?.docs]
            ..sort((a, b) {
              final aDate = a.data()['createdAt'] as Timestamp?;
              final bDate = b.data()['createdAt'] as Timestamp?;
              return (bDate?.millisecondsSinceEpoch ?? 0).compareTo(
                aDate?.millisecondsSinceEpoch ?? 0,
              );
            });

          if (documents.isEmpty) {
            return RefreshIndicator(
              color: Colors.orange,
              onRefresh: _refresh,
              child: const CustomScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _StateMessage(
                      icon: Icons.inbox_outlined,
                      title: 'Henüz destek talebin yok',
                      message:
                      'Oluşturduğun destek talepleri burada görüntülenecek.',
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: Colors.orange,
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: documents.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final document = documents[index];
                final data = document.data();
                final status = (data['status'] as String?) ?? 'open';
                final category =
                    (data['category'] as String?) ?? 'Destek Talebi';
                final message = (data['message'] as String?) ?? '';
                final adminReply =
                    (data['adminReply'] as String?)?.trim() ?? '';
                final createdAt = data['createdAt'] as Timestamp?;

                return Card(
                  color: const Color(0xff171A20),
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Colors.white12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SupportRequestDetailScreen(
                            requestId: document.id,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(17),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  category,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.white38,
                              ),
                            ],
                          ),
                          if (message.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                height: 1.4,
                              ),
                            ),
                          ],
                          if (adminReply.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Row(
                              children: [
                                Icon(
                                  Icons.mark_chat_unread_outlined,
                                  color: Colors.orange,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Destek ekibi yanıtladı',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _StatusBadge(status: status),
                              const Spacer(),
                              Text(
                                _formatDate(createdAt?.toDate()),
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

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
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => onAction?.call(),
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel!),
              ),
            ],
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
      return 'Yanıt Bekleniyor';
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

String _formatDate(DateTime? date) {
  if (date == null) return 'Tarih bekleniyor';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}
