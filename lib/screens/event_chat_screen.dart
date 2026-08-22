import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import '../utils/support_categories.dart';
import 'create_support_request_screen.dart';

class EventChatScreen extends StatefulWidget {
  const EventChatScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  final String eventId;
  final String eventTitle;

  @override
  State<EventChatScreen> createState() => _EventChatScreenState();
}

class _EventChatScreenState extends State<EventChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  Timer? _typingTimer;

  bool _sending = false;
  bool _markingRead = false;
  bool _isTyping = false;
  String? _lastReadMessageId;

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();

    _messageController.addListener(_handleTypingChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatService.ensureCurrentUserIsChatMember(widget.eventId);
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _messageController.removeListener(_handleTypingChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();

    unawaited(_chatService.clearTyping(eventId: widget.eventId));

    super.dispose();
  }

  void _handleTypingChanged() {
    final bool hasText = _messageController.text.trim().isNotEmpty;

    if (hasText && !_isTyping) {
      _isTyping = true;

      unawaited(
        _chatService.setTyping(eventId: widget.eventId, isTyping: true),
      );
    }

    _typingTimer?.cancel();

    if (!hasText) {
      _stopTyping();
      return;
    }

    _typingTimer = Timer(const Duration(seconds: 4), _stopTyping);
  }

  void _stopTyping() {
    _typingTimer?.cancel();

    if (!_isTyping) {
      return;
    }

    _isTyping = false;

    unawaited(_chatService.setTyping(eventId: widget.eventId, isTyping: false));
  }

  Future<void> _sendMessage() async {
    final String text = _messageController.text.trim();

    if (text.isEmpty || _sending) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await _chatService.sendTextMessage(eventId: widget.eventId, text: text);

      _messageController.clear();
      _stopTyping();
      _scrollToLatest();
    } on ChatServiceException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Mesaj gönderilemedi.');
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _scheduleMarkAsRead(List<ChatMessage> messages) {
    if (_markingRead || messages.isEmpty || _currentUserId.isEmpty) {
      return;
    }

    final ChatMessage latestMessage = messages.first;

    if (_lastReadMessageId == latestMessage.id) {
      return;
    }

    final bool hasUnread = messages.any(
      (ChatMessage message) =>
          message.senderUid != _currentUserId &&
          !message.readBy.contains(_currentUserId),
    );

    if (!hasUnread) {
      _lastReadMessageId = latestMessage.id;
      return;
    }

    _markingRead = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _chatService.markMessagesAsRead(eventId: widget.eventId);

        _lastReadMessageId = latestMessage.id;
      } catch (_) {
        // Okundu bilgisi sohbet kullanımını durdurmaz.
      } finally {
        _markingRead = false;
      }
    });
  }

  Future<void> _showMessageActions(ChatMessage message) async {
    if (message.deleted) {
      return;
    }

    final bool isMine = message.isMine(_currentUserId);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (isMine) ...<Widget>[
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Mesajı düzenle'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showEditDialog(message);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Mesajı sil'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmDelete(message);
                  },
                ),
              ] else
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Mesajı Şikâyet Et'),
                  onTap: () async {
                    Navigator.pop(sheetContext);

                    final bool? created = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute<bool>(
                        builder: (_) => CreateSupportRequestScreen(
                          category: SupportCategory.messageReport,
                          relatedMessageId: message.id,
                        ),
                      ),
                    );

                    if (created == true) {
                      _showMessage('Mesaj şikâyetin incelemeye gönderildi.');
                    }
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditDialog(ChatMessage message) async {
    final TextEditingController controller = TextEditingController(
      text: message.text,
    );

    final String? updatedText = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Mesajı düzenle'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 1,
            maxLines: 6,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Mesaj'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                final String value = controller.text.trim();

                if (value.isEmpty) {
                  return;
                }

                Navigator.pop(dialogContext, value);
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (updatedText == null || updatedText == message.text) {
      return;
    }

    try {
      await _chatService.editMessage(
        eventId: widget.eventId,
        messageId: message.id,
        newText: updatedText,
      );
    } on ChatServiceException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Mesaj düzenlenemedi.');
    }
  }

  Future<void> _confirmDelete(ChatMessage message) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Mesaj silinsin mi?'),
          content: const Text('Bu mesaj sohbetten kaldırılacak.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _chatService.deleteMessage(
        eventId: widget.eventId,
        messageId: message.id,
      );
    } on ChatServiceException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Mesaj silinemedi.');
    }
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.eventTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            StreamBuilder<List<String>>(
              stream: _chatService.watchTypingUserIds(widget.eventId),
              builder:
                  (BuildContext context, AsyncSnapshot<List<String>> snapshot) {
                    final int typingCount = snapshot.data?.length ?? 0;

                    if (typingCount == 0) {
                      return const Text(
                        'Etkinlik sohbeti',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    }

                    return Text(
                      typingCount == 1
                          ? 'Bir kişi yazıyor...'
                          : '$typingCount kişi yazıyor...',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  },
            ),
          ],
        ),
      ),
      body: currentUser == null
          ? const _SignedOutChatState()
          : Column(
              children: <Widget>[
                Expanded(
                  child: StreamBuilder<List<ChatMessage>>(
                    stream: _chatService.watchMessages(
                      widget.eventId,
                      limit: 150,
                    ),
                    builder:
                        (
                          BuildContext context,
                          AsyncSnapshot<List<ChatMessage>> snapshot,
                        ) {
                          if (snapshot.hasError) {
                            final Object error =
                                snapshot.error ?? 'Bilinmeyen hata';

                            return _ChatErrorState(
                              message: error is ChatServiceException
                                  ? error.message
                                  : 'Mesajlar yüklenemedi.',
                            );
                          }

                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final List<ChatMessage> messages =
                              snapshot.data ?? <ChatMessage>[];

                          _scheduleMarkAsRead(messages);

                          if (messages.isEmpty) {
                            return const _EmptyChatState();
                          }

                          final List<_ChatListItem> items = _buildListItems(
                            messages,
                          );

                          return ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
                            itemCount: items.length,
                            itemBuilder: (BuildContext context, int index) {
                              final _ChatListItem item = items[index];

                              if (item.date != null) {
                                return _DateSeparator(date: item.date!);
                              }

                              final ChatMessage message = item.message!;

                              return _MessageBubble(
                                message: message,
                                mine: message.isMine(_currentUserId),
                                readByAnother: message.isReadByAnotherUser(
                                  _currentUserId,
                                ),
                                onLongPress: () {
                                  _showMessageActions(message);
                                },
                              );
                            },
                          );
                        },
                  ),
                ),
                _MessageComposer(
                  controller: _messageController,
                  focusNode: _messageFocusNode,
                  sending: _sending,
                  onSend: _sendMessage,
                ),
              ],
            ),
    );
  }

  List<_ChatListItem> _buildListItems(List<ChatMessage> messages) {
    final List<_ChatListItem> items = <_ChatListItem>[];

    for (int index = 0; index < messages.length; index++) {
      final ChatMessage message = messages[index];

      items.add(_ChatListItem.message(message));

      final DateTime? currentDate = message.createdAt;

      if (currentDate == null) {
        continue;
      }

      final DateTime? nextDate = index + 1 < messages.length
          ? messages[index + 1].createdAt
          : null;

      final bool dayChanged =
          nextDate == null || !_isSameDay(currentDate, nextDate);

      if (dayChanged) {
        items.add(_ChatListItem.date(currentDate));
      }
    }

    return items;
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 2000,
                  buildCounter:
                      (
                        BuildContext context, {
                        required int currentLength,
                        required bool isFocused,
                        int? maxLength,
                      }) {
                        return null;
                      },
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: 'Mesaj yaz...',
                    prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton.filled(
                  tooltip: 'Gönder',
                  onPressed: sending ? null : onSend,
                  icon: sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.readByAnother,
    required this.onLongPress,
  });

  final ChatMessage message;
  final bool mine;
  final bool readByAnother;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    final Color bubbleColor = mine
        ? const Color(0xffFF9800)
        : colors.surfaceContainerHighest;

    final Color foregroundColor = mine ? Colors.black : colors.onSurface;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: !message.deleted ? onLongPress : null,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.80,
          ),
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.fromLTRB(12, 9, 10, 7),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 4),
              bottomRight: Radius.circular(mine ? 4 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!mine && message.senderName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _MiniAvatar(
                        imageUrl: message.senderPhotoUrl,
                        name: message.senderName,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          message.senderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                message.deleted ? 'Bu mesaj silindi.' : message.text,
                style: TextStyle(
                  color: message.deleted
                      ? foregroundColor.withValues(alpha: 0.60)
                      : foregroundColor,
                  fontStyle: message.deleted
                      ? FontStyle.italic
                      : FontStyle.normal,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  if (message.edited && !message.deleted) ...[
                    Text(
                      'düzenlendi',
                      style: TextStyle(
                        color: foregroundColor.withValues(alpha: 0.60),
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                  if (message.createdAt != null)
                    Text(
                      _formatTime(message.createdAt!),
                      style: TextStyle(
                        color: foregroundColor.withValues(alpha: 0.62),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.done_all_rounded,
                      size: 17,
                      color: readByAnother
                          ? const Color(0xff0B7A36)
                          : Colors.black54,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTime(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.imageUrl, required this.name});

  final String imageUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final String initial = name.trim().isEmpty
        ? 'Ü'
        : name.trim()[0].toUpperCase();

    return CircleAvatar(
      radius: 10,
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      backgroundImage: imageUrl.isEmpty ? null : NetworkImage(imageUrl),
      child: imageUrl.isEmpty
          ? Text(
              initial,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
            )
          : null,
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          _formatDate(date),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime messageDay = DateTime(value.year, value.month, value.day);

    final int difference = today.difference(messageDay).inDays;

    if (difference == 0) {
      return 'Bugün';
    }

    if (difference == 1) {
      return 'Dün';
    }

    const List<String> months = <String>[
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];

    if (value.year == now.year) {
      return '${value.day} ${months[value.month - 1]}';
    }

    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 82,
              height: 82,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.forum_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 17),
            Text(
              'İlk mesajı sen gönder',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(
              'Etkinlik detaylarını konuşmak ve diğer oyuncularla iletişim kurmak için mesaj yazabilirsin.',
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

class _ChatErrorState extends StatelessWidget {
  const _ChatErrorState({required this.message});

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

class _SignedOutChatState extends StatelessWidget {
  const _SignedOutChatState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          'Sohbeti kullanmak için giriş yapmalısın.',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _ChatListItem {
  const _ChatListItem._({this.message, this.date});

  factory _ChatListItem.message(ChatMessage message) {
    return _ChatListItem._(message: message);
  }

  factory _ChatListItem.date(DateTime date) {
    return _ChatListItem._(date: date);
  }

  final ChatMessage? message;
  final DateTime? date;
}
