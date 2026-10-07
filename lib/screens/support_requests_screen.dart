import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/support_request_model.dart';
import '../services/support_service.dart';
import '../utils/support_categories.dart';
import 'support_request_detail_screen.dart';

class SupportRequestsScreen extends StatelessWidget {
  const SupportRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _t(
            context,
            'Destek Taleplerim',
            'My Support Requests',
            'Meine Supportanfragen',
          ),
        ),
      ),
      body: StreamBuilder<List<SupportRequestModel>>(
        stream: SupportService.watchCurrentUserRequests(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _StateView(
              icon: Icons.cloud_off_outlined,
              title: _t(
                context,
                'Talepler yüklenemedi',
                'Requests could not be loaded',
                'Anfragen konnten nicht geladen werden',
              ),
              message: _t(
                context,
                'Bağlantını kontrol edip tekrar dene.',
                'Check your connection and try again.',
                'Prüfe deine Verbindung und versuche es erneut.',
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<SupportRequestModel> requests =
              snapshot.data ?? const <SupportRequestModel>[];

          if (requests.isEmpty) {
            return _StateView(
              icon: Icons.inbox_outlined,
              title: _t(
                context,
                'Henüz destek talebin yok',
                'No support requests yet',
                'Noch keine Supportanfragen',
              ),
              message: _t(
                context,
                'Oluşturduğun talepler ve yanıtları burada görebilirsin.',
                'Your requests and replies will appear here.',
                'Deine Anfragen und Antworten werden hier angezeigt.',
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final SupportRequestModel request = requests[index];
              final DateTime? createdAt = request.createdAt?.toDate();

              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            SupportRequestDetailScreen(requestId: request.id),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        CircleAvatar(child: Icon(request.category.icon)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      request.subject.isEmpty
                                          ? _categoryTitle(
                                              context,
                                              request.category,
                                            )
                                          : request.subject,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _StatusBadge(status: request.status),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _categoryTitle(context, request.category),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (request.lastMessage
                                  .trim()
                                  .isNotEmpty) ...<Widget>[
                                const SizedBox(height: 8),
                                Text(
                                  request.lastMessage,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: <Widget>[
                                  if (request.adminResponse.trim().isNotEmpty)
                                    const Icon(
                                      Icons.mark_email_read_outlined,
                                      size: 17,
                                    ),
                                  if (request.adminResponse.trim().isNotEmpty)
                                    const SizedBox(width: 5),
                                  if (request.adminResponse.trim().isNotEmpty)
                                    Text(
                                      _t(
                                        context,
                                        'Destek ekibi yanıtladı',
                                        'Support replied',
                                        'Support hat geantwortet',
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  const Spacer(),
                                  if (createdAt != null)
                                    Text(
                                      DateFormat(
                                        'dd.MM.yyyy',
                                      ).format(createdAt),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ],
                          ),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final SupportRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color background;
    final Color foreground;

    switch (status) {
      case SupportRequestStatus.newRequest:
        background = colors.secondaryContainer;
        foreground = colors.onSecondaryContainer;
      case SupportRequestStatus.reviewing:
        background = colors.tertiaryContainer;
        foreground = colors.onTertiaryContainer;
      case SupportRequestStatus.answered:
        background = colors.primaryContainer;
        foreground = colors.onPrimaryContainer;
      case SupportRequestStatus.closed:
        background = colors.surfaceContainerHighest;
        foreground = colors.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusTitle(context, status),
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StateView extends StatelessWidget {
  const _StateView({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 58),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
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
