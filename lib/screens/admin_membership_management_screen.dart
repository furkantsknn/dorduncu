import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../services/plus_entitlement.dart';

String _adminMembershipText(
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

class AdminMembershipManagementScreen extends StatefulWidget {
  const AdminMembershipManagementScreen({super.key, required this.userId});

  final String userId;

  @override
  State<AdminMembershipManagementScreen> createState() =>
      _AdminMembershipManagementScreenState();
}

class _AdminMembershipManagementScreenState
    extends State<AdminMembershipManagementScreen> {
  final TextEditingController _reasonController = TextEditingController();

  bool _saving = false;

  DocumentReference<Map<String, dynamic>> get _userReference {
    return FirebaseFirestore.instance.collection('users').doc(widget.userId);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _updatePlus({required bool enabled}) async {
    if (_saving) {
      return;
    }

    final String reason = _reasonController.text.trim();

    if (reason.length < 3) {
      _showMessage('İşlem açıklamasını yaz.');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            enabled
                ? _adminMembershipText(
                    context,
                    tr: 'Plus Üyelik Ver',
                    en: 'Grant Plus Membership',
                    de: 'Plus-Mitgliedschaft gewähren',
                  )
                : _adminMembershipText(
                    context,
                    tr: 'Plus Üyeliği Kaldır',
                    en: 'Remove Plus Membership',
                    de: 'Plus-Mitgliedschaft entfernen',
                  ),
          ),
          content: Text(
            enabled
                ? 'Kullanıcıya Plus üyelik verilecek.'
                : 'Kullanıcının Plus üyeliği kaldırılacak.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(
                _adminMembershipText(
                  context,
                  tr: 'Vazgeç',
                  en: 'Cancel',
                  de: 'Abbrechen',
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Onayla'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('adminUpdateMembership');

      await callable.call(<String, dynamic>{
        'userId': widget.userId,
        'action': 'plus',
        'enabled': enabled,
        'reason': reason,
      });

      if (!mounted) {
        return;
      }

      _reasonController.clear();

      _showMessage(
        enabled
            ? _adminMembershipText(
                context,
                tr: 'Plus üyelik verildi.',
                en: 'Plus membership granted.',
                de: 'Plus-Mitgliedschaft gewährt.',
              )
            : _adminMembershipText(
                context,
                tr: 'Plus üyelik kaldırıldı.',
                en: 'Plus membership removed.',
                de: 'Plus-Mitgliedschaft entfernt.',
              ),
      );
    } catch (error) {
      _showMessage('İşlem tamamlanamadı: $error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _updatePlayerBadge({required bool approved}) async {
    if (_saving) {
      return;
    }

    final String reason = _reasonController.text.trim();

    if (reason.length < 3) {
      _showMessage('İşlem açıklamasını yaz.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('adminUpdateMembership');

      await callable.call(<String, dynamic>{
        'userId': widget.userId,
        'action': 'playerBadge',
        'enabled': approved,
        'reason': reason,
      });

      if (!mounted) return;
      _reasonController.clear();

      _showMessage(
        approved
            ? 'Oyuncu rozeti verildi.'
            : _adminMembershipText(
                context,
                tr: 'Oyuncu rozeti kaldırıldı.',
                en: 'Player badge removed.',
                de: 'Spielerabzeichen entfernt.',
              ),
      );
    } catch (error) {
      _showMessage('İşlem tamamlanamadı: $error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userReference.snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (snapshot.hasError) {
              return Scaffold(
                appBar: AppBar(
                  title: Text(
                    _adminMembershipText(
                      context,
                      tr: 'Üyelik Yönetimi',
                      en: 'Membership Management',
                      de: 'Mitgliedschaftsverwaltung',
                    ),
                  ),
                ),
                body: Center(
                  child: Text(
                    _adminMembershipText(
                      context,
                      tr: 'Üyelik bilgileri yüklenemedi.',
                      en: 'Membership information could not be loaded.',
                      de: 'Mitgliedschaftsinformationen konnten nicht geladen werden.',
                    ),
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return Scaffold(
                appBar: AppBar(
                  title: Text(
                    _adminMembershipText(
                      context,
                      tr: 'Üyelik Yönetimi',
                      en: 'Membership Management',
                      de: 'Mitgliedschaftsverwaltung',
                    ),
                  ),
                ),
                body: const Center(child: CircularProgressIndicator()),
              );
            }

            final Map<String, dynamic> data =
                snapshot.data?.data() ?? <String, dynamic>{};

            final bool isPlus = PlusEntitlement.isActive(data);
            final bool adminGranted = data['plusAdminGranted'] == true;

            final bool isPlayer =
                data['oyuncuRozeti'] == true || data['verified'] == true;

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  _adminMembershipText(
                    context,
                    tr: 'Üyelik Yönetimi',
                    en: 'Membership Management',
                    de: 'Mitgliedschaftsverwaltung',
                  ),
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: <Widget>[
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _adminMembershipText(
                              context,
                              tr: 'Mevcut üyelik',
                              en: 'Current membership',
                              de: 'Aktuelle Mitgliedschaft',
                            ),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _StatusRow(
                            title: _adminMembershipText(
                              context,
                              tr: 'Plus üyelik',
                              en: 'Plus membership',
                              de: 'Plus-Mitgliedschaft',
                            ),
                            enabled: isPlus,
                            enabledText: _adminMembershipText(
                              context,
                              tr: 'Plus üye',
                              en: 'Plus member',
                              de: 'Plus-Mitglied',
                            ),
                            disabledText: _adminMembershipText(
                              context,
                              tr: 'Normal üye',
                              en: 'Standard member',
                              de: 'Standardmitglied',
                            ),
                          ),
                          const Divider(height: 26),
                          _StatusRow(
                            title: 'Oyuncu rozeti',
                            enabled: isPlayer,
                            enabledText: 'Oyuncu rozeti aktif',
                            disabledText: 'Oyuncu doğrulaması yok',
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Admin isterse oyuncu rozetini verebilir veya kaldırabilir. Yapılan tüm işlemler admin işlem geçmişine kaydedilir.',
                            style: TextStyle(height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _adminMembershipText(
                              context,
                              tr: 'Admin işlemi',
                              en: 'Admin action',
                              de: 'Admin-Aktion',
                            ),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _reasonController,
                            enabled: !_saving,
                            minLines: 3,
                            maxLines: 5,
                            decoration: InputDecoration(
                              labelText: _adminMembershipText(
                                context,
                                tr: 'İşlem açıklaması',
                                en: 'Action description',
                                de: 'Aktionsbeschreibung',
                              ),
                              hintText:
                                  'Örnek: Kampanya, satın alma düzeltmesi veya iade',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _saving || adminGranted
                                  ? null
                                  : () {
                                      _updatePlus(enabled: true);
                                    },
                              icon: const Icon(
                                Icons.workspace_premium_outlined,
                              ),
                              label: Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Text(
                                  _adminMembershipText(
                                    context,
                                    tr: 'Plus Üyelik Ver',
                                    en: 'Grant Plus Membership',
                                    de: 'Plus-Mitgliedschaft gewähren',
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _saving || !adminGranted
                                  ? null
                                  : () {
                                      _updatePlus(enabled: false);
                                    },
                              icon: const Icon(Icons.remove_circle_outline),
                              label: Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Text(
                                  _adminMembershipText(
                                    context,
                                    tr: 'Plus Üyeliği Kaldır',
                                    en: 'Remove Plus Membership',
                                    de: 'Plus-Mitgliedschaft entfernen',
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _saving || isPlayer
                                  ? null
                                  : () {
                                      _updatePlayerBadge(approved: true);
                                    },
                              icon: const Icon(Icons.verified_outlined),
                              label: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Text('Oyuncu Rozeti Ver'),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _saving || !isPlayer
                                  ? null
                                  : () {
                                      _updatePlayerBadge(approved: false);
                                    },
                              icon: const Icon(Icons.remove_circle_outline),
                              label: Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Text(
                                  _adminMembershipText(
                                    context,
                                    tr: 'Oyuncu Rozetini Kaldır',
                                    en: 'Remove Player Badge',
                                    de: 'Spielerabzeichen entfernen',
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_saving) ...<Widget>[
                            const SizedBox(height: 16),
                            const Center(child: CircularProgressIndicator()),
                          ],
                        ],
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

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.title,
    required this.enabled,
    required this.enabledText,
    required this.disabledText,
  });

  final String title;
  final bool enabled;
  final String enabledText;
  final String disabledText;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Icon(
          enabled ? Icons.check_circle_rounded : Icons.remove_circle_outline,
          size: 20,
          color: enabled ? Colors.green : null,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            enabled ? enabledText : disabledText,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
