enum RoomStatus {
  waiting,
  playing,
  finished;

  static RoomStatus parse(String s) => RoomStatus.values.firstWhere((e) => e.name == s, orElse: () => RoomStatus.waiting);
}

class RoomPlayer {
  const RoomPlayer({
    required this.userId,
    required this.displayName,
    required this.seat,
    required this.ready,
    required this.connected,
    this.avatarUrl,
    this.micActive = false,
    this.muted = false,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int seat;
  final bool ready;
  final bool connected;
  final bool micActive;
  final bool muted;

  factory RoomPlayer.fromJson(Map<String, dynamic> j) => RoomPlayer(
        userId: j['userId'] as String,
        displayName: j['displayName'] as String,
        avatarUrl: j['avatarUrl'] as String?,
        seat: j['seat'] as int,
        ready: j['ready'] as bool? ?? false,
        connected: j['connected'] as bool? ?? true,
        micActive: j['micActive'] as bool? ?? false,
        muted: j['muted'] as bool? ?? false,
      );

  RoomPlayer copyWith({bool? connected, bool? micActive, bool? muted, bool? ready}) => RoomPlayer(
        userId: userId,
        displayName: displayName,
        avatarUrl: avatarUrl,
        seat: seat,
        ready: ready ?? this.ready,
        connected: connected ?? this.connected,
        micActive: micActive ?? this.micActive,
        muted: muted ?? this.muted,
      );
}

class RoomState {
  const RoomState({
    required this.roomId,
    required this.gameId,
    required this.hostUserId,
    required this.isPrivate,
    required this.inviteCode,
    required this.rules,
    required this.maxPlayers,
    required this.minPlayers,
    required this.players,
    required this.spectators,
    required this.status,
    required this.matchId,
    required this.rematchVotes,
  });

  final String roomId;
  final String gameId;
  final String hostUserId;
  final bool isPrivate;
  final String? inviteCode;
  final Map<String, dynamic> rules;
  final int maxPlayers;
  final int minPlayers;
  final List<RoomPlayer> players;
  final List<String> spectators;
  final RoomStatus status;
  final String? matchId;
  final List<String> rematchVotes;

  factory RoomState.fromJson(Map<String, dynamic> j) => RoomState(
        roomId: j['roomId'] as String,
        gameId: j['gameId'] as String,
        hostUserId: j['hostUserId'] as String,
        isPrivate: j['isPrivate'] as bool? ?? false,
        inviteCode: j['inviteCode'] as String?,
        rules: (j['rules'] as Map<String, dynamic>?) ?? const {},
        maxPlayers: j['maxPlayers'] as int,
        minPlayers: j['minPlayers'] as int,
        players: (j['players'] as List<dynamic>).map((p) => RoomPlayer.fromJson(p as Map<String, dynamic>)).toList(),
        spectators: (j['spectators'] as List<dynamic>? ?? const []).cast<String>(),
        status: RoomStatus.parse(j['status'] as String),
        matchId: j['matchId'] as String?,
        rematchVotes: (j['rematchVotes'] as List<dynamic>? ?? const []).cast<String>(),
      );

  RoomPlayer? playerById(String userId) {
    for (final p in players) {
      if (p.userId == userId) return p;
    }
    return null;
  }

  RoomPlayer? playerBySeat(int seat) {
    for (final p in players) {
      if (p.seat == seat) return p;
    }
    return null;
  }

  RoomState withPlayers(List<RoomPlayer> next) => RoomState(
        roomId: roomId,
        gameId: gameId,
        hostUserId: hostUserId,
        isPrivate: isPrivate,
        inviteCode: inviteCode,
        rules: rules,
        maxPlayers: maxPlayers,
        minPlayers: minPlayers,
        players: next,
        spectators: spectators,
        status: status,
        matchId: matchId,
        rematchVotes: rematchVotes,
      );
}

class RoomSummary {
  const RoomSummary({required this.roomId, required this.gameId, required this.hostUserId, required this.playerCount, required this.maxPlayers});
  final String roomId;
  final String gameId;
  final String hostUserId;
  final int playerCount;
  final int maxPlayers;
  factory RoomSummary.fromJson(Map<String, dynamic> j) => RoomSummary(
        roomId: j['roomId'] as String,
        gameId: j['gameId'] as String,
        hostUserId: j['hostUserId'] as String,
        playerCount: j['playerCount'] as int,
        maxPlayers: j['maxPlayers'] as int,
      );
}

/// A server event with its sequence number, used for ordered replay.
class SequencedEvent {
  const SequencedEvent({required this.seq, required this.at, required this.actorSeat, required this.type, required this.seat, required this.payload});
  final int seq;
  final int at;
  final int? actorSeat;
  final String type;
  final int? seat;
  final Map<String, dynamic> payload;

  factory SequencedEvent.fromJson(Map<String, dynamic> j) {
    final ev = j['event'] as Map<String, dynamic>;
    return SequencedEvent(
      seq: j['seq'] as int,
      at: j['at'] as int,
      actorSeat: j['actorSeat'] as int?,
      type: ev['type'] as String,
      seat: ev['seat'] as int?,
      payload: (ev['payload'] as Map<String, dynamic>?) ?? const {},
    );
  }
}

class MatchPlacement {
  const MatchPlacement({required this.seat, required this.userId, required this.placement, required this.score});
  final int seat;
  final String userId;
  final int placement;
  final int score;
  factory MatchPlacement.fromJson(Map<String, dynamic> j) =>
      MatchPlacement(seat: j['seat'] as int, userId: j['userId'] as String, placement: j['placement'] as int, score: j['score'] as int);
}

class MatchResult {
  const MatchResult({required this.roomId, required this.matchId, required this.placements, required this.winnerIds, required this.rewards});
  final String roomId;
  final String matchId;
  final List<MatchPlacement> placements;
  final List<String> winnerIds;
  final Map<String, int> rewards;
  factory MatchResult.fromJson(Map<String, dynamic> j) => MatchResult(
        roomId: j['roomId'] as String,
        matchId: j['matchId'] as String,
        placements: (j['placements'] as List<dynamic>).map((p) => MatchPlacement.fromJson(p as Map<String, dynamic>)).toList(),
        winnerIds: (j['winnerIds'] as List<dynamic>).cast<String>(),
        rewards: ((j['rewards'] as Map<String, dynamic>?) ?? const {}).map((k, v) => MapEntry(k, v as int)),
      );
}
