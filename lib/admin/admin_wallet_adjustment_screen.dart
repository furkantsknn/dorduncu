import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminWalletAdjustmentScreen extends StatefulWidget {
  const AdminWalletAdjustmentScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  State<AdminWalletAdjustmentScreen> createState() =>
      _AdminWalletAdjustmentScreenState();
}

class _AdminWalletAdjustmentScreenState
    extends State<AdminWalletAdjustmentScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  String _selectedOperation = 'balance_add';
  String _selectedBalanceType = 'withdrawable';
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> get _userReference {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId);
  }

  DocumentReference<Map<String, dynamic>> get _walletReference {
    return FirebaseFirestore.instance
        .collection('wallets')
        .doc(widget.userId);
  }

  bool get _isBalanceOperation {
    return _selectedOperation == 'balance_add' ||
        _selectedOperation == 'balance_remove';
  }

  bool get _isAddition {
    return _selectedOperation == 'balance_add' ||
        _selectedOperation == 'point_add';
  }
  String get _selectedBalanceField {
    return _selectedBalanceType == 'market'
        ? 'marketBalanceKurus'
        : 'availableBalanceKurus';
  }

  String get _selectedBalanceLabel {
    return _selectedBalanceType == 'market'
        ? 'Market Bakiyesi'
        : 'Çekilebilir Bakiye';
  }
  Future<void> _save() async {
    if (_saving) {
      return;
    }

    final String amountText = _amountController.text
        .trim()
        .replaceAll(',', '.');

    final double? amount = double.tryParse(amountText);
    final String reason = _reasonController.text.trim();

    if (amount == null || amount <= 0) {
      _showMessage('Geçerli bir tutar gir.');
      return;
    }

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
          title: const Text('İşlemi Onayla'),
          content: Text(
            '${_operationTitle(_selectedOperation)}\n\n'
                '${_isBalanceOperation ? amount.toStringAsFixed(2) : amount.toStringAsFixed(0)} '
                '${_isBalanceOperation ? 'TL' : 'puan'}\n'
                '${_isBalanceOperation ? 'Bakiye türü: $_selectedBalanceLabel\n' : ''}\n'
                'Açıklama: $reason',
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
      if (_isBalanceOperation) {
        await _updateBalance(
          amount: amount,
          adminId: adminId,
          reason: reason,
        );
      } else {
        await _updatePoints(
          amount: amount,
          adminId: adminId,
          reason: reason,
        );
      }

      if (!mounted) {
        return;
      }

      _amountController.clear();
      _reasonController.clear();

      _showMessage('İşlem başarıyla tamamlandı.');
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

  Future<void> _updateBalance({
    required double amount,
    required String adminId,
    required String reason,
  }) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    final int amountKurus = (amount * 100).round();
    final int delta = _isAddition ? amountKurus : -amountKurus;

    final DocumentReference<Map<String, dynamic>> transactionReference =
    _walletReference.collection('transactions').doc();
    final DocumentReference<Map<String, dynamic>>
    notificationReference =
    _userReference.collection('notifications').doc();

    final DocumentReference<Map<String, dynamic>>
    decisionReference =
    _userReference.collection('management_decisions').doc();

    await firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> walletDocument =
      await transaction.get(_walletReference);

      final Map<String, dynamic> walletData =
          walletDocument.data() ?? <String, dynamic>{};

      final int currentBalance =
          (walletData[_selectedBalanceField] as num?)?.toInt() ?? 0;

      final int newBalance = currentBalance + delta;

      if (newBalance < 0) {
        throw StateError('Kullanıcının bakiyesi yetersiz.');
      }

      transaction.set(
        _walletReference,
        < String, dynamic>{
          'availableBalanceKurus':
          _selectedBalanceField == 'availableBalanceKurus'
              ? newBalance
              : (walletData['availableBalanceKurus'] as num?)?.toInt() ?? 0,
          'marketBalanceKurus':
          _selectedBalanceField == 'marketBalanceKurus'
              ? newBalance
              : (walletData['marketBalanceKurus'] as num?)?.toInt() ?? 0,

          'pendingBalanceKurus':
          (walletData['pendingBalanceKurus'] as num?)?.toInt() ?? 0,
          'refundBalanceKurus':
          (walletData['refundBalanceKurus'] as num?)?.toInt() ?? 0,
          'frozenBalanceKurus':
          (walletData['frozenBalanceKurus'] as num?)?.toInt() ?? 0,
          'withdrawalPendingKurus':
          (walletData['withdrawalPendingKurus'] as num?)?.toInt() ?? 0,
          'isFrozen': walletData['isFrozen'] == true,
          'createdAt': walletDocument.exists
              ? walletData['createdAt']
              : FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      transaction.set(transactionReference, <String, dynamic>{
        'type': _isAddition ? 'admin_credit' : 'admin_debit',
        'amountKurus': delta,
        'status': 'completed',
        'description': reason,
        'adminId': adminId,
        'performedByUid': adminId,
        'targetUserId': widget.userId,
        'metadata': <String, dynamic>{
          'previousBalanceKurus': currentBalance,
          'newBalanceKurus': newBalance,
          'balanceType': _selectedBalanceType,
          'balanceField': _selectedBalanceField,
          'availableDelta':
          _selectedBalanceField == 'availableBalanceKurus' ? delta : 0,
          'marketDelta':
          _selectedBalanceField == 'marketBalanceKurus' ? delta : 0,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(
        notificationReference,
        <String, dynamic>{
          'notificationId': notificationReference.id,
          'userId': widget.userId,
          'actorId': adminId,
          'type': 'walletAdjustment',
          'title': _isAddition
              ? 'Hesabına bakiye eklendi'
              : 'Hesabından bakiye düşüldü',
          'message': '${amount.toStringAsFixed(2)} TL\n\n$reason',
          'isRead': false,
          'read': false,
          'okundu': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      transaction.set(
        decisionReference,
        <String, dynamic>{
          'decisionId': decisionReference.id,
          'userId': widget.userId,
          'adminId': adminId,
          'type': 'walletAdjustment',
          'title': _isAddition
              ? 'Bakiye Düzenlemesi'
              : 'Cezai Bakiye Kesintisi',
          'reason': reason,
          'amount': amount,
          'status': 'completed',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    });
  }

  Future<void> _updatePoints({
    required double amount,
    required String adminId,
    required String reason,
  }) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    final double normalizedAmount = amount.roundToDouble();
    final double delta =
    _isAddition ? normalizedAmount : -normalizedAmount;

    final DocumentReference<Map<String, dynamic>> logReference =
    _userReference.collection('point_transactions').doc();

    final DocumentReference<Map<String, dynamic>>
    notificationReference =
    _userReference.collection('notifications').doc();

    final DocumentReference<Map<String, dynamic>>
    decisionReference =
    _userReference.collection('management_decisions').doc();

    await firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> userDocument =
      await transaction.get(_userReference);

      final Map<String, dynamic>? userData = userDocument.data();

      if (!userDocument.exists || userData == null) {
        throw StateError('Kullanıcı bulunamadı.');
      }

      final double currentPoints =
          (userData['puan'] as num?)?.toDouble() ?? 0;

      final double newPoints = currentPoints + delta;

      if (newPoints < 0) {
        throw StateError('Kullanıcının puanı yetersiz.');
      }

      transaction.update(_userReference, <String, dynamic>{
        'puan': newPoints,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(logReference, <String, dynamic>{
        'type':
        _isAddition ? 'admin_point_credit' : 'admin_point_debit',
        'amount': delta,
        'status': 'completed',
        'description': reason,
        'adminId': adminId,
        'performedByUid': adminId,
        'targetUserId': widget.userId,
        'previousPoints': currentPoints,
        'newPoints': newPoints,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.set(
        notificationReference,
        <String, dynamic>{
          'notificationId': notificationReference.id,
          'userId': widget.userId,
          'actorId': adminId,
          'type': 'pointAdjustment',
          'title': _isAddition
              ? 'Puanın güncellendi'
              : 'Puanından kesinti yapıldı',
          'message': '${amount.toStringAsFixed(0)} puan\n\n$reason',
          'isRead': false,
          'read': false,
          'okundu': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      transaction.set(
        decisionReference,
        <String, dynamic>{
          'decisionId': decisionReference.id,
          'userId': widget.userId,
          'adminId': adminId,
          'type': 'pointAdjustment',
          'title': _isAddition
              ? 'Puan Düzenlemesi'
              : 'Cezai Puan Kesintisi',
          'reason': reason,
          'amount': amount,
          'status': 'completed',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    });
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

  String _operationTitle(String value) {
    switch (value) {
      case 'balance_add':
        return 'Bakiye Ekle';
      case 'balance_remove':
        return 'Bakiye Düş';
      case 'point_add':
        return 'Puan Ekle';
      case 'point_remove':
        return 'Puan Düş';
      default:
        return 'İşlem';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bakiye ve Puan İşlemi',
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
                  const Text(
                    'İşlem Türü',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedOperation,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'balance_add',
                        child: Text('Bakiye Ekle'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'balance_remove',
                        child: Text('Bakiye Düş'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'point_add',
                        child: Text('Puan Ekle'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'point_remove',
                        child: Text('Puan Düş'),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (String? value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _selectedOperation = value;
                        _amountController.clear();
                      });
                    },
                  ),
                  if (_isBalanceOperation) ...<Widget>[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedBalanceType,
                      decoration: const InputDecoration(
                        labelText: 'Bakiye Türü',
                        border: OutlineInputBorder(),
                      ),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: 'market',
                          child: Text('Sadece Market Bakiyesi'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'withdrawable',
                          child: Text('Çekilebilir Bakiye'),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (String? value) {
                        if (value == null) return;

                        setState(() {
                          _selectedBalanceType = value;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amountController,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText:
                      _isBalanceOperation ? 'Tutar' : 'Puan',
                      suffixText:
                      _isBalanceOperation ? 'TL' : 'puan',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _reasonController,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'İşlem açıklaması',
                      hintText:
                      'Örnek: Kampanya ödülü, manuel düzeltme veya iade',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.save_outlined),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        child: Text(
                          _saving
                              ? 'Kaydediliyor...'
                              : _operationTitle(_selectedOperation),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}