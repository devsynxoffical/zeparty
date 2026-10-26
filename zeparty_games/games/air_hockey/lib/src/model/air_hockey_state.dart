/// Typed view of the server state for Neon Air Hockey. Mirrors
/// `AirHockeyState` in backend/src/games/air_hockey/engine.ts.
class AirHockeyState {
  const AirHockeyState({
    required this.rules,
    required this.table,
    required this.seats,
    required this.puck,
    required this.paddles,
    required this.clockMs,
    required this.elapsedMs,
    required this.faceoffAt,
    required this.faceoffToward,
    required this.suddenDeath,
    required this.phase,
    required this.placements,
    required this.finishReason,
    required this.version,
  });

  final AirHockeyRules rules;
  final TableSpec table;
  final List<AirHockeySeat> seats;
  final Body puck;
  final List<PaddleSnapshot> paddles;
  final int clockMs;
  final int elapsedMs;
  final int? faceoffAt;
  final int faceoffToward;
  final bool suddenDeath;
  final AirHockeyPhase phase;
  final List<int> placements;
  final String? finishReason;
  final int version;

  bool get finished => phase == AirHockeyPhase.finished;
  bool get inFaceoff => faceoffAt != null && faceoffAt! > elapsedMs;
  int get faceoffRemainingMs => faceoffAt == null ? 0 : (faceoffAt! - elapsedMs).clamp(0, 1 << 30);
  int get leaderSeat => seats[0].score == seats[1].score ? -1 : (seats[0].score > seats[1].score ? 0 : 1);
  int? get winnerSeat => finished && placements.isNotEmpty && finishReason != 'draw' ? placements.first : null;

  AirHockeySeat seatAt(int seat) => seats.firstWhere((s) => s.seat == seat);
  AirHockeySeat? seatOrNull(int? seat) => seat == null ? null : seats.where((s) => s.seat == seat).firstOrNull;

  factory AirHockeyState.fromJson(Map<String, dynamic> j) {
    final paddles = (j['paddles'] as List<dynamic>).map((p) => PaddleSnapshot.fromJson(p as Map<String, dynamic>)).toList();
    return AirHockeyState(
      rules: AirHockeyRules.fromJson((j['rules'] as Map<String, dynamic>?) ?? const {}),
      table: TableSpec.fromJson((j['table'] as Map<String, dynamic>?) ?? const {}),
      seats: (j['seats'] as List<dynamic>).map((s) => AirHockeySeat.fromJson(s as Map<String, dynamic>)).toList(),
      puck: Body.fromJson(j['puck'] as Map<String, dynamic>),
      paddles: paddles,
      clockMs: _int(j['clockMs']),
      elapsedMs: _int(j['elapsedMs']),
      faceoffAt: j['faceoffAt'] == null ? null : _int(j['faceoffAt']),
      faceoffToward: _int(j['faceoffToward']),
      suddenDeath: j['suddenDeath'] as bool? ?? false,
      phase: j['phase'] == 'finished' ? AirHockeyPhase.finished : AirHockeyPhase.playing,
      placements: ((j['placements'] as List<dynamic>?) ?? const []).map(_int).toList(),
      finishReason: j['finishReason'] as String?,
      version: _int(j['version']),
    );
  }
}

enum AirHockeyPhase { playing, finished }

class AirHockeyRules {
  const AirHockeyRules({this.goalsToWin = 7, this.matchSeconds = 180, this.suddenDeath = true, this.faceoffPauseMs = 1500});
  final int goalsToWin;
  final int matchSeconds;
  final bool suddenDeath;
  final int faceoffPauseMs;
  factory AirHockeyRules.fromJson(Map<String, dynamic> j) => AirHockeyRules(
        goalsToWin: _int(j['goalsToWin'], 7),
        matchSeconds: _int(j['matchSeconds'], 180),
        suddenDeath: j['suddenDeath'] as bool? ?? true,
        faceoffPauseMs: _int(j['faceoffPauseMs'], 1500),
      );
}

class TableSpec {
  const TableSpec({this.width = 100, this.height = 180, this.goalWidth = 36, this.puckRadius = 3, this.paddleRadius = 6});
  final double width;
  final double height;
  final double goalWidth;
  final double puckRadius;
  final double paddleRadius;
  factory TableSpec.fromJson(Map<String, dynamic> j) => TableSpec(
        width: _double(j['width'], 100),
        height: _double(j['height'], 180),
        goalWidth: _double(j['goalWidth'], 36),
        puckRadius: _double(j['puckRadius'], 3),
        paddleRadius: _double(j['paddleRadius'], 6),
      );
}

class AirHockeySeat {
  const AirHockeySeat({required this.seat, required this.userId, required this.displayName, required this.score, required this.connected, required this.forfeited});
  final int seat;
  final String userId;
  final String displayName;
  final int score;
  final bool connected;
  final bool forfeited;
  factory AirHockeySeat.fromJson(Map<String, dynamic> j) => AirHockeySeat(
        seat: _int(j['seat']),
        userId: j['userId'] as String? ?? '',
        displayName: j['displayName'] as String? ?? 'Player',
        score: _int(j['score']),
        connected: j['connected'] as bool? ?? true,
        forfeited: j['forfeited'] as bool? ?? false,
      );
}

/// Position plus velocity in table units.
class Body {
  const Body({required this.x, required this.y, required this.vx, required this.vy});
  final double x;
  final double y;
  final double vx;
  final double vy;
  factory Body.fromJson(Map<String, dynamic> j) => Body(x: _double(j['x']), y: _double(j['y']), vx: _double(j['vx']), vy: _double(j['vy']));
}

class PaddleSnapshot extends Body {
  const PaddleSnapshot({required super.x, required super.y, required super.vx, required super.vy, required this.lastAckSeq, required this.moveBudget});
  final int lastAckSeq;
  final double moveBudget;
  factory PaddleSnapshot.fromJson(Map<String, dynamic> j) => PaddleSnapshot(
        x: _double(j['x']),
        y: _double(j['y']),
        vx: _double(j['vx']),
        vy: _double(j['vy']),
        lastAckSeq: _int(j['lastAckSeq']),
        moveBudget: _double(j['moveBudget']),
      );
}

int _int(dynamic v, [int fallback = 0]) => v is int ? v : v is num ? v.round() : fallback;
double _double(dynamic v, [double fallback = 0]) => v is num ? v.toDouble() : fallback;
