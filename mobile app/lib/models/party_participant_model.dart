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
