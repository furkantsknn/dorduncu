import 'package:flutter/material.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Raporlar',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _ReportTile(
            icon: Icons.people_alt_outlined,
            title: 'Kullanıcı İstatistikleri',
            subtitle: 'Kayıtlar, aktif kullanıcılar',
          ),
          _ReportTile(
            icon: Icons.event_outlined,
            title: 'Etkinlik İstatistikleri',
            subtitle: 'Oluşturulan ve tamamlanan etkinlikler',
          ),
          _ReportTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Cüzdan Raporu',
            subtitle: 'Bakiye ve işlem özeti',
          ),
          _ReportTile(
            icon: Icons.storefront_outlined,
            title: 'Market Raporu',
            subtitle: 'Satışlar ve ürün performansı',
          ),
          _ReportTile(
            icon: Icons.workspace_premium_outlined,
            title: 'Plus Üyelik Raporu',
            subtitle: 'Aktif Plus üyeler',
          ),
          _ReportTile(
            icon: Icons.support_agent_outlined,
            title: 'Destek Raporu',
            subtitle: 'Açık ve kapanan talepler',
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
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
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