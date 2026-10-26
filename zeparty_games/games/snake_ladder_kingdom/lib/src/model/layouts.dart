import 'dart:math' as math;

/// Mirror of backend/src/games/snake_ladder_kingdom/layouts.ts. The server embeds the
/// resolved layout in every state, so this copy is only a fallback for states that
/// omit it and for parity tests against tests/fixtures/snake_ladder_kingdom_layouts.json.
class Link {
  const Link(this.from, this.to);
  final int from;
  final int to;

  factory Link.fromJson(Map<String, dynamic> j) => Link(j['from'] as int, j['to'] as int);

  @override
  bool operator ==(Object other) => other is Link && other.from == from && other.to == to;
  @override
  int get hashCode => Object.hash(from, to);
  @override
  String toString() => 'Link($from->$to)';
}

class BoardLayout {
  const BoardLayout({required this.id, required this.boardSize, required this.ladders, required this.snakes});
  final String id;
  final int boardSize;
  final List<Link> ladders;
  final List<Link> snakes;

  factory BoardLayout.fromJson(Map<String, dynamic> j) => BoardLayout(
        id: j['id'] as String,
        boardSize: j['boardSize'] as int,
        ladders: (j['ladders'] as List<dynamic>).map((l) => Link.fromJson(l as Map<String, dynamic>)).toList(),
        snakes: (j['snakes'] as List<dynamic>).map((l) => Link.fromJson(l as Map<String, dynamic>)).toList(),
      );

  Link? ladderAt(int square) => ladders.where((l) => l.from == square).firstOrNull;
  Link? snakeAt(int square) => snakes.where((s) => s.from == square).firstOrNull;
}

const Map<int, Map<String, BoardLayout>> kLayouts = {
  100: {
    'kingdom_a': BoardLayout(
      id: 'kingdom_a',
      boardSize: 100,
      ladders: [Link(4, 14), Link(9, 31), Link(20, 38), Link(28, 84), Link(40, 59), Link(51, 67), Link(63, 81), Link(71, 91)],
      snakes: [Link(17, 7), Link(54, 34), Link(62, 19), Link(64, 60), Link(87, 24), Link(93, 73), Link(95, 75), Link(99, 78)],
    ),
    'kingdom_b': BoardLayout(
      id: 'kingdom_b',
      boardSize: 100,
      ladders: [Link(3, 22), Link(11, 26), Link(15, 44), Link(36, 57), Link(47, 66), Link(56, 77), Link(70, 90), Link(82, 98)],
      snakes: [Link(27, 5), Link(41, 21), Link(52, 30), Link(68, 49), Link(79, 58), Link(88, 67), Link(94, 71), Link(97, 86)],
    ),
  },
  64: {
    'kingdom_a': BoardLayout(
      id: 'kingdom_a',
      boardSize: 64,
      ladders: [Link(3, 17), Link(8, 26), Link(19, 38), Link(29, 47), Link(42, 60), Link(50, 55)],
      snakes: [Link(14, 4), Link(24, 11), Link(35, 21), Link(46, 31), Link(58, 40), Link(63, 52)],
    ),
    'kingdom_b': BoardLayout(
      id: 'kingdom_b',
      boardSize: 64,
      ladders: [Link(5, 20), Link(12, 33), Link(22, 41), Link(30, 52), Link(37, 57), Link(49, 62)],
      snakes: [Link(16, 2), Link(27, 9), Link(39, 18), Link(45, 28), Link(56, 36), Link(61, 44)],
    ),
  },
};

BoardLayout layoutFor(int boardSize, String id) => kLayouts[boardSize]?[id] ?? kLayouts[100]!['kingdom_a']!;

int columnsFor(int boardSize) => math.sqrt(boardSize).round();

/// Grid cell with row 0 at the bottom (the renderer flips y).
class Cell {
  const Cell(this.row, this.col);
  final int row;
  final int col;

  @override
  bool operator ==(Object other) => other is Cell && other.row == row && other.col == col;
  @override
  int get hashCode => Object.hash(row, col);
  @override
  String toString() => 'Cell($row,$col)';
}

/// Boustrophedon path: square 1 bottom-left, row 0 left to right, row 1 right to left.
Cell cellForSquare(int square, int boardSize) {
  final cols = columnsFor(boardSize);
  final idx = square - 1;
  final row = idx ~/ cols;
  final inRow = idx % cols;
  final col = row.isEven ? inRow : cols - 1 - inRow;
  return Cell(row, col);
}
