/// Ludo board geometry on the 15x15 grid. Mirrors backend/src/games/ludo_royale/board.ts
/// and is verified against tests/fixtures/ludo_board.json so client animation targets
/// and server positions can never disagree.
///
/// Relative step per token: -1 base, 0..50 main track, 51..55 home column, 56 home.
library;

const int trackLength = 52;
const int lastTrackStep = 50;
const int homeColumnStart = 51;
const int homeStep = 56;

enum LudoColor {
  red,
  green,
  yellow,
  blue;

  static LudoColor parse(String s) => LudoColor.values.firstWhere((c) => c.name == s);
}

const Map<LudoColor, int> startIndex = {LudoColor.red: 0, LudoColor.green: 13, LudoColor.yellow: 26, LudoColor.blue: 39};
const List<int> starIndex = [8, 21, 34, 47];

class Cell {
  const Cell(this.row, this.col);
  final double row;
  final double col;
  @override
  bool operator ==(Object other) => other is Cell && other.row == row && other.col == col;
  @override
  int get hashCode => Object.hash(row, col);
  @override
  String toString() => 'Cell($row,$col)';
}

final List<Cell> trackCells = _buildTrack();

List<Cell> _buildTrack() {
  final cells = <Cell>[];
  void push(int r, int c) => cells.add(Cell(r.toDouble(), c.toDouble()));
  for (var c = 1; c <= 5; c++) {
    push(6, c);
  }
  for (var r = 5; r >= 0; r--) {
    push(r, 6);
  }
  push(0, 7);
  for (var r = 0; r <= 5; r++) {
    push(r, 8);
  }
  for (var c = 9; c <= 14; c++) {
    push(6, c);
  }
  push(7, 14);
  for (var c = 14; c >= 9; c--) {
    push(8, c);
  }
  for (var r = 9; r <= 14; r++) {
    push(r, 8);
  }
  push(14, 7);
  for (var r = 14; r >= 9; r--) {
    push(r, 6);
  }
  for (var c = 5; c >= 0; c--) {
    push(8, c);
  }
  push(7, 0);
  push(6, 0);
  return List.unmodifiable(cells);
}

final Map<LudoColor, List<Cell>> homeColumnCells = {
  LudoColor.red: [for (final c in [1, 2, 3, 4, 5]) Cell(7, c.toDouble())],
  LudoColor.green: [for (final r in [1, 2, 3, 4, 5]) Cell(r.toDouble(), 7)],
  LudoColor.yellow: [for (final c in [13, 12, 11, 10, 9]) Cell(7, c.toDouble())],
  LudoColor.blue: [for (final r in [13, 12, 11, 10, 9]) Cell(r.toDouble(), 7)],
};

const Map<LudoColor, Cell> homeCell = {
  LudoColor.red: Cell(7, 6),
  LudoColor.green: Cell(6, 7),
  LudoColor.yellow: Cell(7, 8),
  LudoColor.blue: Cell(8, 7),
};

const Map<LudoColor, List<Cell>> baseCells = {
  LudoColor.red: [Cell(1.5, 1.5), Cell(1.5, 3.5), Cell(3.5, 1.5), Cell(3.5, 3.5)],
  LudoColor.green: [Cell(1.5, 10.5), Cell(1.5, 12.5), Cell(3.5, 10.5), Cell(3.5, 12.5)],
  LudoColor.yellow: [Cell(10.5, 10.5), Cell(10.5, 12.5), Cell(12.5, 10.5), Cell(12.5, 12.5)],
  LudoColor.blue: [Cell(10.5, 1.5), Cell(10.5, 3.5), Cell(12.5, 1.5), Cell(12.5, 3.5)],
};

/// Top-left corner of each 6x6 base quadrant.
const Map<LudoColor, Cell> baseOrigin = {
  LudoColor.red: Cell(0, 0),
  LudoColor.green: Cell(0, 9),
  LudoColor.yellow: Cell(9, 9),
  LudoColor.blue: Cell(9, 0),
};

int? absoluteIndex(LudoColor color, int step) {
  if (step < 0 || step > lastTrackStep) return null;
  return (startIndex[color]! + step) % trackLength;
}

bool isStartSquare(int abs) => startIndex.values.contains(abs);
bool isStarSquare(int abs) => starIndex.contains(abs);

bool isSafeSquare(int abs, String mode) {
  if (mode == 'none') return false;
  if (isStartSquare(abs)) return true;
  return mode == 'stars_and_starts' && isStarSquare(abs);
}

Cell cellForStep(LudoColor color, int step, int tokenIndex) {
  if (step < 0) {
    final slots = baseCells[color]!;
    return slots[tokenIndex.clamp(0, slots.length - 1)];
  }
  if (step <= lastTrackStep) return trackCells[absoluteIndex(color, step)!];
  if (step < homeStep) return homeColumnCells[color]![step - homeColumnStart];
  return homeCell[color]!;
}

/// Cells visited when moving from `from` to `to` (exclusive of `from`).
List<Cell> pathCells(LudoColor color, int from, int to, int tokenIndex) {
  final out = <Cell>[];
  final start = from < 0 ? -1 : from;
  for (var s = start + 1; s <= to; s++) {
    out.add(cellForStep(color, s, tokenIndex));
  }
  return out;
}

/// Colours used for a given player count, in seat order. Mirrors the server.
List<LudoColor> colorsForPlayerCount(int n) => switch (n) {
      2 => const [LudoColor.red, LudoColor.yellow],
      3 => const [LudoColor.red, LudoColor.green, LudoColor.yellow],
      _ => LudoColor.values,
    };
