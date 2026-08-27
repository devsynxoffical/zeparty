// ============================================================
// ZeParty Admin Portal — Games Mock Data (JavaScript)
// ============================================================

export const MOCK_GAMES = [
  {
    id: 'game-001',
    name: 'Lucky Wheel',
    type: 'Spin',
    status: 'active',
    entryFee: 10,
    minPrize: 0,
    maxPrize: 500,
    totalRounds: 284000,
    totalPaidOut: 184000,
    houseEdge: 10.0,
    expectedReturn: 0.90,
    createdAt: '2024-01-01T00:00:00Z',
    description: 'Classic lucky wheel spin with randomized prize segments.',
    outcomes: [
      { id: 'out-101', name: 'No Win', probability: 50, payout: 0, active: true },
      { id: 'out-102', name: 'Standard Prize (2x)', probability: 35, payout: 2, active: true },
      { id: 'out-103', name: 'Major Jackpot (4x)', probability: 5, payout: 4, active: true },
      { id: 'out-104', name: 'Bonus Return (0x)', probability: 10, active: true, payout: 0 }
    ],
    history: [
      {
        version: 'v1.0',
        effectiveDate: '2024-01-01T00:00:00Z',
        operator: 'System Initializer',
        reason: 'Initial economic setup for Lucky Wheel',
        expectedReturn: 0.90,
        houseEdge: 10.0,
        outcomesCount: 4
      }
    ],
    config: { segments: 8, jackpotOdds: '1:1000' }
  },
  {
    id: 'game-002',
    name: 'Diamond Rush',
    type: 'Slots',
    status: 'active',
    entryFee: 5,
    minPrize: 0,
    maxPrize: 1000,
    totalRounds: 192000,
    totalPaidOut: 128000,
    houseEdge: 15.0,
    expectedReturn: 0.85,
    createdAt: '2024-03-15T00:00:00Z',
    description: 'Fast-paced slot machine with diamond-themed prizes.',
    outcomes: [
      { id: 'out-201', name: 'No Match', probability: 60, payout: 0, active: true },
      { id: 'out-202', name: 'Double Diamonds (2x)', probability: 25, payout: 2, active: true },
      { id: 'out-203', name: 'Triple Diamonds (5x)', probability: 11, payout: 5, active: true },
      { id: 'out-204', name: 'Diamond Mega Jackpot (10x)', probability: 4, payout: 10, active: true }
    ],
    history: [
      {
        version: 'v1.0',
        effectiveDate: '2024-03-15T00:00:00Z',
        operator: 'System Initializer',
        reason: 'Initial economic release for Slots minigame',
        expectedReturn: 0.85,
        houseEdge: 15.0,
        outcomesCount: 4
      }
    ],
    config: { reels: 3, lines: 5, jackpotOdds: '1:5000' }
  },
  {
    id: 'game-003',
    name: 'Card Battle',
    type: 'Card Game',
    status: 'active',
    entryFee: 20,
    minPrize: 0,
    maxPrize: 200,
    totalRounds: 84000,
    totalPaidOut: 62000,
    houseEdge: 8.0,
    expectedReturn: 0.92,
    createdAt: '2024-06-01T00:00:00Z',
    description: 'Multiplayer card battle game with real-time opponents.',
    outcomes: [
      { id: 'out-301', name: 'Defeat / High Card', probability: 48, payout: 0, active: true },
      { id: 'out-302', name: 'Draw Split bet (1x)', probability: 10, payout: 1, active: true },
      { id: 'out-303', name: 'Victory Standard (1.5x)', probability: 38, payout: 1.5, active: true },
      { id: 'out-304', name: 'Victory Royale (7x)', probability: 4, payout: 7, active: true }
    ],
    history: [
      {
        version: 'v1.0',
        effectiveDate: '2024-06-01T00:00:00Z',
        operator: 'System Initializer',
        reason: 'Economy release v1.0',
        expectedReturn: 0.92,
        houseEdge: 8.0,
        outcomesCount: 4
      }
    ],
    config: { minPlayers: 2, maxPlayers: 6 }
  },
  {
    id: 'game-004',
    name: 'Treasure Chest',
    type: 'Instant Win',
    status: 'active',
    entryFee: 30,
    minPrize: 0,
    maxPrize: 3000,
    totalRounds: 48200,
    totalPaidOut: 36100,
    houseEdge: 12.0,
    expectedReturn: 0.88,
    createdAt: '2024-08-10T00:00:00Z',
    description: 'Open chests to reveal instant prizes.',
    outcomes: [
      { id: 'out-401', name: 'Empty Chest', probability: 55, payout: 0, active: true },
      { id: 'out-402', name: 'Bronze Treasure (1.5x)', probability: 30, payout: 1.5, active: true },
      { id: 'out-403', name: 'Silver Treasure (3x)', probability: 11, payout: 3, active: true },
      { id: 'out-404', name: 'Golden Treasure (10x)', probability: 4, payout: 10, active: true }
    ],
    history: [
      {
        version: 'v1.0',
        effectiveDate: '2024-08-10T00:00:00Z',
        operator: 'System Initializer',
        reason: 'Initial RTP configuration for Chests',
        expectedReturn: 0.88,
        houseEdge: 12.0,
        outcomesCount: 4
      }
    ],
    config: { chestTypes: ['Bronze', 'Silver', 'Gold', 'Diamond'] }
  }
];

export const GAME_STATUSES = ['all', 'active', 'paused', 'inactive'];
export const GAME_TYPES = ['All', 'Spin', 'Slots', 'Card Game', 'Instant Win', 'Dice', 'Classic'];
