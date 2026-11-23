import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_access.dart';
import 'admin_audit_logs_screen.dart';
import 'admin_events_screen.dart';
import 'admin_gift_operations_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_play_product_mapping_screen.dart';
import 'admin_play_sales_screen.dart';
import 'admin_review_scope.dart';
import 'admin_roles_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_statistics_screen.dart';
import 'admin_support_detail_screen.dart';
import 'admin_support_list_screen.dart';
import 'admin_users_screen.dart';
import 'admin_verification_detail_screen.dart';
import 'admin_verification_list_screen.dart';
import 'admin_version_policy_screen.dart';

const _background = Color(0xff151617);
const _surface = Color(0xff1f2123);
const _divider = Color(0xff36383b);
const _muted = Color(0xffa8aaae);
const _accent = Color(0xfff28c28);

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  int _section = 0;
  int _reviewTab = 0;
  Future<Map<String, dynamic>?> _claims = AdminAccess.currentClaims(
    forceRefresh: true,
  );
  late Future<_OverviewData> _overview = _loadOverview();
  final PageStorageBucket _pageStorage = PageStorageBucket();
  StreamSubscription<User?>? _sessionChanges;
  String? _sessionUid;

  @override
  void initState() {
    super.initState();
    _sessionUid = FirebaseAuth.instance.currentUser?.uid;
    _sessionChanges = FirebaseAuth.instance.idTokenChanges().listen((user) {
      if (!mounted) return;
      final changedAccount = user?.uid != _sessionUid;
      _sessionUid = user?.uid;
      setState(() => _claims = AdminAccess.currentClaims());
      if (changedAccount) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  void dispose() {
    _sessionChanges?.cancel();
    super.dispose();
  }

  bool _can(Map<String, dynamic>? claims, AdminPermission permission) {
    return AdminAccess.hasPermission(claims, permission);
  }

  Future<_OverviewData> _loadOverview() async {
    final firestore = FirebaseFirestore.instance;
    final claims = await _claims;
    final canUsers = _can(claims, AdminPermission.usersRead);
    final canVerification = _can(claims, AdminPermission.verificationReview);
    final canSupport = _can(claims, AdminPermission.supportManage);
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      canUsers
          ? firestore.collection('users').count().get()
          : Future.value(null),
      firestore.collection('events').get(),
      canVerification
          ? firestore
                .collection('verification_requests')
                .where('status', isEqualTo: 'pending')
                .get()
          : Future.value(null),
      canSupport
          ? firestore
                .collection('support_requests')
                .where('status', isEqualTo: 'new')
                .get()
          : Future.value(null),
    ]);
    final userCount = (results[0] as AggregateQuerySnapshot?)?.count ?? 0;
    final events = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final verifications =
        (results[2] as QuerySnapshot<Map<String, dynamic>>?)?.docs ??
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final support =
        (results[3] as QuerySnapshot<Map<String, dynamic>>?)?.docs ??
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final activeEvents = events.docs.where((doc) {
      final value = (doc.data()['status'] ?? doc.data()['durum'] ?? '')
          .toString()
          .toLowerCase();
      return !<String>{
        'expired',
        'completed',
        'finished',
        'tamamlandi',
        'tamamlandı',
        'cancelled',
        'canceled',
        'iptal',
        'cancelled_by_host',
        'hidden',
        'removed',
        'gizli',
      }.contains(value);
    }).length;

    final tasks = <_PendingTask>[
      ...verifications.map(_PendingTask.verification),
      ...support.map(_PendingTask.support),
    ];
    tasks.sort((a, b) {
      final priority = b.priority.compareTo(a.priority);
      if (priority != 0) return priority;
      return a.createdAt.compareTo(b.createdAt);
    });
    return _OverviewData(
      users: userCount,
      activeEvents: activeEvents,
      verificationCount: verifications.length,
      supportCount: support
          .where((doc) => !isAdminReportCategory(doc.data()['category']))
          .length,
      reportCount: support
          .where((doc) => isAdminReportCategory(doc.data()['category']))
          .length,
      tasks: tasks.take(5).toList(growable: false),
    );
  }

  Future<void> _refreshOverview() async {
    final next = _loadOverview();
    setState(() => _overview = next);
    await next;
  }

  void _open(Widget screen) {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _selectSection(int value) {
    if (_section == value) return;
    setState(() => _section = value);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _claims,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: _background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final claims = snapshot.data;
        if (snapshot.hasError || !AdminAccess.canAccessPanel(claims)) {
          return Scaffold(
            backgroundColor: _background,
            appBar: AppBar(title: const Text('Yönetim')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.hasError
                      ? 'Yönetici yetkisi kontrol edilirken bir hata oluştu.'
                      : 'Bu sayfaya erişim yetkin yok.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final pages = <Widget>[
          _OverviewPage(
            future: _overview,
            canUsers: _can(claims, AdminPermission.usersRead),
            canVerification: _can(claims, AdminPermission.verificationReview),
            canSupport: _can(claims, AdminPermission.supportManage),
            onRefresh: _refreshOverview,
            onOpenTask: (task) {
              if (task.kind == _TaskKind.verification) {
                _open(AdminVerificationDetailScreen(requestId: task.id));
              } else {
                _open(AdminSupportDetailScreen(requestId: task.id));
              }
            },
            onSeeAll: () => _selectSection(3),
          ),
          _PermissionPage(
            allowed: _can(claims, AdminPermission.usersRead),
            child: const AdminUsersScreen(
              key: PageStorageKey<String>('admin-users'),
            ),
          ),
          _PermissionPage(
            allowed: _can(claims, AdminPermission.eventsModerate),
            child: const AdminEventsScreen(
              key: PageStorageKey<String>('admin-events'),
            ),
          ),
          _ReviewsPage(
            claims: claims,
            selectedTab: _reviewTab,
            counts: _overview,
            onTabChanged: (value) => setState(() => _reviewTab = value),
          ),
          _OtherPage(claims: claims, open: _open),
        ];

        return PopScope(
          canPop: _section == 0,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && _section != 0) _selectSection(0);
          },
          child: Scaffold(
            backgroundColor: _background,
            body: PageStorage(
              bucket: _pageStorage,
              child: KeyedSubtree(
                key: ValueKey<int>(_section),
                child: pages[_section],
              ),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _section,
              onDestinationSelected: _selectSection,
              backgroundColor: const Color(0xff1a1c1e),
              indicatorColor: _accent.withValues(alpha: .18),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded),
                  label: 'Özet',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people_rounded),
                  label: 'Kullanıcılar',
                ),
                NavigationDestination(
                  icon: Icon(Icons.event_outlined),
                  selectedIcon: Icon(Icons.event_rounded),
                  label: 'Etkinlikler',
                ),
                NavigationDestination(
                  icon: Icon(Icons.fact_check_outlined),
                  selectedIcon: Icon(Icons.fact_check_rounded),
                  label: 'İncelemeler',
                ),
                NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view_rounded),
                  label: 'Diğer',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OverviewPage extends StatelessWidget {
  const _OverviewPage({
    required this.future,
    required this.canUsers,
    required this.canVerification,
    required this.canSupport,
    required this.onRefresh,
    required this.onOpenTask,
    required this.onSeeAll,
  });

  final Future<_OverviewData> future;
  final bool canUsers;
  final bool canVerification;
  final bool canSupport;
  final Future<void> Function() onRefresh;
  final ValueChanged<_PendingTask> onOpenTask;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Yönetim',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Yenile',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_OverviewData>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(onRetry: onRefresh);
          }
          final data = snapshot.data!;
          final visibleTasks = data.tasks
              .where((task) {
                return task.kind == _TaskKind.verification
                    ? canVerification
                    : canSupport;
              })
              .toList(growable: false);
          final pending =
              (canVerification ? data.verificationCount : 0) +
              (canSupport ? data.supportCount + data.reportCount : 0);
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: <Widget>[
                _MetricStrip(
                  users: canUsers ? data.users : null,
                  activeEvents: data.activeEvents,
                  pending: pending,
                ),
                const SizedBox(height: 26),
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'İşlem bekleyenler',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (visibleTasks.isNotEmpty)
                      TextButton(
                        onPressed: onSeeAll,
                        child: const Text('Tümünü gör'),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                if (visibleTasks.isEmpty)
                  const _EmptyWork()
                else
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: _surface,
                      border: Border.all(color: _divider),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: <Widget>[
                        for (var i = 0; i < visibleTasks.length; i++) ...[
                          _TaskRow(
                            task: visibleTasks[i],
                            onTap: () => onOpenTask(visibleTasks[i]),
                          ),
                          if (i != visibleTasks.length - 1)
                            const Divider(height: 1, indent: 68),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({
    required this.users,
    required this.activeEvents,
    required this.pending,
  });
  final int? users;
  final int activeEvents;
  final int pending;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: <Widget>[
            Expanded(
              child: _Metric(
                value: users?.toString() ?? '—',
                label: 'Kullanıcı',
              ),
            ),
            const VerticalDivider(width: 1, color: _divider),
            Expanded(
              child: _Metric(value: '$activeEvents', label: 'Aktif etkinlik'),
            ),
            const VerticalDivider(width: 1, color: _divider),
            Expanded(
              child: _Metric(value: '$pending', label: 'Bekleyen iş'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.onTap});
  final _PendingTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        child: Row(
          children: <Widget>[
            _UserAvatar(uid: task.userId),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _UserName(uid: task.userId, fallback: task.fallbackName),
                  const SizedBox(height: 4),
                  Text(
                    task.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 14,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${task.typeLabel} · ${_waitingText(task.createdAt)}',
                    style: TextStyle(
                      color: task.kind == _TaskKind.report
                          ? Colors.redAccent.shade100
                          : _accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _muted),
          ],
        ),
      ),
    );
  }
}

class _ReviewsPage extends StatelessWidget {
  const _ReviewsPage({
    required this.claims,
    required this.selectedTab,
    required this.counts,
    required this.onTabChanged,
  });
  final Map<String, dynamic>? claims;
  final int selectedTab;
  final Future<_OverviewData> counts;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final canVerification = AdminAccess.hasPermission(
      claims,
      AdminPermission.verificationReview,
    );
    final canSupport = AdminAccess.hasPermission(
      claims,
      AdminPermission.supportManage,
    );
    final allowed = <bool>[canVerification, canSupport, canSupport];
    return DefaultTabController(
      length: 3,
      initialIndex: selectedTab,
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: _background,
            appBar: AppBar(
              backgroundColor: _background,
              title: const Text(
                'İncelemeler',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                onTap: onTabChanged,
                tabs: <Widget>[
                  _CountTab(
                    label: 'Doğrulama',
                    data: counts,
                    pick: (d) => d.verificationCount,
                  ),
                  _CountTab(
                    label: 'Destek',
                    data: counts,
                    pick: (d) => d.supportCount,
                  ),
                  _CountTab(
                    label: 'Şikâyet',
                    data: counts,
                    pick: (d) => d.reportCount,
                  ),
                ],
              ),
            ),
            body: allowed[selectedTab]
                ? switch (selectedTab) {
                    0 => const AdminVerificationListScreen(
                      key: PageStorageKey<String>('review-verification'),
                      initialStatus: 'pending',
                      embedded: true,
                    ),
                    1 => const AdminSupportListScreen(
                      key: PageStorageKey<String>('review-support'),
                      initialStatus: 'new',
                      initialCategory: 'support',
                      embedded: true,
                    ),
                    _ => const AdminSupportListScreen(
                      key: PageStorageKey<String>('review-reports'),
                      initialStatus: 'new',
                      initialCategory: 'reports',
                      embedded: true,
                    ),
                  }
                : const _NoPermission(),
          );
        },
      ),
    );
  }
}

class _CountTab extends StatelessWidget {
  const _CountTab({
    required this.label,
    required this.data,
    required this.pick,
  });
  final String label;
  final Future<_OverviewData> data;
  final int Function(_OverviewData) pick;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_OverviewData>(
      future: data,
      builder: (context, snapshot) {
        final count = snapshot.hasData ? pick(snapshot.data!) : null;
        return Tab(text: count == null ? label : '$label  $count');
      },
    );
  }
}

class _OtherPage extends StatelessWidget {
  const _OtherPage({required this.claims, required this.open});
  final Map<String, dynamic>? claims;
  final ValueChanged<Widget> open;

  @override
  Widget build(BuildContext context) {
    bool can(AdminPermission permission) =>
        AdminAccess.hasPermission(claims, permission);
    final items = <_ToolItem>[
      if (can(AdminPermission.contentManage) ||
          can(AdminPermission.financeManage))
        _ToolItem(
          'Market',
          'Ürün kataloğu ve Play eşlemeleri',
          Icons.storefront_outlined,
          () => open(
            const AdminPlayProductMappingScreen(
              title: 'Market',
              marketMode: true,
            ),
          ),
        ),
      if (can(AdminPermission.financeManage))
        _ToolItem(
          'Satın almalar',
          'Satış ve yaşam döngüsü kayıtları',
          Icons.receipt_long_outlined,
          () => open(const AdminPlaySalesScreen()),
        ),
      if (can(AdminPermission.financeManage))
        _ToolItem(
          'Hediye / iade',
          'İnceleme ve teslimatlar',
          Icons.card_giftcard_outlined,
          () => open(const AdminGiftOperationsScreen()),
        ),
      if (can(AdminPermission.notificationsManage))
        _ToolItem(
          'Bildirimler',
          'Yönetim bildirimleri',
          Icons.notifications_outlined,
          () => open(const AdminNotificationsScreen()),
        ),
      if (can(AdminPermission.reportsRead))
        _ToolItem(
          'İstatistik ve raporlar',
          'Operasyon özeti',
          Icons.query_stats_outlined,
          () => open(const AdminStatisticsScreen()),
        ),
      if (can(AdminPermission.settingsManage))
        _ToolItem(
          'Sürüm politikası',
          'Minimum ve güncel sürümler',
          Icons.system_update_alt_outlined,
          () => open(const AdminVersionPolicyScreen()),
        ),
      if (can(AdminPermission.rolesManage))
        _ToolItem(
          'Yetkiler',
          'Admin rolleri ve erişimler',
          Icons.admin_panel_settings_outlined,
          () => open(const AdminRolesScreen()),
        ),
      if (can(AdminPermission.auditRead))
        _ToolItem(
          'Audit',
          'Yönetim işlem kayıtları',
          Icons.history_outlined,
          () => open(const AdminAuditLogsScreen()),
        ),
      if (can(AdminPermission.settingsManage))
        _ToolItem(
          'Ayarlar',
          'Genel sistem ayarları',
          Icons.settings_outlined,
          () => open(const AdminSettingsScreen()),
        ),
    ];
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        title: const Text(
          'Diğer',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: items.isEmpty
          ? const _NoPermission()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 58),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  minTileHeight: 68,
                  leading: Icon(item.icon, color: _muted),
                  title: Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    item.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: item.onTap,
                );
              },
            ),
    );
  }
}

class _PermissionPage extends StatelessWidget {
  const _PermissionPage({required this.allowed, required this.child});
  final bool allowed;
  final Widget child;

  @override
  Widget build(BuildContext context) => allowed ? child : const _NoPermission();
}

class _NoPermission extends StatelessWidget {
  const _NoPermission();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _background,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Bu yönetim aracına erişim yetkin yok.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _EmptyWork extends StatelessWidget {
  const _EmptyWork();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: <Widget>[
          Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Bekleyen iş yok. Kuyruk temiz.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Tekrar dene'),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.uid});
  final String uid;
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final photo = (data?['profilFotografi'] ?? data?['avatarUrl'] ?? '')
            .toString();
        return CircleAvatar(
          radius: 22,
          foregroundImage: photo.isEmpty ? null : NetworkImage(photo),
          child: photo.isEmpty
              ? const Icon(Icons.person_outline_rounded)
              : null,
        );
      },
    );
  }
}

class _UserName extends StatelessWidget {
  const _UserName({required this.uid, required this.fallback});
  final String uid;
  final String fallback;
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final profileName = data?['profilAdi']?.toString().trim() ?? '';
        final fullName = '${data?['ad'] ?? ''} ${data?['soyad'] ?? ''}'.trim();
        final name = profileName.isNotEmpty
            ? profileName
            : fullName.isNotEmpty
            ? fullName
            : fallback.isNotEmpty
            ? fallback
            : 'Kullanıcı';
        return Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        );
      },
    );
  }
}

enum _TaskKind { verification, support, report }

class _PendingTask {
  const _PendingTask({
    required this.id,
    required this.userId,
    required this.fallbackName,
    required this.description,
    required this.createdAt,
    required this.priority,
    required this.kind,
  });

  factory _PendingTask.verification(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _PendingTask(
      id: doc.id,
      userId: (data['uid'] ?? data['userId'] ?? doc.id).toString(),
      fallbackName: (data['displayName'] ?? '').toString(),
      description: 'Oyuncu doğrulama başvurusu',
      createdAt: _date(data['createdAt']),
      priority: (data['priorityScore'] as num?)?.toInt() ?? 0,
      kind: _TaskKind.verification,
    );
  }

  factory _PendingTask.support(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final category = (data['category'] ?? '').toString();
    final report = isAdminReportCategory(category);
    final subject = (data['subject'] ?? data['description'] ?? '')
        .toString()
        .trim();
    return _PendingTask(
      id: doc.id,
      userId: (data['uid'] ?? data['userId'] ?? '').toString(),
      fallbackName: '',
      description: subject.isEmpty
          ? (report ? 'Yeni şikâyet' : 'Yeni destek talebi')
          : subject,
      createdAt: _date(data['createdAt']),
      priority: (data['priorityScore'] as num?)?.toInt() ?? 0,
      kind: report ? _TaskKind.report : _TaskKind.support,
    );
  }

  final String id;
  final String userId;
  final String fallbackName;
  final String description;
  final DateTime createdAt;
  final int priority;
  final _TaskKind kind;

  String get typeLabel => switch (kind) {
    _TaskKind.verification => 'Doğrulama',
    _TaskKind.support => 'Destek',
    _TaskKind.report => 'Şikâyet',
  };
}

class _OverviewData {
  const _OverviewData({
    required this.users,
    required this.activeEvents,
    required this.verificationCount,
    required this.supportCount,
    required this.reportCount,
    required this.tasks,
  });
  final int users;
  final int activeEvents;
  final int verificationCount;
  final int supportCount;
  final int reportCount;
  final List<_PendingTask> tasks;
}

class _ToolItem {
  const _ToolItem(this.title, this.description, this.icon, this.onTap);
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
}

DateTime _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.fromMillisecondsSinceEpoch(0);
}

String _waitingText(DateTime createdAt) {
  if (createdAt.millisecondsSinceEpoch == 0) return 'Süre bilgisi yok';
  final difference = DateTime.now().difference(createdAt);
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes.clamp(1, 59)} dk bekliyor';
  }
  if (difference.inHours < 24) return '${difference.inHours} sa bekliyor';
  return '${difference.inDays} gün bekliyor';
}
