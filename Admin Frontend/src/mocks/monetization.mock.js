// ============================================================
// ZeParty Admin Portal — Monetization Mock Data (JavaScript)
// ============================================================

// ---- Recharge Plans ----
export const MOCK_RECHARGE_PLANS = [
  { id: 'plan-001', name: 'Starter Pack', coins: 100, price: 0.99, bonus: 0, featured: false, active: true },
  { id: 'plan-002', name: 'Basic Pack', coins: 500, price: 4.99, bonus: 50, featured: false, active: true },
  { id: 'plan-003', name: 'Popular Pack', coins: 1000, price: 9.99, bonus: 150, featured: true, active: true },
  { id: 'plan-004', name: 'Value Pack', coins: 2500, price: 24.99, bonus: 500, featured: false, active: true },
  { id: 'plan-005', name: 'Premium Pack', coins: 5000, price: 49.99, bonus: 1250, featured: true, active: true },
  { id: 'plan-006', name: 'Elite Pack', coins: 10000, price: 99.99, bonus: 3000, featured: false, active: true },
  { id: 'plan-007', name: 'Legacy Pack', coins: 200, price: 1.99, bonus: 0, featured: false, active: false },
];

// ---- Offline Recharge Requests ----
export const MOCK_OFFLINE_RECHARGE = [
  {
    id: 'or-001', userId: 'usr-001', userName: 'StarQueen Luna', userUsername: '@luna_star',
    amount: 49.99, coins: 5000, paymentRef: 'TXN-2026081301', method: 'Bank Transfer',
    requestedAt: '2026-08-13T07:00:00Z', status: 'pending', notes: '',
  },
  {
    id: 'or-002', userId: 'usr-005', userName: 'ZenMaster Aria', userUsername: '@aria_zen',
    amount: 24.99, coins: 2500, paymentRef: 'TXN-2026081302', method: 'Mobile Money',
    requestedAt: '2026-08-13T06:30:00Z', status: 'pending', notes: '',
  },
  {
    id: 'or-003', userId: 'usr-007', userName: 'Nova Streams', userUsername: '@nova_streams',
    amount: 9.99, coins: 1000, paymentRef: 'TXN-2026081201', method: 'Bank Transfer',
    requestedAt: '2026-08-12T14:00:00Z', status: 'approved', notes: 'Verified payment.',
  },
  {
    id: 'or-004', userId: 'usr-008', userName: 'Cosmic Dancer', userUsername: '@cosmic_dancer',
    amount: 4.99, coins: 500, paymentRef: 'TXN-2026081202', method: 'Mobile Money',
    requestedAt: '2026-08-12T11:00:00Z', status: 'rejected', notes: 'Invalid payment reference.',
  },
  {
    id: 'or-005', userId: 'usr-009', userName: 'Fire Phoenix', userUsername: '@fire_phoenix',
    amount: 99.99, coins: 10000, paymentRef: 'TXN-2026081101', method: 'Bank Transfer',
    requestedAt: '2026-08-11T09:00:00Z', status: 'approved', notes: 'Confirmed via bank statement.',
  },
];

// ---- Withdrawals ----
export const MOCK_WITHDRAWALS = [
  {
    id: 'wd-001', hostId: 'usr-001', hostName: 'StarQueen Luna', hostUsername: '@luna_star',
    amount: 2400, currency: 'USD', method: 'Bank Transfer', accountLast4: '4242',
    requestedAt: '2026-08-13T05:00:00Z', status: 'pending', note: '',
  },
  {
    id: 'wd-002', hostId: 'usr-002', hostName: 'NightOwl Kai', hostUsername: '@kai_night',
    amount: 1800, currency: 'USD', method: 'PayPal', accountLast4: null,
    requestedAt: '2026-08-13T04:30:00Z', status: 'pending', note: '',
  },
  {
    id: 'wd-003', hostId: 'usr-003', hostName: 'BlazingRose', hostUsername: '@blazing_rose',
    amount: 1200, currency: 'USD', method: 'Bank Transfer', accountLast4: '8891',
    requestedAt: '2026-08-12T20:00:00Z', status: 'approved', note: 'Processed via bank.',
  },
  {
    id: 'wd-004', hostId: 'usr-005', hostName: 'ZenMaster Aria', hostUsername: '@aria_zen',
    amount: 800, currency: 'USD', method: 'PayPal', accountLast4: null,
    requestedAt: '2026-08-12T18:00:00Z', status: 'approved', note: '',
  },
  {
    id: 'wd-005', hostId: 'usr-006', hostName: 'TechWizard Max', hostUsername: '@max_techw',
    amount: 500, currency: 'USD', method: 'Bank Transfer', accountLast4: '1234',
    requestedAt: '2026-08-11T10:00:00Z', status: 'rejected', note: 'Account details mismatch.',
  },
  {
    id: 'wd-006', hostId: 'usr-009', hostName: 'Fire Phoenix', hostUsername: '@fire_phoenix',
    amount: 3200, currency: 'USD', method: 'Bank Transfer', accountLast4: '5567',
    requestedAt: '2026-08-10T08:00:00Z', status: 'completed', note: 'Payout confirmed.',
  },
];
