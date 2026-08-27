// ============================================================
// ZeParty Admin Portal — Communications Mock Data (JavaScript)
// ============================================================

// ---- Announcements ----
export const MOCK_ANNOUNCEMENTS = [
  {
    id: 'ann-001', title: 'Platform Maintenance Notice',
    content: 'ZeParty will undergo scheduled maintenance on August 15, 2026 from 02:00–04:00 UTC. All live streams will be temporarily unavailable during this period.',
    type: 'Maintenance', status: 'published', pinned: true,
    audience: 'All Users', publishedAt: '2026-08-13T08:00:00Z', expiresAt: '2026-08-16T00:00:00Z',
    createdBy: 'Admin',
  },
  {
    id: 'ann-002', title: 'New Feature: PK Battle Season 3 Launch',
    content: 'Introducing PK Battle Season 3 with new maps, enhanced rewards, and real-time leaderboards. Join now to earn exclusive Season 3 badges!',
    type: 'Feature', status: 'published', pinned: false,
    audience: 'All Users', publishedAt: '2026-08-10T10:00:00Z', expiresAt: null,
    createdBy: 'Admin',
  },
  {
    id: 'ann-003', title: 'Host Bonus Program — August 2026',
    content: 'All verified hosts who reach 50 live hours this month will receive a 10% bonus on their earnings. The program runs from August 1–31, 2026.',
    type: 'Promotion', status: 'published', pinned: false,
    audience: 'Hosts Only', publishedAt: '2026-08-01T00:00:00Z', expiresAt: '2026-08-31T23:59:59Z',
    createdBy: 'Admin',
  },
  {
    id: 'ann-004', title: 'Upcoming: VIP Store Expansion',
    content: 'Draft announcement about new VIP store items being added next week.',
    type: 'Feature', status: 'draft', pinned: false,
    audience: 'All Users', publishedAt: null, expiresAt: null,
    createdBy: 'Admin',
  },
];

// ---- Notification Broadcasts ----
export const MOCK_NOTIFICATIONS = [
  {
    id: 'notif-001', title: 'Welcome to ZeParty!',
    body: 'Welcome aboard! Explore live streams, PK battles, and more. Your adventure begins here.',
    type: 'Welcome', status: 'sent', audience: 'New Users',
    sentAt: '2026-08-13T09:00:00Z', recipients: 1284, openRate: 84.2,
  },
  {
    id: 'notif-002', title: 'Your favorite host is live!',
    body: 'StarQueen Luna just started a live stream. Tap to join now!',
    type: 'Push', status: 'sent', audience: 'Luna Followers',
    sentAt: '2026-08-13T04:35:00Z', recipients: 48200, openRate: 62.4,
  },
  {
    id: 'notif-003', title: 'Recharge Bonus: 20% Extra Coins This Weekend',
    body: 'Limited time offer! Recharge any plan this weekend and get 20% bonus coins.',
    type: 'Promotional', status: 'sent', audience: 'All Users',
    sentAt: '2026-08-12T08:00:00Z', recipients: 124000, openRate: 38.7,
  },
  {
    id: 'notif-004', title: 'Your withdrawal has been processed',
    body: 'Your withdrawal request of $2,400 has been approved and is being processed.',
    type: 'Transactional', status: 'sent', audience: 'Targeted User',
    sentAt: '2026-08-12T12:00:00Z', recipients: 1, openRate: 100,
  },
  {
    id: 'notif-005', title: 'August VIP Rewards Reminder',
    body: 'Draft notification for August VIP reward distribution.',
    type: 'Promotional', status: 'draft', audience: 'VIP Users',
    sentAt: null, recipients: 0, openRate: 0,
  },
];
