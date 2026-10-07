import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

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

class AdminStatisticsScreen extends StatefulWidget {
  const AdminStatisticsScreen({super.key});

  @override
  State<AdminStatisticsScreen> createState() => _AdminStatisticsScreenState();
}

class _AdminStatisticsScreenState extends State<AdminStatisticsScreen> {
  late Future<_ReportOverview> _report = _load();

  Future<_ReportOverview> _load() async {
    final HttpsCallable callable = FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    ).httpsCallable('adminGetReportOverview');

    final HttpsCallableResult<dynamic> result = await callable.call();

    final Map<String, dynamic> data = Map<String, dynamic>.from(
      result.data as Map,
    );

    return _ReportOverview.fromMap(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _locText(
            context,
            tr: 'İstatistikler',
            en: 'Statistics',
            de: 'Statistiken',
          ),
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: FutureBuilder<_ReportOverview>(
        future: _report,
        builder:
            (BuildContext context, AsyncSnapshot<_ReportOverview> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text(
                          'İstatistikler yüklenirken bir hata oluştu.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              _report = _load();
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tekrar dene'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final _ReportOverview report = snapshot.data!;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: <Widget>[
                  _SectionCard(
                    title: _locText(
                      context,
                      tr: 'Kullanıcılar',
                      en: 'Users',
                      de: 'Nutzer',
                    ),
                    icon: Icons.people_alt_outlined,
                    children: <Widget>[
                      _StatisticGrid(
                        items: <_StatisticItem>[
                          _StatisticItem(
                            title: 'Toplam kullanıcı',
                            value: report.users.total,
                            icon: Icons.people_alt_outlined,
                          ),
                          _StatisticItem(
                            title: 'Bugün kayıt',
                            value: report.users.today,
                            icon: Icons.person_add_alt_outlined,
                          ),
                          _StatisticItem(
                            title: 'Bu hafta kayıt',
                            value: report.users.week,
                            icon: Icons.calendar_view_week_outlined,
                          ),
                          _StatisticItem(
                            title: 'Plus üye',
                            value: report.users.plus,
                            icon: Icons.workspace_premium_outlined,
                          ),
                          _StatisticItem(
                            title: 'Oyuncu rozeti',
                            value: report.users.player,
                            icon: Icons.verified_outlined,
                          ),
                          _StatisticItem(
                            title: 'Yönetim hesabı',
                            value: report.users.admins,
                            icon: Icons.admin_panel_settings_outlined,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: _locText(
                      context,
                      tr: 'Etkinlikler',
                      en: 'Events',
                      de: 'Veranstaltungen',
                    ),
                    icon: Icons.event_outlined,
                    children: <Widget>[
                      _StatisticGrid(
                        items: <_StatisticItem>[
                          _StatisticItem(
                            title: 'Toplam etkinlik',
                            value: report.events.total,
                            icon: Icons.event_note_outlined,
                          ),
                          _StatisticItem(
                            title: 'Aktif',
                            value: report.events.active,
                            icon: Icons.event_available_outlined,
                          ),
                          _StatisticItem(
                            title: 'Tamamlandı',
                            value: report.events.completed,
                            icon: Icons.task_alt_outlined,
                          ),
                          _StatisticItem(
                            title: 'İptal edildi',
                            value: report.events.cancelled,
                            icon: Icons.event_busy_outlined,
                          ),
                          _StatisticItem(
                            title: 'Gizli',
                            value: report.events.hidden,
                            icon: Icons.visibility_off_outlined,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: _locText(
                      context,
                      tr: 'Operasyon Sağlığı',
                      en: 'Operations Health',
                      de: 'Betriebsstatus',
                    ),
                    icon: Icons.monitor_heart_outlined,
                    children: <Widget>[
                      _StatisticGrid(
                        items: <_StatisticItem>[
                          _StatisticItem(
                            title: _locText(
                              context,
                              tr: 'Dikkat gereken',
                              en: 'Needs attention',
                              de: 'Handlungsbedarf',
                            ),
                            value: report.operations.attentionRequired,
                            icon: Icons.warning_amber_rounded,
                          ),
                          _StatisticItem(
                            title: _locText(
                              context,
                              tr: 'Bekleyen ödeme',
                              en: 'Pending payments',
                              de: 'Ausstehende Zahlungen',
                            ),
                            value: report.operations.pendingPayments,
                            icon: Icons.hourglass_top_outlined,
                          ),
                          _StatisticItem(
                            title: _locText(
                              context,
                              tr: '24 saati aşan ödeme',
                              en: 'Payments pending 24h+',
                              de: 'Zahlungen über 24 Std.',
                            ),
                            value: report.operations.stalePendingPayments,
                            icon: Icons.schedule_outlined,
                          ),
                          _StatisticItem(
                            title: _locText(
                              context,
                              tr: 'Başarısız ödeme',
                              en: 'Failed payments',
                              de: 'Fehlgeschlagene Zahlungen',
                            ),
                            value: report.operations.failedPayments,
                            icon: Icons.error_outline,
                          ),
                          _StatisticItem(
                            title: _locText(
                              context,
                              tr: 'Bekleyen çekim',
                              en: 'Pending withdrawals',
                              de: 'Ausstehende Auszahlungen',
                            ),
                            value: report.operations.pendingWithdrawals,
                            icon: Icons.account_balance_outlined,
                          ),
                          _StatisticItem(
                            title: _locText(
                              context,
                              tr: '24 saati aşan çekim',
                              en: 'Withdrawals pending 24h+',
                              de: 'Auszahlungen über 24 Std.',
                            ),
                            value: report.operations.stalePendingWithdrawals,
                            icon: Icons.schedule_outlined,
                          ),
                          _StatisticItem(
                            title: _locText(
                              context,
                              tr: 'Bekleyen doğrulama',
                              en: 'Pending verifications',
                              de: 'Ausstehende Verifizierungen',
                            ),
                            value: report.operations.pendingVerifications,
                            icon: Icons.fact_check_outlined,
                          ),
                          _StatisticItem(
                            title: _locText(
                              context,
                              tr: '24 saati aşan doğrulama',
                              en: 'Verifications pending 24h+',
                              de: 'Verifizierungen über 24 Std.',
                            ),
                            value: report.operations.stalePendingVerifications,
                            icon: Icons.schedule_outlined,
                          ),
                          _StatisticItem(
                            title: _locText(
                              context,
                              tr: '24 saatte arama',
                              en: 'Calls in 24h',
                              de: 'Anrufe in 24 Std.',
                            ),
                            value: report.operations.maskedCallsLast24h,
                            icon: Icons.phone_in_talk_outlined,
                          ),
                          _StatisticItem(
                            title: _locText(
                              context,
                              tr: 'Arama altyapısı bekliyor',
                              en: 'Call provider pending',
                              de: 'Anrufanbieter ausstehend',
                            ),
                            value: report.operations.unavailableMaskedCalls,
                            icon: Icons.phone_disabled_outlined,
                          ),
                          _StatisticItem(
                            title: _locText(
                              context,
                              tr: '24 saatte audit',
                              en: 'Audit events in 24h',
                              de: 'Audit-Ereignisse in 24 Std.',
                            ),
                            value: report.operations.auditEventsLast24h,
                            icon: Icons.shield_outlined,
                          ),
                          _StatisticItem(
                            title: _locText(
                              context,
                              tr: 'Tamamlanan ödeme',
                              en: 'Completed payments',
                              de: 'Abgeschlossene Zahlungen',
                            ),
                            value: report.operations.paidPayments,
                            icon: Icons.check_circle_outline,
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
                            value: report.support.total,
                            icon: Icons.inbox_outlined,
                          ),
                          _StatisticItem(
                            title: 'Yeni',
                            value: report.support.newCount,
                            icon: Icons.fiber_new_outlined,
                          ),
                          _StatisticItem(
                            title: 'İnceleniyor',
                            value: report.support.reviewing,
                            icon: Icons.manage_search_outlined,
                          ),
                          _StatisticItem(
                            title: 'Yanıtlandı',
                            value: report.support.answered,
                            icon: Icons.mark_email_read_outlined,
                          ),
                          _StatisticItem(
                            title: 'Kapatıldı',
                            value: report.support.closed,
                            icon: Icons.check_circle_outline,
                          ),
                          _StatisticItem(
                            title: 'Kritik',
                            value: report.support.critical,
                            icon: Icons.emergency_outlined,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            },
      ),
    );
  }
}

class _ReportOverview {
  const _ReportOverview({
    required this.users,
    required this.events,
    required this.support,
    required this.operations,
  });

  factory _ReportOverview.fromMap(Map<String, dynamic> map) {
    return _ReportOverview(
      users: _UserReport.fromMap(_map(map['users'])),
      events: _EventReport.fromMap(_map(map['events'])),
      support: _SupportReport.fromMap(_map(map['support'])),
      operations: _OperationsReport.fromMap(_map(map['operations'])),
    );
  }

  final _UserReport users;
  final _EventReport events;
  final _SupportReport support;
  final _OperationsReport operations;

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }
}

class _UserReport {
  const _UserReport({
    required this.total,
    required this.today,
    required this.week,
    required this.plus,
    required this.player,
    required this.admins,
  });

  factory _UserReport.fromMap(Map<String, dynamic> map) {
    return _UserReport(
      total: _number(map['total']),
      today: _number(map['today']),
      week: _number(map['week']),
      plus: _number(map['plus']),
      player: _number(map['player']),
      admins: _number(map['admins']),
    );
  }

  final int total;
  final int today;
  final int week;
  final int plus;
  final int player;
  final int admins;
}

class _EventReport {
  const _EventReport({
    required this.total,
    required this.active,
    required this.completed,
    required this.cancelled,
    required this.hidden,
  });

  factory _EventReport.fromMap(Map<String, dynamic> map) {
    return _EventReport(
      total: _number(map['total']),
      active: _number(map['active']),
      completed: _number(map['completed']),
      cancelled: _number(map['cancelled']),
      hidden: _number(map['hidden']),
    );
  }

  final int total;
  final int active;
  final int completed;
  final int cancelled;
  final int hidden;
}

class _SupportReport {
  const _SupportReport({
    required this.total,
    required this.newCount,
    required this.reviewing,
    required this.answered,
    required this.closed,
    required this.critical,
  });

  factory _SupportReport.fromMap(Map<String, dynamic> map) {
    return _SupportReport(
      total: _number(map['total']),
      newCount: _number(map['new']),
      reviewing: _number(map['reviewing']),
      answered: _number(map['answered']),
      closed: _number(map['closed']),
      critical: _number(map['critical']),
    );
  }

  final int total;
  final int newCount;
  final int reviewing;
  final int answered;
  final int closed;
  final int critical;
}

class _OperationsReport {
  const _OperationsReport({
    required this.paymentSessions,
    required this.pendingPayments,
    required this.paidPayments,
    required this.failedPayments,
    required this.stalePendingPayments,
    required this.pendingWithdrawals,
    required this.stalePendingWithdrawals,
    required this.pendingVerifications,
    required this.stalePendingVerifications,
    required this.attentionRequired,
    required this.maskedCallsLast24h,
    required this.unavailableMaskedCalls,
    required this.auditEventsLast24h,
  });

  factory _OperationsReport.fromMap(Map<String, dynamic> map) {
    return _OperationsReport(
      paymentSessions: _number(map['paymentSessions']),
      pendingPayments: _number(map['pendingPayments']),
      paidPayments: _number(map['paidPayments']),
      failedPayments: _number(map['failedPayments']),
      stalePendingPayments: _number(map['stalePendingPayments']),
      pendingWithdrawals: _number(map['pendingWithdrawals']),
      stalePendingWithdrawals: _number(map['stalePendingWithdrawals']),
      pendingVerifications: _number(map['pendingVerifications']),
      stalePendingVerifications: _number(map['stalePendingVerifications']),
      attentionRequired: _number(map['attentionRequired']),
      maskedCallsLast24h: _number(map['maskedCallsLast24h']),
      unavailableMaskedCalls: _number(map['unavailableMaskedCalls']),
      auditEventsLast24h: _number(map['auditEventsLast24h']),
    );
  }

  final int paymentSessions;
  final int pendingPayments;
  final int paidPayments;
  final int failedPayments;
  final int stalePendingPayments;
  final int pendingWithdrawals;
  final int stalePendingWithdrawals;
  final int pendingVerifications;
  final int stalePendingVerifications;
  final int attentionRequired;
  final int maskedCallsLast24h;
  final int unavailableMaskedCalls;
  final int auditEventsLast24h;
}

int _number(dynamic value) {
  if (value is num) {
    return value.toInt();
  }

  return 0;
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
  const _StatisticGrid({required this.items});

  final List<_StatisticItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = (constraints.maxWidth - 10) / 2;

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
  const _StatisticTile({required this.item});

  final _StatisticItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(item.icon),
          const SizedBox(height: 10),
          Text(
            item.value.toString(),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(item.title),
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
