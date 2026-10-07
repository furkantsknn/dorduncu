import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'admin_access.dart';

class _PlayMappingEdit {
  const _PlayMappingEdit({required this.playId, required this.basePlanId});

  final String playId;
  final String basePlanId;
}

/// Edits `googlePlayProductId` on Plus and badge catalog documents.
class AdminPlayProductMappingScreen extends StatelessWidget {
  const AdminPlayProductMappingScreen({super.key});

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
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Play ürün eşlemesi'),
              bottom: const TabBar(
                tabs: <Widget>[
                  Tab(text: 'Plus'),
                  Tab(text: 'Rozetler'),
                ],
              ),
            ),
            body: const TabBarView(
              children: <Widget>[
                _CatalogList(collectionName: 'plus_products'),
                _CatalogList(collectionName: 'badge_products'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CatalogList extends StatelessWidget {
  const _CatalogList({required this.collectionName});

  final String collectionName;

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
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final QueryDocumentSnapshot<Map<String, dynamic>> document =
                docs[index];
            final Map<String, dynamic> data = document.data();
            final String playId =
                data['googlePlayProductId']?.toString().trim() ?? '';
            final String basePlanId = collectionName == 'plus_products'
                ? data['googlePlayBasePlanId']?.toString().trim() ?? ''
                : '';
            final String title =
                data['title']?.toString().trim().isNotEmpty == true
                ? data['title'].toString().trim()
                : document.id;
            final String subtitle = collectionName == 'plus_products'
                ? 'İç kimlik: ${document.id}\n'
                      'Play kimliği: ${playId.isEmpty ? '—' : playId}\n'
                      'Base plan: ${basePlanId.isEmpty ? '—' : basePlanId}'
                : 'İç kimlik: ${document.id}\n'
                      'Play kimliği: ${playId.isEmpty ? '—' : playId}';

            return Card(
              child: ListTile(
                title: Text(title),
                subtitle: Text(subtitle),
                isThreeLine: true,
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _editMapping(
                  context,
                  collectionName: collectionName,
                  productId: document.id,
                  currentPlayId: playId,
                  currentBasePlanId: basePlanId,
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
}) async {
  final bool isPlus = collectionName == 'plus_products';
  final TextEditingController controller = TextEditingController(
    text: currentPlayId,
  );
  final TextEditingController basePlanController = TextEditingController(
    text: currentBasePlanId,
  );
  final _PlayMappingEdit? next = await showDialog<_PlayMappingEdit>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Google Play ürün eşlemesi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'googlePlayProductId',
                helperText: 'Boş bırakılırsa ürün eşlemesi temizlenir.',
              ),
            ),
            if (isPlus) ...<Widget>[
              const SizedBox(height: 12),
              TextField(
                controller: basePlanController,
                decoration: const InputDecoration(
                  labelText: 'googlePlayBasePlanId',
                  helperText:
                      'Standart base plan. Boş bırakılırsa plan eşlemesi temizlenir.',
                ),
              ),
            ],
          ],
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

  if (next == null ||
      (next.playId == currentPlayId &&
          (!isPlus || next.basePlanId == currentBasePlanId)) ||
      !context.mounted) {
    return;
  }

  try {
    final HttpsCallable callable = FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    ).httpsCallable('adminSetGooglePlayProductId');
    final Map<String, dynamic> payload = <String, dynamic>{
      'collection': collectionName,
      'productId': productId,
      'googlePlayProductId': next.playId,
    };
    if (isPlus) {
      payload['googlePlayBasePlanId'] = next.basePlanId;
    }
    await callable.call<dynamic>(payload);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Play ürün eşlemesi kaydedildi.')),
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
