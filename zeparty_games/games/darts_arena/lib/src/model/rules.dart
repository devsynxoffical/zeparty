/// Client-side mirror of the server ruleset (backend/src/games/darts_arena/rules.ts).
/// Used for display and the throw preview only; the server owns every outcome.
class DartsRules {
  const DartsRules({
    this.format = '501',
    this.doubleOut = true,
    this.doubleIn = false,
    this.legsToWin = 1,
    this.turnTimeoutSeconds = 30,
    this.timeoutsToForfeit = 3,
    this.baseSigma = 0.07,
  });

  final String format;
  final bool doubleOut;
  final bool doubleIn;
  final int legsToWin;
  final int turnTimeoutSeconds;
  final int timeoutsToForfeit;
  final double baseSigma;

  factory DartsRules.fromJson(Map<String, dynamic> j) => DartsRules(
        format: j['format'] as String? ?? '501',
        doubleOut: j['doubleOut'] as bool? ?? true,
        doubleIn: j['doubleIn'] as bool? ?? false,
        legsToWin: j['legsToWin'] as int? ?? 1,
        turnTimeoutSeconds: j['turnTimeoutSeconds'] as int? ?? 30,
        timeoutsToForfeit: j['timeoutsToForfeit'] as int? ?? 3,
        baseSigma: (j['baseSigma'] as num?)?.toDouble() ?? 0.07,
      );
}
