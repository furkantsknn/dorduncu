import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../admin/admin_access.dart';

String _verificationAdminText(
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


class VerificationAdminScreen extends StatefulWidget {
  const VerificationAdminScreen({super.key});

  @override
  State<VerificationAdminScreen> createState() =>
      _VerificationAdminScreenState();
}

class _VerificationAdminScreenState extends State<VerificationAdminScreen> {
  @override
  void initState() {
    super.initState();
    _runPrivatePathMigration();
    _runDecisionReasonMigration();
  }

  Future<bool> _isSuperAdmin() async {
    final Map<String, dynamic>? claims = await AdminAccess.currentClaims();

    return AdminAccess.roleFromClaims(claims) == 'super_admin';
  }

  Future<void> _runDecisionReasonMigration() async {
    try {
      if (!await _isSuperAdmin()) {
        return;
      }

      await FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('adminMigrateVerificationDecisionReasons').call<void>();
    } catch (_) {
      // Migration retries when a super admin opens this screen.
    }
  }

  Future<void> _runPrivatePathMigration() async {
    try {
      if (!await _isSuperAdmin()) {
        return;
      }

      await FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('adminMigrateVerificationDocumentPaths').call<void>();
    } catch (_) {
      // Migration retries when a super admin opens this screen.
    }
  }

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
        return _verificationAdminText(context, tr: 'Kontrol başarılı', en: 'Check successful', de: 'Prüfung erfolgreich');
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
      appBar: AppBar(title: Text(_verificationAdminText(context, tr: 'Profil Doğrulamaları', en: 'Profile Verifications', de: 'Profilprüfungen'))),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('verification_requests')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(_verificationAdminText(context, tr: 'Başvurular yüklenemedi.', en: 'Applications could not be loaded.', de: 'Anträge konnten nicht geladen werden.')));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Text(_verificationAdminText(context, tr: 'Bekleyen doğrulama başvurusu yok.', en: 'No pending verification applications.', de: 'Keine ausstehenden Verifizierungsanträge.')),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final String fullName =
                  '${data['ad'] ?? ''} ${data['soyad'] ?? ''}'.trim();

              final String automaticStatus =
                  data['automaticCheckStatus']?.toString().trim() ?? 'pending';

              final Color statusColor = _statusColor(automaticStatus);

              return Card(
                margin: EdgeInsets.zero,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            VerificationAdminDetailScreen(requestId: doc.id),
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
                                : fullName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName.isEmpty ? _verificationAdminText(context, tr: 'Kullanıcı', en: 'User', de: 'Nutzer') : fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                data['telefon']?.toString() ?? '-',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    _statusIcon(automaticStatus),
                                    size: 17,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      _statusText(automaticStatus),
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
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
            },
          );
        },
      ),
    );
  }
}

class VerificationAdminDetailScreen extends StatelessWidget {
  const VerificationAdminDetailScreen({required this.requestId, super.key});

  final String requestId;

  Future<void> _claimVerification(BuildContext context) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('claimVerificationRequest');

      await callable.call(<String, dynamic>{'requestId': requestId});

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_verificationAdminText(context, tr: 'Doğrulama incelemesi sana atandı.', en: 'The verification review was assigned to you.', de: 'Die Verifizierungsprüfung wurde dir zugewiesen.'))),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Başvuru üstlenilemedi.')),
      );
    }
  }

  Future<void> _analyzeVerification(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belgeler otomatik kontrol ediliyor...')),
      );

      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('analyzeVerification');

      await callable.call(<String, dynamic>{'requestId': requestId});

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_verificationAdminText(context, tr: 'Otomatik kontrol tamamlandı.', en: 'Automatic check completed.', de: 'Automatische Prüfung abgeschlossen.'))),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Otomatik kontrol yapılamadı.'),
        ),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Otomatik kontrol sırasında hata oluştu.'),
        ),
      );
    }
  }

  Future<void> _decide(BuildContext context, bool approved) async {
    String adminNote = '';

    if (!approved) {
      final TextEditingController controller = TextEditingController();

      final String? reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text('Red sebebi'),
            content: TextField(
              controller: controller,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Örn: Kimlik ön yüzü okunamıyor.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: Text(_verificationAdminText(context, tr: 'Vazgeç', en: 'Cancel', de: 'Abbrechen')),
              ),
              FilledButton(
                onPressed: () {
                  final String value = controller.text.trim();

                  if (value.length < 3) {
                    return;
                  }

                  Navigator.pop(dialogContext, value);
                },
                child: const Text('Devam'),
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
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('processVerification');

      await callable.call(<String, dynamic>{
        'requestId': requestId,
        'status': approved ? 'approved' : 'rejected',
        'decisionReason': adminNote,
      });

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved ? _verificationAdminText(context, tr: 'Başvuru onaylandı.', en: 'Application approved.', de: 'Antrag genehmigt.') : _verificationAdminText(context, tr: 'Başvuru reddedildi.', en: 'Application rejected.', de: 'Antrag abgelehnt.'),
          ),
        ),
      );

      Navigator.pop(context);
    } on FirebaseFunctionsException catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? _verificationAdminText(context, tr: 'İşlem tamamlanamadı.', en: 'Operation could not be completed.', de: 'Vorgang konnte nicht abgeschlossen werden.'))),
      );
    }
  }

  Future<void> _openDocument(BuildContext context, String documentType) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('getVerificationDocumentContent');

      final HttpsCallableResult<dynamic> result = await callable.call(
        <String, dynamic>{'requestId': requestId, 'documentType': documentType},
      );

      final Map<String, dynamic> data = Map<String, dynamic>.from(
        result.data as Map,
      );

      final String encoded = data['content']?.toString() ?? '';
      final String contentType = data['contentType']?.toString() ?? '';

      if (encoded.isEmpty) {
        throw StateError('Belge içeriği boş.');
      }

      final Uint8List bytes = base64Decode(encoded);

      if (!context.mounted) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => _SecureVerificationViewer(
            title: _documentTitle(context, documentType),
            bytes: bytes,
            isPdf: contentType == 'application/pdf',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? _verificationAdminText(context, tr: 'Belge açılamadı.', en: 'Document could not be opened.', de: 'Dokument konnte nicht geöffnet werden.'))),
      );
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_verificationAdminText(context, tr: 'Belge güvenli şekilde açılamadı.', en: 'The document could not be opened securely.', de: 'Das Dokument konnte nicht sicher geöffnet werden.'))),
      );
    }
  }

  String _documentTitle(BuildContext context, String documentType) {
    switch (documentType) {
      case 'identity_front':
        return _verificationAdminText(context, tr: 'Kimlik Ön Yüzü', en: 'ID Front', de: 'Ausweis Vorderseite');
      case 'identity_back':
        return _verificationAdminText(context, tr: 'Kimlik Arka Yüzü', en: 'ID Back', de: 'Ausweis Rückseite');
      case 'criminal_record':
        return 'Adli Sicil Belgesi';
      case 'selfie':
        return 'Selfie';
      default:
        return 'Belge';
    }
  }

  Map<String, dynamic> _readCheck(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  Widget _documentTile({
    required BuildContext context,
    required String title,
    required String? path,
    required String documentType,
    required bool canAccess,
  }) {
    final bool available = path?.trim().isNotEmpty == true;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        available ? Icons.check_circle : Icons.cancel,
        color: available ? Colors.green : Colors.red,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        !available
            ? 'Belge eksik'
            : canAccess
            ? 'Belgeyi görüntülemek için dokun'
            : 'Belge yalnızca atanmış doğrulama adminine açık',
      ),
      trailing: available ? const Icon(Icons.open_in_new) : null,
      onTap: available && canAccess
          ? () => _openDocument(context, documentType)
          : null,
    );
  }

  Widget _automaticCheckTile({
    required BuildContext context,
    required String title,
    required Map<String, dynamic> check,
  }) {
    final String status = check['status']?.toString().trim() ?? 'pending';

    final String reason = check['reason']?.toString().trim() ?? '';

    final bool passed = status == 'passed';

    final bool failed = status == 'failed';

    final bool processing = status == 'processing';

    final Color color = passed
        ? Colors.green
        : failed
        ? Colors.red
        : Colors.orange;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  reason.isNotEmpty
                      ? reason
                      : processing
                      ? 'Kontrol ediliyor...'
                      : _verificationAdminText(context, tr: 'Henüz kontrol edilmedi.', en: 'Not checked yet.', de: 'Noch nicht geprüft.'),
                  style: TextStyle(
                    color: failed ? Colors.redAccent : null,
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

  Widget _automaticSummary(String status) {
    final bool passed = status == 'passed';

    final bool failed = status == 'failed';

    final bool processing = status == 'processing';

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
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
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
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DocumentReference<Map<String, dynamic>> reference = FirebaseFirestore
        .instance
        .collection('verification_requests')
        .doc(requestId);

    return Scaffold(
      appBar: AppBar(title: Text(_verificationAdminText(context, tr: 'Başvuru Detayı', en: 'Application Details', de: 'Antragsdetails'))),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: reference.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Başvuru yüklenemedi.'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.data!.exists) {
            return const Center(child: Text('Başvuru bulunamadı.'));
          }

          final data = snapshot.data!.data()!;

          final String currentAdminUid =
              FirebaseAuth.instance.currentUser?.uid ?? '';

          final String assignedVerifierUid =
              data['assignedVerifierUid']?.toString().trim() ?? '';

          final bool isAssignedToMe =
              currentAdminUid.isNotEmpty &&
              assignedVerifierUid == currentAdminUid;

          final bool isUnassigned = assignedVerifierUid.isEmpty;

          final String fullName = '${data['ad'] ?? ''} ${data['soyad'] ?? ''}'
              .trim();

          final String automaticStatus =
              data['automaticCheckStatus']?.toString().trim() ?? 'pending';

          final bool isProcessing = automaticStatus == 'processing';

          final identityFrontCheck = _readCheck(data['identityFrontCheck']);

          final identityBackCheck = _readCheck(data['identityBackCheck']);

          final criminalRecordCheck = _readCheck(data['criminalRecordCheck']);

          final bool hasLegacyIdentityBack =
              (data['identityBackPath'] ?? data['identityBackUrl'])
                  ?.toString()
                  .trim()
                  .isNotEmpty ==
              true;

          final bool hasLegacyCriminalRecord =
              (data['criminalRecordPath'] ?? data['criminalRecordUrl'])
                  ?.toString()
                  .trim()
                  .isNotEmpty ==
              true;

          final selfieCheck = _readCheck(data['selfieCheck']);
          final identityUniquenessCheck = _readCheck(
            data['identityUniquenessCheck'],
          );

          final String identityUniquenessStatus =
              identityUniquenessCheck['status']?.toString().trim() ?? 'pending';

          final bool canApprove =
              automaticStatus == 'passed' &&
              identityUniquenessStatus == 'passed';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName.isEmpty ? _verificationAdminText(context, tr: 'Kullanıcı', en: 'User', de: 'Nutzer') : fullName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Telefon: '
                          '${data['telefon'] ?? '-'}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Doğrulama İnceleme Yetkisi',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isAssignedToMe
                              ? 'Bu başvuru sana atanmış.'
                              : isUnassigned
                              ? 'Bu başvuru henüz bir doğrulama adminine atanmadı.'
                              : 'Bu başvuru başka bir doğrulama adminine atanmış.',
                        ),
                        if (assignedVerifierUid.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Atanan admin: $assignedVerifierUid',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                        if (!isAssignedToMe) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _claimVerification(context),
                              icon: const Icon(Icons.assignment_ind_outlined),
                              label: Text(
                                isUnassigned
                                    ? 'İncelemeyi Üstlen'
                                    : 'İncelemeyi Devral',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _verificationAdminText(context, tr: 'Yüklenen Belgeler', en: 'Uploaded Documents', de: 'Hochgeladene Dokumente'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                _documentTile(
                  context: context,
                  title: _verificationAdminText(context, tr: 'Kimlik Ön Yüzü', en: 'ID Front', de: 'Ausweis Vorderseite'),
                  path:
                      data['identityFrontPath']?.toString() ??
                      data['identityFrontUrl']?.toString(),
                  documentType: 'identity_front',
                  canAccess: isAssignedToMe,
                ),
                if (hasLegacyIdentityBack)
                  _documentTile(
                    context: context,
                    title: 'Kimlik Arka Yüzü (Eski Başvuru)',
                    path:
                        data['identityBackPath']?.toString() ??
                        data['identityBackUrl']?.toString(),
                    documentType: 'identity_back',
                    canAccess: isAssignedToMe,
                  ),
                if (hasLegacyCriminalRecord)
                  _documentTile(
                    context: context,
                    title: 'Adli Sicil Belgesi (Eski Başvuru)',
                    path:
                        data['criminalRecordPath']?.toString() ??
                        data['criminalRecordUrl']?.toString(),
                    documentType: 'criminal_record',
                    canAccess: isAssignedToMe,
                  ),
                _documentTile(
                  context: context,
                  title: 'Selfie',
                  path:
                      data['selfiePath']?.toString() ??
                      data['selfieUrl']?.toString(),
                  documentType: 'selfie',
                  canAccess: isAssignedToMe,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  _verificationAdminText(context, tr: 'Otomatik Belge Kontrolü', en: 'Automatic Document Check', de: 'Automatische Dokumentprüfung'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                _automaticSummary(automaticStatus),
                const SizedBox(height: 14),
                _automaticCheckTile(
                  context: context,
                  title: _verificationAdminText(context, tr: 'Kimlik Ön Yüzü', en: 'ID Front', de: 'Ausweis Vorderseite'),
                  check: identityFrontCheck,
                ),
                if (hasLegacyIdentityBack)
                  _automaticCheckTile(
                    context: context,
                    title: 'Kimlik Arka Yüzü (Eski Başvuru)',
                    check: identityBackCheck,
                  ),
                if (hasLegacyCriminalRecord)
                  _automaticCheckTile(
                    context: context,
                    title: 'Adli Sicil Belgesi (Eski Başvuru)',
                    check: criminalRecordCheck,
                  ),
                _automaticCheckTile(context: context, title: 'Selfie', check: selfieCheck),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isProcessing || !isAssignedToMe
                        ? null
                        : () => _analyzeVerification(context),
                    icon: isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.security),
                    label: Text(
                      isProcessing
                          ? 'Kontrol Ediliyor...'
                          : automaticStatus == 'pending'
                          ? _verificationAdminText(context, tr: 'Otomatik Kontrolü Başlat', en: 'Start Automatic Check', de: 'Automatische Prüfung starten')
                          : _verificationAdminText(context, tr: 'Otomatik Kontrolü Tekrarla', en: 'Repeat Automatic Check', de: 'Automatische Prüfung wiederholen'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isAssignedToMe
                            ? () => _decide(context, false)
                            : null,
                        icon: const Icon(Icons.close),
                        label: const Text('Reddet'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: canApprove && isAssignedToMe
                            ? () => _decide(context, true)
                            : null,
                        icon: const Icon(Icons.check),
                        label: const Text('Onayla'),
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

class _SecureVerificationViewer extends StatelessWidget {
  const _SecureVerificationViewer({
    required this.title,
    required this.bytes,
    required this.isPdf,
  });

  final String title;
  final Uint8List bytes;
  final bool isPdf;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Stack(
        children: [
          Positioned.fill(
            child: isPdf
                ? SfPdfViewer.memory(bytes)
                : PhotoView(
                    imageProvider: MemoryImage(bytes),
                    backgroundDecoration: const BoxDecoration(
                      color: Colors.black,
                    ),
                  ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Admin: ${FirebaseAuth.instance.currentUser?.uid ?? '-'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
