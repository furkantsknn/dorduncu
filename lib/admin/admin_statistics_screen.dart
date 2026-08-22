import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminStatisticsScreen extends StatelessWidget {
  const AdminStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'İstatistikler',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .snapshots(),
        builder: (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> usersSnapshot,
            ) {
          if (usersSnapshot.hasError) {
            return const Center(
              child: Text(
                'İstatistikler yüklenirken bir hata oluştu.',
              ),
            );
          }

          if (!usersSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('events')
                .snapshots(),
            builder: (
                BuildContext context,
                AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                eventsSnapshot,
                ) {
              if (eventsSnapshot.hasError) {
                return const Center(
                  child: Text(
                    'Etkinlik istatistikleri yüklenemedi.',
                  ),
                );
              }

              if (!eventsSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('support_requests')
                    .snapshots(),
                builder: (
                    BuildContext context,
                    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                    supportSnapshot,
                    ) {
                  if (supportSnapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Destek istatistikleri yüklenemedi.',
                      ),
                    );
                  }

                  if (!supportSnapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                  users = usersSnapshot.data!.docs;

                  final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                  events = eventsSnapshot.data!.docs;

                  final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                  supportRequests = supportSnapshot.data!.docs;

                  final DateTime now = DateTime.now();

                  final DateTime startOfToday = DateTime(
                    now.year,
                    now.month,
                    now.day,
                  );

                  final DateTime startOfWeek = startOfToday.subtract(
                    Duration(days: now.weekday - 1),
                  );

                  int plusUsers = 0;
                  int playerUsers = 0;
                  int adminUsers = 0;
                  int todayUsers = 0;
                  int weekUsers = 0;

                  for (final QueryDocumentSnapshot<Map<String, dynamic>>
                  document in users) {
                    final Map<String, dynamic> data = document.data();

                    if (data['plus'] == true) {
                      plusUsers++;
                    }

                    if (data['oyuncuRozeti'] == true ||
                        data['verified'] == true ||
                        data['verificationStatus'] == 'approved') {
                      playerUsers++;
                    }

                    if (data['admin'] == true ||
                        data['role'] == 'admin') {
                      adminUsers++;
                    }

                    final DateTime? createdAt = _dateFromValue(
                      data['createdAt'] ?? data['kayitTarihi'],
                    );

                    if (createdAt != null) {
                      if (!createdAt.isBefore(startOfToday)) {
                        todayUsers++;
                      }

                      if (!createdAt.isBefore(startOfWeek)) {
                        weekUsers++;
                      }
                    }
                  }

                  int activeEvents = 0;
                  int completedEvents = 0;
                  int cancelledEvents = 0;
                  int hiddenEvents = 0;

                  for (final QueryDocumentSnapshot<Map<String, dynamic>>
                  document in events) {
                    final String status = _eventStatus(
                      document.data(),
                    );

                    switch (status) {
                      case 'completed':
                        completedEvents++;
                        break;
                      case 'cancelled':
                        cancelledEvents++;
                        break;
                      case 'hidden':
                        hiddenEvents++;
                        break;
                      default:
                        activeEvents++;
                    }
                  }

                  int newSupport = 0;
                  int reviewingSupport = 0;
                  int answeredSupport = 0;
                  int closedSupport = 0;
                  int criticalSupport = 0;

                  for (final QueryDocumentSnapshot<Map<String, dynamic>>
                  document in supportRequests) {
                    final Map<String, dynamic> data = document.data();

                    final String status =
                        data['status']?.toString() ?? 'new';

                    final String urgency =
                        data['urgency']?.toString() ?? 'normal';

                    switch (status) {
                      case 'reviewing':
                        reviewingSupport++;
                        break;
                      case 'answered':
                        answeredSupport++;
                        break;
                      case 'closed':
                        closedSupport++;
                        break;
                      default:
                        newSupport++;
                    }

                    if (urgency == 'critical') {
                      criticalSupport++;
                    }
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      32,
                    ),
                    children: <Widget>[
                      _SectionCard(
                        title: 'Kullanıcılar',
                        icon: Icons.people_alt_outlined,
                        children: <Widget>[
                          _StatisticGrid(
                            items: <_StatisticItem>[
                              _StatisticItem(
                                title: 'Toplam kullanıcı',
                                value: users.length,
                                icon: Icons.people_alt_outlined,
                              ),
                              _StatisticItem(
                                title: 'Bugün kayıt',
                                value: todayUsers,
                                icon: Icons.person_add_alt_outlined,
                              ),
                              _StatisticItem(
                                title: 'Bu hafta kayıt',
                                value: weekUsers,
                                icon: Icons.calendar_view_week_outlined,
                              ),
                              _StatisticItem(
                                title: 'Plus üye',
                                value: plusUsers,
                                icon: Icons.workspace_premium_outlined,
                              ),
                              _StatisticItem(
                                title: 'Oyuncu rozeti',
                                value: playerUsers,
                                icon: Icons.verified_outlined,
                              ),
                              _StatisticItem(
                                title: 'Admin',
                                value: adminUsers,
                                icon: Icons.admin_panel_settings_outlined,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _SectionCard(
                        title: 'Etkinlikler',
                        icon: Icons.event_outlined,
                        children: <Widget>[
                          _StatisticGrid(
                            items: <_StatisticItem>[
                              _StatisticItem(
                                title: 'Toplam etkinlik',
                                value: events.length,
                                icon: Icons.event_note_outlined,
                              ),
                              _StatisticItem(
                                title: 'Aktif',
                                value: activeEvents,
                                icon: Icons.event_available_outlined,
                              ),
                              _StatisticItem(
                                title: 'Tamamlandı',
                                value: completedEvents,
                                icon: Icons.task_alt_outlined,
                              ),
                              _StatisticItem(
                                title: 'İptal edildi',
                                value: cancelledEvents,
                                icon: Icons.event_busy_outlined,
                              ),
                              _StatisticItem(
                                title: 'Gizli',
                                value: hiddenEvents,
                                icon: Icons.visibility_off_outlined,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _SectionCard(
                        title: 'Destek ve Şikâyetler',
                        icon: Icons.support_agent_outlined,
                        children: <Widget>[
                          _StatisticGrid(
                            items: <_StatisticItem>[
                              _StatisticItem(
                                title: 'Toplam talep',
                                value: supportRequests.length,
                                icon: Icons.inbox_outlined,
                              ),
                              _StatisticItem(
                                title: 'Yeni',
                                value: newSupport,
                                icon: Icons.fiber_new_outlined,
                              ),
                              _StatisticItem(
                                title: 'İnceleniyor',
                                value: reviewingSupport,
                                icon: Icons.manage_search_outlined,
                              ),
                              _StatisticItem(
                                title: 'Yanıtlandı',
                                value: answeredSupport,
                                icon: Icons.mark_email_read_outlined,
                              ),
                              _StatisticItem(
                                title: 'Kapatıldı',
                                value: closedSupport,
                                icon: Icons.check_circle_outline,
                              ),
                              _StatisticItem(
                                title: 'Kritik',
                                value: criticalSupport,
                                icon: Icons.emergency_outlined,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
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

  static String _eventStatus(
      Map<String, dynamic> data,
      ) {
    final String value =
        data['status']?.toString().toLowerCase() ??
            data['durum']?.toString().toLowerCase() ??
            '';

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
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
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

class _StatisticGrid extends StatelessWidget {
  const _StatisticGrid({
    required this.items,
  });

  final List<_StatisticItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (
          BuildContext context,
          BoxConstraints constraints,
          ) {
        final double width =
            (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            for (final _StatisticItem item in items)
              SizedBox(
                width: width,
                child: _StatisticTile(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _StatisticTile extends StatelessWidget {
  const _StatisticTile({
    required this.item,
  });

  final _StatisticItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: <Widget>[
          Icon(item.icon),
          const SizedBox(height: 7),
          Text(
            '${item.value}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatisticItem {
  const _StatisticItem({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final int value;
  final IconData icon;
}