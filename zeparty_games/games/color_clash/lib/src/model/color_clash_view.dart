import 'card.dart';

enum CcPhase {
  play,
  drawn,
  finished;

  static CcPhase parse(String? s) => CcPhase.values.firstWhere((p) => p.name == s, orElse: () => CcPhase.play);
}

class CcRules {
  const CcRules({required this.startingHand, required this.targetScore, required this.maxRounds, required this.stackSurge, required this.turnTimeoutSeconds, required this.timeoutsToForfeit});
  final int startingHand;
  final int targetScore;
  final int maxRounds;
  final bool stackSurge;
  final int turnTimeoutSeconds;
  final int timeoutsToForfeit;

  factory CcRules.fromJson(Map<String, dynamic> j) => CcRules(
        startingHand: j['startingHand'] as int? ?? 7,
        targetScore: j['targetScore'] as int? ?? 200,
        maxRounds: j['maxRounds'] as int? ?? 1,
        stackSurge: j['stackSurge'] as bool? ?? false,
        turnTimeoutSeconds: j['turnTimeoutSeconds'] as int? ?? 20,
        timeoutsToForfeit: j['timeoutsToForfeit'] as int? ?? 3,
      );
}

/// A seat as every viewer sees it: counts only, never cards.
class CcSeat {
  const CcSeat({required this.seat, required this.userId, required this.displayName, required this.handCount, required this.score, required this.declared, required this.forfeited, required this.connected, required this.consecutiveTimeouts});
  final int seat;
  final String userId;
  final String displayName;
  final int handCount;
  final int score;
  final bool declared;
  final bool forfeited;
  final bool connected;
  final int consecutiveTimeouts;

  factory CcSeat.fromJson(Map<String, dynamic> j) => CcSeat(
        seat: j['seat'] as int,
        userId: j['userId'] as String,
        displayName: j['displayName'] as String,
        handCount: j['handCount'] as int? ?? 0,
        score: j['score'] as int? ?? 0,
        declared: j['declared'] as bool? ?? false,
        forfeited: j['forfeited'] as bool? ?? false,
        connected: j['connected'] as bool? ?? true,
        consecutiveTimeouts: j['consecutiveTimeouts'] as int? ?? 0,
      );
}

class CcLastRound {
  const CcLastRound({required this.winnerSeat, required this.points});
  final int winnerSeat;
  final int points;
  factory CcLastRound.fromJson(Map<String, dynamic> j) => CcLastRound(winnerSeat: j['winnerSeat'] as int, points: j['points'] as int);
}

/// Immutable snapshot of the per-viewer projection the server sends (engine.getView).
class CcView {
  const CcView({
    required this.rules,
    required this.round,
    required this.phase,
    required this.turnSeat,
    required this.direction,
    required this.drawCount,
    required this.discardCount,
    required this.topCard,
    required this.currentColor,
    required this.echoNumber,
    required this.pendingDraw,
    required this.catchable,
    required this.version,
    required this.turnDeadline,
    required this.placements,
    required this.lastRound,
    required this.seats,
    required this.viewerSeat,
    required this.myHand,
    required this.playable,
    required this.drawnCardId,
    required this.canDeclare,
    required this.canDraw,
    required this.canPass,
    required this.catchTargets,
  });

  final CcRules rules;
  final int round;
  final CcPhase phase;
  final int turnSeat;
  final int direction;
  final int drawCount;
  final int discardCount;
  final CcCard? topCard;
  final CcColor currentColor;
  final int? echoNumber;
  final int pendingDraw;
  final int? catchable;
  final int version;
  final int? turnDeadline;
  final List<int> placements;
  final CcLastRound? lastRound;
  final List<CcSeat> seats;
  final int? viewerSeat;
  /// Null for spectators.
  final List<CcCard>? myHand;
  final List<String> playable;
  final String? drawnCardId;
  final bool canDeclare;
  final bool canDraw;
  final bool canPass;
  final List<int> catchTargets;

  bool get finished => phase == CcPhase.finished;
  CcSeat seatAt(int seat) => seats.firstWhere((s) => s.seat == seat);
  CcSeat? seatOrNull(int? seat) => seat == null ? null : seats.where((s) => s.seat == seat).firstOrNull;
  CcSeat get current => seatAt(turnSeat);
  bool get isMyTurn => viewerSeat != null && turnSeat == viewerSeat && !finished;
  bool isPlayable(String cardId) => playable.contains(cardId);

  factory CcView.fromJson(Map<String, dynamic> j) => CcView(
        rules: CcRules.fromJson((j['rules'] as Map<String, dynamic>?) ?? const {}),
        round: j['round'] as int? ?? 1,
        phase: CcPhase.parse(j['phase'] as String?),
        turnSeat: j['turnSeat'] as int? ?? 0,
        direction: j['direction'] as int? ?? 1,
        drawCount: j['drawCount'] as int? ?? 0,
        discardCount: j['discardCount'] as int? ?? 0,
        topCard: j['topCard'] == null ? null : CcCard.fromJson(j['topCard'] as Map<String, dynamic>),
        currentColor: CcColor.parse(j['currentColor'] as String? ?? 'ruby'),
        echoNumber: j['echoNumber'] as int?,
        pendingDraw: j['pendingDraw'] as int? ?? 0,
        catchable: j['catchable'] as int?,
        version: j['version'] as int? ?? 0,
        turnDeadline: j['turnDeadline'] as int?,
        placements: (j['placements'] as List<dynamic>? ?? const []).cast<int>(),
        lastRound: j['lastRound'] == null ? null : CcLastRound.fromJson(j['lastRound'] as Map<String, dynamic>),
        seats: (j['seats'] as List<dynamic>).map((s) => CcSeat.fromJson(s as Map<String, dynamic>)).toList(),
        viewerSeat: j['viewerSeat'] as int?,
        myHand: j['myHand'] == null ? null : (j['myHand'] as List<dynamic>).map((c) => CcCard.fromJson(c as Map<String, dynamic>)).toList(),
        playable: (j['playable'] as List<dynamic>? ?? const []).cast<String>(),
        drawnCardId: j['drawnCardId'] as String?,
        canDeclare: j['canDeclare'] as bool? ?? false,
        canDraw: j['canDraw'] as bool? ?? false,
        canPass: j['canPass'] as bool? ?? false,
        catchTargets: (j['catchTargets'] as List<dynamic>? ?? const []).cast<int>(),
      );
}
