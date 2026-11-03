import { LudoEngine } from './ludo_royale/engine.js';
import { engine as connect4Engine } from './connect4_galaxy/index.js';
import { engine as snakeLadderEngine } from './snake_ladder_kingdom/index.js';
import { engine as chessEngine } from './chess_legends/index.js';
import { engine as colorClashEngine } from './color_clash/index.js';
import { engine as carromEngine } from './carrom_masters/index.js';
import { engine as poolEngine } from './pool_elite/index.js';
import { engine as airHockeyEngine } from './air_hockey/index.js';
import { engine as dartsEngine } from './darts_arena/index.js';
import { engine as miniGolfEngine } from './mini_golf_paradise/index.js';
export const GAME_CATALOG = [
    {
        gameId: 'ludo_royale',
        title: 'Ludo Royale',
        tagline: 'Imperial palace, crystal dice',
        description: 'The classic race in a marble and gold royal chamber. Roll a six to leave the palace gates, capture rivals, race all four tokens home.',
        theme: 'Imperial Palace',
        minPlayers: 2,
        maxPlayers: 4,
        kind: 'turn_based',
        authority: 'server_turn_based',
        status: 'available',
        artwork: 'games/ludo_royale/ui/card_art.webp',
        accent: '#C9A227',
    },
    { gameId: 'connect4_galaxy', title: 'Connect 4 Galaxy', tagline: 'Four in a row among the stars', description: 'Drop glowing energy discs into a crystal grid floating in deep space.', theme: 'Galactic Strategy Chamber', minPlayers: 2, maxPlayers: 2, kind: 'turn_based', authority: 'server_turn_based', status: 'available', artwork: 'games/connect4_galaxy/ui/card_art.webp', accent: '#5B7CFF' },
    { gameId: 'snake_ladder_kingdom', title: 'Snake & Ladder Kingdom', tagline: 'Climb the floating isles', description: 'A miniature fantasy kingdom where ladders are golden and snakes are friendly dragons.', theme: 'Fantasy Kingdom', minPlayers: 2, maxPlayers: 4, kind: 'turn_based', authority: 'server_turn_based', status: 'available', artwork: 'games/snake_ladder_kingdom/ui/card_art.webp', accent: '#3DBE7A' },
    { gameId: 'chess_legends', title: 'Chess Legends', tagline: 'Obsidian and crystal', description: 'Full chess with time controls in the Grandmaster Hall.', theme: 'Royal Grandmaster Hall', minPlayers: 2, maxPlayers: 2, kind: 'turn_based', authority: 'server_turn_based', status: 'available', artwork: 'games/chess_legends/ui/card_art.webp', accent: '#B8C4D6' },
    { gameId: 'color_clash', title: 'Color Clash', tagline: 'Holographic card arena', description: 'An original colour and number matching card game with ZeParty action cards.', theme: 'Holographic Card Arena', minPlayers: 2, maxPlayers: 6, kind: 'turn_based', authority: 'server_turn_based', status: 'available', artwork: 'games/color_clash/ui/card_art.webp', accent: '#FF4FA3' },
    { gameId: 'carrom_masters', title: 'Carrom Masters', tagline: 'Luxury heritage club', description: 'Photoreal walnut board, precise striker physics.', theme: 'Luxury Heritage Club', minPlayers: 2, maxPlayers: 4, kind: 'physics_shot', authority: 'server_shot_validated', status: 'available', artwork: 'games/carrom_masters/ui/card_art.webp', accent: '#A86B3C' },
    { gameId: 'pool_elite', title: '8 Ball Pool Elite', tagline: 'Private billiards lounge', description: 'Cinematic 8-ball with authoritative shot resolution.', theme: 'Private Luxury Billiards Lounge', minPlayers: 2, maxPlayers: 2, kind: 'physics_shot', authority: 'server_shot_validated', status: 'available', artwork: 'games/pool_elite/ui/card_art.webp', accent: '#1F7A4D' },
    { gameId: 'air_hockey', title: 'Neon Air Hockey', tagline: 'Futuristic arena', description: 'Real-time neon air hockey with latency-aware sync.', theme: 'Futuristic Competitive Arena', minPlayers: 2, maxPlayers: 2, kind: 'physics_realtime', authority: 'server_realtime', status: 'available', artwork: 'games/air_hockey/ui/card_art.webp', accent: '#19E6FF' },
    { gameId: 'darts_arena', title: 'Darts Arena', tagline: 'Premium sports lounge', description: 'Authentic dartboard, skill-based throws.', theme: 'Premium Competitive Sports Lounge', minPlayers: 2, maxPlayers: 4, kind: 'physics_shot', authority: 'server_shot_validated', status: 'available', artwork: 'games/darts_arena/ui/card_art.webp', accent: '#D9452B' },
    { gameId: 'mini_golf_paradise', title: 'Mini Golf Paradise', tagline: 'Fantasy tropical resort', description: 'Five island courses with moving obstacles and waterfalls.', theme: 'Fantasy Tropical Resort', minPlayers: 2, maxPlayers: 4, kind: 'physics_shot', authority: 'server_shot_validated', status: 'available', artwork: 'games/mini_golf_paradise/ui/card_art.webp', accent: '#2BC0B4' },
];
const engines = {
    ludo_royale: new LudoEngine(),
    connect4_galaxy: connect4Engine,
    snake_ladder_kingdom: snakeLadderEngine,
    chess_legends: chessEngine,
    color_clash: colorClashEngine,
    carrom_masters: carromEngine,
    pool_elite: poolEngine,
    air_hockey: airHockeyEngine,
    darts_arena: dartsEngine,
    mini_golf_paradise: miniGolfEngine,
};
for (const g of GAME_CATALOG)
    if (engines[g.gameId])
        g.status = 'available';
export function getEngine(gameId) {
    return engines[gameId] ?? null;
}
export function getCatalogEntry(gameId) {
    return GAME_CATALOG.find((g) => g.gameId === gameId) ?? null;
}
export function registerEngine(gameId, engine) {
    engines[gameId] = engine;
    const entry = getCatalogEntry(gameId);
    if (entry)
        entry.status = 'available';
}
