import 'package:flutter/material.dart';

import 'admin_events_screen.dart';
import 'admin_market_orders_screen.dart';
import 'admin_statistics_screen.dart';
import 'admin_support_list_screen.dart';
import 'admin_users_screen.dart';
import 'admin_wallet_management_screen.dart';

class AdminAnalyticsReportsScreen extends StatelessWidget {
  const AdminAnalyticsReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Raporlar',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _ReportTile(
            icon: Icons.people_alt_outlined,
            title: 'Kullanıcı İstatistikleri',
            subtitle: 'Kayıtlar, üyelikler ve kullanıcı dağılımları',
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
          _ReportTile(
            icon: Icons.event_outlined,
            title: 'Etkinlik İstatistikleri',
            subtitle: 'Aktif, tamamlanan ve iptal edilen etkinlikler',
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
          _ReportTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Cüzdan Raporu',
            subtitle: 'Kullanıcı bakiyeleri ve cüzdan durumları',
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
          _ReportTile(
            icon: Icons.storefront_outlined,
            title: 'Market Raporu',
            subtitle: 'Siparişler, ödeme türleri ve satış işlemleri',
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
          _ReportTile(
            icon: Icons.workspace_premium_outlined,
            title: 'Plus Üyelik Raporu',
            subtitle: 'Aktif Plus üyelerin listesi',
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (BuildContext context) {
                    return const AdminUsersScreen(
                      initialFilter: 'plus',
                    );
                  },
                ),
              );
            },
          ),
          _ReportTile(
            icon: Icons.support_agent_outlined,
            title: 'Destek Raporu',
            subtitle: 'Yeni, incelenen ve kapatılan destek talepleri',
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}