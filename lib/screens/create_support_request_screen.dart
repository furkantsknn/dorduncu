import 'package:flutter/material.dart';

import '../services/support_attachment_service.dart';
import '../services/support_service.dart';
import '../services/gift_recipient_service.dart';
import '../utils/support_categories.dart';
import '../widgets/user_avatar.dart';

String _supportRequestText(
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

class CreateSupportRequestScreen extends StatefulWidget {
  const CreateSupportRequestScreen({
    super.key,
    required this.category,
    this.relatedUserId,
    this.relatedUserName,
    this.relatedUserAvatarUrl,
    this.relatedEventId,
    this.relatedMessageId,
  });

  final SupportCategory category;
  final String? relatedUserId;
  final String? relatedUserName;
  final String? relatedUserAvatarUrl;
  final String? relatedEventId;
  final String? relatedMessageId;

  @override
  State<CreateSupportRequestScreen> createState() =>
      _CreateSupportRequestScreenState();
}

class _CreateSupportRequestScreenState
    extends State<CreateSupportRequestScreen> {
  late final String _clientRequestId =
      '${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _subjectController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();

  SupportUrgency _selectedUrgency = SupportUrgency.normal;

  bool _isSubmitting = false;

  final List<SupportAttachmentDraft> _attachments = <SupportAttachmentDraft>[];

  @override
  void initState() {
    super.initState();

    if (widget.category.isCriticalCategory) {
      _selectedUrgency = SupportUrgency.critical;
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String get _descriptionLabel {
    switch (widget.category) {
      case SupportCategory.suggestion:
        return _supportRequestText(
          context,
          tr: 'Önerin',
          en: 'Your suggestion',
          de: 'Dein Vorschlag',
        );
      case SupportCategory.bugReport:
        return _supportRequestText(
          context,
          tr: 'Hata açıklaması',
          en: 'Bug description',
          de: 'Fehlerbeschreibung',
        );
      case SupportCategory.generalSupport:
        return 'Destek talebin';
      case SupportCategory.paymentIssue:
        return _supportRequestText(
          context,
          tr: 'Ödeme sorununun açıklaması',
          en: 'Payment issue description',
          de: 'Beschreibung des Zahlungsproblems',
        );
      case SupportCategory.accountAppeal:
        return _supportRequestText(
          context,
          tr: 'İtiraz açıklaması',
          en: 'Appeal description',
          de: 'Beschreibung des Einspruchs',
        );
      case SupportCategory.userReport:
        return _supportRequestText(
          context,
          tr: 'Şikâyet açıklaması',
          en: 'Complaint description',
          de: 'Beschwerdebeschreibung',
        );
      case SupportCategory.eventReport:
        return 'Etkinlikle ilgili açıklama';
      case SupportCategory.messageReport:
        return 'Mesajla ilgili açıklama';
      case SupportCategory.inappropriateImage:
        return 'Görselle ilgili açıklama';
      case SupportCategory.securityEmergency:
        return _supportRequestText(
          context,
          tr: 'Güvenlik durumu açıklaması',
          en: 'Security issue description',
          de: 'Beschreibung des Sicherheitsproblems',
        );
    }
  }

  String get _descriptionHint {
    switch (widget.category) {
      case SupportCategory.suggestion:
        return 'Önerini mümkün olduğunca ayrıntılı anlat.';
      case SupportCategory.bugReport:
        return 'Sorunun nasıl oluştuğunu ve tekrar etme adımlarını yaz.';
      case SupportCategory.generalSupport:
        return 'Yardıma ihtiyaç duyduğun konuyu ayrıntılı anlat.';
      case SupportCategory.paymentIssue:
        return 'Ödeme tarihi, işlem türü ve yaşadığın sorunu yaz.';
      case SupportCategory.accountAppeal:
        return 'Hesabınla ilgili itiraz nedenini ayrıntılı açıkla.';
      case SupportCategory.userReport:
        return 'Kullanıcının hangi davranışını şikâyet ettiğini açıkla.';
      case SupportCategory.eventReport:
        return 'Etkinlikte gördüğün sorunu veya kural ihlalini açıkla.';
      case SupportCategory.messageReport:
        return 'Mesajın neden uygunsuz olduğunu açıkla.';
      case SupportCategory.inappropriateImage:
        return 'Görselin neden uygunsuz olduğunu açıkla.';
      case SupportCategory.securityEmergency:
        return 'Tehdit veya güvenlik riskini açık ve ayrıntılı şekilde yaz.';
    }
  }

  Future<void> _pickScreenshots() async {
    if (_isSubmitting ||
        _attachments.length >= SupportAttachmentService.maxAttachmentCount) {
      return;
    }

    try {
      final List<SupportAttachmentDraft> selected =
          await SupportAttachmentService.pickScreenshots(
            remainingSlots:
                SupportAttachmentService.maxAttachmentCount -
                _attachments.length,
          );

      if (!mounted || selected.isEmpty) {
        return;
      }

      setState(() {
        _attachments.addAll(selected);
      });
    } on StateError catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Ekran görüntüsü seçilemedi.');
    }
  }

  void _removeAttachment(int index) {
    if (_isSubmitting || index < 0 || index >= _attachments.length) {
      return;
    }

    setState(() {
      _attachments.removeAt(index);
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_isSubmitting) {
      return;
    }

    final FormState? form = _formKey.currentState;

    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    List<String> uploadedPaths = const <String>[];

    try {
      uploadedPaths = await SupportAttachmentService.uploadDrafts(_attachments);

      await SupportService.createRequest(
        clientRequestId: _clientRequestId,
        category: widget.category,
        subject: _subjectController.text,
        description: _descriptionController.text,
        urgency: _selectedUrgency,
        relatedUserId: widget.relatedUserId,
        relatedEventId: widget.relatedEventId,
        relatedMessageId: widget.relatedMessageId,
        attachmentUrls: uploadedPaths,
      );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(Icons.check_circle_outline, size: 52),
            title: Text(
              _supportRequestText(
                context,
                tr: 'Talebin oluşturuldu',
                en: 'Request created',
                de: 'Anfrage erstellt',
              ),
              textAlign: TextAlign.center,
            ),
            content: Text(
              _supportRequestText(
                    context,
                    tr: 'Destek talebin başarıyla kaydedildi. ',
                    en: 'Your support request was saved successfully. ',
                    de: 'Deine Support-Anfrage wurde erfolgreich gespeichert. ',
                  ) +
                  _supportRequestText(
                    context,
                    tr: 'Durumunu Destek Merkezi ekranından takip edebilirsin.',
                    en: 'You can track its status from the Support Center.',
                    de: 'Du kannst den Status im Support-Center verfolgen.',
                  ),
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: <Widget>[
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Tamam'),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } on ArgumentError catch (error) {
      await SupportAttachmentService.deletePaths(uploadedPaths);
      _showError(
        error.message?.toString() ?? 'Talep bilgileri kontrol edilemedi.',
      );
    } on StateError catch (error) {
      await SupportAttachmentService.deletePaths(uploadedPaths);
      _showError(error.message);
    } catch (_) {
      await SupportAttachmentService.deletePaths(uploadedPaths);
      if (!mounted) return;
      _showError(
        _supportRequestText(
              context,
              tr: 'Talep oluşturulurken bir sorun oluştu. ',
              en: 'There was a problem creating the request. ',
              de: 'Beim Erstellen der Anfrage ist ein Problem aufgetreten. ',
            ) +
            _supportRequestText(
              context,
              tr: 'Lütfen tekrar dene.',
              en: 'Please try again.',
              de: 'Bitte versuche es erneut.',
            ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final SupportCategory category = widget.category;

    return Scaffold(
      appBar: AppBar(title: Text(category.title)),
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: <Widget>[
                  _CategoryHeader(category: category),
                  if (category.isCriticalCategory) ...<Widget>[
                    const SizedBox(height: 16),
                    const _EmergencyWarning(),
                  ],
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _subjectController,
                    enabled: !_isSubmitting,
                    textInputAction: TextInputAction.next,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: 'Konu',
                      hintText: _supportRequestText(
                        context,
                        tr: 'Talebini kısaca özetle',
                        en: 'Briefly summarize your request',
                        de: 'Fasse deine Anfrage kurz zusammen',
                      ),
                      prefixIcon: Icon(Icons.title),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final String subject = value?.trim() ?? '';

                      if (subject.isEmpty) {
                        return _supportRequestText(
                          context,
                          tr: 'Konu boş bırakılamaz.',
                          en: 'Subject cannot be empty.',
                          de: 'Der Betreff darf nicht leer sein.',
                        );
                      }

                      if (subject.length < 3) {
                        return _supportRequestText(
                          context,
                          tr: 'Konu en az 3 karakter olmalıdır.',
                          en: 'Subject must be at least 3 characters.',
                          de: 'Der Betreff muss mindestens 3 Zeichen lang sein.',
                        );
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descriptionController,
                    enabled: !_isSubmitting,
                    minLines: 6,
                    maxLines: 12,
                    maxLength: 3000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: _descriptionLabel,
                      hintText: _descriptionHint,
                      alignLabelWithHint: true,
                      prefixIcon: const Icon(Icons.notes_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final String description = value?.trim() ?? '';

                      if (description.isEmpty) {
                        return _supportRequestText(
                          context,
                          tr: 'Açıklama boş bırakılamaz.',
                          en: 'Description cannot be empty.',
                          de: 'Die Beschreibung darf nicht leer sein.',
                        );
                      }

                      if (description.length < 10) {
                        return _supportRequestText(
                          context,
                          tr: 'Açıklama en az 10 karakter olmalıdır.',
                          en: 'Description must be at least 10 characters.',
                          de: 'Die Beschreibung muss mindestens 10 Zeichen lang sein.',
                        );
                      }

                      return null;
                    },
                  ),
                  if (_hasRelatedReference) ...<Widget>[
                    const SizedBox(height: 16),
                    _RelatedReferenceCard(
                      relatedUserId: widget.relatedUserId,
                      relatedUserName: widget.relatedUserName,
                      relatedUserAvatarUrl: widget.relatedUserAvatarUrl,
                      relatedEventId: widget.relatedEventId,
                      relatedMessageId: widget.relatedMessageId,
                    ),
                  ],
                  const SizedBox(height: 16),
                  _AttachmentPickerCard(
                    attachments: _attachments,
                    enabled: !_isSubmitting,
                    onAdd: _pickScreenshots,
                    onRemove: _removeAttachment,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<SupportUrgency>(
                    initialValue: _selectedUrgency,
                    decoration: const InputDecoration(
                      labelText: 'Aciliyet seviyesi',
                      prefixIcon: Icon(Icons.priority_high_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: SupportUrgency.values
                        .map(
                          (urgency) => DropdownMenuItem<SupportUrgency>(
                            value: urgency,
                            child: Text(urgency.title),
                          ),
                        )
                        .toList(),
                    onChanged: category.isCriticalCategory || _isSubmitting
                        ? null
                        : (urgency) {
                            if (urgency == null) {
                              return;
                            }

                            setState(() {
                              _selectedUrgency = urgency;
                            });
                          },
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Ekran görüntüsü ekleme özelliği '
                                    'sonraki pakette bağlanacak.',
                                  ),
                                ),
                              );
                          },
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      _supportRequestText(
                        context,
                        tr: 'Ekran görüntüsü ekle',
                        en: 'Add screenshot',
                        de: 'Screenshot hinzufügen',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Gönderdiğin bilgiler yalnızca talebin '
                    'incelenmesi ve güvenlik işlemleri için kullanılır.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: const Icon(Icons.send_outlined),
                      label: Text(
                        _isSubmitting
                            ? _supportRequestText(
                                context,
                                tr: 'Gönderiliyor...',
                                en: 'Sending...',
                                de: 'Wird gesendet...',
                              )
                            : _supportRequestText(
                                context,
                                tr: 'Talebi gönder',
                                en: 'Send request',
                                de: 'Anfrage senden',
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isSubmitting)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  bool get _hasRelatedReference {
    return (widget.relatedUserId?.trim().isNotEmpty ?? false) ||
        (widget.relatedEventId?.trim().isNotEmpty ?? false) ||
        (widget.relatedMessageId?.trim().isNotEmpty ?? false);
  }
}

class _AttachmentPickerCard extends StatelessWidget {
  const _AttachmentPickerCard({
    required this.attachments,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
  });

  final List<SupportAttachmentDraft> attachments;
  final bool enabled;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final bool canAdd =
        enabled &&
        attachments.length < SupportAttachmentService.maxAttachmentCount;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.add_photo_alternate_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _supportRequestText(
                      context,
                      tr: 'Ekran görüntüsü / kanıt',
                      en: 'Screenshot / evidence',
                      de: 'Screenshot / Nachweis',
                    ),
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${attachments.length}/'
                  '${SupportAttachmentService.maxAttachmentCount}',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'İsteğe bağlı. JPG, PNG veya WEBP; dosya başına en fazla 5 MB.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (attachments.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              ...attachments.asMap().entries.map((entry) {
                final int index = entry.key;
                final SupportAttachmentDraft attachment = entry.value;
                final double sizeMb = attachment.sizeBytes / (1024 * 1024);

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.image_outlined),
                  title: Text(
                    attachment.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('${sizeMb.toStringAsFixed(1)} MB'),
                  trailing: IconButton(
                    tooltip: _supportRequestText(
                      context,
                      tr: 'Kaldır',
                      en: 'Remove',
                      de: 'Entfernen',
                    ),
                    onPressed: enabled ? () => onRemove(index) : null,
                    icon: const Icon(Icons.close),
                  ),
                );
              }),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: canAdd ? onAdd : null,
              icon: const Icon(Icons.attach_file),
              label: Text(
                canAdd
                    ? _supportRequestText(
                        context,
                        tr: 'Ekran görüntüsü ekle',
                        en: 'Add screenshot',
                        de: 'Screenshot hinzufügen',
                      )
                    : 'En fazla 3 dosya eklenebilir',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});

  final SupportCategory category;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 25,
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            child: Icon(category.icon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  category.title,
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  category.description,
                  style: TextStyle(color: colors.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyWarning extends StatelessWidget {
  const _EmergencyWarning();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.error),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.emergency_outlined, color: colors.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bu kategori güvenlik riski, tehdit veya acil durum '
              'bildirimleri içindir. Talepler öncelikli olarak '
              'incelenir. Devam eden fiziksel bir tehlike varsa '
              'yerel acil yardım birimlerine de ulaşmalısın.',
              style: TextStyle(
                color: colors.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedReferenceCard extends StatelessWidget {
  const _RelatedReferenceCard({
    required this.relatedUserId,
    required this.relatedUserName,
    required this.relatedUserAvatarUrl,
    required this.relatedEventId,
    required this.relatedMessageId,
  });

  final String? relatedUserId;
  final String? relatedUserName;
  final String? relatedUserAvatarUrl;
  final String? relatedEventId;
  final String? relatedMessageId;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];

    if (relatedUserId?.trim().isNotEmpty ?? false) {
      final suppliedName = relatedUserName?.trim() ?? '';
      rows.add(
        FutureBuilder(
          future: suppliedName.isNotEmpty
              ? null
              : GiftRecipientService().load(relatedUserId!),
          builder: (context, snapshot) {
            final resolved = snapshot.data;
            final name = suppliedName.isNotEmpty
                ? suppliedName
                : resolved?.displayName ??
                      _supportRequestText(
                        context,
                        tr: 'Profil bilgisi kullanılamıyor',
                        en: 'Profile information unavailable',
                        de: 'Profilinformationen nicht verfügbar',
                      );
            return _ReferenceRow(
              icon: Icons.person_outline,
              label: _supportRequestText(
                context,
                tr: 'İlgili kullanıcı',
                en: 'Related user',
                de: 'Betroffener Nutzer',
              ),
              value: name,
              avatarUrl: suppliedName.isNotEmpty
                  ? relatedUserAvatarUrl
                  : resolved?.avatarUrl,
            );
          },
        ),
      );
    }

    if (relatedEventId?.trim().isNotEmpty ?? false) {
      rows.add(
        _ReferenceRow(
          icon: Icons.event_outlined,
          label: _supportRequestText(
            context,
            tr: 'İlgili etkinlik',
            en: 'Related event',
            de: 'Betroffene Veranstaltung',
          ),
          value: relatedEventId!,
        ),
      );
    }

    if (relatedMessageId?.trim().isNotEmpty ?? false) {
      rows.add(
        _ReferenceRow(
          icon: Icons.message_outlined,
          label: _supportRequestText(
            context,
            tr: 'İlgili mesaj',
            en: 'Related message',
            de: 'Betroffene Nachricht',
          ),
          value: relatedMessageId!,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          for (int index = 0; index < rows.length; index++) ...<Widget>[
            rows[index],
            if (index != rows.length - 1) const Divider(height: 22),
          ],
        ],
      ),
    );
  }
}

class _ReferenceRow extends StatelessWidget {
  const _ReferenceRow({
    required this.icon,
    required this.label,
    required this.value,
    this.avatarUrl,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        if (avatarUrl != null)
          UserAvatar(displayName: value, imageUrl: avatarUrl!, radius: 18)
        else
          Icon(icon),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const Icon(Icons.lock_outline, size: 18),
      ],
    );
  }
}
