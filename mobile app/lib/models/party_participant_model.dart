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
  final bool isOnline;
  final bool inRoom;
  final bool isMutedByModerator;

  const PartyParticipantModel({
    required this.user,
    this.role = ParticipantRole.listener,
    this.seatNumber,
    this.micStatus = MicStatus.muted,
    required this.joinedAt,
    this.isSpeaking = false,
    this.isOnline = true,
    this.inRoom = true,
    this.isMutedByModerator = false,
  });

  bool get isMuted => micStatus == MicStatus.muted;

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
    final isMutedByModerator = json['isMutedByModerator'] == true ||
        (isMuted && json['moderatedByUserId'] != null);

    return PartyParticipantModel(
      user: user,
      role: index == 0 ? ParticipantRole.host : ParticipantRole.speaker,
      seatNumber: index,
      micStatus: isLocked ? MicStatus.locked : (isMuted ? MicStatus.muted : MicStatus.on),
      joinedAt: DateTime.now(),
      isSpeaking: false,
      isOnline: true,
      inRoom: true,
      isMutedByModerator: isMutedByModerator,
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
    if (roleStr == 'MODERATOR' || roleStr == 'ADMIN') role = ParticipantRole.moderator;
    if (roleStr == 'SPEAKER') role = ParticipantRole.speaker;

    final isOnline = json['isOnline'] is bool
        ? json['isOnline'] as bool
        : (json['isOnline'] != null ? json['isOnline'].toString().toLowerCase() == 'true' : true);
    final inRoom = json['inRoom'] is bool
        ? json['inRoom'] as bool
        : (json['inRoom'] != null ? json['inRoom'].toString().toLowerCase() == 'true' : isOnline);
    final isMutedByModerator = json['isMutedByModerator'] == true;

    return PartyParticipantModel(
      user: user,
      role: role,
      seatNumber: json['seatIndex'] is int ? json['seatIndex'] as int : null,
      micStatus: MicStatus.muted,
      joinedAt: json['joinedAt'] != null ? (DateTime.tryParse(json['joinedAt'].toString()) ?? DateTime.now()) : DateTime.now(),
      isSpeaking: false,
      isOnline: isOnline,
      inRoom: inRoom,
      isMutedByModerator: isMutedByModerator,
    );
  }

  static const Object _unset = Object();

  PartyParticipantModel copyWith({
    UserModel? user,
    ParticipantRole? role,
    dynamic seatNumber = _unset,
    MicStatus? micStatus,
    DateTime? joinedAt,
    bool? isSpeaking,
    bool? isOnline,
    bool? inRoom,
    bool? isMutedByModerator,
    bool clearSeat = false,
  }) {
    int? resolvedSeatNumber;
    if (clearSeat) {
      resolvedSeatNumber = null;
    } else if (identical(seatNumber, _unset)) {
      resolvedSeatNumber = this.seatNumber;
    } else {
      resolvedSeatNumber = seatNumber as int?;
    }

    return PartyParticipantModel(
      user: user ?? this.user,
      role: role ?? this.role,
      seatNumber: resolvedSeatNumber,
      micStatus: micStatus ?? this.micStatus,
      joinedAt: joinedAt ?? this.joinedAt,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isOnline: isOnline ?? this.isOnline,
      inRoom: inRoom ?? this.inRoom,
      isMutedByModerator: isMutedByModerator ?? this.isMutedByModerator,
    );
  }
}
