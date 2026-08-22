import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class VerificationAdminScreen extends StatelessWidget {
  const VerificationAdminScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'passed':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'processing':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'passed':
        return Icons.check_circle;
      case 'failed':
        return Icons.cancel;
      case 'processing':
        return Icons.hourglass_top;
      default:
        return Icons.pending_outlined;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'passed':
        return 'Kontrol başarılı';
      case 'failed':
        return 'Sorun bulundu';
      case 'processing':
        return 'Kontrol ediliyor';
      default:
        return 'Kontrol bekliyor';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Doğrulamaları'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('verification_requests')
            .where(
          'status',
          isEqualTo: 'pending',
        )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Başvurular yüklenemedi.',
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Bekleyen doğrulama başvurusu yok.',
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            separatorBuilder: (_, _) =>
            const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final String fullName =
              '${data['ad'] ?? ''} ${data['soyad'] ?? ''}'
                  .trim();

              final String automaticStatus =
                  data['automaticCheckStatus']
                      ?.toString()
                      .trim() ??
                      'pending';

              final Color statusColor =
              _statusColor(automaticStatus);

              return Card(
                margin: EdgeInsets.zero,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            VerificationAdminDetailScreen(
                              requestId: doc.id,
                            ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          child: Text(
                            fullName.isEmpty
                                ? '?'
                                : fullName
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName.isEmpty
                                    ? 'Kullanıcı'
                                    : fullName,
                                maxLines: 1,
                                overflow:
                                TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                  FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                data['telefon']
                                    ?.toString() ??
                                    '-',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    _statusIcon(
                                      automaticStatus,
                                    ),
                                    size: 17,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      _statusText(
                                        automaticStatus,
                                      ),
                                      overflow:
                                      TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 12,
                                        fontWeight:
                                        FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class VerificationAdminDetailScreen extends StatelessWidget {
  const VerificationAdminDetailScreen({
    required this.requestId,
    super.key,
  });

  final String requestId;

  Future<void> _analyzeVerification(
      BuildContext context,
      ) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Belgeler otomatik kontrol ediliyor...',
          ),
        ),
      );

      final HttpsCallable callable =
      FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable(
        'analyzeVerification',
      );

      await callable.call(<String, dynamic>{
        'requestId': requestId,
      });

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Otomatik kontrol tamamlandı.',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ??
                'Otomatik kontrol yapılamadı.',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Otomatik kontrol sırasında hata oluştu.',
          ),
        ),
      );
    }
  }

  Future<void> _decide(
      BuildContext context,
      bool approved,
      ) async {
    String adminNote = '';

    if (!approved) {
      final TextEditingController controller =
      TextEditingController();

      final String? reason =
      await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Red sebebi',
            ),
            content: TextField(
              controller: controller,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText:
                'Örn: Kimlik ön yüzü okunamıyor.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text(
                  'Vazgeç',
                ),
              ),
              FilledButton(
                onPressed: () {
                  final String value =
                  controller.text.trim();

                  if (value.length < 3) {
                    return;
                  }

                  Navigator.pop(
                    dialogContext,
                    value,
                  );
                },
                child: const Text(
                  'Devam',
                ),
              ),
            ],
          );
        },
      );

      controller.dispose();

      if (reason == null) {
        return;
      }

      adminNote = reason;
    }

    try {
      final HttpsCallable callable =
      FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable(
        'processVerification',
      );

      await callable.call(<String, dynamic>{
        'requestId': requestId,
        'status':
        approved ? 'approved' : 'rejected',
        'adminNote': adminNote,
      });

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? 'Başvuru onaylandı.'
                : 'Başvuru reddedildi.',
          ),
        ),
      );

      Navigator.pop(context);
    } on FirebaseFunctionsException catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ??
                'İşlem tamamlanamadı.',
          ),
        ),
      );
    }
  }

  Future<void> _openDocument(
      BuildContext context,
      String? url,
      ) async {
    final String value =
        url?.trim() ?? '';

    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Belge bağlantısı bulunamadı.',
          ),
        ),
      );
      return;
    }

    final Uri uri =
    Uri.parse(value);

    final bool opened =
    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Belge açılamadı.',
          ),
        ),
      );
    }
  }

  Map<String, dynamic> _readCheck(
      dynamic value,
      ) {
    if (value is Map) {
      return Map<String, dynamic>.from(
        value,
      );
    }

    return <String, dynamic>{};
  }

  Widget _documentTile({
    required BuildContext context,
    required String title,
    required String? url,
  }) {
    final bool available =
        url?.trim().isNotEmpty == true;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        available
            ? Icons.check_circle
            : Icons.cancel,
        color:
        available ? Colors.green : Colors.red,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        available
            ? 'Belgeyi görüntülemek için dokun'
            : 'Belge eksik',
      ),
      trailing: available
          ? const Icon(
        Icons.open_in_new,
      )
          : null,
      onTap: available
          ? () => _openDocument(
        context,
        url,
      )
          : null,
    );
  }

  Widget _automaticCheckTile({
    required String title,
    required Map<String, dynamic> check,
  }) {
    final String status =
        check['status']
            ?.toString()
            .trim() ??
            'pending';

    final String reason =
        check['reason']
            ?.toString()
            .trim() ??
            '';

    final bool passed =
        status == 'passed';

    final bool failed =
        status == 'failed';

    final bool processing =
        status == 'processing';

    final Color color = passed
        ? Colors.green
        : failed
        ? Colors.red
        : Colors.orange;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius:
        BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(
            alpha: 0.4,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            passed
                ? Icons.check_circle
                : failed
                ? Icons.cancel
                : Icons.hourglass_empty,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason.isNotEmpty
                      ? reason
                      : processing
                      ? 'Kontrol ediliyor...'
                      : 'Henüz kontrol edilmedi.',
                  style: TextStyle(
                    color: failed
                        ? Colors.redAccent
                        : null,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _automaticSummary(
      String status,
      ) {
    final bool passed =
        status == 'passed';

    final bool failed =
        status == 'failed';

    final bool processing =
        status == 'processing';

    final Color color = passed
        ? Colors.green
        : failed
        ? Colors.red
        : Colors.orange;

    final String text = passed
        ? 'Tüm otomatik kontroller başarılı'
        : failed
        ? 'Otomatik kontrolde sorun bulundu'
        : processing
        ? 'Otomatik kontrol devam ediyor'
        : 'Otomatik kontrol henüz yapılmadı';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.08,
        ),
        borderRadius:
        BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(
            alpha: 0.35,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            passed
                ? Icons.verified
                : failed
                ? Icons.warning_amber_rounded
                : Icons.hourglass_top,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight:
                FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DocumentReference<Map<String, dynamic>>
    reference = FirebaseFirestore.instance
        .collection(
      'verification_requests',
    )
        .doc(requestId);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Başvuru Detayı',
        ),
      ),
      body: StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
        stream: reference.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Başvuru yüklenemedi.',
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.data!.exists) {
            return const Center(
              child: Text(
                'Başvuru bulunamadı.',
              ),
            );
          }

          final data =
          snapshot.data!.data()!;

          final String fullName =
          '${data['ad'] ?? ''} ${data['soyad'] ?? ''}'
              .trim();

          final String automaticStatus =
              data['automaticCheckStatus']
                  ?.toString()
                  .trim() ??
                  'pending';

          final bool isProcessing =
              automaticStatus ==
                  'processing';

          final identityFrontCheck =
          _readCheck(
            data['identityFrontCheck'],
          );

          final identityBackCheck =
          _readCheck(
            data['identityBackCheck'],
          );

          final criminalRecordCheck =
          _readCheck(
            data['criminalRecordCheck'],
          );

          final selfieCheck =
          _readCheck(
            data['selfieCheck'],
          );
          final identityUniquenessCheck =
          _readCheck(
            data['identityUniquenessCheck'],
          );

          final String identityUniquenessStatus =
              identityUniquenessCheck['status']
                  ?.toString()
                  .trim() ??
                  'pending';

          final bool canApprove =
              automaticStatus == 'passed' &&
                  identityUniquenessStatus == 'passed';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding:
                    const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName.isEmpty
                              ? 'Kullanıcı'
                              : fullName,
                          style:
                          const TextStyle(
                            fontSize: 20,
                            fontWeight:
                            FontWeight.w900,
                          ),
                        ),
                        const SizedBox(
                          height: 6,
                        ),
                        Text(
                          'Telefon: '
                              '${data['telefon'] ?? '-'}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Yüklenen Belgeler',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                _documentTile(
                  context: context,
                  title:
                  'Kimlik Ön Yüzü',
                  url:
                  data['identityFrontUrl']
                      ?.toString(),
                ),
                _documentTile(
                  context: context,
                  title:
                  'Kimlik Arka Yüzü',
                  url:
                  data['identityBackUrl']
                      ?.toString(),
                ),
                _documentTile(
                  context: context,
                  title:
                  'Adli Sicil Belgesi',
                  url:
                  data['criminalRecordUrl']
                      ?.toString(),
                ),
                _documentTile(
                  context: context,
                  title: 'Selfie',
                  url: data['selfieUrl']
                      ?.toString(),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  'Otomatik Belge Kontrolü',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _automaticSummary(
                  automaticStatus,
                ),
                const SizedBox(height: 14),
                _automaticCheckTile(
                  title:
                  'Kimlik Ön Yüzü',
                  check:
                  identityFrontCheck,
                ),
                _automaticCheckTile(
                  title:
                  'Kimlik Arka Yüzü',
                  check:
                  identityBackCheck,
                ),
                _automaticCheckTile(
                  title:
                  'Adli Sicil Belgesi',
                  check:
                  criminalRecordCheck,
                ),
                _automaticCheckTile(
                  title: 'Selfie',
                  check: selfieCheck,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child:
                  OutlinedButton.icon(
                    onPressed: isProcessing
                        ? null
                        : () =>
                        _analyzeVerification(
                          context,
                        ),
                    icon: isProcessing
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(
                      Icons.security,
                    ),
                    label: Text(
                      isProcessing
                          ? 'Kontrol Ediliyor...'
                          : automaticStatus ==
                          'pending'
                          ? 'Otomatik Kontrolü Başlat'
                          : 'Otomatik Kontrolü Tekrarla',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child:
                      OutlinedButton.icon(
                        onPressed: () =>
                            _decide(
                              context,
                              false,
                            ),
                        icon: const Icon(
                          Icons.close,
                        ),
                        label: const Text(
                          'Reddet',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child:
                      FilledButton.icon(
                        onPressed: canApprove
                            ? () =>
                            _decide(
                              context,
                              true,
                            )
                            : null,
                        icon: const Icon(
                          Icons.check,
                        ),
                        label: const Text(
                          'Onayla',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}