import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/event_model.dart';
import '../services/event_service.dart';
import '../utils/game_experience.dart';
import '../widgets/plus_emblem.dart';
import 'public_profile_screen.dart';

String _applicantText(
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

class ApplicantManagementScreen extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> initialData;

  const ApplicantManagementScreen({
    super.key,
    required this.eventId,
    required this.initialData,
  });

  @override
  State<ApplicantManagementScreen> createState() =>
      _ApplicantManagementScreenState();
}

class _ApplicantManagementScreenState extends State<ApplicantManagementScreen> {
  final Set<String> _busyApplicantIds = <String>{};

  DocumentReference<Map<String, dynamic>> get _eventRef =>
      FirebaseFirestore.instance.collection('events').doc(widget.eventId);

  String _eventTitle(Map<String, dynamic> data) {
    for (final String key in <String>[
      'gameName',
      'oyun',
      'eventTitle',
      'title',
    ]) {
      final String value = data[key]?.toString().trim() ?? '';

      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }

    return 'Etkinlik';
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

  Future<bool> _confirm({required String name, required bool accept}) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Text(
                accept
                    ? _applicantText(
                        context,
                        tr: 'Başvuruyu kabul et',
                        en: 'Accept application',
                        de: 'Bewerbung annehmen',
                      )
                    : _applicantText(
                        context,
                        tr: 'Başvuruyu reddet',
                        en: 'Reject application',
                        de: 'Bewerbung ablehnen',
                      ),
              ),
              content: Text(
                accept
                    ? '$name etkinliğe katılımcı olarak eklenecek.'
                    : '$name tarafından yapılan başvuru reddedilecek.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(
                    _applicantText(
                      context,
                      tr: 'Vazgeç',
                      en: 'Cancel',
                      de: 'Abbrechen',
                    ),
                  ),
                ),
                FilledButton(
                  style: accept
                      ? null
                      : FilledButton.styleFrom(
                          backgroundColor: Theme.of(
                            dialogContext,
                          ).colorScheme.error,
                          foregroundColor: Theme.of(
                            dialogContext,
                          ).colorScheme.onError,
                        ),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(accept ? 'Kabul Et' : 'Reddet'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _reviewApplicant({
    required String uid,
    required String name,
    required bool accept,
  }) async {
    if (_busyApplicantIds.contains(uid)) {
      return;
    }

    final bool confirmed = await _confirm(name: name, accept: accept);

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _busyApplicantIds.add(uid);
    });

    try {
      if (accept) {
        await EventService().acceptApplication(
          eventId: widget.eventId,
          playerId: uid,
        );
      } else {
        await EventService().rejectApplication(
          eventId: widget.eventId,
          playerId: uid,
        );
      }

      _showMessage(
        accept
            ? '$name etkinliğe kabul edildi.'
            : '$name başvurusu reddedildi.',
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      _showMessage(
        error.message ??
            (accept
                ? _applicantText(
                    context,
                    tr: 'Başvuru kabul edilemedi.',
                    en: 'Application could not be accepted.',
                    de: 'Bewerbung konnte nicht angenommen werden.',
                  )
                : _applicantText(
                    context,
                    tr: 'Başvuru reddedilemedi.',
                    en: 'Application could not be rejected.',
                    de: 'Bewerbung konnte nicht abgelehnt werden.',
                  )),
      );
    } on StateError catch (error) {
      _showMessage(error.message.toString());
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        accept
            ? _applicantText(
                context,
                tr: 'Başvuru kabul edilemedi.',
                en: 'Application could not be accepted.',
                de: 'Bewerbung konnte nicht angenommen werden.',
              )
            : _applicantText(
                context,
                tr: 'Başvuru reddedilemedi.',
                en: 'Application could not be rejected.',
                de: 'Bewerbung konnte nicht abgelehnt werden.',
              ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyApplicantIds.remove(uid);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _eventRef.snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> eventSnapshot,
          ) {
            final Map<String, dynamic> data =
                eventSnapshot.data?.data() ?? widget.initialData;

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  _applicantText(
                    context,
                    tr: 'Başvuru Yönetimi',
                    en: 'Application Management',
                    de: 'Bewerbungsverwaltung',
                  ),
                ),
                centerTitle: true,
              ),
              body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _eventRef
                    .collection('applications')
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                      applicationSnapshot,
                    ) {
                      if (applicationSnapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              _applicantText(
                                context,
                                tr: 'Başvurular yüklenemedi. Lütfen tekrar dene.',
                                en: 'Applications could not be loaded. Please try again.',
                                de: 'Bewerbungen konnten nicht geladen werden. Bitte versuche es erneut.',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      if (applicationSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          !applicationSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final bool inactive = EventModel.mapIsInactive(data);
                      final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                      applicants =
                          applicationSnapshot.data?.docs
                              .where(
                                (document) => document.id.trim().isNotEmpty,
                              )
                              .toList(growable: false) ??
                          <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                      if (applicants.isEmpty) {
                        return _EmptyState(eventTitle: _eventTitle(data));
                      }

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                        children: <Widget>[
                          _HeaderCard(
                            eventTitle: _eventTitle(data),
                            count: applicants.length,
                          ),
                          if (inactive) ...<Widget>[
                            const SizedBox(height: 12),
                            Text(
                              _applicantText(
                                context,
                                tr: 'Bu etkinliğin süresi doldu. Başvuru kabul veya ret edilemez.',
                                en: 'This event has ended. Applications can no longer be reviewed.',
                                de: 'Diese Veranstaltung ist beendet. Bewerbungen können nicht mehr geprüft werden.',
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          ...applicants.map(
                            (document) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ApplicantCard(
                                uid: document.id,
                                application: document.data(),
                                busy: _busyApplicantIds.contains(document.id),
                                actionsEnabled: !inactive,
                                onAccept: (String name) => _reviewApplicant(
                                  uid: document.id,
                                  name: name,
                                  accept: true,
                                ),
                                onReject: (String name) => _reviewApplicant(
                                  uid: document.id,
                                  name: name,
                                  accept: false,
                                ),
                              ),
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
}

class _HeaderCard extends StatelessWidget {
  final String eventTitle;
  final int count;

  const _HeaderCard({required this.eventTitle, required this.count});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.group_add_outlined,
              color: colors.onPrimary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  eventTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count bekleyen başvuru',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicantCard extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> application;
  final bool busy;
  final bool actionsEnabled;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onReject;

  const _ApplicantCard({
    required this.uid,
    required this.application,
    required this.busy,
    required this.actionsEnabled,
    required this.onAccept,
    required this.onReject,
  });

  String _firstText(
    Map<String, dynamic> profile,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final String key in keys) {
      final String value = profile[key]?.toString().trim() ?? '';

      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }

    return fallback;
  }

  double _rating(Map<String, dynamic> profile) {
    final dynamic raw =
        profile['rating'] ??
        profile['puanOrtalamasi'] ??
        profile['averageRating'];

    if (raw is num) {
      return raw.toDouble().clamp(0, 5).toDouble();
    }

    return (double.tryParse(raw?.toString() ?? '') ?? 0).clamp(0, 5).toDouble();
  }

  int _ratingCount(Map<String, dynamic> profile) {
    final dynamic raw =
        profile['ratingCount'] ??
        profile['degerlendirmeSayisi'] ??
        profile['reviewCount'];

    if (raw is num) {
      return raw.toInt().clamp(0, 1000000).toInt();
    }

    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

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

            final String name = _firstText(profile, <String>[
              'profilAdi',
              'displayName',
              'name',
            ], fallback: 'Oyuncu');

            final String city = _firstText(
              profile,
              <String>['sehir', 'city'],
              fallback: _applicantText(
                context,
                tr: 'Şehir belirtilmedi',
                en: 'City not specified',
                de: 'Stadt nicht angegeben',
              ),
            );

            final String district = _firstText(profile, <String>[
              'ilce',
              'district',
            ]);

            final String photo = _firstText(profile, <String>[
              'profilFotografi',
              'profilFotoUrl',
              'photoUrl',
            ]);

            final bool verified =
                profile['verified'] == true ||
                profile['verificationStatus'] == 'approved';
            final bool plus = profile['plus'] == true;
            final double rating = _rating(profile);
            final int ratingCount = _ratingCount(profile);
            final String location = district.isEmpty
                ? city
                : '$district • $city';
            final String initial = name.isEmpty
                ? '?'
                : name.substring(0, 1).toUpperCase();

            return InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PublicProfileScreen(userId: uid),
                  ),
                );
              },
              child: Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          CircleAvatar(
                            radius: 29,
                            backgroundImage: photo.isNotEmpty
                                ? NetworkImage(photo)
                                : null,
                            child: photo.isEmpty
                                ? Text(
                                    initial,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 20,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Flexible(
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
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
                                      const PlusMark(size: 16),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: <Widget>[
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        location,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: <Widget>[
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 18,
                                      color: Color(0xffFFB300),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      rating > 0
                                          ? rating.toStringAsFixed(1)
                                          : 'Yeni',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    if (ratingCount > 0) ...<Widget>[
                                      const SizedBox(width: 5),
                                      Text(
                                        '($ratingCount değerlendirme)',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          const Icon(Icons.sports_esports_outlined, size: 18),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              selfDeclaredExperienceText(
                                context,
                                application['applicantGameExperienceLevel'],
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (!actionsEnabled)
                        Text(
                          _applicantText(
                            context,
                            tr: 'Bu etkinlik için karar verilemez.',
                            en: 'This event can no longer be reviewed.',
                            de: 'Diese Veranstaltung kann nicht mehr geprüft werden.',
                          ),
                        )
                      else
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: busy ? null : () => onReject(name),
                                icon: const Icon(Icons.close_rounded),
                                label: const Text('Reddet'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: busy ? null : () => onAccept(name),
                                icon: busy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.check_rounded),
                                label: const Text('Kabul Et'),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String eventTitle;

  const _EmptyState({required this.eventTitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.mark_email_read_outlined,
              size: 74,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            Text(
              _applicantText(
                context,
                tr: 'Bekleyen başvuru yok',
                en: 'No pending applications',
                de: 'Keine ausstehenden Bewerbungen',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              '$eventTitle için değerlendirilecek yeni bir oyuncu başvurusu bulunmuyor.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
