import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../models/badge_product_model.dart';
import '../models/plus_product_model.dart';
import '../services/market_service.dart';
import '../services/plus_service.dart';
import 'market_payment_sheet.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final MarketService _marketService = MarketService();
  final PlusService _plusService = PlusService();

  String _searchText = '';
  String _selectedFilter = 'all';
  bool _purchaseBusy = false;

  int _readInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(int kurus) {
    final String whole = (kurus ~/ 100).toString();
    final String decimal = (kurus % 100).abs().toString().padLeft(2, '0');

    final StringBuffer buffer = StringBuffer();

    for (int index = 0; index < whole.length; index++) {
      if (index > 0 && (whole.length - index) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(whole[index]);
    }

    return '₺${buffer.toString()},$decimal';
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(
          child: Text('Market için giriş yapmalısın.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dört. Store',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Rozetlerim',
            onPressed: () {
              setState(() {
                _selectedFilter = 'owned';
              });
            },
            icon: const Icon(Icons.workspace_premium_outlined),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _marketService.watchWallet(uid),
        builder: (context, walletSnapshot) {
          final Map<String, dynamic> walletData =
              walletSnapshot.data?.data() ?? <String, dynamic>{};

          final int marketBalance =
          _readInt(walletData['marketBalanceKurus']);
          final int availableBalance =
          _readInt(walletData['availableBalanceKurus']);

          return StreamBuilder<Set<String>>(
            stream: _marketService.watchOwnedBadgeIds(uid),
            builder: (context, ownedSnapshot) {
              final Set<String> ownedBadgeIds =
                  ownedSnapshot.data ?? <String>{};

              return StreamBuilder<List<BadgeProductModel>>(
                stream: _marketService.watchActiveBadgeProducts(),
                builder: (context, productSnapshot) {
                  if (productSnapshot.hasError) {
                    return _ErrorState(
                      message: 'Ürünler yüklenemedi.',
                      onRetry: () => setState(() {}),
                    );
                  }

                  if (productSnapshot.connectionState ==
                      ConnectionState.waiting &&
                      !productSnapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final List<BadgeProductModel> products =
                  (productSnapshot.data ?? const <BadgeProductModel>[])
                      .where((product) {
                    final bool searchMatches = _searchText.isEmpty ||
                        product.title
                            .toLowerCase()
                            .contains(_searchText) ||
                        product.gameName
                            .toLowerCase()
                            .contains(_searchText);

                    final bool owned =
                    ownedBadgeIds.contains(product.id);

                    final bool filterMatches =
                        _selectedFilter == 'all' ||
                            (_selectedFilter == 'owned' && owned) ||
                            (_selectedFilter == 'available' && !owned);

                    return searchMatches && filterMatches;
                  }).toList();

                  return RefreshIndicator(
                    color: const Color(0xffFF9800),
                    onRefresh: () async {
                      await Future.wait<dynamic>(<Future<dynamic>>[
                        FirebaseFirestore.instance
                            .collection('wallets')
                            .doc(uid)
                            .get(),
                        FirebaseFirestore.instance
                            .collection('badge_products')
                            .limit(1)
                            .get(),
                      ]);
                    },
                    child: ListView(
                      physics:
                      const AlwaysScrollableScrollPhysics(),
                      padding:
                      const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: <Widget>[
                        _StoreHeader(
                          marketBalance: _money(marketBalance),
                          availableBalance:
                          _money(availableBalance),
                          ownedCount: ownedBadgeIds.length,
                        ),
                        const SizedBox(height: 14),
                        StreamBuilder<List<PlusProductModel>>(
                          stream: _plusService.watchActiveProducts(),
                          builder: (context, plusSnapshot) {
                            final List<PlusProductModel> plusProducts =
                                plusSnapshot.data ??
                                    const <PlusProductModel>[];

                            return _PlusMembershipShowcase(
                              loading:
                              plusSnapshot.connectionState ==
                                  ConnectionState.waiting &&
                                  !plusSnapshot.hasData,
                              enabled: plusProducts.isNotEmpty,
                              onTap: plusProducts.isEmpty
                                  ? null
                                  : () {
                                _showPlusProducts(
                                  products: plusProducts,
                                  availableBalance:
                                  availableBalance,
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          onChanged: (value) {
                            setState(() {
                              _searchText =
                                  value.trim().toLowerCase();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Oyun rozeti ara',
                            prefixIcon:
                            const Icon(Icons.search_rounded),
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 42,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: <Widget>[
                              _filterChip(
                                value: 'all',
                                label: 'Tümü',
                                icon: Icons.grid_view_rounded,
                              ),
                              const SizedBox(width: 8),
                              _filterChip(
                                value: 'available',
                                label: 'Satın Alınabilir',
                                icon:
                                Icons.shopping_bag_outlined,
                              ),
                              const SizedBox(width: 8),
                              _filterChip(
                                value: 'owned',
                                label: 'Rozetlerim',
                                icon:
                                Icons.workspace_premium_outlined,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'Rozet Koleksiyonu',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                  fontWeight:
                                  FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              '${products.length} ürün',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (products.isEmpty)
                          const _EmptyState()
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final int crossAxisCount =
                              constraints.maxWidth >= 760 ? 2 : 1;

                              return GridView.builder(
                                shrinkWrap: true,
                                physics:
                                const NeverScrollableScrollPhysics(),
                                itemCount: products.length,
                                gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: constraints.maxWidth >= 760 ? 3.05 : 3.15,
                                ),
                                itemBuilder: (context, index) {
                                  final BadgeProductModel product =
                                  products[index];
                                  final bool owned =
                                  ownedBadgeIds.contains(
                                    product.id,
                                  );

                                  return _BadgeProductCard(
                                    product: product,
                                    owned: owned,
                                    price: _money(
                                      product.priceKurus,
                                    ),
                                    onTap: () {
                                      _showProductPreview(
                                        product: product,
                                        owned: owned,
                                        marketBalance:
                                        marketBalance,
                                        availableBalance:
                                        availableBalance,
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _filterChip({
    required String value,
    required String label,
    required IconData icon,
  }) {
    return ChoiceChip(
      selected: _selectedFilter == value,
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onSelected: (_) {
        setState(() {
          _selectedFilter = value;
        });
      },
    );
  }

  Future<void> _showProductPreview({
    required BadgeProductModel product,
    required bool owned,
    required int marketBalance,
    required int availableBalance,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.52,
          maxChildSize: 0.94,
          builder: (
              BuildContext context,
              ScrollController scrollController,
              ) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(
                    child: Text(
                      product.emoji.isEmpty ? '🏅' : product.emoji,
                      style: const TextStyle(fontSize: 46),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    product.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description.isEmpty
                        ? 'Bu rozet profilinde görünür.'
                        : product.description,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      children: <Widget>[
                        _BenefitRow(
                          icon: Icons.visibility_outlined,
                          text: 'Profilinde herkese görünür',
                        ),
                        SizedBox(height: 9),
                        _BenefitRow(
                          icon: Icons.lock_outline_rounded,
                          text: 'Tek sefer satın alınır ve kalıcıdır',
                        ),
                        SizedBox(height: 9),
                        _BenefitRow(
                          icon: Icons.workspace_premium_outlined,
                          text: 'Oyun kimliğini öne çıkarır',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _PaymentInfoRow(
                    label: 'Ürün fiyatı',
                    value: _money(product.priceKurus),
                  ),
                  _PaymentInfoRow(
                    label: 'Market bakiyesi',
                    value: _money(marketBalance),
                  ),
                  _PaymentInfoRow(
                    label: 'Çekilebilir bakiye',
                    value: _money(availableBalance),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: owned || _purchaseBusy
                        ? null
                        : () async {
                      Navigator.of(sheetContext).pop();

                      final MarketPaymentSource? source =
                      await showMarketPaymentSheet(
                        context: context,
                        priceKurus: product.priceKurus,
                        marketBalanceKurus: marketBalance,
                        availableBalanceKurus:
                        availableBalance,
                        title: product.title,
                      );

                      if (source == null || !mounted) {
                        return;
                      }

                      await _purchaseBadge(
                        product,
                        paymentSource: source,
                      );
                    },
                    icon: _purchaseBusy
                        ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : Icon(
                      owned
                          ? Icons.check_circle_outline
                          : Icons.shopping_bag_outlined,
                    ),
                    label: Padding(
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        owned
                            ? 'Bu rozete sahipsin'
                            : _purchaseBusy
                            ? 'İşleniyor...'
                            : 'Satın Al',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  Future<void> _purchaseBadge(
      BadgeProductModel product, {
        required MarketPaymentSource paymentSource,
      }) async {
    if (_purchaseBusy) return;

    setState(() {
      _purchaseBusy = true;
    });

    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('purchaseBadge');

      await callable.call(<String, dynamic>{
        'badgeId': product.id,
        'paymentSource': paymentSource.value,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${product.title} başarıyla satın alındı.',
            ),
          ),
        );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;

      final String message = error.message?.trim().isNotEmpty == true
          ? error.message!.trim()
          : 'Satın alma işlemi tamamlanamadı.';

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(message)),
        );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Satın alma işlemi tamamlanamadı: $error',
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _purchaseBusy = false;
        });
      }
    }
  }

  Future<void> _showPlusProducts({
    required List<PlusProductModel> products,
    required int availableBalance,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Icon(
                Icons.workspace_premium_rounded,
                size: 54,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 10),
              Text(
                'Dört. Plus',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sana uygun Plus paketini seç.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ...products.map((product) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PlusProductCard(
                    product: product,
                    price: _money(product.priceKurus),
                    onTap: _purchaseBusy
                        ? null
                        : availableBalance < product.priceKurus
                        ? null
                        : () async {
                      Navigator.of(sheetContext).pop();

                      await _purchasePlus(product);
                    },
                  ),
                );
              }),
              const SizedBox(height: 4),
              const _PlusBenefitsCard(),
            ],
          ),
        );
      },
    );
  }

  Future<void> _purchasePlus(
      PlusProductModel product,
      ) async {
    if (_purchaseBusy) {
      return;
    }

    setState(() {
      _purchaseBusy = true;
    });

    try {
      final DateTime expiry = await _plusService.purchasePlus(
        productId: product.id,
        paymentSource: 'available',
      );
      if (!mounted) {
        return;
      }

      final String expiryText =
          '${expiry.day.toString().padLeft(2, '0')}.'
          '${expiry.month.toString().padLeft(2, '0')}.'
          '${expiry.year}';

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${product.title} aktif edildi. Bitiş: $expiryText',
            ),
          ),
        );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error.message ??
                  'Plus satın alma işlemi tamamlanamadı.',
            ),
          ),
        );
    } on PlusServiceException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(error.message)),
        );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Plus satın alma işlemi tamamlanamadı: $error',
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _purchaseBusy = false;
        });
      }
    }
  }


}

class _PlusMembershipShowcase extends StatelessWidget {
  const _PlusMembershipShowcase({
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  final bool loading;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled && !loading ? onTap : null,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.onSurface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: <BoxShadow>[
              BoxShadow(
                blurRadius: 24,
                offset: const Offset(0, 10),
                color: Colors.black.withValues(alpha: 0.14),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xffFFB74D),
                      Color(0xffF57C00),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 31,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          'Dört. Plus',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(width: 8),
                        _PlusActiveLabel(),
                      ],
                    ),
                    SizedBox(height: 5),
                    Text(
                      '1 veya 3 aylık paketi seç, ayrıcalıkları hemen kullan.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (loading)
                const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(
                  enabled
                      ? Icons.arrow_forward_ios_rounded
                      : Icons.error_outline_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlusActiveLabel extends StatelessWidget {
  const _PlusActiveLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xffFF9800).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Text(
        'SATIŞTA',
        style: TextStyle(
          color: Color(0xffFFB74D),
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _PlusProductCard extends StatelessWidget {
  const _PlusProductCard({
    required this.product,
    required this.price,
    required this.onTap,
  });

  final PlusProductModel product;
  final String price;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colors.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      product.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${product.durationDays} gün Plus üyelik',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    price,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlusBenefitsCard extends StatelessWidget {
  const _PlusBenefitsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: <Widget>[
          _BenefitRow(
            icon: Icons.event_available_outlined,
            text: 'Etkinlikleri ileri tarihe planla',
          ),
          SizedBox(height: 10),
          _BenefitRow(
            icon: Icons.groups_outlined,
            text: 'Birden fazla oyuncu için etkinlik oluştur',
          ),
          SizedBox(height: 10),
          _BenefitRow(
            icon: Icons.workspace_premium_outlined,
            text: 'Profilinde Plus ayrıcalığını göster',
          ),
        ],
      ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({
    required this.marketBalance,
    required this.availableBalance,
    required this.ownedCount,
  });

  final String marketBalance;
  final String availableBalance;
  final int ownedCount;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            colors.primary,
            colors.primary.withValues(alpha: 0.84),
            const Color(0xffFF9800),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            blurRadius: 26,
            offset: const Offset(0, 12),
            color: colors.primary.withValues(alpha: 0.22),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -18,
            top: -28,
            child: Icon(
              Icons.workspace_premium_rounded,
              size: 132,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.24),
                      ),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Dört. Market',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Rozetlerini topla, profilini kişiselleştir',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '$ownedCount rozet',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (
                    BuildContext context,
                    BoxConstraints constraints,
                    ) {
                  if (constraints.maxWidth < 390) {
                    return Column(
                      children: <Widget>[
                        _BalanceMiniCard(
                          title: 'Market bakiyesi',
                          value: marketBalance,
                          icon: Icons.shopping_bag_outlined,
                        ),
                        const SizedBox(height: 9),
                        _BalanceMiniCard(
                          title: 'Kullanılabilir bakiye',
                          value: availableBalance,
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: <Widget>[
                      Expanded(
                        child: _BalanceMiniCard(
                          title: 'Market bakiyesi',
                          value: marketBalance,
                          icon: Icons.shopping_bag_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _BalanceMiniCard(
                          title: 'Kullanılabilir bakiye',
                          value: availableBalance,
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceMiniCard extends StatelessWidget {
  const _BalanceMiniCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeProductCard extends StatelessWidget {
  const _BadgeProductCard({
    required this.product,
    required this.owned,
    required this.price,
    required this.onTap,
  });

  final BadgeProductModel product;
  final bool owned;
  final String price;
  final VoidCallback onTap;

  String get _shortDescription {
    final String gameName = product.gameName.trim().isNotEmpty
        ? product.gameName.trim()
        : product.title.replaceAll('Rozeti', '').trim();

    return '$gameName severlere özel.';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    const Color accent = Color(0xffC98A2E);
    const Color ownedColor = Color(0xff159447);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.50),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                blurRadius: 14,
                offset: const Offset(0, 5),
                color: colors.shadow.withValues(alpha: 0.045),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            child: Row(
              children: <Widget>[
                _GameBadgeEmblem(
                  emoji: product.emoji,
                  imageUrl: product.imageUrl,
                  gameName: product.gameName,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        product.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _shortDescription,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    if (owned)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: ownedColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: ownedColor,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Sahipsin',
                              style: TextStyle(
                                color: ownedColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          price,
                          style: const TextStyle(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.outlineVariant
                              .withValues(alpha: 0.50),
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 17,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameBadgeEmblem extends StatelessWidget {
  const _GameBadgeEmblem({
    required this.emoji,
    required this.imageUrl,
    required this.gameName,
  });

  final String emoji;
  final String imageUrl;
  final String gameName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: <Color>[
            Color(0xff2B2B2B),
            Color(0xff141414),
          ],
        ),
        border: Border.all(
          width: 2,
          color: const Color(0xffC98A2E),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 5),
            color: const Color(0xffC98A2E)
                .withValues(alpha: 0.16),
          ),
        ],
      ),
      child: Container(
        width: 54,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xffE1B86C)
                .withValues(alpha: 0.55),
          ),
        ),
        child: imageUrl.isNotEmpty
            ? ClipOval(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Text(
                emoji.isEmpty ? '🏅' : emoji,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
        )
            : Text(
          emoji.isEmpty ? '🏅' : emoji,
          style: const TextStyle(fontSize: 28),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(
          icon,
          size: 19,
          color: const Color(0xffFF9800),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentInfoRow extends StatelessWidget {
  const _PaymentInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.workspace_premium_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 14),
          Text(
            'Rozet bulunamadı',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Aktif oyun rozetleri burada gösterilecek.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline_rounded, size: 54),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}
