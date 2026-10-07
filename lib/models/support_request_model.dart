import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/support_categories.dart';

class SupportRequestModel {
  final String id;

  final String userId;

  final SupportCategory category;

  final String subject;

  final String description;

  final String? relatedUserId;

  final String? relatedEventId;

  final String? relatedMessageId;

  final List<String> attachmentUrls;

  final SupportUrgency urgency;

  final SupportRequestStatus status;

  final String adminResponse;

  final String lastMessage;

  final String lastMessageSenderId;

  final Timestamp? createdAt;

  final Timestamp? updatedAt;

  final Timestamp? closedAt;

  final String ticketId;

  final int replyCount;

  final bool isReadByUser;

  final bool isReadByAdmin;

  final bool isDeleted;

  final List<String> tags;

  final String? assignedAdminId;

  final Timestamp? firstResponseAt;

  final Timestamp? lastReplyAt;
  final int priorityScore;
  final int? satisfactionScore;

  const SupportRequestModel({
    required this.id,
    required this.userId,
    required this.category,
    required this.subject,
    required this.description,
    required this.attachmentUrls,
    required this.urgency,
    required this.status,
    required this.adminResponse,
    this.lastMessage = '',

    this.lastMessageSenderId = '',
    this.relatedUserId,
    this.relatedEventId,
    this.relatedMessageId,
    this.createdAt,
    this.updatedAt,
    this.closedAt,
    this.ticketId = '',

    this.replyCount = 0,

    this.isReadByUser = true,

    this.isReadByAdmin = false,

    this.isDeleted = false,

    this.tags = const [],

    this.assignedAdminId,

    this.firstResponseAt,

    this.lastReplyAt,
    this.priorityScore = 0,
    this.satisfactionScore,
  });

  factory SupportRequestModel.fromMap(String id, Map<String, dynamic> map) {
    return SupportRequestModel(
      id: id,
      userId: map['userId'] ?? '',
      category: SupportCategoryExtension.fromValue(map['category']),
      subject: map['subject'] ?? '',
      description: map['description'] ?? '',
      relatedUserId: map['relatedUserId'],
      relatedEventId: map['relatedEventId'],
      relatedMessageId: map['relatedMessageId'],
      attachmentUrls: List<String>.from(map['attachmentUrls'] ?? const []),
      urgency: SupportUrgencyExtension.fromValue(map['urgency']),
      status: SupportRequestStatusExtension.fromValue(map['status']),
      adminResponse: map['adminResponse'] ?? '',
      lastMessage: map['lastMessage'] ?? '',

      lastMessageSenderId: map['lastMessageSenderId'] ?? '',
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
      closedAt: map['closedAt'],
      ticketId: map['ticketId'] ?? '',

      replyCount: map['replyCount'] ?? 0,

      isReadByUser: map['isReadByUser'] ?? true,

      isReadByAdmin: map['isReadByAdmin'] ?? false,

      isDeleted: map['isDeleted'] ?? false,

      tags: List<String>.from(map['tags'] ?? const []),

      assignedAdminId: map['assignedAdminId'],

      firstResponseAt: map['firstResponseAt'],

      lastReplyAt: map['lastReplyAt'],
      priorityScore: (map['priorityScore'] ?? 0) as int,
      satisfactionScore: map['satisfactionScore'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'category': category.value,
      'subject': subject,
      'description': description,
      'relatedUserId': relatedUserId,
      'relatedEventId': relatedEventId,
      'relatedMessageId': relatedMessageId,
      'attachmentUrls': attachmentUrls,
      'urgency': urgency.value,
      'status': status.value,
      'adminResponse': adminResponse,
      'lastMessage': lastMessage,

      'lastMessageSenderId': lastMessageSenderId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'closedAt': closedAt,
      'ticketId': ticketId,

      'replyCount': replyCount,

      'isReadByUser': isReadByUser,

      'isReadByAdmin': isReadByAdmin,

      'isDeleted': isDeleted,

      'tags': tags,

      'assignedAdminId': assignedAdminId,

      'firstResponseAt': firstResponseAt,

      'lastReplyAt': lastReplyAt,
      'priorityScore': priorityScore,
      'satisfactionScore': satisfactionScore,
    };
  }

  SupportRequestModel copyWith({
    String? id,
    String? userId,
    SupportCategory? category,
    String? subject,
    String? description,
    String? relatedUserId,
    String? relatedEventId,
    String? relatedMessageId,
    List<String>? attachmentUrls,
    SupportUrgency? urgency,
    SupportRequestStatus? status,
    String? adminResponse,
    String? lastMessage,

    String? lastMessageSenderId,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    Timestamp? closedAt,
    String? ticketId,

    int? replyCount,

    bool? isReadByUser,

    bool? isReadByAdmin,

    bool? isDeleted,

    List<String>? tags,

    String? assignedAdminId,

    Timestamp? firstResponseAt,

    Timestamp? lastReplyAt,
    int? priorityScore,
    int? satisfactionScore,
  }) {
    return SupportRequestModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      relatedUserId: relatedUserId ?? this.relatedUserId,
      relatedEventId: relatedEventId ?? this.relatedEventId,
      relatedMessageId: relatedMessageId ?? this.relatedMessageId,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      urgency: urgency ?? this.urgency,
      status: status ?? this.status,
      adminResponse: adminResponse ?? this.adminResponse,
      lastMessage: lastMessage ?? this.lastMessage,

      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      closedAt: closedAt ?? this.closedAt,
      ticketId: ticketId ?? this.ticketId,

      replyCount: replyCount ?? this.replyCount,

      isReadByUser: isReadByUser ?? this.isReadByUser,

      isReadByAdmin: isReadByAdmin ?? this.isReadByAdmin,

      isDeleted: isDeleted ?? this.isDeleted,

      tags: tags ?? this.tags,

      assignedAdminId: assignedAdminId ?? this.assignedAdminId,

      firstResponseAt: firstResponseAt ?? this.firstResponseAt,

      lastReplyAt: lastReplyAt ?? this.lastReplyAt,
      priorityScore: priorityScore ?? this.priorityScore,
      satisfactionScore: satisfactionScore ?? this.satisfactionScore,
    );
  }
}
