/// Logical asset paths for Mini Golf Paradise (relative to the shared `assets/`
/// root, resolved through `ZpAssets.key`). Every image is a decorative layer over
/// exact procedural geometry; the renderer falls back to drawn art when a file
/// is missing.
class MiniGolfAssets {
  MiniGolfAssets._();

  static const background = 'games/mini_golf_paradise/backgrounds/resort.webp';
  static const turf = 'games/mini_golf_paradise/boards/green_turf.webp';
  static const sand = 'games/mini_golf_paradise/boards/sand.webp';
  static const water = 'games/mini_golf_paradise/boards/water.webp';
  static const rockWall = 'games/mini_golf_paradise/boards/rock_wall.webp';
  static const ballWhite = 'games/mini_golf_paradise/pieces/ball_white.webp';
  static const ballGold = 'games/mini_golf_paradise/pieces/ball_gold.webp';
  static const flag = 'games/mini_golf_paradise/pieces/flag.webp';
  static const cardArt = 'games/mini_golf_paradise/ui/card_art.webp';
  static const particles = 'common/particles/particles_sheet.webp';

  /// Cosmetic id `mini_golf_paradise.ball.gold` swaps the ball sprite.
  static String ball(String skin) => skin == 'gold' ? ballGold : ballWhite;

  static const sfx = {
    'putt': 'games/mini_golf_paradise/audio/putt.mp3',
    'bounce': 'games/mini_golf_paradise/audio/bounce.mp3',
    'water': 'games/mini_golf_paradise/audio/water.mp3',
    'hole': 'games/mini_golf_paradise/audio/hole.mp3',
    'victory': 'games/mini_golf_paradise/audio/victory.mp3',
  };
  static const commonSfx = {
    'ui_tap': 'common/audio/ui_tap.mp3',
    'coins_award': 'common/audio/coins_award.mp3',
  };

  static List<String> preload({String ballSkin = 'white'}) => [background, turf, sand, water, rockWall, flag, particles, ball(ballSkin), ballWhite];
}
