import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/user_service.dart';
import 'public_profile_screen.dart';
import '../utils/support_categories.dart';
import '../widgets/game_visuals.dart';
import '../widgets/user_avatar.dart';
import 'create_support_request_screen.dart';
import 'event_chat_screen.dart';

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
  bool busy = false;

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
      _message('Kendi etkinliğine başvuramazsın.');
      return;
    }
    if (selectedPlayers.contains(user.uid)) {
      _message('Bu etkinlik için zaten seçildin.');
      return;
    }
    if (applicants.contains(user.uid)) {
      _message('Başvurun etkinlik sahibinin değerlendirmesini bekliyor.');
      return;
    }

    final int needed = ((data['oyuncuSayisi'] as num?)?.toInt() ?? 1)
        .clamp(1, 4)
        .toInt();
    if (selectedPlayers.length >= needed) {
      _message('Bu etkinliğin oyuncu kontenjanı dolmuş.');
      return;
    }

    final Map<String, dynamic> profile = await UserService.getProfileData();
    if (!_hasPlayerBadge(profile)) {
      _message(
        'Başvurmak için oyuncu profilini tamamlayıp Oyuncu Rozeti almalısın.',
      );
      return;
    }

    final String preference = data['uyeTercihi']?.toString().trim() ?? 'Herkes';
    final bool playerIsPlus = profile['plus'] == true;

    if (preference == 'Plus Üye' && !playerIsPlus) {
      _message('Bu etkinlik yalnızca Plus oyuncu başvurularını kabul ediyor.');
      return;
    }
    if (preference == 'Normal Üye' && playerIsPlus) {
      _message('Etkinlik sahibi bu etkinlikte Normal Üye tercih etmiş.');
      return;
    }

    setState(() => busy = true);
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await transaction.get(_eventRef);
        final Map<String, dynamic> latest =
            snapshot.data() ?? <String, dynamic>{};

        final List<String> latestSelected = _stringList(
          latest['selectedPlayerIds'],
        );
        final List<String> latestApplicants = _stringList(
          latest['basvuranOyuncuIds'],
        );
        final int latestNeeded =
        ((latest['oyuncuSayisi'] as num?)?.toInt() ?? 1)
            .clamp(1, 4)
            .toInt();

        if (latestSelected.length >= latestNeeded) {
          throw StateError('Kontenjan doldu.');
        }
        if (latestSelected.contains(user.uid) ||
            latestApplicants.contains(user.uid)) {
          return;
        }

        transaction.update(_eventRef, <String, dynamic>{
          'basvuranOyuncuIds': FieldValue.arrayUnion(<String>[user.uid]),
          'basvuruSayisi': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final DocumentReference<Map<String, dynamic>> notificationRef =
        FirebaseFirestore.instance
            .collection('users')
            .doc(creator)
            .collection('notifications')
            .doc();

        transaction.set(notificationRef, <String, dynamic>{
          'notificationId': notificationRef.id,
          'type': 'eventApplication',
          'title': 'Yeni etkinlik başvurusu',
          'message':
          '${profile['profilAdi']?.toString().trim().isNotEmpty == true ? profile['profilAdi'] : 'Bir oyuncu'} etkinliğine başvurdu.',
          'eventId': widget.eventId,
          'actorUid': user.uid,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      _message('Başvurun etkinlik sahibine gönderildi.');
    } on StateError catch (error) {
      _message(error.message.toString());
    } catch (error) {
      _message('Başvuru gönderilemedi: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _withdrawApplication() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || busy) return;

    setState(() => busy = true);
    try {
      await _eventRef.update(<String, dynamic>{
        'basvuranOyuncuIds': FieldValue.arrayRemove(<String>[user.uid]),
        'basvuruSayisi': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message('Başvurun geri çekildi.');
    } catch (error) {
      _message('Başvuru geri çekilemedi: $error');
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
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await transaction.get(_eventRef);
        final Map<String, dynamic> latest =
            snapshot.data() ?? <String, dynamic>{};

        final List<String> selected = _stringList(latest['selectedPlayerIds']);
        final int needed = ((latest['oyuncuSayisi'] as num?)?.toInt() ?? 1)
            .clamp(1, 4)
            .toInt();

        if (accept && selected.length >= needed) {
          throw StateError('Oyuncu kontenjanı dolmuş.');
        }

        final Map<String, dynamic> update = <String, dynamic>{
          'basvuranOyuncuIds': FieldValue.arrayRemove(<String>[applicantUid]),
          'basvuruSayisi': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (accept) {
          update['selectedPlayerIds'] = FieldValue.arrayUnion(<String>[
            applicantUid,
          ]);
          update['katilanlar'] = FieldValue.arrayUnion(<String>[applicantUid]);
          update['chatMemberUids'] = FieldValue.arrayUnion(<String>[
            applicantUid,
          ]);

          if (selected.length + 1 >= needed) {
            update['durum'] = 'oyuncularSecildi';
          }
        }

        transaction.update(_eventRef, update);

        final DocumentReference<Map<String, dynamic>> notificationRef =
        FirebaseFirestore.instance
            .collection('users')
            .doc(applicantUid)
            .collection('notifications')
            .doc();

        transaction.set(notificationRef, <String, dynamic>{
          'notificationId': notificationRef.id,
          'type': accept
              ? 'eventApplicationAccepted'
              : 'eventApplicationRejected',
          'title': accept ? 'Başvurun kabul edildi' : 'Başvurun reddedildi',
          'message': accept
              ? 'Etkinlik başvurun organizatör tarafından kabul edildi.'
              : 'Etkinlik başvurun organizatör tarafından reddedildi.',
          'eventId': widget.eventId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      _message(accept ? 'Oyuncu kabul edildi.' : 'Başvuru reddedildi.');
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
      title: 'Etkinliği iptal et',
      hint: 'İptal nedenini yaz',
      confirmText: 'İptal et',
    );
    if (reason == null) return;

    final String paymentStatus =
        data['paymentStatus']?.toString() ?? 'notCreated';
    final bool paymentExists =
        paymentStatus != 'notCreated' && paymentStatus != 'cancelled';

    final bool confirmed = await _confirm(
      title: 'İptali onayla',
      message: paymentExists
          ? 'Ödeme yapılmışsa sözleşmedeki iptal ve iade kuralları uygulanır. Devam edilsin mi?'
          : 'Etkinlik iptal edilecek. Devam edilsin mi?',
      confirmText: 'Evet, iptal et',
    );
    if (!confirmed) return;

    setState(() => busy = true);
    try {
      await _eventRef.update(<String, dynamic>{
        'durum': paymentExists ? 'cancellationRequested' : 'iptal',
        'cancellationReason': reason,
        'cancellationRequestedBy': user.uid,
        'cancellationRequestedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _message(
        paymentExists
            ? 'İptal ve iade talebi incelemeye gönderildi.'
            : 'Etkinlik iptal edildi.',
      );
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
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                final String text = controller.text.trim();
                if (text.length < 5) {
                  _message('Lütfen daha açıklayıcı bir neden yaz.');
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
              child: const Text('Vazgeç'),
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
    final User? user = FirebaseAuth.instance.currentUser;
    final String creator = data['olusturanUid']?.toString() ?? '';
    final List<String> selectedPlayers = _stringList(data['selectedPlayerIds']);
    final bool canViewPrivateLocation =
        user != null &&
            (user.uid == creator || selectedPlayers.contains(user.uid));

    if (!canViewPrivateLocation) {
      _message(
        'Açık adres ve yol tarifi yalnızca etkinlik sahibi ile onaylanan oyunculara gösterilir.',
      );
      return;
    }

    final double latitude = (data['latitude'] as num?)?.toDouble() ?? 0;
    final double longitude = (data['longitude'] as num?)?.toDouble() ?? 0;
    final String address = <String>[
      data['adres']?.toString().trim() ?? '',
      data['semt']?.toString().trim() ?? '',
      data['ilce']?.toString().trim() ?? '',
      data['sehir']?.toString().trim() ?? '',
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
      _message('Yol tarifi için konum bilgisi bulunamadı.');
      return;
    }

    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) _message('Navigasyon uygulaması açılamadı.');
  }

  void _openChat(String game) {
    Navigator.push(
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
                ? const Center(child: Text('Henüz başvuru yok.'))
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
        final String city = data['sehir']?.toString().trim() ?? '';
        final String district = data['ilce']?.toString().trim() ?? '';
        final String neighborhood = _shortArea(data);
        final String fullAddress = data['adres']?.toString().trim() ?? '';
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
        final bool applied = user != null && applicants.contains(user.uid);
        final bool canViewPrivateLocation = isCreator || selected;
        final bool canChat = isCreator || selected;
        final int needed = ((data['oyuncuSayisi'] as num?)?.toInt() ?? 1)
            .clamp(1, 4)
            .toInt();
        final bool full = selectedPlayers.length >= needed;
        final String status = data['durum']?.toString() ?? 'aktif';
        final bool closed = <String>{
          'iptal',
          'cancelled',
          'completed',
          'tamamlandi',
        }.contains(status);

        final String publicLocationText = <String>[
          city,
          district,
        ].where((String value) => value.isNotEmpty).join(' - ');

        final String privateLocationText = <String>[
          fullAddress,
          if (fullAddress.isEmpty) neighborhood,
          district,
          city,
        ].where((String value) => value.isNotEmpty).join(' - ');

        final String locationText = canViewPrivateLocation
            ? privateLocationText
            : publicLocationText;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Etkinlik Detayı'),
            centerTitle: true,
            actions: <Widget>[
              if (!isCreator)
                IconButton(
                  tooltip: 'Etkinliği Şikâyet Et',
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
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
            children: <Widget>[
              Container(
                height: 180,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      _color(game),
                      _color(game).withValues(alpha: 0.55),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Center(
                  child: Text(
                    _emoji(game),
                    style: const TextStyle(fontSize: 76),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _clean(game),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  _StatusChip(status: status),
                ],
              ),
              const SizedBox(height: 14),
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
                '${selectedPlayers.length}/$needed oyuncu seçildi',
              ),
              _info(
                Icons.workspace_premium_outlined,
                'Oyuncu tercihi: ${data['uyeTercihi'] ?? 'Herkes'}',
              ),
              const SizedBox(height: 8),
              _NoticeCard(
                icon: Icons.cloud_outlined,
                title: 'Hava durumunu kontrol et',
                text:
                'Ödeme yapmadan ve yola çıkmadan önce etkinlik saatindeki hava koşullarını kontrol et.',
              ),
              const SizedBox(height: 10),
              _NoticeCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Güvenli ödeme',
                text:
                'Ödeme emanet hesapta tutulur. Oyuncu kazancı müşteriye gösterilmez ve etkinlik sonucuna göre işlenir.',
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: canViewPrivateLocation
                      ? () => _openNavigation(data)
                      : null,
                  icon: Icon(
                    canViewPrivateLocation
                        ? Icons.navigation_rounded
                        : Icons.lock_outline_rounded,
                  ),
                  label: Text(
                    canViewPrivateLocation
                        ? 'Yol Tarifi Al'
                        : applied
                        ? 'Adres, başvurun onaylanınca açılır'
                        : 'Adres yalnızca onaylanan oyunculara açılır',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _sectionTitle('Etkinlik Sahibi'),
              const SizedBox(height: 8),
              _OrganizerCard(
                uid: creator,
                fallbackName: data['olusturanProfilAdi']?.toString() ?? '',
                fallbackPhotoUrl: resolveUserImageUrl(data),
                fallbackVerified: data['olusturanDogrulanmis'] == true,
                fallbackPlus: data['olusturanPlus'] == true,
              ),
              const SizedBox(height: 20),
              if (selectedPlayers.isNotEmpty) ...[
                const SizedBox(height: 20),
                _sectionTitle('Seçilen Oyuncular'),
                ...selectedPlayers.map(
                      (uid) => _ApplicantTile(
                    uid: uid,
                    busy: true,
                    onAccept: () {},
                    onReject: () {},
                  ),
                ),
              ],
              _sectionTitle('Açıklama'),
              Text(
                description.isEmpty
                    ? 'Etkinlik açıklaması eklenmemiş.'
                    : description,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
              if (isCreator) ...<Widget>[
                const SizedBox(height: 22),
                _sectionTitle('Etkinlik Sahibi İşlemleri'),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.group_add_outlined),
                  title: const Text('Oyuncu başvuruları'),
                  subtitle: Text('${applicants.length} bekleyen başvuru'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: busy ? null : () => _showApplicants(data),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cancel_outlined),
                  title: const Text('Etkinliği iptal et'),
                  subtitle: const Text(
                    'Ödeme varsa iptal ve iade incelemesi başlatılır.',
                  ),
                  onTap: busy || closed ? null : () => _cancelEvent(data),
                ),
              ],
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canChat ? () => _openChat(game) : null,
                    icon: const Icon(Icons.forum_outlined),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 15),
                      child: Text('Sohbet'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                    isCreator || selected || full || closed || busy
                        ? null
                        : applied
                        ? _withdrawApplication
                        : () => _apply(data),
                    icon: busy
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : Icon(
                      isCreator
                          ? Icons.manage_accounts_outlined
                          : selected
                          ? Icons.check_circle
                          : applied
                          ? Icons.undo
                          : full
                          ? Icons.group_off_outlined
                          : Icons.person_add_alt_1,
                    ),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: Text(
                        isCreator
                            ? 'Sen oluşturdun'
                            : selected
                            ? 'Seçildin'
                            : applied
                            ? 'Başvuruyu çek'
                            : full
                            ? 'Kontenjan dolu'
                            : 'Başvur',
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

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
      padding: const EdgeInsets.only(bottom: 10),
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

  String _shortArea(Map<String, dynamic> data) {
    final String semt = data['semt']?.toString().trim() ?? '';
    if (semt.isNotEmpty) return semt;

    final String address = data['adres']?.toString().trim() ?? '';
    if (address.isEmpty) return '';

    return address
        .split(RegExp(r'[,;\n]'))
        .first
        .trim()
        .replaceAll(RegExp(r'\bMahallesi\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bMah\.\b', caseSensitive: false), '')
        .trim();
  }

  String _emoji(String value) {
    return GameVisuals.emoji(value);
  }

  String _clean(String value) {
    return GameVisuals.name(value);
  }

  Color _color(String value) {
    return GameVisuals.color(value);
  }
}

class _ApplicantTile extends StatelessWidget {
  final String uid;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _ApplicantTile({
    required this.uid,
    required this.busy,
    required this.onAccept,
    required this.onReject,
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
                builder: (_) => PublicProfileScreen(
                  userId: uid,
                ),
              ),
            );
          },
          trailing: Wrap(
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
          ),
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
    final String safeName =
    name.trim().isEmpty ? 'Kullanıcı' : name.trim();

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: UserAvatar(
          displayName: safeName,
          imageUrl: photoUrl,
          radius: 24,
          backgroundColor:
          Theme.of(context).colorScheme.secondaryContainer,
          foregroundColor:
          Theme.of(context).colorScheme.onSecondaryContainer,
        ),
        title: Row(
          children: <Widget>[
            Flexible(
              child: Text(
                safeName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (verified) ...<Widget>[
              const SizedBox(width: 5),
              const Icon(
                Icons.verified,
                size: 18,
                color: Colors.blue,
              ),
            ],
            if (plus) ...<Widget>[
              const SizedBox(width: 5),
              const Icon(
                Icons.diamond,
                size: 17,
                color: Color(0xffFF9800),
              ),
            ],
          ],
        ),
        subtitle: const Text('Etkinlik Sahibi'),
        onTap: uid.trim().isEmpty
            ? null
            : () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PublicProfileScreen(
                userId: uid,
              ),
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
        label = 'Oyuncular seçildi';
        break;
      case 'cancellationRequested':
        label = 'İptal inceleniyor';
        break;
      case 'iptal':
      case 'cancelled':
        label = 'İptal edildi';
        break;
      case 'completed':
      case 'tamamlandi':
        label = 'Tamamlandı';
        break;
      default:
        label = 'Aktif';
        break;
    }

    return Chip(label: Text(label));
  }
}
