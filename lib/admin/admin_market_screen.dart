import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../services/digital_purchase_service.dart';
import 'admin_gift_operations_screen.dart';
import 'admin_market_campaigns_screen.dart';
import 'admin_market_orders_screen.dart';

String _adminMarketText(
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

class AdminMarketScreen extends StatefulWidget {
  const AdminMarketScreen({super.key});

  @override
  State<AdminMarketScreen> createState() => _AdminMarketScreenState();
}

class _AdminMarketScreenState extends State<AdminMarketScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  String _selectedFilter = 'all';
  bool _seedingBadges = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> get _productsCollection {
    return FirebaseFirestore.instance.collection('marketProducts');
  }

  Future<void> _seedBadgeProducts() async {
    if (_seedingBadges) {
      return;
    }

    setState(() {
      _seedingBadges = true;
    });

    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('seedBadgeProducts');

      final HttpsCallableResult<dynamic> result = await callable.call();

      if (!mounted) {
        return;
      }

      final dynamic rawCount =
          (result.data as Map<Object?, Object?>?)?['createdOrUpdatedCount'];

      final int count = rawCount is num ? rawCount.toInt() : 0;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('$count oyun rozeti oluşturuldu veya güncellendi.'),
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
            content: Text(error.message ?? 'Rozet ürünleri oluşturulamadı.'),
          ),
        );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Rozet ürünleri oluşturulamadı: $error')),
        );
    } finally {
      if (mounted) {
        setState(() {
          _seedingBadges = false;
        });
      }
    }
  }

  Future<void> _openProductEditor({
    QueryDocumentSnapshot<Map<String, dynamic>>? document,
  }) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return _AdminMarketProductEditorScreen(
            productId: document?.id,
            initialData: document?.data(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _adminMarketText(
            context,
            tr: 'Market Yönetimi',
            en: 'Market Management',
            de: 'Marktverwaltung',
          ),
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: _adminMarketText(
              context,
              tr: 'Oyun rozetlerini oluştur',
              en: 'Create game badges',
              de: 'Spielabzeichen erstellen',
            ),
            onPressed: _seedingBadges ? null : _seedBadgeProducts,
            icon: _seedingBadges
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined),
          ),
          IconButton(
            tooltip: _adminMarketText(
              context,
              tr: 'Siparişler',
              en: 'Orders',
              de: 'Bestellungen',
            ),
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (BuildContext context) {
                    return const AdminMarketOrdersScreen();
                  },
                ),
              );
            },
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          IconButton(
            tooltip: _adminMarketText(
              context,
              tr: 'Yeni ürün',
              en: 'New product',
              de: 'Neues Produkt',
            ),
            onPressed: _openProductEditor,
            icon: const Icon(Icons.add_business_outlined),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _productsCollection
            .orderBy('createdAt', descending: true)
            .snapshots(),
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
                      'Market ürünleri yüklenirken bir hata oluştu.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final List<QueryDocumentSnapshot<Map<String, dynamic>>>
              allProducts = snapshot.data!.docs;

              final List<QueryDocumentSnapshot<Map<String, dynamic>>>
              visibleProducts = allProducts.where((document) {
                final Map<String, dynamic> data = document.data();

                final bool active = data['active'] == true;
                final String productType =
                    data['productType']?.toString().trim() ?? '';

                switch (_selectedFilter) {
                  case 'active':
                    if (!active) {
                      return false;
                    }
                  case 'inactive':
                    if (active) {
                      return false;
                    }
                  case 'plus':
                    if (productType != 'plus') {
                      return false;
                    }
                  case 'badge':
                    if (productType != 'badge') {
                      return false;
                    }
                  case 'digital':
                    if (productType != 'digital') {
                      return false;
                    }
                  case 'all':
                    break;
                }

                if (_searchText.isEmpty) {
                  return true;
                }

                final String query = _searchText.toLowerCase();

                final String title =
                    data['title']?.toString().toLowerCase() ?? '';

                final String description =
                    data['description']?.toString().toLowerCase() ?? '';

                final String code =
                    data['code']?.toString().toLowerCase() ?? '';

                return title.contains(query) ||
                    description.contains(query) ||
                    code.contains(query) ||
                    document.id.toLowerCase().contains(query);
              }).toList();

              return Column(
                children: <Widget>[
                  const _CanonicalCatalogSummary(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      children: <Widget>[
                        TextButton(
                          onPressed: kMarketCampaignActionsEnabled
                              ? () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const AdminMarketCampaignsScreen(),
                                    ),
                                  );
                                }
                              : null,
                          child: const Text('Kampanyalar'),
                        ),
                        TextButton(
                          onPressed: kMarketCampaignActionsEnabled
                              ? () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const AdminGiftOperationsScreen(),
                                    ),
                                  );
                                }
                              : null,
                          child: const Text('Hediye işlemleri'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: _buildStatistics(allProducts),
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
                        hintText: 'Ürün adı, kod veya açıklama ara',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchText.isEmpty
                            ? null
                            : IconButton(
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
                        _buildFilter(
                          'all',
                          _adminMarketText(
                            context,
                            tr: 'Tümü',
                            en: 'All',
                            de: 'Alle',
                          ),
                        ),
                        _buildFilter('active', 'Aktif'),
                        _buildFilter('inactive', 'Pasif'),
                        _buildFilter('plus', 'Plus'),
                        _buildFilter('badge', 'Rozet'),
                        _buildFilter('digital', 'Dijital'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: visibleProducts.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Bu filtreye uygun market ürünü bulunamadı.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            itemCount: visibleProducts.length,
                            separatorBuilder:
                                (BuildContext context, int index) {
                                  return const SizedBox(height: 10);
                                },
                            itemBuilder: (BuildContext context, int index) {
                              final QueryDocumentSnapshot<Map<String, dynamic>>
                              document = visibleProducts[index];

                              return _buildProductCard(document);
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
    List<QueryDocumentSnapshot<Map<String, dynamic>>> products,
  ) {
    int activeCount = 0;
    int plusCount = 0;
    int badgeCount = 0;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in products) {
      final Map<String, dynamic> data = document.data();

      if (data['active'] == true) {
        activeCount++;
      }

      switch (data['productType']?.toString()) {
        case 'plus':
          plusCount++;
          break;
        case 'badge':
          badgeCount++;
          break;
      }
    }

    return Row(
      children: <Widget>[
        Expanded(
          child: _StatisticCard(
            title: 'Toplam',
            count: products.length,
            icon: Icons.storefront_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatisticCard(
            title: 'Aktif',
            count: activeCount,
            icon: Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatisticCard(
            title: 'Plus',
            count: plusCount,
            icon: Icons.workspace_premium_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatisticCard(
            title: 'Rozet',
            count: badgeCount,
            icon: Icons.military_tech_outlined,
          ),
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

  Widget _buildProductCard(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data();

    final String title = data['title']?.toString().trim() ?? 'İsimsiz ürün';

    final String productType =
        data['productType']?.toString().trim() ?? 'digital';

    final bool active = data['active'] == true;

    final bool allowTlPayment = data['allowTlPayment'] == true;
    final bool allowWalletPayment = data['allowWalletPayment'] == true;
    final bool allowPointPayment = data['allowPointPayment'] == true;

    final int priceKurus = (data['priceKurus'] as num?)?.toInt() ?? 0;

    final double pointPrice = (data['pointPrice'] as num?)?.toDouble() ?? 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _openProductEditor(document: document);
        },
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(radius: 27, child: Icon(_productIcon(productType))),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: <Widget>[
                        _InfoLabel(
                          text: _productTypeTitle(productType),
                          icon: _productIcon(productType),
                        ),
                        _InfoLabel(
                          text: active ? 'Aktif' : 'Pasif',
                          icon: active
                              ? Icons.check_circle_outline
                              : Icons.pause_circle_outline,
                        ),
                        if (allowTlPayment)
                          _InfoLabel(
                            text: _money(priceKurus),
                            icon: Icons.credit_card_outlined,
                          ),
                        if (allowWalletPayment)
                          const _InfoLabel(
                            text: 'Cüzdan',
                            icon: Icons.account_balance_wallet_outlined,
                          ),
                        if (allowPointPayment)
                          _InfoLabel(
                            text: '${_formatPoints(pointPrice)} puan',
                            icon: Icons.stars_outlined,
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    SelectableText(
                      document.id,
                      style: Theme.of(context).textTheme.bodySmall,
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

  static IconData _productIcon(String value) {
    switch (value) {
      case 'plus':
        return Icons.workspace_premium_outlined;
      case 'badge':
        return Icons.military_tech_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  static String _productTypeTitle(String value) {
    switch (value) {
      case 'plus':
        return 'Plus üyelik';
      case 'badge':
        return 'Rozet';
      default:
        return 'Dijital ürün';
    }
  }

  static String _money(int amountKurus) {
    return '${(amountKurus / 100).toStringAsFixed(2)} TL';
  }

  static String _formatPoints(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }
}

class _CanonicalCatalogSummary extends StatelessWidget {
  const _CanonicalCatalogSummary();

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore db = FirebaseFirestore.instance;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('badge_products').snapshots(),
      builder: (context, badges) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection('plus_products').snapshots(),
          builder: (context, plus) {
            final bool loading = !badges.hasData || !plus.hasData;
            final bool failed = badges.hasError || plus.hasError;
            final int badgeCount = badges.data?.docs.length ?? 0;
            final int plusCount = plus.data?.docs.length ?? 0;
            final int mapped =
                badges.data?.docs.where((document) {
                  final data = document.data();
                  return (data['googlePlayProductId']?.toString().trim() ?? '')
                      .isNotEmpty;
                }).length ??
                0;
            return Card(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: failed
                    ? const Text(
                        'Kanonik katalog okunamadı; bu durum 0 ürün değildir.',
                      )
                    : loading
                    ? const LinearProgressIndicator()
                    : Row(
                        children: <Widget>[
                          Expanded(child: Text('Kişisel ürünler: $badgeCount')),
                          Expanded(child: Text('Plus: $plusCount')),
                          Expanded(
                            child: Text(
                              'Play eşlemesi: $mapped/$badgeCount\n'
                              'Satış durumu: doğrulanmadı',
                            ),
                          ),
                        ],
                      ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AdminMarketProductEditorScreen extends StatefulWidget {
  const _AdminMarketProductEditorScreen({
    required this.productId,
    required this.initialData,
  });

  final String? productId;
  final Map<String, dynamic>? initialData;

  @override
  State<_AdminMarketProductEditorScreen> createState() =>
      _AdminMarketProductEditorScreenState();
}

class _AdminMarketProductEditorScreenState
    extends State<_AdminMarketProductEditorScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _pointPriceController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  String _productType = 'digital';

  bool _active = true;
  bool _allowTlPayment = true;
  bool _allowWalletPayment = true;
  bool _allowPointPayment = false;
  bool _saving = false;

  bool get _isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();

    final Map<String, dynamic>? data = widget.initialData;

    if (data == null) {
      return;
    }

    _titleController.text = data['title']?.toString() ?? '';
    _codeController.text = data['code']?.toString() ?? '';
    _descriptionController.text = data['description']?.toString() ?? '';

    _priceController.text = (((data['priceKurus'] as num?)?.toInt() ?? 0) / 100)
        .toStringAsFixed(2);

    _pointPriceController.text = ((data['pointPrice'] as num?)?.toDouble() ?? 0)
        .toString();

    _durationController.text = ((data['durationDays'] as num?)?.toInt() ?? 0)
        .toString();

    _productType = data['productType']?.toString() ?? 'digital';

    _active = data['active'] == true;
    _allowTlPayment = data['allowTlPayment'] == true;
    _allowWalletPayment = data['allowWalletPayment'] == true;
    _allowPointPayment = data['allowPointPayment'] == true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _pointPriceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    final String title = _titleController.text.trim();
    final String code = _codeController.text.trim().toLowerCase();
    final String description = _descriptionController.text.trim();

    final double price =
        double.tryParse(_priceController.text.trim().replaceAll(',', '.')) ?? 0;

    final double pointPrice =
        double.tryParse(
          _pointPriceController.text.trim().replaceAll(',', '.'),
        ) ??
        0;

    final int durationDays = int.tryParse(_durationController.text.trim()) ?? 0;

    if (title.length < 2) {
      _showMessage('Ürün adını yaz.');
      return;
    }

    if (code.length < 2) {
      _showMessage('Ürün kodunu yaz.');
      return;
    }

    if (!_allowTlPayment && !_allowWalletPayment && !_allowPointPayment) {
      _showMessage('En az bir ödeme yöntemi seç.');
      return;
    }

    if ((_allowTlPayment || _allowWalletPayment) && price <= 0) {
      _showMessage('Geçerli TL fiyatı gir.');
      return;
    }

    if (_allowPointPayment && pointPrice <= 0) {
      _showMessage('Geçerli puan fiyatı gir.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('adminSaveMarketProduct');

      await callable.call(<String, dynamic>{
        if (widget.productId != null) 'productId': widget.productId,
        'title': title,
        'code': code,
        'description': description,
        'productType': _productType,
        'active': _active,
        'allowTlPayment': _allowTlPayment,
        'allowWalletPayment': _allowWalletPayment,
        'allowPointPayment': _allowPointPayment,
        'priceKurus': (price * 100).round(),
        'pointPrice': pointPrice,
        'durationDays': durationDays,
      });

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } on FirebaseFunctionsException catch (error) {
      _showMessage(error.message ?? 'Ürün kaydedilemedi.');
    } catch (error) {
      _showMessage('Ürün kaydedilemedi: $error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _delete() async {
    if (!_isEditing || _saving) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            _adminMarketText(
              context,
              tr: 'Ürünü Sil',
              en: 'Delete Product',
              de: 'Produkt löschen',
            ),
          ),
          content: Text('Bu market ürünü kalıcı olarak silinecek.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(
                _adminMarketText(
                  context,
                  tr: 'Vazgeç',
                  en: 'Cancel',
                  de: 'Abbrechen',
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('adminDeleteMarketProduct');

      await callable.call(<String, dynamic>{'productId': widget.productId});

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } on FirebaseFunctionsException catch (error) {
      _showMessage(error.message ?? 'Ürün silinemedi.');
    } catch (error) {
      _showMessage('Ürün silinemedi: $error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? _adminMarketText(
                  context,
                  tr: 'Market Ürününü Düzenle',
                  en: 'Edit Market Product',
                  de: 'Marktprodukt bearbeiten',
                )
              : _adminMarketText(
                  context,
                  tr: 'Market Ürünü Ekle',
                  en: 'Add Market Product',
                  de: 'Marktprodukt hinzufügen',
                ),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: <Widget>[
          if (_isEditing)
            IconButton(
              tooltip: 'Ürünü sil',
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: _productType,
                    decoration: InputDecoration(
                      labelText: _adminMarketText(
                        context,
                        tr: 'Ürün türü',
                        en: 'Product type',
                        de: 'Produkttyp',
                      ),
                      border: OutlineInputBorder(),
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'plus',
                        child: Text('Plus üyelik'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'badge',
                        child: Text('Rozet'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'digital',
                        child: Text('Dijital ürün'),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (String? value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _productType = value;
                            });
                          },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _titleController,
                    enabled: !_saving,
                    decoration: InputDecoration(
                      labelText: _adminMarketText(
                        context,
                        tr: 'Ürün adı',
                        en: 'Product name',
                        de: 'Produktname',
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _codeController,
                    enabled: !_saving,
                    decoration: InputDecoration(
                      labelText: _adminMarketText(
                        context,
                        tr: 'Ürün kodu',
                        en: 'Product code',
                        de: 'Produktcode',
                      ),
                      hintText: 'Örnek: plus_monthly',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _descriptionController,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: _adminMarketText(
                        context,
                        tr: 'Açıklama',
                        en: 'Description',
                        de: 'Beschreibung',
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _adminMarketText(
                        context,
                        tr: 'Ürün aktif',
                        en: 'Product active',
                        de: 'Produkt aktiv',
                      ),
                    ),
                    value: _active,
                    onChanged: _saving
                        ? null
                        : (bool value) {
                            setState(() {
                              _active = value;
                            });
                          },
                  ),
                  const Divider(height: 26),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Online ödeme ile alınabilir'),
                    value: _allowTlPayment,
                    onChanged: _saving
                        ? null
                        : (bool value) {
                            setState(() {
                              _allowTlPayment = value;
                            });
                          },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Cüzdan bakiyesi ile alınabilir'),
                    value: _allowWalletPayment,
                    onChanged: _saving
                        ? null
                        : (bool value) {
                            setState(() {
                              _allowWalletPayment = value;
                            });
                          },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Puan ile alınabilir'),
                    value: _allowPointPayment,
                    onChanged: _saving
                        ? null
                        : (bool value) {
                            setState(() {
                              _allowPointPayment = value;
                            });
                          },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _priceController,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'TL fiyatı',
                      suffixText: 'TL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _pointPriceController,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Puan fiyatı',
                      suffixText: 'puan',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _durationController,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Süre',
                      hintText: 'Kalıcı ürün için 0',
                      suffixText: 'gün',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          _saving
                              ? 'Kaydediliyor...'
                              : _adminMarketText(
                                  context,
                                  tr: 'Ürünü Kaydet',
                                  en: 'Save Product',
                                  de: 'Produkt speichern',
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatisticCard extends StatelessWidget {
  const _StatisticCard({
    required this.title,
    required this.count,
    required this.icon,
  });

  final String title;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 12),
        child: Column(
          children: <Widget>[
            Icon(icon),
            const SizedBox(height: 5),
            Text(
              '$count',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            Text(
              title,
              maxLines: 1,
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
