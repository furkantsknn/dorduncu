import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSupportDetailScreen extends StatefulWidget {
  const AdminSupportDetailScreen({
    super.key,
    required this.requestId,
  });

  final String requestId;

  @override
  State<AdminSupportDetailScreen> createState() =>
      _AdminSupportDetailScreenState();
}

class _AdminSupportDetailScreenState
    extends State<AdminSupportDetailScreen> {
  final TextEditingController _responseController =
  TextEditingController();

  final TextEditingController _notesController =
  TextEditingController();

  bool _saving = false;
  bool _controllersInitialized = false;

  DocumentReference<Map<String, dynamic>> get _requestReference {
    return FirebaseFirestore.instance
        .collection('support_requests')
        .doc(widget.requestId);
  }

  @override
  void dispose() {
    _responseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String status) async {
    if (_saving) {
      return;
    }

    setState(() => _saving = true);

    try {
      final Map<String, dynamic> updateData = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (status == 'closed') {
        updateData['closedAt'] = FieldValue.serverTimestamp();
      } else {
        updateData['closedAt'] = null;
      }

      await _requestReference.update(updateData);

      await _requestReference.collection('history').add(
        <String, dynamic>{
          'type': 'status_changed',
          'status': status,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Talep durumu ${_statusTitle(status)} olarak güncellendi.',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      _showError(
        error.message ?? 'Talep durumu güncellenemedi.',
      );
    } catch (_) {
      _showError('Talep durumu güncellenemedi.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _saveAdminContent() async {
    if (_saving) {
      return;
    }

    final String response = _responseController.text.trim();
    final String notes = _notesController.text.trim();

    setState(() => _saving = true);

    try {
      final Map<String, dynamic> updateData = <String, dynamic>{
        'adminResponse': response,
        'adminNotes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (response.isNotEmpty) {
        updateData['status'] = 'answered';
      }

      await _requestReference.update(updateData);

      await _requestReference.collection('history').add(
        <String, dynamic>{
          'type': response.isEmpty
              ? 'admin_notes_updated'
              : 'admin_response_added',
          'adminResponse': response,
          'adminNotes': notes,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.isEmpty
                ? 'Admin notu kaydedildi.'
                : 'Admin cevabı kaydedildi.',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      _showError(
        error.message ?? 'Değişiklikler kaydedilemedi.',
      );
    } catch (_) {
      _showError('Değişiklikler kaydedilemedi.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _requestReference.snapshots(),
      builder: (
          BuildContext context,
          AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Talep Detayı'),
            ),
            body: const Center(
              child: Text(
                'Destek talebi yüklenirken bir hata oluştu.',
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Talep Detayı'),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final DocumentSnapshot<Map<String, dynamic>> document =
        snapshot.data!;

        final Map<String, dynamic>? data = document.data();

        if (!document.exists || data == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Talep Detayı'),
            ),
            body: const Center(
              child: Text('Destek talebi bulunamadı.'),
            ),
          );
        }

        if (!_controllersInitialized) {
          _responseController.text =
              data['adminResponse']?.toString() ?? '';

          _notesController.text =
              data['adminNotes']?.toString() ?? '';

          _controllersInitialized = true;
        }

        final String category =
            data['category']?.toString() ?? '';

        final String subject =
            data['subject']?.toString() ?? '';

        final String description =
            data['description']?.toString() ?? '';

        final String status =
            data['status']?.toString() ?? 'new';

        final String urgency =
            data['urgency']?.toString() ?? 'normal';

        final String userId =
            data['userId']?.toString() ?? '';

        final String relatedUserId =
            data['relatedUserId']?.toString() ?? '';

        final String relatedEventId =
            data['relatedEventId']?.toString() ?? '';

        final String relatedMessageId =
            data['relatedMessageId']?.toString() ?? '';

        final List<String> attachmentUrls =
        List<String>.from(
          data['attachmentUrls'] ?? const <String>[],
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Talep Detayı',
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
            actions: <Widget>[
              if (_saving)
                const Padding(
                  padding: EdgeInsets.only(right: 18),
                  child: Center(
                    child: SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              32,
            ),
            children: <Widget>[
              _buildHeaderCard(
                context: context,
                category: category,
                subject: subject,
                status: status,
                urgency: urgency,
              ),
              const SizedBox(height: 14),
              _buildInformationCard(
                context: context,
                title: 'Talep bilgileri',
                children: <Widget>[
                  _DetailRow(
                    label: 'Talep numarası',
                    value: document.id,
                  ),
                  _DetailRow(
                    label: 'Oluşturan kullanıcı',
                    value: userId,
                  ),
                  if (relatedUserId.isNotEmpty)
                    _DetailRow(
                      label: 'İlgili kullanıcı',
                      value: relatedUserId,
                    ),
                  if (relatedEventId.isNotEmpty)
                    _DetailRow(
                      label: 'İlgili etkinlik',
                      value: relatedEventId,
                    ),
                  if (relatedMessageId.isNotEmpty)
                    _DetailRow(
                      label: 'İlgili mesaj',
                      value: relatedMessageId,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _buildInformationCard(
                context: context,
                title: 'Açıklama',
                children: <Widget>[
                  Text(
                    description.isEmpty
                        ? 'Açıklama bulunmuyor.'
                        : description,
                    style: const TextStyle(
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (attachmentUrls.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                _buildAttachmentsCard(
                  context,
                  attachmentUrls,
                ),
              ],
              const SizedBox(height: 14),
              _buildStatusCard(
                context: context,
                currentStatus: status,
              ),
              const SizedBox(height: 14),
              _buildAdminResponseCard(context),
              const SizedBox(height: 14),
              _buildAdminNotesCard(context),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed:
                _saving ? null : _saveAdminContent,
                icon: const Icon(Icons.save_outlined),
                label: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                  child: Text(
                    _saving
                        ? 'Kaydediliyor...'
                        : 'Admin işlemlerini kaydet',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard({
    required BuildContext context,
    required String category,
    required String subject,
    required String status,
    required String urgency,
  }) {
    final Color statusColor = _statusColor(status);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _LabelChip(
                  icon: Icons.support_agent_rounded,
                  label: _categoryTitle(category),
                  color: Theme.of(context).colorScheme.primary,
                ),
                _LabelChip(
                  icon: Icons.circle,
                  label: _statusTitle(status),
                  color: statusColor,
                ),
                _LabelChip(
                  icon: Icons.priority_high_rounded,
                  label: _urgencyTitle(urgency),
                  color: _urgencyColor(urgency),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              subject.isEmpty
                  ? _categoryTitle(category)
                  : subject,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInformationCard({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentsCard(
      BuildContext context,
      List<String> urls,
      ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Ek dosyalar',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: urls.length,
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (
                  BuildContext context,
                  int index,
                  ) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    urls[index],
                    fit: BoxFit.cover,
                    errorBuilder: (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                        ) {
                      return Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image_outlined,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required BuildContext context,
    required String currentStatus,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Talep durumu',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: currentStatus,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(
                  Icons.sync_alt_rounded,
                ),
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'new',
                  child: Text('Yeni'),
                ),
                DropdownMenuItem<String>(
                  value: 'reviewing',
                  child: Text('İnceleniyor'),
                ),
                DropdownMenuItem<String>(
                  value: 'answered',
                  child: Text('Yanıtlandı'),
                ),
                DropdownMenuItem<String>(
                  value: 'closed',
                  child: Text('Kapatıldı'),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (String? value) {
                if (value != null &&
                    value != currentStatus) {
                  _updateStatus(value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminResponseCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Kullanıcıya verilecek cevap',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Bu alan kullanıcı tarafından görüntülenebilir.',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _responseController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Talebe verilecek cevabı yaz...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminNotesCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Dahili admin notu',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Bu alan yalnızca yöneticiler içindir.',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              minLines: 3,
              maxLines: 7,
              decoration: const InputDecoration(
                hintText: 'İnceleme notunu yaz...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _categoryTitle(String category) {
    switch (category) {
      case 'suggestion':
        return 'Öneri';
      case 'bugReport':
      case 'bug_report':
        return 'Hata Bildirimi';
      case 'generalSupport':
      case 'general_support':
        return 'Genel Destek';
      case 'paymentIssue':
      case 'payment_issue':
        return 'Ödeme Sorunu';
      case 'accountAppeal':
      case 'account_appeal':
        return 'Hesap İtirazı';
      case 'userReport':
      case 'user_report':
        return 'Kullanıcı Şikâyeti';
      case 'eventReport':
      case 'event_report':
        return 'Etkinlik Şikâyeti';
      case 'messageReport':
      case 'message_report':
        return 'Mesaj Şikâyeti';
      case 'inappropriateImage':
      case 'inappropriate_image':
        return 'Uygunsuz Görsel';
      case 'securityEmergency':
      case 'security_emergency':
        return 'Güvenlik Bildirimi';
      default:
        return category.isEmpty
            ? 'Destek Talebi'
            : category;
    }
  }

  String _statusTitle(String status) {
    switch (status) {
      case 'reviewing':
        return 'İnceleniyor';
      case 'answered':
        return 'Yanıtlandı';
      case 'closed':
        return 'Kapatıldı';
      case 'new':
      default:
        return 'Yeni';
    }
  }

  String _urgencyTitle(String urgency) {
    switch (urgency) {
      case 'low':
        return 'Düşük';
      case 'high':
        return 'Yüksek';
      case 'critical':
      case 'emergency':
        return 'Acil';
      case 'normal':
      default:
        return 'Normal';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'reviewing':
        return Colors.blue;
      case 'answered':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      case 'new':
      default:
        return Colors.orange;
    }
  }

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'low':
        return Colors.green;
      case 'high':
        return Colors.deepOrange;
      case 'critical':
      case 'emergency':
        return Colors.red;
      case 'normal':
      default:
        return Colors.blueGrey;
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
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