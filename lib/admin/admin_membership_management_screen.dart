import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../utils/verification_admin_labels.dart';
import 'admin_permission_gate.dart';

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

      _reasonController.clear();

      _showMessage(
        enabled ? 'Plus üyelik verildi.' : 'Plus üyelik kaldırıldı.',
      );
    } on FirebaseFunctionsException catch (error) {
      _showMessage(error.message ?? 'İşlem tamamlanamadı.');
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

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            approved ? 'Oyuncu Rozeti Ver' : 'Oyuncu Rozetini Kaldır',
          ),
          content: Text(
            approved
                ? 'Kullanıcıya oyuncu rozeti verilecek.'
                : 'Kullanıcının oyuncu rozeti kaldırılacak.',
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
        'action': 'playerBadge',
        'enabled': approved,
        'reason': reason,
      });

      _reasonController.clear();

      _showMessage(
        approved ? 'Oyuncu rozeti verildi.' : 'Oyuncu rozeti kaldırıldı.',
      );
    } on FirebaseFunctionsException catch (error) {
      _showMessage(error.message ?? 'İşlem tamamlanamadı.');
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
                body: const Center(
                  child: Text('Üyelik bilgileri yüklenemedi.'),
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

            final bool isPlus = data['plus'] == true;

            final bool isPlayer =
                data['oyuncuRozeti'] == true || data['verified'] == true;
            final VerificationAdminLabels application =
                presentVerificationAdmin(
                  status: data['verificationStatus']?.toString() ?? '',
                  automaticCheckStatus: '',
                  reasonCode: data['verificationReasonCode']?.toString() ?? '',
                  decisionSource:
                      data['verificationDecisionSource']?.toString() ?? '',
                );

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
                          const SizedBox(height: 8),
                          Text(
                            _adminMembershipText(
                              context,
                              tr: 'Bu ekran eski admin bayrağını değiştirir. Google Play hakkı, süre ve Play ürün kimliği buradan açılmaz.',
                              en: 'This screen changes the legacy admin flag. It does not grant a Google Play entitlement, expiry, or Play product id.',
                              de: 'Dieser Bildschirm ändert nur die alte Admin-Markierung. Er vergibt kein Google-Play-Recht, kein Ablaufdatum und keine Play-Produkt-ID.',
                            ),
                          ),
                          const SizedBox(height: 16),
                          _StatusRow(
                            title: 'Eski Plus bayrağı',
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
                            disabledText: 'Oyuncu rozeti kapalı',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Kimlik başvurusu: ${application.applicationStatus}',
                            style: const TextStyle(height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Rozet ve kimlik başvurusu ayrı kayıtlardır. Kaldırma yalnızca rozeti kapatır.',
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
                              onPressed: _saving || isPlus
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
                              onPressed: _saving || !isPlus
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
                          AdminRoleGate(
                            allowedRoles: const <String>{'super_admin'},
                            child: Column(
                              children: <Widget>[
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
                                      padding: EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
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
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                    label: const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      child: Text('Oyuncu Rozetini Kaldır'),
                                    ),
                                  ),
                                ),
                              ],
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
