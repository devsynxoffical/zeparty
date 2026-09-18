// ============================================================
// ZeParty Admin Portal — Canonical 10-Game Catalog Data (JavaScript)
// ============================================================

export const MOCK_GAMES = [
  {
    id: 'fishing_star',
    name: 'Fishing Star',
    type: 'Arcade',
    status: 'active',
    entryFee: 10,
    minPrize: 12,
    maxPrize: 2000,
    totalRounds: 342000,
    totalPaidOut: 314640,
    houseEdge: 8.0,
    expectedReturn: 0.92,
    specificationStatus: 'SPECIFICATION_SHELL',
    createdAt: '2024-01-01T00:00:00Z',
    description: 'Dynamic deep-sea arcade fishing where players target virtual fish with configurable coin tiers.',
    outcomes: [
      { id: 'out-fs-1', name: 'Missed Shot', probability: 35, payout: 0, active: true },
      { id: 'out-fs-2', name: 'Clownfish (1.2x)', probability: 40, payout: 1.2, active: true },
      { id: 'out-fs-3', name: 'Swordfish (2.5x)', probability: 18, payout: 2.5, active: true },
      { id: 'out-fs-4', name: 'Hammerhead Shark (5x)', probability: 5, payout: 5.0, active: true },
      { id: 'out-fs-5', name: 'Golden Dragon Whale (20x)', probability: 2, payout: 20.0, active: true }
    ],
    history: [
      {
        version: 'v1.0',
        effectiveDate: '2024-01-01T00:00:00Z',
        operator: 'System Initializer',
        reason: 'Initial setup for Fishing Star',
        expectedReturn: 0.92,
        houseEdge: 8.0,
        outcomesCount: 5
      }
    ],
    config: { fishTiers: 4, cannonLevels: 5 }
  },
  {
    id: 'teen_patti',
    name: 'Teen Patti',
    type: 'Card Game',
    status: 'active',
    entryFee: 20,
    minPrize: 0,
    maxPrize: 10000,
    totalRounds: 512000,
    totalPaidOut: 486400,
    houseEdge: 5.0,
    expectedReturn: 0.95,
    specificationStatus: 'STANDARD_IDENTITY',
    createdAt: '2024-01-01T00:00:00Z',
    description: 'Classic 3-card Indian poker game with standard hand ranking hierarchy.',
    outcomes: [
      { id: 'out-tp-1', name: 'High Card Loss', probability: 52.5, payout: 0, active: true },
      { id: 'out-tp-2', name: 'Pair / Flush (2x)', probability: 42.5, payout: 2.0, active: true },
      { id: 'out-tp-3', name: 'Straight Sequence (3x)', probability: 3.5, payout: 3.0, active: true },
      { id: 'out-tp-4', name: 'Pure Sequence / Trail (10x)', probability: 1.5, payout: 10.0, active: true }
    ],
    history: [
      {
        version: 'v1.0',
        effectiveDate: '2024-01-01T00:00:00Z',
        operator: 'System Initializer',
        reason: 'Initial economic setup for Teen Patti',
        expectedReturn: 0.95,
        houseEdge: 5.0,
        outcomesCount: 4
      }
    ],
    config: { maxPlayers: 6, cardRankings: 'Standard 3-Card' }
  },
  {
    id: 'dragon_tiger',
    name: 'Dragon & Tiger',
    type: 'Card Game',
    status: 'active',
    entryFee: 10,
    minPrize: 0,
    maxPrize: 9000,
    totalRounds: 680000,
    totalPaidOut: 654636,
    houseEdge: 3.73,
    expectedReturn: 0.9627,
    specificationStatus: 'STANDARD_IDENTITY',
    createdAt: '2024-01-01T00:00:00Z',
    description: 'Fast-paced two-card comparison game (Dragon vs Tiger vs Tie).',
    outcomes: [
      { id: 'out-dt-1', name: 'Opponent High Card', probability: 51.86, payout: 0, active: true },
      { id: 'out-dt-2', name: 'Dragon / Tiger Victory (2x)', probability: 45.14, payout: 2.0, active: true },
      { id: 'out-dt-3', name: 'Tie Result (9x)', probability: 3.0, payout: 9.0, active: true }
    ],
    history: [
      {
        version: 'v1.0',
        effectiveDate: '2024-01-01T00:00:00Z',
        operator: 'System Initializer',
        reason: 'Initial release for Dragon & Tiger table',
        expectedReturn: 0.9627,
        houseEdge: 3.73,
        outcomesCount: 3
      }
    ],
    config: { deckCount: 8, tieMultiplier: 9 }
  },
  {
    id: 'roulette',
    name: 'Roulette',
    type: 'Table Game',
    status: 'active',
    entryFee: 10,
    minPrize: 0,
    maxPrize: 36000,
    totalRounds: 420000,
    totalPaidOut: 408660,
    houseEdge: 2.7,
    expectedReturn: 0.973,
    specificationStatus: 'STANDARD_IDENTITY',
    createdAt: '2024-01-01T00:00:00Z',
    description: 'Single-zero European wheel roulette table with straight, split, color, and dozen wager distributions.',
    outcomes: [
      { id: 'out-rou-1', name: 'Miss', probability: 51.35, payout: 0, active: true },
      { id: 'out-rou-2', name: 'Red / Black / Even / Odd (2x)', probability: 45.95, payout: 2.0, active: true },
      { id: 'out-rou-3', name: 'Straight Up Number (36x)', probability: 2.7, payout: 36.0, active: true }
    ],
    history: [
      {
        version: 'v1.0',
        effectiveDate: '2024-01-01T00:00:00Z',
        operator: 'System Initializer',
        reason: 'Single zero European wheel rules release',
        expectedReturn: 0.973,
        houseEdge: 2.7,
        outcomesCount: 3
      }
    ],
    config: { pockets: 37, zeroType: 'Single' }
  },
  {
    id: 'delicious',
    name: 'Delicious',
    type: 'Arcade',
    status: 'active',
    entryFee: 10,
    minPrize: 0,
    maxPrize: 2500,
    totalRounds: 110000,
    totalPaidOut: 99000,
    houseEdge: 10.0,
    expectedReturn: 0.90,
    specificationStatus: 'CLIENT_SPEC_REQUIRED',
    createdAt: '2024-01-01T00:00:00Z',
    description: 'Food & gourmet culinary matching theme. Engine placeholder awaiting client mathematical and gameplay rule specifications.',
    outcomes: [
      { id: 'out-del-1', name: 'Standard Loss', probability: 55, payout: 0, active: true },
      { id: 'out-del-2', name: 'Sweet Match (2x)', probability: 45, payout: 2.0, active: true }
    ],
    history: [
      {
        version: 'v1.0',
        effectiveDate: '2024-01-01T00:00:00Z',
        operator: 'System Initializer',
        reason: 'Specification placeholder shell',
        expectedReturn: 0.90,
        houseEdge: 10.0,
        outcomesCount: 2
      }
    ],
    config: { note: 'Awaiting client specification' }
  },
  {
    id: 'rocket',
    name: 'Rocket',
    type: 'Crash / Multiplier',
    status: 'active',
    entryFee: 10,
    minPrize: 0,
    maxPrize: 50000,
    totalRounds: 890000,
    totalPaidOut: 854400,
    houseEdge: 4.0,
    expectedReturn: 0.96,
    specificationStatus: 'SERVER_AUTHORITATIVE_ENGINE',
    createdAt: '2024-01-01T00:00:00Z',
    description: 'Server-authoritative rocket crash game where multiplier climbs in real-time until sudden engine crash.',
    outcomes: [
      { id: 'out-rkt-1', name: 'Early Crash (0x)', probability: 40, payout: 0, active: true },
      { id: 'out-rkt-2', name: 'Low Cashout (1.5x)', probability: 40, payout: 1.5, active: true },
      { id: 'out-rkt-3', name: 'Mid Altitude (3x)', probability: 15, payout: 3.0, active: true },
      { id: 'out-rkt-4', name: 'Moon Launch (10x)', probability: 5, payout: 10.0, active: true }
    ],
    history: [
      {
        version: 'v1.0',
        effectiveDate: '2024-01-01T00:00:00Z',
        operator: 'System Initializer',
        reason: 'Provably fair crash engine configuration',
        expectedReturn: 0.96,
        houseEdge: 4.0,
        outcomesCount: 4
      }
    ],
    config: { maxMultiplier: 2000, tickRateMs: 100 }
  },
  {
    id: 'fruit_party_jackpot',
    name: 'Fruit Party Jackpot',
    type: 'Slots / Jackpot',
    status: 'active',
    entryFee: 10,
    minPrize: 0,
    maxPrize: 50000,
    totalRounds: 730000,
    totalPaidOut: 689850,
    houseEdge: 5.5,
    expectedReturn: 0.945,
    specificationStatus: 'SLOT_FRAMEWORK',
    createdAt: '2024-01-01T00:00:00Z',
    description: 'Vibrant fruit slot engine featuring symbol cascading combinations and server-managed jackpot pool contributions.',
    outcomes: [
      { id: 'out-fp-1', name: 'No Match', probability: 50, payout: 0, active: true },
      { id: 'out-fp-2', name: 'Fruit Pair (1.5x)', probability: 35, payout: 1.5, active: true },
      { id: 'out-fp-3', name: 'Triple Star (20x)', probability: 13, payout: 20.0, active: true },
      { id: 'out-fp-4', name: 'Lucky 777 Jackpot (50x)', probability: 2, payout: 50.0, active: true }
    ],
    history: [
      {
        version: 'v1.0',
        effectiveDate: '2024-01-01T00:00:00Z',
        operator: 'System Initializer',
        reason: 'Fruit Party Jackpot math initialization',
        expectedReturn: 0.945,
        houseEdge: 5.5,
        outcomesCount: 4
      }
    ],
    config: { reels: 3, jackpotPoolPercentage: 2.0 }
  },
  {
    id: 'bounty_football',
    name: 'Bounty Football',
    type: 'Sports / Arcade',
    status: 'active',
    entryFee: 10,
    minPrize: 0,
    maxPrize: 5000,
    totalRounds: 140000,
    totalPaidOut: 126000,
    houseEdge: 10.0,
    expectedReturn: 0.90,
    specificationStatus: 'CLIENT_SPEC_REQUIRED',
    createdAt: '2024-01-01T00:00:00Z',
    description: 'Football and penalty challenge game. Engine placeholder awaiting client mechanics and odds specification.',
    outcomes: [
      { id: 'out-bf-1', name: 'Goalie Save', probability: 55, payout: 0, active: true },
      { id: 'out-bf-2', name: 'Goal Score (2x)', probability: 45, payout: 2.0, active: true }
    ],
    history: [
      {
        version: 'v1.0',
        effectiveDate: '2024-01-01T00:00:00Z',
        operator: 'System Initializer',
        reason: 'Specification placeholder shell',
        expectedReturn: 0.90,
        houseEdge: 10.0,
        outcomesCount: 2
      }
    ],
    config: { note: 'Awaiting client specification' }
  },
  {
    id: 'greedy_lion',
    name: 'Greedy Lion',
    type: 'Multiplier',
    status: 'active',
    entryFee: 10,
    minPrize: 0,
    maxPrize: 5000,
    totalRounds: 125000,
    totalPaidOut: 112500,
    houseEdge: 10.0,
    expectedReturn: 0.90,
    specificationStatus: 'CLIENT_SPEC_REQUIRED',
    createdAt: '2024-01-01T00:00:00Z',
    description: 'Safari lion multiplier adventure. Engine placeholder awaiting client gameplay rules and math models.',
    outcomes: [
      { id: 'out-gl-1', name: 'Lion Retreat', probability: 55, payout: 0, active: true },
      { id: 'out-gl-2', name: 'Lion Roar (2x)', probability: 45, payout: 2.0, active: true }
    ],
    history: [
      {
        version: 'v1.0',
        effectiveDate: '2024-01-01T00:00:00Z',
        operator: 'System Initializer',
        reason: 'Specification placeholder shell',
        expectedReturn: 0.90,
        houseEdge: 10.0,
        outcomesCount: 2
      }
    ],
    config: { note: 'Awaiting client specification' }
  },
  {
    id: 'double_seven_77',
    name: 'Double Seven (77)',
    type: 'Slots / Match',
    status: 'active',
    entryFee: 10,
    minPrize: 0,
    maxPrize: 5000,
    totalRounds: 135000,
    totalPaidOut: 121500,
    houseEdge: 10.0,
    expectedReturn: 0.90,
    specificationStatus: 'CLIENT_SPEC_REQUIRED',
    createdAt: '2024-01-01T00:00:00Z',
    description: 'Lucky 77 matching experience. Engine placeholder awaiting client number generation rules and paytable.',
    outcomes: [
      { id: 'out-ds-1', name: 'No 77 Match', probability: 55, payout: 0, active: true },
      { id: 'out-ds-2', name: 'Double 7 Match (2x)', probability: 45, payout: 2.0, active: true }
    ],
    history: [
      {
        version: 'v1.0',
        effectiveDate: '2024-01-01T00:00:00Z',
        operator: 'System Initializer',
        reason: 'Specification placeholder shell',
        expectedReturn: 0.90,
        houseEdge: 10.0,
        outcomesCount: 2
      }
    ],
    config: { note: 'Awaiting client specification' }
  }
];

export const GAME_STATUSES = ['all', 'active', 'paused', 'inactive'];
export const GAME_TYPES = ['All', 'Arcade', 'Card Game', 'Table Game', 'Crash / Multiplier', 'Slots / Jackpot', 'Multiplier', 'Slots / Match'];
