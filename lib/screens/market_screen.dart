import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/badge_product_model.dart';
import '../models/plus_product_model.dart';
import '../services/market_service.dart';
import '../services/plus_entitlement.dart';
import '../services/plus_service.dart';
import '../services/plus_subscription_offer.dart';
import '../services/digital_purchase_service.dart';
import '../widgets/game_badge_emblem.dart';
import 'legal_document_screen.dart';
import 'user_search_screen.dart';

String _marketText(
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

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final MarketService _marketService = MarketService();
  final PlusService _plusService = PlusService();
  final DigitalPurchaseService _digitalPurchaseService =
      DigitalPurchaseService.instance;

  String _searchText = '';
  String _selectedFilter = 'all';
  bool _purchaseBusy = false;
  bool _playPriceRequestInFlight = false;
  final Map<String, String> _playPrices = <String, String>{};
  final Set<String> _unavailablePlayPriceIds = <String>{};
  final Map<String, PlusSubscriptionSelection> _plusQuotes =
      <String, PlusSubscriptionSelection>{};
  final Map<String, String> _plusQuoteErrors = <String, String>{};
  final Set<String> _plusQuotesLoading = <String>{};
  final ValueNotifier<int> _plusQuotesVersion = ValueNotifier<int>(0);

  @override
  void dispose() {
    _plusQuotesVersion.dispose();
    super.dispose();
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

  String _displayPrice({
    required String googlePlayProductId,
    required int priceKurus,
  }) {
    final String storeId = googlePlayProductId.trim();
    final String? playPrice = _playPrices[storeId];

    if (playPrice != null && playPrice.isNotEmpty) {
      return playPrice;
    }

    return _money(priceKurus);
  }

  String _plusQuoteKey(PlusProductModel product) {
    return '${product.id}|${product.googlePlayProductId.trim()}|'
        '${product.googlePlayBasePlanId.trim()}';
  }

  String? _plusBlockedReason(PlusProductModel product, String quoteKey) {
    if (product.googlePlayProductId.trim().isEmpty) {
      return 'Google Play eşlemesi bekleniyor';
    }

    if (product.googlePlayBasePlanId.trim().isEmpty) {
      return 'Base plan eşlemesi bekleniyor';
    }

    final String? error = _plusQuoteErrors[quoteKey];

    if (error != null && error.isNotEmpty) {
      return error;
    }

    if (_plusQuotes[quoteKey] == null) {
      return 'Google Play fiyatı yükleniyor';
    }

    return null;
  }

  void _requestPlusQuotes(List<PlusProductModel> products) {
    final List<PlusProductModel> pending = <PlusProductModel>[];

    for (final PlusProductModel product in products) {
      if (product.googlePlayProductId.trim().isEmpty ||
          product.googlePlayBasePlanId.trim().isEmpty) {
        continue;
      }

      final String key = _plusQuoteKey(product);

      if (_plusQuotes.containsKey(key) ||
          _plusQuoteErrors.containsKey(key) ||
          _plusQuotesLoading.contains(key)) {
        continue;
      }

      _plusQuotesLoading.add(key);
      pending.add(product);
    }

    if (pending.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final PlusProductModel product in pending) {
        final String key = _plusQuoteKey(product);

        try {
          final PlusSubscriptionSelection selection =
              await _digitalPurchaseService.loadPlusSelection(
                googlePlayProductId: product.googlePlayProductId,
                googlePlayBasePlanId: product.googlePlayBasePlanId,
              );

          if (!mounted) {
            return;
          }

          setState(() {
            _plusQuotes[key] = selection;
            _plusQuoteErrors.remove(key);
            _plusQuotesLoading.remove(key);
          });
        } on PlusSubscriptionOfferException catch (error) {
          if (!mounted) {
            return;
          }

          setState(() {
            _plusQuoteErrors[key] = error.message;
            _plusQuotesLoading.remove(key);
          });
        } catch (error) {
          if (!mounted) {
            return;
          }

          setState(() {
            _plusQuoteErrors[key] =
                'Google Play fiyatı alınamadı. Satın alma kapatıldı.';
            _plusQuotesLoading.remove(key);
          });
        }

        _plusQuotesVersion.value++;
      }
    });
  }

  void _requestPlayPrices(Iterable<String> rawIds) {
    final Set<String> ids = rawIds
        .map((String id) => id.trim())
        .where(
          (String id) =>
              id.isNotEmpty &&
              !_playPrices.containsKey(id) &&
              !_unavailablePlayPriceIds.contains(id),
        )
        .toSet();

    if (ids.isEmpty || _playPriceRequestInFlight) {
      return;
    }

    _playPriceRequestInFlight = true;
    final Set<String> requested = Set<String>.of(ids);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      final Map<String, String> loaded = await _digitalPurchaseService
          .loadLocalizedPrices(requested);

      if (!mounted) {
        return;
      }

      setState(() {
        for (final String id in requested) {
          final String price = loaded[id]?.trim() ?? '';

          if (price.isEmpty) {
            _unavailablePlayPriceIds.add(id);
          } else {
            _playPrices[id] = price;
          }
        }

        _playPriceRequestInFlight = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        body: Center(
          child: Text(
            _marketText(
              context,
              tr: 'Market için giriş yapmalısın.',
              en: 'You must sign in to use the store.',
              de: 'Du musst dich anmelden, um den Store zu nutzen.',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dört. Store',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.4),
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
      body: StreamBuilder<Set<String>>(
        stream: _marketService.watchOwnedBadgeIds(uid),
        builder: (context, ownedSnapshot) {
          final Set<String> ownedBadgeIds = ownedSnapshot.data ?? <String>{};

          return StreamBuilder<List<BadgeProductModel>>(
            stream: _marketService.watchActiveBadgeProducts(),
            builder: (context, productSnapshot) {
              if (productSnapshot.hasError) {
                return _ErrorState(
                  message: _marketText(
                    context,
                    tr: 'Ürünler yüklenemedi.',
                    en: 'Products could not be loaded.',
                    de: 'Produkte konnten nicht geladen werden.',
                  ),
                  onRetry: () => setState(() {}),
                );
              }

              if (productSnapshot.connectionState == ConnectionState.waiting &&
                  !productSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final List<BadgeProductModel> catalog =
                  productSnapshot.data ?? const <BadgeProductModel>[];
              _requestPlayPrices(
                catalog.map(
                  (BadgeProductModel product) => product.googlePlayProductId,
                ),
              );

              final List<BadgeProductModel> products = catalog.where((product) {
                final bool searchMatches =
                    _searchText.isEmpty ||
                    product.title.toLowerCase().contains(_searchText) ||
                    product.gameName.toLowerCase().contains(_searchText);

                final bool owned = ownedBadgeIds.contains(product.id);

                final bool filterMatches =
                    _selectedFilter == 'all' ||
                    (_selectedFilter == 'owned' && owned) ||
                    (_selectedFilter == 'available' && !owned);

                return searchMatches && filterMatches;
              }).toList();

              return RefreshIndicator(
                color: const Color(0xffFF9800),
                onRefresh: () async {
                  await FirebaseFirestore.instance
                      .collection('badge_products')
                      .limit(1)
                      .get(const GetOptions(source: Source.server));
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: <Widget>[
                    _StoreHeader(ownedCount: ownedBadgeIds.length),
                    const SizedBox(height: 14),
                    StreamBuilder<List<PlusProductModel>>(
                      stream: _plusService.watchActiveProducts(),
                      builder: (context, plusSnapshot) {
                        final List<PlusProductModel> plusProducts =
                            plusSnapshot.data ?? const <PlusProductModel>[];

                        _requestPlusQuotes(plusProducts);

                        return StreamBuilder<
                          DocumentSnapshot<Map<String, dynamic>>
                        >(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .snapshots(),
                          builder: (context, userSnapshot) {
                            final Map<String, dynamic>? userData = userSnapshot
                                .data
                                ?.data();
                            final bool plusActive = PlusEntitlement.isActive(
                              userData,
                            );
                            final String playProductId =
                                userData?['plusGooglePlayProductId']
                                    ?.toString()
                                    .trim() ??
                                '';

                            return _PlusMembershipShowcase(
                              loading:
                                  plusSnapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  !plusSnapshot.hasData,
                              enabled: plusProducts.isNotEmpty || plusActive,
                              plusActive: plusActive,
                              onTap: plusProducts.isEmpty && !plusActive
                                  ? null
                                  : () {
                                      _showPlusProducts(
                                        products: plusProducts,
                                        plusActive: plusActive,
                                        playProductId: playProductId,
                                      );
                                    },
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      onChanged: (value) {
                        setState(() {
                          _searchText = value.trim().toLowerCase();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Oyun rozeti ara',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
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
                            label: _marketText(
                              context,
                              tr: 'Tümü',
                              en: 'All',
                              de: 'Alle',
                            ),
                            icon: Icons.grid_view_rounded,
                          ),
                          const SizedBox(width: 8),
                          _filterChip(
                            value: 'available',
                            label: _marketText(
                              context,
                              tr: 'Satın Alınabilir',
                              en: 'Available',
                              de: 'Verfügbar',
                            ),
                            icon: Icons.shopping_bag_outlined,
                          ),
                          const SizedBox(width: 8),
                          _filterChip(
                            value: 'owned',
                            label: 'Rozetlerim',
                            icon: Icons.workspace_premium_outlined,
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
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(
                          '${products.length} ürün',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (products.isEmpty)
                      const _EmptyState()
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final int crossAxisCount = constraints.maxWidth >= 760
                              ? 2
                              : 1;

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: products.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: constraints.maxWidth >= 760
                                      ? 3.05
                                      : 3.15,
                                ),
                            itemBuilder: (context, index) {
                              final BadgeProductModel product = products[index];
                              final bool owned = ownedBadgeIds.contains(
                                product.id,
                              );

                              return _BadgeProductCard(
                                product: product,
                                owned: owned,
                                price: _displayPrice(
                                  googlePlayProductId:
                                      product.googlePlayProductId,
                                  priceKurus: product.priceKurus,
                                ),
                                onTap: () {
                                  _showProductPreview(
                                    product: product,
                                    owned: owned,
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
          builder: (BuildContext context, ScrollController scrollController) {
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
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description.isEmpty
                        ? _marketText(
                            context,
                            tr: 'Bu rozet profilinde görünür.',
                            en: 'This badge is visible on your profile.',
                            de: 'Dieses Abzeichen ist in deinem Profil sichtbar.',
                          )
                        : product.description,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: <Widget>[
                        _BenefitRow(
                          icon: Icons.visibility_outlined,
                          text: _marketText(
                            context,
                            tr: 'Profilinde herkese görünür',
                            en: 'Visible to everyone on your profile',
                            de: 'Für alle in deinem Profil sichtbar',
                          ),
                        ),
                        SizedBox(height: 9),
                        _BenefitRow(
                          icon: Icons.lock_outline_rounded,
                          text: _marketText(
                            context,
                            tr: 'Tek seferlik dijital üründür',
                            en: 'One-time digital product',
                            de: 'Einmaliges digitales Produkt',
                          ),
                        ),
                        SizedBox(height: 9),
                        _BenefitRow(
                          icon: Icons.workspace_premium_outlined,
                          text: _marketText(
                            context,
                            tr: 'Oyun kimliğini öne çıkarır',
                            en: 'Highlights your gaming identity',
                            de: 'Hebt deine Spielidentität hervor',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _PaymentInfoRow(
                    label: _marketText(
                      context,
                      tr: 'Ürün fiyatı',
                      en: 'Product price',
                      de: 'Produktpreis',
                    ),
                    value: _displayPrice(
                      googlePlayProductId: product.googlePlayProductId,
                      priceKurus: product.priceKurus,
                    ),
                  ),
                  _PaymentInfoRow(
                    label: _marketText(
                      context,
                      tr: 'Ödeme',
                      en: 'Payment',
                      de: 'Zahlung',
                    ),
                    value: 'Google Play',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _marketText(
                      context,
                      tr: 'Ödeme ve iade Google Play üzerinden yürür.',
                      en: 'Payment and refunds run through Google Play.',
                      de: 'Zahlung und Erstattung laufen über Google Play.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  _LegalTextLink(
                    label: _marketText(
                      context,
                      tr: 'Dijital Ürün Koşulları',
                      en: 'Digital Product Terms',
                      de: 'Digitale Produkte',
                    ),
                    onTap: () => _openLegalDocument('digital_products'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed:
                        owned ||
                            _purchaseBusy ||
                            product.googlePlayProductId.isEmpty
                        ? null
                        : () async {
                            Navigator.of(sheetContext).pop();

                            await _purchaseBadge(product);
                          },
                    icon: _purchaseBusy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            owned
                                ? Icons.check_circle_outline
                                : Icons.shopping_bag_outlined,
                          ),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        owned
                            ? 'Bu rozete sahipsin'
                            : product.googlePlayProductId.isEmpty
                            ? _marketText(
                                context,
                                tr: 'Google Play eşlemesi bekleniyor',
                                en: 'Waiting for Google Play mapping',
                                de: 'Google-Play-Zuordnung ausstehend',
                              )
                            : _purchaseBusy
                            ? _marketText(
                                context,
                                tr: 'İşleniyor...',
                                en: 'Processing...',
                                de: 'Wird verarbeitet...',
                              )
                            : _marketText(
                                context,
                                tr: 'Google Play ile satın al',
                                en: 'Buy with Google Play',
                                de: 'Mit Google Play kaufen',
                              ),
                      ),
                    ),
                  ),
                  if (!owned &&
                      product.googlePlayProductId.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _purchaseBusy
                          ? null
                          : () async {
                              final String? recipientUid =
                                  await Navigator.push<String>(
                                    sheetContext,
                                    MaterialPageRoute<String>(
                                      builder: (_) => const UserSearchScreen(
                                        selectRecipient: true,
                                      ),
                                    ),
                                  );
                              if (recipientUid == null ||
                                  recipientUid.isEmpty) {
                                return;
                              }
                              if (!sheetContext.mounted) {
                                return;
                              }
                              Navigator.of(sheetContext).pop();
                              await _purchaseBadge(
                                product,
                                recipientUid: recipientUid,
                              );
                            },
                      icon: const Icon(Icons.card_giftcard_outlined),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          _marketText(
                            context,
                            tr: 'Hediye gönder',
                            en: 'Send as a gift',
                            de: 'Als Geschenk senden',
                          ),
                        ),
                      ),
                    ),
                  ],
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
    String? recipientUid,
  }) async {
    if (_purchaseBusy) return;

    setState(() {
      _purchaseBusy = true;
    });

    try {
      await _digitalPurchaseService.purchase(
        googlePlayProductId: product.googlePlayProductId,
        kind: DigitalStoreProductKind.badgeNonConsumable,
        internalProductId: product.id,
        recipientUid: recipientUid,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              recipientUid == null
                  ? '${product.title} başarıyla satın alındı.'
                  : '${product.title} hediye olarak gönderildi.',
            ),
          ),
        );
    } on DigitalPurchaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Satın alma işlemi tamamlanamadı: $error')),
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
    required bool plusActive,
    required String playProductId,
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
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                plusActive
                    ? _marketText(
                        context,
                        tr: 'Plus üyeliğin aktif',
                        en: 'Your Plus membership is active',
                        de: 'Deine Plus-Mitgliedschaft ist aktiv',
                      )
                    : _marketText(
                        context,
                        tr: 'Sana uygun Plus paketini seç.',
                        en: 'Choose the Plus plan that suits you.',
                        de: 'Wähle das passende Plus-Paket.',
                      ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (plusActive)
                FilledButton.icon(
                  onPressed: () => _openSubscriptionManagement(playProductId),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(
                    _marketText(
                      context,
                      tr: 'Aboneliği yönet',
                      en: 'Manage subscription',
                      de: 'Abonnement verwalten',
                    ),
                  ),
                )
              else
                ListenableBuilder(
                  listenable: _plusQuotesVersion,
                  builder: (context, _) {
                    return Column(
                      children: products.map((PlusProductModel product) {
                        final String quoteKey = _plusQuoteKey(product);
                        final PlusSubscriptionSelection? quote =
                            _plusQuotes[quoteKey];
                        final String? blockedReason = _plusBlockedReason(
                          product,
                          quoteKey,
                        );

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PlusProductCard(
                            product: product,
                            price: quote?.formattedPrice ?? '',
                            periodLabel: quote?.periodLabel ?? '',
                            blockedReason: blockedReason,
                            onTap: _purchaseBusy || quote == null
                                ? null
                                : () async {
                                    Navigator.of(sheetContext).pop();
                                    await _purchasePlus(product, quote);
                                  },
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: _purchaseBusy
                    ? null
                    : () async {
                        Navigator.of(sheetContext).pop();
                        await _restoreDigitalPurchases();
                      },
                icon: const Icon(Icons.restore_rounded),
                label: Text(
                  _marketText(
                    context,
                    tr: 'Google Play satın alımlarını geri yükle',
                    en: 'Restore Google Play purchases',
                    de: 'Google-Play-Käufe wiederherstellen',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _marketText(
                  context,
                  tr: 'Ücret, bu ekranda görünen Google Play fiyatıdır. Abonelik seçilen döneme göre yenilenebilir.',
                  en: 'The price is the Google Play price shown here. The subscription may renew for the selected period.',
                  de: 'Der Preis ist der hier angezeigte Google-Play-Preis. Das Abonnement kann für den gewählten Zeitraum verlängert werden.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              _LegalTextLink(
                label: _marketText(
                  context,
                  tr: 'Plus Abonelik Koşulları',
                  en: 'Plus Subscription Terms',
                  de: 'Plus-Abonnementbedingungen',
                ),
                onTap: () => _openLegalDocument('plus_subscription'),
              ),
              _LegalTextLink(
                label: _marketText(
                  context,
                  tr: 'Otomatik Yenileme',
                  en: 'Automatic Renewal',
                  de: 'Automatische Verlängerung',
                ),
                onTap: () => _openLegalDocument('automatic_renewal'),
              ),
              const SizedBox(height: 8),
              const _PlusBenefitsCard(),
            ],
          ),
        );
      },
    );
  }

  Future<void> _restoreDigitalPurchases() async {
    if (_purchaseBusy) {
      return;
    }

    setState(() {
      _purchaseBusy = true;
    });

    try {
      await _digitalPurchaseService.restorePurchases();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _marketText(
                    context,
                    tr: 'Google Play satın alımları kontrol ediliyor. ',
                    en: 'Google Play purchases are being checked. ',
                    de: 'Google-Play-Käufe werden geprüft. ',
                  ) +
                  _marketText(
                    context,
                    tr: 'Doğrulanan haklar hesabına otomatik yansıyacak.',
                    en: 'Verified entitlements will be added to your account automatically.',
                    de: 'Verifizierte Berechtigungen werden deinem Konto automatisch hinzugefügt.',
                  ),
            ),
          ),
        );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Satın alımlar geri yüklenemedi: $error')),
        );
    } finally {
      if (mounted) {
        setState(() {
          _purchaseBusy = false;
        });
      }
    }
  }

  Future<void> _openSubscriptionManagement(String playProductId) async {
    final String sku = playProductId.trim();
    final Uri uri = sku.isEmpty
        ? Uri.parse('https://play.google.com/store/account/subscriptions')
        : Uri.https('play.google.com', '/store/account/subscriptions', {
            'sku': sku,
            'package': 'com.dortapp.dort',
          });

    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      final bool fallbackOpened = await launchUrl(
        Uri.parse('https://play.google.com/store/account/subscriptions'),
        mode: LaunchMode.externalApplication,
      );
      if (!fallbackOpened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _marketText(
                context,
                tr: 'Google Play abonelik sayfası açılamadı.',
                en: 'The Google Play subscriptions page could not be opened.',
                de: 'Die Google-Play-Abonnementseite konnte nicht geöffnet werden.',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _purchasePlus(
    PlusProductModel product,
    PlusSubscriptionSelection displayedOffer,
  ) async {
    if (_purchaseBusy) {
      return;
    }

    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final DocumentSnapshot<Map<String, dynamic>> userSnapshot =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (PlusEntitlement.isActive(userSnapshot.data())) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _marketText(
                context,
                tr: 'Plus üyeliğin aktif',
                en: 'Your Plus membership is active',
                de: 'Deine Plus-Mitgliedschaft ist aktiv',
              ),
            ),
          ),
        );
        return;
      }
    }

    setState(() {
      _purchaseBusy = true;
    });

    try {
      final DigitalPurchaseResult result = await _digitalPurchaseService
          .purchase(
            googlePlayProductId: product.googlePlayProductId,
            googlePlayBasePlanId: product.googlePlayBasePlanId,
            plusSelection: displayedOffer,
            kind: DigitalStoreProductKind.plusSubscription,
            internalProductId: product.id,
          );

      if (!mounted) {
        return;
      }

      final DateTime? expiry = result.plusExpiresAt;

      final String expiryText = expiry == null
          ? _marketText(
              context,
              tr: 'Google Play hesabındaki abonelik süresi',
              en: 'your Google Play subscription period',
              de: 'deine Google-Play-Abonnementlaufzeit',
            )
          : '${expiry.day.toString().padLeft(2, '0')}.'
                '${expiry.month.toString().padLeft(2, '0')}.'
                '${expiry.year}';

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${product.title} aktif edildi. Bitiş: $expiryText'),
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
                  _marketText(
                    context,
                    tr: 'Plus satın alma işlemi tamamlanamadı.',
                    en: 'Plus purchase could not be completed.',
                    de: 'Der Plus-Kauf konnte nicht abgeschlossen werden.',
                  ),
            ),
          ),
        );
    } on DigitalPurchaseException catch (error) {
      if (!mounted) {
        return;
      }

      if (error.code == 'offer_changed') {
        final String key = _plusQuoteKey(product);
        setState(() {
          _plusQuotes.remove(key);
          _plusQuoteErrors.remove(key);
          _plusQuotesLoading.remove(key);
        });
        _plusQuotesVersion.value++;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Plus satın alma işlemi tamamlanamadı: $error'),
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

  void _openLegalDocument(String documentCode) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(documentCode: documentCode),
      ),
    );
  }
}

class _LegalTextLink extends StatelessWidget {
  const _LegalTextLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.centerLeft,
        ),
        child: Text(label),
      ),
    );
  }
}

class _PlusMembershipShowcase extends StatelessWidget {
  const _PlusMembershipShowcase({
    required this.loading,
    required this.enabled,
    required this.plusActive,
    required this.onTap,
  });

  final bool loading;
  final bool enabled;
  final bool plusActive;
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
                    colors: <Color>[Color(0xffFFB74D), Color(0xffF57C00)],
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
              Expanded(
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
                        _PlusActiveLabel(activeMembership: plusActive),
                      ],
                    ),
                    SizedBox(height: 5),
                    Text(
                      plusActive
                          ? _marketText(
                              context,
                              tr: 'Plus üyeliğin aktif',
                              en: 'Your Plus membership is active',
                              de: 'Deine Plus-Mitgliedschaft ist aktiv',
                            )
                          : _marketText(
                              context,
                              tr: '1 veya 3 aylık paketi seç, ayrıcalıkları hemen kullan.',
                              en: 'Choose a 1 or 3 month plan and use the benefits immediately.',
                              de: 'Wähle ein 1- oder 3-Monats-Paket und nutze die Vorteile sofort.',
                            ),
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
  const _PlusActiveLabel({required this.activeMembership});

  final bool activeMembership;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xffFF9800).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        activeMembership
            ? _marketText(context, tr: 'AKTİF', en: 'ACTIVE', de: 'AKTIV')
            : _marketText(
                context,
                tr: 'SATIŞTA',
                en: 'AVAILABLE',
                de: 'VERFÜGBAR',
              ),
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
    required this.periodLabel,
    required this.blockedReason,
    required this.onTap,
  });

  final PlusProductModel product;
  final String price;
  final String periodLabel;
  final String? blockedReason;
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
        side: BorderSide(color: colors.outlineVariant),
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
                      blockedReason ?? periodLabel,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    blockedReason == null ? price : '—',
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: <Widget>[
          _BenefitRow(
            icon: Icons.event_available_outlined,
            text: 'Etkinlikleri ileri tarihe planla',
          ),
          SizedBox(height: 10),
          _BenefitRow(
            icon: Icons.groups_outlined,
            text: _marketText(
              context,
              tr: 'Birden fazla oyuncu için etkinlik oluştur',
              en: 'Create events for multiple players',
              de: 'Erstelle Veranstaltungen für mehrere Spieler',
            ),
          ),
          SizedBox(height: 10),
          _BenefitRow(
            icon: Icons.workspace_premium_outlined,
            text: _marketText(
              context,
              tr: 'Profilinde Plus ayrıcalığını göster',
              en: 'Show your Plus benefit on your profile',
              de: 'Zeige deinen Plus-Vorteil im Profil',
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.ownedCount});

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
                  Expanded(
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
                          _marketText(
                            context,
                            tr: 'Rozetlerini topla, profilini kişiselleştir',
                            en: 'Collect badges and personalize your profile',
                            de: 'Sammle Abzeichen und personalisiere dein Profil',
                          ),
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
            ],
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: <Widget>[
                GameBadgeEmblem(
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
                          color: colors.outlineVariant.withValues(alpha: 0.50),
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

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 19, color: const Color(0xffFF9800)),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _PaymentInfoRow extends StatelessWidget {
  const _PaymentInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
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
            _marketText(
              context,
              tr: 'Rozet bulunamadı',
              en: 'No badges found',
              de: 'Keine Abzeichen gefunden',
            ),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            _marketText(
              context,
              tr: 'Aktif oyun rozetleri burada gösterilecek.',
              en: 'Active game badges will appear here.',
              de: 'Aktive Spielabzeichen werden hier angezeigt.',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
            FilledButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
          ],
        ),
      ),
    );
  }
}
