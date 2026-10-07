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

  static CollectionReference<Map<String, dynamic>> transactionsRef(String uid) {
    return walletRef(uid).collection(_transactionsCollection);
  }

  static CollectionReference<Map<String, dynamic>> withdrawalsRef(String uid) {
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

    return transactionsRef(
      uid,
    ).orderBy('createdAt', descending: true).limit(safeLimit).snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchWithdrawals(
    String uid, {
    int limit = 50,
  }) {
    final int safeLimit = limit.clamp(1, 100);

    return withdrawalsRef(
      uid,
    ).orderBy('createdAt', descending: true).limit(safeLimit).snapshots();
  }
}
