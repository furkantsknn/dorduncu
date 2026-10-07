import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/support_request_model.dart';
import '../services/support_service.dart';
import '../utils/support_categories.dart';

class SupportRequestDetailScreen extends StatefulWidget {
  const SupportRequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<SupportRequestDetailScreen> createState() =>
      _SupportRequestDetailScreenState();
}

class _SupportRequestDetailScreenState
    extends State<SupportRequestDetailScreen> {
  final TextEditingController _replyController = TextEditingController();
  bool _sending = false;
  bool _changingStatus = false;

  @override
  void initState() {
    super.initState();
    SupportService.markMessagesAsRead(widget.requestId).catchError((_) {});
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final String text = _replyController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);

    try {
      await SupportService.sendMessage(
        requestId: widget.requestId,
        message: text,
      );

      _replyController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              context,
              'Yanıtın gönderildi.',
              'Your reply was sent.',
              'Deine Antwort wurde gesendet.',
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _changeStatus(bool close) async {
    if (_changingStatus) return;
    setState(() => _changingStatus = true);

    try {
      if (close) {
        await SupportService.closeOwnRequest(widget.requestId);
      } else {
        await SupportService.reopenOwnRequest(widget.requestId);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _changingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SupportRequestModel?>(
      stream: SupportService.watchRequest(widget.requestId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                _t(
                  context,
                  'Talep Detayı',
                  'Request Details',
                  'Anfragedetails',
                ),
              ),
            ),
            body: Center(
              child: Text(
                _t(
                  context,
                  'Talep yüklenemedi.',
                  'Request could not be loaded.',
                  'Anfrage konnte nicht geladen werden.',
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                _t(
                  context,
                  'Talep Detayı',
                  'Request Details',
                  'Anfragedetails',
                ),
              ),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final SupportRequestModel? request = snapshot.data;
        if (request == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                _t(
                  context,
                  'Talep Detayı',
                  'Request Details',
                  'Anfragedetails',
                ),
              ),
            ),
            body: Center(
              child: Text(
                _t(
                  context,
                  'Talep bulunamadı.',
                  'Request not found.',
                  'Anfrage nicht gefunden.',
                ),
              ),
            ),
          );
        }

        final bool closed = request.status == SupportRequestStatus.closed;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              request.ticketId.isEmpty
                  ? _t(
                      context,
                      'Talep Detayı',
                      'Request Details',
                      'Anfragedetails',
                    )
                  : request.ticketId,
            ),
            actions: <Widget>[
              if (!_changingStatus)
                TextButton(
                  onPressed: () => _changeStatus(!closed),
                  child: Text(
                    closed
                        ? _t(context, 'Yeniden aç', 'Reopen', 'Wieder öffnen')
                        : _t(context, 'Kapat', 'Close', 'Schließen'),
                  ),
                ),
            ],
          ),
          body: Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  children: <Widget>[
                    _RequestSummary(request: request),
                    const SizedBox(height: 18),
                    Text(
                      _t(
                        context,
                        'Mesaj geçmişi',
                        'Conversation',
                        'Nachrichtenverlauf',
                      ),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _MessageHistory(requestId: widget.requestId),
                    const SizedBox(height: 18),
                    Text(
                      _t(
                        context,
                        'İşlem geçmişi',
                        'Activity history',
                        'Aktivitätsverlauf',
                      ),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _History(requestId: widget.requestId),
                  ],
                ),
              ),
              if (!closed)
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _replyController,
                            minLines: 1,
                            maxLines: 5,
                            maxLength: 4000,
                            decoration: InputDecoration(
                              hintText: _t(
                                context,
                                'Yanıtını yaz',
                                'Write a reply',
                                'Antwort schreiben',
                              ),
                              counterText: '',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _sending ? null : _sendReply,
                          icon: _sending
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RequestSummary extends StatelessWidget {
  const _RequestSummary({required this.request});

  final SupportRequestModel request;

  @override
  Widget build(BuildContext context) {
    final DateTime? created = request.createdAt?.toDate();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(child: Icon(request.category.icon)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    request.subject,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Chip(label: Text(_statusTitle(context, request.status))),
              ],
            ),
            const SizedBox(height: 12),
            Text(request.description),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                Chip(label: Text(_categoryTitle(context, request.category))),
                Chip(label: Text(_urgencyTitle(context, request.urgency))),
                if (created != null)
                  Chip(
                    label: Text(
                      DateFormat('dd.MM.yyyy • HH:mm').format(created),
                    ),
                  ),
              ],
            ),
            if (request.attachmentUrls.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  const Icon(Icons.attach_file, size: 18),
                  const SizedBox(width: 5),
                  Text(
                    _t(
                      context,
                      '${request.attachmentUrls.length} ek dosya',
                      '${request.attachmentUrls.length} attachment(s)',
                      '${request.attachmentUrls.length} Anhang/Anhänge',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageHistory extends StatelessWidget {
  const _MessageHistory({required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: SupportService.watchMessages(requestId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: LinearProgressIndicator());
        }

        final documents = snapshot.data!.docs;

        if (documents.isEmpty) {
          return Text(
            _t(
              context,
              'Henüz mesaj yok.',
              'No messages yet.',
              'Noch keine Nachrichten.',
            ),
          );
        }

        return Column(
          children: documents.map((document) {
            final data = document.data();
            final bool deleted = data['deleted'] == true;
            final String role = data['senderRole']?.toString() ?? 'user';
            final bool admin = role == 'admin';
            final String message = deleted
                ? _t(
                    context,
                    'Bu mesaj silindi.',
                    'This message was deleted.',
                    'Diese Nachricht wurde gelöscht.',
                  )
                : data['message']?.toString() ?? '';
            final Timestamp? ts = data['createdAt'] as Timestamp?;

            return Align(
              alignment: admin ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: admin
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      admin
                          ? _t(
                              context,
                              'Destek Ekibi',
                              'Support Team',
                              'Support-Team',
                            )
                          : _t(context, 'Sen', 'You', 'Du'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(message),
                    if (ts != null) ...<Widget>[
                      const SizedBox(height: 5),
                      Text(
                        DateFormat('dd.MM.yyyy • HH:mm').format(ts.toDate()),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: SupportService.watchRequestHistory(requestId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: LinearProgressIndicator());
        }

        final documents = snapshot.data!.docs;
        if (documents.isEmpty) {
          return Text(
            _t(
              context,
              'İşlem geçmişi yok.',
              'No activity history.',
              'Kein Aktivitätsverlauf.',
            ),
          );
        }

        return Column(
          children: documents.map((document) {
            final data = document.data();
            final String action = data['action']?.toString() ?? '';
            final Timestamp? ts = data['createdAt'] as Timestamp?;

            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history, size: 20),
              title: Text(_historyTitle(context, action)),
              subtitle: ts == null
                  ? null
                  : Text(DateFormat('dd.MM.yyyy • HH:mm').format(ts.toDate())),
            );
          }).toList(),
        );
      },
    );
  }
}

String _historyTitle(BuildContext context, String action) {
  switch (action) {
    case 'created':
      return _t(
        context,
        'Talep oluşturuldu',
        'Request created',
        'Anfrage erstellt',
      );
    case 'status_changed':
      return _t(
        context,
        'Durum güncellendi',
        'Status updated',
        'Status aktualisiert',
      );
    case 'admin_response_added':
      return _t(
        context,
        'Destek ekibi yanıtladı',
        'Support replied',
        'Support hat geantwortet',
      );
    case 'message_sent':
      return _t(
        context,
        'Mesaj gönderildi',
        'Message sent',
        'Nachricht gesendet',
      );
    case 'closed_by_user':
      return _t(
        context,
        'Talep kapatıldı',
        'Request closed',
        'Anfrage geschlossen',
      );
    case 'reopened_by_user':
      return _t(
        context,
        'Talep yeniden açıldı',
        'Request reopened',
        'Anfrage wieder geöffnet',
      );
    default:
      return _t(
        context,
        'Talep güncellendi',
        'Request updated',
        'Anfrage aktualisiert',
      );
  }
}

String _statusTitle(BuildContext context, SupportRequestStatus status) {
  switch (status) {
    case SupportRequestStatus.newRequest:
      return _t(context, 'Yeni', 'New', 'Neu');
    case SupportRequestStatus.reviewing:
      return _t(context, 'İnceleniyor', 'Under review', 'Wird geprüft');
    case SupportRequestStatus.answered:
      return _t(context, 'Yanıtlandı', 'Answered', 'Beantwortet');
    case SupportRequestStatus.closed:
      return _t(context, 'Kapatıldı', 'Closed', 'Geschlossen');
  }
}

String _urgencyTitle(BuildContext context, SupportUrgency urgency) {
  switch (urgency) {
    case SupportUrgency.low:
      return _t(context, 'Düşük', 'Low', 'Niedrig');
    case SupportUrgency.normal:
      return _t(context, 'Normal', 'Normal', 'Normal');
    case SupportUrgency.high:
      return _t(context, 'Yüksek', 'High', 'Hoch');
    case SupportUrgency.critical:
      return _t(context, 'Kritik', 'Critical', 'Kritisch');
  }
}

String _categoryTitle(BuildContext context, SupportCategory category) {
  final String lang = Localizations.localeOf(context).languageCode;
  const Map<String, List<String>> labels = <String, List<String>>{
    'suggestion': <String>['Öneri', 'Suggestion', 'Vorschlag'],
    'bug_report': <String>['Hata bildirimi', 'Bug report', 'Fehlermeldung'],
    'general_support': <String>[
      'Genel destek',
      'General support',
      'Allgemeiner Support',
    ],
    'payment_issue': <String>[
      'Ödeme sorunu',
      'Payment issue',
      'Zahlungsproblem',
    ],
    'account_appeal': <String>[
      'Hesap itirazı',
      'Account appeal',
      'Kontoeinspruch',
    ],
    'user_report': <String>[
      'Kullanıcı şikâyeti',
      'User report',
      'Nutzermeldung',
    ],
    'event_report': <String>[
      'Etkinlik şikâyeti',
      'Event report',
      'Eventmeldung',
    ],
    'message_report': <String>[
      'Mesaj şikâyeti',
      'Message report',
      'Nachrichtenmeldung',
    ],
    'inappropriate_image': <String>[
      'Uygunsuz görsel',
      'Inappropriate image',
      'Unangemessenes Bild',
    ],
    'security_emergency': <String>[
      'Güvenlik bildirimi',
      'Safety report',
      'Sicherheitsmeldung',
    ],
  };

  final List<String> values =
      labels[category.value] ??
      <String>[category.value, category.value, category.value];

  if (lang == 'en') return values[1];
  if (lang == 'de') return values[2];
  return values[0];
}

String _t(BuildContext context, String tr, String en, String de) {
  final String lang = Localizations.localeOf(context).languageCode;
  if (lang == 'en') return en;
  if (lang == 'de') return de;
  return tr;
}
