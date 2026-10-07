import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_access.dart';
import 'admin_support_list_screen.dart';
import 'admin_events_screen.dart';
import 'admin_statistics_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_wallet_management_screen.dart';
import 'admin_market_screen.dart';
import 'admin_play_sales_screen.dart';
import 'admin_play_product_mapping_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_roles_screen.dart';
import 'admin_audit_logs_screen.dart';
import 'admin_analytics_reports_screen.dart';
import 'admin_users_screen.dart';
import '../screens/verification_admin_screen.dart';

String _adminPanelText(
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

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  Future<Map<String, dynamic>?> _claims() async {
    return AdminAccess.currentClaims(forceRefresh: true);
  }

  bool _can(Map<String, dynamic>? claims, AdminPermission permission) {
    return AdminAccess.hasPermission(claims, permission);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _claims(),
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

            if (snapshot.hasError) {
              return Scaffold(
                appBar: AppBar(
                  title: Text(
                    _adminPanelText(
                      context,
                      tr: 'Yönetim Paneli',
                      en: 'Admin Panel',
                      de: 'Admin-Bereich',
                    ),
                  ),
                ),
                body: const Center(
                  child: Text(
                    'Yönetici yetkisi kontrol edilirken bir hata oluştu.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final Map<String, dynamic>? claims = snapshot.data;

            if (!AdminAccess.canAccessPanel(claims)) {
              return Scaffold(
                appBar: AppBar(
                  title: Text(
                    _adminPanelText(
                      context,
                      tr: 'Yönetim Paneli',
                      en: 'Admin Panel',
                      de: 'Admin-Bereich',
                    ),
                  ),
                ),
                body: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      _adminPanelText(
                        context,
                        tr: 'Bu sayfaya erişim yetkin yok.',
                        en: 'You do not have permission to access this page.',
                        de: 'Du hast keine Berechtigung für diese Seite.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              );
            }

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  _adminPanelText(
                    context,
                    tr: 'Yönetim Paneli',
                    en: 'Admin Panel',
                    de: 'Admin-Bereich',
                  ),
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                actions: <Widget>[
                  IconButton(
                    tooltip: _adminPanelText(
                      context,
                      tr: 'Güvenli çıkış',
                      en: 'Secure sign out',
                      de: 'Sicher abmelden',
                    ),
                    onPressed: FirebaseAuth.instance.signOut,
                    icon: const Icon(Icons.logout),
                  ),
                ],
              ),
              body: GridView.count(
                padding: const EdgeInsets.all(16),
                crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                childAspectRatio: MediaQuery.of(context).size.width > 900
                    ? 1.25
                    : 1.05,
                children: <Widget>[
                  if (_can(claims, AdminPermission.verificationReview))
                    _AdminTile(
                      icon: Icons.verified_user_outlined,
                      title: _adminPanelText(
                        context,
                        tr: 'Oyuncu Doğrulamaları',
                        en: 'Player Verifications',
                        de: 'Spielerverifizierungen',
                      ),
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
                  if (_can(claims, AdminPermission.supportManage))
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
                  if (_can(claims, AdminPermission.usersRead))
                    _AdminTile(
                      icon: Icons.people_alt_outlined,
                      title: _adminPanelText(
                        context,
                        tr: 'Kullanıcılar',
                        en: 'Users',
                        de: 'Nutzer',
                      ),
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
                  if (_can(claims, AdminPermission.eventsModerate))
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
                  if (_can(claims, AdminPermission.financeManage))
                    _AdminTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: _adminPanelText(
                        context,
                        tr: 'Cüzdan',
                        en: 'Wallet',
                        de: 'Wallet',
                      ),
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
                  if (_can(claims, AdminPermission.financeManage))
                    _AdminTile(
                      icon: Icons.receipt_long_outlined,
                      title: 'Play satışları',
                      collection: 'commercial_operations',
                      field: 'provider',
                      value: 'google_play',
                      countDescription: 'Play satışı',
                      showCount: false,
                      onTap: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) {
                              return const AdminPlaySalesScreen();
                            },
                          ),
                        );
                      },
                    ),
                  if (_can(claims, AdminPermission.financeManage) ||
                      _can(claims, AdminPermission.contentManage))
                    _AdminTile(
                      icon: Icons.link_outlined,
                      title: 'Play ürün eşlemesi',
                      collection: 'badge_products',
                      field: 'active',
                      value: true,
                      countDescription: 'katalog ürünü',
                      showCount: false,
                      onTap: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) {
                              return const AdminPlayProductMappingScreen();
                            },
                          ),
                        );
                      },
                    ),
                  if (_can(claims, AdminPermission.contentManage))
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
                  if (_can(claims, AdminPermission.reportsRead))
                    _AdminTile(
                      icon: Icons.bar_chart_outlined,
                      title: _adminPanelText(
                        context,
                        tr: 'İstatistikler',
                        en: 'Statistics',
                        de: 'Statistiken',
                      ),
                      collection: 'users',
                      field: 'role',
                      value: 'user',
                      countDescription: 'toplu sistem verisi',
                      showCount: false,
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
                  if (_can(claims, AdminPermission.notificationsManage))
                    _AdminTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'Bildirim Merkezi',
                      collection: 'admin_notifications',
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

                  if (_can(claims, AdminPermission.settingsManage))
                    _AdminTile(
                      icon: Icons.settings_outlined,
                      title: _adminPanelText(
                        context,
                        tr: 'Sistem Ayarları',
                        en: 'System Settings',
                        de: 'Systemeinstellungen',
                      ),
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
                  if (_can(claims, AdminPermission.rolesManage))
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
                  if (_can(claims, AdminPermission.auditRead))
                    _AdminTile(
                      icon: Icons.history_outlined,
                      title: _adminPanelText(
                        context,
                        tr: 'Admin İşlem Kayıtları',
                        en: 'Admin Audit Logs',
                        de: 'Admin-Audit-Protokolle',
                      ),
                      collection: 'audit_logs',
                      field: 'action',
                      value: 'unused',
                      countDescription: 'güvenlik işlem kayıtları',
                      showCount: false,
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
                  if (_can(claims, AdminPermission.reportsRead))
                    _AdminTile(
                      icon: Icons.analytics_outlined,
                      title: 'Raporlar',
                      collection: 'users',
                      field: 'role',
                      value: 'user',
                      countDescription: 'yetkili rapor merkezi',
                      showCount: false,
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
    this.showCount = true,
  });

  final IconData icon;
  final String title;
  final String collection;
  final String field;
  final Object value;
  final String countDescription;
  final VoidCallback onTap;
  final bool countAllDocuments;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    if (!showCount) {
      return _buildCard(
        context,
        countText: null,
        description: countDescription,
        loading: false,
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: countAllDocuments
          ? FirebaseFirestore.instance.collection(collection).snapshots()
          : FirebaseFirestore.instance
                .collection(collection)
                .where(field, isEqualTo: value)
                .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final int count = snapshot.data?.docs.length ?? 0;

            return _buildCard(
              context,
              countText: snapshot.hasError ? '—' : '$count',
              description: snapshot.hasError
                  ? _adminPanelText(
                      context,
                      tr: 'Sayı alınamadı',
                      en: 'Count unavailable',
                      de: 'Anzahl nicht verfügbar',
                    )
                  : countDescription,
              loading: snapshot.connectionState == ConnectionState.waiting,
            );
          },
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String? countText,
    required String description,
    required bool loading,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              CircleAvatar(radius: 23, child: Icon(icon, size: 24)),
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
              if (loading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (countText != null)
                Text(
                  countText,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                )
              else
                const Icon(Icons.lock_outline, size: 21),
              const SizedBox(height: 4),
              Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
