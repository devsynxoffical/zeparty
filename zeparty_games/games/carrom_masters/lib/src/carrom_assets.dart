/// Logical asset paths for Carrom Masters (relative to the shared `assets/`
/// root, resolved through `ZpAssets.key`). Every image is a decorative layer:
/// the playfield geometry is drawn by code and each image has a procedural
/// fallback when the file is missing.
class CarromAssets {
  CarromAssets._();

  static const background = 'games/carrom_masters/backgrounds/club.webp';
  static const frame = 'games/carrom_masters/boards/walnut_frame.webp';
  static const playfield = 'games/carrom_masters/boards/playfield_wood.webp';
  static const striker = 'games/carrom_masters/pieces/striker.webp';
  static const coinWhite = 'games/carrom_masters/pieces/coin_white.webp';
  static const coinBlack = 'games/carrom_masters/pieces/coin_black.webp';
  static const coinQueen = 'games/carrom_masters/pieces/coin_queen.webp';
  static const cardArt = 'games/carrom_masters/ui/card_art.webp';
  static const particles = 'common/particles/particles_sheet.webp';

  static const sfx = {
    'strike': 'games/carrom_masters/audio/strike.mp3',
    'coin_hit': 'games/carrom_masters/audio/coin_hit.mp3',
    'pocket': 'games/carrom_masters/audio/pocket.mp3',
    'foul': 'games/carrom_masters/audio/foul.mp3',
    'victory': 'games/carrom_masters/audio/victory.mp3',
  };
  static const commonSfx = {
    'ui_tap': 'common/audio/ui_tap.mp3',
    'coins_award': 'common/audio/coins_award.mp3',
  };

  static List<String> preload() => [background, frame, playfield, striker, coinWhite, coinBlack, coinQueen, particles];
}
