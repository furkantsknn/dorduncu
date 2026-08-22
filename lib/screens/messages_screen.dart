import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'event_chat_screen.dart';


String _messagesText(
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

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
  });

  @override
  State<MessagesScreen> createState() =>
      _MessagesScreenState();
}

class _MessagesScreenState
    extends State<MessagesScreen> {
  final TextEditingController _searchController =
  TextEditingController();

  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>
  _conversationStream() {
    return FirebaseFirestore.instance
        .collection('events')
        .orderBy(
      'lastMessageAt',
      descending: true,
    )
        .snapshots();
  }

  void _openConversation(
      BuildContext context, {
        required String eventId,
        required String eventTitle,
      }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EventChatScreen(
          eventId: eventId,
          eventTitle: eventTitle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser =
        FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor:
      Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.messages,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: currentUser == null
          ? const _SignedOutState()
          : Column(
        children: <Widget>[
          _SearchField(
            controller: _searchController,
            onChanged: (String value) {
              setState(() {
                _searchText = value
                    .trim()
                    .toLowerCase();
              });
            },
            onClear: () {
              _searchController.clear();

              setState(() {
                _searchText = '';
              });
            },
          ),
          Expanded(
            child: StreamBuilder<
                QuerySnapshot<
                    Map<String, dynamic>>>(
              stream:
              _conversationStream(),
              builder: (
                  BuildContext context,
                  AsyncSnapshot<
                      QuerySnapshot<
                          Map<String,
                              dynamic>>>
                  snapshot,
                  ) {
                if (snapshot.hasError) {
                  return _MessagesError(
                    message: _messagesText(
                      context,
                      tr: 'Sohbetler yüklenemedi. Firestore kurallarını ve bağlantını kontrol et.',
                      en: 'Chats could not be loaded. Check your Firestore rules and internet connection.',
                      de: 'Chats konnten nicht geladen werden. Überprüfe deine Firestore-Regeln und Internetverbindung.',
                    ),
                    onRetry: () {
                      setState(() {});
                    },
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

                final List<
                    QueryDocumentSnapshot<
                        Map<String, dynamic>>>
                conversations =
                _filterConversations(
                  snapshot.data?.docs ??
                      <QueryDocumentSnapshot<
                          Map<String,
                              dynamic>>>[],
                  currentUser.uid,
                );

                if (conversations.isEmpty) {
                  return _EmptyMessagesState(
                    searching:
                    _searchText.isNotEmpty,
                    onClearSearch: () {
                      _searchController.clear();

                      setState(() {
                        _searchText = '';
                      });
                    },
                  );
                }

                final int unreadCount =
                    conversations.where(
                          (
                          QueryDocumentSnapshot<
                              Map<String,
                                  dynamic>>
                          document,
                          ) {
                        return _isUnread(
                          document.data(),
                          currentUser.uid,
                        );
                      },
                    ).length;

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});

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
                      16,
                      10,
                      16,
                      30,
                    ),
                    itemCount:
                    conversations.length + 1,
                    separatorBuilder: (
                        BuildContext context,
                        int index,
                        ) {
                      return const SizedBox(
                        height: 10,
                      );
                    },
                    itemBuilder: (
                        BuildContext context,
                        int index,
                        ) {
                      if (index == 0) {
                        return _MessagesSummary(
                          conversationCount:
                          conversations
                              .length,
                          unreadCount:
                          unreadCount,
                        );
                      }

                      final QueryDocumentSnapshot<
                          Map<String,
                              dynamic>>
                      document =
                      conversations[
                      index - 1];

                      final Map<String, dynamic>
                      data =
                      document.data();

                      final _ConversationData
                      conversation =
                      _ConversationData
                          .fromMap(
                        context,
                        document.id,
                        data,
                        currentUser.uid,
                      );

                      return _ConversationCard(
                        conversation:
                        conversation,
                        onTap: () {
                          _openConversation(
                            context,
                            eventId:
                            conversation
                                .eventId,
                            eventTitle:
                            conversation
                                .title,
                          );
                        },
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

  List<
      QueryDocumentSnapshot<
          Map<String, dynamic>>>
  _filterConversations(
      List<
          QueryDocumentSnapshot<
              Map<String, dynamic>>>
      documents,
      String currentUserId,
      ) {
    final List<
        QueryDocumentSnapshot<
            Map<String, dynamic>>>
    result =
    documents.where(
          (
          QueryDocumentSnapshot<
              Map<String, dynamic>>
          document,
          ) {
        final Map<String, dynamic> data =
        document.data();

        final List<String> memberIds =
        _stringList(
          data['chatMemberUids'] ??
              data['memberUids'] ??
              data['participantUids'],
        );

        if (!memberIds.contains(currentUserId)) {
          return false;
        }

        final bool hasMessage =
            data['lastMessageAt'] != null ||
                _readText(
                  data,
                  <String>[
                    'lastMessage',
                    'sonMesaj',
                  ],
                ).isNotEmpty;

        if (!hasMessage) {
          return false;
        }

        if (_searchText.isEmpty) {
          return true;
        }

        final String title =
        _eventTitle(data).toLowerCase();

        final String lastMessage = _readText(
          data,
          <String>[
            'lastMessage',
            'sonMesaj',
          ],
        ).toLowerCase();

        final String category = _readText(
          data,
          <String>[
            'categoryName',
            'kategori',
          ],
        ).toLowerCase();

        final String location = _readText(
          data,
          <String>[
            'sehir',
            'il',
            'ilce',
            'locationName',
            'konum',
          ],
        ).toLowerCase();

        return title.contains(_searchText) ||
            lastMessage.contains(_searchText) ||
            category.contains(_searchText) ||
            location.contains(_searchText);
      },
    ).toList();

    result.sort(
          (
          QueryDocumentSnapshot<
              Map<String, dynamic>>
          first,
          QueryDocumentSnapshot<
              Map<String, dynamic>>
          second,
          ) {
        final DateTime? firstDate =
        _readDate(
          first.data()['lastMessageAt'],
        );

        final DateTime? secondDate =
        _readDate(
          second.data()['lastMessageAt'],
        );

        if (firstDate == null &&
            secondDate == null) {
          return 0;
        }

        if (firstDate == null) {
          return 1;
        }

        if (secondDate == null) {
          return -1;
        }

        return secondDate.compareTo(firstDate);
      },
    );

    return result;
  }

  bool _isUnread(
      Map<String, dynamic> data,
      String currentUserId,
      ) {
    final String senderId = _readText(
      data,
      <String>[
        'lastMessageSenderUid',
        'lastSenderUid',
        'sonMesajGonderenUid',
      ],
    );

    final List<String> readBy = _stringList(
      data['lastMessageReadBy'] ??
          data['readBy'] ??
          data['sonMesajOkuyanlar'],
    );

    return senderId.isNotEmpty &&
        senderId != currentUserId &&
        !readBy.contains(currentUserId);
  }

  static String _eventTitle(
      Map<String, dynamic> data,
      ) {
    final String rawTitle = _readText(
      data,
      <String>[
        'gameName',
        'oyun',
        'title',
        'eventTitle',
      ],
    );

    if (rawTitle.isEmpty) {
      return 'Etkinlik Sohbeti';
    }

    return _cleanTitle(rawTitle);
  }

  static String _readText(
      Map<String, dynamic> data,
      List<String> keys,
      ) {
    for (final String key in keys) {
      final Object? value = data[key];

      if (value == null) {
        continue;
      }

      final String text =
      value.toString().trim();

      if (text.isNotEmpty &&
          text.toLowerCase() != 'null') {
        return text;
      }
    }

    return '';
  }

  static List<String> _stringList(
      Object? value,
      ) {
    if (value is! Iterable) {
      return <String>[];
    }

    return value
        .map(
          (Object? item) =>
      item?.toString().trim() ?? '',
    )
        .where(
          (String item) => item.isNotEmpty,
    )
        .toList();
  }

  static DateTime? _readDate(
      Object? value,
      ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        value,
      );
    }

    return null;
  }

  static String _cleanTitle(
      String value,
      ) {
    return value
        .replaceFirst(
      RegExp(
        r'^[^A-Za-zÇĞİÖŞÜçğıöşü0-9]+\s*',
      ),
      '',
    )
        .trim();
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16,
          10,
          16,
          12,
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction:
          TextInputAction.search,
          decoration: InputDecoration(
            hintText: _messagesText(
              context,
              tr: 'Etkinlik veya mesaj ara',
              en: 'Search events or messages',
              de: 'Veranstaltungen oder Nachrichten suchen',
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
            ),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
              tooltip: _messagesText(
                context,
                tr: 'Aramayı temizle',
                en: 'Clear search',
                de: 'Suche löschen',
              ),
              onPressed: onClear,
              icon: const Icon(
                Icons.close_rounded,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessagesSummary extends StatelessWidget {
  const _MessagesSummary({
    required this.conversationCount,
    required this.unreadCount,
  });

  final int conversationCount;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .secondaryContainer,
              borderRadius:
              BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.forum_outlined,
              color: Theme.of(context)
                  .colorScheme
                  .onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _messagesText(
                    context,
                    tr: '$conversationCount sohbet',
                    en: '$conversationCount chats',
                    de: '$conversationCount Chats',
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  unreadCount == 0
                      ? _messagesText(
                    context,
                    tr: 'Tüm mesajlarını okudun',
                    en: 'You have read all your messages',
                    de: 'Du hast alle Nachrichten gelesen',
                  )
                      : _messagesText(
                    context,
                    tr: '$unreadCount okunmamış sohbetin var',
                    en: 'You have $unreadCount unread chats',
                    de: 'Du hast $unreadCount ungelesene Chats',
                  ),
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (unreadCount > 0)
            Container(
              constraints:
              const BoxConstraints(
                minWidth: 28,
                minHeight: 28,
              ),
              alignment: Alignment.center,
              padding:
              const EdgeInsets.symmetric(
                horizontal: 8,
              ),
              decoration: BoxDecoration(
                color:
                const Color(0xffFF9800),
                borderRadius:
                BorderRadius.circular(99),
              ),
              child: Text(
                unreadCount > 99
                    ? '99+'
                    : '$unreadCount',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConversationCard
    extends StatelessWidget {
  const _ConversationCard({
    required this.conversation,
    required this.onTap,
  });

  final _ConversationData conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors =
        Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            14,
            13,
            10,
            13,
          ),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.center,
            children: <Widget>[
              _ConversationAvatar(
                title: conversation.title,
                imageUrl:
                conversation.imageUrl,
                unread: conversation.unread,
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
                            conversation.title,
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight:
                              conversation.unread
                                  ? FontWeight
                                  .w900
                                  : FontWeight
                                  .w800,
                            ),
                          ),
                        ),
                        if (conversation
                            .lastMessageAt !=
                            null) ...[
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(
                              context,
                              conversation.lastMessageAt!,
                            ),
                            style: TextStyle(
                              color:
                              conversation.unread
                                  ? const Color(
                                0xffFF9800,
                              )
                                  : colors
                                  .onSurfaceVariant,
                              fontSize: 11,
                              fontWeight:
                              conversation.unread
                                  ? FontWeight
                                  .w900
                                  : FontWeight
                                  .w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: <Widget>[
                        if (conversation
                            .sentByCurrentUser) ...[
                          Icon(
                            Icons.done_all_rounded,
                            size: 16,
                            color: colors
                                .onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            conversation.lastMessage.isEmpty
                                ? _messagesText(
                              context,
                              tr: 'Sohbeti aç',
                              en: 'Open chat',
                              de: 'Chat öffnen',
                            )
                                : conversation.sentByCurrentUser
                                ? _messagesText(
                              context,
                              tr: 'Sen: ${conversation.lastMessage}',
                              en: 'You: ${conversation.lastMessage}',
                              de: 'Du: ${conversation.lastMessage}',
                            )
                                : conversation.lastMessage,
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,
                            style: TextStyle(
                              color:
                              conversation.unread
                                  ? colors.onSurface
                                  : colors
                                  .onSurfaceVariant,
                              fontSize: 13,
                              fontWeight:
                              conversation.unread
                                  ? FontWeight
                                  .w800
                                  : FontWeight
                                  .w500,
                            ),
                          ),
                        ),
                        if (conversation.unread) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 10,
                            height: 10,
                            decoration:
                            const BoxDecoration(
                              color: Color(
                                0xffFF9800,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (conversation
                        .secondaryInfo
                        .isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        conversation.secondaryInfo,
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors
                              .onSurfaceVariant,
                          fontSize: 11,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTime(
      BuildContext context,
      DateTime value,
      ) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(
      now.year,
      now.month,
      now.day,
    );
    final DateTime messageDay = DateTime(
      value.year,
      value.month,
      value.day,
    );

    final int difference =
        today.difference(messageDay).inDays;

    if (difference == 0) {
      return '${value.hour.toString().padLeft(2, '0')}:'
          '${value.minute.toString().padLeft(2, '0')}';
    }

    if (difference == 1) {
      return _messagesText(
        context,
        tr: 'Dün',
        en: 'Yesterday',
        de: 'Gestern',
      );
    }

    if (difference > 1 &&
        difference < 7) {
      final List<String> weekdays;
      switch (Localizations.localeOf(context).languageCode.toLowerCase()) {
        case 'en':
          weekdays = <String>[
            'Mon',
            'Tue',
            'Wed',
            'Thu',
            'Fri',
            'Sat',
            'Sun',
          ];
          break;
        case 'de':
          weekdays = <String>[
            'Mo',
            'Di',
            'Mi',
            'Do',
            'Fr',
            'Sa',
            'So',
          ];
          break;
        default:
          weekdays = <String>[
            'Pzt',
            'Sal',
            'Çar',
            'Per',
            'Cum',
            'Cmt',
            'Paz',
          ];
      }

      return weekdays[value.weekday - 1];
    }

    if (value.year == now.year) {
      return '${value.day.toString().padLeft(2, '0')}.'
          '${value.month.toString().padLeft(2, '0')}';
    }

    return '${value.day.toString().padLeft(2, '0')}.'
        '${value.month.toString().padLeft(2, '0')}.'
        '${value.year}';
  }
}

class _ConversationAvatar
    extends StatelessWidget {
  const _ConversationAvatar({
    required this.title,
    required this.imageUrl,
    required this.unread,
  });

  final String title;
  final String imageUrl;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors =
        Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            shape: BoxShape.circle,
            border: Border.all(
              color: unread
                  ? const Color(0xffFF9800)
                  : colors.outlineVariant,
              width: unread ? 2.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: imageUrl.isEmpty
              ? _AvatarFallback(title: title)
              : Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (
                BuildContext context,
                Object error,
                StackTrace? stackTrace,
                ) {
              return _AvatarFallback(
                title: title,
              );
            },
          ),
        ),
        if (unread)
          Positioned(
            right: -1,
            bottom: 1,
            child: Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color:
                const Color(0xffFF9800),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.surface,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final String initial = title.trim().isEmpty
        ? 'D'
        : title.trim()[0].toUpperCase();

    return Container(
      alignment: Alignment.center,
      color: Theme.of(context)
          .colorScheme
          .secondaryContainer,
      child: Text(
        initial,
        style: TextStyle(
          color: Theme.of(context)
              .colorScheme
              .onSecondaryContainer,
          fontSize: 21,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ConversationData {
  const _ConversationData({
    required this.eventId,
    required this.title,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.sentByCurrentUser,
    required this.unread,
    required this.imageUrl,
    required this.secondaryInfo,
  });

  final String eventId;
  final String title;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final bool sentByCurrentUser;
  final bool unread;
  final String imageUrl;
  final String secondaryInfo;

  factory _ConversationData.fromMap(
      BuildContext context,
      String eventId,
      Map<String, dynamic> data,
      String currentUserId,
      ) {
    final String senderId =
    _MessagesScreenState._readText(
      data,
      <String>[
        'lastMessageSenderUid',
        'lastSenderUid',
        'sonMesajGonderenUid',
      ],
    );

    final List<String> readBy =
    _MessagesScreenState._stringList(
      data['lastMessageReadBy'] ??
          data['readBy'] ??
          data['sonMesajOkuyanlar'],
    );

    final String city =
    _MessagesScreenState._readText(
      data,
      <String>[
        'ilce',
        'sehir',
        'il',
        'locationName',
      ],
    );

    final String category =
    _MessagesScreenState._readText(
      data,
      <String>[
        'categoryName',
        'kategori',
      ],
    );

    final List<String> secondaryParts =
    <String>[
      if (category.isNotEmpty) category,
      if (city.isNotEmpty) city,
    ];

    return _ConversationData(
      eventId: eventId,
      title: _MessagesScreenState._eventTitle(data) == 'Etkinlik Sohbeti'
          ? _messagesText(
        context,
        tr: 'Etkinlik Sohbeti',
        en: 'Event Chat',
        de: 'Veranstaltungs-Chat',
      )
          : _MessagesScreenState._eventTitle(data),
      lastMessage:
      _MessagesScreenState._readText(
        data,
        <String>[
          'lastMessage',
          'sonMesaj',
        ],
      ),
      lastMessageAt:
      _MessagesScreenState._readDate(
        data['lastMessageAt'] ??
            data['sonMesajZamani'],
      ),
      sentByCurrentUser:
      senderId == currentUserId,
      unread: senderId.isNotEmpty &&
          senderId != currentUserId &&
          !readBy.contains(currentUserId),
      imageUrl:
      _MessagesScreenState._readText(
        data,
        <String>[
          'imageUrl',
          'eventImageUrl',
          'gameImageUrl',
          'kapakFotografi',
        ],
      ),
      secondaryInfo:
      secondaryParts.join(' · '),
    );
  }
}

class _EmptyMessagesState
    extends StatelessWidget {
  const _EmptyMessagesState({
    required this.searching,
    required this.onClearSearch,
  });

  final bool searching;
  final VoidCallback onClearSearch;

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
                searching
                    ? Icons.search_off_rounded
                    : Icons
                    .mark_chat_unread_outlined,
                size: 40,
                color: Theme.of(context)
                    .colorScheme
                    .onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              searching
                  ? _messagesText(
                context,
                tr: 'Sohbet bulunamadı',
                en: 'No chats found',
                de: 'Keine Chats gefunden',
              )
                  : _messagesText(
                context,
                tr: 'Henüz mesajın yok',
                en: 'You have no messages yet',
                de: 'Du hast noch keine Nachrichten',
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
            const SizedBox(height: 8),
            Text(
              searching
                  ? _messagesText(
                context,
                tr: 'Arama kelimeni değiştirerek tekrar deneyebilirsin.',
                en: 'Try again with different search terms.',
                de: 'Versuche es mit anderen Suchbegriffen erneut.',
              )
                  : _messagesText(
                context,
                tr: 'Katıldığın bir etkinliğin sohbetine mesaj gönderdiğinde konuşma burada görünecek.',
                en: 'When you send a message in an event chat, the conversation will appear here.',
                de: 'Wenn du in einem Veranstaltungs-Chat eine Nachricht sendest, erscheint die Unterhaltung hier.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
                height: 1.45,
              ),
            ),
            if (searching) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onClearSearch,
                icon: const Icon(
                  Icons.close_rounded,
                ),
                label: Text(
                  _messagesText(
                    context,
                    tr: 'Aramayı temizle',
                    en: 'Clear search',
                    de: 'Suche löschen',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessagesError extends StatelessWidget {
  const _MessagesError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

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
              size: 56,
            ),
            const SizedBox(height: 13),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 15),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedOutState extends StatelessWidget {
  const _SignedOutState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.lock_outline_rounded,
              size: 56,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
            ),
            const SizedBox(height: 13),
            Text(
              _messagesText(
                context,
                tr: 'Mesajlarını görmek için giriş yapmalısın.',
                en: 'You must sign in to view your messages.',
                de: 'Du musst dich anmelden, um deine Nachrichten zu sehen.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}