/// Logical asset paths for Connect 4 Galaxy (relative to the shared `assets/`
/// root, resolved through `ZpAssets.key`). Every image here is a decorative
/// layer; the renderer falls back to procedural drawing when a file is missing.
class Connect4Assets {
  Connect4Assets._();

  static const background = 'games/connect4_galaxy/backgrounds/galaxy.webp';
  static const frame = 'games/connect4_galaxy/boards/frame_crystal.webp';
  static const cardArt = 'games/connect4_galaxy/ui/card_art.webp';
  static const particles = 'common/particles/particles_sheet.webp';

  /// Disc image for a seat (0 = blue, 1 = gold) and skin ('classic' or 'plasma').
  static String disc(String skin, int seat) {
    final color = seat == 0 ? 'blue' : 'gold';
    return skin == 'plasma' ? 'games/connect4_galaxy/discs/disc_plasma_$color.webp' : 'games/connect4_galaxy/discs/disc_$color.webp';
  }

  static const sfx = {
    'disc_drop': 'games/connect4_galaxy/audio/disc_drop.mp3',
    'disc_land': 'games/connect4_galaxy/audio/disc_land.mp3',
    'win_line': 'games/connect4_galaxy/audio/win_line.mp3',
    'victory': 'games/connect4_galaxy/audio/victory.mp3',
  };
  static const commonSfx = {
    'ui_tap': 'common/audio/ui_tap.mp3',
    'coins_award': 'common/audio/coins_award.mp3',
  };

  static List<String> preload({String discSkin = 'classic'}) => [
        background,
        frame,
        particles,
        disc(discSkin, 0),
        disc(discSkin, 1),
      ];
}
