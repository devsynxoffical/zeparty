export const pkEventsMock = [
  { id: 'PK-1001', name: 'Global Challenge', type: 'GLOBAL', status: 'LIVE', startDate: '2026-08-18T10:00:00Z', endDate: '2026-08-20T10:00:00Z', participants: 50, prizePool: 100000, topWinner: 'KingLion', host1: 'KingLion', host2: 'QueenBee' },
  { id: 'PK-1002', name: 'Weekend Rumble', type: 'WEEKEND', status: 'SCHEDULED', startDate: '2026-08-22T20:00:00Z', endDate: '2026-08-24T20:00:00Z', participants: 200, prizePool: 500000, topWinner: '-', host1: 'TBA', host2: 'TBA' },
  { id: 'PK-1003', name: 'Voice Kings', type: 'VOICE', status: 'COMPLETED', startDate: '2026-08-10T12:00:00Z', endDate: '2026-08-12T12:00:00Z', participants: 120, prizePool: 250000, topWinner: 'VocalStar', host1: 'VocalStar', host2: 'MicCheck' },
  { id: 'PK-1004', name: 'Newbie Clash', type: 'NEW_HOST', status: 'LIVE', startDate: '2026-08-19T08:00:00Z', endDate: '2026-08-19T14:00:00Z', participants: 10, prizePool: 50000, topWinner: 'Rookie_99', host1: 'Rookie_99', host2: 'FreshTalent' },
  { id: 'PK-1005', name: 'Agency Wars', type: 'AGENCY', status: 'DISABLED', startDate: '2026-09-01T00:00:00Z', endDate: '2026-09-07T00:00:00Z', participants: 500, prizePool: 1000000, topWinner: '-', host1: 'AgencyAlpha', host2: 'AgencyBeta' },
  { id: 'PK-1006', name: 'Flash PK', type: 'FLASH', status: 'COMPLETED', startDate: '2026-08-15T15:00:00Z', endDate: '2026-08-15T16:00:00Z', participants: 2, prizePool: 10000, topWinner: 'SpeedyG', host1: 'SpeedyG', host2: 'SlowPoke' },
];

export const pkStats = {
  activeEvents: 2,
  scheduledEvents: 1,
  completedEvents: 2,
  totalParticipants: 882,
  totalRewardsDistributed: 260000,
};

export const pkLeaderboard = [
  { rank: 1, host: 'KingLion', score: 150000, gifts: 5000, rounds: 40, wins: 35, rewards: 20000 },
  { rank: 2, host: 'QueenBee', score: 145000, gifts: 4800, rounds: 40, wins: 32, rewards: 18000 },
  { rank: 3, host: 'VocalStar', score: 98000, gifts: 3100, rounds: 20, wins: 18, rewards: 10000 },
  { rank: 4, host: 'MicCheck', score: 85000, gifts: 2800, rounds: 20, wins: 15, rewards: 8000 },
  { rank: 5, host: 'SpeedyG', score: 50000, gifts: 1500, rounds: 5, wins: 5, rewards: 5000 },
];
