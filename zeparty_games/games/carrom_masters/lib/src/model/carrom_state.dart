import 'geometry.dart';

/// Which team a seat or coin belongs to.
enum CarromSide {
  white,
  black;

  static CarromSide parse(String s) => s == 'black' ? CarromSide.black : CarromSide.white;
  CarromSide get other => this == CarromSide.white ? CarromSide.black : CarromSide.white;
}

enum CoinKind {
  white,
  black,
  queen;

  static CoinKind parse(String s) => switch (s) { 'black' => CoinKind.black, 'queen' => CoinKind.queen, _ => CoinKind.white };
  CarromSide? get side => switch (this) { CoinKind.white => CarromSide.white, CoinKind.black => CarromSide.black, CoinKind.queen => null };
}

/// Explicit ruleset mirrored from backend rules.ts.
class CarromRules {
  const CarromRules({this.coinsPerSide = 9, this.queenRequired = true, this.penaltyOnStrikerPocket = true, this.turnTimeoutSeconds = 45, this.timeoutsToForfeit = 3, this.pointsToWin = 1});
  final int coinsPerSide;
  final bool queenRequired;
  final bool penaltyOnStrikerPocket;
  final int turnTimeoutSeconds;
  final int timeoutsToForfeit;
  final int pointsToWin;

  factory CarromRules.fromJson(Map<String, dynamic> j) => CarromRules(
        coinsPerSide: (j['coinsPerSide'] as num?)?.toInt() ?? 9,
        queenRequired: j['queenRequired'] as bool? ?? true,
        penaltyOnStrikerPocket: j['penaltyOnStrikerPocket'] as bool? ?? true,
        turnTimeoutSeconds: (j['turnTimeoutSeconds'] as num?)?.toInt() ?? 45,
        timeoutsToForfeit: (j['timeoutsToForfeit'] as num?)?.toInt() ?? 3,
        pointsToWin: (j['pointsToWin'] as num?)?.toInt() ?? 1,
      );
}

class CarromSeat {
  const CarromSeat({required this.seat, required this.userId, required this.displayName, required this.side, required this.edge, required this.consecutiveTimeouts, required this.forfeited, required this.connected});
  final int seat;
  final String userId;
  final String displayName;
  final CarromSide side;
  /// Board edge the seat shoots from: 0 bottom, 1 right, 2 top, 3 left.
  final int edge;
  final int consecutiveTimeouts;
  final bool forfeited;
  final bool connected;

  factory CarromSeat.fromJson(Map<String, dynamic> j) => CarromSeat(
        seat: j['seat'] as int,
        userId: j['userId'] as String,
        displayName: j['displayName'] as String,
        side: CarromSide.parse(j['side'] as String),
        edge: (j['edge'] as num?)?.toInt() ?? 0,
        consecutiveTimeouts: (j['consecutiveTimeouts'] as num?)?.toInt() ?? 0,
        forfeited: j['forfeited'] as bool? ?? false,
        connected: j['connected'] as bool? ?? true,
      );
}

class CarromCoin {
  const CarromCoin({required this.id, required this.kind, required this.position, required this.pocketed, required this.pocketedBy});
  final String id;
  final CoinKind kind;
  /// Board coordinates (meaningless while pocketed).
  final BPoint position;
  final bool pocketed;
  final CarromSide? pocketedBy;

  factory CarromCoin.fromJson(Map<String, dynamic> j) => CarromCoin(
        id: j['id'] as String,
        kind: CoinKind.parse(j['kind'] as String),
        position: BPoint((j['x'] as num).toDouble(), (j['y'] as num).toDouble()),
        pocketed: j['pocketed'] as bool? ?? false,
        pocketedBy: j['pocketedBy'] == null ? null : CarromSide.parse(j['pocketedBy'] as String),
      );
}

enum QueenState {
  board,
  pending,
  covered;

  static QueenState parse(String? s) => switch (s) { 'pending' => QueenState.pending, 'covered' => QueenState.covered, _ => QueenState.board };
}

class QueenStatus {
  const QueenStatus({required this.status, required this.pendingBy, required this.coveredBy});
  final QueenState status;
  final CarromSide? pendingBy;
  final CarromSide? coveredBy;

  factory QueenStatus.fromJson(Map<String, dynamic>? j) => QueenStatus(
        status: QueenState.parse(j?['status'] as String?),
        pendingBy: j?['pendingBy'] == null ? null : CarromSide.parse(j!['pendingBy'] as String),
        coveredBy: j?['coveredBy'] == null ? null : CarromSide.parse(j!['coveredBy'] as String),
      );
}

enum CarromPhase { aim, finished }

/// Immutable snapshot of the server state (backend/src/games/carrom_masters/engine.ts).
class CarromState {
  const CarromState({
    required this.rules,
    required this.seats,
    required this.coins,
    required this.turnSeat,
    required this.phase,
    required this.strikesThisTurn,
    required this.queen,
    required this.dues,
    required this.boardsWon,
    required this.boardNumber,
    required this.winnerSide,
    required this.version,
    required this.placements,
    required this.turnDeadline,
  });
  final CarromRules rules;
  final List<CarromSeat> seats;
  final List<CarromCoin> coins;
  final int turnSeat;
  final CarromPhase phase;
  final int strikesThisTurn;
  final QueenStatus queen;
  final Map<CarromSide, int> dues;
  final Map<CarromSide, int> boardsWon;
  final int boardNumber;
  final CarromSide? winnerSide;
  final int version;
  final List<int> placements;
  final int? turnDeadline;

  bool get finished => phase == CarromPhase.finished;
  CarromSeat seatAt(int seat) => seats.firstWhere((s) => s.seat == seat);
  CarromSeat? seatOrNull(int? seat) => seat == null ? null : seats.where((s) => s.seat == seat).firstOrNull;
  CarromSeat get current => seatAt(turnSeat);
  CarromCoin? coin(String id) => coins.where((c) => c.id == id).firstOrNull;
  Iterable<CarromCoin> get onBoard => coins.where((c) => !c.pocketed);
  List<CarromCoin> pocketedFor(CarromSide side) => coins.where((c) => c.pocketed && c.pocketedBy == side && c.kind != CoinKind.queen).toList();
  int remaining(CarromSide side) => coins.where((c) => c.kind.side == side && !c.pocketed).length;
  List<CarromSeat> seatsOf(CarromSide side) => seats.where((s) => s.side == side).toList();

  factory CarromState.fromJson(Map<String, dynamic> j) {
    final dues = (j['dues'] as Map<String, dynamic>?) ?? const {};
    final boards = (j['boardsWon'] as Map<String, dynamic>?) ?? const {};
    return CarromState(
      rules: CarromRules.fromJson((j['rules'] as Map<String, dynamic>?) ?? const {}),
      seats: (j['seats'] as List<dynamic>).map((s) => CarromSeat.fromJson(s as Map<String, dynamic>)).toList(),
      coins: (j['coins'] as List<dynamic>? ?? const []).map((c) => CarromCoin.fromJson(c as Map<String, dynamic>)).toList(),
      turnSeat: j['turnSeat'] as int,
      phase: j['phase'] == 'finished' ? CarromPhase.finished : CarromPhase.aim,
      strikesThisTurn: (j['strikesThisTurn'] as num?)?.toInt() ?? 0,
      queen: QueenStatus.fromJson(j['queen'] as Map<String, dynamic>?),
      dues: {CarromSide.white: (dues['white'] as num?)?.toInt() ?? 0, CarromSide.black: (dues['black'] as num?)?.toInt() ?? 0},
      boardsWon: {CarromSide.white: (boards['white'] as num?)?.toInt() ?? 0, CarromSide.black: (boards['black'] as num?)?.toInt() ?? 0},
      boardNumber: (j['boardNumber'] as num?)?.toInt() ?? 1,
      winnerSide: j['winnerSide'] == null ? null : CarromSide.parse(j['winnerSide'] as String),
      version: (j['version'] as num?)?.toInt() ?? 0,
      placements: (j['placements'] as List<dynamic>? ?? const []).cast<int>(),
      turnDeadline: (j['turnDeadline'] as num?)?.toInt(),
    );
  }
}
