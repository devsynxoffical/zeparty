// ============================================================
// ZeParty Admin Portal — Leaderboards Mock Data (JavaScript)
// ============================================================

export const MOCK_LEADERBOARD_RICH = [
  { rank: 1, userId: 'usr-001', username: '@luna_star', displayName: 'StarQueen Luna', country: 'US', totalCoinsSpent: 284000, vipLevel: 'VIP5', change: 0 },
  { rank: 2, userId: 'usr-009', username: '@fire_phoenix', displayName: 'Fire Phoenix', country: 'KR', totalCoinsSpent: 218000, vipLevel: 'VIP4', change: 1 },
  { rank: 3, userId: 'usr-002', username: '@kai_night', displayName: 'NightOwl Kai', country: 'UK', totalCoinsSpent: 156000, vipLevel: 'VIP3', change: -1 },
  { rank: 4, userId: 'usr-003', username: '@blazing_rose', displayName: 'BlazingRose', country: 'CA', totalCoinsSpent: 72000, vipLevel: null, change: 2 },
  { rank: 5, userId: 'usr-005', username: '@aria_zen', displayName: 'ZenMaster Aria', country: 'JP', totalCoinsSpent: 45000, vipLevel: 'VIP2', change: 0 },
];

export const MOCK_LEADERBOARD_HOSTS = [
  { rank: 1, hostId: 'usr-001', username: '@luna_star', displayName: 'StarQueen Luna', country: 'US', totalEarnings: 48200, giftsReceived: 12840, liveHours: 320 },
  { rank: 2, hostId: 'usr-009', username: '@fire_phoenix', displayName: 'Fire Phoenix', country: 'KR', totalEarnings: 38800, giftsReceived: 10200, liveHours: 280 },
  { rank: 3, hostId: 'usr-002', username: '@kai_night', displayName: 'NightOwl Kai', country: 'UK', totalEarnings: 29400, giftsReceived: 8100, liveHours: 240 },
  { rank: 4, hostId: 'usr-003', username: '@blazing_rose', displayName: 'BlazingRose', country: 'CA', totalEarnings: 21800, giftsReceived: 6200, liveHours: 180 },
  { rank: 5, hostId: 'usr-005', username: '@aria_zen', displayName: 'ZenMaster Aria', country: 'JP', totalEarnings: 15200, giftsReceived: 4400, liveHours: 120 },
];

// ---- Coin Sellers ----
export const MOCK_COIN_SELLERS = [
  {
    id: 'cs-001', sellerName: 'CoinMaster Pro', username: '@coinmaster_pro',
    email: 'coinmaster@example.com', country: 'US', phone: '+1 555 0101',
    totalSold: 1284000, totalRevenue: 12840, status: 'active', joinedAt: '2024-01-15T00:00:00Z',
    monthlyQuota: 2000000, usedQuota: 1284000,
  },
  {
    id: 'cs-002', sellerName: 'QuickCoins Hub', username: '@quickcoins_hub',
    email: 'quickcoins@example.com', country: 'UK', phone: '+44 20 0001',
    totalSold: 924000, totalRevenue: 9240, status: 'active', joinedAt: '2024-03-01T00:00:00Z',
    monthlyQuota: 1500000, usedQuota: 924000,
  },
  {
    id: 'cs-003', sellerName: 'StarCoins Asia', username: '@starcoins_asia',
    email: 'starcoins@example.com', country: 'KR', phone: '+82 10 0001',
    totalSold: 743000, totalRevenue: 7430, status: 'active', joinedAt: '2024-05-10T00:00:00Z',
    monthlyQuota: 1000000, usedQuota: 743000,
  },
  {
    id: 'cs-004', sellerName: 'Coin Express', username: '@coin_express',
    email: 'coinexpress@example.com', country: 'AU', phone: '+61 2 0001',
    totalSold: 481000, totalRevenue: 4810, status: 'active', joinedAt: '2024-08-20T00:00:00Z',
    monthlyQuota: 800000, usedQuota: 481000,
  },
  {
    id: 'cs-005', sellerName: 'Suspended Seller', username: '@suspended_seller',
    email: 'bad@seller.com', country: 'XX', phone: '+00 0 0000',
    totalSold: 12000, totalRevenue: 120, status: 'suspended', joinedAt: '2026-07-01T00:00:00Z',
    monthlyQuota: 500000, usedQuota: 12000,
  },
];
