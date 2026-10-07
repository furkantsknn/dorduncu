import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/support_request_model.dart';
import '../services/support_service.dart';
import '../utils/support_categories.dart';
import 'create_support_request_screen.dart';

String _supportCenterText(
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


class SupportCenterScreen extends StatelessWidget {
  const SupportCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Destek Merkezi')),
      body: StreamBuilder<List<SupportRequestModel>>(
        stream: SupportService.watchCurrentUserRequests(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorView(onRetry: () {});
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<SupportRequestModel> requests =
              snapshot.data ?? const <SupportRequestModel>[];

          return RefreshIndicator(
            onRefresh: () async {
              await Future<void>.delayed(const Duration(milliseconds: 500));
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: _SupportHeader(
                    requestCount: requests.length,
                    onCreateRequest: () {
                      _showCategorySheet(context);
                    },
                  ),
                ),
                if (requests.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyView(),
                  )
                else ...<Widget>[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Text(
                        'Destek taleplerim',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: requests.length,
                      separatorBuilder: (_, _) {
                        return const SizedBox(height: 10);
                      },
                      itemBuilder: (context, index) {
                        return _SupportRequestCard(
                          request: requests[index],
                          onTap: () {
                            _showRequestSummary(context, requests[index]);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCategorySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.78,
            minChildSize: 0.45,
            maxChildSize: 0.92,
            builder: (context, scrollController) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
                    child: Text(
                      _supportCenterText(context, tr: 'Nasıl yardımcı olabiliriz?', en: 'How can we help?', de: 'Wie können wir helfen?'),
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Text(_supportCenterText(context, tr: 'Talebine en uygun kategoriyi seç.', en: 'Choose the category that best fits your request.', de: 'Wähle die passende Kategorie für deine Anfrage.')),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: SupportCategory.values.length,
                      separatorBuilder: (_, _) {
                        return const SizedBox(height: 4);
                      },
                      itemBuilder: (context, index) {
                        final SupportCategory category =
                            SupportCategory.values[index];

                        return ListTile(
                          leading: CircleAvatar(child: Icon(category.icon)),
                          title: Text(
                            category.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(category.description),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            Navigator.pop(sheetContext);

                            final bool? created = await Navigator.of(context)
                                .push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => CreateSupportRequestScreen(
                                      category: category,
                                    ),
                                  ),
                                );

                            if (!context.mounted) {
                              return;
                            }

                            if (created == true) {
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _supportCenterText(context, tr: 'Destek talebin başarıyla oluşturuldu.', en: 'Your support request was created successfully.', de: 'Deine Support-Anfrage wurde erfolgreich erstellt.'),
                                    ),
                                  ),
                                );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showRequestSummary(BuildContext context, SupportRequestModel request) {
    final DateTime? createdAt = request.createdAt?.toDate();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    CircleAvatar(child: Icon(request.category.icon)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            request.subject,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(request.category.title),
                        ],
                      ),
                    ),
                    _StatusBadge(status: request.status),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  _supportCenterText(context, tr: 'Açıklama', en: 'Description', de: 'Beschreibung'),
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(request.description),
                if (request.adminResponse.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 20),
                  Text(
                    _supportCenterText(context, tr: 'Destek ekibi cevabı', en: 'Support team response', de: 'Antwort des Support-Teams'),
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(request.adminResponse),
                  ),
                ],
                if (createdAt != null) ...<Widget>[
                  const SizedBox(height: 20),
                  Text(
                    'Oluşturulma: '
                    '${DateFormat('dd.MM.yyyy • HH:mm').format(createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SupportHeader extends StatelessWidget {
  const _SupportHeader({
    required this.requestCount,
    required this.onCreateRequest,
  });

  final int requestCount;
  final VoidCallback onCreateRequest;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.support_agent,
              size: 36,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            const SizedBox(height: 12),
            Text(
              _supportCenterText(context, tr: 'Yardıma mı ihtiyacın var?', en: 'Need help?', de: 'Brauchst du Hilfe?'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              requestCount == 0
                  ? _supportCenterText(context, tr: 'Öneri, hata, ödeme veya güvenlik konularında bize ulaşabilirsin.', en: 'You can contact us about suggestions, bugs, payments or security.', de: 'Du kannst uns zu Vorschlägen, Fehlern, Zahlungen oder Sicherheit kontaktieren.')
                  : '$requestCount destek talebin bulunuyor.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onCreateRequest,
              icon: const Icon(Icons.add),
              label: Text(_supportCenterText(context, tr: 'Yeni talep oluştur', en: 'Create new request', de: 'Neue Anfrage erstellen')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportRequestCard extends StatelessWidget {
  const _SupportRequestCard({required this.request, required this.onTap});

  final SupportRequestModel request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DateTime? createdAt = request.createdAt?.toDate();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                                ? request.category.title
                                : request.subject,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(status: request.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.category.title,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      request.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (createdAt != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('dd.MM.yyyy • HH:mm').format(createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (request.adminResponse.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Icon(Icons.mark_email_read_outlined, size: 17),
                          SizedBox(width: 5),
                          Text(
                            _supportCenterText(context, tr: 'Destek ekibi cevapladı', en: 'Support replied', de: 'Support hat geantwortet'),
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final SupportRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    Color backgroundColor;
    Color foregroundColor;

    switch (status) {
      case SupportRequestStatus.newRequest:
        backgroundColor = colors.secondaryContainer;
        foregroundColor = colors.onSecondaryContainer;
      case SupportRequestStatus.reviewing:
        backgroundColor = colors.tertiaryContainer;
        foregroundColor = colors.onTertiaryContainer;
      case SupportRequestStatus.answered:
        backgroundColor = colors.primaryContainer;
        foregroundColor = colors.onPrimaryContainer;
      case SupportRequestStatus.closed:
        backgroundColor = colors.surfaceContainerHighest;
        foregroundColor = colors.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.title,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.inbox_outlined, size: 64),
            SizedBox(height: 14),
            Text(
              _supportCenterText(context, tr: 'Henüz destek talebin yok', en: 'You have no support requests yet', de: 'Du hast noch keine Support-Anfragen'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 7),
            Text(
              _supportCenterText(context, tr: 'Yeni bir talep oluşturduğunda durumunu buradan takip edebilirsin.', en: 'When you create a request, you can track its status here.', de: 'Wenn du eine Anfrage erstellst, kannst du ihren Status hier verfolgen.'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 12),
            Text(
              _supportCenterText(context, tr: 'Destek talepleri yüklenemedi.', en: 'Support requests could not be loaded.', de: 'Support-Anfragen konnten nicht geladen werden.'),
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}
