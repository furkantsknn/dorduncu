import 'package:cloud_firestore/cloud_firestore.dart';
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


class AdminMarketOrdersScreen extends StatefulWidget {
  const AdminMarketOrdersScreen({super.key});

  @override
  State<AdminMarketOrdersScreen> createState() =>
      _AdminMarketOrdersScreenState();
}

class _AdminMarketOrdersScreenState
    extends State<AdminMarketOrdersScreen> {
  final TextEditingController _searchController =
  TextEditingController();

  String _searchText = '';
  String _selectedStatus = 'all';
  String _selectedPaymentType = 'all';

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
          'Market Siparişleri',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('market_orders')
            .orderBy('createdAt', descending: true)
            .limit(500)
            .snapshots(),
        builder: (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
            snapshot,
            ) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Market siparişleri yüklenirken bir hata oluştu.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final List<
              QueryDocumentSnapshot<Map<String, dynamic>>>
          allOrders = snapshot.data!.docs;

          final List<
              QueryDocumentSnapshot<Map<String, dynamic>>>
          visibleOrders = allOrders.where((document) {
            final Map<String, dynamic> data =
            document.data();

            final String status =
                data['status']?.toString() ?? 'pending';

            final String paymentType =
                data['paymentType']?.toString() ??
                    data['paymentMethod']?.toString() ??
                    '';

            if (_selectedStatus != 'all' &&
                status != _selectedStatus) {
              return false;
            }

            if (_selectedPaymentType != 'all' &&
                paymentType != _selectedPaymentType) {
              return false;
            }

            if (_searchText.isEmpty) {
              return true;
            }

            final String query =
            _searchText.toLowerCase();

            final String userId =
                data['userId']
                    ?.toString()
                    .toLowerCase() ??
                    '';

            final String productId =
                data['productId']
                    ?.toString()
                    .toLowerCase() ??
                    '';

            final String productTitle =
                data['productTitle']
                    ?.toString()
                    .toLowerCase() ??
                    '';

            final String transactionId =
                data['transactionId']
                    ?.toString()
                    .toLowerCase() ??
                    '';

            return userId.contains(query) ||
                productId.contains(query) ||
                productTitle.contains(query) ||
                transactionId.contains(query) ||
                document.id
                    .toLowerCase()
                    .contains(query);
          }).toList();

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  10,
                ),
                child: _buildStatistics(allOrders),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  12,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (String value) {
                    setState(() {
                      _searchText = value.trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText:
                    'Kullanıcı, ürün veya sipariş no ara',
                    prefixIcon:
                    const Icon(Icons.search),
                    suffixIcon: _searchText.isEmpty
                        ? null
                        : IconButton(
                      onPressed: () {
                        _searchController
                            .clear();

                        setState(() {
                          _searchText = '';
                        });
                      },
                      icon: const Icon(
                        Icons.close,
                      ),
                    ),
                    border:
                    const OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    _buildStatusFilter(
                      'all',
                      'Tüm durumlar',
                    ),
                    _buildStatusFilter(
                      'pending',
                      'Bekliyor',
                    ),
                    _buildStatusFilter(
                      'completed',
                      _locText(context, tr: 'Tamamlandı', en: 'Completed', de: 'Abgeschlossen'),
                    ),
                    _buildStatusFilter(
                      'failed',
                      _locText(context, tr: 'Başarısız', en: 'Failed', de: 'Fehlgeschlagen'),
                    ),
                    _buildStatusFilter(
                      'refunded',
                      'İade',
                    ),
                    _buildStatusFilter(
                      'cancelled',
                      'İptal',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ListView(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    _buildPaymentFilter(
                      'all',
                      'Tüm ödemeler',
                    ),
                    _buildPaymentFilter(
                      'wallet',
                      'Cüzdan',
                    ),
                    _buildPaymentFilter(
                      'points',
                      'Puan',
                    ),
                    _buildPaymentFilter(
                      'online',
                      'Online',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: visibleOrders.isEmpty
                    ? const Center(
                  child: Padding(
                    padding:
                    EdgeInsets.all(24),
                    child: Text(
                      'Bu filtreye uygun sipariş bulunamadı.',
                      textAlign:
                      TextAlign.center,
                      style: TextStyle(
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),
                  ),
                )
                    : ListView.separated(
                  padding:
                  const EdgeInsets
                      .fromLTRB(
                    16,
                    0,
                    16,
                    32,
                  ),
                  itemCount:
                  visibleOrders.length,
                  separatorBuilder: (
                      BuildContext context,
                      int index,
                      ) {
                    return const SizedBox(
                      height: 10,
                    );
                  },
                  itemBuilder: (
                      BuildContext context,
                      int index,
                      ) {
                    final QueryDocumentSnapshot<
                        Map<String,
                            dynamic>>
                    document =
                    visibleOrders[index];

                    return _OrderCard(
                      orderId: document.id,
                      data:
                      document.data(),
                    );
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
      List<QueryDocumentSnapshot<Map<String, dynamic>>>
      orders,
      ) {
    int completedCount = 0;
    int pendingCount = 0;
    int failedCount = 0;

    for (final QueryDocumentSnapshot<
        Map<String, dynamic>> document
    in orders) {
      final String status =
          document.data()['status']?.toString() ??
              'pending';

      switch (status) {
        case 'completed':
          completedCount++;
          break;
        case 'failed':
          failedCount++;
          break;
        default:
          pendingCount++;
      }
    }

    return Row(
      children: <Widget>[
        Expanded(
          child: _StatisticCard(
            title: 'Toplam',
            value: orders.length,
            icon:
            Icons.shopping_bag_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatisticCard(
            title: _locText(context, tr: 'Tamamlandı', en: 'Completed', de: 'Abgeschlossen'),
            value: completedCount,
            icon:
            Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatisticCard(
            title: 'Bekliyor',
            value: pendingCount,
            icon:
            Icons.hourglass_top_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatisticCard(
            title: _locText(context, tr: 'Başarısız', en: 'Failed', de: 'Fehlgeschlagen'),
            value: failedCount,
            icon: Icons.error_outline,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusFilter(
      String value,
      String label,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _selectedStatus == value,
        onSelected: (_) {
          setState(() {
            _selectedStatus = value;
          });
        },
      ),
    );
  }

  Widget _buildPaymentFilter(
      String value,
      String label,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected:
        _selectedPaymentType == value,
        onSelected: (_) {
          setState(() {
            _selectedPaymentType = value;
          });
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.orderId,
    required this.data,
  });

  final String orderId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final String productTitle =
        data['productTitle']?.toString().trim() ??
            'İsimsiz ürün';

    final String userId =
        data['userId']?.toString().trim() ?? '';

    final String productId =
        data['productId']?.toString().trim() ?? '';

    final String status =
        data['status']?.toString() ?? 'pending';

    final String paymentType =
        data['paymentType']?.toString() ??
            data['paymentMethod']?.toString() ??
            '';

    final int amountKurus =
        (data['amountKurus'] as num?)?.toInt() ??
            0;

    final double pointAmount =
        (data['pointAmount'] as num?)
            ?.toDouble() ??
            (data['pointPrice'] as num?)
                ?.toDouble() ??
            0;

    final DateTime? createdAt =
    _dateFromValue(data['createdAt']);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(
              child: Icon(
                _paymentIcon(paymentType),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    productTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight:
                      FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: <Widget>[
                      _InfoLabel(
                        text:
                        _statusTitle(context, status),
                        icon:
                        _statusIcon(status),
                      ),
                      _InfoLabel(
                        text:
                        _paymentTitle(paymentType),
                        icon:
                        _paymentIcon(paymentType),
                      ),
                      if (amountKurus > 0)
                        _InfoLabel(
                          text:
                          _money(amountKurus),
                          icon:
                          Icons.payments_outlined,
                        ),
                      if (pointAmount > 0)
                        _InfoLabel(
                          text:
                          '${_formatPoints(pointAmount)} puan',
                          icon:
                          Icons.stars_outlined,
                        ),
                      if (createdAt != null)
                        _InfoLabel(
                          text:
                          _formatDate(createdAt),
                          icon:
                          Icons.schedule_outlined,
                        ),
                    ],
                  ),
                  if (userId.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    SelectableText(
                      'Kullanıcı: $userId',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall,
                    ),
                  ],
                  if (productId.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    SelectableText(
                      'Ürün: $productId',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall,
                    ),
                  ],
                  const SizedBox(height: 4),
                  SelectableText(
                    'Sipariş: $orderId',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusTitle(BuildContext context, String value) {
    switch (value) {
      case 'completed':
        return _locText(context, tr: 'Tamamlandı', en: 'Completed', de: 'Abgeschlossen');
      case 'failed':
        return _locText(context, tr: 'Başarısız', en: 'Failed', de: 'Fehlgeschlagen');
      case 'refunded':
        return 'İade edildi';
      case 'cancelled':
        return _locText(context, tr: 'İptal edildi', en: 'Cancelled', de: 'Abgesagt');
      default:
        return 'Bekliyor';
    }
  }

  static IconData _statusIcon(String value) {
    switch (value) {
      case 'completed':
        return Icons.check_circle_outline;
      case 'failed':
        return Icons.error_outline;
      case 'refunded':
        return Icons.currency_exchange_outlined;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.hourglass_top_outlined;
    }
  }

  static String _paymentTitle(String value) {
    switch (value) {
      case 'wallet':
        return 'Cüzdan';
      case 'points':
        return 'Puan';
      case 'online':
        return 'Online ödeme';
      default:
        return 'Ödeme türü yok';
    }
  }

  static IconData _paymentIcon(String value) {
    switch (value) {
      case 'wallet':
        return Icons
            .account_balance_wallet_outlined;
      case 'points':
        return Icons.stars_outlined;
      case 'online':
        return Icons.credit_card_outlined;
      default:
        return Icons.payment_outlined;
    }
  }

  static DateTime? _dateFromValue(
      dynamic value,
      ) {
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

  String _formatDate(
      DateTime value,
      ) {
    final String day =
    value.day.toString().padLeft(2, '0');

    final String month =
    value.month.toString().padLeft(2, '0');

    final String year =
    value.year.toString();

    final String hour =
    value.hour.toString().padLeft(2, '0');

    final String minute =
    value.minute.toString().padLeft(2, '0');

    return '$day.$month.$year $hour:$minute';
  }

  static String _money(int amountKurus) {
    return '${(amountKurus / 100).toStringAsFixed(2)} TL';
  }

  static String _formatPoints(
      double value,
      ) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }
}

class _StatisticCard extends StatelessWidget {
  const _StatisticCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 12,
        ),
        child: Column(
          children: <Widget>[
            Icon(icon),
            const SizedBox(height: 5),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 19,
                fontWeight:
                FontWeight.w900,
              ),
            ),
            Text(
              title,
              maxLines: 1,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLabel extends StatelessWidget {
  const _InfoLabel({
    required this.text,
    required this.icon,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .secondaryContainer,
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight:
              FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}