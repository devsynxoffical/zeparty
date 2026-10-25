import 'rules.dart';

/// Match formats (mirror of the server's `format` enum).
enum DartsFormat {
  x501('501'),
  x301('301'),
  cricket('cricket'),
  aroundTheClock('around_the_clock');

  const DartsFormat(this.wire);
  final String wire;

  bool get isX01 => this == x501 || this == x301;
  int get startScore => switch (this) { x501 => 501, x301 => 301, _ => 0 };
  String get title => switch (this) { x501 => '501', x301 => '301', cricket => 'Cricket', aroundTheClock => 'Around the Clock' };

  static DartsFormat parse(String? s) => DartsFormat.values.firstWhere((f) => f.wire == s, orElse: () => DartsFormat.x501);
}

/// Cricket numbers in scoreboard order; 25 is the bull.
const List<int> kCricketNumbers = [20, 19, 18, 17, 16, 15, 25];
const int kDartsPerVisit = 3;
const int kClockBull = 25;
const int kClockDone = 26;

class BoardPoint {
  const BoardPoint(this.x, this.y);
  final double x;
  final double y;
  factory BoardPoint.fromJson(Map<dynamic, dynamic> j) => BoardPoint((j['x'] as num).toDouble(), (j['y'] as num).toDouble());
  @override
  bool operator ==(Object other) => other is BoardPoint && other.x == x && other.y == y;
  @override
  int get hashCode => Object.hash(x, y);
}

/// One resolved dart (server authoritative). Same shape as the `dart_thrown` payload.
class ThrownDart {
  const ThrownDart({required this.dartIndex, required this.aim, required this.landed, required this.segment, required this.multiplier, required this.points, required this.label, this.bust = false, this.miss = false});
  final int dartIndex;
  final BoardPoint aim;
  final BoardPoint landed;
  final int segment;
  final int multiplier;
  final int points;
  final String label;
  final bool bust;
  final bool miss;

  bool get isInnerBull => segment == 25 && multiplier == 2;

  factory ThrownDart.fromJson(Map<String, dynamic> j) => ThrownDart(
        dartIndex: j['dartIndex'] as int? ?? 0,
        aim: BoardPoint.fromJson((j['aim'] as Map<dynamic, dynamic>?) ?? const {'x': 0, 'y': 0}),
        landed: BoardPoint.fromJson(j['landed'] as Map<dynamic, dynamic>),
        segment: j['segment'] as int? ?? 0,
        multiplier: j['multiplier'] as int? ?? 0,
        points: j['points'] as int? ?? 0,
        label: j['label'] as String? ?? '',
        bust: j['bust'] as bool? ?? false,
        miss: j['miss'] as bool? ?? false,
      );
}

class LastVisit {
  const LastVisit({required this.seat, required this.darts, required this.score});
  final int seat;
  final List<ThrownDart> darts;
  final int score;
  factory LastVisit.fromJson(Map<String, dynamic> j) => LastVisit(
        seat: j['seat'] as int,
        darts: (j['darts'] as List<dynamic>? ?? const []).map((d) => ThrownDart.fromJson((d as Map<dynamic, dynamic>).cast<String, dynamic>())).toList(),
        score: j['score'] as int? ?? 0,
      );
}

class DartsSeat {
  const DartsSeat({
    required this.seat,
    required this.userId,
    required this.displayName,
    required this.remaining,
    required this.inOpen,
    required this.marks,
    required this.points,
    required this.clockTarget,
    required this.legsWon,
    required this.finishedPlacement,
    required this.consecutiveTimeouts,
    required this.forfeited,
    required this.connected,
  });
  final int seat;
  final String userId;
  final String displayName;
  final int remaining;
  final bool inOpen;
  final Map<int, int> marks;
  final int points;
  final int clockTarget;
  final int legsWon;
  final int? finishedPlacement;
  final int consecutiveTimeouts;
  final bool forfeited;
  final bool connected;

  bool get active => !forfeited;
  int marksOn(int number) => marks[number] ?? 0;
  bool closed(int number) => marksOn(number) >= 3;
  bool get allClosed => kCricketNumbers.every(closed);

  factory DartsSeat.fromJson(Map<String, dynamic> j) {
    final rawMarks = (j['marks'] as Map<dynamic, dynamic>?) ?? const {};
    return DartsSeat(
      seat: j['seat'] as int,
      userId: j['userId'] as String,
      displayName: j['displayName'] as String,
      remaining: j['remaining'] as int? ?? 0,
      inOpen: j['inOpen'] as bool? ?? true,
      marks: {for (final e in rawMarks.entries) int.parse(e.key as String): (e.value as num).toInt()},
      points: j['points'] as int? ?? 0,
      clockTarget: j['clockTarget'] as int? ?? 1,
      legsWon: j['legsWon'] as int? ?? 0,
      finishedPlacement: j['finishedPlacement'] as int?,
      consecutiveTimeouts: j['consecutiveTimeouts'] as int? ?? 0,
      forfeited: j['forfeited'] as bool? ?? false,
      connected: j['connected'] as bool? ?? true,
    );
  }
}

enum DartsPhase { throwing, finished }

/// Immutable snapshot of the server's Darts Arena state (see backend engine.ts).
class DartsState {
  const DartsState({
    required this.rules,
    required this.format,
    required this.seats,
    required this.turnSeat,
    required this.phase,
    required this.leg,
    required this.legStarterSeat,
    required this.dartIndex,
    required this.visit,
    required this.visitStartRemaining,
    required this.lastVisit,
    required this.legWinners,
    required this.version,
    required this.placements,
    required this.turnDeadline,
  });
  final DartsRules rules;
  final DartsFormat format;
  final List<DartsSeat> seats;
  final int turnSeat;
  final DartsPhase phase;
  final int leg;
  final int legStarterSeat;
  final int dartIndex;
  final List<ThrownDart> visit;
  final int visitStartRemaining;
  final LastVisit? lastVisit;
  final List<int> legWinners;
  final int version;
  final List<int> placements;
  final int? turnDeadline;

  bool get finished => phase == DartsPhase.finished;
  int get dartsLeft => kDartsPerVisit - dartIndex;
  DartsSeat seatAt(int seat) => seats.firstWhere((s) => s.seat == seat);
  DartsSeat? seatOrNull(int? seat) => seat == null ? null : seats.where((s) => s.seat == seat).firstOrNull;
  DartsSeat get current => seatAt(turnSeat);
  int get visitScore => visit.fold(0, (a, d) => a + (d.bust ? 0 : d.points));

  factory DartsState.fromJson(Map<String, dynamic> j) {
    final rules = DartsRules.fromJson((j['rules'] as Map<String, dynamic>?) ?? const {});
    return DartsState(
      rules: rules,
      format: DartsFormat.parse(j['format'] as String? ?? rules.format),
      seats: (j['seats'] as List<dynamic>).map((s) => DartsSeat.fromJson((s as Map<dynamic, dynamic>).cast<String, dynamic>())).toList(),
      turnSeat: j['turnSeat'] as int,
      phase: j['phase'] == 'finished' ? DartsPhase.finished : DartsPhase.throwing,
      leg: j['leg'] as int? ?? 1,
      legStarterSeat: j['legStarterSeat'] as int? ?? 0,
      dartIndex: j['dartIndex'] as int? ?? 0,
      visit: (j['visit'] as List<dynamic>? ?? const []).map((d) => ThrownDart.fromJson((d as Map<dynamic, dynamic>).cast<String, dynamic>())).toList(),
      visitStartRemaining: j['visitStartRemaining'] as int? ?? 0,
      lastVisit: j['lastVisit'] == null ? null : LastVisit.fromJson((j['lastVisit'] as Map<dynamic, dynamic>).cast<String, dynamic>()),
      legWinners: (j['legWinners'] as List<dynamic>? ?? const []).cast<int>(),
      version: j['version'] as int? ?? 0,
      placements: (j['placements'] as List<dynamic>? ?? const []).cast<int>(),
      turnDeadline: j['turnDeadline'] as int?,
    );
  }
}
