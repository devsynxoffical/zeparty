/**
 * Canonical ZeParty 6-Game Catalog Constants & Registry
 * Authoritative source for official skill, timing, and puzzle games.
 * Compliant with Google Play & Apple App Store skill game guidelines.
 */

export const GAME_CATEGORIES = {
  ARCADE: 'Arcade',
  SPORTS: 'Sports & Skill',
  PUZZLE: 'Puzzle & Strategy',
  REFLEX: 'Reflex & Timing',
  RUNNER: 'Endless Runner',
};

export const CANONICAL_GAMES = [
  {
    id: 'fishing',
    gameKey: 'FISHING',
    name: 'Fishing',
    category: GAME_CATEGORIES.ARCADE,
    tagline: 'Arcade fish shooter with waves & boss battles',
    description: 'Aim and shoot nets to catch fish, build combo multipliers, survive waves and defeat the giant boss.',
    energyCost: 1,
    usesEnergy: true,
    avgDurationSec: 180,
    isActive: true,
    icon: '🎣',
    badge: 'ARCADE',
    gradient: ['#00C6FF', '#0072FF'],
    accentColor: '#00D2FF',
    modes: ['Classic Waves (10 Waves)', 'Boss Rush', 'Endless Challenge'],
    boosters: [
      { id: 'double_cannon', name: 'Double Cannon', description: 'Two nets per shot for one run', rpPrice: 200, coinPrice: 50 },
      { id: 'freeze_net', name: 'Freeze Net', description: 'One manual freeze per wave', rpPrice: 150, coinPrice: 40 },
      { id: 'wide_net', name: 'Wide Net', description: '30% larger net radius', rpPrice: 180, coinPrice: 45 },
      { id: 'heat_shield', name: 'Heat Shield', description: 'No overheating for one run', rpPrice: 150, coinPrice: 40 },
    ],
    rpBands: [
      { maxScore: 2000, rp: 10 },
      { maxScore: 8000, rp: 20 },
      { maxScore: 15000, rp: 35 },
      { maxScore: Infinity, rp: 50 },
    ],
  },
  {
    id: 'football',
    gameKey: 'FOOTBALL',
    name: 'Football',
    category: GAME_CATEGORIES.SPORTS,
    tagline: 'Penalty shootout with timing & curve accuracy',
    description: 'Aim with curve swipe, time the power bar sweet spot, score goals, and dive as a goalkeeper.',
    energyCost: 0,
    usesEnergy: false,
    avgDurationSec: 120,
    isActive: true,
    icon: '⚽',
    badge: 'SPORTS',
    gradient: ['#11998E', '#38EF7D'],
    accentColor: '#38EF7D',
    modes: ['Quick Shootout vs AI', '1 vs 1 Realtime', 'Host Challenge', 'Daily Ladder'],
    boosters: [
      { id: 'slow_power_bar', name: 'Slow Power Bar', description: 'Slows down the power indicator in practice', rpPrice: 150, coinPrice: 40 },
      { id: 'gold_striker_kit', name: 'Gold Striker Kit', description: 'Cosmetic gold kit & cleats', rpPrice: 800, coinPrice: 150 },
      { id: 'stadium_night_theme', name: 'Neon Stadium', description: 'Custom illuminated stadium theme', rpPrice: 1500, coinPrice: 300 },
    ],
    rpBands: [
      { maxScore: 300, rp: 15 },
      { maxScore: 600, rp: 30 },
      { maxScore: Infinity, rp: 45 },
    ],
  },
  {
    id: 'fruit_match',
    gameKey: 'FRUIT_MATCH',
    name: 'Fruit Match',
    category: GAME_CATEGORIES.PUZZLE,
    tagline: 'Match-3 puzzle with 60+ progressive levels',
    description: 'Swap adjacent fruits to clear targets within move limits. Create striped, bomb, and rainbow fruit combos.',
    energyCost: 0,
    usesEnergy: false,
    avgDurationSec: 150,
    isActive: true,
    icon: '🍓',
    badge: 'PUZZLE',
    gradient: ['#FF512F', '#DD2476'],
    accentColor: '#FF512F',
    modes: ['Level Journey (60 Levels)', 'Star Challenge', 'Endless Match'],
    boosters: [
      { id: 'extra_moves', name: 'Extra Moves (+5)', description: '+5 moves once per level', rpPrice: 150, coinPrice: 30 },
      { id: 'fruit_hammer', name: 'Fruit Hammer', description: 'Smash and remove any single tile', rpPrice: 100, coinPrice: 25 },
      { id: 'board_shuffle', name: 'Board Shuffle', description: 'Reshuffle the fruit layout', rpPrice: 100, coinPrice: 25 },
      { id: 'rainbow_start', name: 'Rainbow Start', description: 'Begin level with a Rainbow Fruit', rpPrice: 200, coinPrice: 50 },
    ],
    rpBands: [
      { maxScore: 3000, rp: 20 },
      { maxScore: 6000, rp: 35 },
      { maxScore: Infinity, rp: 50 },
    ],
  },
  {
    id: 'rocket_challenge',
    gameKey: 'ROCKET_CHALLENGE',
    name: 'Rocket Challenge',
    category: GAME_CATEGORIES.REFLEX,
    tagline: 'Precision timing reflex challenge to target altitudes',
    description: 'Launch the rocket and tap STOP at the exact target altitude. Precision timing scores Perfects and streaks.',
    energyCost: 0,
    usesEnergy: false,
    avgDurationSec: 90,
    isActive: true,
    icon: '🚀',
    badge: 'TIMING',
    gradient: ['#8E2DE2', '#4A00E0'],
    accentColor: '#8E2DE2',
    modes: ['Classic (10 Rounds)', 'Endurance (3 Misses)', 'Duel Mode'],
    boosters: [
      { id: 'slow_motion', name: 'Slow Motion', description: 'Slows the last 0.5s before target zone (3 rounds)', rpPrice: 250, coinPrice: 60 },
      { id: 'second_chance', name: 'Second Chance', description: 'Re-do one missed round', rpPrice: 200, coinPrice: 50 },
      { id: 'cosmic_trail', name: 'Cosmic Star Trail', description: 'Glowing stellar particle trail', rpPrice: 800, coinPrice: 150 },
    ],
    rpBands: [
      { maxScore: 400, rp: 10 },
      { maxScore: 700, rp: 20 },
      { maxScore: 900, rp: 35 },
      { maxScore: Infinity, rp: 50 },
    ],
  },
  {
    id: 'lion_adventure',
    gameKey: 'LION_ADVENTURE',
    name: 'Lion Adventure',
    category: GAME_CATEGORIES.RUNNER,
    tagline: '3-lane endless runner through jungle ruins',
    description: 'Swipe left/right to change lanes, jump over logs and slide under branches. Collect gems and powers.',
    energyCost: 1,
    usesEnergy: true,
    avgDurationSec: 180,
    isActive: true,
    icon: '🦁',
    badge: 'RUNNER',
    gradient: ['#F7971E', '#FFD200'],
    accentColor: '#FFD200',
    modes: ['Jungle Run', 'Ruins Sprint', 'Night Hunt'],
    boosters: [
      { id: 'start_shield', name: 'Start Shield', description: 'Begin run with protective bubble', rpPrice: 150, coinPrice: 40 },
      { id: 'head_start', name: 'Head Start (+300m)', description: 'Rocket boost first 300 meters', rpPrice: 150, coinPrice: 40 },
      { id: 'revive_token', name: 'Revive Token', description: 'Instant one-time revive on crash', rpPrice: 200, coinPrice: 50 },
      { id: 'crown_outfit', name: 'Royal Crown Skin', description: 'Golden King Lion cosmetic skin', rpPrice: 1200, coinPrice: 250 },
    ],
    rpBands: [
      { maxScore: 500, rp: 10 },
      { maxScore: 1500, rp: 20 },
      { maxScore: 3000, rp: 35 },
      { maxScore: Infinity, rp: 50 },
    ],
  },
  {
    id: 'seven_puzzle',
    gameKey: 'SEVEN_PUZZLE',
    name: 'Seven Puzzle',
    category: GAME_CATEGORIES.PUZZLE,
    tagline: '5x7 number merge puzzle with 7-burst cascades',
    description: 'Drop numbered tiles into columns. Merge equal numbers to reach 7, clear neighbors, and trigger chain reactions.',
    energyCost: 0,
    usesEnergy: false,
    avgDurationSec: 180,
    isActive: true,
    icon: '🧩',
    badge: 'PUZZLE',
    gradient: ['#654EA3', '#EAAFC8'],
    accentColor: '#EAAFC8',
    modes: ['Classic Strategy', 'Timed Rush (2 Mins)', 'Daily Board'],
    boosters: [
      { id: 'puzzle_undo', name: 'Undo (3x)', description: 'Undo the last move', rpPrice: 100, coinPrice: 25 },
      { id: 'swap_tile', name: 'Swap Tile', description: 'Swap the upcoming preview tile', rpPrice: 120, coinPrice: 30 },
      { id: 'clear_column', name: 'Clear Column', description: 'Clear a full column of tiles', rpPrice: 150, coinPrice: 40 },
    ],
    rpBands: [
      { maxScore: 500, rp: 10 },
      { maxScore: 1500, rp: 20 },
      { maxScore: 3000, rp: 35 },
      { maxScore: Infinity, rp: 50 },
    ],
  },
];

export const DAILY_RP_CAP = 500;
export const MAX_ENERGY = 5;
export const ENERGY_REFILL_MINUTES = 20;

export function getCanonicalGame(idOrKey) {
  if (!idOrKey) return null;
  const query = String(idOrKey).toLowerCase().trim().replace(/[-_]/g, '');
  return CANONICAL_GAMES.find((g) => {
    const gid = g.id.toLowerCase().replace(/[-_]/g, '');
    const gkey = g.gameKey.toLowerCase().replace(/[-_]/g, '');
    return gid === query || gkey === query;
  }) || null;
}

export function isValidGameId(idOrKey) {
  return Boolean(getCanonicalGame(idOrKey));
}

export default {
  GAME_CATEGORIES,
  CANONICAL_GAMES,
  DAILY_RP_CAP,
  MAX_ENERGY,
  ENERGY_REFILL_MINUTES,
  getCanonicalGame,
  isValidGameId,
};
