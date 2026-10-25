import 'board.dart';
import 'rules.dart';

/// Immutable snapshot of the server's Ludo state (see backend engine.ts).
class LudoSeat {
  const LudoSeat({required this.seat, required this.userId, required this.displayName, required this.color, required this.tokens, required this.finishedPlacement, required this.forfeited, required this.connected, required this.consecutiveTimeouts});
  final int seat;
  final String userId;
  final String displayName;
  final LudoColor color;
  final List<int> tokens;
  final int? finishedPlacement;
  final bool forfeited;
  final bool connected;
  final int consecutiveTimeouts;

  bool get active => !forfeited && finishedPlacement == null;
  int get homeCount => tokens.where((t) => t == homeStep).length;
  int get progress => tokens.fold(0, (a, t) => a + (t < 0 ? 0 : t));

  factory LudoSeat.fromJson(Map<String, dynamic> j) => LudoSeat(
        seat: j['seat'] as int,
        userId: j['userId'] as String,
        displayName: j['displayName'] as String,
        color: LudoColor.parse(j['color'] as String),
        tokens: (j['tokens'] as List<dynamic>).cast<int>(),
        finishedPlacement: j['finishedPlacement'] as int?,
        forfeited: j['forfeited'] as bool? ?? false,
        connected: j['connected'] as bool? ?? true,
        consecutiveTimeouts: j['consecutiveTimeouts'] as int? ?? 0,
      );
}

enum LudoPhase { roll, move, finished }

class LudoState {
  const LudoState({required this.rules, required this.seats, required this.turnSeat, required this.phase, required this.dice, required this.consecutiveSixes, required this.legalTokens, required this.version, required this.placements, required this.turnDeadline});
  final LudoRules rules;
  final List<LudoSeat> seats;
  final int turnSeat;
  final LudoPhase phase;
  final int? dice;
  final int consecutiveSixes;
  final List<int> legalTokens;
  final int version;
  final List<int> placements;
  final int? turnDeadline;

  LudoSeat seatAt(int seat) => seats.firstWhere((s) => s.seat == seat);
  LudoSeat? seatOrNull(int? seat) => seat == null ? null : seats.where((s) => s.seat == seat).firstOrNull;
  LudoSeat get current => seatAt(turnSeat);

  factory LudoState.fromJson(Map<String, dynamic> j) => LudoState(
        rules: LudoRules.fromJson((j['rules'] as Map<String, dynamic>?) ?? const {}),
        seats: (j['seats'] as List<dynamic>).map((s) => LudoSeat.fromJson(s as Map<String, dynamic>)).toList(),
        turnSeat: j['turnSeat'] as int,
        phase: LudoPhase.values.firstWhere((p) => p.name == j['phase'], orElse: () => LudoPhase.roll),
        dice: j['dice'] as int?,
        consecutiveSixes: j['consecutiveSixes'] as int? ?? 0,
        legalTokens: (j['legalTokens'] as List<dynamic>? ?? const []).cast<int>(),
        version: j['version'] as int? ?? 0,
        placements: (j['placements'] as List<dynamic>? ?? const []).cast<int>(),
        turnDeadline: j['turnDeadline'] as int?,
      );

  /// Client-side preview of legal tokens for a hypothetical die, mirroring the
  /// server. Used to pre-highlight while the authoritative result is in flight.
  List<int> previewLegalTokens(int seat, int dice) {
    final me = seatAt(seat);
    final r = rules;
    final out = <int>[];
    for (var i = 0; i < me.tokens.length; i++) {
      final step = me.tokens[i];
      if (step == homeStep) continue;
      int target;
      if (step < 0) {
        if (dice != r.unlockRoll) continue;
        target = 0;
      } else {
        target = step + dice;
        if (target > homeStep) {
          if (r.exactHomeEntry) continue;
          target = homeStep;
        }
      }
      if (r.stackingAllowed && _blockedByStack(me, target)) continue;
      out.add(i);
    }
    return out;
  }

  bool _blockedByStack(LudoSeat me, int target) {
    if (target > lastTrackStep) return false;
    final abs = absoluteIndex(me.color, target)!;
    for (final other in seats) {
      if (other.seat == me.seat) continue;
      final count = other.tokens.where((t) => t >= 0 && t <= lastTrackStep && absoluteIndex(other.color, t) == abs).length;
      if (count >= 2) return true;
    }
    return false;
  }
}
