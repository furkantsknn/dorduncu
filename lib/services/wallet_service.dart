import 'package:cloud_firestore/cloud_firestore.dart';

class WalletServiceException implements Exception {
  const WalletServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WalletService {
  WalletService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _walletsCollection = 'wallets';
  static const String _transactionsCollection = 'transactions';
  static const String _withdrawalsCollection = 'withdrawals';

  static DocumentReference<Map<String, dynamic>> walletRef(String uid) {
    final String normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      throw const WalletServiceException('Kullanıcı kimliği geçersiz.');
    }

    return _firestore.collection(_walletsCollection).doc(normalizedUid);
  }

  static CollectionReference<Map<String, dynamic>> transactionsRef(
      String uid,
      ) {
    return walletRef(uid).collection(_transactionsCollection);
  }

  static CollectionReference<Map<String, dynamic>> withdrawalsRef(
      String uid,
      ) {
    return walletRef(uid).collection(_withdrawalsCollection);
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchWallet(
      String uid,
      ) {
    return walletRef(uid).snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchTransactions(
      String uid, {
        int limit = 100,
      }) {
    final int safeLimit = limit.clamp(1, 250);

    return transactionsRef(uid)
        .orderBy('createdAt', descending: true)
        .limit(safeLimit)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchWithdrawals(
      String uid, {
        int limit = 50,
      }) {
    final int safeLimit = limit.clamp(1, 100);

    return withdrawalsRef(uid)
        .orderBy('createdAt', descending: true)
        .limit(safeLimit)
        .snapshots();
  }

  static Future<void> ensureWallet(String uid) async {
    final DocumentReference<Map<String, dynamic>> ref = walletRef(uid);

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
      await transaction.get(ref);

      if (snapshot.exists) {
        transaction.set(
          ref,
          <String, dynamic>{
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        return;
      }

      transaction.set(ref, <String, dynamic>{
        'availableBalanceKurus': 0,
        'marketBalanceKurus': 0,
        'pendingBalanceKurus': 0,
        'refundBalanceKurus': 0,
        'frozenBalanceKurus': 0,
        'withdrawalPendingKurus': 0,
        'isFrozen': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<String> addTransaction({
    required String uid,
    required String type,
    required int amountKurus,
    required String status,
    String? eventId,
    String? eventTitle,
    String? description,
    String? paymentId,
    String? transactionId,
    Map<String, dynamic>? metadata,
  }) async {
    _validateAmount(amountKurus, allowZero: true);

    final String normalizedType = type.trim();
    final String normalizedStatus = status.trim();

    if (normalizedType.isEmpty) {
      throw const WalletServiceException('İşlem türü boş olamaz.');
    }

    if (normalizedStatus.isEmpty) {
      throw const WalletServiceException('İşlem durumu boş olamaz.');
    }

    await ensureWallet(uid);

    final DocumentReference<Map<String, dynamic>> transactionRef =
    transactionId == null || transactionId.trim().isEmpty
        ? transactionsRef(uid).doc()
        : transactionsRef(uid).doc(transactionId.trim());

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> existing =
      await transaction.get(transactionRef);

      if (existing.exists) {
        return;
      }

      transaction.set(transactionRef, <String, dynamic>{
        'type': normalizedType,
        'amountKurus': amountKurus,
        'status': normalizedStatus,
        'eventId': eventId?.trim(),
        'eventTitle': eventTitle?.trim(),
        'description': description?.trim(),
        'paymentId': paymentId?.trim(),
        'metadata': metadata ?? <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return transactionRef.id;
  }

  static Future<void> creditPending({
    required String uid,
    required int amountKurus,
    required String referenceId,
    String? eventId,
    String? eventTitle,
    String? paymentId,
    String? description,
  }) async {
    await _applyBalanceMutation(
      uid: uid,
      transactionId: 'pending_credit_$referenceId',
      type: 'pending_credit',
      amountKurus: amountKurus,
      availableDelta: 0,
      pendingDelta: amountKurus,
      refundDelta: 0,
      frozenDelta: 0,
      withdrawalPendingDelta: 0,
      eventId: eventId,
      eventTitle: eventTitle,
      paymentId: paymentId,
      description: description,
    );
  }

  static Future<void> movePendingToAvailable({
    required String uid,
    required int amountKurus,
    required String eventId,
    String? eventTitle,
    String? paymentId,
    String? referenceId,
  }) async {
    final String safeReference =
    referenceId?.trim().isNotEmpty == true
        ? referenceId!.trim()
        : '${eventId.trim()}_$amountKurus';

    await _applyBalanceMutation(
      uid: uid,
      transactionId: 'earning_release_$safeReference',
      type: 'earning_released',
      amountKurus: amountKurus,
      availableDelta: amountKurus,
      pendingDelta: -amountKurus,
      refundDelta: 0,
      frozenDelta: 0,
      withdrawalPendingDelta: 0,
      eventId: eventId,
      eventTitle: eventTitle,
      paymentId: paymentId,
      description: 'Bekleyen kazanç kullanılabilir bakiyeye aktarıldı.',
    );
  }

  static Future<void> reversePending({
    required String uid,
    required int amountKurus,
    required String referenceId,
    String? eventId,
    String? eventTitle,
    String? paymentId,
    String? description,
  }) async {
    await _applyBalanceMutation(
      uid: uid,
      transactionId: 'pending_reverse_$referenceId',
      type: 'pending_reversed',
      amountKurus: amountKurus,
      availableDelta: 0,
      pendingDelta: -amountKurus,
      refundDelta: 0,
      frozenDelta: 0,
      withdrawalPendingDelta: 0,
      eventId: eventId,
      eventTitle: eventTitle,
      paymentId: paymentId,
      description: description,
    );
  }

  static Future<void> creditRefund({
    required String uid,
    required int amountKurus,
    required String referenceId,
    String? eventId,
    String? eventTitle,
    String? paymentId,
    String? description,
  }) async {
    await _applyBalanceMutation(
      uid: uid,
      transactionId: 'refund_credit_$referenceId',
      type: 'refund_credit',
      amountKurus: amountKurus,
      availableDelta: 0,
      pendingDelta: 0,
      refundDelta: amountKurus,
      frozenDelta: 0,
      withdrawalPendingDelta: 0,
      eventId: eventId,
      eventTitle: eventTitle,
      paymentId: paymentId,
      description: description,
    );
  }

  static Future<void> consumeRefundBalance({
    required String uid,
    required int amountKurus,
    required String referenceId,
    String? description,
  }) async {
    await _applyBalanceMutation(
      uid: uid,
      transactionId: 'refund_debit_$referenceId',
      type: 'refund_debit',
      amountKurus: amountKurus,
      availableDelta: 0,
      pendingDelta: 0,
      refundDelta: -amountKurus,
      frozenDelta: 0,
      withdrawalPendingDelta: 0,
      description: description,
    );
  }

  static Future<void> freezeAvailableBalance({
    required String uid,
    required int amountKurus,
    required String referenceId,
    String? description,
  }) async {
    await _applyBalanceMutation(
      uid: uid,
      transactionId: 'freeze_$referenceId',
      type: 'balance_frozen',
      amountKurus: amountKurus,
      availableDelta: -amountKurus,
      pendingDelta: 0,
      refundDelta: 0,
      frozenDelta: amountKurus,
      withdrawalPendingDelta: 0,
      description: description,
    );
  }

  static Future<void> releaseFrozenBalance({
    required String uid,
    required int amountKurus,
    required String referenceId,
    String? description,
  }) async {
    await _applyBalanceMutation(
      uid: uid,
      transactionId: 'unfreeze_$referenceId',
      type: 'balance_unfrozen',
      amountKurus: amountKurus,
      availableDelta: amountKurus,
      pendingDelta: 0,
      refundDelta: 0,
      frozenDelta: -amountKurus,
      withdrawalPendingDelta: 0,
      description: description,
    );
  }

  static Future<String> requestWithdrawal({
    required String uid,
    required int amountKurus,
    required String iban,
    required String accountHolderName,
  }) async {
    _validateAmount(amountKurus);

    final String normalizedIban = iban.replaceAll(' ', '').toUpperCase();
    final String normalizedHolder = accountHolderName.trim();

    if (!_isValidTurkishIban(normalizedIban)) {
      throw const WalletServiceException('Geçerli bir Türkiye IBAN’ı girilmelidir.');
    }

    if (normalizedHolder.length < 3) {
      throw const WalletServiceException('Hesap sahibi adı geçersiz.');
    }

    final DocumentReference<Map<String, dynamic>> wallet = walletRef(uid);
    final DocumentReference<Map<String, dynamic>> withdrawal =
    withdrawalsRef(uid).doc();
    final DocumentReference<Map<String, dynamic>> ledger =
    transactionsRef(uid).doc('withdrawal_request_${withdrawal.id}');

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> ledgerSnapshot =
      await transaction.get(ledger);
      if (ledgerSnapshot.exists) {
        return;
      }

      final DocumentSnapshot<Map<String, dynamic>> walletSnapshot =
      await transaction.get(wallet);
      final Map<String, dynamic> data = walletSnapshot.data() ?? <String, dynamic>{};

      final bool isFrozen = data['isFrozen'] == true;
      if (isFrozen) {
        throw const WalletServiceException('Cüzdan geçici olarak dondurulmuş.');
      }

      final int available = _readBalance(data, 'availableBalanceKurus');
      final int withdrawalPending =
      _readBalance(data, 'withdrawalPendingKurus');

      if (available < amountKurus) {
        throw const WalletServiceException('Kullanılabilir bakiye yetersiz.');
      }

      transaction.set(
        wallet,
        <String, dynamic>{
          'availableBalanceKurus': available - amountKurus,
          'withdrawalPendingKurus': withdrawalPending + amountKurus,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      transaction.set(withdrawal, <String, dynamic>{
        'amountKurus': amountKurus,
        'iban': normalizedIban,
        'accountHolderName': normalizedHolder,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(ledger, <String, dynamic>{
        'type': 'withdrawal_requested',
        'amountKurus': amountKurus,
        'status': 'pending',
        'withdrawalId': withdrawal.id,
        'description': 'Para çekme talebi oluşturuldu.',
        'metadata': <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return withdrawal.id;
  }

  static Future<void> cancelWithdrawal({
    required String uid,
    required String withdrawalId,
  }) async {
    final String normalizedId = withdrawalId.trim();
    if (normalizedId.isEmpty) {
      throw const WalletServiceException('Para çekme kaydı geçersiz.');
    }

    final DocumentReference<Map<String, dynamic>> wallet = walletRef(uid);
    final DocumentReference<Map<String, dynamic>> withdrawal =
    withdrawalsRef(uid).doc(normalizedId);
    final DocumentReference<Map<String, dynamic>> ledger =
    transactionsRef(uid).doc('withdrawal_cancel_$normalizedId');

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> existingLedger =
      await transaction.get(ledger);
      if (existingLedger.exists) {
        return;
      }

      final DocumentSnapshot<Map<String, dynamic>> withdrawalSnapshot =
      await transaction.get(withdrawal);
      final Map<String, dynamic>? withdrawalData = withdrawalSnapshot.data();

      if (!withdrawalSnapshot.exists || withdrawalData == null) {
        throw const WalletServiceException('Para çekme talebi bulunamadı.');
      }

      if (withdrawalData['status'] != 'pending') {
        throw const WalletServiceException('Bu para çekme talebi iptal edilemez.');
      }

      final int amountKurus =
          (withdrawalData['amountKurus'] as num?)?.toInt() ?? 0;
      _validateAmount(amountKurus);

      final DocumentSnapshot<Map<String, dynamic>> walletSnapshot =
      await transaction.get(wallet);
      final Map<String, dynamic> walletData =
          walletSnapshot.data() ?? <String, dynamic>{};

      final int available = _readBalance(walletData, 'availableBalanceKurus');
      final int withdrawalPending =
      _readBalance(walletData, 'withdrawalPendingKurus');

      if (withdrawalPending < amountKurus) {
        throw const WalletServiceException(
          'Bekleyen para çekme bakiyesi yetersiz.',
        );
      }

      transaction.set(
        wallet,
        <String, dynamic>{
          'availableBalanceKurus': available + amountKurus,
          'withdrawalPendingKurus': withdrawalPending - amountKurus,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      transaction.update(withdrawal, <String, dynamic>{
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(ledger, <String, dynamic>{
        'type': 'withdrawal_cancelled',
        'amountKurus': amountKurus,
        'status': 'completed',
        'withdrawalId': normalizedId,
        'description': 'Para çekme talebi iptal edildi.',
        'metadata': <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> setWalletFrozen({
    required String uid,
    required bool frozen,
    String? reason,
  }) async {
    await walletRef(uid).set(
      <String, dynamic>{
        'isFrozen': frozen,
        'freezeReason': frozen ? reason?.trim() : null,
        'frozenAt': frozen ? FieldValue.serverTimestamp() : null,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> _applyBalanceMutation({
    required String uid,
    required String transactionId,
    required String type,
    required int amountKurus,
    required int availableDelta,
    required int pendingDelta,
    required int refundDelta,
    required int frozenDelta,
    required int withdrawalPendingDelta,
    String? eventId,
    String? eventTitle,
    String? paymentId,
    String? description,
  }) async {
    _validateAmount(amountKurus);

    final DocumentReference<Map<String, dynamic>> wallet = walletRef(uid);
    final DocumentReference<Map<String, dynamic>> ledger =
    transactionsRef(uid).doc(transactionId);

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> ledgerSnapshot =
      await transaction.get(ledger);

      if (ledgerSnapshot.exists) {
        return;
      }

      final DocumentSnapshot<Map<String, dynamic>> walletSnapshot =
      await transaction.get(wallet);
      final Map<String, dynamic> data = walletSnapshot.data() ?? <String, dynamic>{};

      final int available = _readBalance(data, 'availableBalanceKurus');
      final int pending = _readBalance(data, 'pendingBalanceKurus');
      final int refund = _readBalance(data, 'refundBalanceKurus');
      final int frozen = _readBalance(data, 'frozenBalanceKurus');
      final int withdrawalPending =
      _readBalance(data, 'withdrawalPendingKurus');

      final int newAvailable = available + availableDelta;
      final int newPending = pending + pendingDelta;
      final int newRefund = refund + refundDelta;
      final int newFrozen = frozen + frozenDelta;
      final int newWithdrawalPending =
          withdrawalPending + withdrawalPendingDelta;

      if (newAvailable < 0) {
        throw const WalletServiceException('Kullanılabilir bakiye yetersiz.');
      }
      if (newPending < 0) {
        throw const WalletServiceException('Bekleyen bakiye yetersiz.');
      }
      if (newRefund < 0) {
        throw const WalletServiceException('İade bakiyesi yetersiz.');
      }
      if (newFrozen < 0) {
        throw const WalletServiceException('Dondurulmuş bakiye yetersiz.');
      }
      if (newWithdrawalPending < 0) {
        throw const WalletServiceException(
          'Bekleyen para çekme bakiyesi yetersiz.',
        );
      }

      transaction.set(
        wallet,
        <String, dynamic>{
          'availableBalanceKurus': newAvailable,
          'pendingBalanceKurus': newPending,
          'refundBalanceKurus': newRefund,
          'frozenBalanceKurus': newFrozen,
          'withdrawalPendingKurus': newWithdrawalPending,
          'createdAt': walletSnapshot.exists
              ? data['createdAt']
              : FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      transaction.set(ledger, <String, dynamic>{
        'type': type,
        'amountKurus': amountKurus,
        'status': 'completed',
        'eventId': eventId?.trim(),
        'eventTitle': eventTitle?.trim(),
        'paymentId': paymentId?.trim(),
        'description': description?.trim(),
        'metadata': <String, dynamic>{
          'availableDelta': availableDelta,
          'pendingDelta': pendingDelta,
          'refundDelta': refundDelta,
          'frozenDelta': frozenDelta,
          'withdrawalPendingDelta': withdrawalPendingDelta,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static int _readBalance(
      Map<String, dynamic> data,
      String field,
      ) {
    final int value = (data[field] as num?)?.toInt() ?? 0;
    return value < 0 ? 0 : value;
  }

  static void _validateAmount(
      int amountKurus, {
        bool allowZero = false,
      }) {
    if (allowZero ? amountKurus < 0 : amountKurus <= 0) {
      throw const WalletServiceException('İşlem tutarı geçersiz.');
    }
  }

  static bool _isValidTurkishIban(String iban) {
    return RegExp(r'^TR\d{24}$').hasMatch(iban);
  }
}
