/// Pure grid helpers mirroring backend/src/games/connect4_galaxy/engine.ts.
///
/// The client never decides a result with these; they exist so the renderer can
/// predict the landing row of a preview disc and so parity tests can check the
/// Dart mirror against the server fixtures.
library;

const int emptyCell = -1;

class GridCell {
  const GridCell(this.row, this.col);
  final int row;
  final int col;

  factory GridCell.fromJson(Map<String, dynamic> j) => GridCell((j['row'] as num).toInt(), (j['col'] as num).toInt());

  @override
  bool operator ==(Object other) => other is GridCell && other.row == row && other.col == col;
  @override
  int get hashCode => Object.hash(row, col);
  @override
  String toString() => '($row,$col)';
}

class WinInfo {
  const WinInfo(this.seat, this.line);
  final int seat;
  final List<GridCell> line;
}

/// Directions covering horizontal, vertical and both diagonals (dRow, dCol).
const List<(int, int)> _directions = [(0, 1), (1, 0), (1, 1), (1, -1)];

List<List<int>> emptyGrid(int rows, int columns) => List.generate(rows, (_) => List.filled(columns, emptyCell));

/// Lowest empty row in [column] (row 0 is the bottom), or -1 when full.
int landingRow(List<List<int>> grid, int column) {
  for (var r = 0; r < grid.length; r++) {
    if (grid[r][column] == emptyCell) return r;
  }
  return -1;
}

List<int> legalColumnsOf(List<List<int>> grid) {
  final cols = grid.isEmpty ? 0 : grid[0].length;
  return [for (var c = 0; c < cols; c++) if (landingRow(grid, c) >= 0) c];
}

bool isGridFull(List<List<int>> grid) => legalColumnsOf(grid).isEmpty;

/// Line of [connect] same-seat discs through (row, col), ordered from the
/// lowest-left end, or null. Mirrors `findWinningLine` on the server.
List<GridCell>? findWinningLine(List<List<int>> grid, int row, int col, int connect) {
  final rows = grid.length;
  final cols = rows == 0 ? 0 : grid[0].length;
  if (row < 0 || row >= rows || col < 0 || col >= cols) return null;
  final seat = grid[row][col];
  if (seat == emptyCell) return null;
  for (final (dr, dc) in _directions) {
    final line = <GridCell>[GridCell(row, col)];
    var r = row - dr;
    var c = col - dc;
    while (r >= 0 && r < rows && c >= 0 && c < cols && grid[r][c] == seat) {
      line.insert(0, GridCell(r, c));
      r -= dr;
      c -= dc;
    }
    r = row + dr;
    c = col + dc;
    while (r >= 0 && r < rows && c >= 0 && c < cols && grid[r][c] == seat) {
      line.add(GridCell(r, c));
      r += dr;
      c += dc;
    }
    if (line.length >= connect) return line.sublist(0, connect);
  }
  return null;
}

/// Scans the whole grid for any winning line. Mirrors `findAnyWin` on the server.
WinInfo? findAnyWin(List<List<int>> grid, int connect) {
  for (var r = 0; r < grid.length; r++) {
    for (var c = 0; c < grid[r].length; c++) {
      final seat = grid[r][c];
      if (seat == emptyCell) continue;
      for (final (dr, dc) in _directions) {
        final line = <GridCell>[];
        var rr = r;
        var cc = c;
        while (rr >= 0 && rr < grid.length && cc >= 0 && cc < grid[rr].length && grid[rr][cc] == seat && line.length < connect) {
          line.add(GridCell(rr, cc));
          rr += dr;
          cc += dc;
        }
        if (line.length >= connect) return WinInfo(seat, line);
      }
    }
  }
  return null;
}
