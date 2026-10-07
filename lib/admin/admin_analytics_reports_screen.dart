import 'package:flutter/material.dart';

import 'admin_access.dart';
import 'admin_events_screen.dart';
import 'admin_market_orders_screen.dart';
import 'admin_statistics_screen.dart';
import 'admin_support_list_screen.dart';
import 'admin_users_screen.dart';
import 'admin_wallet_management_screen.dart';
import 'admin_audit_logs_screen.dart';

class AdminAnalyticsReportsScreen extends StatelessWidget {
  const AdminAnalyticsReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: AdminAccess.currentClaims(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<Map<String, dynamic>?> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final Map<String, dynamic>? claims = snapshot.data;

            if (!AdminAccess.hasPermission(
              claims,
              AdminPermission.reportsRead,
            )) {
              return const Scaffold(
                body: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Bu raporlara erişim yetkin yok.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            final bool canReadUsers = AdminAccess.hasPermission(
              claims,
              AdminPermission.usersRead,
            );
            final bool canModerateEvents = AdminAccess.hasPermission(
              claims,
              AdminPermission.eventsModerate,
            );
            final bool canManageFinance = AdminAccess.hasPermission(
              claims,
              AdminPermission.financeManage,
            );
            final bool canManageSupport = AdminAccess.hasPermission(
              claims,
              AdminPermission.supportManage,
            );
            final bool canReadAudit = AdminAccess.hasPermission(
              claims,
              AdminPermission.auditRead,
            );

            return Scaffold(
              appBar: AppBar(
                title: const Text(
                  'Raporlar',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  _ReportTile(
                    icon: Icons.analytics_outlined,
                    title: 'Genel İstatistik Özeti',
                    subtitle:
                        'Kişisel kayıtları açmadan toplu sistem istatistikleri',
                    onTap: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) {
                            return const AdminStatisticsScreen();
                          },
                        ),
                      );
                    },
                  ),
                  if (canReadAudit)
                    _ReportTile(
                      icon: Icons.shield_outlined,
                      title: 'Audit ve Operasyon Kayıtları',
                      subtitle:
                          'Kritik yönetim ve sistem hareketlerini incele',
                      onTap: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) {
                              return const AdminAuditLogsScreen();
                            },
                          ),
                        );
                      },
                    ),
                  if (canReadUsers)
                    _ReportTile(
                      icon: Icons.people_alt_outlined,
                      title: 'Kullanıcı Detayları',
                      subtitle: 'Yetkin dahilindeki kullanıcı kayıtları',
                      onTap: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) {
                              return const AdminUsersScreen();
                            },
                          ),
                        );
                      },
                    ),
                  if (canModerateEvents)
                    _ReportTile(
                      icon: Icons.event_outlined,
                      title: 'Etkinlik Detayları',
                      subtitle: 'Moderasyon kapsamındaki etkinlik kayıtları',
                      onTap: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) {
                              return const AdminEventsScreen();
                            },
                          ),
                        );
                      },
                    ),
                  if (canManageFinance)
                    _ReportTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Cüzdan Detayları',
                      subtitle: 'Finans yetkisi gerektiren cüzdan kayıtları',
                      onTap: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) {
                              return const AdminWalletManagementScreen();
                            },
                          ),
                        );
                      },
                    ),
                  if (canManageFinance)
                    _ReportTile(
                      icon: Icons.storefront_outlined,
                      title: 'Market Siparişleri',
                      subtitle: 'Finans yetkisi gerektiren sipariş kayıtları',
                      onTap: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) {
                              return const AdminMarketOrdersScreen();
                            },
                          ),
                        );
                      },
                    ),
                  if (canManageSupport)
                    _ReportTile(
                      icon: Icons.support_agent_outlined,
                      title: 'Destek Detayları',
                      subtitle: 'Destek yetkisi gerektiren talep kayıtları',
                      onTap: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) {
                              return const AdminSupportListScreen();
                            },
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
