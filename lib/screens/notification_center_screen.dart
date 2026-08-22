import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import 'event_chat_screen.dart';
import 'event_detail_screen.dart';
import 'public_profile_screen.dart';

String _notificationText(
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

String _filterText(BuildContext context, String filter) {
  switch (filter) {
    case 'Okunmamış':
      return _notificationText(
        context,
        tr: 'Okunmamış',
        en: 'Unread',
        de: 'Ungelesen',
      );
    case 'Etkinlik':
      return _notificationText(
        context,
        tr: 'Etkinlik',
        en: 'Event',
        de: 'Veranstaltung',
      );
    case 'Mesaj':
      return _notificationText(
        context,
        tr: 'Mesaj',
        en: 'Message',
        de: 'Nachricht',
      );
    case 'Ödeme':
      return _notificationText(
        context,
        tr: 'Ödeme',
        en: 'Payment',
        de: 'Zahlung',
      );
    case 'Hesap':
      return _notificationText(
        context,
        tr: 'Hesap',
        en: 'Account',
        de: 'Konto',
      );
    default:
      return _notificationText(
        context,
        tr: 'Tümü',
        en: 'All',
        de: 'Alle',
      );
  }
}

String _notificationTypeText(
    BuildContext context,
    NotificationType type,
    ) {
  switch (type) {

    case NotificationType.application:
      return _notificationText(
        context,
        tr: 'Başvuru',
        en: 'Application',
        de: 'Bewerbung',
      );
    case NotificationType.applicationAccepted:
      return _notificationText(
        context,
        tr: 'Başvuru kabul edildi',
        en: 'Application accepted',
        de: 'Bewerbung angenommen',
      );
    case NotificationType.applicationRejected:
      return _notificationText(
        context,
        tr: 'Başvuru reddedildi',
        en: 'Application rejected',
        de: 'Bewerbung abgelehnt',
      );
    case NotificationType.message:
      return _notificationText(
        context,
        tr: 'Mesaj',
        en: 'Message',
        de: 'Nachricht',
      );
    case NotificationType.eventCancelled:
      return _notificationText(
        context,
        tr: 'Etkinlik iptal edildi',
        en: 'Event cancelled',
        de: 'Veranstaltung abgesagt',
      );
    case NotificationType.eventUpdated:
      return _notificationText(
        context,
        tr: 'Etkinlik güncellendi',
        en: 'Event updated',
        de: 'Veranstaltung aktualisiert',
      );
    case NotificationType.eventReminder:
      return _notificationText(
        context,
        tr: 'Etkinlik hatırlatması',
        en: 'Event reminder',
        de: 'Veranstaltungserinnerung',
      );
    case NotificationType.payment:
      return _notificationText(
        context,
        tr: 'Ödeme',
        en: 'Payment',
        de: 'Zahlung',
      );
    case NotificationType.refund:
      return _notificationText(
        context,
        tr: 'İade',
        en: 'Refund',
        de: 'Rückerstattung',
      );
    case NotificationType.verification:
      return _notificationText(
        context,
        tr: 'Doğrulama',
        en: 'Verification',
        de: 'Verifizierung',
      );
    case NotificationType.friendRequest:
      return _notificationText(
        context,
        tr: 'Arkadaşlık İsteği',
        en: 'Friend Request',
        de: 'Freundschaftsanfrage',
      );

    case NotificationType.friendAccepted:
      return _notificationText(
        context,
        tr: 'Arkadaşlık Kabul Edildi',
        en: 'Friend Request Accepted',
        de: 'Freundschaft akzeptiert',
      );
    case NotificationType.system:
      return _notificationText(
        context,
        tr: 'Sistem',
        en: 'System',
        de: 'System',
      );
    case NotificationType.unknown:
      return _notificationText(
        context,
        tr: 'Bildirim',
        en: 'Notification',
        de: 'Benachrichtigung',
      );
  }
}

class NotificationCenterScreen
    extends StatefulWidget {
  const NotificationCenterScreen({
    super.key,
  });

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends State<NotificationCenterScreen> {
  String _selectedFilter = 'Tümü';
  bool _actionBusy = false;

  static const List<String> _filters =
  <String>[
    'Tümü',
    'Okunmamış',
    'Etkinlik',
    'Mesaj',
    'Ödeme',
    'Hesap',
  ];

  Future<void> _markAllRead() async {
    if (_actionBusy) {
      return;
    }

    setState(() {
      _actionBusy = true;
    });

    try {
      final int updatedCount =
      await NotificationService.markAllRead();

      if (!mounted) {
        return;
      }

      if (updatedCount == 0) {
        _showMessage(
          _notificationText(
            context,
            tr: 'Okunmamış bildirim bulunmuyor.',
            en: 'There are no unread notifications.',
            de: 'Es gibt keine ungelesenen Benachrichtigungen.',
          ),
        );
      } else {
        _showMessage(
          _notificationText(
            context,
            tr: '$updatedCount bildirim okundu olarak işaretlendi.',
            en: '$updatedCount notifications were marked as read.',
            de: '$updatedCount Benachrichtigungen wurden als gelesen markiert.',
          ),
        );
      }
    } on NotificationServiceException
    catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage(
        _notificationText(
          context,
          tr: 'Bildirimler güncellenemedi.',
          en: 'Notifications could not be updated.',
          de: 'Benachrichtigungen konnten nicht aktualisiert werden.',
        ),
      );
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
          builder: (
              BuildContext dialogContext,
              ) {
            return AlertDialog(
              title: Text(
                _notificationText(
                  context,
                  tr: 'Bildirimler temizlensin mi?',
                  en: 'Clear notifications?',
                  de: 'Benachrichtigungen löschen?',
                ),
              ),
              content: Text(
                _notificationText(
                  context,
                  tr: 'Tüm bildirimler kalıcı olarak silinecek.',
                  en: 'All notifications will be permanently deleted.',
                  de: 'Alle Benachrichtigungen werden dauerhaft gelöscht.',
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      false,
                    );
                  },
                  child: Text(
                    _notificationText(
                      context,
                      tr: 'Vazgeç',
                      en: 'Cancel',
                      de: 'Abbrechen',
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      true,
                    );
                  },
                  child: Text(
                    _notificationText(
                      context,
                      tr: 'Temizle',
                      en: 'Clear',
                      de: 'Löschen',
                    ),
                  ),
                ),
              ],
            );
          },
        ) ??
            false;

    if (!confirmed) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _actionBusy = true;
    });

    try {
      final int deletedCount =
      await NotificationService.deleteAll();

      if (!mounted) {
        return;
      }

      if (deletedCount == 0) {
        _showMessage(
          _notificationText(
            context,
            tr: 'Silinecek bildirim bulunmuyor.',
            en: 'There are no notifications to delete.',
            de: 'Es gibt keine Benachrichtigungen zum Löschen.',
          ),
        );
      } else {
        _showMessage(
          _notificationText(
            context,
            tr: 'Bildirimler temizlendi.',
            en: 'Notifications were cleared.',
            de: 'Benachrichtigungen wurden gelöscht.',
          ),
        );
      }
    } on NotificationServiceException
    catch (error) {
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage(
        _notificationText(
          context,
          tr: 'Bildirimler silinemedi.',
          en: 'Notifications could not be deleted.',
          de: 'Benachrichtigungen konnten nicht gelöscht werden.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
        });
      }
    }
  }

  Future<void> _deleteNotification(
      AppNotification notification,
      ) async {
    try {
      await NotificationService
          .deleteNotification(
        notificationId: notification.id,
      );

      if (!mounted) {
        return;
      }
    } on NotificationServiceException
    catch (error) {
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _notificationText(
          context,
          tr: 'Etkinlik açılamadı.',
          en: 'The event could not be opened.',
          de: 'Die Veranstaltung konnte nicht geöffnet werden.',
        ),
      );
    }
  }

  Future<void> _toggleRead(
      AppNotification notification,
      ) async {
    try {
      if (notification.isRead) {
        await NotificationService.markUnread(
          notificationId: notification.id,
        );
      } else {
        await NotificationService.markRead(
          notificationId: notification.id,
        );
      }

      if (!mounted) {
        return;
      }
    } on NotificationServiceException
    catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage(
        _notificationText(
          context,
          tr: 'Bildirim güncellenemedi.',
          en: 'The notification could not be updated.',
          de: 'Die Benachrichtigung konnte nicht aktualisiert werden.',
        ),
      );
    }
  }

  Future<void> _openNotification(
      AppNotification notification,
      ) async {
    if (!notification.isRead) {
      try {
        await NotificationService.markRead(
          notificationId: notification.id,
        );
      } catch (_) {
        // Okundu işlemi başarısız olsa da
        // bildirimin hedefi açılabilir.
      }
    }

    if (!mounted) {
      return;
    }

    if ((notification.type == NotificationType.friendRequest ||
        notification.type == NotificationType.friendAccepted) &&
        notification.senderUid.isNotEmpty) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PublicProfileScreen(
            userId: notification.senderUid,
          ),
        ),
      );

      return;
    }
    if (notification.type ==
        NotificationType.message &&
        notification.eventId.isNotEmpty) {
      final String title =
      notification.eventTitle.isEmpty
          ? _notificationText(
        context,
        tr: 'Etkinlik Sohbeti',
        en: 'Event Chat',
        de: 'Veranstaltungs-Chat',
      )
          : notification.eventTitle;

      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => EventChatScreen(
            eventId: notification.eventId,
            eventTitle: title,
          ),
        ),
      );

      return;
    }

    if (notification.eventId.isNotEmpty) {
      await _openEvent(
        notification.eventId,
      );
      return;
    }

    _showNotificationDetails(
      notification,
    );
  }

  Future<void> _openEvent(
      String eventId,
      ) async {
    try {
      final DocumentSnapshot<
          Map<String, dynamic>>
      snapshot = await FirebaseFirestore
          .instance
          .collection('events')
          .doc(eventId)
          .get();

      if (!mounted) {
        return;
      }

      final Map<String, dynamic>? data =
      snapshot.data();

      if (!snapshot.exists || data == null) {
        _showMessage(
          _notificationText(
            context,
            tr: 'İlgili etkinlik artık bulunamıyor.',
            en: 'The related event is no longer available.',
            de: 'Die zugehörige Veranstaltung ist nicht mehr verfügbar.',
          ),
        );
        return;
      }

      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => EventDetailScreen(
            eventId: eventId,
            initialData: data,
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(
        error.message ??
            _notificationText(
              context,
              tr: 'Etkinlik açılamadı.',
              en: 'The event could not be opened.',
              de: 'Die Veranstaltung konnte nicht geöffnet werden.',
            ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _notificationText(
          context,
          tr: 'Etkinlik açılamadı.',
          en: 'The event could not be opened.',
          de: 'Die Veranstaltung konnte nicht geöffnet werden.',
        ),
      );
    }
  }

  void _showNotificationDetails(
      AppNotification notification,
      ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (
          BuildContext sheetContext,
          ) {
        return SafeArea(
          child: Padding(
            padding:
            const EdgeInsets.fromLTRB(
              22,
              4,
              22,
              24,
            ),
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    CircleAvatar(
                      child: Icon(
                        _iconForType(
                          notification.type,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        notification.title,
                        style: Theme.of(
                          sheetContext,
                        )
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                          fontWeight:
                          FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  notification.body,
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.bodyLarge,
                ),
                if (notification.createdAt !=
                    null) ...<Widget>[
                  const SizedBox(height: 14),
                  Text(
                    _fullDateText(
                      notification.createdAt!,
                    ),
                    style: Theme.of(
                      sheetContext,
                    ).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(
                        sheetContext,
                      );
                    },
                    child: Text(
                      _notificationText(
                        context,
                        tr: 'Kapat',
                        en: 'Close',
                        de: 'Schließen',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _matchesFilter(
      AppNotification notification,
      ) {
    switch (_selectedFilter) {
      case 'Okunmamış':
        return !notification.isRead;
      case 'Etkinlik':
        return notification.type ==
            NotificationType.application ||
            notification.type ==
                NotificationType
                    .applicationAccepted ||
            notification.type ==
                NotificationType
                    .applicationRejected ||
            notification.type ==
                NotificationType
                    .eventCancelled ||
            notification.type ==
                NotificationType.eventUpdated ||
            notification.type ==
                NotificationType
                    .eventReminder;
      case 'Mesaj':
        return notification.type ==
            NotificationType.message;
      case 'Ödeme':
        return notification.type ==
            NotificationType.payment ||
            notification.type ==
                NotificationType.refund;
      case 'Hesap':
        return notification.type ==
            NotificationType.verification ||
            notification.type ==
                NotificationType.system;
      default:
        return true;
    }
  }

  void _showMessage(
      String text,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior:
          SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Text(
              _notificationText(
                context,
                tr: 'Bildirimleri görmek için giriş yapmalısın.',
                en: 'You need to sign in to view notifications.',
                de: 'Du musst dich anmelden, um Benachrichtigungen zu sehen.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _notificationText(
            context,
            tr: 'Bildirimler',
            en: 'Notifications',
            de: 'Benachrichtigungen',
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip:
            _notificationText(
              context,
              tr: 'Tümünü okundu yap',
              en: 'Mark all as read',
              de: 'Alle als gelesen markieren',
            ),
            onPressed: _actionBusy
                ? null
                : _markAllRead,
            icon: const Icon(
              Icons.done_all_rounded,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: _notificationText(
              context,
              tr: 'Bildirim seçenekleri',
              en: 'Notification options',
              de: 'Benachrichtigungsoptionen',
            ),
            enabled: !_actionBusy,
            onSelected: (
                String value,
                ) {
              if (value == 'clear') {
                _clearNotifications();
              }
            },
            itemBuilder: (
                BuildContext context,
                ) {
              return <
                  PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'clear',
                  child: ListTile(
                    contentPadding:
                    EdgeInsets.zero,
                    leading: Icon(
                      Icons
                          .delete_sweep_outlined,
                    ),
                    title: Text(
                      _notificationText(
                        context,
                        tr: 'Bildirimleri temizle',
                        en: 'Clear notifications',
                        de: 'Benachrichtigungen löschen',
                      ),
                    ),
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_actionBusy)
            const LinearProgressIndicator(),
          SizedBox(
            height: 58,
            child: ListView.separated(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              scrollDirection:
              Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (
                  BuildContext context,
                  int index,
                  ) {
                return const SizedBox(
                  width: 8,
                );
              },
              itemBuilder: (
                  BuildContext context,
                  int index,
                  ) {
                final String filter =
                _filters[index];

                return ChoiceChip(
                  label: Text(
                    _filterText(context, filter),
                  ),
                  selected:
                  _selectedFilter ==
                      filter,
                  onSelected: (
                      bool selected,
                      ) {
                    if (!selected) {
                      return;
                    }

                    setState(() {
                      _selectedFilter =
                          filter;
                    });
                  },
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<
                List<AppNotification>>(
              stream: NotificationService
                  .watchNotifications(
                limit: 150,
              ),
              builder: (
                  BuildContext context,
                  AsyncSnapshot<
                      List<AppNotification>>
                  snapshot,
                  ) {
                if (snapshot.hasError) {
                  final Object error =
                      snapshot.error ??
                          _notificationText(
                            context,
                            tr: 'Bilinmeyen hata',
                            en: 'Unknown error',
                            de: 'Unbekannter Fehler',
                          );

                  return _ErrorState(
                    message: error
                    is NotificationServiceException
                        ? error.message
                        : _notificationText(
                      context,
                      tr: 'Bildirimler yüklenemedi.',
                      en: 'Notifications could not be loaded.',
                      de: 'Benachrichtigungen konnten nicht geladen werden.',
                    ),
                  );
                }

                if (snapshot.connectionState ==
                    ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child:
                    CircularProgressIndicator(),
                  );
                }

                final List<AppNotification>
                notifications =
                (snapshot.data ??
                    <AppNotification>[])
                    .where(_matchesFilter)
                    .toList(
                  growable: false,
                );

                if (notifications.isEmpty) {
                  return _EmptyState(
                    filtered:
                    _selectedFilter !=
                        'Tümü',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await Future<void>.delayed(
                      const Duration(
                        milliseconds: 350,
                      ),
                    );
                  },
                  child: ListView.separated(
                    physics:
                    const AlwaysScrollableScrollPhysics(),
                    padding:
                    const EdgeInsets.fromLTRB(
                      14,
                      4,
                      14,
                      18,
                    ),
                    itemCount:
                    notifications.length,
                    separatorBuilder: (
                        BuildContext context,
                        int index,
                        ) {
                      return const SizedBox(
                        height: 8,
                      );
                    },
                    itemBuilder: (
                        BuildContext context,
                        int index,
                        ) {
                      final AppNotification
                      notification =
                      notifications[index];

                      return Dismissible(
                        key: ValueKey<String>(
                          notification.id,
                        ),
                        direction:
                        DismissDirection
                            .endToStart,
                        background: Container(
                          alignment:
                          Alignment.centerRight,
                          padding:
                          const EdgeInsets.only(
                            right: 22,
                          ),
                          decoration:
                          BoxDecoration(
                            color: Theme.of(
                              context,
                            )
                                .colorScheme
                                .errorContainer,
                            borderRadius:
                            BorderRadius
                                .circular(14),
                          ),
                          child: Icon(
                            Icons
                                .delete_outline_rounded,
                            color: Theme.of(
                              context,
                            )
                                .colorScheme
                                .onErrorContainer,
                          ),
                        ),
                        confirmDismiss:
                            (_) async {
                          return await showDialog<
                              bool>(
                            context: context,
                            builder: (
                                BuildContext
                                dialogContext,
                                ) {
                              return AlertDialog(
                                title: Text(
                                  _notificationText(
                                    context,
                                    tr: 'Bildirim silinsin mi?',
                                    en: 'Delete notification?',
                                    de: 'Benachrichtigung löschen?',
                                  ),
                                ),
                                content: Text(
                                  _notificationText(
                                    context,
                                    tr: 'Bu bildirim kalıcı olarak silinecek.',
                                    en: 'This notification will be permanently deleted.',
                                    de: 'Diese Benachrichtigung wird dauerhaft gelöscht.',
                                  ),
                                ),
                                actions: <
                                    Widget>[
                                  TextButton(
                                    onPressed:
                                        () {
                                      Navigator.pop(
                                        dialogContext,
                                        false,
                                      );
                                    },
                                    child: Text(
                                      _notificationText(
                                        context,
                                        tr: 'Vazgeç',
                                        en: 'Cancel',
                                        de: 'Abbrechen',
                                      ),
                                    ),
                                  ),
                                  FilledButton(
                                    onPressed:
                                        () {
                                      Navigator.pop(
                                        dialogContext,
                                        true,
                                      );
                                    },
                                    child: Text(
                                      _notificationText(
                                        context,
                                        tr: 'Sil',
                                        en: 'Delete',
                                        de: 'Löschen',
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        onDismissed: (_) {
                          _deleteNotification(
                            notification,
                          );
                        },
                        child:
                        _NotificationCard(
                          notification:
                          notification,
                          onTap: () {
                            _openNotification(
                              notification,
                            );
                          },
                          onReadToggle: () {
                            _toggleRead(
                              notification,
                            );
                          },
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

class _NotificationCard
    extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onReadToggle,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onReadToggle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors =
        Theme.of(context).colorScheme;

    return Card(
      color: notification.isRead
          ? null
          : colors.primaryContainer,
      child: InkWell(
        borderRadius:
        BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding:
          const EdgeInsets.fromLTRB(
            12,
            12,
            6,
            12,
          ),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: <Widget>[
              _NotificationAvatar(
                notification: notification,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 2,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style: TextStyle(
                              fontWeight:
                              notification
                                  .isRead
                                  ? FontWeight
                                  .w700
                                  : FontWeight
                                  .w900,
                            ),
                          ),
                        ),
                        if (!notification
                            .isRead)
                          Container(
                            width: 9,
                            height: 9,
                            margin:
                            const EdgeInsets
                                .only(
                              left: 8,
                            ),
                            decoration:
                            const BoxDecoration(
                              color: Color(
                                0xffFF9800,
                              ),
                              shape:
                              BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (notification
                        .body.isNotEmpty) ...<
                        Widget>[
                      const SizedBox(height: 5),
                      Text(
                        notification.body,
                        maxLines: 3,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style: TextStyle(
                          color: colors
                              .onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Text(
                          _timeText(
                            context,
                            notification.createdAt,
                          ),
                          style: TextStyle(
                            color: colors
                                .onSurfaceVariant,
                            fontSize: 11,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _notificationTypeText(
                            context,
                            notification.type,
                          ),
                          style: TextStyle(
                            color:
                            colors.primary,
                            fontSize: 11,
                            fontWeight:
                            FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: notification.isRead
                    ? _notificationText(
                  context,
                  tr: 'Okunmamış yap',
                  en: 'Mark as unread',
                  de: 'Als ungelesen markieren',
                )
                    : _notificationText(
                  context,
                  tr: 'Okundu yap',
                  en: 'Mark as read',
                  de: 'Als gelesen markieren',
                ),
                onPressed: onReadToggle,
                icon: Icon(
                  notification.isRead
                      ? Icons
                      .mark_email_unread_outlined
                      : Icons
                      .done_all_rounded,
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

class _NotificationAvatar
    extends StatelessWidget {
  const _NotificationAvatar({
    required this.notification,
  });

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final String photoUrl =
        notification.senderPhotoUrl;

    return CircleAvatar(
      radius: 24,
      backgroundImage: photoUrl.isEmpty
          ? null
          : NetworkImage(photoUrl),
      child: photoUrl.isEmpty
          ? Icon(
        _iconForType(
          notification.type,
        ),
      )
          : null,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.filtered,
  });

  final bool filtered;

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
                color: Theme.of(context)
                    .colorScheme
                    .secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons
                    .notifications_none_rounded,
                size: 42,
                color: Theme.of(context)
                    .colorScheme
                    .onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              filtered
                  ? _notificationText(
                context,
                tr: 'Bu filtrede bildirim yok',
                en: 'No notifications in this filter',
                de: 'Keine Benachrichtigungen in diesem Filter',
              )
                  : _notificationText(
                context,
                tr: 'Henüz bildirimin yok',
                en: 'You have no notifications yet',
                de: 'Du hast noch keine Benachrichtigungen',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight:
                FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              filtered
                  ? _notificationText(
                context,
                tr: 'Başka bir filtre seçerek bildirimlerini görüntüleyebilirsin.',
                en: 'Select another filter to view your notifications.',
                de: 'Wähle einen anderen Filter, um deine Benachrichtigungen anzuzeigen.',
              )
                  : _notificationText(
                context,
                tr: 'Etkinlik, mesaj ve hesap bildirimlerin burada görünecek.',
                en: 'Your event, message and account notifications will appear here.',
                de: 'Deine Veranstaltungs-, Nachrichten- und Kontobenachrichtigungen werden hier angezeigt.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
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
  const _ErrorState({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.error_outline_rounded,
              size: 54,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
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

IconData _iconForType(
    NotificationType type,
    ) {
  switch (type) {
    case NotificationType.application:
      return Icons.person_add_alt_1_rounded;
    case NotificationType
        .applicationAccepted:
      return Icons
          .check_circle_outline_rounded;
    case NotificationType
        .applicationRejected:
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

String _timeText(
    BuildContext context,
    DateTime? date,
    ) {
  if (date == null) {
    return '';
  }

  final DateTime now = DateTime.now();
  final Duration difference = now.difference(date);

  if (difference.isNegative) {
    return _fullDateText(date);
  }

  if (difference.inMinutes < 1) {
    return _notificationText(
      context,
      tr: 'Şimdi',
      en: 'Now',
      de: 'Jetzt',
    );
  }

  if (difference.inMinutes < 60) {
    return _notificationText(
      context,
      tr: '${difference.inMinutes} dk önce',
      en: '${difference.inMinutes} min ago',
      de: 'vor ${difference.inMinutes} Min.',
    );
  }

  if (difference.inHours < 24) {
    return _notificationText(
      context,
      tr: '${difference.inHours} sa önce',
      en: '${difference.inHours} hr ago',
      de: 'vor ${difference.inHours} Std.',
    );
  }

  if (difference.inDays == 1) {
    return _notificationText(
      context,
      tr: 'Dün',
      en: 'Yesterday',
      de: 'Gestern',
    );
  }

  if (difference.inDays < 7) {
    return _notificationText(
      context,
      tr: '${difference.inDays} gün önce',
      en: '${difference.inDays} days ago',
      de: 'vor ${difference.inDays} Tagen',
    );
  }

  return _fullDateText(date);
}

String _fullDateText(
    DateTime date,
    ) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year} • '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}