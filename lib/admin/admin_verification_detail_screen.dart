import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:cloud_functions/cloud_functions.dart';

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


class AdminVerificationDetailScreen extends StatefulWidget {
  const AdminVerificationDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<AdminVerificationDetailScreen> createState() =>
      _AdminVerificationDetailScreenState();
}

class _AdminVerificationDetailScreenState
    extends State<AdminVerificationDetailScreen> {
  final TextEditingController _adminNoteController = TextEditingController();

  bool _processing = false;

  DocumentReference<Map<String, dynamic>> get _requestReference {
    return FirebaseFirestore.instance
        .collection('verification_requests')
        .doc(widget.requestId);
  }

  @override
  void dispose() {
    _adminNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _locText(context, tr: 'Oyuncu Başvurusu', en: 'Player Application', de: 'Spielerbewerbung'),
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _requestReference.snapshots(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.hasError) {
                return _ErrorView(
                  message: 'Başvuru bilgileri yüklenirken bir hata oluştu.',
                  onRetry: () {
                    setState(() {});
                  },
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final DocumentSnapshot<Map<String, dynamic>>? document =
                  snapshot.data;

              if (document == null || !document.exists) {
                return const _EmptyView();
              }

              final Map<String, dynamic> data =
                  document.data() ?? <String, dynamic>{};

              return _buildContent(context: context, data: data);
            },
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required Map<String, dynamic> data,
  }) {
    final String name = data['ad']?.toString().trim() ?? '';

    final String surname = data['soyad']?.toString().trim() ?? '';

    final String fullName = '$name $surname'.trim();

    final String phone = data['telefon']?.toString().trim() ?? '';

    final String uid = data['uid']?.toString().trim() ?? widget.requestId;

    final String status = data['status']?.toString().trim() ?? 'pending';

    final String normalizedStatus = status.toLowerCase();

    final DateTime? birthDate = _dateFromValue(data['dogumTarihi']);

    final DateTime? createdAt = _dateFromValue(data['createdAt']);

    final DateTime? updatedAt = _dateFromValue(data['updatedAt']);

    final DateTime? reviewedAt = _dateFromValue(data['reviewedAt']);

    final String reviewedBy = data['reviewedBy']?.toString().trim() ?? '';

    final String identityFrontPath =
        data['identityFrontPath']?.toString().trim() ??
        data['identityFrontUrl']?.toString().trim() ??
        '';

    final String identityBackPath =
        data['identityBackPath']?.toString().trim() ??
        data['identityBackUrl']?.toString().trim() ??
        '';

    final String criminalRecordPath =
        data['criminalRecordPath']?.toString().trim() ??
        data['criminalRecordUrl']?.toString().trim() ??
        '';

    final String selfiePath =
        data['selfiePath']?.toString().trim() ??
        data['selfieUrl']?.toString().trim() ??
        '';

    final String adminNote =
        data['decisionReason']?.toString().trim().isNotEmpty == true
        ? data['decisionReason'].toString()
        : data['adminNote']?.toString() ?? '';

    if (_adminNoteController.text.isEmpty && adminNote.isNotEmpty) {
      _adminNoteController.text = adminNote;
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _requestReference.get();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          _ApplicationHeaderCard(
            fullName: fullName,
            phone: phone,
            status: status,
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: _locText(context, tr: 'Başvuru bilgileri', en: 'Application details', de: 'Bewerbungsdetails'),
            icon: Icons.assignment_outlined,
            children: <Widget>[
              _InformationRow(
                icon: Icons.person_outline,
                label: 'Ad soyad',
                value: fullName.isEmpty ? _locText(context, tr: 'Bilgi bulunamadı', en: 'Information unavailable', de: 'Information nicht verfügbar') : fullName,
              ),
              const Divider(height: 25),
              _InformationRow(
                icon: Icons.phone_outlined,
                label: 'Telefon',
                value: phone.isEmpty ? _locText(context, tr: 'Bilgi bulunamadı', en: 'Information unavailable', de: 'Information nicht verfügbar') : phone,
              ),
              const Divider(height: 25),
              _InformationRow(
                icon: Icons.cake_outlined,
                label: 'Doğum tarihi',
                value: birthDate == null
                    ? _locText(context, tr: 'Bilgi bulunamadı', en: 'Information unavailable', de: 'Information nicht verfügbar')
                    : _formatDate(birthDate, includeTime: false),
              ),
              const Divider(height: 25),
              _InformationRow(
                icon: Icons.schedule_outlined,
                label: 'Başvuru tarihi',
                value: createdAt == null
                    ? _locText(context, tr: 'Bilgi bulunamadı', en: 'Information unavailable', de: 'Information nicht verfügbar')
                    : _formatDate(createdAt),
              ),
              if (updatedAt != null) ...<Widget>[
                const Divider(height: 25),
                _InformationRow(
                  icon: Icons.update_outlined,
                  label: 'Son güncelleme',
                  value: _formatDate(updatedAt),
                ),
              ],
              if (reviewedAt != null) ...<Widget>[
                const Divider(height: 25),
                _InformationRow(
                  icon: Icons.fact_check_outlined,
                  label: 'İnceleme tarihi',
                  value: _formatDate(reviewedAt),
                ),
              ],
              if (reviewedBy.isNotEmpty) ...<Widget>[
                const Divider(height: 25),
                _InformationRow(
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'İnceleyen admin',
                  value: reviewedBy,
                  allowCopy: true,
                ),
              ],
              const Divider(height: 25),
              _InformationRow(
                icon: Icons.fingerprint,
                label: 'Kullanıcı kimliği',
                value: uid,
                allowCopy: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Yüklenen belgeler',
            icon: Icons.folder_copy_outlined,
            children: <Widget>[
              _DocumentCard(
                title: 'Kimlik ön yüz',
                subtitle: 'Kullanıcının yüklediği kimlik ön yüzü',
                icon: Icons.credit_card_outlined,
                url: identityFrontPath,
                onTap: () {
                  _showDocumentMessage(
                    title: 'Kimlik ön yüz',
                    documentType: 'identity_front',
                  );
                },
              ),
              const SizedBox(height: 12),
              _DocumentCard(
                title: 'Kimlik arka yüz',
                subtitle: 'Kullanıcının yüklediği kimlik arka yüzü',
                icon: Icons.credit_card_outlined,
                url: identityBackPath,
                onTap: () {
                  _showDocumentMessage(
                    title: 'Kimlik arka yüz',
                    documentType: 'identity_back',
                  );
                },
              ),
              const SizedBox(height: 12),
              _DocumentCard(
                title: 'Adli sicil kaydı',
                subtitle: 'Kullanıcının yüklediği adli sicil belgesi',
                icon: Icons.description_outlined,
                url: criminalRecordPath,
                onTap: () {
                  _showDocumentMessage(
                    title: 'Adli sicil kaydı',
                    documentType: 'criminal_record',
                  );
                },
              ),
              const SizedBox(height: 12),
              _DocumentCard(
                title: 'Selfie',
                subtitle: 'Kullanıcının kamera ile çektiği doğrulama fotoğrafı',
                icon: Icons.camera_alt_outlined,
                url: selfiePath,
                onTap: () {
                  _showDocumentMessage(title: 'Selfie', documentType: 'selfie');
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          _StatusInformationCard(status: status),

          const SizedBox(height: 16),

          _SectionCard(
            title: 'Admin Notu',
            icon: Icons.edit_note_outlined,
            children: <Widget>[
              TextField(
                controller: _adminNoteController,
                enabled: !_processing,
                minLines: 5,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Başvuru hakkında yönetici notu...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _SectionCard(
            title: 'Başvuruyu sonuçlandır',
            icon: Icons.admin_panel_settings_outlined,
            children: <Widget>[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _processing || normalizedStatus == 'approved'
                      ? null
                      : () {
                          _processApplication(status: 'approved', uid: uid);
                        },
                  icon: const Icon(Icons.verified_rounded),
                  label: const Text('Başvuruyu Onayla'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _processing || normalizedStatus == 'revision'
                      ? null
                      : () {
                          _processApplication(status: 'revision', uid: uid);
                        },
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Revizyon İste'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepOrange,
                    side: const BorderSide(color: Colors.deepOrange),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _processing || normalizedStatus == 'rejected'
                      ? null
                      : () {
                          _processApplication(status: 'rejected', uid: uid);
                        },
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Başvuruyu Reddet'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              if (_processing) ...<Widget>[
                const SizedBox(height: 18),
                const Center(
                  child: Column(
                    children: <Widget>[
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text(
                        'İşlem gerçekleştiriliyor...',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _processApplication({
    required String status,
    required String uid,
  }) async {
    if (_processing) {
      return;
    }

    final String adminNote = _adminNoteController.text.trim();

    if ((status == 'revision' || status == 'rejected') && adminNote.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Revizyon veya ret işlemi için admin notu yazmalısın.',
            ),
          ),
        );

      return;
    }

    final String actionTitle;

    switch (status) {
      case 'approved':
        actionTitle = 'Başvuruyu onayla';
        break;
      case 'revision':
        actionTitle = 'Revizyon iste';
        break;
      case 'rejected':
        actionTitle = 'Başvuruyu reddet';
        break;
      default:
        return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(actionTitle),
          content: Text(_confirmationMessage(status)),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(_locText(context, tr: 'Vazgeç', en: 'Cancel', de: 'Abbrechen')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(
                status == 'approved'
                    ? 'Onayla'
                    : status == 'revision'
                    ? 'Revizyon iste'
                    : 'Reddet',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('processVerification');

      await callable.call(<String, dynamic>{
        'requestId': widget.requestId,
        'status': status,
        'decisionReason': adminNote,
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_successMessage(status))));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('İşlem tamamlanamadı: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  String _confirmationMessage(String status) {
    switch (status) {
      case 'approved':
        return 'Başvuru onaylanacak ve kullanıcıya oyuncu rozeti verilecek.';
      case 'revision':
        return 'Başvuru revizyona gönderilecek. Yazdığın admin notu kullanıcıya düzeltme nedeni olarak iletilebilecek.';
      case 'rejected':
        return 'Başvuru reddedilecek. Bu işlemi gerçekleştirmek istediğine emin misin?';
      default:
        return '';
    }
  }

  String _successMessage(String status) {
    switch (status) {
      case 'approved':
        return 'Oyuncu başvurusu onaylandı.';
      case 'revision':
        return 'Kullanıcıdan revizyon istendi.';
      case 'rejected':
        return 'Oyuncu başvurusu reddedildi.';
      default:
        return 'İşlem tamamlandı.';
    }
  }

  DateTime? _dateFromValue(dynamic value) {
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

  String _formatDate(DateTime date, {bool includeTime = true}) {
    final String day = date.day.toString().padLeft(2, '0');

    final String month = date.month.toString().padLeft(2, '0');

    final String year = date.year.toString();

    if (!includeTime) {
      return '$day.$month.$year';
    }

    final String hour = date.hour.toString().padLeft(2, '0');

    final String minute = date.minute.toString().padLeft(2, '0');

    return '$day.$month.$year $hour:$minute';
  }

  Future<void> _showDocumentMessage({
    required String title,
    required String documentType,
  }) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('getVerificationDocumentContent');

      final HttpsCallableResult<dynamic> result = await callable.call(
        <String, dynamic>{
          'requestId': widget.requestId,
          'documentType': documentType,
        },
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

      if (!mounted) return;

      final bool isPdf = contentType == 'application/pdf';

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) {
            if (isPdf) {
              return _PdfDocumentViewerScreen(title: title, bytes: bytes);
            }

            return _ImageDocumentViewerScreen(title: title, bytes: bytes);
          },
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Belge açılamadı.')),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belge güvenli şekilde açılamadı.')),
      );
    }
  }
}

class _ImageDocumentViewerScreen extends StatelessWidget {
  const _ImageDocumentViewerScreen({required this.title, required this.bytes});

  final String title;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: PhotoView(
          imageProvider: MemoryImage(bytes),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stackTrace) {
                return const _DocumentLoadError(
                  message: 'Görsel güvenli şekilde açılamadı.',
                  foregroundColor: Colors.white,
                );
              },
          minScale: PhotoViewComputedScale.contained,
          initialScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 4,
          enableRotation: false,
        ),
      ),
    );
  }
}

class _PdfDocumentViewerScreen extends StatefulWidget {
  const _PdfDocumentViewerScreen({required this.title, required this.bytes});

  final String title;
  final Uint8List bytes;

  @override
  State<_PdfDocumentViewerScreen> createState() =>
      _PdfDocumentViewerScreenState();
}

class _PdfDocumentViewerScreenState extends State<_PdfDocumentViewerScreen> {
  final PdfViewerController _pdfController = PdfViewerController();

  bool _hasError = false;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (_totalPages > 0)
              Text(
                'Sayfa $_currentPage / $_totalPages',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Önceki sayfa',
            onPressed: _currentPage > 1 && !_hasError
                ? () {
                    _pdfController.previousPage();
                  }
                : null,
            icon: const Icon(Icons.keyboard_arrow_up),
          ),
          IconButton(
            tooltip: 'Sonraki sayfa',
            onPressed:
                _totalPages > 0 && _currentPage < _totalPages && !_hasError
                ? () {
                    _pdfController.nextPage();
                  }
                : null,
            icon: const Icon(Icons.keyboard_arrow_down),
          ),
        ],
      ),
      body: _hasError
          ? const _DocumentLoadError(
              message:
                  'PDF yüklenemedi. Belge bağlantısı geçersiz veya erişilemiyor olabilir.',
            )
          : SfPdfViewer.memory(
              widget.bytes,
              controller: _pdfController,
              canShowScrollHead: true,
              canShowScrollStatus: true,
              enableDoubleTapZooming: true,
              enableTextSelection: true,
              onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                if (!mounted) {
                  return;
                }

                setState(() {
                  _totalPages = details.document.pages.count;
                  _currentPage = 1;
                });
              },
              onPageChanged: (PdfPageChangedDetails details) {
                if (!mounted) {
                  return;
                }

                setState(() {
                  _currentPage = details.newPageNumber;
                });
              },
              onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                if (!mounted) {
                  return;
                }

                setState(() {
                  _hasError = true;
                });
              },
            ),
    );
  }
}

class _DocumentLoadError extends StatelessWidget {
  const _DocumentLoadError({required this.message, this.foregroundColor});

  final String message;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final Color color = foregroundColor ?? Theme.of(context).colorScheme.error;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.broken_image_outlined, size: 60, color: color),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicationHeaderCard extends StatelessWidget {
  const _ApplicationHeaderCard({
    required this.fullName,
    required this.phone,
    required this.status,
  });

  final String fullName;
  final String phone;
  final String status;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _verificationStatusColor(status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            statusColor.withValues(alpha: 0.20),
            Theme.of(context).colorScheme.surfaceContainerHighest,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withValues(alpha: 0.30)),
      ),
      child: Column(
        children: <Widget>[
          CircleAvatar(
            radius: 36,
            backgroundColor: statusColor.withValues(alpha: 0.16),
            child: Icon(
              Icons.verified_user_outlined,
              color: statusColor,
              size: 38,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            fullName.isEmpty ? 'İsimsiz kullanıcı' : fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            phone.isEmpty ? 'Telefon bilgisi yok' : phone,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 13),
          _VerificationStatusChip(status: status),
        ],
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
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 17),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.icon,
    required this.label,
    required this.value,
    this.allowCopy = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool allowCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (allowCopy)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(Icons.content_copy_outlined, size: 18),
          ),
      ],
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.url,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool available = url.isNotEmpty;

    final Color color = available
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 49,
                height: 49,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  available ? icon : Icons.file_present_outlined,
                  color: color,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      available ? subtitle : 'Belge bulunamadı',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      available
                          ? Icons.visibility_outlined
                          : Icons.warning_amber_rounded,
                      size: 16,
                      color: color,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      available ? 'Görüntüle' : 'Eksik',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusInformationCard extends StatelessWidget {
  const _StatusInformationCard({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final Color color = _verificationStatusColor(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(_verificationStatusIcon(status), color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _verificationStatusTitle(status),
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  _verificationStatusDescription(status),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
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

class _VerificationStatusChip extends StatelessWidget {
  const _VerificationStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final Color color = _verificationStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(_verificationStatusIcon(status), size: 17, color: color),
          const SizedBox(width: 7),
          Text(
            _verificationStatusTitle(status),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

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
            Icon(
              Icons.error_outline,
              size: 58,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.find_in_page_outlined, size: 58),
            SizedBox(height: 14),
            Text(
              'Oyuncu başvurusu bulunamadı.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

String _verificationStatusTitle(String status) {
  switch (status.toLowerCase()) {
    case 'approved':
      return 'Onaylandı';
    case 'revision':
      return 'Revizyon istendi';
    case 'rejected':
      return 'Reddedildi';
    case 'expired':
      return 'Süresi Doldu';
    case 'pending':
    default:
      return 'İnceleme bekliyor';
  }
}

String _verificationStatusDescription(String status) {
  switch (status.toLowerCase()) {
    case 'approved':
      return 'Bu oyuncu doğrulama başvurusu onaylanmış durumda.';
    case 'revision':
      return 'Kullanıcıdan başvurudaki belgeler için düzeltme istenmiş durumda.';
    case 'rejected':
      return 'Bu oyuncu doğrulama başvurusu reddedilmiş durumda.';
    case 'pending':
    default:
      return 'Başvuru henüz bir yönetici tarafından sonuçlandırılmamış.';
  }
}

IconData _verificationStatusIcon(String status) {
  switch (status.toLowerCase()) {
    case 'approved':
      return Icons.verified_rounded;
    case 'revision':
      return Icons.edit_note_rounded;
    case 'rejected':
      return Icons.cancel_outlined;
    case 'pending':
    default:
      return Icons.hourglass_top_rounded;
  }
}

Color _verificationStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'approved':
      return Colors.green;
    case 'revision':
      return Colors.deepOrange;
    case 'rejected':
      return Colors.red;
    case 'expired':
      return Colors.grey;
    case 'pending':
    default:
      return Colors.orange;
  }
}
