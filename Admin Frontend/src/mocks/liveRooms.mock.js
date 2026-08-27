// ============================================================
// ZeParty Admin Portal — Live Rooms Mock Data (JavaScript)
// ============================================================

export const MOCK_LIVE_ROOMS = [
  {
    id: 'room-001', title: 'Midnight PK Battle Championship',
    hostId: 'usr-001', hostName: 'StarQueen Luna', hostUsername: '@luna_star',
    category: 'PK Battle', viewers: 48200, peakViewers: 52100,
    duration: '3h 24m', startedAt: '2026-08-13T04:30:00Z',
    status: 'active', giftsReceived: 12840, region: 'US',
  },
  {
    id: 'room-002', title: 'Chill Saturday Dance Night',
    hostId: 'usr-003', hostName: 'BlazingRose', hostUsername: '@blazing_rose',
    category: 'Entertainment', viewers: 36700, peakViewers: 41200,
    duration: '2h 48m', startedAt: '2026-08-13T05:10:00Z',
    status: 'active', giftsReceived: 9210, region: 'CA',
  },
  {
    id: 'room-003', title: 'Trivia Game Night with Prizes',
    hostId: 'usr-002', hostName: 'NightOwl Kai', hostUsername: '@kai_night',
    category: 'Games', viewers: 29100, peakViewers: 33800,
    duration: '1h 52m', startedAt: '2026-08-13T06:00:00Z',
    status: 'active', giftsReceived: 7550, region: 'UK',
  },
  {
    id: 'room-004', title: 'Morning Motivation & Chat',
    hostId: 'usr-005', hostName: 'ZenMaster Aria', hostUsername: '@aria_zen',
    category: 'Talk Show', viewers: 22400, peakViewers: 24100,
    duration: '1h 15m', startedAt: '2026-08-13T07:00:00Z',
    status: 'active', giftsReceived: 5890, region: 'JP',
  },
  {
    id: 'room-005', title: 'Tech Talk: AI Trends 2026',
    hostId: 'usr-006', hostName: 'TechWizard Max', hostUsername: '@max_techw',
    category: 'Educational', viewers: 18900, peakViewers: 21000,
    duration: '2h 10m', startedAt: '2026-08-13T06:30:00Z',
    status: 'active', giftsReceived: 4200, region: 'DE',
  },
  {
    id: 'room-006', title: 'K-Pop Karaoke Night',
    hostId: 'usr-009', hostName: 'Fire Phoenix', hostUsername: '@fire_phoenix',
    category: 'Music', viewers: 14200, peakViewers: 16800,
    duration: '1h 30m', startedAt: '2026-08-13T07:30:00Z',
    status: 'active', giftsReceived: 3100, region: 'KR',
  },
  {
    id: 'room-007', title: 'Inappropriate Content Room',
    hostId: 'usr-004', hostName: 'SpamBot99', hostUsername: '@spammer_99',
    category: 'Unknown', viewers: 0, peakViewers: 120,
    duration: '0h 12m', startedAt: '2026-08-13T09:20:00Z',
    status: 'closed', giftsReceived: 0, region: 'XX',
  },
];

export const ROOM_CATEGORIES = ['All', 'PK Battle', 'Entertainment', 'Games', 'Talk Show', 'Educational', 'Music'];
export const ROOM_STATUSES = ['all', 'active', 'closed', 'paused'];
