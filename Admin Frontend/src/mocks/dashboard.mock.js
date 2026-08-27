// ============================================================
// ZeParty Admin Portal — Dashboard Mock Data (JavaScript)
// ============================================================
// This file provides mock data for the Dashboard (Phase 2).
// Replace with real API calls when the backend is available.
// All values here are illustrative and do not represent
// actual ZeParty production statistics.
// ============================================================

export const MOCK_DASHBOARD_STATS = {
  totalUsers: 284510,
  activeUsers: 61302,
  activeLiveRooms: 1847,
  pendingWithdrawals: 43,
  pendingHostVerifications: 18,
  pendingAgencyVerifications: 7,
  dau: 61302,
  mau: 284510,
  revenueToday: 18740,
  revenueThisMonth: 412830,
  revenueGrowthPercent: 12.4,
  userGrowthPercent: 8.7,
};

export const MOCK_CHART_DATA = {
  userActivity: [
    { label: 'Mon', value: 52100 },
    { label: 'Tue', value: 58400 },
    { label: 'Wed', value: 55700 },
    { label: 'Thu', value: 63200 },
    { label: 'Fri', value: 71800 },
    { label: 'Sat', value: 80500 },
    { label: 'Sun', value: 61302 },
  ],
  revenue: [
    { label: 'Mon', value: 12400 },
    { label: 'Tue', value: 15800 },
    { label: 'Wed', value: 11200 },
    { label: 'Thu', value: 18600 },
    { label: 'Fri', value: 22100 },
    { label: 'Sat', value: 28400 },
    { label: 'Sun', value: 18740 },
  ],
  streamingActivity: [
    { label: 'Mon', value: 1240 },
    { label: 'Tue', value: 1580 },
    { label: 'Wed', value: 1120 },
    { label: 'Thu', value: 1650 },
    { label: 'Fri', value: 1990 },
    { label: 'Sat', value: 2310 },
    { label: 'Sun', value: 1847 },
  ],
};

export const MOCK_TOP_HOSTS = [
  {
    id: 'host-001',
    rank: 1,
    displayName: 'StarQueen Luna',
    username: '@luna_star',
    totalEarnings: 148200,
    totalViewers: 2840000,
    hoursStreamed: 312,
    isVerified: true,
  },
  {
    id: 'host-002',
    rank: 2,
    displayName: 'NightOwl Kai',
    username: '@kai_night',
    totalEarnings: 112580,
    totalViewers: 1960000,
    hoursStreamed: 285,
    isVerified: true,
  },
  {
    id: 'host-003',
    rank: 3,
    displayName: 'BlazingRose',
    username: '@blazing_rose',
    totalEarnings: 98300,
    totalViewers: 1520000,
    hoursStreamed: 247,
    isVerified: true,
  },
  {
    id: 'host-004',
    rank: 4,
    displayName: 'TechWizard Max',
    username: '@max_techw',
    totalEarnings: 74100,
    totalViewers: 1180000,
    hoursStreamed: 198,
    isVerified: false,
  },
  {
    id: 'host-005',
    rank: 5,
    displayName: 'ZenMaster Aria',
    username: '@aria_zen',
    totalEarnings: 61800,
    totalViewers: 880000,
    hoursStreamed: 172,
    isVerified: true,
  },
];

export const MOCK_TOP_CONTENT = [
  {
    id: 'content-001',
    rank: 1,
    title: 'Midnight PK Battle Championship',
    hostName: 'StarQueen Luna',
    viewers: 48200,
    gifts: 12840,
    duration: '3h 24m',
    category: 'PK Battle',
  },
  {
    id: 'content-002',
    rank: 2,
    title: 'Chill Saturday Dance Night',
    hostName: 'BlazingRose',
    viewers: 36700,
    gifts: 9210,
    duration: '2h 48m',
    category: 'Entertainment',
  },
  {
    id: 'content-003',
    rank: 3,
    title: 'Trivia Game Night with Prizes',
    hostName: 'NightOwl Kai',
    viewers: 29100,
    gifts: 7550,
    duration: '1h 52m',
    category: 'Games',
  },
  {
    id: 'content-004',
    rank: 4,
    title: 'Morning Motivation & Chat',
    hostName: 'ZenMaster Aria',
    viewers: 22400,
    gifts: 5890,
    duration: '1h 15m',
    category: 'Talk Show',
  },
  {
    id: 'content-005',
    rank: 5,
    title: 'Tech Talk: AI Trends 2026',
    hostName: 'TechWizard Max',
    viewers: 18900,
    gifts: 4200,
    duration: '2h 10m',
    category: 'Educational',
  },
];

export const MOCK_RECENT_ACTIVITY = [
  {
    id: 'act-001',
    type: 'withdrawal_approved',
    description: 'Approved withdrawal of $2,400 for @luna_star',
    adminName: 'Super Admin',
    timestamp: new Date(Date.now() - 5 * 60 * 1000).toISOString(),
  },
  {
    id: 'act-002',
    type: 'host_verified',
    description: 'Host application approved for @nova_streams',
    adminName: 'Super Admin',
    timestamp: new Date(Date.now() - 28 * 60 * 1000).toISOString(),
  },
  {
    id: 'act-003',
    type: 'user_banned',
    description: 'User @spammer_99 banned for Terms of Service violation',
    adminName: 'Super Admin',
    timestamp: new Date(Date.now() - 1.5 * 60 * 60 * 1000).toISOString(),
  },
  {
    id: 'act-004',
    type: 'announcement',
    description: 'Platform announcement: Summer Festival event published',
    adminName: 'Super Admin',
    timestamp: new Date(Date.now() - 3 * 60 * 60 * 1000).toISOString(),
  },
  {
    id: 'act-005',
    type: 'gift_added',
    description: 'New gift "Golden Dragon" added to the catalog',
    adminName: 'Super Admin',
    timestamp: new Date(Date.now() - 5 * 60 * 60 * 1000).toISOString(),
  },
  {
    id: 'act-006',
    type: 'agency_verified',
    description: 'Agency "StarLight Entertainment" approved',
    adminName: 'Super Admin',
    timestamp: new Date(Date.now() - 8 * 60 * 60 * 1000).toISOString(),
  },
  {
    id: 'act-007',
    type: 'room_closed',
    description: 'Live room #4821 closed for inappropriate content',
    adminName: 'Super Admin',
    timestamp: new Date(Date.now() - 12 * 60 * 60 * 1000).toISOString(),
  },
];
