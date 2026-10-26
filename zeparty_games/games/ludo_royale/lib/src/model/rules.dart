/// Client-side mirror of the server ruleset. Used only for move preview and
/// highlighting; the server remains the authority for every applied move.
class LudoRules {
  const LudoRules({
    this.variant = 'classic',
    this.unlockRoll = 6,
    this.maxTokens = 4,
    this.tokensStartingOut = 0,
    this.extraTurnOnSix = true,
    this.extraTurnOnCapture = true,
    this.extraTurnOnHome = true,
    this.threeSixesForfeit = true,
    this.safeSquares = 'stars_and_starts',
    this.exactHomeEntry = true,
    this.stackingAllowed = false,
    this.captureOnSafe = false,
    this.endOnFirstWinner = false,
    this.turnTimeoutSeconds = 30,
    this.timeoutsToForfeit = 3,
  });

  final String variant;
  final int unlockRoll;
  final int maxTokens;
  final int tokensStartingOut;
  final bool extraTurnOnSix;
  final bool extraTurnOnCapture;
  final bool extraTurnOnHome;
  final bool threeSixesForfeit;
  final String safeSquares;
  final bool exactHomeEntry;
  final bool stackingAllowed;
  final bool captureOnSafe;
  final bool endOnFirstWinner;
  final int turnTimeoutSeconds;
  final int timeoutsToForfeit;

  factory LudoRules.fromJson(Map<String, dynamic> j) => LudoRules(
        variant: j['variant'] as String? ?? 'classic',
        unlockRoll: j['unlockRoll'] as int? ?? 6,
        maxTokens: j['maxTokens'] as int? ?? 4,
        tokensStartingOut: j['tokensStartingOut'] as int? ?? 0,
        extraTurnOnSix: j['extraTurnOnSix'] as bool? ?? true,
        extraTurnOnCapture: j['extraTurnOnCapture'] as bool? ?? true,
        extraTurnOnHome: j['extraTurnOnHome'] as bool? ?? true,
        threeSixesForfeit: j['threeSixesForfeit'] as bool? ?? true,
        safeSquares: j['safeSquares'] as String? ?? 'stars_and_starts',
        exactHomeEntry: j['exactHomeEntry'] as bool? ?? true,
        stackingAllowed: j['stackingAllowed'] as bool? ?? false,
        captureOnSafe: j['captureOnSafe'] as bool? ?? false,
        endOnFirstWinner: j['endOnFirstWinner'] as bool? ?? false,
        turnTimeoutSeconds: j['turnTimeoutSeconds'] as int? ?? 30,
        timeoutsToForfeit: j['timeoutsToForfeit'] as int? ?? 3,
      );
}
