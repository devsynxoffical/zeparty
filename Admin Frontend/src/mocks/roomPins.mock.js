// ============================================================
// ZeParty Admin Portal — Room Pin Management Mock Data (JavaScript)
// ============================================================

export const PIN_TYPES = [
  { id: 'global_top', label: 'Global Top Pin (Slot 1-3)', color: 'gold', badge: 'GLOBAL TOP' },
  { id: 'category_top', label: 'Category Top Pin', color: 'purple', badge: 'CATEGORY TOP' },
  { id: 'country_top', label: 'Country Priority Pin', color: 'blue', badge: 'COUNTRY PIN' },
  { id: 'hot_recommendation', label: 'Hot Feed Recommendation', color: 'emerald', badge: 'HOT FEED' }
];

export const PIN_SLOTS = [
  { slot: 1, label: 'Slot 1 (Hero Priority)', maxCapacity: 1, status: 'OCCUPIED' },
  { slot: 2, label: 'Slot 2 (Featured Carousel)', maxCapacity: 1, status: 'OCCUPIED' },
  { slot: 3, label: 'Slot 3 (Top Grid)', maxCapacity: 1, status: 'OCCUPIED' },
  { slot: 4, label: 'Slot 4 (Secondary Grid)', maxCapacity: 1, status: 'AVAILABLE' },
  { slot: 5, label: 'Slot 5 (Category Header)', maxCapacity: 1, status: 'AVAILABLE' }
];

export const MOCK_PINNED_ROOMS = [
  {
    pinId: 'pin-901',
    roomId: 'room-001',
    roomTitle: '🔥 Global PK Championship Finals — Room 1',
    hostName: 'Aria Star',
    hostUsername: 'aria_voice',
    category: 'PK Battle',
    country: 'PK',
    pinType: 'global_top',
    slotPosition: 1,
    pinnedByAdmin: 'SuperAdmin (Alex)',
    pinnedAt: '2026-08-29T18:00:00Z',
    expiresAt: '2026-08-30T06:00:00Z', // 12h
    durationHours: 12,
    status: 'ACTIVE',
    viewersCount: 4820,
    giftsVolumeCoins: 385000,
    notes: 'Official sponsored PK battle tournament live pin.'
  },
  {
    pinId: 'pin-902',
    roomId: 'room-003',
    roomTitle: '🎤 Late Night Acoustic Lounge & Chat',
    hostName: 'David Vibes',
    hostUsername: 'david_music',
    category: 'Entertainment',
    country: 'BR',
    pinType: 'category_top',
    slotPosition: 2,
    pinnedByAdmin: 'Moderator (Sarah)',
    pinnedAt: '2026-08-29T20:00:00Z',
    expiresAt: '2026-08-30T02:00:00Z', // 6h
    durationHours: 6,
    status: 'ACTIVE',
    viewersCount: 2150,
    giftsVolumeCoins: 142000,
    notes: 'High conversion creator engagement promotion.'
  },
  {
    pinId: 'pin-903',
    roomId: 'room-005',
    roomTitle: '🎮 Gaming & Coin Giveaway Marathon',
    hostName: 'Gamer Pro',
    hostUsername: 'gamer_x',
    category: 'Games',
    country: 'SA',
    pinType: 'country_top',
    slotPosition: 3,
    pinnedByAdmin: 'SuperAdmin (Alex)',
    pinnedAt: '2026-08-29T21:00:00Z',
    expiresAt: '2026-08-30T01:00:00Z', // 4h
    durationHours: 4,
    status: 'ACTIVE',
    viewersCount: 3100,
    giftsVolumeCoins: 210000,
    notes: 'Saudi Arabia regional feature pin.'
  }
];

export const MOCK_PIN_HISTORY = [
  {
    id: 'pinhis-101',
    pinId: 'pin-888',
    roomId: 'room-002',
    roomTitle: 'VIP Lounge Party',
    hostName: 'Elena Star',
    pinType: 'global_top',
    slotPosition: 1,
    pinnedBy: 'Admin (David)',
    pinnedAt: '2026-08-28T10:00:00Z',
    unpinnedAt: '2026-08-28T22:00:00Z',
    unpinReason: 'Duration Expired',
    peakViewers: 6400,
    totalCoinsGained: 520000
  },
  {
    id: 'pinhis-102',
    pinId: 'pin-889',
    roomId: 'room-004',
    roomTitle: 'Talk Show Night',
    hostName: 'Marcus Broadcast',
    pinType: 'category_top',
    slotPosition: 2,
    pinnedBy: 'Admin (Sarah)',
    pinnedAt: '2026-08-27T14:00:00Z',
    unpinnedAt: '2026-08-27T20:00:00Z',
    unpinReason: 'Manually Unpinned by Admin',
    peakViewers: 1890,
    totalCoinsGained: 95000
  }
];
