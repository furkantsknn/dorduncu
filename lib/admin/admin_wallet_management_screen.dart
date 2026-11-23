import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_user_detail_screen.dart';

class AdminWalletManagementScreen extends StatefulWidget {
  const AdminWalletManagementScreen({super.key});

  @override
  State<AdminWalletManagementScreen> createState() =>
      _AdminWalletManagementScreenState();
}

class _AdminWalletManagementScreenState
    extends State<AdminWalletManagementScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  String _selectedFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cüzdan Yönetimi',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('wallets').snapshots(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Cüzdanlar yüklenirken bir hata oluştu.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final List<QueryDocumentSnapshot<Map<String, dynamic>>>
              allWallets = snapshot.data!.docs;

              final List<QueryDocumentSnapshot<Map<String, dynamic>>>
              visibleWallets = allWallets.where((document) {
                final Map<String, dynamic> data = document.data();

                final int availableBalance = _readInt(
                  data,
                  'availableBalanceKurus',
                );

                final int pendingBalance = _readInt(
                  data,
                  'pendingBalanceKurus',
                );

                final bool isFrozen = data['isFrozen'] == true;

                switch (_selectedFilter) {
                  case 'positive':
                    if (availableBalance <= 0) {
                      return false;
                    }
                  case 'pending':
                    if (pendingBalance <= 0) {
                      return false;
                    }
                  case 'frozen':
                    if (!isFrozen) {
                      return false;
                    }
                  case 'all':
                    break;
                }

                if (_searchText.isEmpty) {
                  return true;
                }

                final String query = _searchText.toLowerCase();

                final String userId = document.id.toLowerCase();

                final String ownerId =
                    data['userId']?.toString().toLowerCase() ?? '';

                return userId.contains(query) || ownerId.contains(query);
              }).toList();

              visibleWallets.sort((a, b) {
                final int aBalance = _readInt(
                  a.data(),
                  'availableBalanceKurus',
                );

                final int bBalance = _readInt(
                  b.data(),
                  'availableBalanceKurus',
                );

                return bBalance.compareTo(aBalance);
              });

              return Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: _buildStatistics(allWallets),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (String value) {
                        setState(() {
                          _searchText = value.trim();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Kullanıcı kimliği ara',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchText.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Aramayı temizle',
                                onPressed: () {
                                  _searchController.clear();

                                  setState(() {
                                    _searchText = '';
                                  });
                                },
                                icon: const Icon(Icons.close),
                              ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      children: <Widget>[
                        _buildFilter('all', 'Tümü'),
                        _buildFilter('positive', 'Bakiyesi Olan'),
                        _buildFilter('pending', 'Bekleyen Kazanç'),
                        _buildFilter('frozen', 'Dondurulan'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: visibleWallets.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Bu filtreye uygun cüzdan bulunamadı.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                            itemCount: visibleWallets.length,
                            separatorBuilder:
                                (BuildContext context, int index) {
                                  return const SizedBox(height: 10);
                                },
                            itemBuilder: (BuildContext context, int index) {
                              final QueryDocumentSnapshot<Map<String, dynamic>>
                              document = visibleWallets[index];

                              return _buildWalletCard(context, document);
                            },
                          ),
                  ),
                ],
              );
            },
      ),
    );
  }

  Widget _buildStatistics(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> wallets,
  ) {
    int totalAvailable = 0;
    int totalPending = 0;
    int frozenCount = 0;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in wallets) {
      final Map<String, dynamic> data = document.data();

      totalAvailable += _readInt(data, 'availableBalanceKurus');

      totalPending += _readInt(data, 'pendingBalanceKurus');

      if (data['isFrozen'] == true) {
        frozenCount++;
      }
    }

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _StatisticCard(
                title: 'Cüzdan',
                value: '${wallets.length}',
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatisticCard(
                title: 'Dondurulan',
                value: '$frozenCount',
                icon: Icons.ac_unit_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: _StatisticCard(
                title: 'Toplam Bakiye',
                value: _money(totalAvailable),
                icon: Icons.payments_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatisticCard(
                title: 'Bekleyen',
                value: _money(totalPending),
                icon: Icons.hourglass_top_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilter(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _selectedFilter == value,
        onSelected: (_) {
          setState(() {
            _selectedFilter = value;
          });
        },
      ),
    );
  }

  Widget _buildWalletCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data();

    final String userId = data['userId']?.toString().trim().isNotEmpty == true
        ? data['userId'].toString().trim()
        : document.id;

    final int availableBalance = _readInt(data, 'availableBalanceKurus');

    final int pendingBalance = _readInt(data, 'pendingBalanceKurus');

    final int refundBalance = _readInt(data, 'refundBalanceKurus');

    final int frozenBalance = _readInt(data, 'frozenBalanceKurus');

    final bool isFrozen = data['isFrozen'] == true;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (BuildContext context) {
                return AdminUserDetailScreen(userId: userId);
              },
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                radius: 27,
                child: Icon(
                  isFrozen
                      ? Icons.lock_outline
                      : Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Kullanıcı Cüzdanı',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    SelectableText(
                      userId,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: <Widget>[
                        _InfoLabel(
                          text: 'Bakiye: ${_money(availableBalance)}',
                          icon: Icons.payments_outlined,
                        ),
                        if (pendingBalance > 0)
                          _InfoLabel(
                            text: 'Bekleyen: ${_money(pendingBalance)}',
                            icon: Icons.hourglass_top_outlined,
                          ),
                        if (refundBalance > 0)
                          _InfoLabel(
                            text: 'İade: ${_money(refundBalance)}',
                            icon: Icons.currency_exchange_outlined,
                          ),
                        if (frozenBalance > 0)
                          _InfoLabel(
                            text: 'Dondurulan: ${_money(frozenBalance)}',
                            icon: Icons.ac_unit_outlined,
                          ),
                        _InfoLabel(
                          text: isFrozen ? 'Cüzdan donduruldu' : 'Cüzdan aktif',
                          icon: isFrozen
                              ? Icons.lock_outline
                              : Icons.check_circle_outline,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  static int _readInt(Map<String, dynamic> data, String key) {
    return (data[key] as num?)?.toInt() ?? 0;
  }

  static String _money(int amountKurus) {
    return '${(amountKurus / 100).toStringAsFixed(2)} TL';
  }
}

class _StatisticCard extends StatelessWidget {
  const _StatisticCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        child: Column(
          children: <Widget>[
            Icon(icon),
            const SizedBox(height: 6),
            FittedBox(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLabel extends StatelessWidget {
  const _InfoLabel({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
