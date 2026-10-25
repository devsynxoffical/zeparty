/// Pure helpers for squares and FEN piece placement. The client never generates
/// moves; it only needs to know where pieces stand so it can draw them.
library;

const String files = 'abcdefgh';

/// 0-based file index of an algebraic square ('e4' -> 4).
int fileOf(String square) => files.indexOf(square[0]);

/// 0-based rank index of an algebraic square ('e4' -> 3).
int rankOf(String square) => int.parse(square[1]) - 1;

String squareName(int file, int rank) => '${files[file]}${rank + 1}';

bool isValidSquare(String s) => s.length == 2 && files.contains(s[0]) && rankOf(s) >= 0 && rankOf(s) <= 7;

/// Light squares (a1 is dark).
bool isLightSquare(String square) => (fileOf(square) + rankOf(square)).isOdd;

bool isWhitePiece(String piece) => piece.toUpperCase() == piece;

/// Material value used for the HUD difference indicator.
int pieceValue(String type) => switch (type.toLowerCase()) { 'p' => 1, 'n' => 3, 'b' => 3, 'r' => 5, 'q' => 9, _ => 0 };

/// Parsed piece placement of a FEN string: square -> FEN letter.
class BoardPlacement {
  const BoardPlacement(this.pieces, {required this.whiteToMove, this.castling = '-', this.enPassant = '-', this.halfmove = 0, this.fullmove = 1});

  final Map<String, String> pieces;
  final bool whiteToMove;
  final String castling;
  final String enPassant;
  final int halfmove;
  final int fullmove;

  static const BoardPlacement empty = BoardPlacement({}, whiteToMove: true);

  factory BoardPlacement.parse(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) throw FormatException('empty FEN', fen);
    final ranks = parts[0].split('/');
    if (ranks.length != 8) throw FormatException('FEN needs 8 ranks', fen);
    final map = <String, String>{};
    for (var r = 0; r < 8; r++) {
      final rank = 7 - r;
      var file = 0;
      for (final ch in ranks[r].split('')) {
        final digit = int.tryParse(ch);
        if (digit != null) {
          file += digit;
        } else {
          if (!'pnbrqkPNBRQK'.contains(ch) || file > 7) throw FormatException('bad piece "$ch"', fen);
          map[squareName(file, rank)] = ch;
          file++;
        }
      }
      if (file != 8) throw FormatException('rank $rank does not add up to 8', fen);
    }
    return BoardPlacement(
      Map.unmodifiable(map),
      whiteToMove: parts.length < 2 || parts[1] != 'b',
      castling: parts.length > 2 ? parts[2] : '-',
      enPassant: parts.length > 3 ? parts[3] : '-',
      halfmove: parts.length > 4 ? int.tryParse(parts[4]) ?? 0 : 0,
      fullmove: parts.length > 5 ? int.tryParse(parts[5]) ?? 1 : 1,
    );
  }

  String? at(String square) => pieces[square];

  /// Square of the king of the given colour, or null in malformed positions.
  String? kingSquare({required bool white}) {
    final k = white ? 'K' : 'k';
    for (final e in pieces.entries) {
      if (e.value == k) return e.key;
    }
    return null;
  }

  int get pieceCount => pieces.length;
}
