/// Client-side mirror of the server ruleset (backend/src/games/connect4_galaxy/rules.ts).
/// Used for layout and hints only; the server remains the authority.
class Connect4Rules {
  const Connect4Rules({
    this.columns = 7,
    this.rows = 6,
    this.connect = 4,
    this.turnTimeoutSeconds = 30,
    this.timeoutsToForfeit = 3,
    this.firstMove = 'random',
  });

  final int columns;
  final int rows;
  final int connect;
  final int turnTimeoutSeconds;
  final int timeoutsToForfeit;
  final String firstMove;

  factory Connect4Rules.fromJson(Map<String, dynamic> j) => Connect4Rules(
        columns: (j['columns'] as num?)?.toInt() ?? 7,
        rows: (j['rows'] as num?)?.toInt() ?? 6,
        connect: (j['connect'] as num?)?.toInt() ?? 4,
        turnTimeoutSeconds: (j['turnTimeoutSeconds'] as num?)?.toInt() ?? 30,
        timeoutsToForfeit: (j['timeoutsToForfeit'] as num?)?.toInt() ?? 3,
        firstMove: j['firstMove'] as String? ?? 'random',
      );

  Map<String, dynamic> toJson() => {
        'columns': columns,
        'rows': rows,
        'connect': connect,
        'turnTimeoutSeconds': turnTimeoutSeconds,
        'timeoutsToForfeit': timeoutsToForfeit,
        'firstMove': firstMove,
      };
}
