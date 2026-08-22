import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_support_list_screen.dart';
import 'admin_events_screen.dart';
import 'admin_statistics_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_wallet_management_screen.dart';
import 'admin_market_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_roles_screen.dart';
import 'admin_audit_logs_screen.dart';
import 'admin_analytics_reports_screen.dart';
import 'admin_users_screen.dart';
import '../screens/verification_admin_screen.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  Future<bool> _isAdmin() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return false;
    }

    final IdTokenResult tokenResult =
    await user.getIdTokenResult(true);

    final Map<String, dynamic>? claims =
        tokenResult.claims;

    if (claims == null) {
      return false;
    }

    final String role =
        claims['role']?.toString().toLowerCase() ?? '';

    return claims['admin'] == true ||
        role == 'admin' ||
        role == 'super_admin' ||
        role == 'moderator';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isAdmin(),
      builder: (
          BuildContext context,
          AsyncSnapshot<bool> snapshot,
          ) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Yönetim Paneli'),
            ),
            body: const Center(
              child: Text(
                'Yönetici yetkisi kontrol edilirken bir hata oluştu.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.data != true) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Yönetim Paneli'),
            ),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Bu sayfaya erişim yetkin yok.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Yönetim Paneli',
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          body: GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount:
            MediaQuery.of(context).size.width > 900 ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            childAspectRatio:
            MediaQuery.of(context).size.width > 900 ? 1.25 : 1.05,
            children: <Widget>[
              _AdminTile(
                icon: Icons.verified_user_outlined,
                title: 'Oyuncu Doğrulamaları',
                collection: 'users',
                field: 'verificationStatus',
                value: 'pending',
                countDescription: 'bekleyen doğrulama',
                onTap: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) {
                        return const VerificationAdminScreen();
                      },
                    ),
                  );
                },
              ),
              _AdminTile(
                icon: Icons.support_agent_outlined,
                title: 'Destek Merkezi',
                collection: 'support_requests',
                field: 'status',
                value: 'new',
                countDescription: 'yeni talep',
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
              _AdminTile(
                icon: Icons.people_alt_outlined,
                title: 'Kullanıcılar',
                collection: 'users',
                field: 'role',
                value: 'user',
                countDescription: 'kullanıcı',
                countAllDocuments: true,
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
              _AdminTile(
                icon: Icons.event_outlined,
                title: 'Etkinlikler',
                collection: 'events',
                field: 'durum',
                value: 'aktif',
                countDescription: 'aktif etkinlik',
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
              _AdminTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Cüzdan',
                collection: 'wallets',
                field: 'isFrozen',
                value: false,
                countDescription: 'aktif cüzdan',
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
              _AdminTile(
                icon: Icons.storefront_outlined,
                title: 'Market',
                collection: 'marketProducts',
                field: 'active',
                value: true,
                countDescription: 'aktif ürün',
                onTap: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) {
                        return const AdminMarketScreen();
                      },
                    ),
                  );
                },
              ),
              _AdminTile(
                icon: Icons.flag_outlined,
                title: 'Şikâyet ve Moderasyon',
                collection: 'support_requests',
                field: 'status',
                value: 'new',
                countDescription: 'yeni kayıt',
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
              _AdminTile(
                icon: Icons.bar_chart_outlined,
                title: 'İstatistikler',
                collection: 'users',
                field: 'role',
                value: 'user',
                countDescription: 'kullanıcı verisi',
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
              _AdminTile(
                icon: Icons.notifications_active_outlined,
                title: 'Bildirim Merkezi',
                collection: 'notifications',
                field: 'isRead',
                value: false,
                countDescription: 'okunmamış bildirim',
                onTap: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) {
                        return const AdminNotificationsScreen();
                      },
                    ),
                  );
                },
              ),

              _AdminTile(
                icon: Icons.settings_outlined,
                title: 'Sistem Ayarları',
                collection: 'system_settings',
                field: 'maintenanceMode',
                value: false,
                countDescription: 'genel ayarlar',
                onTap: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) {
                        return const AdminSettingsScreen();
                      },
                    ),
                  );
                },
              ),
              _AdminTile(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Admin ve Yetkiler',
                collection: 'users',
                field: 'admin',
                value: true,
                countDescription: 'admin kullanıcı',
                onTap: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) {
                        return const AdminRolesScreen();
                      },
                    ),
                  );
                },
              ),
              _AdminTile(
                icon: Icons.history_outlined,
                title: 'Admin İşlem Kayıtları',
                collection: 'admin_system_actions',
                field: 'action',
                value: 'system_settings_updated',
                countDescription: 'sistem işlemi',
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
              _AdminTile(
                icon: Icons.analytics_outlined,
                title: 'Raporlar',
                collection: 'users',
                field: 'role',
                value: 'user',
                countDescription: 'genel raporlar',
                onTap: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) {
                        return const AdminAnalyticsReportsScreen();
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

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.icon,
    required this.title,
    required this.collection,
    required this.field,
    required this.value,
    required this.countDescription,
    required this.onTap,
    this.countAllDocuments = false,
  });

  final IconData icon;
  final String title;
  final String collection;
  final String field;
  final Object value;
  final String countDescription;
  final VoidCallback onTap;
  final bool countAllDocuments;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: countAllDocuments
            ? FirebaseFirestore.instance
            .collection(collection)
            .snapshots()
            : FirebaseFirestore.instance
            .collection(collection)
            .where(field, isEqualTo: value)
            .snapshots(),
        builder: (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
          final int count = snapshot.data?.docs.length ?? 0;

          return InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  CircleAvatar(
                    radius: 23,
                    child: Icon(
                      icon,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  else if (snapshot.hasError)
                    const Text(
                      '—',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  else
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    snapshot.hasError
                        ? 'Sayı alınamadı'
                        : countDescription,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}