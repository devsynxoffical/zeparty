/// Logical asset paths for Color Clash (see docs/architecture/game_module_contract.md).
/// Every image is optional: the renderer draws a procedural holographic card when a
/// file is missing, so these are decorative overlays only.
class ColorClashAssets {
  ColorClashAssets._();

  static const background = 'games/color_clash/backgrounds/arena.webp';
  static const cardBack = 'games/color_clash/cards/card_back.webp';
  static const cardArt = 'games/color_clash/ui/card_art.webp';
  static const particles = 'common/particles/particles_sheet.webp';

  /// Blank holographic faces keyed by the contract's colour file names.
  static const faces = {
    'ruby': 'games/color_clash/cards/card_face_red.webp',
    'sapphire': 'games/color_clash/cards/card_face_blue.webp',
    'emerald': 'games/color_clash/cards/card_face_green.webp',
    'gold': 'games/color_clash/cards/card_face_gold.webp',
  };

  /// Transparent action icons keyed by card kind. Echo has no file and is always drawn.
  static const symbols = {
    'skip': 'games/color_clash/cards/symbol_skip.webp',
    'flip': 'games/color_clash/cards/symbol_reverse.webp',
    'surge': 'games/color_clash/cards/symbol_draw2.webp',
    'prism': 'games/color_clash/cards/symbol_wild.webp',
    'prism_surge': 'games/color_clash/cards/symbol_draw4.webp',
  };

  static const sfx = {
    'card_draw': 'games/color_clash/audio/card_draw.mp3',
    'card_play': 'games/color_clash/audio/card_play.mp3',
    'action': 'games/color_clash/audio/action.mp3',
    'last_card': 'games/color_clash/audio/last_card.mp3',
    'victory': 'games/color_clash/audio/victory.mp3',
  };
  static const commonSfx = {
    'ui_tap': 'common/audio/ui_tap.mp3',
    'coins_award': 'common/audio/coins_award.mp3',
  };

  static List<String> preload() => [background, cardBack, particles, ...faces.values, ...symbols.values];
}
