import 'relationship_card_model.dart';

enum RelationshipInvitationStatus {
  pending,
  accepted,
  declined,
  expired,
  cancelled,
}

class RelationshipInvitationModel {
  final String id;
  final String transactionId;
  final String senderUserId;
  final String senderUserName;
  final String targetUserId;
  final String targetUserName;
  final RelationshipCardModel card;
  final RelationshipInvitationStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;

  const RelationshipInvitationModel({
    required this.id,
    required this.transactionId,
    required this.senderUserId,
    required this.senderUserName,
    required this.targetUserId,
    required this.targetUserName,
    required this.card,
    this.status = RelationshipInvitationStatus.pending,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'transactionId': transactionId,
        'senderUserId': senderUserId,
        'senderUserName': senderUserName,
        'targetUserId': targetUserId,
        'targetUserName': targetUserName,
        'card': card.toJson(),
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory RelationshipInvitationModel.fromJson(Map<String, dynamic> json) => RelationshipInvitationModel(
        id: json['id'] ?? '',
        transactionId: json['transactionId'] ?? '',
        senderUserId: json['senderUserId'] ?? '',
        senderUserName: json['senderUserName'] ?? '',
        targetUserId: json['targetUserId'] ?? '',
        targetUserName: json['targetUserName'] ?? '',
        card: RelationshipCardModel.fromJson(json['card'] ?? {}),
        status: RelationshipInvitationStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => RelationshipInvitationStatus.pending,
        ),
        createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
        expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : DateTime.now().add(const Duration(hours: 48)),
      );
}
