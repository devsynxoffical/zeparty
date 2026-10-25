import type { Cosmetic, WalletRepository } from '../../src/wallet/types.js';
import { GAME_COSMETICS } from './cosmetics_all.js';

/**
 * Cosmetic catalog. Prices are in ZCOIN. Price 0 items are defaults everyone owns.
 * preview_asset paths are relative to the assets/ root shared with the Flutter packages.
 */
export const COSMETICS: Cosmetic[] = [
  { cosmeticId: 'ludo_royale.board.imperial_palace', gameId: 'ludo_royale', category: 'board', name: 'Imperial Palace', description: 'Marble and champagne gold, the default royal chamber board.', price: 0, previewAsset: 'games/ludo_royale/boards/tex_marble_ivory.webp', enabled: true },
  { cosmeticId: 'ludo_royale.board.crystal_kingdom', gameId: 'ludo_royale', category: 'board', name: 'Crystal Kingdom', description: 'Frosted crystal tiles with ice blue illumination.', price: 400, previewAsset: 'games/ludo_royale/boards/tex_crystal_ice.webp', enabled: true },
  { cosmeticId: 'ludo_royale.board.midnight_gold', gameId: 'ludo_royale', category: 'board', name: 'Midnight Gold', description: 'Obsidian black with brushed gold inlays.', price: 600, previewAsset: 'games/ludo_royale/boards/tex_marble_obsidian.webp', enabled: true },
  { cosmeticId: 'ludo_royale.dice.crystal', gameId: 'ludo_royale', category: 'dice', name: 'Crystal Dice', description: 'Translucent crystal die with inner refractions.', price: 0, previewAsset: 'games/ludo_royale/dice/dice_crystal_1.webp', enabled: true },
  { cosmeticId: 'ludo_royale.dice.ruby', gameId: 'ludo_royale', category: 'dice', name: 'Ruby Dice', description: 'Deep ruby glass with gold pips.', price: 250, previewAsset: 'games/ludo_royale/dice/dice_ruby_1.webp', enabled: true },
  { cosmeticId: 'ludo_royale.token.classic', gameId: 'ludo_royale', category: 'token', name: 'Royal Tokens', description: 'Enamel domes with metallic gold rims.', price: 0, previewAsset: 'games/ludo_royale/tokens/token_red.webp', enabled: true },
  { cosmeticId: 'ludo_royale.token.crown', gameId: 'ludo_royale', category: 'token', name: 'Crown Tokens', description: 'Miniature jewelled crowns.', price: 350, previewAsset: 'games/ludo_royale/tokens/token_crown_red.webp', enabled: true },
  { cosmeticId: 'common.frame.gold_laurel', gameId: 'common', category: 'frame', name: 'Gold Laurel Frame', description: 'Avatar frame with animated laurel leaves.', price: 300, previewAsset: 'common/avatars/frame_gold_laurel.webp', enabled: true },
  { cosmeticId: 'common.frame.royal_crown', gameId: 'common', category: 'frame', name: 'Royal Crown Frame', description: 'Crowned avatar frame.', price: 500, previewAsset: 'common/avatars/frame_royal_crown.webp', enabled: true },
  { cosmeticId: 'common.reaction.confetti', gameId: 'common', category: 'reaction', name: 'Confetti Burst', description: 'Animated reaction.', price: 100, previewAsset: 'common/ui/reaction_confetti.webp', enabled: true },
  { cosmeticId: 'common.reaction.laugh', gameId: 'common', category: 'reaction', name: 'Royal Laugh', description: 'Animated reaction.', price: 100, previewAsset: 'common/ui/reaction_laugh.webp', enabled: true },
];

export async function seedCosmetics(repo: WalletRepository): Promise<void> {
  for (const c of [...COSMETICS, ...GAME_COSMETICS]) await repo.upsertCosmetic(c);
}
