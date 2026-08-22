import 'package:flutter/material.dart';

import '../services/support_service.dart';
import '../utils/support_categories.dart';

class CreateSupportRequestScreen extends StatefulWidget {
  const CreateSupportRequestScreen({
    super.key,
    required this.category,
    this.relatedUserId,
    this.relatedEventId,
    this.relatedMessageId,
  });

  final SupportCategory category;
  final String? relatedUserId;
  final String? relatedEventId;
  final String? relatedMessageId;

  @override
  State<CreateSupportRequestScreen> createState() =>
      _CreateSupportRequestScreenState();
}

class _CreateSupportRequestScreenState
    extends State<CreateSupportRequestScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _subjectController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();

  SupportUrgency _selectedUrgency = SupportUrgency.normal;

  bool _isSubmitting = false;

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
        return 'Önerin';
      case SupportCategory.bugReport:
        return 'Hata açıklaması';
      case SupportCategory.generalSupport:
        return 'Destek talebin';
      case SupportCategory.paymentIssue:
        return 'Ödeme sorununun açıklaması';
      case SupportCategory.accountAppeal:
        return 'İtiraz açıklaması';
      case SupportCategory.userReport:
        return 'Şikâyet açıklaması';
      case SupportCategory.eventReport:
        return 'Etkinlikle ilgili açıklama';
      case SupportCategory.messageReport:
        return 'Mesajla ilgili açıklama';
      case SupportCategory.inappropriateImage:
        return 'Görselle ilgili açıklama';
      case SupportCategory.securityEmergency:
        return 'Güvenlik durumu açıklaması';
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

    try {
      await SupportService.createRequest(
        category: widget.category,
        subject: _subjectController.text,
        description: _descriptionController.text,
        urgency: _selectedUrgency,
        relatedUserId: widget.relatedUserId,
        relatedEventId: widget.relatedEventId,
        relatedMessageId: widget.relatedMessageId,
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
            title: const Text(
              'Talebin oluşturuldu',
              textAlign: TextAlign.center,
            ),
            content: const Text(
              'Destek talebin başarıyla kaydedildi. '
              'Durumunu Destek Merkezi ekranından takip edebilirsin.',
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
      _showError(
        error.message?.toString() ?? 'Talep bilgileri kontrol edilemedi.',
      );
    } on StateError catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError(
        'Talep oluşturulurken bir sorun oluştu. '
        'Lütfen tekrar dene.',
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
                    decoration: const InputDecoration(
                      labelText: 'Konu',
                      hintText: 'Talebini kısaca özetle',
                      prefixIcon: Icon(Icons.title),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final String subject = value?.trim() ?? '';

                      if (subject.isEmpty) {
                        return 'Konu boş bırakılamaz.';
                      }

                      if (subject.length < 3) {
                        return 'Konu en az 3 karakter olmalıdır.';
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
                        return 'Açıklama boş bırakılamaz.';
                      }

                      if (description.length < 10) {
                        return 'Açıklama en az 10 karakter olmalıdır.';
                      }

                      return null;
                    },
                  ),
                  if (_hasRelatedReference) ...<Widget>[
                    const SizedBox(height: 16),
                    _RelatedReferenceCard(
                      relatedUserId: widget.relatedUserId,
                      relatedEventId: widget.relatedEventId,
                      relatedMessageId: widget.relatedMessageId,
                    ),
                  ],
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
                    label: const Text('Ekran görüntüsü ekle'),
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
                        _isSubmitting ? 'Gönderiliyor...' : 'Talebi gönder',
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
    required this.relatedEventId,
    required this.relatedMessageId,
  });

  final String? relatedUserId;
  final String? relatedEventId;
  final String? relatedMessageId;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];

    if (relatedUserId?.trim().isNotEmpty ?? false) {
      rows.add(
        _ReferenceRow(
          icon: Icons.person_outline,
          label: 'İlgili kullanıcı',
          value: relatedUserId!,
        ),
      );
    }

    if (relatedEventId?.trim().isNotEmpty ?? false) {
      rows.add(
        _ReferenceRow(
          icon: Icons.event_outlined,
          label: 'İlgili etkinlik',
          value: relatedEventId!,
        ),
      );
    }

    if (relatedMessageId?.trim().isNotEmpty ?? false) {
      rows.add(
        _ReferenceRow(
          icon: Icons.message_outlined,
          label: 'İlgili mesaj',
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
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
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
