/// Logical asset paths for Neon Air Hockey (relative to the shared `assets/`
/// root, resolved through `ZpAssets.key`). Every image is a decorative layer
/// over exact procedural geometry; the renderer falls back to drawing when a
/// file is missing.
class AirHockeyAssets {
  AirHockeyAssets._();

  static const background = 'games/air_hockey/backgrounds/arena.webp';
  static const surface = 'games/air_hockey/boards/surface_glass.webp';
  static const puck = 'games/air_hockey/pieces/puck.webp';
  static const paddleCyan = 'games/air_hockey/pieces/paddle_cyan.webp';
  static const paddleMagenta = 'games/air_hockey/pieces/paddle_magenta.webp';
  static const cardArt = 'games/air_hockey/ui/card_art.webp';
  static const particles = 'common/particles/particles_sheet.webp';

  static const sfx = {
    'hit': 'games/air_hockey/audio/hit.mp3',
    'wall': 'games/air_hockey/audio/wall.mp3',
    'goal': 'games/air_hockey/audio/goal.mp3',
    'victory': 'games/air_hockey/audio/victory.mp3',
  };
  static const commonSfx = {
    'ui_tap': 'common/audio/ui_tap.mp3',
    'coins_award': 'common/audio/coins_award.mp3',
  };

  static List<String> preload() => [background, surface, puck, paddleCyan, paddleMagenta, particles];
}
