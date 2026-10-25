import 'course.dart';
import 'rules.dart';

/// One player's authoritative state (see MiniGolfSeatState in engine.ts).
class MiniGolfSeat {
  const MiniGolfSeat({
    required this.seat,
    required this.userId,
    required this.displayName,
    required this.strokes,
    required this.position,
    required this.lastRest,
    required this.holed,
    required this.consecutiveTimeouts,
    required this.forfeited,
    required this.connected,
  });

  final int seat;
  final String userId;
  final String displayName;
  final List<int> strokes;
  final Vec position;
  final Vec lastRest;
  final bool holed;
  final int consecutiveTimeouts;
  final bool forfeited;
  final bool connected;

  int get total => strokes.fold(0, (a, b) => a + b);
  bool get active => !forfeited;

  factory MiniGolfSeat.fromJson(Map<String, dynamic> j) => MiniGolfSeat(
        seat: (j['seat'] as num).toInt(),
        userId: j['userId'] as String,
        displayName: j['displayName'] as String,
        strokes: (j['strokes'] as List<dynamic>? ?? const []).map((e) => (e as num).toInt()).toList(),
        position: Vec.fromJson(j['position'] as Map<String, dynamic>),
        lastRest: j['lastRest'] == null ? Vec.fromJson(j['position'] as Map<String, dynamic>) : Vec.fromJson(j['lastRest'] as Map<String, dynamic>),
        holed: j['holed'] as bool? ?? false,
        consecutiveTimeouts: (j['consecutiveTimeouts'] as num?)?.toInt() ?? 0,
        forfeited: j['forfeited'] as bool? ?? false,
        connected: j['connected'] as bool? ?? true,
      );
}

enum MiniGolfPhase { play, finished }

/// Immutable snapshot of the server's state (see MiniGolfState in engine.ts).
class MiniGolfState {
  const MiniGolfState({
    required this.rules,
    required this.seats,
    required this.holeIndex,
    required this.course,
    required this.turnSeat,
    required this.phase,
    required this.obstaclePhase,
    required this.holeWinners,
    required this.placements,
    required this.version,
    required this.turnDeadline,
  });

  final MiniGolfRules rules;
  final List<MiniGolfSeat> seats;
  final int holeIndex;
  final Course course;
  final int turnSeat;
  final MiniGolfPhase phase;
  final double obstaclePhase;
  final List<int?> holeWinners;
  final List<int> placements;
  final int version;
  final int? turnDeadline;

  bool get finished => phase == MiniGolfPhase.finished;
  int get holeCount => rules.holes.length;
  MiniGolfSeat seatAt(int seat) => seats.firstWhere((s) => s.seat == seat);
  MiniGolfSeat? seatOrNull(int? seat) => seat == null ? null : seats.where((s) => s.seat == seat).firstOrNull;
  MiniGolfSeat get current => seatAt(turnSeat);

  /// Strokes of a seat on the current hole.
  int strokesOnCurrentHole(int seat) {
    final s = seatOrNull(seat);
    if (s == null || holeIndex >= s.strokes.length) return 0;
    return s.strokes[holeIndex];
  }

  factory MiniGolfState.fromJson(Map<String, dynamic> j) => MiniGolfState(
        rules: MiniGolfRules.fromJson((j['rules'] as Map<String, dynamic>?) ?? const {}),
        seats: (j['seats'] as List<dynamic>).map((s) => MiniGolfSeat.fromJson(s as Map<String, dynamic>)).toList(),
        holeIndex: (j['holeIndex'] as num?)?.toInt() ?? 0,
        course: Course.fromJson(j['course'] as Map<String, dynamic>),
        turnSeat: (j['turnSeat'] as num).toInt(),
        phase: j['phase'] == 'finished' ? MiniGolfPhase.finished : MiniGolfPhase.play,
        obstaclePhase: (j['obstaclePhase'] as num?)?.toDouble() ?? 0,
        holeWinners: (j['holeWinners'] as List<dynamic>? ?? const []).map((e) => (e as num?)?.toInt()).toList(),
        placements: (j['placements'] as List<dynamic>? ?? const []).map((e) => (e as num).toInt()).toList(),
        version: (j['version'] as num?)?.toInt() ?? 0,
        turnDeadline: (j['turnDeadline'] as num?)?.toInt(),
      );
}
