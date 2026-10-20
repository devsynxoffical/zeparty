import 'user_model.dart';

class PKSupporterModel {
  final int rank;
  final String userId;
  final String displayName;
  final String avatarUrl;
  final int totalCoins;

  const PKSupporterModel({
    required this.rank,
    required this.userId,
    required this.displayName,
    this.avatarUrl = '',
    this.totalCoins = 0,
  });

  factory PKSupporterModel.fromJson(Map<String, dynamic> json) {
    return PKSupporterModel(
      rank: json['rank'] is int ? json['rank'] as int : int.tryParse(json['rank']?.toString() ?? '0') ?? 0,
      userId: json['userId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? json['username']?.toString() ?? 'Supporter',
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      totalCoins: json['totalCoins'] is int
          ? json['totalCoins'] as int
          : int.tryParse(json['totalCoins']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'userId': userId,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'totalCoins': totalCoins,
    };
  }
}

class PKSideModel {
  final String roomId;
  final String roomTitle;
  final String hostId;
  final String? numericId;
  final String displayName;
  final String avatarUrl;
  final int score;
  final String connectionStatus; // 'CONNECTED', 'RECONNECTING', 'OFFLINE'
  final bool ready;
  final bool mediaPrepared;

  const PKSideModel({
    required this.roomId,
    this.roomTitle = '',
    required this.hostId,
    this.numericId,
    required this.displayName,
    this.avatarUrl = '',
    this.score = 0,
    this.connectionStatus = 'CONNECTED',
    this.ready = false,
    this.mediaPrepared = false,
  });

  factory PKSideModel.fromJson(Map<String, dynamic> json) {
    return PKSideModel(
      roomId: json['roomId']?.toString() ?? '',
      roomTitle: json['roomTitle']?.toString() ?? '',
      hostId: json['hostId']?.toString() ?? '',
      numericId: json['numericId']?.toString(),
      displayName: json['displayName']?.toString() ?? json['name']?.toString() ?? 'Host',
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      score: json['score'] is int
          ? json['score'] as int
          : int.tryParse(json['score']?.toString() ?? '0') ?? 0,
      connectionStatus: json['connectionStatus']?.toString() ?? 'CONNECTED',
      ready: json['ready'] == true,
      mediaPrepared: json['mediaPrepared'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roomId': roomId,
      'roomTitle': roomTitle,
      'hostId': hostId,
      if (numericId != null) 'numericId': numericId,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'score': score,
      'connectionStatus': connectionStatus,
      'ready': ready,
      'mediaPrepared': mediaPrepared,
    };
  }

  UserModel toUserModel() {
    return UserModel(
      id: hostId,
      name: displayName,
      username: displayName,
      avatarUrl: avatarUrl,
    );
  }

  PKSideModel copyWith({
    String? roomId,
    String? roomTitle,
    String? hostId,
    String? numericId,
    String? displayName,
    String? avatarUrl,
    int? score,
    String? connectionStatus,
    bool? ready,
    bool? mediaPrepared,
  }) {
    return PKSideModel(
      roomId: roomId ?? this.roomId,
      roomTitle: roomTitle ?? this.roomTitle,
      hostId: hostId ?? this.hostId,
      numericId: numericId ?? this.numericId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      score: score ?? this.score,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      ready: ready ?? this.ready,
      mediaPrepared: mediaPrepared ?? this.mediaPrepared,
    );
  }
}

class PKAgoraRelayModel {
  final String channelA;
  final String channelB;
  final int hostAUid;
  final int hostBUid;

  const PKAgoraRelayModel({
    required this.channelA,
    required this.channelB,
    required this.hostAUid,
    required this.hostBUid,
  });

  factory PKAgoraRelayModel.fromJson(Map<String, dynamic> json) {
    return PKAgoraRelayModel(
      channelA: json['channelA']?.toString() ?? '',
      channelB: json['channelB']?.toString() ?? '',
      hostAUid: json['hostAUid'] is int ? json['hostAUid'] as int : int.tryParse(json['hostAUid']?.toString() ?? '0') ?? 0,
      hostBUid: json['hostBUid'] is int ? json['hostBUid'] as int : int.tryParse(json['hostBUid']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'channelA': channelA,
      'channelB': channelB,
      'hostAUid': hostAUid,
      'hostBUid': hostBUid,
    };
  }
}

class PKDiscoveryResult {
  final String roomId;
  final String roomTitle;
  final String roomType;
  final String region;
  final String hostId;
  final String hostUsername;
  final String hostDisplayName;
  final String hostAvatarUrl;
  final String? numericId;
  final bool isOnline;

  const PKDiscoveryResult({
    required this.roomId,
    required this.roomTitle,
    required this.roomType,
    required this.region,
    required this.hostId,
    required this.hostUsername,
    required this.hostDisplayName,
    this.hostAvatarUrl = '',
    this.numericId,
    this.isOnline = true,
  });

  factory PKDiscoveryResult.fromJson(Map<String, dynamic> json) {
    final hostMap = json['host'] as Map<String, dynamic>? ?? {};
    return PKDiscoveryResult(
      roomId: json['roomId']?.toString() ?? '',
      roomTitle: json['roomTitle']?.toString() ?? '',
      roomType: json['roomType']?.toString() ?? 'AUDIO',
      region: json['region']?.toString() ?? 'GLOBAL',
      hostId: hostMap['id']?.toString() ?? '',
      hostUsername: hostMap['username']?.toString() ?? '',
      hostDisplayName: hostMap['displayName']?.toString() ?? hostMap['username']?.toString() ?? 'Host',
      hostAvatarUrl: hostMap['avatarUrl']?.toString() ?? '',
      numericId: hostMap['numericId']?.toString(),
      isOnline: json['isOnline'] == true,
    );
  }
}

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
  final int remainingSeconds;
  final String status; // 'PENDING', 'PREPARING', 'COUNTDOWN', 'ACTIVE', 'FINISHED', 'FORFEIT', 'ABORTED', 'CANCELLED', 'EXPIRED', 'READY', 'STARTED', 'ENDED'
  final int stateVersion;
  final String roomType; // 'AUDIO', 'VIDEO'
  final String region;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? inviteCode;
  final String? winnerId;
  final String? winnerName;
  final bool isDraw;
  final String? endReason;
  final PKSideModel? sideA;
  final PKSideModel? sideB;
  final List<PKSupporterModel> topSupportersA;
  final List<PKSupporterModel> topSupportersB;
  final PKAgoraRelayModel? agoraRelay;

  PKBattleModel({
    required this.id,
    this.initiatorUserId = '',
    this.roomAId = '',
    this.roomBId = '',
    List<PKParticipantModel>? participants,
    int? durationSeconds,
    int? remainingSeconds,
    this.status = 'READY',
    this.stateVersion = 1,
    this.roomType = 'AUDIO',
    this.region = 'GLOBAL',
    this.startedAt,
    this.endedAt,
    this.inviteCode,
    this.winnerId,
    this.winnerName,
    this.isDraw = false,
    this.endReason,
    this.sideA,
    this.sideB,
    this.topSupportersA = const [],
    this.topSupportersB = const [],
    this.agoraRelay,
    UserModel? hostA,
    UserModel? hostB,
    int? scoreA,
    int? scoreB,
  })  : durationSeconds = durationSeconds ?? 300,
        remainingSeconds = remainingSeconds ?? (durationSeconds ?? 300),
        participants = participants ??
            [
              if (sideA != null)
                PKParticipantModel(
                  userId: sideA.hostId,
                  name: sideA.displayName,
                  username: sideA.displayName,
                  avatarUrl: sideA.avatarUrl,
                  roomId: sideA.roomId,
                  slot: 1,
                  isHost: true,
                  isInitiator: true,
                  score: sideA.score,
                  status: 'READY',
                )
              else if (hostA != null)
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
              if (sideB != null)
                PKParticipantModel(
                  userId: sideB.hostId,
                  name: sideB.displayName,
                  username: sideB.displayName,
                  avatarUrl: sideB.avatarUrl,
                  roomId: sideB.roomId,
                  slot: 2,
                  isHost: true,
                  isInitiator: false,
                  score: sideB.score,
                  status: 'READY',
                )
              else if (hostB != null)
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
    final pkId = json['matchId']?.toString() ?? json['pkId']?.toString() ?? json['id']?.toString() ?? '';
    final statusStr = (json['status']?.toString() ?? 'READY').toUpperCase();
    final duration = json['durationSeconds'] is int ? json['durationSeconds'] as int : int.tryParse(json['durationSeconds']?.toString() ?? '300') ?? 300;
    final remaining = json['remainingSeconds'] is int
        ? json['remainingSeconds'] as int
        : int.tryParse(json['remainingSeconds']?.toString() ?? duration.toString()) ?? duration;
    final stateVer = json['stateVersion'] is int ? json['stateVersion'] as int : int.tryParse(json['stateVersion']?.toString() ?? '1') ?? 1;

    PKSideModel? parsedSideA;
    if (json['sideA'] is Map) {
      parsedSideA = PKSideModel.fromJson(Map<String, dynamic>.from(json['sideA'] as Map));
    }

    PKSideModel? parsedSideB;
    if (json['sideB'] is Map) {
      parsedSideB = PKSideModel.fromJson(Map<String, dynamic>.from(json['sideB'] as Map));
    }

    List<PKSupporterModel> parsedSupportersA = [];
    if (json['topSupportersA'] is List) {
      parsedSupportersA = (json['topSupportersA'] as List)
          .map((s) => PKSupporterModel.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList();
    }

    List<PKSupporterModel> parsedSupportersB = [];
    if (json['topSupportersB'] is List) {
      parsedSupportersB = (json['topSupportersB'] as List)
          .map((s) => PKSupporterModel.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList();
    }

    PKAgoraRelayModel? parsedRelay;
    if (json['agoraRelay'] is Map) {
      parsedRelay = PKAgoraRelayModel.fromJson(Map<String, dynamic>.from(json['agoraRelay'] as Map));
    }

    List<PKParticipantModel> participantsList = [];
    if (json['participants'] is List) {
      participantsList = (json['participants'] as List)
          .map((p) => PKParticipantModel.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList();
    } else {
      final rawHostA = json['hostA'] ?? json['roomA']?['creator'];
      final rawHostB = json['hostB'] ?? json['roomB']?['creator'];
      final scoreANum = json['hostAScore'] != null
          ? int.tryParse(json['hostAScore'].toString()) ?? 0
          : (json['scoreA'] != null ? int.tryParse(json['scoreA'].toString()) ?? 0 : parsedSideA?.score ?? 0);
      final scoreBNum = json['hostBScore'] != null
          ? int.tryParse(json['hostBScore'].toString()) ?? 0
          : (json['scoreB'] != null ? int.tryParse(json['scoreB'].toString()) ?? 0 : parsedSideB?.score ?? 0);

      if (parsedSideA != null) {
        participantsList.add(PKParticipantModel(
          userId: parsedSideA.hostId,
          name: parsedSideA.displayName,
          username: parsedSideA.displayName,
          avatarUrl: parsedSideA.avatarUrl,
          roomId: parsedSideA.roomId,
          slot: 1,
          isHost: true,
          isInitiator: true,
          score: scoreANum,
          status: parsedSideA.ready ? 'READY' : 'PREPARING',
        ));
      } else if (rawHostA != null && rawHostA is Map) {
        participantsList.add(PKParticipantModel(
          userId: rawHostA['id']?.toString() ?? rawHostA['userId']?.toString() ?? 'host_blue',
          name: rawHostA['name']?.toString() ?? rawHostA['displayName']?.toString() ?? 'Host Blue',
          username: rawHostA['username']?.toString() ?? 'host_blue',
          avatarUrl: rawHostA['avatarUrl']?.toString() ?? '',
          roomId: json['roomAId']?.toString(),
          slot: 1,
          isHost: true,
          isInitiator: true,
          score: scoreANum,
          status: 'READY',
        ));
      }

      if (parsedSideB != null) {
        participantsList.add(PKParticipantModel(
          userId: parsedSideB.hostId,
          name: parsedSideB.displayName,
          username: parsedSideB.displayName,
          avatarUrl: parsedSideB.avatarUrl,
          roomId: parsedSideB.roomId,
          slot: 2,
          isHost: true,
          isInitiator: false,
          score: scoreBNum,
          status: parsedSideB.ready ? 'READY' : 'PREPARING',
        ));
      } else if (rawHostB != null && rawHostB is Map) {
        participantsList.add(PKParticipantModel(
          userId: rawHostB['id']?.toString() ?? rawHostB['userId']?.toString() ?? 'host_red',
          name: rawHostB['name']?.toString() ?? rawHostB['displayName']?.toString() ?? 'Host Red',
          username: rawHostB['username']?.toString() ?? 'host_red',
          avatarUrl: rawHostB['avatarUrl']?.toString() ?? '',
          roomId: json['roomBId']?.toString(),
          slot: 2,
          isHost: true,
          isInitiator: false,
          score: scoreBNum,
          status: 'READY',
        ));
      }
    }

    DateTime? parsedStartedAt;
    if (json['startAt'] != null || json['startedAt'] != null) {
      parsedStartedAt = DateTime.tryParse((json['startAt'] ?? json['startedAt']).toString());
    }

    DateTime? parsedEndedAt;
    if (json['endAt'] != null || json['endedAt'] != null) {
      parsedEndedAt = DateTime.tryParse((json['endAt'] ?? json['endedAt']).toString());
    }

    final winnerIdVal = json['winnerHostId']?.toString() ?? json['winnerUserId']?.toString() ?? json['winnerHostUserId']?.toString();

    return PKBattleModel(
      id: pkId,
      initiatorUserId: json['initiatorUserId']?.toString() ?? (participantsList.isNotEmpty ? participantsList[0].userId : ''),
      roomAId: json['roomAId']?.toString() ?? json['sideA']?['roomId']?.toString() ?? '',
      roomBId: json['roomBId']?.toString() ?? json['sideB']?['roomId']?.toString() ?? '',
      participants: participantsList,
      durationSeconds: duration,
      remainingSeconds: remaining,
      status: statusStr,
      stateVersion: stateVer,
      roomType: json['roomType']?.toString() ?? 'AUDIO',
      region: json['region']?.toString() ?? 'GLOBAL',
      startedAt: parsedStartedAt,
      endedAt: parsedEndedAt,
      inviteCode: json['inviteCode']?.toString(),
      winnerId: winnerIdVal,
      winnerName: json['winnerName']?.toString(),
      isDraw: json['isDraw'] == true,
      endReason: json['endReason']?.toString(),
      sideA: parsedSideA,
      sideB: parsedSideB,
      topSupportersA: parsedSupportersA,
      topSupportersB: parsedSupportersB,
      agoraRelay: parsedRelay,
    );
  }

  // ── Authoritative Getters ──
  UserModel get hostA => sideA != null
      ? sideA!.toUserModel()
      : (participants.isNotEmpty
          ? participants[0].toUserModel()
          : const UserModel(id: 'host_blue', username: 'host_blue', name: 'Host Blue', avatarUrl: ''));

  UserModel get hostB => sideB != null
      ? sideB!.toUserModel()
      : (participants.length > 1
          ? participants[1].toUserModel()
          : const UserModel(id: 'host_red', username: 'host_red', name: 'Host Red', avatarUrl: ''));

  int get scoreA => sideA?.score ?? (participants.isNotEmpty ? participants[0].score : 0);
  int get scoreB => sideB?.score ?? (participants.length > 1 ? participants[1].score : 0);

  int get participantCount => participants.length;
  int get totalParticipants => participants.length;
  List<PKParticipantModel> get participantList => participants;

  bool get isPreparing => status == 'PREPARING';
  bool get isCountdown => status == 'COUNTDOWN';
  bool get isReady => status == 'READY' || status == 'STARTED' || status == 'ACTIVE' || status == 'COUNTDOWN';
  bool get isStarted => status == 'STARTED' || status == 'ACTIVE';
  bool get isEnded => const ['FINISHED', 'FORFEIT', 'ABORTED', 'CANCELLED', 'EXPIRED', 'ENDED'].contains(status);

  String get hostAConnectionStatus => sideA?.connectionStatus ?? 'CONNECTED';
  String get hostBConnectionStatus => sideB?.connectionStatus ?? 'CONNECTED';

  /// Calculates authoritative remaining seconds based on server startedAt or remainingSeconds
  int calculateRemainingSeconds() {
    if (isEnded) return 0;
    if (!isStarted || startedAt == null) return durationSeconds;
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
    int? remainingSeconds,
    String? status,
    int? stateVersion,
    String? roomType,
    String? region,
    DateTime? startedAt,
    DateTime? endedAt,
    String? inviteCode,
    String? winnerId,
    String? winnerName,
    bool? isDraw,
    String? endReason,
    PKSideModel? sideA,
    PKSideModel? sideB,
    List<PKSupporterModel>? topSupportersA,
    List<PKSupporterModel>? topSupportersB,
    PKAgoraRelayModel? agoraRelay,
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

    PKSideModel? updatedSideA = sideA ?? this.sideA;
    if (scoreA != null && updatedSideA != null) {
      updatedSideA = updatedSideA.copyWith(score: scoreA);
    }

    PKSideModel? updatedSideB = sideB ?? this.sideB;
    if (scoreB != null && updatedSideB != null) {
      updatedSideB = updatedSideB.copyWith(score: scoreB);
    }

    return PKBattleModel(
      id: id ?? this.id,
      initiatorUserId: initiatorUserId ?? this.initiatorUserId,
      roomAId: roomAId ?? this.roomAId,
      roomBId: roomBId ?? this.roomBId,
      participants: updatedParticipants,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      status: (isEnded == true) ? 'FINISHED' : (status ?? this.status),
      stateVersion: stateVersion ?? this.stateVersion,
      roomType: roomType ?? this.roomType,
      region: region ?? this.region,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      inviteCode: inviteCode ?? this.inviteCode,
      winnerId: winnerId ?? this.winnerId,
      winnerName: winnerName ?? this.winnerName,
      isDraw: isDraw ?? this.isDraw,
      endReason: endReason ?? this.endReason,
      sideA: updatedSideA,
      sideB: updatedSideB,
      topSupportersA: topSupportersA ?? this.topSupportersA,
      topSupportersB: topSupportersB ?? this.topSupportersB,
      agoraRelay: agoraRelay ?? this.agoraRelay,
    );
  }
}
