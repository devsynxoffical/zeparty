import 'user_model.dart';

enum ParticipantRole { host, moderator, speaker, listener }
enum MicStatus { on, muted, locked }

class PartyParticipantModel {
  final UserModel user;
  final ParticipantRole role;
  final int? seatNumber;
  final MicStatus micStatus;
  final DateTime joinedAt;
  final bool isSpeaking; // Managed by Agora active speaker callback

  const PartyParticipantModel({
    required this.user,
    this.role = ParticipantRole.listener,
    this.seatNumber,
    this.micStatus = MicStatus.muted,
    required this.joinedAt,
    this.isSpeaking = false,
  });

  factory PartyParticipantModel.fromRoomSeatJson(Map<String, dynamic> json, int index) {
    final userData = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : (json['occupiedUser'] is Map ? Map<String, dynamic>.from(json['occupiedUser'] as Map) : <String, dynamic>{});

    final user = userData.isNotEmpty
        ? UserModel.fromJson(userData)
        : UserModel(
            id: json['userId']?.toString() ?? json['occupiedUserId']?.toString() ?? 'seat_user_$index',
            username: 'speaker_$index',
            name: 'Speaker ${index + 1}',
            avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=300&q=80',
          );

    final isMuted = json['isMuted'] == true;
    final isLocked = json['isLocked'] == true;

    return PartyParticipantModel(
      user: user,
      role: index == 0 ? ParticipantRole.host : ParticipantRole.speaker,
      seatNumber: index,
      micStatus: isLocked ? MicStatus.locked : (isMuted ? MicStatus.muted : MicStatus.on),
      joinedAt: DateTime.now(),
      isSpeaking: false,
    );
  }

  factory PartyParticipantModel.fromMemberJson(Map<String, dynamic> json) {
    final userData = json['user'] is Map ? Map<String, dynamic>.from(json['user'] as Map) : <String, dynamic>{};
    final user = userData.isNotEmpty
        ? UserModel.fromJson(userData)
        : UserModel(
            id: json['userId']?.toString() ?? 'member_unknown',
            username: 'viewer',
            name: 'Viewer',
            avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
          );

    final roleStr = json['role']?.toString().toUpperCase() ?? 'LISTENER';
    ParticipantRole role = ParticipantRole.listener;
    if (roleStr == 'HOST') role = ParticipantRole.host;
    if (roleStr == 'MODERATOR') role = ParticipantRole.moderator;
    if (roleStr == 'SPEAKER') role = ParticipantRole.speaker;

    return PartyParticipantModel(
      user: user,
      role: role,
      seatNumber: json['seatIndex'] is int ? json['seatIndex'] as int : null,
      micStatus: MicStatus.muted,
      joinedAt: json['joinedAt'] != null ? (DateTime.tryParse(json['joinedAt'].toString()) ?? DateTime.now()) : DateTime.now(),
      isSpeaking: false,
    );
  }

  PartyParticipantModel copyWith({
    UserModel? user,
    ParticipantRole? role,
    int? seatNumber,
    MicStatus? micStatus,
    DateTime? joinedAt,
    bool? isSpeaking,
  }) {
    return PartyParticipantModel(
      user: user ?? this.user,
      role: role ?? this.role,
      seatNumber: seatNumber ?? this.seatNumber,
      micStatus: micStatus ?? this.micStatus,
      joinedAt: joinedAt ?? this.joinedAt,
      isSpeaking: isSpeaking ?? this.isSpeaking,
    );
  }
}
