import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'admin_access.dart';
import 'admin_ui.dart';

class _PlayMappingEdit {
  const _PlayMappingEdit({
    required this.playId,
    required this.basePlanId,
    required this.giftPlayId,
    required this.purchaseOptionId,
    required this.giftPurchaseOptionId,
    required this.appleProductId,
  });

  final String playId;
  final String basePlanId;
  final String giftPlayId;
  final String purchaseOptionId;
  final String giftPurchaseOptionId;
  final String appleProductId;
}

@visibleForTesting
Map<String, dynamic> buildAppleMappingPayload({
  required String collectionName,
  required String productId,
  required String appleProductId,
}) {
  return <String, dynamic>{
    'collection': collectionName,
    'productId': productId,
    'appleProductId': appleProductId.trim(),
  };
}

@visibleForTesting
Map<String, dynamic> buildPlayMappingPayload({
  required String collectionName,
  required String productId,
  required String googlePlayProductId,
  required String googlePlayBasePlanId,
  required String giftGooglePlayProductId,
  required String googlePlayPurchaseOptionId,
  required String giftGooglePlayPurchaseOptionId,
}) {
  final bool isPlus = collectionName == 'plus_products';
  return <String, dynamic>{
    'collection': collectionName,
    'productId': productId,
    'googlePlayProductId': googlePlayProductId.trim(),
    'giftGooglePlayProductId': giftGooglePlayProductId.trim(),
    'giftGooglePlayPurchaseOptionId': giftGooglePlayPurchaseOptionId.trim(),
    if (isPlus) 'googlePlayBasePlanId': googlePlayBasePlanId.trim(),
    if (!isPlus)
      'googlePlayPurchaseOptionId': googlePlayPurchaseOptionId.trim(),
  };
}

/// Edits `googlePlayProductId` on Plus and badge catalog documents.
class AdminPlayProductMappingScreen extends StatelessWidget {
  const AdminPlayProductMappingScreen({
    this.initialTabIndex = 0,
    this.title = 'Play ürün eşlemesi',
    this.marketMode = false,
    super.key,
  });

  final int initialTabIndex;
  final String title;
  final bool marketMode;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: AdminAccess.currentClaims(forceRefresh: true),
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final bool allowed =
            AdminAccess.hasPermission(
              snapshot.data,
              AdminPermission.financeManage,
            ) ||
            AdminAccess.hasPermission(
              snapshot.data,
              AdminPermission.contentManage,
            );

        if (!allowed) {
          return const Scaffold(
            body: Center(child: Text('Bu sayfaya erişim yetkin yok.')),
          );
        }

        return DefaultTabController(
          length: 2,
          initialIndex: initialTabIndex,
          child: Scaffold(
            appBar: AppBar(
              title: Text(title),
              bottom: const TabBar(
                tabs: <Widget>[
                  Tab(text: 'Plus'),
                  Tab(text: 'Rozetler'),
                ],
              ),
            ),
            body: TabBarView(
              children: <Widget>[
                _CatalogList(
                  collectionName: 'plus_products',
                  showCatalogDetails: marketMode,
                ),
                _CatalogList(
                  collectionName: 'badge_products',
                  showCatalogDetails: marketMode,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CatalogList extends StatelessWidget {
  const _CatalogList({
    required this.collectionName,
    required this.showCatalogDetails,
  });

  final String collectionName;
  final bool showCatalogDetails;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(collectionName).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Katalog yüklenemedi.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data!.docs.toList()..sort((
              QueryDocumentSnapshot<Map<String, dynamic>> a,
              QueryDocumentSnapshot<Map<String, dynamic>> b,
            ) {
              final int left = (a.data()['sortOrder'] as num?)?.toInt() ?? 0;
              final int right = (b.data()['sortOrder'] as num?)?.toInt() ?? 0;
              return left.compareTo(right);
            });
        if (docs.isEmpty) {
          return const Center(child: Text('Katalog kaydı yok.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length + 1,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return AdminPageIntro(
                icon: Icons.link_outlined,
                title: collectionName == 'plus_products'
                    ? adminText(
                        context,
                        tr: 'Plus eşlemeleri',
                        en: 'Plus mappings',
                        de: 'Plus-Zuordnungen',
                      )
                    : adminText(
                        context,
                        tr: 'Rozet eşlemeleri',
                        en: 'Badge mappings',
                        de: 'Abzeichen-Zuordnungen',
                      ),
                description: adminText(
                  context,
                  tr: 'Kişisel satın alma, Plus teklifi ve hediye kimlikleri birbirinden bağımsızdır. Bir alanı boş kaydetmek yalnız o eşlemeyi siler.',
                  en: 'Personal purchase, Plus offer and gift identifiers are independent. Saving an empty field clears only that mapping.',
                  de: 'Persönlicher Kauf, Plus-Angebot und Geschenkkennungen sind unabhängig. Ein leeres Feld löscht nur diese Zuordnung.',
                ),
              );
            }
            final QueryDocumentSnapshot<Map<String, dynamic>> document =
                docs[index - 1];
            final Map<String, dynamic> data = document.data();
            final String playId =
                data['googlePlayProductId']?.toString().trim() ?? '';
            final String giftPlayId =
                data['giftGooglePlayProductId']?.toString().trim() ?? '';
            final String purchaseOptionId =
                data['googlePlayPurchaseOptionId']?.toString().trim() ?? '';
            final String giftPurchaseOptionId =
                data['giftGooglePlayPurchaseOptionId']?.toString().trim() ?? '';
            final String basePlanId = collectionName == 'plus_products'
                ? data['googlePlayBasePlanId']?.toString().trim() ?? ''
                : '';
            final String appleId =
                data['appleProductId']?.toString().trim() ?? '';
            final String title =
                data['title']?.toString().trim().isNotEmpty == true
                ? data['title'].toString().trim()
                : document.id;
            final bool active = data['active'] == true;
            final int priceKurus = (data['priceKurus'] as num?)?.toInt() ?? 0;
            final String category = data['categoryId']?.toString().trim() ?? '';
            final String visual = data['emoji']?.toString().trim() ?? '';
            final bool personalMapped = playId.isNotEmpty;
            final bool giftMapped = giftPlayId.isNotEmpty;
            final bool appleMapped = appleId.isNotEmpty;
            return Card(
              child: ListTile(
                minVerticalPadding: 14,
                leading: CircleAvatar(
                  child: Text(visual.isEmpty ? 'D' : visual),
                ),
                title: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (showCatalogDetails) ...<Widget>[
                      Text(
                        '${active ? "Aktif" : "Pasif"}'
                        '${category.isEmpty ? "" : " · $category"}',
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Katalog referansı: ${(priceKurus / 100).toStringAsFixed(2)} TL · Play fiyatı doğrulaması değildir',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 7),
                    ],
                    Text(
                      'Play: ${personalMapped ? "eşlendi" : "yok"} · '
                      'Hediye: ${giftMapped ? "eşlendi" : "yok"} · '
                      'iOS: ${appleMapped ? "eşlendi" : "yok"}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                trailing: const Icon(Icons.edit_outlined, size: 20),
                onTap: () => _editMapping(
                  context,
                  collectionName: collectionName,
                  productId: document.id,
                  currentPlayId: playId,
                  currentBasePlanId: basePlanId,
                  currentGiftPlayId: giftPlayId,
                  currentPurchaseOptionId: purchaseOptionId,
                  currentGiftPurchaseOptionId: giftPurchaseOptionId,
                  currentAppleProductId: appleId,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

Future<void> _editMapping(
  BuildContext context, {
  required String collectionName,
  required String productId,
  required String currentPlayId,
  required String currentBasePlanId,
  required String currentGiftPlayId,
  required String currentPurchaseOptionId,
  required String currentGiftPurchaseOptionId,
  required String currentAppleProductId,
}) async {
  final bool isPlus = collectionName == 'plus_products';
  final TextEditingController controller = TextEditingController(
    text: currentPlayId,
  );
  final TextEditingController basePlanController = TextEditingController(
    text: currentBasePlanId,
  );
  final TextEditingController giftController = TextEditingController(
    text: currentGiftPlayId,
  );
  final TextEditingController optionController = TextEditingController(
    text: currentPurchaseOptionId,
  );
  final TextEditingController giftOptionController = TextEditingController(
    text: currentGiftPurchaseOptionId,
  );
  final TextEditingController appleController = TextEditingController(
    text: currentAppleProductId,
  );
  final _PlayMappingEdit? next = await showDialog<_PlayMappingEdit>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          adminText(
            dialogContext,
            tr: 'Google Play ürün eşlemesi',
            en: 'Google Play product mapping',
            de: 'Google-Play-Produktzuordnung',
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AdminCopyableId(
                label: adminText(
                  dialogContext,
                  tr: 'Katalog kaydı',
                  en: 'Catalog record',
                  de: 'Katalogeintrag',
                ),
                value: productId,
              ),
              const SizedBox(height: 8),
              AdminSectionCard(
                title: adminText(
                  dialogContext,
                  tr: 'Kişisel satın alma',
                  en: 'Personal purchase',
                  de: 'Persönlicher Kauf',
                ),
                description: adminText(
                  dialogContext,
                  tr: 'Kullanıcının kendisi için aldığı ürün. Hediye ürününden bağımsızdır.',
                  en: 'The product a user buys for themselves. Independent from the gift product.',
                  de: 'Das Produkt für den eigenen Kauf. Unabhängig vom Geschenkprodukt.',
                ),
                icon: Icons.person_outline,
                child: Column(
                  children: <Widget>[
                    TextField(
                      key: const Key('personalPlayProductId'),
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: adminText(
                          dialogContext,
                          tr: 'Play ürün kimliği',
                          en: 'Play product ID',
                          de: 'Play-Produkt-ID',
                        ),
                        helperText: adminText(
                          dialogContext,
                          tr: 'Boş kaydetmek kişisel eşlemeyi siler.',
                          en: 'Saving empty clears the personal mapping.',
                          de: 'Leer speichern löscht die persönliche Zuordnung.',
                        ),
                      ),
                    ),
                    if (isPlus) ...<Widget>[
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('plusBasePlanId'),
                        controller: basePlanController,
                        decoration: const InputDecoration(
                          labelText: 'Plus basePlanId',
                        ),
                      ),
                    ],
                    if (!isPlus) ...<Widget>[
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('personalPurchaseOptionId'),
                        controller: optionController,
                        decoration: InputDecoration(
                          labelText: adminText(
                            dialogContext,
                            tr: 'Satın alma seçeneği',
                            en: 'Purchase option',
                            de: 'Kaufoption',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AdminSectionCard(
                title: adminText(
                  dialogContext,
                  tr: 'Hediye',
                  en: 'Gift',
                  de: 'Geschenk',
                ),
                description: adminText(
                  dialogContext,
                  tr: 'Arkadaşa teslim edilen ayrı tek seferlik ürün. Kişisel ürünü burada kullanma.',
                  en: 'Separate one-time product delivered to a friend. Do not use the personal product here.',
                  de: 'Separates Einmalprodukt für einen Freund. Hier nicht das persönliche Produkt verwenden.',
                ),
                icon: Icons.card_giftcard_outlined,
                child: Column(
                  children: <Widget>[
                    TextField(
                      key: const Key('giftPlayProductId'),
                      controller: giftController,
                      decoration: InputDecoration(
                        labelText: adminText(
                          dialogContext,
                          tr: 'Hediye Play ürün kimliği',
                          en: 'Gift Play product ID',
                          de: 'Geschenk-Play-Produkt-ID',
                        ),
                        helperText: adminText(
                          dialogContext,
                          tr: 'Boş kaydetmek yalnız hediye eşlemesini siler.',
                          en: 'Saving empty clears only the gift mapping.',
                          de: 'Leer speichern löscht nur die Geschenkzuordnung.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('giftPurchaseOptionId'),
                      controller: giftOptionController,
                      decoration: InputDecoration(
                        labelText: adminText(
                          dialogContext,
                          tr: 'Hediye satın alma seçeneği',
                          en: 'Gift purchase option',
                          de: 'Geschenk-Kaufoption',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AdminSectionCard(
                title: adminText(
                  dialogContext,
                  tr: 'App Store (iOS)',
                  en: 'App Store (iOS)',
                  de: 'App Store (iOS)',
                ),
                description: adminText(
                  dialogContext,
                  tr: 'App Store Connect ürün kimliği. Google Play eşlemesini etkilemez.',
                  en: 'App Store Connect product ID. Does not affect Google Play mapping.',
                  de: 'App-Store-Connect-Produkt-ID. Beeinflusst Google Play nicht.',
                ),
                icon: Icons.phone_iphone_outlined,
                child: TextField(
                  key: const Key('appleProductId'),
                  controller: appleController,
                  decoration: InputDecoration(
                    labelText: adminText(
                      dialogContext,
                      tr: 'Apple ürün kimliği',
                      en: 'Apple product ID',
                      de: 'Apple-Produkt-ID',
                    ),
                    helperText: adminText(
                      dialogContext,
                      tr: 'Boş kaydetmek yalnız iOS eşlemesini siler.',
                      en: 'Saving empty clears only the iOS mapping.',
                      de: 'Leer speichern löscht nur die iOS-Zuordnung.',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              _PlayMappingEdit(
                playId: controller.text.trim(),
                basePlanId: basePlanController.text.trim(),
                giftPlayId: giftController.text.trim(),
                purchaseOptionId: optionController.text.trim(),
                giftPurchaseOptionId: giftOptionController.text.trim(),
                appleProductId: appleController.text.trim(),
              ),
            ),
            child: const Text('Kaydet'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  basePlanController.dispose();
  giftController.dispose();
  optionController.dispose();
  giftOptionController.dispose();
  appleController.dispose();

  if (next == null || !context.mounted) {
    return;
  }

  final bool playChanged =
      next.playId != currentPlayId ||
      next.giftPlayId != currentGiftPlayId ||
      next.purchaseOptionId != currentPurchaseOptionId ||
      next.giftPurchaseOptionId != currentGiftPurchaseOptionId ||
      (isPlus && next.basePlanId != currentBasePlanId);
  final bool appleChanged = next.appleProductId != currentAppleProductId;

  if (!playChanged && !appleChanged) {
    return;
  }

  try {
    final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    );
    if (playChanged) {
      final HttpsCallable callable = functions.httpsCallable(
        'adminSetGooglePlayProductId',
      );
      final Map<String, dynamic> payload = buildPlayMappingPayload(
        collectionName: collectionName,
        productId: productId,
        googlePlayProductId: next.playId,
        googlePlayBasePlanId: next.basePlanId,
        giftGooglePlayProductId: next.giftPlayId,
        googlePlayPurchaseOptionId: next.purchaseOptionId,
        giftGooglePlayPurchaseOptionId: next.giftPurchaseOptionId,
      );
      await callable.call<dynamic>(payload);
    }
    if (appleChanged) {
      final HttpsCallable appleCallable = functions.httpsCallable(
        'adminSetAppleProductId',
      );
      await appleCallable.call<dynamic>(
        buildAppleMappingPayload(
          collectionName: collectionName,
          productId: productId,
          appleProductId: next.appleProductId,
        ),
      );
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mağaza ürün eşlemesi kaydedildi.')),
    );
  } on FirebaseFunctionsException catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.message ?? 'Eşleme kaydedilemedi.')),
    );
  }
}
