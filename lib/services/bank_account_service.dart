import 'package:cloud_firestore/cloud_firestore.dart';

class BankAccountServiceException implements Exception {
  const BankAccountServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BankAccountService {
  BankAccountService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _walletsCollection = 'wallets';
  static const String _bankAccountsCollection = 'bank_accounts';

  static DocumentReference<Map<String, dynamic>> walletRef(String uid) {
    final String normalizedUid = uid.trim();

    if (normalizedUid.isEmpty) {
      throw const BankAccountServiceException(
        'Kullanıcı kimliği geçersiz.',
      );
    }

    return _firestore.collection(_walletsCollection).doc(normalizedUid);
  }

  static CollectionReference<Map<String, dynamic>> bankAccountsRef(
      String uid,
      ) {
    return walletRef(uid).collection(_bankAccountsCollection);
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchBankAccounts(
      String uid,
      ) {
    return bankAccountsRef(uid)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  static Future<String> addBankAccount({
    required String uid,
    required String bankName,
    required String iban,
    required String accountHolderName,
    bool makeDefault = false,
  }) async {
    final String normalizedBankName = bankName.trim();
    final String normalizedIban = normalizeIban(iban);
    final String normalizedHolder = accountHolderName.trim();

    _validateBankAccount(
      bankName: normalizedBankName,
      iban: normalizedIban,
      accountHolderName: normalizedHolder,
    );

    final CollectionReference<Map<String, dynamic>> accounts =
    bankAccountsRef(uid);

    final QuerySnapshot<Map<String, dynamic>> existingSnapshot =
    await accounts.get();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
    in existingSnapshot.docs) {
      final String existingIban = normalizeIban(
        document.data()['iban']?.toString() ?? '',
      );

      if (existingIban == normalizedIban) {
        throw const BankAccountServiceException(
          'Bu IBAN zaten kayıtlı.',
        );
      }
    }

    final bool shouldBeDefault =
        makeDefault || existingSnapshot.docs.isEmpty;

    final DocumentReference<Map<String, dynamic>> newAccount =
    accounts.doc();

    final WriteBatch batch = _firestore.batch();

    if (shouldBeDefault) {
      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
      in existingSnapshot.docs) {
        if (document.data()['isDefault'] == true) {
          batch.update(document.reference, <String, dynamic>{
            'isDefault': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    }

    batch.set(newAccount, <String, dynamic>{
      'bankName': normalizedBankName,
      'iban': normalizedIban,
      'accountHolderName': normalizedHolder,
      'isDefault': shouldBeDefault,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    return newAccount.id;
  }

  static Future<void> updateBankAccount({
    required String uid,
    required String accountId,
    required String bankName,
    required String iban,
    required String accountHolderName,
    required bool isDefault,
  }) async {
    final String normalizedAccountId = accountId.trim();
    final String normalizedBankName = bankName.trim();
    final String normalizedIban = normalizeIban(iban);
    final String normalizedHolder = accountHolderName.trim();

    if (normalizedAccountId.isEmpty) {
      throw const BankAccountServiceException(
        'Banka hesabı kaydı geçersiz.',
      );
    }

    _validateBankAccount(
      bankName: normalizedBankName,
      iban: normalizedIban,
      accountHolderName: normalizedHolder,
    );

    final CollectionReference<Map<String, dynamic>> accounts =
    bankAccountsRef(uid);

    final DocumentReference<Map<String, dynamic>> selectedAccount =
    accounts.doc(normalizedAccountId);

    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
      selectedAccount.get(),
      accounts.get(),
    ]);

    final DocumentSnapshot<Map<String, dynamic>> selectedSnapshot =
    results[0] as DocumentSnapshot<Map<String, dynamic>>;

    final QuerySnapshot<Map<String, dynamic>> existingSnapshot =
    results[1] as QuerySnapshot<Map<String, dynamic>>;

    if (!selectedSnapshot.exists) {
      throw const BankAccountServiceException(
        'Banka hesabı bulunamadı.',
      );
    }

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
    in existingSnapshot.docs) {
      if (document.id == normalizedAccountId) {
        continue;
      }

      final String existingIban = normalizeIban(
        document.data()['iban']?.toString() ?? '',
      );

      if (existingIban == normalizedIban) {
        throw const BankAccountServiceException(
          'Bu IBAN başka bir hesapta kayıtlı.',
        );
      }
    }

    final WriteBatch batch = _firestore.batch();

    if (isDefault) {
      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
      in existingSnapshot.docs) {
        if (document.id != normalizedAccountId &&
            document.data()['isDefault'] == true) {
          batch.update(document.reference, <String, dynamic>{
            'isDefault': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    }

    batch.update(selectedAccount, <String, dynamic>{
      'bankName': normalizedBankName,
      'iban': normalizedIban,
      'accountHolderName': normalizedHolder,
      'isDefault': isDefault,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    if (!isDefault) {
      await _ensureDefaultAccount(uid);
    }
  }

  static Future<void> deleteBankAccount({
    required String uid,
    required String accountId,
  }) async {
    final String normalizedAccountId = accountId.trim();

    if (normalizedAccountId.isEmpty) {
      throw const BankAccountServiceException(
        'Banka hesabı kaydı geçersiz.',
      );
    }

    final CollectionReference<Map<String, dynamic>> accounts =
    bankAccountsRef(uid);

    final DocumentReference<Map<String, dynamic>> selectedAccount =
    accounts.doc(normalizedAccountId);

    final DocumentSnapshot<Map<String, dynamic>> selectedSnapshot =
    await selectedAccount.get();

    if (!selectedSnapshot.exists) {
      throw const BankAccountServiceException(
        'Banka hesabı bulunamadı.',
      );
    }

    final bool wasDefault =
        selectedSnapshot.data()?['isDefault'] == true;

    await selectedAccount.delete();

    if (wasDefault) {
      await _ensureDefaultAccount(uid);
    }
  }

  static Future<void> setDefaultBankAccount({
    required String uid,
    required String accountId,
  }) async {
    final String normalizedAccountId = accountId.trim();

    if (normalizedAccountId.isEmpty) {
      throw const BankAccountServiceException(
        'Banka hesabı kaydı geçersiz.',
      );
    }

    final CollectionReference<Map<String, dynamic>> accounts =
    bankAccountsRef(uid);

    final DocumentReference<Map<String, dynamic>> selectedAccount =
    accounts.doc(normalizedAccountId);

    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
      selectedAccount.get(),
      accounts.get(),
    ]);

    final DocumentSnapshot<Map<String, dynamic>> selectedSnapshot =
    results[0] as DocumentSnapshot<Map<String, dynamic>>;

    final QuerySnapshot<Map<String, dynamic>> existingSnapshot =
    results[1] as QuerySnapshot<Map<String, dynamic>>;

    if (!selectedSnapshot.exists) {
      throw const BankAccountServiceException(
        'Banka hesabı bulunamadı.',
      );
    }

    final WriteBatch batch = _firestore.batch();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
    in existingSnapshot.docs) {
      final bool shouldBeDefault =
          document.id == normalizedAccountId;

      if (document.data()['isDefault'] != shouldBeDefault) {
        batch.update(document.reference, <String, dynamic>{
          'isDefault': shouldBeDefault,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
  }

  static Future<void> _ensureDefaultAccount(String uid) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
    await bankAccountsRef(uid)
        .orderBy('createdAt', descending: false)
        .get();

    if (snapshot.docs.isEmpty) {
      return;
    }

    final bool hasDefault = snapshot.docs.any(
          (QueryDocumentSnapshot<Map<String, dynamic>> document) =>
      document.data()['isDefault'] == true,
    );

    if (hasDefault) {
      return;
    }

    await snapshot.docs.first.reference.update(<String, dynamic>{
      'isDefault': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static String maskIban(String iban) {
    final String normalizedIban = normalizeIban(iban);

    if (normalizedIban.length < 8) {
      return normalizedIban;
    }

    return '${normalizedIban.substring(0, 4)} '
        '•••• •••• •••• •••• '
        '${normalizedIban.substring(normalizedIban.length - 4)}';
  }

  static String formatIban(String iban) {
    final String normalizedIban = normalizeIban(iban);
    final StringBuffer buffer = StringBuffer();

    for (int index = 0; index < normalizedIban.length; index++) {
      if (index > 0 && index % 4 == 0) {
        buffer.write(' ');
      }

      buffer.write(normalizedIban[index]);
    }

    return buffer.toString();
  }

  static String normalizeIban(String iban) {
    return iban
        .replaceAll(RegExp(r'\s+'), '')
        .toUpperCase();
  }

  static void _validateBankAccount({
    required String bankName,
    required String iban,
    required String accountHolderName,
  }) {
    if (bankName.length < 2) {
      throw const BankAccountServiceException(
        'Geçerli bir banka adı girilmelidir.',
      );
    }

    if (accountHolderName.length < 3) {
      throw const BankAccountServiceException(
        'Hesap sahibi adı geçersiz.',
      );
    }

    if (!_isValidTurkishIban(iban)) {
      throw const BankAccountServiceException(
        'Geçerli bir Türkiye IBAN’ı girilmelidir.',
      );
    }
  }

  static bool _isValidTurkishIban(String iban) {
    if (!RegExp(r'^TR\d{24}$').hasMatch(iban)) {
      return false;
    }

    final String rearranged =
        '${iban.substring(4)}${iban.substring(0, 4)}';

    final StringBuffer numeric = StringBuffer();

    for (final int codeUnit in rearranged.codeUnits) {
      if (codeUnit >= 65 && codeUnit <= 90) {
        numeric.write(codeUnit - 55);
      } else {
        numeric.writeCharCode(codeUnit);
      }
    }

    int remainder = 0;

    for (final int codeUnit in numeric.toString().codeUnits) {
      remainder = (remainder * 10 + codeUnit - 48) % 97;
    }

    return remainder == 1;
  }
}