/// Logical asset paths for Darts Arena (relative to the shared `assets/` root,
/// resolved through `ZpAssets.key`). Every image is a decorative layer over the
/// exact procedural scoring geometry; the renderer falls back to procedural art
/// when a file is missing.
class DartsAssets {
  DartsAssets._();

  static const background = 'games/darts_arena/backgrounds/lounge.webp';
  static const board = 'games/darts_arena/boards/dartboard.webp';
  static const cardArt = 'games/darts_arena/ui/card_art.webp';
  static const particles = 'common/particles/particles_sheet.webp';

  /// Dart sprite for a skin: 'steel' (default) or 'gold' (cosmetic `darts_arena.dart.gold`).
  static String dart(String skin) => skin == 'gold' ? 'games/darts_arena/pieces/dart_gold.webp' : 'games/darts_arena/pieces/dart_steel.webp';

  static const sfx = {
    'throw': 'games/darts_arena/audio/throw.mp3',
    'hit_board': 'games/darts_arena/audio/hit_board.mp3',
    'bullseye': 'games/darts_arena/audio/bullseye.mp3',
    'victory': 'games/darts_arena/audio/victory.mp3',
  };
  static const commonSfx = {
    'ui_tap': 'common/audio/ui_tap.mp3',
    'coins_award': 'common/audio/coins_award.mp3',
  };

  static List<String> preload({String dartSkin = 'steel'}) => [background, board, particles, dart(dartSkin)];
}
