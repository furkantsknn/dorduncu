import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_wallet_transactions_screen.dart';
import 'admin_point_transactions_screen.dart';
import 'admin_wallet_adjustment_screen.dart';
import 'admin_account_status_screen.dart';
import 'admin_membership_management_screen.dart';
import 'admin_user_actions_screen.dart';
import 'admin_permission_gate.dart';
import 'admin_access.dart';
import '../services/plus_entitlement.dart';
import '../utils/verification_admin_labels.dart';

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

class AdminUserDetailScreen extends StatelessWidget {
  const AdminUserDetailScreen({super.key, required this.userId});

  final String userId;

  DocumentReference<Map<String, dynamic>> get _userReference {
    return FirebaseFirestore.instance.collection('users').doc(userId);
  }

  DocumentReference<Map<String, dynamic>> get _walletReference {
    return FirebaseFirestore.instance.collection('wallets').doc(userId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userReference.snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (snapshot.hasError) {
              return Scaffold(
                appBar: AppBar(
                  title: Text(
                    _locText(
                      context,
                      tr: 'Kullanıcı Detayı',
                      en: 'User Details',
                      de: 'Nutzerdetails',
                    ),
                  ),
                ),
                body: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Kullanıcı bilgileri yüklenirken bir hata oluştu.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return Scaffold(
                appBar: AppBar(
                  title: Text(
                    _locText(
                      context,
                      tr: 'Kullanıcı Detayı',
                      en: 'User Details',
                      de: 'Nutzerdetails',
                    ),
                  ),
                ),
                body: const Center(child: CircularProgressIndicator()),
              );
            }

            final DocumentSnapshot<Map<String, dynamic>> document =
                snapshot.data!;

            final Map<String, dynamic>? data = document.data();

            if (!document.exists || data == null) {
              return Scaffold(
                appBar: AppBar(
                  title: Text(
                    _locText(
                      context,
                      tr: 'Kullanıcı Detayı',
                      en: 'User Details',
                      de: 'Nutzerdetails',
                    ),
                  ),
                ),
                body: Center(
                  child: Text(
                    _locText(
                      context,
                      tr: 'Kullanıcı bulunamadı.',
                      en: 'User not found.',
                      de: 'Nutzer nicht gefunden.',
                    ),
                  ),
                ),
              );
            }

            final String profileName =
                data['profilAdi']?.toString().trim() ?? '';

            final String name = data['ad']?.toString().trim() ?? '';

            final String surname = data['soyad']?.toString().trim() ?? '';

            final String fullName = '$name $surname'.trim();

            final String displayName = profileName.isNotEmpty
                ? profileName
                : fullName.isNotEmpty
                ? fullName
                : 'İsimsiz kullanıcı';

            final String phone =
                data['telefon']?.toString().trim() ??
                data['phoneNumber']?.toString().trim() ??
                '';

            final String city = data['sehir']?.toString().trim() ?? '';

            final String activeCity =
                data['aktifSehir']?.toString().trim() ?? '';

            final String photoUrl =
                data['profilFotografi']?.toString().trim() ?? '';

            final bool isPlus = PlusEntitlement.isActive(data);
            final bool legacyPlusFlag = data['plus'] == true && !isPlus;

            final bool isPlayer =
                data['oyuncuRozeti'] == true || data['verified'] == true;
            final VerificationAdminLabels application =
                presentVerificationAdmin(
                  status: data['verificationStatus']?.toString() ?? '',
                  automaticCheckStatus: '',
                  reasonCode: data['verificationReasonCode']?.toString() ?? '',
                  decisionSource:
                      data['verificationDecisionSource']?.toString() ?? '',
                );

            final String role = data['role']?.toString().toLowerCase() ?? '';

            final bool isAdmin =
                data['admin'] == true ||
                role == 'admin' ||
                role == 'super_admin' ||
                role == 'moderator';

            final double points = (data['puan'] as num?)?.toDouble() ?? 0;

            final String accountStatus =
                data['hesapDurumu']?.toString().trim() ??
                data['accountStatus']?.toString().trim() ??
                'active';

            final DateTime? createdAt = _dateFromValue(
              data['createdAt'] ?? data['kayitTarihi'],
            );

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  _locText(
                    context,
                    tr: 'Kullanıcı Detayı',
                    en: 'User Details',
                    de: 'Nutzerdetails',
                  ),
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: <Widget>[
                  _ProfileHeaderCard(
                    displayName: displayName,
                    fullName: fullName,
                    photoUrl: photoUrl,
                    isPlus: isPlus,
                    isPlayer: isPlayer,
                    isAdmin: isAdmin,
                    accountStatus: accountStatus,
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: _locText(
                      context,
                      tr: 'Kullanıcı Bilgileri',
                      en: 'User Information',
                      de: 'Nutzerinformationen',
                    ),
                    icon: Icons.person_outline,
                    children: <Widget>[
                      _InformationRow(
                        label: 'Kullanıcı kimliği',
                        value: userId,
                      ),
                      const SizedBox(height: 14),
                      AdminPermissionGate(
                        permission: AdminPermission.usersModerate,
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.push<bool>(
                                context,
                                MaterialPageRoute<bool>(
                                  builder: (BuildContext context) {
                                    return AdminAccountStatusScreen(
                                      userId: userId,
                                      currentStatus: accountStatus,
                                    );
                                  },
                                ),
                              );
                            },
                            icon: const Icon(Icons.manage_accounts_outlined),
                            label: const Text('Hesap Durumunu Yönet'),
                          ),
                        ),
                      ),
                      AdminPermissionGate(
                        permission: AdminPermission.usersModerate,
                        child: const SizedBox(height: 10),
                      ),
                      AdminPermissionGate(
                        permission: AdminPermission.auditRead,
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (BuildContext context) {
                                    return AdminUserActionsScreen(
                                      userId: userId,
                                    );
                                  },
                                ),
                              );
                            },
                            icon: const Icon(Icons.history_outlined),
                            label: const Text('Admin İşlem Geçmişini Gör'),
                          ),
                        ),
                      ),
                      const Divider(height: 24),
                      _InformationRow(
                        label: 'Profil adı',
                        value: profileName.isEmpty
                            ? 'Bilgi bulunamadı'
                            : profileName,
                      ),
                      const Divider(height: 24),
                      _InformationRow(
                        label: 'Ad soyad',
                        value: fullName.isEmpty ? 'Bilgi bulunamadı' : fullName,
                      ),
                      const Divider(height: 24),
                      _InformationRow(
                        label: 'Telefon',
                        value: phone.isEmpty ? 'Bilgi bulunamadı' : phone,
                      ),
                      const Divider(height: 24),
                      _InformationRow(
                        label: _locText(
                          context,
                          tr: 'Şehir',
                          en: 'City',
                          de: 'Stadt',
                        ),
                        value: city.isEmpty ? 'Bilgi bulunamadı' : city,
                      ),
                      if (activeCity.isNotEmpty) ...<Widget>[
                        const Divider(height: 24),
                        _InformationRow(
                          label: 'Aktif şehir',
                          value: activeCity,
                        ),
                      ],
                      if (createdAt != null) ...<Widget>[
                        const Divider(height: 24),
                        _InformationRow(
                          label: 'Kayıt tarihi',
                          value: _formatDate(createdAt),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Google Play Plus',
                    icon: Icons.workspace_premium_outlined,
                    children: <Widget>[
                      _StatusRow(
                        title: 'Plus',
                        enabled: isPlus,
                        enabledText: 'Aktif',
                        disabledText: 'Pasif',
                      ),
                      const SizedBox(height: 14),
                      _InformationRow(
                        label: 'Bitiş',
                        value: _formatOptionalDate(data['plusExpiresAt']),
                      ),
                      const SizedBox(height: 14),
                      _InformationRow(
                        label: 'Abonelik durumu',
                        value: _textOrDash(data['plusSubscriptionState']),
                      ),
                      const SizedBox(height: 14),
                      _InformationRow(
                        label: 'Play ürün kimliği',
                        value: _textOrDash(data['plusGooglePlayProductId']),
                      ),
                      const SizedBox(height: 14),
                      _InformationRow(
                        label: 'Hak kaynağı',
                        value: isPlus ? 'Google Play' : 'Google Play kaydı yok',
                      ),
                      if (legacyPlusFlag) ...<Widget>[
                        const SizedBox(height: 14),
                        const Text(
                          'Eski admin bayrağı açık. Bu bayrak Play hakkı değildir ve süre yoksa Plus açılmaz.',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  _OwnedBadgesSection(userId: userId),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Üyelik ve Rozetler',
                    icon: Icons.workspace_premium_outlined,
                    children: <Widget>[
                      _StatusRow(
                        title: 'Eski Plus bayrağı',
                        enabled: data['plus'] == true,
                        enabledText: 'Bayrak açık',
                        disabledText: 'Bayrak kapalı',
                      ),
                      const Divider(height: 24),
                      _StatusRow(
                        title: 'Oyuncu rozeti',
                        enabled: isPlayer,
                        enabledText: 'Oyuncu rozeti var',
                        disabledText: 'Oyuncu rozeti kapalı',
                      ),
                      const Divider(height: 24),
                      _InformationRow(
                        label: 'Kimlik başvurusu',
                        value: application.applicationStatus,
                      ),
                      const Divider(height: 24),
                      _StatusRow(
                        title: 'Admin yetkisi',
                        enabled: isAdmin,
                        enabledText: 'Admin',
                        disabledText: 'Standart kullanıcı',
                      ),
                      const Divider(height: 24),
                      _InformationRow(
                        label: 'Mevcut puan',
                        value: points == points.roundToDouble()
                            ? '${points.toInt()} puan'
                            : '${points.toStringAsFixed(2)} puan',
                      ),
                      AdminPermissionGate(
                        permission: AdminPermission.financeManage,
                        child: const SizedBox(height: 14),
                      ),
                      AdminPermissionGate(
                        permission: AdminPermission.financeManage,
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (BuildContext context) {
                                    return AdminMembershipManagementScreen(
                                      userId: userId,
                                    );
                                  },
                                ),
                              );
                            },
                            icon: const Icon(Icons.workspace_premium_outlined),
                            label: const Text('Eski üyelik bayrağı'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  AdminPermissionGate(
                    permission: AdminPermission.financeManage,
                    child: const SizedBox(height: 14),
                  ),
                  AdminPermissionGate(
                    permission: AdminPermission.financeManage,
                    child: _WalletSection(
                      userId: userId,
                      walletReference: _walletReference,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Hesap Durumu',
                    icon: Icons.security_outlined,
                    children: <Widget>[
                      _InformationRow(
                        label: 'Mevcut durum',
                        value: _accountStatusTitle(accountStatus),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
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

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    return null;
  }

  static String _formatOptionalDate(dynamic value) {
    final DateTime? date = _dateFromValue(value);
    if (date == null) {
      return '—';
    }
    return _formatDate(date);
  }

  static String _textOrDash(dynamic value) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? '—' : text;
  }

  static String _formatDate(DateTime value) {
    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String year = value.year.toString();
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');

    return '$day.$month.$year $hour:$minute';
  }

  static String _accountStatusTitle(String value) {
    switch (value.toLowerCase()) {
      case 'blocked':
      case 'banned':
        return 'Engelli';
      case 'suspended':
        return 'Askıya alınmış';
      case 'disabled':
        return 'Pasif';
      case 'deletionrequested':
        return 'Hesap silme talebi var';
      default:
        return 'Aktif';
    }
  }
}

class _WalletSection extends StatelessWidget {
  const _WalletSection({required this.userId, required this.walletReference});

  final String userId;
  final DocumentReference<Map<String, dynamic>> walletReference;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: walletReference.snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic> data =
                snapshot.data?.data() ?? <String, dynamic>{};

            final int available =
                (data['availableBalanceKurus'] as num?)?.toInt() ?? 0;

            final int pending =
                (data['pendingBalanceKurus'] as num?)?.toInt() ?? 0;

            final int refund =
                (data['refundBalanceKurus'] as num?)?.toInt() ?? 0;

            final int frozen =
                (data['frozenBalanceKurus'] as num?)?.toInt() ?? 0;

            final int withdrawalPending =
                (data['withdrawalPendingKurus'] as num?)?.toInt() ?? 0;

            final bool isFrozen = data['isFrozen'] == true;

            return _SectionCard(
              title: 'Cüzdan',
              icon: Icons.account_balance_wallet_outlined,
              children: <Widget>[
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (snapshot.hasError)
                  const Text('Cüzdan bilgileri alınamadı.')
                else ...<Widget>[
                  _BalanceRow(
                    label: 'Kullanılabilir bakiye',
                    value: _money(available),
                  ),
                  const Divider(height: 24),
                  _BalanceRow(label: 'Bekleyen kazanç', value: _money(pending)),
                  const Divider(height: 24),
                  _BalanceRow(label: 'İade bakiyesi', value: _money(refund)),
                  const Divider(height: 24),
                  _BalanceRow(
                    label: 'Dondurulmuş bakiye',
                    value: _money(frozen),
                  ),
                  const Divider(height: 24),
                  _BalanceRow(
                    label: 'Bekleyen para çekme',
                    value: _money(withdrawalPending),
                  ),
                  const Divider(height: 24),
                  _StatusRow(
                    title: 'Cüzdan durumu',
                    enabled: !isFrozen,
                    enabledText: 'Aktif',
                    disabledText: 'Dondurulmuş',
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) {
                              return AdminWalletAdjustmentScreen(
                                userId: userId,
                              );
                            },
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_note_outlined),
                      label: const Text('Bakiye veya Puan İşlemi Yap'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) {
                              return AdminWalletTransactionsScreen(
                                userId: userId,
                              );
                            },
                          ),
                        );
                      },
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('Cüzdan Hareketlerini Gör'),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) {
                            return AdminPointTransactionsScreen(userId: userId);
                          },
                        ),
                      );
                    },
                    icon: const Icon(Icons.stars_outlined),
                    label: const Text('Puan Hareketlerini Gör'),
                  ),
                ),
              ],
            );
          },
    );
  }

  static String _money(int amountKurus) {
    final double amount = amountKurus / 100;
    return '${amount.toStringAsFixed(2)} TL';
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.displayName,
    required this.fullName,
    required this.photoUrl,
    required this.isPlus,
    required this.isPlayer,
    required this.isAdmin,
    required this.accountStatus,
  });

  final String displayName;
  final String fullName;
  final String photoUrl;
  final bool isPlus;
  final bool isPlayer;
  final bool isAdmin;
  final String accountStatus;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 35,
              backgroundImage: photoUrl.isEmpty ? null : NetworkImage(photoUrl),
              child: photoUrl.isEmpty
                  ? const Icon(Icons.person_outline, size: 34)
                  : null,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (fullName.isNotEmpty &&
                      fullName != displayName) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(fullName),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: <Widget>[
                      _HeaderLabel(
                        text: AdminUserDetailScreen._accountStatusTitle(
                          accountStatus,
                        ),
                        icon: Icons.shield_outlined,
                      ),
                      if (isPlus)
                        const _HeaderLabel(
                          text: 'Plus',
                          icon: Icons.workspace_premium_rounded,
                        ),
                      if (isPlayer)
                        const _HeaderLabel(
                          text: 'Oyuncu',
                          icon: Icons.verified_rounded,
                        ),
                      if (isAdmin)
                        const _HeaderLabel(
                          text: 'Admin',
                          icon: Icons.admin_panel_settings_rounded,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

class _InformationRow extends StatelessWidget {
  const _InformationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          child: SelectableText(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        Text(
          value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _OwnedBadgesSection extends StatelessWidget {
  const _OwnedBadgesSection({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('owned_badges')
          .snapshots(),
      builder: (context, snapshot) {
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data?.docs ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        return _SectionCard(
          title: 'Satın alınan rozetler',
          icon: Icons.military_tech_outlined,
          children: <Widget>[
            if (snapshot.hasError)
              const Text('Rozetler yüklenemedi.')
            else if (!snapshot.hasData)
              const LinearProgressIndicator()
            else if (docs.isEmpty)
              const Text('Bu kullanıcıda Play rozeti yok.')
            else
              ...docs.map((document) {
                final Map<String, dynamic> data = document.data();
                final bool revoked = data['googlePlayEntitled'] == false;
                final String name =
                    data['title']?.toString().trim().isNotEmpty == true
                    ? data['title'].toString().trim()
                    : data['gameName']?.toString().trim().isNotEmpty == true
                    ? data['gameName'].toString().trim()
                    : document.id;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text('Rozet kimliği: ${document.id}'),
                      Text(
                        'Play ürünü: ${AdminUserDetailScreen._textOrDash(data['googlePlayProductId'])}',
                      ),
                      Text(
                        revoked
                            ? 'Durum: Play hakkı kaldırıldı'
                            : 'Durum: Aktif',
                      ),
                      Text(
                        'Satın alma: ${AdminUserDetailScreen._formatOptionalDate(data['purchasedAt'] ?? data['createdAt'])}',
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.title,
    required this.enabled,
    required this.enabledText,
    required this.disabledText,
  });

  final String title;
  final bool enabled;
  final String enabledText;
  final String disabledText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(title)),
        Icon(
          enabled ? Icons.check_circle_rounded : Icons.remove_circle_outline,
          size: 19,
        ),
        const SizedBox(width: 6),
        Text(
          enabled ? enabledText : disabledText,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  const _HeaderLabel({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
