import 'package:cloud_firestore/cloud_firestore.dart';

enum WalletTransactionType {
  payment,
  pendingEarning,
  earningReleased,
  refund,
  cancellationCompensation,
  transfer,
  adjustment,
}

enum WalletTransactionStatus {
  pending,
  completed,
  cancelled,
  failed,
}

class WalletTransactionModel {
  const WalletTransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    required this.amount,
    required this.currency,
    required this.title,
    required this.createdAt,
    this.eventId,
    this.paymentId,
    this.description = '',
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String userId;
  final WalletTransactionType type;
  final WalletTransactionStatus status;
  final double amount;
  final String currency;
  final String title;
  final DateTime createdAt;
  final String? eventId;
  final String? paymentId;
  final String description;
  final Map<String, dynamic> metadata;

  factory WalletTransactionModel.fromDocument(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data() ?? const <String, dynamic>{};

    return WalletTransactionModel(
      id: document.id,
      userId: data['userId']?.toString() ?? '',
      type: _typeFromString(data['type']?.toString()),
      status: _statusFromString(data['status']?.toString()),
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      currency: data['currency']?.toString() ?? 'TRY',
      title: data['title']?.toString() ?? '',
      createdAt: _dateFromValue(data['createdAt']),
      eventId: _nullableString(data['eventId']),
      paymentId: _nullableString(data['paymentId']),
      description: data['description']?.toString() ?? '',
      metadata: data['metadata'] is Map
          ? Map<String, dynamic>.from(data['metadata'] as Map)
          : const <String, dynamic>{},
    );
  }

  factory WalletTransactionModel.fromMap(
      Map<String, dynamic> map, {
        String id = '',
      }) {
    return WalletTransactionModel(
      id: id,
      userId: map['userId']?.toString() ?? '',
      type: _typeFromString(map['type']?.toString()),
      status: _statusFromString(map['status']?.toString()),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      currency: map['currency']?.toString() ?? 'TRY',
      title: map['title']?.toString() ?? '',
      createdAt: _dateFromValue(map['createdAt']),
      eventId: _nullableString(map['eventId']),
      paymentId: _nullableString(map['paymentId']),
      description: map['description']?.toString() ?? '',
      metadata: map['metadata'] is Map
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userId': userId,
      'type': type.name,
      'status': status.name,
      'amount': amount,
      'currency': currency,
      'title': title,
      'createdAt': Timestamp.fromDate(createdAt),
      if (eventId != null) 'eventId': eventId,
      if (paymentId != null) 'paymentId': paymentId,
      'description': description,
      'metadata': metadata,
    };
  }

  bool get isCredit => amount > 0;

  bool get isDebit => amount < 0;

  bool get isPending => status == WalletTransactionStatus.pending;

  bool get isCompleted => status == WalletTransactionStatus.completed;

  String get signedAmountText {
    final prefix = amount > 0 ? '+' : '';
    return '$prefix${amount.toStringAsFixed(2)} $currency';
  }

  WalletTransactionModel copyWith({
    String? id,
    String? userId,
    WalletTransactionType? type,
    WalletTransactionStatus? status,
    double? amount,
    String? currency,
    String? title,
    DateTime? createdAt,
    String? eventId,
    String? paymentId,
    String? description,
    Map<String, dynamic>? metadata,
  }) {
    return WalletTransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      eventId: eventId ?? this.eventId,
      paymentId: paymentId ?? this.paymentId,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
    );
  }

  static WalletTransactionType _typeFromString(String? value) {
    return WalletTransactionType.values.firstWhere(
          (item) => item.name == value,
      orElse: () => WalletTransactionType.adjustment,
    );
  }

  static WalletTransactionStatus _statusFromString(String? value) {
    return WalletTransactionStatus.values.firstWhere(
          (item) => item.name == value,
      orElse: () => WalletTransactionStatus.pending,
    );
  }

  static DateTime _dateFromValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    if (value is String) {
      return DateTime.tryParse(value) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}