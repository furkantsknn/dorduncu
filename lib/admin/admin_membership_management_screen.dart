import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminMembershipManagementScreen extends StatefulWidget {
  const AdminMembershipManagementScreen({
    super.key,
    required this.userId,
  });

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
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _updatePlus({
    required bool enabled,
  }) async {
    if (_saving) {
      return;
    }

    final String reason = _reasonController.text.trim();

    if (reason.length < 3) {
      _showMessage('İşlem açıklamasını yaz.');
      return;
    }

    final String adminId =
        FirebaseAuth.instance.currentUser?.uid ?? '';

    if (adminId.isEmpty) {
      _showMessage('Admin oturumu bulunamadı.');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            enabled
                ? 'Plus Üyelik Ver'
                : 'Plus Üyeliği Kaldır',
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
              child: const Text('Vazgeç'),
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
      final FirebaseFirestore firestore =
          FirebaseFirestore.instance;

      final DocumentReference<Map<String, dynamic>> logReference =
      _userReference.collection('admin_actions').doc();

      final WriteBatch batch = firestore.batch();

      batch.set(
        _userReference,
        <String, dynamic>{
          'plus': enabled,
          'plusUpdatedAt': FieldValue.serverTimestamp(),
          'plusUpdatedBy': adminId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      batch.set(logReference, <String, dynamic>{
        'action': enabled
            ? 'plus_membership_granted'
            : 'plus_membership_removed',
        'reason': reason,
        'adminId': adminId,
        'performedByUid': adminId,
        'targetUserId': widget.userId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) {
        return;
      }

      _reasonController.clear();

      _showMessage(
        enabled
            ? 'Plus üyelik verildi.'
            : 'Plus üyelik kaldırıldı.',
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
  Future<void> _updatePlayerBadge({
    required bool approved,
  }) async {
    if (_saving) {
      return;
    }

    final String reason =
    _reasonController.text.trim();

    if (reason.length < 3) {
      _showMessage('İşlem açıklamasını yaz.');
      return;
    }

    final String adminId =
        FirebaseAuth.instance.currentUser?.uid ?? '';

    if (adminId.isEmpty) {
      _showMessage('Admin oturumu bulunamadı.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final FirebaseFirestore firestore =
          FirebaseFirestore.instance;

      final DocumentReference<Map<String, dynamic>>
      logReference =
      _userReference.collection('admin_actions').doc();

      final WriteBatch batch = firestore.batch();

      batch.set(
        _userReference,
        <String, dynamic>{
          'verified': approved,
          'oyuncuRozeti': approved,
          'verificationStatus':
          approved ? 'approved' : 'rejected',
          'verifiedAt': FieldValue.serverTimestamp(),
          'verifiedBy': adminId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      batch.set(
        logReference,
        <String, dynamic>{
          'action': approved
              ? 'player_badge_approved'
              : 'player_badge_removed',
          'reason': reason,
          'adminId': adminId,
          'performedByUid': adminId,
          'targetUserId': widget.userId,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      _reasonController.clear();

      _showMessage(
        approved
            ? 'Oyuncu rozeti verildi.'
            : 'Oyuncu rozeti kaldırıldı.',
      );
    } catch (error) {
      _showMessage(
        'İşlem tamamlanamadı: $error',
      );
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
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userReference.snapshots(),
      builder: (
          BuildContext context,
          AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Üyelik Yönetimi'),
            ),
            body: const Center(
              child: Text(
                'Üyelik bilgileri yüklenemedi.',
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Üyelik Yönetimi'),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final Map<String, dynamic> data =
            snapshot.data?.data() ?? <String, dynamic>{};

        final bool isPlus = data['plus'] == true;

        final bool isPlayer =
            data['oyuncuRozeti'] == true ||
                data['verified'] == true ||
                data['verificationStatus'] == 'approved';

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Üyelik Yönetimi',
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              32,
            ),
            children: <Widget>[
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Mevcut üyelik',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _StatusRow(
                        title: 'Plus üyelik',
                        enabled: isPlus,
                        enabledText: 'Plus üye',
                        disabledText: 'Normal üye',
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
                        style: TextStyle(
                          height: 1.4,
                        ),
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
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Admin işlemi',
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
                        decoration: const InputDecoration(
                          labelText: 'İşlem açıklaması',
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
                            _updatePlus(
                              enabled: true,
                            );
                          },
                          icon: const Icon(
                            Icons.workspace_premium_outlined,
                          ),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            child: Text(
                              'Plus Üyelik Ver',
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
                            _updatePlus(
                              enabled: false,
                            );
                          },
                          icon: const Icon(
                            Icons.remove_circle_outline,
                          ),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            child: Text(
                              'Plus Üyeliği Kaldır',
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
                            _updatePlayerBadge(
                              approved: true,
                            );
                          },
                          icon: const Icon(
                            Icons.verified_outlined,
                          ),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            child: Text(
                              'Oyuncu Rozeti Ver',
                            ),
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
                            _updatePlayerBadge(
                              approved: false,
                            );
                          },
                          icon: const Icon(
                            Icons.remove_circle_outline,
                          ),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            child: Text(
                              'Oyuncu Rozetini Kaldır',
                            ),
                          ),
                        ),
                      ),
                      if (_saving) ...<Widget>[
                        const SizedBox(height: 16),
                        const Center(
                          child: CircularProgressIndicator(),
                        ),
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
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Icon(
          enabled
              ? Icons.check_circle_rounded
              : Icons.remove_circle_outline,
          size: 20,
          color: enabled ? Colors.green : null,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            enabled ? enabledText : disabledText,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}