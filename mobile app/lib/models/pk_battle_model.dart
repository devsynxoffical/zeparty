import 'user_model.dart';

class PKParticipantModel {
  final String userId;
  final String name;
  final String username;
  final String avatarUrl;
  final String? roomId;
  final int slot;
  final bool isHost;
  final bool isInitiator;
  final int score;
  final String status;

  const PKParticipantModel({
    required this.userId,
    required this.name,
    this.username = '',
    this.avatarUrl = '',
    this.roomId,
    this.slot = 1,
    this.isHost = false,
    this.isInitiator = false,
    this.score = 0,
    this.status = 'READY',
  });

  factory PKParticipantModel.fromJson(Map<String, dynamic> json) {
    return PKParticipantModel(
      userId: json['userId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['displayName']?.toString() ?? json['username']?.toString() ?? 'Participant',
      username: json['username']?.toString() ?? 'user',
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      roomId: json['roomId']?.toString(),
      slot: json['slot'] is int ? json['slot'] as int : int.tryParse(json['slot']?.toString() ?? '1') ?? 1,
      isHost: json['isHost'] == true,
      isInitiator: json['isInitiator'] == true,
      score: json['score'] is int ? json['score'] as int : int.tryParse(json['score']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? 'READY',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'username': username,
      'avatarUrl': avatarUrl,
      'roomId': roomId,
      'slot': slot,
      'isHost': isHost,
      'isInitiator': isInitiator,
      'score': score,
      'status': status,
    };
  }

  UserModel toUserModel() {
    return UserModel(
      id: userId,
      name: name,
      username: username.isNotEmpty ? username : 'user_$userId',
      avatarUrl: avatarUrl,
    );
  }

  PKParticipantModel copyWith({
    String? userId,
    String? name,
    String? username,
    String? avatarUrl,
    String? roomId,
    int? slot,
    bool? isHost,
    bool? isInitiator,
    int? score,
    String? status,
  }) {
    return PKParticipantModel(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      roomId: roomId ?? this.roomId,
      slot: slot ?? this.slot,
      isHost: isHost ?? this.isHost,
      isInitiator: isInitiator ?? this.isInitiator,
      score: score ?? this.score,
      status: status ?? this.status,
    );
  }
}

class PKBattleModel {
  final String id;
  final String initiatorUserId;
  final String roomAId;
  final String roomBId;
  final List<PKParticipantModel> participants;
  final int durationSeconds;
  final String status; // 'CREATED', 'INVITING', 'READY', 'STARTED', 'ACTIVE', 'ENDED', 'CANCELLED'
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? inviteCode;
  final String? winnerId;
  final String? winnerName;

  PKBattleModel({
    required this.id,
    this.initiatorUserId = '',
    this.roomAId = '',
    this.roomBId = '',
    List<PKParticipantModel>? participants,
    int? durationSeconds,
    this.status = 'READY',
    this.startedAt,
    this.endedAt,
    this.inviteCode,
    this.winnerId,
    this.winnerName,
    UserModel? hostA,
    UserModel? hostB,
    int? scoreA,
    int? scoreB,
    Duration? remainingTime,
  })  : durationSeconds = durationSeconds ?? (remainingTime != null ? remainingTime.inSeconds : 300),
        participants = participants ??
            [
              if (hostA != null)
                PKParticipantModel(
                  userId: hostA.id,
                  name: hostA.name,
                  username: hostA.username,
                  avatarUrl: hostA.avatarUrl,
                  slot: 1,
                  isHost: true,
                  isInitiator: true,
                  score: scoreA ?? 0,
                  status: 'READY',
                ),
              if (hostB != null)
                PKParticipantModel(
                  userId: hostB.id,
                  name: hostB.name,
                  username: hostB.username,
                  avatarUrl: hostB.avatarUrl,
                  slot: 2,
                  isHost: true,
                  isInitiator: false,
                  score: scoreB ?? 0,
                  status: 'READY',
                ),
            ];

  factory PKBattleModel.fromJson(Map<String, dynamic> json) {
    final pkId = json['pkId']?.toString() ?? json['id']?.toString() ?? '';
    final statusStr = json['status']?.toString() ?? 'READY';
    final duration = json['durationSeconds'] is int ? json['durationSeconds'] as int : 300;

    List<PKParticipantModel> participantsList = [];
    if (json['participants'] is List) {
      participantsList = (json['participants'] as List)
          .map((p) => PKParticipantModel.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList();
    } else {
      // Fallback for 2-host legacy format
      final rawHostA = json['hostA'] ?? json['roomA']?['creator'];
      final rawHostB = json['hostB'] ?? json['roomB']?['creator'];
      final scoreANum = json['hostAScore'] != null ? int.tryParse(json['hostAScore'].toString()) ?? 0 : (json['scoreA'] ?? 0);
      final scoreBNum = json['hostBScore'] != null ? int.tryParse(json['hostBScore'].toString()) ?? 0 : (json['scoreB'] ?? 0);

      if (rawHostA != null && rawHostA is Map) {
        participantsList.add(PKParticipantModel(
          userId: rawHostA['id']?.toString() ?? rawHostA['userId']?.toString() ?? 'host_blue',
          name: rawHostA['name']?.toString() ?? rawHostA['displayName']?.toString() ?? 'Host Blue',
          username: rawHostA['username']?.toString() ?? 'host_blue',
          avatarUrl: rawHostA['avatarUrl']?.toString() ?? '',
          roomId: json['roomAId']?.toString(),
          slot: 1,
          isHost: true,
          isInitiator: true,
          score: scoreANum is int ? scoreANum : 0,
          status: 'READY',
        ));
      }
      if (rawHostB != null && rawHostB is Map) {
        participantsList.add(PKParticipantModel(
          userId: rawHostB['id']?.toString() ?? rawHostB['userId']?.toString() ?? 'host_red',
          name: rawHostB['name']?.toString() ?? rawHostB['displayName']?.toString() ?? 'Host Red',
          username: rawHostB['username']?.toString() ?? 'host_red',
          avatarUrl: rawHostB['avatarUrl']?.toString() ?? '',
          roomId: json['roomBId']?.toString(),
          slot: 2,
          isHost: true,
          isInitiator: false,
          score: scoreBNum is int ? scoreBNum : 0,
          status: 'READY',
        ));
      }
    }

    DateTime? parsedStartedAt;
    if (json['startedAt'] != null) {
      parsedStartedAt = DateTime.tryParse(json['startedAt'].toString());
    }

    DateTime? parsedEndedAt;
    if (json['endedAt'] != null) {
      parsedEndedAt = DateTime.tryParse(json['endedAt'].toString());
    }

    return PKBattleModel(
      id: pkId,
      initiatorUserId: json['initiatorUserId']?.toString() ?? (participantsList.isNotEmpty ? participantsList[0].userId : ''),
      roomAId: json['roomAId']?.toString() ?? json['primaryRoomId']?.toString() ?? '',
      roomBId: json['roomBId']?.toString() ?? '',
      participants: participantsList,
      durationSeconds: duration,
      status: statusStr,
      startedAt: parsedStartedAt,
      endedAt: parsedEndedAt,
      inviteCode: json['inviteCode']?.toString(),
      winnerId: json['winnerUserId']?.toString() ?? json['winnerHostUserId']?.toString(),
      winnerName: json['winnerName']?.toString(),
    );
  }

  // ── Backward-compatible getters for 2-player layouts ──
  UserModel get hostA => participants.isNotEmpty
      ? participants[0].toUserModel()
      : const UserModel(id: 'host_blue', username: 'host_blue', name: 'Host Blue', avatarUrl: '');

  UserModel get hostB => participants.length > 1
      ? participants[1].toUserModel()
      : const UserModel(id: 'host_red', username: 'host_red', name: 'Opponent', avatarUrl: '');

  int get scoreA => participants.isNotEmpty ? participants[0].score : 0;
  int get scoreB => participants.length > 1 ? participants[1].score : 0;

  int get participantCount => participants.length;
  int get totalParticipants => participants.length;
  List<PKParticipantModel> get participantList => participants;
  bool get isReady => status == 'READY' || status == 'STARTED' || status == 'ACTIVE';
  bool get isStarted => status == 'STARTED' || status == 'ACTIVE';
  bool get isEnded => status == 'ENDED' || status == 'CANCELLED';

  /// Calculates authoritative remaining seconds based on server startedAt
  int calculateRemainingSeconds() {
    if (!isStarted || startedAt == null) {
      return durationSeconds;
    }
    if (isEnded) {
      return 0;
    }
    final elapsed = DateTime.now().difference(startedAt!).inSeconds;
    final remaining = durationSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  Duration get remainingTime => Duration(seconds: calculateRemainingSeconds());

  PKBattleModel copyWith({
    String? id,
    String? initiatorUserId,
    String? roomAId,
    String? roomBId,
    List<PKParticipantModel>? participants,
    int? durationSeconds,
    String? status,
    DateTime? startedAt,
    DateTime? endedAt,
    String? inviteCode,
    String? winnerId,
    String? winnerName,
    int? scoreA,
    int? scoreB,
    bool? isEnded,
  }) {
    List<PKParticipantModel> updatedParticipants = participants ?? this.participants;

    if (scoreA != null && updatedParticipants.isNotEmpty) {
      updatedParticipants = List<PKParticipantModel>.from(updatedParticipants);
      updatedParticipants[0] = updatedParticipants[0].copyWith(score: scoreA);
    }
    if (scoreB != null && updatedParticipants.length > 1) {
      updatedParticipants = List<PKParticipantModel>.from(updatedParticipants);
      updatedParticipants[1] = updatedParticipants[1].copyWith(score: scoreB);
    }

    return PKBattleModel(
      id: id ?? this.id,
      initiatorUserId: initiatorUserId ?? this.initiatorUserId,
      roomAId: roomAId ?? this.roomAId,
      roomBId: roomBId ?? this.roomBId,
      participants: updatedParticipants,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      status: (isEnded == true) ? 'ENDED' : (status ?? this.status),
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      inviteCode: inviteCode ?? this.inviteCode,
      winnerId: winnerId ?? this.winnerId,
      winnerName: winnerName ?? this.winnerName,
    );
  }
}
