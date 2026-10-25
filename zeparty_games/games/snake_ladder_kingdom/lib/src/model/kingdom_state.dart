import 'layouts.dart';
import 'rules.dart';

enum KingdomColor {
  red,
  green,
  yellow,
  blue;

  static KingdomColor parse(String s) => KingdomColor.values.firstWhere((c) => c.name == s, orElse: () => KingdomColor.red);
}

/// Snapshot of one seat as sent by the server engine.
class KingdomSeat {
  const KingdomSeat({
    required this.seat,
    required this.userId,
    required this.displayName,
    required this.color,
    required this.position,
    required this.finishedPlacement,
    required this.forfeited,
    required this.connected,
    required this.consecutiveTimeouts,
  });
  final int seat;
  final String userId;
  final String displayName;
  final KingdomColor color;

  /// 0 = off board (start dock), boardSize = finished.
  final int position;
  final int? finishedPlacement;
  final bool forfeited;
  final bool connected;
  final int consecutiveTimeouts;

  bool get active => !forfeited && finishedPlacement == null;

  factory KingdomSeat.fromJson(Map<String, dynamic> j) => KingdomSeat(
        seat: j['seat'] as int,
        userId: j['userId'] as String,
        displayName: j['displayName'] as String,
        color: KingdomColor.parse(j['color'] as String),
        position: j['position'] as int? ?? 0,
        finishedPlacement: j['finishedPlacement'] as int?,
        forfeited: j['forfeited'] as bool? ?? false,
        connected: j['connected'] as bool? ?? true,
        consecutiveTimeouts: j['consecutiveTimeouts'] as int? ?? 0,
      );
}

enum KingdomPhase { roll, finished }

/// Immutable snapshot of the server state (backend/src/games/snake_ladder_kingdom/engine.ts).
class KingdomState {
  const KingdomState({
    required this.rules,
    required this.layout,
    required this.seats,
    required this.turnSeat,
    required this.phase,
    required this.dice,
    required this.version,
    required this.placements,
    required this.turnDeadline,
  });
  final SnakeLadderRules rules;
  final BoardLayout layout;
  final List<KingdomSeat> seats;
  final int turnSeat;
  final KingdomPhase phase;
  final int? dice;
  final int version;
  final List<int> placements;
  final int? turnDeadline;

  int get boardSize => rules.boardSize;
  KingdomSeat seatAt(int seat) => seats.firstWhere((s) => s.seat == seat);
  KingdomSeat? seatOrNull(int? seat) => seat == null ? null : seats.where((s) => s.seat == seat).firstOrNull;
  KingdomSeat get current => seatAt(turnSeat);

  factory KingdomState.fromJson(Map<String, dynamic> j) {
    final rules = SnakeLadderRules.fromJson((j['rules'] as Map<String, dynamic>?) ?? const {});
    final layoutJson = j['layout'] as Map<String, dynamic>?;
    return KingdomState(
      rules: rules,
      layout: layoutJson != null ? BoardLayout.fromJson(layoutJson) : layoutFor(rules.boardSize, rules.layout),
      seats: (j['seats'] as List<dynamic>).map((s) => KingdomSeat.fromJson(s as Map<String, dynamic>)).toList(),
      turnSeat: j['turnSeat'] as int,
      phase: KingdomPhase.values.firstWhere((p) => p.name == j['phase'], orElse: () => KingdomPhase.roll),
      dice: j['dice'] as int?,
      version: j['version'] as int? ?? 0,
      placements: (j['placements'] as List<dynamic>? ?? const []).cast<int>(),
      turnDeadline: j['turnDeadline'] as int?,
    );
  }
}
