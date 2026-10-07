import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/event_service.dart';
import '../models/event_application_state.dart';
import '../models/event_model.dart';

import '../l10n/app_localizations.dart';

import '../widgets/user_avatar.dart';
import '../widgets/game_badge_emblem.dart';
import '../widgets/game_visuals.dart';

import 'event_chat_screen.dart';
import 'event_detail_screen.dart';
import 'applicant_management_screen.dart';
import 'public_profile_screen.dart';

String _myEventsText(
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

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _searchController = TextEditingController();

  late final TabController _tabController;

  String _searchText = '';
  String _selectedStatus = 'Tümü';
  bool _showSearch = false;
  bool _actionBusy = false;

  final Set<String> _busyEventIds = <String>{};

  static const List<String> _statusFilters = <String>[
    'Tümü',
    'Aktif',
    'Yaklaşan',
    'Tamamlanan',
    'İptal',
  ];

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _eventsReference =>
      _firestore.collection('events');

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this);

    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final String value = _searchController.text.trim();

    if (_searchText == value) {
      return;
    }

    setState(() {
      _searchText = value;
    });
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;

      if (!_showSearch) {
        _searchController.clear();
        _searchText = '';
      }
    });
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

  List<String> _stringList(dynamic value) {
    if (value is! Iterable) {
      return <String>[];
    }

    return value
        .map((dynamic item) => item.toString().trim())
        .where((String item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  String _firstText(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final String key in keys) {
      final dynamic rawValue = data[key];

      if (rawValue == null) {
        continue;
      }

      final String value = rawValue.toString().trim();

      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }

    return fallback;
  }

  DateTime? _dateValue(dynamic value) {
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
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    return null;
  }

  DateTime? _eventStartAt(Map<String, dynamic> data) {
    return _dateValue(
      data['startAt'] ?? data['tarih'] ?? data['eventDate'] ?? data['date'],
    );
  }

  DateTime? _eventEndAt(Map<String, dynamic> data) {
    final DateTime? explicitEnd = _dateValue(
      data['endAt'] ?? data['bitisTarihi'] ?? data['eventEndDate'],
    );

    if (explicitEnd != null) {
      return explicitEnd;
    }

    final DateTime? startAt = _eventStartAt(data);

    if (startAt == null) {
      return null;
    }

    final int durationMinutes = _intValue(
      data['durationMinutes'] ?? data['sureDakika'],
    );

    if (durationMinutes > 0) {
      return startAt.add(Duration(minutes: durationMinutes));
    }

    return startAt.add(const Duration(hours: 1));
  }

  int _intValue(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _eventTitle(Map<String, dynamic> data) {
    return _firstText(data, <String>[
      'gameName',
      'oyun',
      'eventTitle',
      'title',
    ], fallback: 'Etkinlik');
  }

  String _categoryName(Map<String, dynamic> data) {
    return _firstText(data, <String>[
      'categoryName',
      'kategoriAdi',
      'category',
    ]);
  }

  String _creatorUid(Map<String, dynamic> data) {
    return _firstText(data, <String>[
      'olusturanUid',
      'creatorUid',
      'ownerUid',
      'userId',
    ]);
  }

  String _creatorName(Map<String, dynamic> data) {
    return _firstText(data, <String>[
      'olusturanProfilAdi',
      'creatorName',
      'ownerName',
      'profilAdi',
    ], fallback: 'Organizatör');
  }

  String _creatorPhotoUrl(Map<String, dynamic> data) {
    return _firstText(data, <String>[
      'olusturanProfilFotografi',
      'creatorPhotoUrl',
      'ownerPhotoUrl',
      'profilFotografi',
      'avatarUrl',
      'profilFotoUrl',
      'photoUrl',
    ]);
  }

  String _city(Map<String, dynamic> data) {
    return _firstText(data, <String>['sehir', 'city']);
  }

  String _district(Map<String, dynamic> data) {
    return _firstText(data, <String>['ilce', 'district']);
  }

  String _neighborhood(Map<String, dynamic> data) {
    return _firstText(data, <String>['semt', 'mahalle', 'neighborhood']);
  }

  String _locationText(Map<String, dynamic> data) {
    final List<String> parts = <String>[
      _neighborhood(data),
      _district(data),
      _city(data),
    ].where((String value) => value.isNotEmpty).toList(growable: false);

    if (parts.isNotEmpty) {
      return parts.join(' • ');
    }

    return _firstText(data, <String>[
      'adres',
      'address',
      'location',
    ], fallback: 'Konum belirtilmedi');
  }

  String _status(Map<String, dynamic> data) {
    return _firstText(data, <String>[
      'durum',
      'status',
      'eventStatus',
    ], fallback: 'aktif').toLowerCase();
  }

  List<String> _participantIds(Map<String, dynamic> data) {
    final Set<String> ids = <String>{};

    ids.addAll(_stringList(data['katilanlar']));

    ids.addAll(_stringList(data['selectedPlayerIds']));

    ids.addAll(_stringList(data['participantIds']));

    ids.addAll(_stringList(data['participants']));

    return ids.toList(growable: false);
  }

  List<String> _applicantIds(Map<String, dynamic> data) {
    final Set<String> ids = <String>{};

    ids.addAll(_stringList(data['basvuranOyuncuIds']));

    ids.addAll(_stringList(data['applicantIds']));

    ids.addAll(_stringList(data['applicationUserIds']));

    return ids.toList(growable: false);
  }

  bool _isCreator(Map<String, dynamic> data) {
    return _currentUserId.isNotEmpty && _creatorUid(data) == _currentUserId;
  }

  bool _isParticipant(Map<String, dynamic> data) {
    return _currentUserId.isNotEmpty &&
        _participantIds(data).contains(_currentUserId);
  }

  bool _isApplicant(Map<String, dynamic> data) {
    return _currentUserId.isNotEmpty &&
        _applicantIds(data).contains(_currentUserId);
  }

  bool _isCancelled(Map<String, dynamic> data) {
    final String status = _status(data);

    return <String>{
      'iptal',
      'iptal_edildi',
      'cancelled',
      'canceled',
      'rejected',
    }.contains(status);
  }

  bool _isCompleted(Map<String, dynamic> data) {
    final String status = _status(data);

    if (<String>{
      'tamamlandi',
      'tamamlandı',
      'completed',
      'finished',
      'closed',
    }.contains(status)) {
      return true;
    }

    if (_isCancelled(data)) {
      return false;
    }

    final DateTime? endAt = _eventEndAt(data);

    if (endAt == null) {
      return false;
    }

    return endAt.isBefore(DateTime.now());
  }

  bool _isUpcoming(Map<String, dynamic> data) {
    if (_isCancelled(data) || _isCompleted(data)) {
      return false;
    }

    final DateTime? startAt = _eventStartAt(data);

    if (startAt == null) {
      return false;
    }

    return startAt.isAfter(DateTime.now());
  }

  bool _isActive(Map<String, dynamic> data) {
    return !_isCancelled(data) && !_isCompleted(data);
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    final String normalizedSearch = _normalize(_searchText);

    if (normalizedSearch.isEmpty) {
      return true;
    }

    final String searchableText = _normalize(
      <String>[
        _eventTitle(data),
        _categoryName(data),
        _creatorName(data),
        _city(data),
        _district(data),
        _neighborhood(data),
        _locationText(data),
        _firstText(data, <String>['aciklama', 'description']),
      ].join(' '),
    );

    return searchableText.contains(normalizedSearch);
  }

  bool _matchesStatusFilter(Map<String, dynamic> data) {
    switch (_selectedStatus) {
      case 'Aktif':
        return _isActive(data);
      case 'Yaklaşan':
        return _isUpcoming(data);
      case 'Tamamlanan':
        return _isCompleted(data);
      case 'İptal':
        return _isCancelled(data);
      default:
        return true;
    }
  }

  bool _matchesCommonFilters(Map<String, dynamic> data) {
    return _matchesSearch(data) && _matchesStatusFilter(data);
  }

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u');
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortDocuments(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> sorted = documents
        .toList(growable: false);

    sorted.sort((
      QueryDocumentSnapshot<Map<String, dynamic>> first,
      QueryDocumentSnapshot<Map<String, dynamic>> second,
    ) {
      final Map<String, dynamic> firstData = first.data();
      final Map<String, dynamic> secondData = second.data();

      final bool firstCancelled = _isCancelled(firstData);
      final bool secondCancelled = _isCancelled(secondData);

      if (firstCancelled != secondCancelled) {
        return firstCancelled ? 1 : -1;
      }

      final bool firstCompleted = _isCompleted(firstData);
      final bool secondCompleted = _isCompleted(secondData);

      if (firstCompleted != secondCompleted) {
        return firstCompleted ? 1 : -1;
      }

      final DateTime firstDate =
          _eventStartAt(firstData) ?? DateTime.fromMillisecondsSinceEpoch(0);

      final DateTime secondDate =
          _eventStartAt(secondData) ?? DateTime.fromMillisecondsSinceEpoch(0);

      if (!firstCompleted && !secondCompleted) {
        return firstDate.compareTo(secondDate);
      }

      return secondDate.compareTo(firstDate);
    });

    return sorted;
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _watchAllEvents() {
    final String uid = _currentUserId;
    if (uid.isEmpty) {
      return Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>.value(
        <QueryDocumentSnapshot<Map<String, dynamic>>>[],
      );
    }

    final Stream<QuerySnapshot<Map<String, dynamic>>> created = _eventsReference
        .where('olusturanUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(80)
        .snapshots();
    final Stream<QuerySnapshot<Map<String, dynamic>>> joined = _eventsReference
        .where('katilanlar', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .limit(80)
        .snapshots();
    final Stream<QuerySnapshot<Map<String, dynamic>>> applied = _eventsReference
        .where('basvuranOyuncuIds', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .limit(80)
        .snapshots();

    QuerySnapshot<Map<String, dynamic>>? createdSnap;
    QuerySnapshot<Map<String, dynamic>>? joinedSnap;
    QuerySnapshot<Map<String, dynamic>>? appliedSnap;
    late final StreamController<
      List<QueryDocumentSnapshot<Map<String, dynamic>>>
    >
    controller;
    late final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
    subscriptions;

    void emit() {
      if (createdSnap == null || joinedSnap == null || appliedSnap == null) {
        return;
      }
      final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> documents =
          <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
          in <QueryDocumentSnapshot<Map<String, dynamic>>>[
            ...createdSnap!.docs,
            ...joinedSnap!.docs,
            ...appliedSnap!.docs,
          ]) {
        documents[document.id] = document;
      }
      if (!controller.isClosed) {
        controller.add(documents.values.toList(growable: false));
      }
    }

    controller =
        StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          onListen: () {
            subscriptions =
                <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[
                  created.listen((
                    QuerySnapshot<Map<String, dynamic>> snapshot,
                  ) {
                    createdSnap = snapshot;
                    emit();
                  }, onError: controller.addError),
                  joined.listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
                    joinedSnap = snapshot;
                    emit();
                  }, onError: controller.addError),
                  applied.listen((
                    QuerySnapshot<Map<String, dynamic>> snapshot,
                  ) {
                    appliedSnap = snapshot;
                    emit();
                  }, onError: controller.addError),
                ];
          },
          onCancel: () async {
            for (final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
                subscription
                in subscriptions) {
              await subscription.cancel();
            }
          },
        );

    return controller.stream;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _createdEvents(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    return _sortDocuments(
      documents.where((QueryDocumentSnapshot<Map<String, dynamic>> document) {
        final Map<String, dynamic> data = document.data();

        return _isCreator(data) && _matchesCommonFilters(data);
      }),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _joinedEvents(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    return _sortDocuments(
      documents.where((QueryDocumentSnapshot<Map<String, dynamic>> document) {
        final Map<String, dynamic> data = document.data();

        return !_isCreator(data) &&
            _isParticipant(data) &&
            _matchesCommonFilters(data);
      }),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _appliedEvents(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    return _sortDocuments(
      documents.where((QueryDocumentSnapshot<Map<String, dynamic>> document) {
        final Map<String, dynamic> data = document.data();

        return !_isCreator(data) &&
            _isApplicant(data) &&
            !_isParticipant(data) &&
            _matchesCommonFilters(data);
      }),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _completedEvents(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    return _sortDocuments(
      documents.where((QueryDocumentSnapshot<Map<String, dynamic>> document) {
        final Map<String, dynamic> data = document.data();

        final bool related = _isCreator(data) || _isParticipant(data);

        return related && _isCompleted(data) && _matchesSearch(data);
      }),
    );
  }

  Future<void> _openEvent(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => EventDetailScreen(
          eventId: document.id,
          initialData: document.data(),
        ),
      ),
    );

    if (mounted) {
      await _refreshEvents();
    }
  }

  Future<void> _openApplicants(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ApplicantManagementScreen(
          eventId: document.id,
          initialData: document.data(),
        ),
      ),
    );

    if (mounted) {
      await _refreshEvents();
    }
  }

  Future<void> _openChat(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final Map<String, dynamic> data = document.data();

    if (!EventModel.mapIsFreeAccess(data) && !_isEventPaymentCompleted(data)) {
      _showMessage(
        _myEventsText(
          context,
          tr: 'Sohbet yalnızca kabul edilen oyunculara açıktır.',
          en: 'Chat is available only to accepted players.',
          de: 'Der Chat ist nur für angenommene Spieler verfügbar.',
        ),
      );
      return;
    }

    if (!_hasChatMembership(data)) {
      _showMessage(
        _myEventsText(
          context,
          tr: 'Bu etkinliğin sohbetine erişimin yok.',
          en: 'You do not have access to this event chat.',
          de: 'Du hast keinen Zugriff auf diesen Veranstaltungs-Chat.',
        ),
      );
      return;
    }

    final bool canReadMessages;

    try {
      canReadMessages = await ChatService().canCurrentUserAccessChat(
        document.id,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _myEventsText(
          context,
          tr: 'Sohbet erişimi doğrulanamadı. Lütfen tekrar dene.',
          en: 'Chat access could not be verified. Please try again.',
          de: 'Der Chat-Zugriff konnte nicht geprüft werden. Bitte versuche es erneut.',
        ),
      );
      return;
    }

    if (!canReadMessages) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _myEventsText(
          context,
          tr: 'Sohbet yalnızca kabul edilen oyunculara açıktır.',
          en: 'Chat is available only to accepted players.',
          de: 'Der Chat ist nur für angenommene Spieler verfügbar.',
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => EventChatScreen(
          eventId: document.id,
          eventTitle: _eventTitle(data),
        ),
      ),
    );
  }

  bool _hasChatMembership(Map<String, dynamic> data) {
    if (_currentUserId.isEmpty) {
      return false;
    }

    if (_isCreator(data) || _isParticipant(data)) {
      return true;
    }

    final List<String> chatMembers = _stringList(
      data['chatMemberUids'] ?? data['chatMembers'],
    );

    return chatMembers.contains(_currentUserId);
  }

  bool _isEventPaymentCompleted(Map<String, dynamic> data) {
    final String paymentStatus =
        data['paymentStatus']?.toString().trim().toLowerCase() ?? '';

    return <String>{
      'paid',
      'completed',
      'success',
      'succeeded',
      'escrowheld',
      'escrow_held',
    }.contains(paymentStatus);
  }

  bool _canOpenChat(Map<String, dynamic> data) {
    if (EventModel.mapIsFreeAccess(data)) {
      return _isCreator(data) ||
          _stringList(data['selectedPlayerIds']).contains(_currentUserId);
    }
    return _hasChatMembership(data) && _isEventPaymentCompleted(data);
  }

  Future<void> _refreshEvents() async {
    try {
      await _eventsReference
          .limit(1)
          .get(const GetOptions(source: Source.server));
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      if (error.code != 'unavailable') {
        _showMessage(
          error.message ??
              _myEventsText(
                context,
                tr: 'Etkinlikler yenilenemedi.',
                en: 'Events could not be refreshed.',
                de: 'Veranstaltungen konnten nicht aktualisiert werden.',
              ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _myEventsText(
          context,
          tr: 'Etkinlikler yenilenemedi.',
          en: 'Events could not be refreshed.',
          de: 'Veranstaltungen konnten nicht aktualisiert werden.',
        ),
      );
    }
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmText,
    bool destructive = false,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            destructive
                ? FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(
                        dialogContext,
                      ).colorScheme.error,
                      foregroundColor: Theme.of(
                        dialogContext,
                      ).colorScheme.onError,
                    ),
                    onPressed: () {
                      Navigator.pop(dialogContext, true);
                    },
                    child: Text(confirmText),
                  )
                : FilledButton(
                    onPressed: () {
                      Navigator.pop(dialogContext, true);
                    },
                    child: Text(confirmText),
                  ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  Future<void> _cancelEvent(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final Map<String, dynamic> data = document.data();

    if (!_isCreator(data)) {
      _showMessage(
        _myEventsText(
          context,
          tr: 'Yalnızca etkinlik sahibi iptal edebilir.',
          en: 'Only the event owner can cancel it.',
          de: 'Nur der Veranstalter kann die Veranstaltung absagen.',
        ),
      );
      return;
    }

    if (_isCancelled(data)) {
      _showMessage(
        _myEventsText(
          context,
          tr: 'Bu etkinlik zaten iptal edilmiş.',
          en: 'This event has already been cancelled.',
          de: 'Diese Veranstaltung wurde bereits abgesagt.',
        ),
      );
      return;
    }

    if (_isCompleted(data)) {
      _showMessage(
        _myEventsText(
          context,
          tr: 'Tamamlanmış etkinlik iptal edilemez.',
          en: 'A completed event cannot be cancelled.',
          de: 'Eine abgeschlossene Veranstaltung kann nicht abgesagt werden.',
        ),
      );
      return;
    }

    final bool confirmed = await _confirmAction(
      title: _myEventsText(
        context,
        tr: 'Etkinlik iptal edilsin mi?',
        en: 'Cancel this event?',
        de: 'Diese Veranstaltung absagen?',
      ),
      message: _myEventsText(
        context,
        tr: '${_eventTitle(data)} etkinliği iptal edilecek. Katılımcılar artık bu etkinliğe erişemeyebilir.',
        en: '${_eventTitle(data)} will be cancelled. Participants may no longer be able to access this event.',
        de: '${_eventTitle(data)} wird abgesagt. Teilnehmer können möglicherweise nicht mehr auf diese Veranstaltung zugreifen.',
      ),
      confirmText: _myEventsText(
        context,
        tr: 'İptal Et',
        en: 'Cancel Event',
        de: 'Veranstaltung absagen',
      ),
      destructive: true,
    );

    if (!confirmed) {
      return;
    }

    if (!mounted) {
      return;
    }

    await _runEventAction(
      eventId: document.id,
      action: () async {
        await EventService().cancelUnpaidEvent(
          eventId: document.id,
          reason: 'Kullanıcı tarafından iptal edildi.',
        );
      },
      successMessage: _myEventsText(
        context,
        tr: 'Etkinlik iptal edildi.',
        en: 'The event was cancelled.',
        de: 'Die Veranstaltung wurde abgesagt.',
      ),
      errorMessage: _myEventsText(
        context,
        tr: 'Etkinlik iptal edilemedi.',
        en: 'The event could not be cancelled.',
        de: 'Die Veranstaltung konnte nicht abgesagt werden.',
      ),
    );
  }

  Future<void> _leaveEvent(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final Map<String, dynamic> data = document.data();

    if (_isCreator(data)) {
      _showMessage(
        _myEventsText(
          context,
          tr: 'Etkinlik sahibi etkinlikten ayrılamaz.',
          en: 'The event owner cannot leave the event.',
          de: 'Der Veranstalter kann die Veranstaltung nicht verlassen.',
        ),
      );
      return;
    }

    if (!_isParticipant(data)) {
      _showMessage(
        _myEventsText(
          context,
          tr: 'Bu etkinliğin katılımcısı değilsin.',
          en: 'You are not a participant in this event.',
          de: 'Du bist kein Teilnehmer dieser Veranstaltung.',
        ),
      );
      return;
    }

    if (_isCompleted(data) || _isCancelled(data)) {
      _showMessage(
        _myEventsText(
          context,
          tr: 'Bu etkinlikten artık ayrılamazsın.',
          en: 'You can no longer leave this event.',
          de: 'Du kannst diese Veranstaltung nicht mehr verlassen.',
        ),
      );
      return;
    }

    final bool confirmed = await _confirmAction(
      title: _myEventsText(
        context,
        tr: 'Etkinlikten ayrıl',
        en: 'Leave event',
        de: 'Veranstaltung verlassen',
      ),
      message: _myEventsText(
        context,
        tr: '${_eventTitle(data)} etkinliğinden ayrılmak istediğine emin misin?',
        en: 'Are you sure you want to leave ${_eventTitle(data)}?',
        de: 'Möchtest du ${_eventTitle(data)} wirklich verlassen?',
      ),
      confirmText: _myEventsText(
        context,
        tr: 'Ayrıl',
        en: 'Leave',
        de: 'Verlassen',
      ),
      destructive: true,
    );

    if (!confirmed) {
      return;
    }

    if (!mounted) {
      return;
    }

    await _runEventAction(
      eventId: document.id,
      action: () async {
        await EventService().leaveEvent(eventId: document.id);
      },
      successMessage: _myEventsText(
        context,
        tr: 'Etkinlikten ayrıldın.',
        en: 'You left the event.',
        de: 'Du hast die Veranstaltung verlassen.',
      ),
      errorMessage: _myEventsText(
        context,
        tr: 'Etkinlikten ayrılamadın.',
        en: 'You could not leave the event.',
        de: 'Du konntest die Veranstaltung nicht verlassen.',
      ),
    );
  }

  Future<void> _withdrawApplication(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final Map<String, dynamic> data = document.data();

    if (!_isApplicant(data)) {
      _showMessage(
        _myEventsText(
          context,
          tr: 'Bu etkinlikte bekleyen başvurun bulunmuyor.',
          en: 'You do not have a pending application for this event.',
          de: 'Du hast keine ausstehende Bewerbung für diese Veranstaltung.',
        ),
      );
      return;
    }

    final bool confirmed = await _confirmAction(
      title: _myEventsText(
        context,
        tr: 'Başvuruyu geri çek',
        en: 'Withdraw application',
        de: 'Bewerbung zurückziehen',
      ),
      message: _myEventsText(
        context,
        tr: '${_eventTitle(data)} etkinliğine yaptığın başvuru geri çekilecek.',
        en: 'Your application for ${_eventTitle(data)} will be withdrawn.',
        de: 'Deine Bewerbung für ${_eventTitle(data)} wird zurückgezogen.',
      ),
      confirmText: _myEventsText(
        context,
        tr: 'Geri Çek',
        en: 'Withdraw',
        de: 'Zurückziehen',
      ),
      destructive: true,
    );

    if (!confirmed) {
      return;
    }

    if (!mounted) {
      return;
    }

    await _runEventAction(
      eventId: document.id,
      action: () async {
        await EventService().withdrawApplication(eventId: document.id);
      },
      successMessage: _myEventsText(
        context,
        tr: 'Başvurun geri çekildi.',
        en: 'Your application was withdrawn.',
        de: 'Deine Bewerbung wurde zurückgezogen.',
      ),
      errorMessage: _myEventsText(
        context,
        tr: 'Başvuru geri çekilemedi.',
        en: 'The application could not be withdrawn.',
        de: 'Die Bewerbung konnte nicht zurückgezogen werden.',
      ),
    );
  }

  Future<void> _runEventAction({
    required String eventId,
    required Future<void> Function() action,
    required String successMessage,
    required String errorMessage,
  }) async {
    if (_busyEventIds.contains(eventId)) {
      return;
    }

    setState(() {
      _busyEventIds.add(eventId);
      _actionBusy = true;
    });

    try {
      await action();

      _showMessage(successMessage);
    } on FirebaseException catch (error) {
      _showMessage(error.message ?? errorMessage);
    } on StateError catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _busyEventIds.remove(eventId);
          _actionBusy = _busyEventIds.isNotEmpty;
        });
      }
    }
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Tarih belirtilmedi';
    }

    return '${_twoDigits(date.day)}.'
        '${_twoDigits(date.month)}.'
        '${date.year}';
  }

  String _formatTime(DateTime? date) {
    if (date == null) {
      return '--:--';
    }

    return '${_twoDigits(date.hour)}:'
        '${_twoDigits(date.minute)}';
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) {
      return 'Tarih belirtilmedi';
    }

    return '${_formatDate(date)} • '
        '${_formatTime(date)}';
  }

  String _formatDateRange(Map<String, dynamic> data) {
    final DateTime? startAt = _eventStartAt(data);
    final DateTime? endAt = _eventEndAt(data);

    if (startAt == null) {
      return 'Tarih belirtilmedi';
    }

    if (endAt == null) {
      return _formatDateTime(startAt);
    }

    final bool sameDay =
        startAt.year == endAt.year &&
        startAt.month == endAt.month &&
        startAt.day == endAt.day;

    if (sameDay) {
      return '${_formatDate(startAt)} • '
          '${_formatTime(startAt)}–'
          '${_formatTime(endAt)}';
    }

    return '${_formatDateTime(startAt)} – '
        '${_formatDateTime(endAt)}';
  }

  String _statusLabel(Map<String, dynamic> data) {
    if (_isCancelled(data)) {
      return _myEventsText(
        context,
        tr: 'İptal Edildi',
        en: 'Cancelled',
        de: 'Abgesagt',
      );
    }

    if (_isCompleted(data)) {
      return _myEventsText(
        context,
        tr: 'Tamamlandı',
        en: 'Completed',
        de: 'Abgeschlossen',
      );
    }

    if (_isPaymentPending(data)) {
      return _myEventsText(
        context,
        tr: 'Etkinlik durumu güncelleniyor',
        en: 'Event status is updating',
        de: 'Veranstaltungsstatus wird aktualisiert',
      );
    }

    final DateTime? startAt = _eventStartAt(data);
    final DateTime? endAt = _eventEndAt(data);
    final DateTime now = DateTime.now();

    if (startAt != null &&
        endAt != null &&
        !now.isBefore(startAt) &&
        now.isBefore(endAt)) {
      return 'Devam Ediyor';
    }

    if (_isUpcoming(data)) {
      return _myEventsText(
        context,
        tr: 'Yaklaşan',
        en: 'Upcoming',
        de: 'Bevorstehend',
      );
    }

    return _myEventsText(context, tr: 'Aktif', en: 'Active', de: 'Aktiv');
  }

  Color _statusColor(BuildContext context, Map<String, dynamic> data) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    if (_isCancelled(data)) {
      return colors.error;
    }

    if (_isCompleted(data)) {
      return colors.secondary;
    }

    final DateTime? startAt = _eventStartAt(data);
    final DateTime? endAt = _eventEndAt(data);
    final DateTime now = DateTime.now();

    if (startAt != null &&
        endAt != null &&
        !now.isBefore(startAt) &&
        now.isBefore(endAt)) {
      return Colors.green.shade700;
    }

    if (_isUpcoming(data)) {
      return colors.primary;
    }

    return colors.tertiary;
  }

  IconData _statusIcon(Map<String, dynamic> data) {
    if (_isCancelled(data)) {
      return Icons.cancel_outlined;
    }

    if (_isCompleted(data)) {
      return Icons.check_circle_outline;
    }

    final DateTime? startAt = _eventStartAt(data);
    final DateTime? endAt = _eventEndAt(data);
    final DateTime now = DateTime.now();

    if (startAt != null &&
        endAt != null &&
        !now.isBefore(startAt) &&
        now.isBefore(endAt)) {
      return Icons.play_circle_outline;
    }

    return Icons.schedule_outlined;
  }

  int _requiredPlayerCount(Map<String, dynamic> data) {
    return _intValue(
      data['oyuncuSayisi'] ??
          data['playerCount'] ??
          data['requiredPlayerCount'],
      fallback: 1,
    ).clamp(1, 100).toInt();
  }

  int _selectedPlayerCount(Map<String, dynamic> data) {
    return EventModel.acceptedPlayerCount(data);
  }

  int _applicationCount(Map<String, dynamic> data) {
    final int actualCount = _applicantIds(data).length;

    final bool hasApplicantList =
        data.containsKey('basvuranOyuncuIds') ||
        data.containsKey('applicantIds') ||
        data.containsKey('applicationUserIds');

    if (hasApplicantList) {
      return actualCount;
    }

    return _intValue(
      data['basvuruSayisi'] ?? data['applicationCount'],
    ).clamp(0, 1000000).toInt();
  }

  bool _isPaymentPending(Map<String, dynamic> data) {
    final String status = _status(data);
    final String paymentStatus =
        data['paymentStatus']?.toString().toLowerCase() ?? '';

    if (EventModel.mapIsFreeAccess(data)) {
      return false;
    }

    return status == 'odeme_bekliyor' ||
        status == 'payment_pending' ||
        paymentStatus == 'paymentpending' ||
        paymentStatus == 'payment_pending';
  }

  bool _eventIsFull(Map<String, dynamic> data) {
    return _selectedPlayerCount(data) >= _requiredPlayerCount(data);
  }

  String _playerCountText(Map<String, dynamic> data) {
    final int selected = _selectedPlayerCount(data);
    final int required = _requiredPlayerCount(data);

    return '$selected / $required oyuncu';
  }

  String _description(Map<String, dynamic> data) {
    return _firstText(data, <String>[
      'aciklama',
      'description',
      'eventDescription',
    ]);
  }

  String _membershipPreference(Map<String, dynamic> data) {
    return _firstText(data, <String>['uyeTercihi', 'memberPreference']);
  }

  String _gameReference(Map<String, dynamic> data) {
    return _firstText(data, <String>[
      'gameId',
      'oyunId',
      'gameName',
      'oyun',
      'eventTitle',
      'title',
    ], fallback: _eventTitle(data));
  }

  Color _gameAvatarColor(BuildContext context, Map<String, dynamic> data) {
    return GameVisuals.color(_gameReference(data)).withValues(alpha: 0.18);
  }

  Color _gameAvatarForeground(BuildContext context, Map<String, dynamic> data) {
    return GameVisuals.color(_gameReference(data));
  }

  String _emptyTextForTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        if (_searchText.isNotEmpty || _selectedStatus != 'Tümü') {
          return _myEventsText(
            context,
            tr: 'Filtrelere uygun oluşturduğun etkinlik bulunamadı.',
            en: 'No created events match the filters.',
            de: 'Keine deiner erstellten Veranstaltungen entspricht den Filtern.',
          );
        }

        return _myEventsText(
          context,
          tr: 'Henüz bir etkinlik oluşturmadın.',
          en: 'You have not created an event yet.',
          de: 'Du hast noch keine Veranstaltung erstellt.',
        );

      case 1:
        if (_searchText.isNotEmpty || _selectedStatus != 'Tümü') {
          return _myEventsText(
            context,
            tr: 'Filtrelere uygun katıldığın etkinlik bulunamadı.',
            en: 'No joined events match the filters.',
            de: 'Keine deiner beigetretenen Veranstaltungen entspricht den Filtern.',
          );
        }

        return _myEventsText(
          context,
          tr: 'Henüz katıldığın bir etkinlik yok.',
          en: 'You have not joined an event yet.',
          de: 'Du bist noch keiner Veranstaltung beigetreten.',
        );

      case 2:
        if (_searchText.isNotEmpty || _selectedStatus != 'Tümü') {
          return _myEventsText(
            context,
            tr: 'Filtrelere uygun bekleyen başvurun bulunamadı.',
            en: 'No pending applications match the filters.',
            de: 'Keine ausstehenden Bewerbungen entsprechen den Filtern.',
          );
        }

        return _myEventsText(
          context,
          tr: 'Bekleyen etkinlik başvurun yok.',
          en: 'You have no pending event applications.',
          de: 'Du hast keine ausstehenden Veranstaltungsbewerbungen.',
        );

      case 3:
        if (_searchText.isNotEmpty) {
          return _myEventsText(
            context,
            tr: 'Aramana uygun tamamlanan etkinlik bulunamadı.',
            en: 'No completed events match your search.',
            de: 'Keine abgeschlossenen Veranstaltungen entsprechen deiner Suche.',
          );
        }

        return _myEventsText(
          context,
          tr: 'Henüz tamamlanan etkinliğin yok.',
          en: 'You do not have any completed events yet.',
          de: 'Du hast noch keine abgeschlossenen Veranstaltungen.',
        );

      default:
        return _myEventsText(
          context,
          tr: 'Etkinlik bulunamadı.',
          en: 'No events found.',
          de: 'Keine Veranstaltungen gefunden.',
        );
    }
  }

  IconData _emptyIconForTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return Icons.add_circle_outline;
      case 1:
        return Icons.groups_outlined;
      case 2:
        return Icons.hourglass_empty_rounded;
      case 3:
        return Icons.task_alt_outlined;
      default:
        return Icons.event_busy_outlined;
    }
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorState(Object? error) {
    String message = _myEventsText(
      context,
      tr: 'Etkinlikler yüklenemedi.',
      en: 'Events could not be loaded.',
      de: 'Veranstaltungen konnten nicht geladen werden.',
    );

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          message = _myEventsText(
            context,
            tr: 'Etkinlikleri görüntüleme iznin bulunmuyor.',
            en: 'You do not have permission to view events.',
            de: 'Du hast keine Berechtigung, Veranstaltungen anzusehen.',
          );
          break;

        case 'unavailable':
          message = _myEventsText(
            context,
            tr: 'Bağlantı kurulamadı. İnternet bağlantını kontrol et.',
            en: 'Connection failed. Check your internet connection.',
            de: 'Verbindung fehlgeschlagen. Überprüfe deine Internetverbindung.',
          );
          break;

        case 'failed-precondition':
          message = _myEventsText(
            context,
            tr: 'Etkinlik sorgusu için gerekli Firestore indeksi henüz hazır değil.',
            en: 'The Firestore index required for this event query is not ready yet.',
            de: 'Der für diese Veranstaltungsabfrage erforderliche Firestore-Index ist noch nicht bereit.',
          );
          break;

        default:
          if ((error.message ?? '').trim().isNotEmpty) {
            message = error.message!;
          }
      }
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.cloud_off_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _myEventsText(
                context,
                tr: 'Etkinlikler yüklenemedi',
                en: 'Events could not be loaded',
                de: 'Veranstaltungen konnten nicht geladen werden',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _refreshEvents,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignedOutState() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _myEventsText(
            context,
            tr: 'Etkinliklerim',
            en: 'My Events',
            de: 'Meine Veranstaltungen',
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.lock_person_outlined,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 18),
              Text(
                'Oturum gerekli',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _myEventsText(
                  context,
                  tr: 'Etkinliklerini görüntülemek için giriş yapmalısın.',
                  en: 'You must sign in to view your events.',
                  de: 'Du musst dich anmelden, um deine Veranstaltungen anzusehen.',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Map<String, dynamic> data) {
    final Color color = _statusColor(context, data);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(_statusIcon(data), size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            _statusLabel(data),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String text,
    Color? foregroundColor,
    Color? backgroundColor,
  }) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    final Color effectiveForeground =
        foregroundColor ?? colors.onSurfaceVariant;

    final Color effectiveBackground =
        backgroundColor ??
        colors.surfaceContainerHighest.withValues(alpha: 0.62);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: effectiveBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: effectiveForeground),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: effectiveForeground,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatorLine(Map<String, dynamic> data) {
    final String creatorUid = _creatorUid(data);
    final bool creatorIsCurrentUser = _isCreator(data);
    final String fallbackName = _creatorName(data);
    final String fallbackImageUrl = _creatorPhotoUrl(data);

    if (creatorUid.isEmpty) {
      return _buildResolvedCreatorLine(
        creatorUid: creatorUid,
        creatorIsCurrentUser: creatorIsCurrentUser,
        displayName: fallbackName,
        imageUrl: fallbackImageUrl,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('public_profiles')
          .doc(creatorUid)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic> profile =
                snapshot.data?.data() ?? <String, dynamic>{};

            final String liveName = _firstText(profile, <String>[
              'profilAdi',
              'profileName',
              'displayName',
            ], fallback: fallbackName);

            final String resolvedProfileImage = resolveUserImageUrl(profile);

            final String liveImageUrl = resolvedProfileImage.isNotEmpty
                ? resolvedProfileImage
                : fallbackImageUrl;

            return _buildResolvedCreatorLine(
              creatorUid: creatorUid,
              creatorIsCurrentUser: creatorIsCurrentUser,
              displayName: liveName,
              imageUrl: liveImageUrl,
            );
          },
    );
  }

  Widget _buildResolvedCreatorLine({
    required String creatorUid,
    required bool creatorIsCurrentUser,
    required String displayName,
    required String imageUrl,
  }) {
    final String safeName = displayName.trim().isEmpty
        ? _myEventsText(context, tr: 'Kullanıcı', en: 'User', de: 'Benutzer')
        : displayName.trim();

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: creatorIsCurrentUser || creatorUid.isEmpty
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PublicProfileScreen(userId: creatorUid),
                ),
              );
            },
      child: Row(
        children: <Widget>[
          UserAvatar(
            displayName: safeName,
            imageUrl: imageUrl,
            radius: 17,
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  creatorIsCurrentUser ? 'Sen' : safeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  'Etkinlik Sahibi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerProgress(Map<String, dynamic> data) {
    final int selected = _selectedPlayerCount(data);

    final int required = _requiredPlayerCount(data);

    final double progress = required <= 0
        ? 0
        : (selected / required).clamp(0.0, 1.0).toDouble();

    final bool isFull = _eventIsFull(data);

    final Color progressColor = isFull
        ? Colors.green.shade700
        : Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              isFull ? Icons.groups_rounded : Icons.group_add_outlined,
              size: 17,
              color: progressColor,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                isFull
                    ? _myEventsText(
                        context,
                        tr: 'Oyuncu kadrosu tamamlandı',
                        en: 'Player roster is complete',
                        de: 'Spielerkader ist vollständig',
                      )
                    : _playerCountText(data),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: progressColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (_isCreator(data) && _applicationCount(data) > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _myEventsText(
                    context,
                    tr: '${_applicationCount(data)} başvuru',
                    en: '${_applicationCount(data)} applications',
                    de: '${_applicationCount(data)} Bewerbungen',
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: progressColor.withValues(alpha: 0.13),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
      ],
    );
  }

  Widget _buildApplicationState(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data();

    if (_isCreator(data)) {
      final int count = _applicationCount(data);

      if (count <= 0) {
        return const SizedBox.shrink();
      }

      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _actionBusy ? null : () => _openApplicants(document),
        child: _buildInfoChip(
          icon: Icons.person_search_outlined,
          text: _myEventsText(
            context,
            tr: '$count bekleyen başvuru',
            en: '$count pending applications',
            de: '$count ausstehende Bewerbungen',
          ),
          foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer,
          backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
        ),
      );
    }

    if (_currentUserId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: EventService().watchApplication(
        eventId: document.id,
        playerId: _currentUserId,
      ),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final EventApplicationState state = EventApplicationState.fromMap(
              snapshot.data?.data(),
            );

            if (!state.exists) {
              if (_isParticipant(data)) {
                return _buildInfoChip(
                  icon: Icons.verified_outlined,
                  text: _myEventsText(
                    context,
                    tr: 'Katılımcı olarak seçildin',
                    en: 'You were selected as a participant',
                    de: 'Du wurdest als Teilnehmer ausgewählt',
                  ),
                  foregroundColor: Colors.green.shade800,
                  backgroundColor: Colors.green.shade50,
                );
              }

              if (_isApplicant(data)) {
                return _buildInfoChip(
                  icon: Icons.hourglass_top_rounded,
                  text: _myEventsText(
                    context,
                    tr: 'Başvurun değerlendiriliyor',
                    en: 'Your application is under review',
                    de: 'Deine Bewerbung wird geprüft',
                  ),
                  foregroundColor: Colors.orange.shade900,
                  backgroundColor: Colors.orange.shade50,
                );
              }

              return const SizedBox.shrink();
            }

            final bool positive = state.isPaid || state.isAddressUnlocked;
            final bool warning =
                state.isAcceptedWaitingRoster ||
                state.isAcceptedPaymentPending ||
                state.isPaymentProcessing ||
                state.isPending;

            return _buildInfoChip(
              icon: positive
                  ? Icons.verified_outlined
                  : warning
                  ? Icons.schedule_outlined
                  : state.isRejected
                  ? Icons.cancel_outlined
                  : Icons.info_outline_rounded,
              text: state.userLabel,
              foregroundColor: positive
                  ? Colors.green.shade800
                  : warning
                  ? Colors.orange.shade900
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              backgroundColor: positive
                  ? Colors.green.shade50
                  : warning
                  ? Colors.orange.shade50
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
            );
          },
    );
  }

  Widget _buildCardHeader(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data();

    final String category = _categoryName(data);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _gameAvatarColor(context, data),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _gameAvatarForeground(
                context,
                data,
              ).withValues(alpha: 0.14),
            ),
          ),
          child: GameBadgeEmblem(
            emoji: GameVisuals.emoji(_gameReference(data)),
            imageUrl: '',
            gameName: _gameReference(data),
            size: 46,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _eventTitle(data),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              if (category.isNotEmpty) ...<Widget>[
                const SizedBox(height: 5),
                Text(
                  category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        _buildStatusBadge(data),
      ],
    );
  }

  Widget _buildCardInformation(Map<String, dynamic> data) {
    final String preference = _membershipPreference(data);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _buildInfoChip(
          icon: Icons.calendar_month_outlined,
          text: _formatDateRange(data),
        ),
        _buildInfoChip(
          icon: Icons.location_on_outlined,
          text: _locationText(data),
        ),
        if (preference.isNotEmpty)
          _buildInfoChip(
            icon: Icons.workspace_premium_outlined,
            text: preference,
          ),
      ],
    );
  }

  Widget _buildDescriptionPreview(Map<String, dynamic> data) {
    final String description = _description(data);

    if (description.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        description,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
      ),
    );
  }

  Widget _buildPrimaryCardAction(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data();

    final bool busy = _busyEventIds.contains(document.id);

    if (_isCreator(data) &&
        _applicationCount(data) > 0 &&
        !_isCompleted(data) &&
        !_isCancelled(data)) {
      return FilledButton.icon(
        onPressed: busy ? null : () => _openApplicants(document),
        icon: const Icon(Icons.people_alt_outlined),
        label: Text(
          _myEventsText(
            context,
            tr: '${_applicationCount(data)} başvuruyu incele',
            en: 'Review ${_applicationCount(data)} applications',
            de: '${_applicationCount(data)} Bewerbungen prüfen',
          ),
        ),
      );
    }

    if (_hasChatMembership(data) &&
        !_isEventPaymentCompleted(data) &&
        !_isCancelled(data)) {
      final ColorScheme colors = Theme.of(context).colorScheme;

      return OutlinedButton.icon(
        onPressed: busy
            ? null
            : () {
                _showMessage(
                  _myEventsText(
                    context,
                    tr: 'Sohbet yalnızca kabul edilen oyunculara açıktır.',
                    en: 'Chat is available only to accepted players.',
                    de: 'Der Chat ist nur für angenommene Spieler verfügbar.',
                  ),
                );
              },
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          backgroundColor: colors.primary.withValues(alpha: 0.06),
          side: BorderSide(color: colors.primary.withValues(alpha: 0.55)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: const Icon(Icons.lock_outline_rounded, size: 20),
        label: Text(
          _myEventsText(
            context,
            tr: 'Sohbet Kilitli',
            en: 'Chat Locked',
            de: 'Chat gesperrt',
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }

    if (_canOpenChat(data) && !_isCancelled(data)) {
      return FilledButton.icon(
        onPressed: busy ? null : () => _openChat(document),
        icon: const Icon(Icons.forum_outlined),
        label: Text(
          _myEventsText(
            context,
            tr: 'Sohbeti Aç',
            en: 'Open Chat',
            de: 'Chat öffnen',
          ),
        ),
      );
    }

    return FilledButton.icon(
      onPressed: busy ? null : () => _openEvent(document),
      icon: const Icon(Icons.visibility_outlined),
      label: Text(
        _myEventsText(
          context,
          tr: 'Detayları Gör',
          en: 'View Details',
          de: 'Details anzeigen',
        ),
      ),
    );
  }

  Widget _buildSecondaryCardAction(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data();

    final bool busy = _busyEventIds.contains(document.id);

    if (_isCreator(data) && !_isCompleted(data) && !_isCancelled(data)) {
      return OutlinedButton.icon(
        onPressed: busy ? null : () => _cancelEvent(document),
        icon: const Icon(Icons.cancel_outlined),
        label: Text(
          _myEventsText(context, tr: 'İptal Et', en: 'Cancel', de: 'Absagen'),
        ),
      );
    }

    if (_isParticipant(data) && !_isCompleted(data) && !_isCancelled(data)) {
      return OutlinedButton.icon(
        onPressed: busy ? null : () => _leaveEvent(document),
        icon: const Icon(Icons.logout_outlined),
        label: Text(
          _myEventsText(context, tr: 'Ayrıl', en: 'Leave', de: 'Verlassen'),
        ),
      );
    }

    if (_isApplicant(data) &&
        !_isParticipant(data) &&
        !_isCompleted(data) &&
        !_isCancelled(data)) {
      return OutlinedButton.icon(
        onPressed: busy ? null : () => _withdrawApplication(document),
        icon: const Icon(Icons.undo_outlined),
        label: Text(
          _myEventsText(
            context,
            tr: 'Başvuruyu Geri Çek',
            en: 'Withdraw Application',
            de: 'Bewerbung zurückziehen',
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: busy ? null : () => _openEvent(document),
      icon: const Icon(Icons.info_outline),
      label: const Text('Detay'),
    );
  }

  Widget _buildCardActions(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final bool busy = _busyEventIds.contains(document.id);

    return Column(
      children: <Widget>[
        if (busy) ...<Widget>[
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 12),
        ],
        Row(
          children: <Widget>[
            Expanded(child: _buildSecondaryCardAction(document)),
            const SizedBox(width: 10),
            Expanded(child: _buildPrimaryCardAction(document)),
          ],
        ),
      ],
    );
  }

  Widget _buildEventCard(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final Map<String, dynamic> data = document.data();

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.75),
        ),
      ),
      child: InkWell(
        onTap: _actionBusy ? null : () => _openEvent(document),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildCardHeader(document),
              const SizedBox(height: 16),
              _buildCreatorLine(data),
              const SizedBox(height: 15),
              _buildCardInformation(data),
              const SizedBox(height: 15),
              _buildPlayerProgress(data),
              if (_isCreator(data) ||
                  _isParticipant(data) ||
                  _isApplicant(data)) ...<Widget>[
                const SizedBox(height: 12),
                _buildApplicationState(document),
              ],
              if (_description(data).isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                _buildDescriptionPreview(data),
              ],
              const SizedBox(height: 16),
              _buildCardActions(document),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(int tabIndex) {
    final bool hasFilters = _searchText.isNotEmpty || _selectedStatus != 'Tümü';

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 92,
              height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.72),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFilters
                    ? Icons.search_off_rounded
                    : _emptyIconForTab(tabIndex),
                size: 44,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              hasFilters
                  ? _myEventsText(
                      context,
                      tr: 'Sonuç bulunamadı',
                      en: 'No results found',
                      de: 'Keine Ergebnisse gefunden',
                    )
                  : _emptyTitleForTab(tabIndex),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              _emptyTextForTab(tabIndex),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            if (hasFilters) ...<Widget>[
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Filtreleri Temizle'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _emptyTitleForTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return _myEventsText(
          context,
          tr: 'Oluşturduğun etkinlik yok',
          en: 'You have not created any events',
          de: 'Du hast keine Veranstaltungen erstellt',
        );
      case 1:
        return _myEventsText(
          context,
          tr: 'Katıldığın etkinlik yok',
          en: 'You have not joined any events',
          de: 'Du hast an keinen Veranstaltungen teilgenommen',
        );
      case 2:
        return _myEventsText(
          context,
          tr: 'Bekleyen başvurun yok',
          en: 'You have no pending applications',
          de: 'Du hast keine ausstehenden Bewerbungen',
        );
      case 3:
        return 'Tamamlanan etkinlik yok';
      default:
        return _myEventsText(
          context,
          tr: 'Etkinlik bulunamadı',
          en: 'No events found',
          de: 'Keine Veranstaltungen gefunden',
        );
    }
  }

  void _clearAllFilters() {
    FocusScope.of(context).unfocus();
    _searchController.clear();

    setState(() {
      _searchText = '';
      _selectedStatus = 'Tümü';
    });
  }

  Widget _buildEventList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents, {
    required int tabIndex,
  }) {
    if (documents.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshEvents,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(tabIndex),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshEvents,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        itemCount: documents.length,
        separatorBuilder: (BuildContext context, int index) {
          return const SizedBox(height: 14);
        },
        itemBuilder: (BuildContext context, int index) {
          return _buildEventCard(documents[index]);
        },
      ),
    );
  }

  Widget _buildTabContent(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocuments,
    int tabIndex,
  ) {
    switch (tabIndex) {
      case 0:
        return _buildEventList(
          _createdEvents(allDocuments),
          tabIndex: tabIndex,
        );
      case 1:
        return _buildEventList(_joinedEvents(allDocuments), tabIndex: tabIndex);
      case 2:
        return _buildEventList(
          _appliedEvents(allDocuments),
          tabIndex: tabIndex,
        );
      case 3:
        return _buildEventList(
          _completedEvents(allDocuments),
          tabIndex: tabIndex,
        );
      default:
        return _buildEventList(
          <QueryDocumentSnapshot<Map<String, dynamic>>>[],
          tabIndex: tabIndex,
        );
    }
  }

  Widget _buildSearchField() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: !_showSearch
          ? const SizedBox.shrink()
          : Padding(
              key: const ValueKey<String>('search-field'),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: _myEventsText(
                    context,
                    tr: 'Oyun, şehir, konum veya organizatör ara',
                    en: 'Search by game, city, location, or organizer',
                    de: 'Nach Spiel, Stadt, Ort oder Veranstalter suchen',
                  ),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchText.isEmpty
                      ? null
                      : IconButton(
                          tooltip: _myEventsText(
                            context,
                            tr: 'Aramayı temizle',
                            en: 'Clear search',
                            de: 'Suche löschen',
                          ),
                          onPressed: () {
                            _searchController.clear();
                          },
                          icon: const Icon(Icons.close),
                        ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStatusFilters() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        itemCount: _statusFilters.length,
        separatorBuilder: (BuildContext context, int index) {
          return const SizedBox(width: 8);
        },
        itemBuilder: (BuildContext context, int index) {
          final String status = _statusFilters[index];
          final bool selected = status == _selectedStatus;

          return FilterChip(
            selected: selected,
            showCheckmark: false,
            label: Text(_statusFilterLabel(status)),
            avatar: Icon(_filterIcon(status), size: 17),
            onSelected: (bool value) {
              setState(() {
                _selectedStatus = status;
              });
            },
            labelStyle: TextStyle(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
            side: BorderSide(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          );
        },
      ),
    );
  }

  String _statusFilterLabel(String status) {
    switch (status) {
      case 'Aktif':
        return _myEventsText(context, tr: 'Aktif', en: 'Active', de: 'Aktiv');
      case 'Yaklaşan':
        return _myEventsText(
          context,
          tr: 'Yaklaşan',
          en: 'Upcoming',
          de: 'Bevorstehend',
        );
      case 'Tamamlanan':
        return _myEventsText(
          context,
          tr: 'Tamamlanan',
          en: 'Completed',
          de: 'Abgeschlossen',
        );
      case 'İptal':
        return _myEventsText(
          context,
          tr: 'İptal',
          en: 'Cancelled',
          de: 'Abgesagt',
        );
      default:
        return AppLocalizations.of(context)!.all;
    }
  }

  IconData _filterIcon(String status) {
    switch (status) {
      case 'Aktif':
        return Icons.play_circle_outline;
      case 'Yaklaşan':
        return Icons.schedule_outlined;
      case 'Tamamlanan':
        return Icons.check_circle_outline;
      case 'İptal':
        return Icons.cancel_outlined;
      default:
        return Icons.view_list_outlined;
    }
  }

  Widget _buildTabBar() {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        tabs: <Widget>[
          Tab(
            icon: Icon(Icons.add_circle_outline),
            text: _myEventsText(
              context,
              tr: 'Oluşturduklarım',
              en: 'Created',
              de: 'Erstellt',
            ),
          ),
          Tab(
            icon: Icon(Icons.groups_outlined),
            text: _myEventsText(
              context,
              tr: 'Katıldıklarım',
              en: 'Joined',
              de: 'Beigetreten',
            ),
          ),
          Tab(
            icon: Icon(Icons.hourglass_empty_rounded),
            text: _myEventsText(
              context,
              tr: 'Başvurularım',
              en: 'Applications',
              de: 'Bewerbungen',
            ),
          ),
          Tab(
            icon: Icon(Icons.task_alt_outlined),
            text: _myEventsText(
              context,
              tr: 'Tamamlananlar',
              en: 'Completed',
              de: 'Abgeschlossen',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildSearchField(),
        _buildStatusFilters(),
        _buildTabBar(),
        Divider(
          height: 1,
          thickness: 1,
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ],
    );
  }

  Widget _buildEventsStream() {
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: _watchAllEvents(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
            snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return _buildLoadingState();
            }

            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error);
            }

            final List<QueryDocumentSnapshot<Map<String, dynamic>>> documents =
                snapshot.data ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];

            return TabBarView(
              controller: _tabController,
              children: <Widget>[
                _buildTabContent(documents, 0),
                _buildTabContent(documents, 1),
                _buildTabContent(documents, 2),
                _buildTabContent(documents, 3),
              ],
            );
          },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId.isEmpty) {
      return _buildSignedOutState();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _myEventsText(
            context,
            tr: 'Etkinliklerim',
            en: 'My Events',
            de: 'Meine Veranstaltungen',
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: _showSearch
                ? _myEventsText(
                    context,
                    tr: 'Aramayı kapat',
                    en: 'Close search',
                    de: 'Suche schließen',
                  )
                : _myEventsText(
                    context,
                    tr: 'Etkinlik ara',
                    en: 'Search events',
                    de: 'Veranstaltungen suchen',
                  ),
            onPressed: _toggleSearch,
            icon: Icon(
              _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
            ),
          ),
          IconButton(
            tooltip: _myEventsText(
              context,
              tr: 'Yenile',
              en: 'Refresh',
              de: 'Aktualisieren',
            ),
            onPressed: _actionBusy ? null : _refreshEvents,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            if (_actionBusy) const LinearProgressIndicator(minHeight: 2),
            _buildHeaderArea(),
            Expanded(child: _buildEventsStream()),
          ],
        ),
      ),
    );
  }
}
