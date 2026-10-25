/// Logical asset paths for Snake & Ladder Kingdom (see docs/architecture/game_module_contract.md).
/// Every image is optional at runtime: the renderer falls back to procedural art.
class KingdomAssets {
  KingdomAssets._();
  static const background = 'games/snake_ladder_kingdom/backgrounds/kingdom.webp';
  static const islandTile = 'games/snake_ladder_kingdom/boards/island_tile.webp';
  static const ladder = 'games/snake_ladder_kingdom/boards/ladder.webp';
  static const dragonHead = 'games/snake_ladder_kingdom/boards/dragon_head.webp';
  static const dragonTail = 'games/snake_ladder_kingdom/boards/dragon_tail.webp';
  static const cardArt = 'games/snake_ladder_kingdom/ui/card_art.webp';
  static String knight(String color) => 'games/snake_ladder_kingdom/characters/knight_$color.webp';

  /// Crystal dice are shared with Ludo Royale.
  static String dice(int face) => 'games/ludo_royale/dice/dice_crystal_$face.webp';
  static const particles = 'common/particles/particles_sheet.webp';

  static const sfx = {
    'step': 'games/snake_ladder_kingdom/audio/step.mp3',
    'ladder': 'games/snake_ladder_kingdom/audio/ladder.mp3',
    'snake': 'games/snake_ladder_kingdom/audio/snake.mp3',
    'victory': 'games/snake_ladder_kingdom/audio/victory.mp3',
    'dice_roll': 'games/ludo_royale/audio/dice_roll.mp3',
    'turn_change': 'games/ludo_royale/audio/turn_change.mp3',
    'extra_turn': 'games/ludo_royale/audio/extra_turn.mp3',
    'illegal_move': 'games/ludo_royale/audio/illegal_move.mp3',
  };
  static const commonSfx = {
    'ui_tap': 'common/audio/ui_tap.mp3',
    'coins_award': 'common/audio/coins_award.mp3',
  };

  static List<String> preload() => [
        background,
        islandTile,
        ladder,
        dragonHead,
        dragonTail,
        particles,
        for (final c in ['red', 'green', 'yellow', 'blue']) knight(c),
        for (var i = 1; i <= 6; i++) dice(i),
      ];
}
