// ============================================================
// ZeParty Admin Portal — Refunds & Risk Mock Data (JSX)
// Client Excel Phase C Specifications
// ============================================================

export const MOCK_COIN_REFUNDS = [
  {
    id: 'CRF-1001',
    originalTxnId: 'TXN-90821-A',
    sourceUser: 'StarQueen Luna (usr-001)',
    coins: 500000,
    reason: 'Accidental duplicate recharge credit',
    status: 'PENDING_REVIEW',
    requestedBy: 'Finance Admin',
    requestedAt: '2026-08-20T09:00:00Z',
    downstreamImpact: {
      transferred: 0,
      gifted: 100000,
      converted: 0,
      withdrawn: 0,
      remainingInWallet: 400000,
    },
  },
  {
    id: 'CRF-1002',
    originalTxnId: 'TXN-88120-X',
    sourceUser: 'SpamBot99 (usr-004)',
    coins: 2000000,
    reason: 'Excess reseller coin assignment error',
    status: 'APPROVED',
    requestedBy: 'Super Admin',
    requestedAt: '2026-08-19T14:30:00Z',
    downstreamImpact: {
      transferred: 0,
      gifted: 0,
      converted: 0,
      withdrawn: 0,
      remainingInWallet: 2000000,
    },
  },
];

export const MOCK_CHARGEBACKS = [
  {
    id: 'CB-501',
    gateway: 'Stripe',
    disputeId: 'dp_1M999901',
    user: 'NightOwl Kai',
    userId: 'usr-002',
    amountUSD: 100.0,
    coinsInvolved: 1000000,
    status: 'UNDER_HOLD',
    reversalState: 'WALLET_FROZEN',
    disputeDate: '2026-08-18T12:00:00Z',
  },
];

export const MOCK_RISK_ALERTS = [
  {
    id: 'RSK-801',
    user: 'BlazingRose',
    userId: 'usr-003',
    riskType: 'Self-Gifting Suspicion',
    riskScore: 88,
    status: 'HIGH_RISK',
    flaggedReason: 'Multiple alt accounts gifting same live room mic',
    timestamp: '2026-08-20T08:15:00Z',
  },
  {
    id: 'RSK-802',
    user: 'SpamBot99',
    userId: 'usr-004',
    riskType: 'Abnormal Rapid Sending',
    riskScore: 99,
    status: 'FROZEN',
    flaggedReason: 'Automated script sending 100 gifts/sec',
    timestamp: '2026-08-19T18:00:00Z',
  },
];
