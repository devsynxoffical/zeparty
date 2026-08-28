// ============================================================
// ZeParty Admin Portal — Comprehensive BD Center & Reaction Mock Data (JavaScript)
// ============================================================

export const MOCK_BD_APPLICATIONS = [
  {
    id: 'bd-app-101',
    userId: 'usr-881',
    nickname: 'Alex Regional Ops',
    email: 'alex.ops@zeparty.com',
    country: 'PK',
    region: 'South Asia',
    referralSource: 'Direct Application',
    submittedAt: '2026-08-25T10:00:00Z',
    status: 'PENDING',
    previousExperience: 'Ex-BIGO Regional BD Manager (3 years)',
    notes: 'Strong candidate for Pakistan agency recruitment.'
  },
  {
    id: 'bd-app-102',
    userId: 'usr-882',
    nickname: 'Sophia LATAM Lead',
    email: 'sophia.br@zeparty.com',
    country: 'BR',
    region: 'LATAM',
    referralSource: 'Agency Referral',
    submittedAt: '2026-08-26T14:20:00Z',
    status: 'PENDING',
    previousExperience: 'Managed 50+ Live Video Syndicates in Brazil',
    notes: 'Awaiting background verification on creator agency ties.'
  }
];

export const MOCK_TARGET_POLICIES = [
  {
    id: 'tgt-pol-01',
    name: 'Platinum BD Growth Target Q3',
    metric: 'recharge', // recharge, coins, team, revenue
    targetValue: 25000000,
    cycle: 'Monthly', // Daily, Weekly, 15-Day, Monthly, Custom
    scope: 'Global', // Global, Country, Region, Individual
    effectiveDate: '2026-08-01',
    status: 'ACTIVE',
    minActiveAgencies: 5,
    minActiveSellers: 3
  },
  {
    id: 'tgt-pol-02',
    name: 'LATAM Agency Expansion Target',
    metric: 'team',
    targetValue: 10, // 10 new agencies
    cycle: '15-Day',
    scope: 'Region',
    targetRegion: 'LATAM',
    effectiveDate: '2026-08-15',
    status: 'ACTIVE',
    minActiveAgencies: 10,
    minActiveSellers: 2
  }
];

export const MOCK_SALARY_PLANS = [
  {
    id: 'sal-plan-01',
    name: 'Standard Regional BD Tier A',
    fixedSalary: 2500, // USD
    currency: 'USD',
    commissionRate: 3.5, // 3.5%
    commissionBase: 'Gross Attributed Recharge',
    tierBonusThreshold: 20000000,
    tierBonusAmount: 1000,
    penaltyRule: '10% deduction if target achievement < 60%',
    payoutCycle: 'Monthly',
    requiresDualApproval: true,
    status: 'ACTIVE'
  },
  {
    id: 'sal-plan-02',
    name: 'Senior Agency Recruiter Plan',
    fixedSalary: 1800,
    currency: 'USD',
    commissionRate: 5.0,
    commissionBase: 'Agency Revenue',
    tierBonusThreshold: 15000000,
    tierBonusAmount: 800,
    penaltyRule: 'None',
    payoutCycle: '15-Day',
    requiresDualApproval: false,
    status: 'ACTIVE'
  }
];

export const MOCK_PAYOUTS = [
  {
    id: 'pay-701',
    bdId: 'bd-101',
    bdName: 'Hassan BD Manager',
    period: '2026-08 (Monthly)',
    payableAmount: 4850,
    paidAmount: 4850,
    heldAmount: 0,
    status: 'Paid',
    payoutMethod: 'Bank Transfer (USD)',
    transactionRef: 'TXN-PAY-994812',
    calculatedAt: '2026-08-01T00:00:00Z',
    paidAt: '2026-08-05T12:30:00Z'
  },
  {
    id: 'pay-702',
    bdId: 'bd-102',
    bdName: 'Elena LATAM Lead',
    period: '2026-08 (15-Day)',
    payableAmount: 3200,
    paidAmount: 0,
    heldAmount: 0,
    status: 'Approved',
    payoutMethod: 'USDT (TRC20)',
    transactionRef: null,
    calculatedAt: '2026-08-16T00:00:00Z',
    paidAt: null
  },
  {
    id: 'pay-703',
    bdId: 'bd-103',
    bdName: 'Marcus EU Ops',
    period: '2026-08 (15-Day)',
    payableAmount: 1950,
    paidAmount: 0,
    heldAmount: 1950,
    status: 'Held',
    payoutMethod: 'Bank Transfer (EUR)',
    transactionRef: null,
    calculatedAt: '2026-08-16T00:00:00Z',
    paidAt: null
  }
];

export const MOCK_BD_REACTIONS = [
  {
    id: 'bd-react-01',
    name: 'Top Performer Crown',
    icon: '👑',
    assetUrl: 'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?auto=format&fit=crop&w=200&q=80',
    type: 'animated',
    placement: 'Profile & Leaderboard',
    scope: 'Global',
    isPaid: false,
    priceCoins: 0,
    status: 'ACTIVE',
    usageCount: 1420
  },
  {
    id: 'bd-react-02',
    name: 'Target Achieved Fire',
    icon: '🔥',
    assetUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=200&q=80',
    type: 'static',
    placement: 'Team Roster',
    scope: 'Global',
    isPaid: true,
    priceCoins: 100,
    status: 'ACTIVE',
    usageCount: 890
  }
];

export const MOCK_APP_EMOJIS = [
  {
    id: 'emoji-01',
    name: 'ZeParty Gold Heart',
    category: 'Love',
    assetUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=200&q=80',
    format: 'WebP',
    isAnimated: true,
    displayOrder: 1,
    availability: 'Party & Live Rooms',
    eligibility: 'Everyone',
    unlockType: 'Free',
    priceCoins: 0,
    scope: 'Global',
    status: 'ACTIVE',
    usageCount: 45200
  },
  {
    id: 'emoji-02',
    name: 'SVIP Dragon Roar',
    category: 'SVIP',
    assetUrl: 'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?auto=format&fit=crop&w=200&q=80',
    format: 'WebP',
    isAnimated: true,
    displayOrder: 2,
    availability: 'Live Rooms',
    eligibility: 'SVIP Only',
    unlockType: 'SVIP Level 5+',
    priceCoins: 50,
    scope: 'Global',
    status: 'ACTIVE',
    usageCount: 12800
  }
];
