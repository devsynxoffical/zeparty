/// Mirror of backend/src/games/mini_golf_paradise/rules.ts.
class MiniGolfRules {
  const MiniGolfRules({
    this.holes = const [0, 1, 2, 3, 4],
    this.maxStrokes = 8,
    this.turnTimeoutSeconds = 45,
    this.timeoutsToForfeit = 3,
    this.strokeOrder = 'rotation',
  });

  final List<int> holes;
  final int maxStrokes;
  final int turnTimeoutSeconds;
  final int timeoutsToForfeit;
  final String strokeOrder;

  factory MiniGolfRules.fromJson(Map<String, dynamic> j) => MiniGolfRules(
        holes: (j['holes'] as List<dynamic>? ?? const [0, 1, 2, 3, 4]).map((e) => (e as num).toInt()).toList(),
        maxStrokes: (j['maxStrokes'] as num?)?.toInt() ?? 8,
        turnTimeoutSeconds: (j['turnTimeoutSeconds'] as num?)?.toInt() ?? 45,
        timeoutsToForfeit: (j['timeoutsToForfeit'] as num?)?.toInt() ?? 3,
        strokeOrder: j['strokeOrder'] as String? ?? 'rotation',
      );
}
