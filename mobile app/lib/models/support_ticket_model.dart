import 'package:flutter/material.dart';

/// Supported categories for customer support tickets
enum SupportCategory {
  account,
  payment,
  liveRoom,
  reportAppeal,
  bug,
  general,
}

extension SupportCategoryExtension on SupportCategory {
  String get apiValue {
    switch (this) {
      case SupportCategory.account:
        return 'ACCOUNT';
      case SupportCategory.payment:
        return 'PAYMENT';
      case SupportCategory.liveRoom:
        return 'LIVE_ROOM';
      case SupportCategory.reportAppeal:
        return 'REPORT_APPEAL';
      case SupportCategory.bug:
        return 'BUG';
      case SupportCategory.general:
        return 'GENERAL';
    }
  }

  String get displayName {
    switch (this) {
      case SupportCategory.account:
        return 'Account & Login';
      case SupportCategory.payment:
        return 'Payment & Recharge';
      case SupportCategory.liveRoom:
        return 'Live Room & Streaming';
      case SupportCategory.reportAppeal:
        return 'Ban & Report Appeal';
      case SupportCategory.bug:
        return 'Bug Report';
      case SupportCategory.general:
        return 'General Inquiries';
    }
  }

  IconData get icon {
    switch (this) {
      case SupportCategory.account:
        return Icons.person_outline_rounded;
      case SupportCategory.payment:
        return Icons.payment_rounded;
      case SupportCategory.liveRoom:
        return Icons.live_tv_rounded;
      case SupportCategory.reportAppeal:
        return Icons.gavel_rounded;
      case SupportCategory.bug:
        return Icons.bug_report_rounded;
      case SupportCategory.general:
        return Icons.help_outline_rounded;
    }
  }

  static SupportCategory fromString(String? val) {
    if (val == null) return SupportCategory.general;
    switch (val.toUpperCase()) {
      case 'ACCOUNT':
        return SupportCategory.account;
      case 'PAYMENT':
        return SupportCategory.payment;
      case 'LIVE_ROOM':
        return SupportCategory.liveRoom;
      case 'REPORT_APPEAL':
        return SupportCategory.reportAppeal;
      case 'BUG':
        return SupportCategory.bug;
      default:
        return SupportCategory.general;
    }
  }
}

/// Supported statuses for customer support tickets
enum SupportTicketStatus {
  open,
  inProgress,
  waitingOnUser,
  resolved,
  closed,
}

extension SupportTicketStatusExtension on SupportTicketStatus {
  String get apiValue {
    switch (this) {
      case SupportTicketStatus.open:
        return 'OPEN';
      case SupportTicketStatus.inProgress:
        return 'IN_PROGRESS';
      case SupportTicketStatus.waitingOnUser:
        return 'WAITING_ON_USER';
      case SupportTicketStatus.resolved:
        return 'RESOLVED';
      case SupportTicketStatus.closed:
        return 'CLOSED';
    }
  }

  String get displayName {
    switch (this) {
      case SupportTicketStatus.open:
        return 'Open';
      case SupportTicketStatus.inProgress:
        return 'In Progress';
      case SupportTicketStatus.waitingOnUser:
        return 'Waiting on You';
      case SupportTicketStatus.resolved:
        return 'Resolved';
      case SupportTicketStatus.closed:
        return 'Closed';
    }
  }

  Color get color {
    switch (this) {
      case SupportTicketStatus.open:
        return Colors.blue;
      case SupportTicketStatus.inProgress:
        return Colors.amber;
      case SupportTicketStatus.waitingOnUser:
        return Colors.orange;
      case SupportTicketStatus.resolved:
        return Colors.green;
      case SupportTicketStatus.closed:
        return Colors.grey;
    }
  }

  static SupportTicketStatus fromString(String? val) {
    if (val == null) return SupportTicketStatus.open;
    switch (val.toUpperCase()) {
      case 'OPEN':
        return SupportTicketStatus.open;
      case 'IN_PROGRESS':
        return SupportTicketStatus.inProgress;
      case 'WAITING_ON_USER':
        return SupportTicketStatus.waitingOnUser;
      case 'RESOLVED':
        return SupportTicketStatus.resolved;
      case 'CLOSED':
        return SupportTicketStatus.closed;
      default:
        return SupportTicketStatus.open;
    }
  }
}

/// Message model inside a support ticket conversation
class SupportMessageModel {
  final String id;
  final String ticketId;
  final String senderType; // 'USER', 'ADMIN', 'SYSTEM'
  final String senderId;
  final String message;
  final dynamic attachmentsJson;
  final bool isInternalNote;
  final DateTime createdAt;

  const SupportMessageModel({
    required this.id,
    required this.ticketId,
    required this.senderType,
    required this.senderId,
    required this.message,
    this.attachmentsJson,
    this.isInternalNote = false,
    required this.createdAt,
  });

  bool get isFromUser => senderType.toUpperCase() == 'USER';

  factory SupportMessageModel.fromJson(Map<String, dynamic> json) {
    return SupportMessageModel(
      id: json['id'] as String? ?? '',
      ticketId: json['ticketId'] as String? ?? '',
      senderType: (json['senderType'] as String? ?? 'USER').toUpperCase(),
      senderId: json['senderId'] as String? ?? '',
      message: json['message'] as String? ?? '',
      attachmentsJson: json['attachmentsJson'],
      isInternalNote: json['isInternalNote'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticketId': ticketId,
      'senderType': senderType,
      'senderId': senderId,
      'message': message,
      'attachmentsJson': attachmentsJson,
      'isInternalNote': isInternalNote,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// Model representing a backend customer support ticket
class SupportTicketModel {
  final String id;
  final String? ticketNumber;
  final String userId;
  final SupportCategory category;
  final String priority; // 'LOW', 'MEDIUM', 'HIGH', 'URGENT'
  final SupportTicketStatus status;
  final String subject;
  final String? resolutionNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final List<SupportMessageModel> messages;

  const SupportTicketModel({
    required this.id,
    this.ticketNumber,
    required this.userId,
    required this.category,
    this.priority = 'MEDIUM',
    required this.status,
    required this.subject,
    this.resolutionNotes,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.messages = const [],
  });

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    var rawMessages = json['messages'] as List<dynamic>? ?? [];
    var parsedMessages = rawMessages
        .map((m) => SupportMessageModel.fromJson(m as Map<String, dynamic>))
        .toList();

    return SupportTicketModel(
      id: json['id'] as String? ?? '',
      ticketNumber: json['ticketNumber'] as String? ?? json['id']?.toString().substring(0, 8),
      userId: json['userId'] as String? ?? '',
      category: SupportCategoryExtension.fromString(json['category'] as String?),
      priority: json['priority'] as String? ?? 'MEDIUM',
      status: SupportTicketStatusExtension.fromString(json['status'] as String?),
      subject: json['subject'] as String? ?? 'Support Inquiry',
      resolutionNotes: json['resolutionNotes'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.tryParse(json['resolvedAt'].toString())
          : null,
      messages: parsedMessages,
    );
  }

  SupportTicketModel copyWith({
    String? id,
    String? ticketNumber,
    String? userId,
    SupportCategory? category,
    String? priority,
    SupportTicketStatus? status,
    String? subject,
    String? resolutionNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? resolvedAt,
    List<SupportMessageModel>? messages,
  }) {
    return SupportTicketModel(
      id: id ?? this.id,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      subject: subject ?? this.subject,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticketNumber': ticketNumber,
      'userId': userId,
      'category': category.apiValue,
      'priority': priority,
      'status': status.apiValue,
      'subject': subject,
      'resolutionNotes': resolutionNotes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }
}
