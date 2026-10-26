/// Logical asset paths for 8 Ball Pool Elite (relative to the shared `assets/`
/// root, resolved through `ZpAssets.key`). Every image is a decorative layer
/// over exact procedural geometry; the renderer falls back to drawing when a
/// file is missing.
class PoolAssets {
  PoolAssets._();

  static const background = 'games/pool_elite/backgrounds/lounge.webp';
  static const felt = 'games/pool_elite/boards/table_felt.webp';
  static const railWood = 'games/pool_elite/boards/table_rail_wood.webp';
  static const cardArt = 'games/pool_elite/ui/card_art.webp';
  static const particles = 'common/particles/particles_sheet.webp';

  /// Ball sprite: 0 is the cue ball, 1..15 the numbered balls.
  static String ball(int id) => id == 0 ? 'games/pool_elite/balls/ball_cue.webp' : 'games/pool_elite/balls/ball_$id.webp';

  /// Cue sprite for a cosmetic skin ('classic' or 'ebony'), horizontal, tip at the left.
  static String cue(String skin) => skin == 'ebony' ? 'games/pool_elite/cues/cue_ebony.webp' : 'games/pool_elite/cues/cue_classic.webp';

  static const sfx = {
    'cue_hit': 'games/pool_elite/audio/cue_hit.mp3',
    'ball_hit': 'games/pool_elite/audio/ball_hit.mp3',
    'cushion': 'games/pool_elite/audio/cushion.mp3',
    'pocket': 'games/pool_elite/audio/pocket.mp3',
    'victory': 'games/pool_elite/audio/victory.mp3',
  };
  static const commonSfx = {
    'ui_tap': 'common/audio/ui_tap.mp3',
    'coins_award': 'common/audio/coins_award.mp3',
  };

  static List<String> preload({String cueSkin = 'classic'}) => [
        background,
        felt,
        railWood,
        particles,
        cue(cueSkin),
        for (var i = 0; i <= 15; i++) ball(i),
      ];
}
