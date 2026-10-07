import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/event_application_state.dart';
import '../models/event_model.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../services/event_service.dart';
import '../services/event_rating_service.dart';
import 'public_profile_screen.dart';
import '../utils/game_cover_assets.dart';
import '../utils/support_categories.dart';
import '../widgets/game_visuals.dart';
import '../widgets/user_avatar.dart';
import 'create_support_request_screen.dart';
import 'event_chat_screen.dart';

String _eventText(
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

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> initialData;

  const EventDetailScreen({
    super.key,
    required this.eventId,
    required this.initialData,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _completionRequested = false;

  Future<void> _ensureCompleted(Map<String, dynamic> data) async {
    if (_completionRequested || !mounted) {
      return;
    }
    if (!EventModel.mapHasEnded(data) || EventModel.mapIsTerminal(data)) {
      return;
    }
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final String creator = data['olusturanUid']?.toString() ?? '';
    final bool selected = _stringList(
      data['selectedPlayerIds'],
    ).contains(user.uid);
    if (user.uid != creator && !selected) {
      return;
    }
    _completionRequested = true;
    try {
      await EventService().markEventCompleted(eventId: widget.eventId);
    } catch (_) {
      _completionRequested = false;
    }
  }

  bool busy = false;
  bool justApplied = false;

  DocumentReference<Map<String, dynamic>> get _eventRef =>
      FirebaseFirestore.instance.collection('events').doc(widget.eventId);

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  List<String> _stringList(dynamic value) {
    if (value is! Iterable) return <String>[];
    return value
        .map((dynamic item) => item.toString())
        .where((String item) => item.isNotEmpty)
        .toList();
  }

  bool _hasPlayerBadge(Map<String, dynamic> profile) {
    if (profile['oyuncuRozeti'] == true ||
        profile['playerBadge'] == true ||
        profile['playerBadgeStatus'] == 'approved') {
      return true;
    }

    final String name = profile['profilAdi']?.toString().trim() ?? '';
    final String city = profile['sehir']?.toString().trim() ?? '';
    final List<String> games = _stringList(profile['oyunlar']);

    return name.isNotEmpty && city.isNotEmpty && games.isNotEmpty;
  }

  Future<void> _apply(Map<String, dynamic> data) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || busy) return;

    final String creator = data['olusturanUid']?.toString() ?? '';
    final List<String> selectedPlayers = _stringList(data['selectedPlayerIds']);
    final List<String> applicants = _stringList(data['basvuranOyuncuIds']);

    if (creator == user.uid) {
      _message(
        _eventText(
          context,
          tr: 'Kendi etkinliğine başvuramazsın.',
          en: 'You cannot apply to your own event.',
          de: 'Du kannst dich nicht für deine eigene Veranstaltung bewerben.',
        ),
      );
      return;
    }
    if (selectedPlayers.contains(user.uid)) {
      _message(
        _eventText(
          context,
          tr: 'Bu etkinlik için zaten seçildin.',
          en: 'You have already been selected for this event.',
          de: 'Du wurdest bereits für diese Veranstaltung ausgewählt.',
        ),
      );
      return;
    }
    if (applicants.contains(user.uid)) {
      _message(
        _eventText(
          context,
          tr: 'Başvurun etkinlik sahibinin değerlendirmesini bekliyor.',
          en: 'Your application is waiting for the organizer’s review.',
          de: 'Deine Bewerbung wartet auf die Prüfung durch den Veranstalter.',
        ),
      );
      return;
    }

    final int needed = ((data['oyuncuSayisi'] as num?)?.toInt() ?? 1)
        .clamp(1, 4)
        .toInt();
    if (selectedPlayers.length >= needed) {
      _message(
        _eventText(
          context,
          tr: 'Bu etkinliğin oyuncu kontenjanı dolmuş.',
          en: 'This event is full.',
          de: 'Diese Veranstaltung ist voll.',
        ),
      );
      return;
    }

    final Map<String, dynamic> profile = await UserService.getProfileData();
    if (!_hasPlayerBadge(profile)) {
      _message(
        'Başvurmak için oyuncu profilini tamamlayıp Oyuncu Rozeti almalısın.',
      );
      return;
    }

    if (!mounted) return;
    final String preference = data['uyeTercihi']?.toString().trim() ?? 'Herkes';
    final bool playerIsPlus = profile['plus'] == true;

    if (preference == 'Plus Üye' && !playerIsPlus) {
      _message(
        _eventText(
          context,
          tr: 'Bu etkinlik yalnızca Plus oyuncu başvurularını kabul ediyor.',
          en: 'This event only accepts applications from Plus players.',
          de: 'Diese Veranstaltung akzeptiert nur Bewerbungen von Plus-Spielern.',
        ),
      );
      return;
    }
    if (preference == 'Normal Üye' && playerIsPlus) {
      _message(
        _eventText(
          context,
          tr: 'Etkinlik sahibi bu etkinlikte Normal Üye tercih etmiş.',
          en: 'The event owner has selected Standard Member for this event.',
          de: 'Der Veranstalter hat für diese Veranstaltung Standardmitglieder ausgewählt.',
        ),
      );
      return;
    }

    setState(() => busy = true);
    try {
      await EventService().applyToEvent(eventId: widget.eventId);

      if (!mounted) return;
      if (mounted) {
        setState(() {
          justApplied = true;
        });
      }

      _message(
        _eventText(
          context,
          tr: 'Başvurun etkinlik sahibine gönderildi.',
          en: 'Your application was sent to the organizer.',
          de: 'Deine Bewerbung wurde an den Veranstalter gesendet.',
        ),
      );
    } on StateError catch (error) {
      _message(error.message.toString());
    } catch (error) {
      _message('Başvuru gönderilemedi: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _reviewApplicant(
    Map<String, dynamic> data,
    String applicantUid,
    bool accept,
  ) async {
    if (busy) return;

    setState(() => busy = true);
    try {
      if (accept) {
        await EventService().acceptApplication(
          eventId: widget.eventId,
          playerId: applicantUid,
        );
      } else {
        await EventService().rejectApplication(
          eventId: widget.eventId,
          playerId: applicantUid,
        );
      }

      if (!mounted) return;
      _message(
        accept
            ? 'Oyuncu kabul edildi.'
            : _eventText(
                context,
                tr: 'Başvuru reddedildi.',
                en: 'Application rejected.',
                de: 'Bewerbung abgelehnt.',
              ),
      );
    } on StateError catch (error) {
      _message(error.message.toString());
    } catch (error) {
      _message('İşlem tamamlanamadı: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _cancelEvent(Map<String, dynamic> data) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || busy) return;

    final String? reason = await _askText(
      title: _eventText(
        context,
        tr: 'Etkinliği iptal et',
        en: 'Cancel event',
        de: 'Veranstaltung absagen',
      ),
      hint: _eventText(
        context,
        tr: 'İptal nedenini yaz',
        en: 'Enter cancellation reason',
        de: 'Stornierungsgrund eingeben',
      ),
      confirmText: _eventText(
        context,
        tr: 'İptal et',
        en: 'Cancel event',
        de: 'Absagen',
      ),
    );
    if (reason == null) return;

    if (!mounted) return;
    final bool confirmed = await _confirm(
      title: _eventText(
        context,
        tr: 'İptali onayla',
        en: 'Confirm cancellation',
        de: 'Stornierung bestätigen',
      ),
      message: 'Etkinlik iptal edilecek. Devam edilsin mi?',
      confirmText: 'Evet, iptal et',
    );
    if (!confirmed) return;

    setState(() => busy = true);
    try {
      await EventService().cancelUnpaidEvent(
        eventId: widget.eventId,
        reason: reason,
      );

      _message('Etkinlik iptal edildi.');
    } catch (error) {
      _message('Etkinlik iptal edilemedi: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<String?> _askText({
    required String title,
    required String hint,
    required String confirmText,
  }) async {
    final TextEditingController controller = TextEditingController();

    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
            decoration: InputDecoration(hintText: hint),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                _eventText(
                  context,
                  tr: 'Vazgeç',
                  en: 'Cancel',
                  de: 'Abbrechen',
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                final String text = controller.text.trim();
                if (text.length < 5) {
                  _message(
                    _eventText(
                      context,
                      tr: 'Lütfen daha açıklayıcı bir neden yaz.',
                      en: 'Please enter a more detailed reason.',
                      de: 'Bitte gib einen ausführlicheren Grund an.',
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, text);
              },
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return value;
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(
                    _eventText(
                      context,
                      tr: 'Vazgeç',
                      en: 'Cancel',
                      de: 'Abbrechen',
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(confirmText),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _openNavigation(Map<String, dynamic> data) async {
    if (busy) return;

    setState(() => busy = true);

    try {
      final Map<String, dynamic> privateLocation = await EventService()
          .getPrivateLocation(eventId: widget.eventId);

      final double latitude =
          (privateLocation['latitude'] as num?)?.toDouble() ?? 0;
      final double longitude =
          (privateLocation['longitude'] as num?)?.toDouble() ?? 0;

      final String address = <String>[
        privateLocation['adres']?.toString().trim() ?? '',
        privateLocation['semt']?.toString().trim() ?? '',
        privateLocation['ilce']?.toString().trim() ?? '',
        privateLocation['sehir']?.toString().trim() ?? '',
      ].where((String value) => value.isNotEmpty).join(', ');

      Uri uri;
      if (latitude != 0 && longitude != 0) {
        uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
        );
      } else if (address.isNotEmpty) {
        uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
        );
      } else {
        if (!mounted) return;
        _message(
          _eventText(
            context,
            tr: 'Yol tarifi için konum bilgisi bulunamadı.',
            en: 'Location information for directions was not found.',
            de: 'Standortinformationen für die Wegbeschreibung wurden nicht gefunden.',
          ),
        );
        return;
      }

      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;
      if (!launched) {
        _message(
          _eventText(
            context,
            tr: 'Navigasyon uygulaması açılamadı.',
            en: 'Navigation app could not be opened.',
            de: 'Die Navigations-App konnte nicht geöffnet werden.',
          ),
        );
      }
    } on StateError catch (error) {
      _message(error.message.toString());
    } catch (_) {
      _message('Açık adres ve yol tarifi şu anda alınamadı.');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> _openChat(String game) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final bool allowed;
    try {
      allowed = await ChatService().canCurrentUserAccessChat(widget.eventId);
    } catch (_) {
      if (!mounted) return;
      _message(
        _eventText(
          context,
          tr: 'Sohbet erişimi doğrulanamadı. Lütfen tekrar dene.',
          en: 'Chat access could not be verified. Please try again.',
          de:
              'Der Chat-Zugriff konnte nicht geprüft werden. '
              'Bitte versuche es erneut.',
        ),
      );
      return;
    }

    if (!allowed) {
      if (!mounted) return;
      _message(
        _eventText(
          context,
          tr: 'Sohbet yalnızca kabul edilen oyunculara açıktır.',
          en: 'Chat is available only to accepted players.',
          de: 'Der Chat ist nur für angenommene Spieler verfügbar.',
        ),
      );
      return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            EventChatScreen(eventId: widget.eventId, eventTitle: _clean(game)),
      ),
    );
  }

  void _showApplicants(Map<String, dynamic> data) {
    final List<String> applicants = _stringList(data['basvuranOyuncuIds']);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.72,
            child: applicants.isEmpty
                ? Center(
                    child: Text(
                      _eventText(
                        context,
                        tr: 'Henüz başvuru yok.',
                        en: 'No applications yet.',
                        de: 'Noch keine Bewerbungen.',
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: applicants.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, int index) {
                      final String uid = applicants[index];
                      return _ApplicantTile(
                        uid: uid,
                        busy: busy,
                        onAccept: () {
                          Navigator.pop(sheetContext);
                          _reviewApplicant(data, uid, true);
                        },
                        onReject: () {
                          Navigator.pop(sheetContext);
                          _reviewApplicant(data, uid, false);
                        },
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  Widget _applicationStatusCard({required String userId}) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: EventService().watchApplication(
        eventId: widget.eventId,
        playerId: userId,
      ),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final EventApplicationState state = EventApplicationState.fromMap(
              snapshot.data?.data(),
            );

            if (!state.exists || state.userLabel.isEmpty) {
              return const SizedBox.shrink();
            }

            final ColorScheme colors = Theme.of(context).colorScheme;

            final bool positive = state.isPaid || state.isAddressUnlocked;
            final bool warning =
                state.isAcceptedPaymentPending || state.isPaymentProcessing;

            final Color background = positive
                ? colors.primaryContainer
                : warning
                ? colors.tertiaryContainer
                : colors.surfaceContainerHighest;

            final IconData icon = positive
                ? Icons.verified_rounded
                : warning
                ? Icons.schedule_rounded
                : state.isRejected
                ? Icons.cancel_outlined
                : Icons.info_outline_rounded;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(icon),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        state.userLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
    );
  }

  Widget _navigationButton({
    required Map<String, dynamic> data,
    required User? user,
    required bool isCreator,
    required bool selected,
  }) {
    if (isCreator) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: busy ? null : () => _openNavigation(data),
          icon: const Icon(Icons.navigation_rounded),
          label: const Text('Yol Tarifi Al'),
        ),
      );
    }

    if (user == null || !selected) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: null,
          child: Text(
            _eventText(
              context,
              tr: 'Adres yalnızca onaylanan oyunculara açılır',
              en: 'Address is shown only to approved players',
              de: 'Die Adresse wird nur bestätigten Spielern angezeigt',
            ),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: EventService().watchApplication(
        eventId: widget.eventId,
        playerId: user.uid,
      ),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final EventApplicationState state = EventApplicationState.fromMap(
              snapshot.data?.data(),
            );

            final bool unlocked = state.isAddressUnlocked;

            return SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: unlocked && !busy
                    ? () => _openNavigation(data)
                    : null,
                icon: Icon(
                  unlocked
                      ? Icons.navigation_rounded
                      : Icons.lock_outline_rounded,
                ),
                label: Text(
                  unlocked
                      ? 'Yol Tarifi Al'
                      : state.isAcceptedPaymentPending ||
                            state.isPaymentProcessing
                      ? _eventText(
                          context,
                          tr: 'Etkinlik durumu güncelleniyor',
                          en: 'Event status is updating',
                          de: 'Veranstaltungsstatus wird aktualisiert',
                        )
                      : _eventText(
                          context,
                          tr: 'Adres organizatör kabul edince açılır',
                          en: 'Address unlocks when the organizer accepts you',
                          de: 'Die Adresse wird freigeschaltet, wenn der Veranstalter dich annimmt',
                        ),
                ),
              ),
            );
          },
    );
  }

  Widget _applicationActionButton({
    required Map<String, dynamic> data,
    required User? user,
    required bool isCreator,
    required bool selected,
    required bool fallbackApplied,
    required bool full,
    required bool closed,
  }) {
    if (user == null || isCreator || selected) {
      return FilledButton.icon(
        onPressed: null,
        style: FilledButton.styleFrom(
          disabledBackgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
          disabledForegroundColor: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant,
        ),
        icon: Icon(
          isCreator ? Icons.manage_accounts_outlined : Icons.check_circle,
        ),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            isCreator
                ? _eventText(
                    context,
                    tr: 'Sen oluşturdun',
                    en: 'You created this',
                    de: 'Von dir erstellt',
                  )
                : _eventText(
                    context,
                    tr: 'Seçildin',
                    en: 'Selected',
                    de: 'Ausgewählt',
                  ),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: EventService().watchApplication(
        eventId: widget.eventId,
        playerId: user.uid,
      ),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final EventApplicationState state = EventApplicationState.fromMap(
              snapshot.data?.data(),
            );

            final bool applicationExists =
                state.blocksNewApplication || fallbackApplied;

            final bool disabled = applicationExists || full || closed || busy;

            String label = _eventText(
              context,
              tr: 'Başvur',
              en: 'Apply',
              de: 'Bewerben',
            );
            IconData icon = Icons.person_add_alt_1;

            if (state.isPending || fallbackApplied) {
              label = 'Karar bekleniyor';
              icon = Icons.schedule_outlined;
            } else if (state.isAcceptedPaymentPending ||
                state.isPaymentProcessing) {
              label = _eventText(
                context,
                tr: 'Etkinlik durumu güncelleniyor',
                en: 'Event status is updating',
                de: 'Veranstaltungsstatus wird aktualisiert',
              );
              icon = Icons.schedule_outlined;
            } else if (state.isPaid || state.isAddressUnlocked) {
              label = _eventText(
                context,
                tr: 'Kadroya alındın',
                en: 'You are on the roster',
                de: 'Du bist im Kader',
              );
              icon = Icons.verified_rounded;
            } else if (state.isRejected) {
              label = _eventText(
                context,
                tr: 'Tekrar başvur',
                en: 'Apply again',
                de: 'Erneut bewerben',
              );
              icon = Icons.refresh_rounded;
            } else if (full) {
              label = 'Kontenjan dolu';
              icon = Icons.group_off_outlined;
            }

            return FilledButton.icon(
              onPressed: disabled ? null : () => _apply(data),
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(icon),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(label),
              ),
            );
          },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _eventRef.snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic> data =
                snapshot.data?.data() ?? widget.initialData;

            final String game = data['oyun']?.toString() ?? 'Etkinlik';
            final String gameId = data['gameId']?.toString() ?? '';
            final String city = data['sehir']?.toString().trim() ?? '';
            final String district = data['ilce']?.toString().trim() ?? '';
            final String description =
                data['aciklama']?.toString().trim() ?? '';
            final DateTime? date = data['tarih'] is Timestamp
                ? (data['tarih'] as Timestamp).toDate()
                : null;

            final User? user = FirebaseAuth.instance.currentUser;
            final String creator = data['olusturanUid']?.toString() ?? '';
            final bool isCreator = user?.uid == creator;
            final List<String> selectedPlayers = _stringList(
              data['selectedPlayerIds'],
            );
            final List<String> applicants = _stringList(
              data['basvuranOyuncuIds'],
            );
            final bool selected =
                user != null && selectedPlayers.contains(user.uid);
            final bool applied =
                justApplied || (user != null && applicants.contains(user.uid));
            final int needed = ((data['oyuncuSayisi'] as num?)?.toInt() ?? 1)
                .clamp(1, 4)
                .toInt();
            final bool full = selectedPlayers.length >= needed;
            final String status = data['durum']?.toString() ?? 'aktif';
            final bool ended = EventModel.mapHasEnded(data);
            final bool cancelled = status == 'iptal' || status == 'cancelled';
            final bool completed =
                status == 'completed' ||
                status == 'tamamlandi' ||
                status == 'tamamlandı';
            final bool closed = cancelled || completed || ended;
            final String displayStatus = cancelled
                ? status
                : (completed || ended)
                ? 'tamamlandi'
                : status;
            if (ended && !completed && !cancelled) {
              _ensureCompleted(data);
            }

            final String publicLocationText = <String>[
              city,
              district,
            ].where((String value) => value.isNotEmpty).join(' - ');

            final String locationText = publicLocationText;

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  _eventText(
                    context,
                    tr: 'Etkinlik Detayı',
                    en: 'Event Details',
                    de: 'Veranstaltungsdetails',
                  ),
                ),
                centerTitle: true,
                actions: <Widget>[
                  if (!isCreator)
                    IconButton(
                      tooltip: _eventText(
                        context,
                        tr: 'Etkinliği Şikâyet Et',
                        en: 'Report Event',
                        de: 'Veranstaltung melden',
                      ),
                      onPressed: busy
                          ? null
                          : () async {
                              await Navigator.push<bool>(
                                context,
                                MaterialPageRoute<bool>(
                                  builder: (_) => CreateSupportRequestScreen(
                                    category: SupportCategory.eventReport,
                                    relatedEventId: widget.eventId,
                                  ),
                                ),
                              );
                            },
                      icon: const Icon(Icons.flag_outlined),
                    ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
                children: <Widget>[
                  _GameCoverHeader(
                    game: gameId.isNotEmpty ? gameId : game,
                    color: _color(game),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _clean(game),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      _StatusChip(status: displayStatus),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _info(
                    Icons.calendar_month_rounded,
                    date == null
                        ? 'Tarih belirtilmedi'
                        : DateFormat('dd.MM.yyyy • HH:mm').format(date),
                  ),
                  _info(
                    Icons.location_on_rounded,
                    locationText.isEmpty ? 'Konum belirtilmedi' : locationText,
                  ),
                  _info(
                    Icons.groups_rounded,
                    '${EventModel.acceptedPlayerCount(data)}/$needed oyuncu seçildi',
                  ),
                  _info(
                    Icons.workspace_premium_outlined,
                    'Oyuncu tercihi: ${data['uyeTercihi'] ?? 'Herkes'}',
                  ),
                  const SizedBox(height: 4),
                  _NoticeCard(
                    icon: Icons.cloud_outlined,
                    title: 'Hava durumunu kontrol et',
                    text:
                        'Yola çıkmadan önce etkinlik saatindeki hava koşullarını kontrol et.',
                  ),
                  const SizedBox(height: 10),
                  if (!isCreator && user != null)
                    _applicationStatusCard(userId: user.uid),
                  _navigationButton(
                    data: data,
                    user: user,
                    isCreator: isCreator,
                    selected: selected,
                  ),
                  const SizedBox(height: 14),
                  _sectionTitle('Etkinlik Sahibi'),
                  const SizedBox(height: 8),
                  _OrganizerCard(
                    uid: creator,
                    fallbackName: data['olusturanProfilAdi']?.toString() ?? '',
                    fallbackPhotoUrl: resolveUserImageUrl(data),
                    fallbackVerified: data['olusturanDogrulanmis'] == true,
                    fallbackPlus: data['olusturanPlus'] == true,
                  ),
                  const SizedBox(height: 12),
                  if (selectedPlayers.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionTitle(
                      _eventText(
                        context,
                        tr: 'Seçilen Oyuncular',
                        en: 'Selected Players',
                        de: 'Ausgewählte Spieler',
                      ),
                    ),
                    ...selectedPlayers.map(
                      (uid) => _ApplicantTile(
                        uid: uid,
                        busy: busy,
                        onAccept: () {},
                        onReject: () {},
                        showReviewActions: false,
                      ),
                    ),
                  ],
                  if (user != null && completed && !cancelled) ...[
                    const SizedBox(height: 20),
                    _EventRatingSection(eventId: widget.eventId),
                  ],
                  _sectionTitle(
                    _eventText(
                      context,
                      tr: 'Açıklama',
                      en: 'Description',
                      de: 'Beschreibung',
                    ),
                  ),
                  Text(
                    description.isEmpty
                        ? _eventText(
                            context,
                            tr: 'Etkinlik açıklaması eklenmemiş.',
                            en: 'No event description added.',
                            de: 'Keine Veranstaltungsbeschreibung hinzugefügt.',
                          )
                        : description,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                  if (isCreator) ...<Widget>[
                    const SizedBox(height: 22),
                    _sectionTitle(
                      _eventText(
                        context,
                        tr: 'Etkinlik Sahibi İşlemleri',
                        en: 'Organizer Actions',
                        de: 'Veranstalter-Aktionen',
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.group_add_outlined),
                      title: Text(
                        _eventText(
                          context,
                          tr: 'Oyuncu başvuruları',
                          en: 'Player applications',
                          de: 'Spielerbewerbungen',
                        ),
                      ),
                      subtitle: Text('${applicants.length} bekleyen başvuru'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: busy || closed
                          ? null
                          : () => _showApplicants(data),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.cancel_outlined),
                      title: Text(
                        _eventText(
                          context,
                          tr: 'Etkinliği iptal et',
                          en: 'Cancel event',
                          de: 'Veranstaltung absagen',
                        ),
                      ),
                      subtitle: const Text('Etkinlik iptal edilecek.'),
                      onTap: busy || closed ? null : () => _cancelEvent(data),
                    ),
                  ],
                ],
              ),
              bottomNavigationBar: SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _ChatAccessButton(
                            eventId: widget.eventId,
                            eventData: data,
                            onOpen: () => _openChat(game),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _applicationActionButton(
                            data: data,
                            user: user,
                            isCreator: isCreator,
                            selected: selected,
                            fallbackApplied: applied,
                            full: full,
                            closed: closed,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _info(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: const Color(0xffFF9800)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _clean(String value) {
    return GameVisuals.name(value);
  }

  Color _color(String value) {
    return GameVisuals.color(value);
  }
}

class _ChatAccessButton extends StatelessWidget {
  const _ChatAccessButton({
    required this.eventId,
    required this.eventData,
    required this.onOpen,
  });

  final String eventId;
  final Map<String, dynamic> eventData;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _button(context: context, enabled: false);
    }

    if (!ChatService.requiresCanonicalApplication(eventData, user.uid)) {
      return _button(
        context: context,
        enabled: ChatService.messageReadAllowed(
          event: eventData,
          uid: user.uid,
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: EventService().watchApplication(
        eventId: eventId,
        playerId: user.uid,
      ),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            return _button(
              context: context,
              enabled: ChatService.messageReadAllowed(
                event: eventData,
                uid: user.uid,
                application: snapshot.data?.data(),
                applicationResolved: snapshot.hasData,
              ),
            );
          },
    );
  }

  Widget _button({required BuildContext context, required bool enabled}) {
    final Widget button = OutlinedButton.icon(
      onPressed: enabled ? onOpen : null,
      style: OutlinedButton.styleFrom(
        disabledForegroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        side: BorderSide(
          color: enabled
              ? Theme.of(context).colorScheme.outline
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      icon: const Icon(Icons.forum_outlined),
      label: const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Sohbet'),
      ),
    );

    if (enabled) {
      return button;
    }

    return Tooltip(
      message: _eventText(
        context,
        tr: 'Sohbet yalnızca kabul edilen oyunculara açıktır.',
        en: 'Chat is available only to accepted players.',
        de: 'Der Chat ist nur für angenommene Spieler verfügbar.',
      ),
      child: button,
    );
  }
}

class _EventRatingSection extends StatefulWidget {
  const _EventRatingSection({required this.eventId});

  final String eventId;

  @override
  State<_EventRatingSection> createState() => _EventRatingSectionState();
}

class _EventRatingSectionState extends State<_EventRatingSection> {
  final EventRatingService _service = EventRatingService();

  late Future<EventRatingState> _future;
  final Set<String> _busyTargets = <String>{};

  @override
  void initState() {
    super.initState();
    _future = _service.getState(eventId: widget.eventId);
  }

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _future = _service.getState(eventId: widget.eventId);
    });
  }

  void _message(String text) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _rate(String targetUid) async {
    if (_busyTargets.contains(targetUid)) {
      return;
    }

    final _RatingDialogResult? result = await showDialog<_RatingDialogResult>(
      context: context,
      builder: (BuildContext dialogContext) {
        return const _RatingDialog();
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _busyTargets.add(targetUid);
    });

    try {
      await _service.submit(
        eventId: widget.eventId,
        targetUid: targetUid,
        rating: result.rating,
        comment: result.comment,
      );

      if (!mounted) return;
      _message(
        _eventText(
          context,
          tr: 'Değerlendirmen kaydedildi.',
          en: 'Your rating was saved.',
          de: 'Deine Bewertung wurde gespeichert.',
        ),
      );
      await _refresh();
    } on StateError catch (error) {
      _message(error.message.toString());
    } catch (_) {
      if (!mounted) return;
      _message(
        _eventText(
          context,
          tr: 'Değerlendirme gönderilemedi.',
          en: 'Rating could not be submitted.',
          de: 'Die Bewertung konnte nicht gesendet werden.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyTargets.remove(targetUid);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EventRatingState>(
      future: _future,
      builder:
          (BuildContext context, AsyncSnapshot<EventRatingState> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('Değerlendirme bilgileri yükleniyor...'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(
                    _eventText(
                      context,
                      tr: 'Etkinlik değerlendirmesi',
                      en: 'Event rating',
                      de: 'Veranstaltungsbewertung',
                    ),
                  ),
                  subtitle: const Text(
                    'Değerlendirme bilgileri şu anda alınamadı.',
                  ),
                  trailing: IconButton(
                    tooltip: 'Tekrar dene',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ),
              );
            }

            final EventRatingState? state = snapshot.data;

            if (state == null || !state.completed || state.targets.isEmpty) {
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Etkinlik Değerlendirmesi',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                ...state.targets.map((EventRatingTargetState target) {
                  return _RatingTargetTile(
                    target: target,
                    busy: _busyTargets.contains(target.targetUid),
                    onRate: () => _rate(target.targetUid),
                  );
                }),
              ],
            );
          },
    );
  }
}

class _RatingTargetTile extends StatelessWidget {
  const _RatingTargetTile({
    required this.target,
    required this.busy,
    required this.onRate,
  });

  final EventRatingTargetState target;
  final bool busy;
  final VoidCallback onRate;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('public_profiles')
          .doc(target.targetUid)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic> profile =
                snapshot.data?.data() ?? <String, dynamic>{};

            final String profileName =
                profile['profilAdi']?.toString().trim() ?? '';
            final String displayName =
                profile['displayName']?.toString().trim() ?? '';
            final String name = profileName.isNotEmpty
                ? profileName
                : displayName.isNotEmpty
                ? displayName
                : 'Kullanıcı';

            final String photoUrl = resolveUserImageUrl(profile);

            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: UserAvatar(
                  displayName: name,
                  imageUrl: photoUrl,
                  radius: 22,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondaryContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onSecondaryContainer,
                ),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: target.submitted
                    ? Row(
                        children: <Widget>[
                          const Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: Color(0xffFF9800),
                          ),
                          const SizedBox(width: 4),
                          Text('${target.rating ?? 0}/5 • Değerlendirildi'),
                        ],
                      )
                    : const Text('Bu etkinlik için değerlendirme bekleniyor.'),
                trailing: target.submitted
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                      )
                    : FilledButton(
                        onPressed: busy ? null : onRate,
                        child: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Puanla'),
                      ),
              ),
            );
          },
    );
  }
}

class _RatingDialogResult {
  const _RatingDialogResult({required this.rating, required this.comment});

  final int rating;
  final String comment;
}

class _RatingDialog extends StatefulWidget {
  const _RatingDialog();

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  final TextEditingController _commentController = TextEditingController();

  int _rating = 5;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _eventText(
          context,
          tr: 'Etkinliği değerlendir',
          en: 'Rate event',
          de: 'Veranstaltung bewerten',
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _eventText(
                context,
                tr: 'Puanın',
                en: 'Your rating',
                de: 'Deine Bewertung',
              ),
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(5, (int index) {
                final int value = index + 1;

                return IconButton(
                  tooltip: '$value yıldız',
                  onPressed: () {
                    setState(() {
                      _rating = value;
                    });
                  },
                  icon: Icon(
                    value <= _rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: const Color(0xffFF9800),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: 'Yorum',
                hintText: 'İstersen kısa bir yorum yazabilirsin.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            _eventText(context, tr: 'Vazgeç', en: 'Cancel', de: 'Abbrechen'),
          ),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              _RatingDialogResult(
                rating: _rating,
                comment: _commentController.text.trim(),
              ),
            );
          },
          child: Text(
            _eventText(context, tr: 'Gönder', en: 'Submit', de: 'Senden'),
          ),
        ),
      ],
    );
  }
}

class _ApplicantTile extends StatelessWidget {
  final String uid;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool showReviewActions;

  const _ApplicantTile({
    required this.uid,
    required this.busy,
    required this.onAccept,
    required this.onReject,
    this.showReviewActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('public_profiles')
          .doc(uid)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic> profile =
                snapshot.data?.data() ?? <String, dynamic>{};
            final String name =
                profile['profilAdi']?.toString().trim().isNotEmpty == true
                ? profile['profilAdi'].toString().trim()
                : 'Oyuncu';
            final String photo =
                profile['profilFotografi']?.toString().trim() ??
                profile['profilFotoUrl']?.toString().trim() ??
                '';

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                child: photo.isEmpty ? Text(name[0].toUpperCase()) : null,
              ),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                profile['plus'] == true ? 'Plus oyuncu' : 'Oyuncu',
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PublicProfileScreen(userId: uid),
                  ),
                );
              },
              trailing: showReviewActions
                  ? Wrap(
                      spacing: 4,
                      children: <Widget>[
                        IconButton(
                          tooltip: 'Reddet',
                          onPressed: busy ? null : onReject,
                          icon: const Icon(Icons.close),
                        ),
                        IconButton(
                          tooltip: 'Kabul et',
                          onPressed: busy ? null : onAccept,
                          icon: const Icon(Icons.check_circle),
                        ),
                      ],
                    )
                  : null,
            );
          },
    );
  }
}

class _OrganizerCard extends StatelessWidget {
  final String uid;
  final String fallbackName;
  final String fallbackPhotoUrl;
  final bool fallbackVerified;
  final bool fallbackPlus;

  const _OrganizerCard({
    required this.uid,
    required this.fallbackName,
    required this.fallbackPhotoUrl,
    required this.fallbackVerified,
    required this.fallbackPlus,
  });

  @override
  Widget build(BuildContext context) {
    if (uid.trim().isEmpty) {
      return _card(
        context,
        name: fallbackName,
        photoUrl: fallbackPhotoUrl,
        verified: fallbackVerified,
        plus: fallbackPlus,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('public_profiles')
          .doc(uid)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic> profile =
                snapshot.data?.data() ?? <String, dynamic>{};
            final String profileName =
                profile['profilAdi']?.toString().trim() ?? '';
            final String displayName =
                profile['displayName']?.toString().trim() ?? '';
            final String name = profileName.isNotEmpty
                ? profileName
                : displayName.isNotEmpty
                ? displayName
                : fallbackName.trim();
            final String liveImageUrl = resolveUserImageUrl(profile);
            final String photoUrl = liveImageUrl.isNotEmpty
                ? liveImageUrl
                : fallbackPhotoUrl;
            final bool verified =
                profile['verified'] == true ||
                profile['verificationStatus'] == 'approved' ||
                fallbackVerified;
            final bool plus = profile['plus'] == true || fallbackPlus;

            return _card(
              context,
              name: name,
              photoUrl: photoUrl,
              verified: verified,
              plus: plus,
            );
          },
    );
  }

  Widget _card(
    BuildContext context, {
    required String name,
    required String photoUrl,
    required bool verified,
    required bool plus,
  }) {
    final String safeName = name.trim().isEmpty ? 'Kullanıcı' : name.trim();

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: UserAvatar(
          displayName: safeName,
          imageUrl: photoUrl,
          radius: 24,
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
        title: Row(
          children: <Widget>[
            Flexible(
              child: Text(
                safeName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (verified) ...<Widget>[
              const SizedBox(width: 5),
              const Icon(Icons.verified, size: 18, color: Colors.blue),
            ],
            if (plus) ...<Widget>[
              const SizedBox(width: 5),
              const Icon(Icons.diamond, size: 17, color: Color(0xffFF9800)),
            ],
          ],
        ),
        subtitle: const Text('Etkinlik Sahibi'),
        onTap: uid.trim().isEmpty
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PublicProfileScreen(userId: uid),
                  ),
                );
              },
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(text),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final String label;
    switch (status) {
      case 'oyuncularSecildi':
        label = _eventText(
          context,
          tr: 'Oyuncular seçildi',
          en: 'Players selected',
          de: 'Spieler ausgewählt',
        );
        break;
      case 'cancellationRequested':
        label = _eventText(
          context,
          tr: 'İptal inceleniyor',
          en: 'Cancellation under review',
          de: 'Stornierung wird geprüft',
        );
        break;
      case 'iptal':
      case 'cancelled':
        label = _eventText(
          context,
          tr: 'İptal edildi',
          en: 'Cancelled',
          de: 'Abgesagt',
        );
        break;
      case 'completed':
      case 'tamamlandi':
        label = _eventText(
          context,
          tr: 'Tamamlandı',
          en: 'Completed',
          de: 'Abgeschlossen',
        );
        break;
      default:
        label = 'Aktif';
        break;
    }

    return Chip(label: Text(label));
  }
}

class _GameCoverHeader extends StatelessWidget {
  const _GameCoverHeader({required this.game, required this.color});

  final String game;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final String? cover = GameCoverAssets.pathFor(game);
    final Widget fallback = Container(
      height: 82,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[color, color.withValues(alpha: 0.55)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Center(
        child: Icon(
          Icons.sports_rounded,
          color: Colors.white.withValues(alpha: 0.9),
          size: 32,
        ),
      ),
    );
    if (cover == null) {
      return fallback;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Image.asset(
        cover,
        height: 168,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
