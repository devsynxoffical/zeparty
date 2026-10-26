/// Client-side mirror of the server ruleset (backend/src/games/snake_ladder_kingdom/rules.ts).
/// Used only for presentation (board size, timer length); the server resolves every move.
class SnakeLadderRules {
  const SnakeLadderRules({
    this.boardSize = 100,
    this.layout = 'kingdom_a',
    this.exactFinish = true,
    this.extraTurnOnSix = true,
    this.unlockRoll = 0,
    this.endOnFirstWinner = false,
    this.turnTimeoutSeconds = 30,
    this.timeoutsToForfeit = 3,
  });

  final int boardSize;
  final String layout;
  final bool exactFinish;
  final bool extraTurnOnSix;
  final int unlockRoll;
  final bool endOnFirstWinner;
  final int turnTimeoutSeconds;
  final int timeoutsToForfeit;

  factory SnakeLadderRules.fromJson(Map<String, dynamic> j) => SnakeLadderRules(
        boardSize: j['boardSize'] as int? ?? 100,
        layout: j['layout'] as String? ?? 'kingdom_a',
        exactFinish: j['exactFinish'] as bool? ?? true,
        extraTurnOnSix: j['extraTurnOnSix'] as bool? ?? true,
        unlockRoll: j['unlockRoll'] as int? ?? 0,
        endOnFirstWinner: j['endOnFirstWinner'] as bool? ?? false,
        turnTimeoutSeconds: j['turnTimeoutSeconds'] as int? ?? 30,
        timeoutsToForfeit: j['timeoutsToForfeit'] as int? ?? 3,
      );
}
