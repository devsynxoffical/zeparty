import 'package:flutter/foundation.dart';

enum LiveCoHostInvitationStatus {
  pending,
  accepted,
  declined,
  cancelled,
  expired,
  failed,
}

@immutable
class LiveCoHostInvitationModel {
  final String id;
  final String roomId;
  final String roomTitle;
  final String inviterId;
  final String inviterName;
  final String inviterAvatarUrl;
  final String recipientId;
  final String recipientName;
  final LiveCoHostInvitationStatus status;
  final DateTime createdAt;

  const LiveCoHostInvitationModel({
    required this.id,
    required this.roomId,
    required this.roomTitle,
    required this.inviterId,
    required this.inviterName,
    required this.inviterAvatarUrl,
    required this.recipientId,
    this.recipientName = '',
    this.status = LiveCoHostInvitationStatus.pending,
    required this.createdAt,
  });

  String get inviteeUserId => recipientId;
  String get targetUserId => recipientId;
  String get hostUserId => inviterId;
  String get hostName => inviterName;

  factory LiveCoHostInvitationModel.fromJson(Map<String, dynamic> json) {
    final inviter = json['inviter'] is Map<String, dynamic> ? json['inviter'] as Map<String, dynamic> : {};
    final inviterId = json['inviterId']?.toString() ?? inviter['id']?.toString() ?? '';
    final inviterName = json['inviterName']?.toString() ?? inviter['name']?.toString() ?? 'Host';
    final inviterAvatar = json['inviterAvatarUrl']?.toString() ?? inviter['avatarUrl']?.toString() ?? '';

    LiveCoHostInvitationStatus status = LiveCoHostInvitationStatus.pending;
    final rawStatus = (json['status']?.toString() ?? 'pending').toLowerCase();
    switch (rawStatus) {
      case 'accepted':
        status = LiveCoHostInvitationStatus.accepted;
        break;
      case 'declined':
      case 'rejected':
        status = LiveCoHostInvitationStatus.declined;
        break;
      case 'cancelled':
        status = LiveCoHostInvitationStatus.cancelled;
        break;
      case 'expired':
        status = LiveCoHostInvitationStatus.expired;
        break;
      case 'failed':
        status = LiveCoHostInvitationStatus.failed;
        break;
      case 'pending':
      default:
        status = LiveCoHostInvitationStatus.pending;
        break;
    }

    return LiveCoHostInvitationModel(
      id: json['invitationId']?.toString() ?? json['id']?.toString() ?? '',
      roomId: json['roomId']?.toString() ?? '',
      roomTitle: json['roomTitle']?.toString() ?? '',
      inviterId: inviterId,
      inviterName: inviterName,
      inviterAvatarUrl: inviterAvatar,
      recipientId: json['recipientId']?.toString() ?? json['targetUserId']?.toString() ?? '',
      recipientName: json['recipientName']?.toString() ?? '',
      status: status,
      createdAt: json['timestamp'] != null
          ? (DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'invitationId': id,
      'roomId': roomId,
      'roomTitle': roomTitle,
      'inviterId': inviterId,
      'inviterName': inviterName,
      'inviterAvatarUrl': inviterAvatarUrl,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'status': status.name,
      'timestamp': createdAt.toIso8601String(),
    };
  }
}
