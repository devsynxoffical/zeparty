import 'rules.dart';
import 'win_detection.dart';

/// Immutable snapshot of the server's Connect 4 state (see backend engine.ts).
class Connect4Seat {
  const Connect4Seat({required this.seat, required this.userId, required this.displayName, required this.consecutiveTimeouts, required this.forfeited, required this.connected});
  final int seat;
  final String userId;
  final String displayName;
  final int consecutiveTimeouts;
  final bool forfeited;
  final bool connected;

  factory Connect4Seat.fromJson(Map<String, dynamic> j) => Connect4Seat(
        seat: (j['seat'] as num).toInt(),
        userId: j['userId'] as String,
        displayName: j['displayName'] as String,
        consecutiveTimeouts: (j['consecutiveTimeouts'] as num?)?.toInt() ?? 0,
        forfeited: j['forfeited'] as bool? ?? false,
        connected: j['connected'] as bool? ?? true,
      );
}

enum Connect4Phase { play, finished }

class LastDrop {
  const LastDrop({required this.column, required this.row, required this.seat});
  final int column;
  final int row;
  final int seat;
  factory LastDrop.fromJson(Map<String, dynamic> j) => LastDrop(column: (j['column'] as num).toInt(), row: (j['row'] as num).toInt(), seat: (j['seat'] as num).toInt());
}

class Connect4State {
  const Connect4State({
    required this.rules,
    required this.seats,
    required this.grid,
    required this.turnSeat,
    required this.phase,
    required this.legalColumns,
    required this.moveCount,
    required this.lastDrop,
    required this.winnerSeat,
    required this.winLine,
    required this.draw,
    required this.placements,
    required this.version,
    required this.turnDeadline,
  });

  final Connect4Rules rules;
  final List<Connect4Seat> seats;

  /// grid[row][col]: seat index or [emptyCell]. Row 0 is the bottom row.
  final List<List<int>> grid;
  final int turnSeat;
  final Connect4Phase phase;
  final List<int> legalColumns;
  final int moveCount;
  final LastDrop? lastDrop;
  final int? winnerSeat;
  final List<GridCell>? winLine;
  final bool draw;
  final List<int> placements;
  final int version;
  final int? turnDeadline;

  int get rows => grid.length;
  int get columns => grid.isEmpty ? rules.columns : grid[0].length;
  bool get finished => phase == Connect4Phase.finished;

  Connect4Seat seatAt(int seat) => seats.firstWhere((s) => s.seat == seat);
  Connect4Seat? seatOrNull(int? seat) => seat == null ? null : seats.where((s) => s.seat == seat).firstOrNull;
  Connect4Seat get current => seatAt(turnSeat);

  int cellAt(int row, int col) => grid[row][col];
  int discCount(int seat) => grid.fold(0, (a, row) => a + row.where((v) => v == seat).length);

  /// Row a disc dropped in [column] would land on, or -1 when the column is full.
  int landingRowFor(int column) => landingRow(grid, column);

  factory Connect4State.fromJson(Map<String, dynamic> j) {
    final rules = Connect4Rules.fromJson((j['rules'] as Map<String, dynamic>?) ?? const {});
    final rawGrid = j['grid'] as List<dynamic>?;
    final grid = rawGrid == null ? emptyGrid(rules.rows, rules.columns) : rawGrid.map((r) => (r as List<dynamic>).map((v) => (v as num).toInt()).toList()).toList();
    final rawLine = j['winLine'] as List<dynamic>?;
    return Connect4State(
      rules: rules,
      seats: (j['seats'] as List<dynamic>).map((s) => Connect4Seat.fromJson(s as Map<String, dynamic>)).toList(),
      grid: grid,
      turnSeat: (j['turnSeat'] as num).toInt(),
      phase: Connect4Phase.values.firstWhere((p) => p.name == j['phase'], orElse: () => Connect4Phase.play),
      legalColumns: (j['legalColumns'] as List<dynamic>?)?.map((v) => (v as num).toInt()).toList() ?? legalColumnsOf(grid),
      moveCount: (j['moveCount'] as num?)?.toInt() ?? 0,
      lastDrop: j['lastDrop'] == null ? null : LastDrop.fromJson(j['lastDrop'] as Map<String, dynamic>),
      winnerSeat: (j['winnerSeat'] as num?)?.toInt(),
      winLine: rawLine?.map((c) => GridCell.fromJson(c as Map<String, dynamic>)).toList(),
      draw: j['draw'] as bool? ?? false,
      placements: (j['placements'] as List<dynamic>? ?? const []).map((v) => (v as num).toInt()).toList(),
      version: (j['version'] as num?)?.toInt() ?? 0,
      turnDeadline: (j['turnDeadline'] as num?)?.toInt(),
    );
  }
}
