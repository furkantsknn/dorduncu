import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/event_service.dart';
import 'public_profile_screen.dart';

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

class _ApplicantManagementScreenState
    extends State<ApplicantManagementScreen> {
  final Set<String> _busyApplicantIds = <String>{};

  DocumentReference<Map<String, dynamic>> get _eventRef =>
      FirebaseFirestore.instance.collection('events').doc(widget.eventId);

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

  List<String> _applicantIds(Map<String, dynamic> data) {
    final Set<String> ids = <String>{};

    ids.addAll(_stringList(data['basvuranOyuncuIds']));
    ids.addAll(_stringList(data['applicantIds']));
    ids.addAll(_stringList(data['applicationUserIds']));

    return ids.toList(growable: false);
  }

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
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<bool> _confirm({
    required String name,
    required bool accept,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            accept ? 'Başvuruyu kabul et' : 'Başvuruyu reddet',
          ),
          content: Text(
            accept
                ? '$name etkinliğe katılımcı olarak eklenecek.'
                : '$name tarafından yapılan başvuru reddedilecek.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              style: accept
                  ? null
                  : FilledButton.styleFrom(
                backgroundColor:
                Theme.of(dialogContext).colorScheme.error,
                foregroundColor:
                Theme.of(dialogContext).colorScheme.onError,
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

    final bool confirmed = await _confirm(
      name: name,
      accept: accept,
    );

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
      _showMessage(
        error.message ??
            (accept
                ? 'Başvuru kabul edilemedi.'
                : 'Başvuru reddedilemedi.'),
      );
    } on StateError catch (error) {
      _showMessage(error.message.toString());
    } catch (_) {
      _showMessage(
        accept
            ? 'Başvuru kabul edilemedi.'
            : 'Başvuru reddedilemedi.',
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
      builder: (
          BuildContext context,
          AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
        final Map<String, dynamic> data =
            snapshot.data?.data() ?? widget.initialData;
        final List<String> applicants = _applicantIds(data);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Başvuru Yönetimi'),
            centerTitle: true,
          ),
          body: snapshot.connectionState == ConnectionState.waiting &&
              snapshot.data == null
              ? const Center(child: CircularProgressIndicator())
              : applicants.isEmpty
              ? _EmptyState(
            eventTitle: _eventTitle(data),
          )
              : ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: <Widget>[
              _HeaderCard(
                eventTitle: _eventTitle(data),
                count: applicants.length,
              ),
              const SizedBox(height: 14),
              ...applicants.map(
                    (String uid) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ApplicantCard(
                    uid: uid,
                    busy: _busyApplicantIds.contains(uid),
                    onAccept: (String name) =>
                        _reviewApplicant(
                          uid: uid,
                          name: name,
                          accept: true,
                        ),
                    onReject: (String name) =>
                        _reviewApplicant(
                          uid: uid,
                          name: name,
                          accept: false,
                        ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String eventTitle;
  final int count;

  const _HeaderCard({
    required this.eventTitle,
    required this.count,
  });

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
  final bool busy;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onReject;

  const _ApplicantCard({
    required this.uid,
    required this.busy,
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
    final dynamic raw = profile['rating'] ??
        profile['puanOrtalamasi'] ??
        profile['averageRating'];

    if (raw is num) {
      return raw.toDouble().clamp(0, 5).toDouble();
    }

    return (double.tryParse(raw?.toString() ?? '') ?? 0)
        .clamp(0, 5)
        .toDouble();
  }

  int _ratingCount(Map<String, dynamic> profile) {
    final dynamic raw = profile['ratingCount'] ??
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
      builder: (
          BuildContext context,
          AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
        final Map<String, dynamic> profile =
            snapshot.data?.data() ?? <String, dynamic>{};

        final String name = _firstText(
          profile,
          <String>['profilAdi', 'displayName', 'name'],
          fallback: 'Oyuncu',
        );

        final String city = _firstText(
          profile,
          <String>['sehir', 'city'],
          fallback: 'Şehir belirtilmedi',
        );

        final String district = _firstText(
          profile,
          <String>['ilce', 'district'],
        );

        final String photo = _firstText(
          profile,
          <String>[
            'profilFotografi',
            'profilFotoUrl',
            'photoUrl',
          ],
        );

        final bool verified = profile['verified'] == true ||
            profile['verificationStatus'] == 'approved';
        final bool plus = profile['plus'] == true;
        final double rating = _rating(profile);
        final int ratingCount = _ratingCount(profile);
        final String location =
        district.isEmpty ? city : '$district • $city';
        final String initial =
        name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();

        return InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PublicProfileScreen(
                    userId: uid,
                  ),
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
                      backgroundImage:
                      photo.isNotEmpty ? NetworkImage(photo) : null,
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
                                const Icon(
                                  Icons.diamond,
                                  size: 17,
                                  color: Color(0xffFF9800),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall,
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
                                  style:
                                  Theme.of(context).textTheme.bodySmall,
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

  const _EmptyState({
    required this.eventTitle,
  });

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
              'Bekleyen başvuru yok',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
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
