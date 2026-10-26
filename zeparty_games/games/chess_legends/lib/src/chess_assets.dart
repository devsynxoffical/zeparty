/// Logical asset paths for Chess Legends (see docs/architecture/game_module_contract.md).
/// Every image is optional: the renderer falls back to procedural drawing.
class ChessAssets {
  ChessAssets._();

  static const background = 'games/chess_legends/backgrounds/hall.webp';
  static const cardArt = 'games/chess_legends/ui/card_art.webp';
  static const particles = 'common/particles/particles_sheet.webp';

  /// Square texture pairs per board skin: (dark squares, light squares).
  static const boardTextures = {
    'obsidian': ('games/chess_legends/boards/tex_obsidian.webp', 'games/ludo_royale/boards/tex_marble_obsidian.webp'),
    'ivory': ('games/chess_legends/boards/tex_ivory.webp', 'games/ludo_royale/boards/tex_marble_ivory.webp'),
  };

  static const pieceNames = {'k': 'king', 'q': 'queen', 'r': 'rook', 'b': 'bishop', 'n': 'knight', 'p': 'pawn'};

  /// [type] is a lowercase FEN letter, [white] selects the colour.
  static String piece(String type, {required bool white}) => 'games/chess_legends/pieces/${white ? 'white' : 'black'}_${pieceNames[type] ?? 'pawn'}.webp';

  static const sfx = {
    'move': 'games/chess_legends/audio/move.mp3',
    'capture': 'games/chess_legends/audio/capture.mp3',
    'check': 'games/chess_legends/audio/check.mp3',
    'checkmate': 'games/chess_legends/audio/checkmate.mp3',
  };
  static const commonSfx = {
    'ui_tap': 'common/audio/ui_tap.mp3',
    'coins_award': 'common/audio/coins_award.mp3',
  };

  static List<String> preload({String board = 'obsidian'}) => [
        background,
        boardTextures[board]!.$1,
        boardTextures[board]!.$2,
        particles,
        for (final t in pieceNames.keys) ...[piece(t, white: true), piece(t, white: false)],
      ];
}
