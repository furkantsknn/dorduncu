import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/language_controller.dart';
import '../services/notification_service.dart';
import 'event_chat_screen.dart';
import 'event_detail_screen.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  String _selectedFilter = 'all';
  bool _actionBusy = false;

  static const List<String> _filters = <String>[
    'all',
    'unread',
    'event',
    'message',
    'payment',
    'account',
  ];

  _NotificationText get text =>
      _NotificationText(LanguageController.language.value);

  void _handleLanguageChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    LanguageController.language.addListener(_handleLanguageChanged);
  }

  @override
  void dispose() {
    LanguageController.language.removeListener(_handleLanguageChanged);
    super.dispose();
  }

  Future<void> _markAllRead() async {
    if (_actionBusy) {
      return;
    }

    setState(() {
      _actionBusy = true;
    });

    try {
      final int updatedCount = await NotificationService.markAllRead();

      if (updatedCount == 0) {
        _showMessage(text.noUnreadNotifications);
      } else {
        _showMessage(text.notificationsMarkedRead(updatedCount));
      }
    } on NotificationServiceException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage(text.notificationsUpdateFailed);
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<void> _clearNotifications() async {
    if (_actionBusy) {
      return;
    }

    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Text(text.clearNotificationsQuestion),
              content: Text(text.allNotificationsDeletedWarning),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: Text(text.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, true);
                  },
                  child: Text(text.clear),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    setState(() {
      _actionBusy = true;
    });

    try {
      final int deletedCount = await NotificationService.deleteAll();

      if (deletedCount == 0) {
        _showMessage(text.noNotificationsToDelete);
      } else {
        _showMessage(text.notificationsCleared);
      }
    } on NotificationServiceException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage(text.notificationsDeleteFailed);
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<void> _deleteNotification(AppNotification notification) async {
    try {
      await NotificationService.deleteNotification(
        notificationId: notification.id,
      );
    } on NotificationServiceException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage(text.notificationDeleteFailed);
    }
  }

  Future<void> _toggleRead(AppNotification notification) async {
    try {
      if (notification.isRead) {
        await NotificationService.markUnread(notificationId: notification.id);
      } else {
        await NotificationService.markRead(notificationId: notification.id);
      }
    } on NotificationServiceException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage(text.notificationUpdateFailed);
    }
  }

  Future<void> _openNotification(AppNotification notification) async {
    if (!notification.isRead) {
      try {
        await NotificationService.markRead(notificationId: notification.id);
      } catch (_) {
        // Bildirimin okundu olarak işaretlenmesi başarısız olsa da
        // ilgili ekran açılabilir.
      }
    }

    if (!mounted) {
      return;
    }

    if (notification.type == NotificationType.message &&
        notification.eventId.isNotEmpty) {
      final String title = notification.eventTitle.isEmpty
          ? text.eventChat
          : notification.eventTitle;

      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              EventChatScreen(eventId: notification.eventId, eventTitle: title),
        ),
      );

      return;
    }

    if (notification.eventId.isNotEmpty) {
      await _openEvent(notification.eventId);
      return;
    }

    _showNotificationDetails(notification);
  }

  Future<void> _openEvent(String eventId) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('events')
              .doc(eventId)
              .get();

      if (!mounted) {
        return;
      }

      final Map<String, dynamic>? data = snapshot.data();

      if (!snapshot.exists || data == null) {
        _showMessage(text.relatedEventNotFound);
        return;
      }

      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              EventDetailScreen(eventId: eventId, initialData: data),
        ),
      );
    } on FirebaseException catch (error) {
      _showMessage(error.message ?? text.eventOpenFailed);
    } catch (_) {
      _showMessage(text.eventOpenFailed);
    }
  }

  void _showNotificationDetails(AppNotification notification) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    CircleAvatar(child: Icon(_iconForType(notification.type))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        notification.title,
                        style: Theme.of(sheetContext).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  notification.body,
                  style: Theme.of(sheetContext).textTheme.bodyLarge,
                ),
                if (notification.createdAt != null) ...<Widget>[
                  const SizedBox(height: 14),
                  Text(
                    _fullDateText(notification.createdAt!),
                    style: Theme.of(sheetContext).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                    },
                    child: Text(text.close),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _matchesFilter(AppNotification notification) {
    switch (_selectedFilter) {
      case 'unread':
        return !notification.isRead;

      case 'event':
        return notification.type == NotificationType.application ||
            notification.type == NotificationType.applicationAccepted ||
            notification.type == NotificationType.applicationRejected ||
            notification.type == NotificationType.eventCancelled ||
            notification.type == NotificationType.eventUpdated ||
            notification.type == NotificationType.eventReminder;

      case 'message':
        return notification.type == NotificationType.message;

      case 'payment':
        return notification.type == NotificationType.payment ||
            notification.type == NotificationType.refund;

      case 'account':
        return notification.type == NotificationType.verification ||
            notification.type == NotificationType.system;

      default:
        return true;
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Text(
              text.loginRequired,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(text.notifications),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: text.markAllRead,
            onPressed: _actionBusy ? null : _markAllRead,
            icon: const Icon(Icons.done_all_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: text.notificationOptions,
            enabled: !_actionBusy,
            onSelected: (value) {
              if (value == 'clear') {
                _clearNotifications();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'clear',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_sweep_outlined),
                  title: Text(text.clearNotifications),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_actionBusy) const LinearProgressIndicator(),

          SizedBox(
            height: 58,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];

                return ChoiceChip(
                  label: Text(text.filterName(filter)),
                  selected: _selectedFilter == filter,
                  onSelected: (selected) {
                    if (!selected) return;

                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                );
              },
            ),
          ),

          Expanded(
            child: StreamBuilder<List<AppNotification>>(
              stream: NotificationService.watchNotifications(limit: 150),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  final error = snapshot.error;

                  return _ErrorState(
                    message: error is NotificationServiceException
                        ? error.message
                        : text.notificationsLoadFailed,
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final notifications = (snapshot.data ?? <AppNotification>[])
                    .where(_matchesFilter)
                    .toList(growable: false);

                if (notifications.isEmpty) {
                  return _EmptyState(
                    filtered: _selectedFilter != 'all',
                    text: text,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await Future.delayed(const Duration(milliseconds: 350));
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
                    itemCount: notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];

                      return Dismissible(
                        key: ValueKey(notification.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 22),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                        ),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) {
                                  return AlertDialog(
                                    title: Text(
                                      text.deleteNotificationQuestion,
                                    ),
                                    content: Text(
                                      text.deleteNotificationWarning,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(dialogContext, false);
                                        },
                                        child: Text(text.cancel),
                                      ),
                                      FilledButton(
                                        onPressed: () {
                                          Navigator.pop(dialogContext, true);
                                        },
                                        child: Text(text.delete),
                                      ),
                                    ],
                                  );
                                },
                              ) ??
                              false;
                        },
                        onDismissed: (_) {
                          _deleteNotification(notification);
                        },
                        child: _NotificationCard(
                          notification: notification,
                          onTap: () {
                            _openNotification(notification);
                          },
                          onReadToggle: () {
                            _toggleRead(notification);
                          },
                          text: text,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onReadToggle,
    required this.text,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onReadToggle;
  final _NotificationText text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Card(
      color: notification.isRead ? null : colors.primaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _NotificationAvatar(notification: notification),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: notification.isRead
                                  ? FontWeight.w700
                                  : FontWeight.w900,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: const BoxDecoration(
                              color: Color(0xffFF9800),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (notification.body.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 5),
                      Text(
                        notification.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Text(
                          _timeText(notification.createdAt, text),
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          text.notificationTypeName(notification.type),
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: notification.isRead ? text.markUnread : text.markRead,
                onPressed: onReadToggle,
                icon: Icon(
                  notification.isRead
                      ? Icons.mark_email_unread_outlined
                      : Icons.done_all_rounded,
                  size: 21,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationAvatar extends StatelessWidget {
  const _NotificationAvatar({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final String photoUrl = notification.senderPhotoUrl;

    return CircleAvatar(
      radius: 24,
      backgroundImage: photoUrl.isEmpty ? null : NetworkImage(photoUrl),
      child: photoUrl.isEmpty ? Icon(_iconForType(notification.type)) : null,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered, required this.text});

  final bool filtered;
  final _NotificationText text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 42,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              filtered ? text.noNotificationsInFilter : text.noNotificationsYet,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(
              filtered
                  ? text.chooseAnotherFilter
                  : text.notificationsWillAppearHere,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline_rounded, size: 54),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconForType(NotificationType type) {
  switch (type) {
    case NotificationType.application:
      return Icons.person_add_alt_1_rounded;

    case NotificationType.applicationAccepted:
      return Icons.check_circle_outline_rounded;

    case NotificationType.applicationRejected:
      return Icons.cancel_outlined;

    case NotificationType.message:
      return Icons.chat_bubble_outline_rounded;

    case NotificationType.eventCancelled:
      return Icons.event_busy_rounded;

    case NotificationType.eventUpdated:
      return Icons.event_note_rounded;

    case NotificationType.eventReminder:
      return Icons.alarm_rounded;

    case NotificationType.payment:
      return Icons.payments_outlined;

    case NotificationType.refund:
      return Icons.currency_exchange_rounded;

    case NotificationType.verification:
      return Icons.verified_user_outlined;

    case NotificationType.friendRequest:
      return Icons.person_add_alt_1_rounded;

    case NotificationType.friendAccepted:
      return Icons.handshake_rounded;

    case NotificationType.system:
      return Icons.info_outline_rounded;

    case NotificationType.unknown:
      return Icons.notifications_none_rounded;
  }
}

String _timeText(DateTime? date, _NotificationText text) {
  if (date == null) {
    return '';
  }

  final DateTime now = DateTime.now();
  final Duration difference = now.difference(date);

  if (difference.isNegative) {
    return _fullDateText(date);
  }

  if (difference.inMinutes < 1) {
    return text.now;
  }

  if (difference.inMinutes < 60) {
    return text.minutesAgo(difference.inMinutes);
  }

  if (difference.inHours < 24) {
    return text.hoursAgo(difference.inHours);
  }

  if (difference.inDays == 1) {
    return text.yesterday;
  }

  if (difference.inDays < 7) {
    return text.daysAgo(difference.inDays);
  }

  return _fullDateText(date);
}

String _fullDateText(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year} • '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

class _NotificationText {
  const _NotificationText(this.language);

  final AppLanguage language;

  String v(String tr, String en, String de) {
    switch (language) {
      case AppLanguage.turkish:
        return tr;
      case AppLanguage.english:
        return en;
      case AppLanguage.german:
        return de;
    }
  }

  String get notifications =>
      v('Bildirimler', 'Notifications', 'Benachrichtigungen');

  String get loginRequired => v(
    'Bildirimleri görmek için giriş yapmalısın.',
    'You must sign in to view your notifications.',
    'Du musst dich anmelden, um deine Benachrichtigungen anzusehen.',
  );

  String get markAllRead =>
      v('Tümünü okundu yap', 'Mark all as read', 'Alle als gelesen markieren');

  String get notificationOptions => v(
    'Bildirim seçenekleri',
    'Notification options',
    'Benachrichtigungsoptionen',
  );

  String get clearNotifications => v(
    'Bildirimleri temizle',
    'Clear notifications',
    'Benachrichtigungen löschen',
  );

  String get clearNotificationsQuestion => v(
    'Bildirimler temizlensin mi?',
    'Clear notifications?',
    'Benachrichtigungen löschen?',
  );

  String get allNotificationsDeletedWarning => v(
    'Tüm bildirimler kalıcı olarak silinecek.',
    'All notifications will be permanently deleted.',
    'Alle Benachrichtigungen werden dauerhaft gelöscht.',
  );

  String get cancel => v('Vazgeç', 'Cancel', 'Abbrechen');

  String get clear => v('Temizle', 'Clear', 'Löschen');

  String get delete => v('Sil', 'Delete', 'Löschen');

  String get close => v('Kapat', 'Close', 'Schließen');

  String get noUnreadNotifications => v(
    'Okunmamış bildirim bulunmuyor.',
    'There are no unread notifications.',
    'Es gibt keine ungelesenen Benachrichtigungen.',
  );

  String notificationsMarkedRead(int count) => v(
    '$count bildirim okundu olarak işaretlendi.',
    '$count notifications were marked as read.',
    '$count Benachrichtigungen wurden als gelesen markiert.',
  );

  String get notificationsUpdateFailed => v(
    'Bildirimler güncellenemedi.',
    'Notifications could not be updated.',
    'Die Benachrichtigungen konnten nicht aktualisiert werden.',
  );

  String get noNotificationsToDelete => v(
    'Silinecek bildirim bulunmuyor.',
    'There are no notifications to delete.',
    'Es gibt keine Benachrichtigungen zum Löschen.',
  );

  String get notificationsCleared => v(
    'Bildirimler temizlendi.',
    'Notifications were cleared.',
    'Die Benachrichtigungen wurden gelöscht.',
  );

  String get notificationsDeleteFailed => v(
    'Bildirimler silinemedi.',
    'Notifications could not be deleted.',
    'Die Benachrichtigungen konnten nicht gelöscht werden.',
  );

  String get notificationDeleteFailed => v(
    'Bildirim silinemedi.',
    'The notification could not be deleted.',
    'Die Benachrichtigung konnte nicht gelöscht werden.',
  );

  String get notificationUpdateFailed => v(
    'Bildirim güncellenemedi.',
    'The notification could not be updated.',
    'Die Benachrichtigung konnte nicht aktualisiert werden.',
  );

  String get deleteNotificationQuestion => v(
    'Bildirim silinsin mi?',
    'Delete notification?',
    'Benachrichtigung löschen?',
  );

  String get deleteNotificationWarning => v(
    'Bu bildirim kalıcı olarak silinecek.',
    'This notification will be permanently deleted.',
    'Diese Benachrichtigung wird dauerhaft gelöscht.',
  );

  String get eventChat =>
      v('Etkinlik Sohbeti', 'Event Chat', 'Veranstaltungschat');

  String get relatedEventNotFound => v(
    'İlgili etkinlik artık bulunamıyor.',
    'The related event is no longer available.',
    'Die zugehörige Veranstaltung ist nicht mehr verfügbar.',
  );

  String get eventOpenFailed => v(
    'Etkinlik açılamadı.',
    'The event could not be opened.',
    'Die Veranstaltung konnte nicht geöffnet werden.',
  );

  String get notificationsLoadFailed => v(
    'Bildirimler yüklenemedi.',
    'Notifications could not be loaded.',
    'Die Benachrichtigungen konnten nicht geladen werden.',
  );

  String get markUnread =>
      v('Okunmamış yap', 'Mark as unread', 'Als ungelesen markieren');

  String get markRead =>
      v('Okundu yap', 'Mark as read', 'Als gelesen markieren');

  String get noNotificationsInFilter => v(
    'Bu filtrede bildirim yok',
    'There are no notifications in this filter',
    'In diesem Filter gibt es keine Benachrichtigungen',
  );

  String get noNotificationsYet => v(
    'Henüz bildirimin yok',
    'You do not have any notifications yet',
    'Du hast noch keine Benachrichtigungen',
  );

  String get chooseAnotherFilter => v(
    'Başka bir filtre seçerek bildirimlerini görüntüleyebilirsin.',
    'Choose another filter to view your notifications.',
    'Wähle einen anderen Filter, um deine Benachrichtigungen anzuzeigen.',
  );

  String get notificationsWillAppearHere => v(
    'Etkinlik, mesaj ve hesap bildirimlerin burada görünecek.',
    'Your event, message, and account notifications will appear here.',
    'Deine Veranstaltungs-, Nachrichten- und Kontobenachrichtigungen werden hier angezeigt.',
  );

  String filterName(String filter) {
    switch (filter) {
      case 'unread':
        return v('Okunmamış', 'Unread', 'Ungelesen');
      case 'event':
        return v('Etkinlik', 'Event', 'Veranstaltung');
      case 'message':
        return v('Mesaj', 'Message', 'Nachricht');
      case 'payment':
        return v('Ödeme', 'Payment', 'Zahlung');
      case 'account':
        return v('Hesap', 'Account', 'Konto');
      default:
        return v('Tümü', 'All', 'Alle');
    }
  }

  String notificationTypeName(NotificationType type) {
    switch (type) {
      case NotificationType.application:
        return v('Başvuru', 'Application', 'Bewerbung');

      case NotificationType.applicationAccepted:
        return v(
          'Başvuru kabul edildi',
          'Application accepted',
          'Bewerbung angenommen',
        );

      case NotificationType.applicationRejected:
        return v(
          'Başvuru reddedildi',
          'Application rejected',
          'Bewerbung abgelehnt',
        );

      case NotificationType.message:
        return v('Mesaj', 'Message', 'Nachricht');

      case NotificationType.eventCancelled:
        return v(
          'Etkinlik iptal edildi',
          'Event cancelled',
          'Veranstaltung abgesagt',
        );

      case NotificationType.eventUpdated:
        return v(
          'Etkinlik güncellendi',
          'Event updated',
          'Veranstaltung aktualisiert',
        );

      case NotificationType.eventReminder:
        return v(
          'Etkinlik hatırlatması',
          'Event reminder',
          'Veranstaltungserinnerung',
        );

      case NotificationType.payment:
        return v('Ödeme', 'Payment', 'Zahlung');

      case NotificationType.refund:
        return v('İade', 'Refund', 'Rückerstattung');

      case NotificationType.verification:
        return v('Doğrulama', 'Verification', 'Verifizierung');

      case NotificationType.friendRequest:
        return 'Arkadaşlık İsteği';

      case NotificationType.friendAccepted:
        return 'Arkadaşlık Kabul Edildi';

      case NotificationType.system:
        return v('Sistem', 'System', 'System');

      case NotificationType.unknown:
        return v('Bildirim', 'Notification', 'Benachrichtigung');
    }
  }

  String get now => v('Şimdi', 'Now', 'Jetzt');

  String minutesAgo(int minutes) =>
      v('$minutes dk önce', '$minutes min ago', 'vor $minutes Min.');

  String hoursAgo(int hours) =>
      v('$hours sa önce', '$hours hr ago', 'vor $hours Std.');

  String get yesterday => v('Dün', 'Yesterday', 'Gestern');

  String daysAgo(int days) =>
      v('$days gün önce', '$days days ago', 'vor $days Tagen');
}
