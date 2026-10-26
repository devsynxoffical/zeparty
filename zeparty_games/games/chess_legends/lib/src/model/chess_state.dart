import 'board_fen.dart';

/// Typed mirror of backend/src/games/chess_legends/engine.ts `ChessState`
/// (plus the optional `legalMoves` that `getView` adds for the side to move).
class ChessRules {
  const ChessRules({this.initialSeconds = 300, this.incrementSeconds = 3, this.clockEnabled = true});
  final int initialSeconds;
  final int incrementSeconds;
  final bool clockEnabled;

  factory ChessRules.fromJson(Map<String, dynamic> j) => ChessRules(
        initialSeconds: (j['initialSeconds'] as num?)?.toInt() ?? 300,
        incrementSeconds: (j['incrementSeconds'] as num?)?.toInt() ?? 3,
        clockEnabled: j['clockEnabled'] as bool? ?? true,
      );
}

class ChessSeat {
  const ChessSeat({required this.seat, required this.userId, required this.displayName, required this.color, required this.connected});
  final int seat;
  final String userId;
  final String displayName;
  /// 'w' or 'b'.
  final String color;
  final bool connected;

  bool get isWhite => color == 'w';

  factory ChessSeat.fromJson(Map<String, dynamic> j) => ChessSeat(
        seat: j['seat'] as int,
        userId: j['userId'] as String,
        displayName: j['displayName'] as String,
        color: j['color'] as String,
        connected: j['connected'] as bool? ?? true,
      );
}

class ChessMoveRecord {
  const ChessMoveRecord({
    required this.ply,
    required this.color,
    required this.san,
    required this.uci,
    required this.from,
    required this.to,
    required this.piece,
    this.captured,
    this.promotion,
    this.castle,
    this.enPassant = false,
    this.check = false,
    this.checkmate = false,
  });
  final int ply;
  final String color;
  final String san;
  final String uci;
  final String from;
  final String to;
  final String piece;
  final String? captured;
  final String? promotion;
  final String? castle;
  final bool enPassant;
  final bool check;
  final bool checkmate;

  /// 1-based move number as printed in a move list.
  int get moveNumber => ply ~/ 2 + 1;
  bool get isWhite => color == 'w';

  factory ChessMoveRecord.fromJson(Map<String, dynamic> j) => ChessMoveRecord(
        ply: j['ply'] as int? ?? 0,
        color: j['color'] as String? ?? 'w',
        san: j['san'] as String? ?? '',
        uci: j['uci'] as String? ?? '',
        from: j['from'] as String,
        to: j['to'] as String,
        piece: j['piece'] as String? ?? 'p',
        captured: j['captured'] as String?,
        promotion: j['promotion'] as String?,
        castle: j['castle'] as String?,
        enPassant: j['enPassant'] as bool? ?? false,
        check: j['check'] as bool? ?? false,
        checkmate: j['checkmate'] as bool? ?? false,
      );
}

class ChessResult {
  const ChessResult({required this.outcome, required this.reason, required this.winnerSeat});
  /// 'white' | 'black' | 'draw'.
  final String outcome;
  final String reason;
  final int? winnerSeat;

  bool get isDraw => outcome == 'draw';

  factory ChessResult.fromJson(Map<String, dynamic> j) => ChessResult(outcome: j['outcome'] as String, reason: j['reason'] as String, winnerSeat: j['winnerSeat'] as int?);

  String get reasonLabel => switch (reason) {
        'checkmate' => 'Checkmate',
        'stalemate' => 'Stalemate',
        'resignation' => 'Resignation',
        'timeout' => 'Time',
        'agreement' => 'Draw agreed',
        'fifty_move' => 'Fifty-move rule',
        'threefold_repetition' => 'Threefold repetition',
        'insufficient_material' => 'Insufficient material',
        'abandoned' => 'Opponent left',
        _ => reason,
      };
}

enum ChessPhase { playing, finished }

class ChessState {
  const ChessState({
    required this.rules,
    required this.seats,
    required this.fen,
    required this.turn,
    required this.turnSeat,
    required this.phase,
    required this.clocks,
    required this.turnStartedAt,
    required this.turnDeadline,
    required this.moves,
    required this.san,
    required this.uci,
    required this.captured,
    required this.check,
    required this.lastMove,
    required this.drawOffer,
    required this.result,
    required this.version,
    required this.legalMoves,
    required this.placement,
  });

  final ChessRules rules;
  final List<ChessSeat> seats;
  final String fen;
  /// 'w' or 'b'.
  final String turn;
  final int turnSeat;
  final ChessPhase phase;
  /// Remaining ms per colour, keyed 'w' / 'b'.
  final Map<String, int> clocks;
  final int turnStartedAt;
  final int? turnDeadline;
  final List<ChessMoveRecord> moves;
  final List<String> san;
  final List<String> uci;
  /// Victim piece types captured by each colour, keyed 'w' / 'b'.
  final Map<String, List<String>> captured;
  final bool check;
  final (String from, String to)? lastMove;
  final int? drawOffer;
  final ChessResult? result;
  final int version;
  /// Only present in the view of the side to move.
  final Map<String, List<String>>? legalMoves;
  final BoardPlacement placement;

  bool get finished => phase == ChessPhase.finished;
  bool get whiteToMove => turn == 'w';

  ChessSeat seatAt(int seat) => seats.firstWhere((s) => s.seat == seat);
  ChessSeat? seatOrNull(int? seat) => seat == null ? null : seats.where((s) => s.seat == seat).firstOrNull;
  ChessSeat seatOfColor(String color) => seats.firstWhere((s) => s.color == color);
  ChessSeat get current => seatAt(turnSeat);

  int clockFor(String color) => clocks[color] ?? 0;

  /// Material captured by [color] minus material captured by the opponent.
  int materialDiff(String color) {
    int sum(List<String> l) => l.fold(0, (a, t) => a + pieceValue(t));
    final other = color == 'w' ? 'b' : 'w';
    return sum(captured[color] ?? const []) - sum(captured[other] ?? const []);
  }

  List<String> legalTargets(String from) => legalMoves?[from] ?? const [];
  bool isLegal(String from, String to) => legalTargets(from).contains(to);

  factory ChessState.fromJson(Map<String, dynamic> j) {
    final fen = j['fen'] as String;
    final lm = j['lastMove'] as Map<String, dynamic>?;
    final legal = j['legalMoves'] as Map<String, dynamic>?;
    final capturedRaw = (j['captured'] as Map<String, dynamic>?) ?? const {};
    final clocksRaw = (j['clocks'] as Map<String, dynamic>?) ?? const {};
    return ChessState(
      rules: ChessRules.fromJson((j['rules'] as Map<String, dynamic>?) ?? const {}),
      seats: (j['seats'] as List<dynamic>).map((s) => ChessSeat.fromJson(s as Map<String, dynamic>)).toList(),
      fen: fen,
      turn: j['turn'] as String? ?? (fen.split(' ').length > 1 ? fen.split(' ')[1] : 'w'),
      turnSeat: j['turnSeat'] as int,
      phase: j['phase'] == 'finished' ? ChessPhase.finished : ChessPhase.playing,
      clocks: {'w': (clocksRaw['w'] as num?)?.toInt() ?? 0, 'b': (clocksRaw['b'] as num?)?.toInt() ?? 0},
      turnStartedAt: (j['turnStartedAt'] as num?)?.toInt() ?? 0,
      turnDeadline: (j['turnDeadline'] as num?)?.toInt(),
      moves: (j['moves'] as List<dynamic>? ?? const []).map((m) => ChessMoveRecord.fromJson(m as Map<String, dynamic>)).toList(),
      san: (j['san'] as List<dynamic>? ?? const []).cast<String>(),
      uci: (j['uci'] as List<dynamic>? ?? const []).cast<String>(),
      captured: {
        'w': ((capturedRaw['w'] as List<dynamic>?) ?? const []).cast<String>(),
        'b': ((capturedRaw['b'] as List<dynamic>?) ?? const []).cast<String>(),
      },
      check: j['check'] as bool? ?? false,
      lastMove: lm == null ? null : (lm['from'] as String, lm['to'] as String),
      drawOffer: j['drawOffer'] as int?,
      result: j['result'] == null ? null : ChessResult.fromJson(j['result'] as Map<String, dynamic>),
      version: j['version'] as int? ?? 0,
      legalMoves: legal?.map((k, v) => MapEntry(k, (v as List<dynamic>).cast<String>())),
      placement: BoardPlacement.parse(fen),
    );
  }
}

/// Formats a clock value as m:ss, or s.t under ten seconds.
String formatClock(int ms) {
  if (ms <= 0) return '0:00';
  if (ms < 10_000) {
    final tenths = (ms / 100).floor();
    return '0:0${tenths ~/ 10}.${tenths % 10}';
  }
  final total = (ms / 1000).ceil();
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
