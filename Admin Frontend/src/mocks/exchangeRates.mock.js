// ============================================================
// ZeParty Admin Portal — Exchange Rates Admin Control Mock Data
// ============================================================

export const MOCK_EXCHANGE_RATES = [
  {
    id: 'ex-101',
    rateType: 'USD_TO_COIN',
    name: 'USD to Coin Standard Rate',
    currency: 'USD',
    country: 'GLOBAL',
    currentRate: 10000, // 1 USD = 10,000 Coins
    proposedRate: 10500,
    unit: 'Coins / $1 USD',
    status: 'ACTIVE',
    version: 'v3.2.0',
    effectiveDate: '2026-08-01T00:00:00Z',
    createdBy: 'Super Admin',
    approvedBy: 'Finance Lead',
    updatedAt: '2026-08-01T00:00:00Z',
    history: [
      { version: 'v3.2.0', rate: 10000, effectiveDate: '2026-08-01', changedBy: 'Super Admin', notes: 'Baseline 2026 standard coin conversion.' },
      { version: 'v3.1.0', rate: 9500, effectiveDate: '2026-05-15', changedBy: 'Finance Admin', notes: 'Mid-year promotional rate update.' },
      { version: 'v3.0.0', rate: 9000, effectiveDate: '2026-01-01', changedBy: 'Super Admin', notes: 'Initial 2026 launch rate.' }
    ]
  },
  {
    id: 'ex-102',
    rateType: 'DIAMOND_TO_USD',
    name: 'Diamond to USD Payout Rate',
    currency: 'USD',
    country: 'GLOBAL',
    currentRate: 10000, // 10,000 Diamonds = $1 USD
    proposedRate: 10000,
    unit: 'Diamonds / $1 USD',
    status: 'ACTIVE',
    version: 'v3.0.0',
    effectiveDate: '2026-01-01T00:00:00Z',
    createdBy: 'Finance Admin',
    approvedBy: 'Super Admin',
    updatedAt: '2026-01-01T00:00:00Z',
    history: [
      { version: 'v3.0.0', rate: 10000, effectiveDate: '2026-01-01', changedBy: 'Finance Admin', notes: 'Established host payout conversion baseline.' }
    ]
  },
  {
    id: 'ex-103',
    rateType: 'PK_LOCAL_CURRENCY',
    name: 'PKR Local Fiat to Coin Rate',
    currency: 'PKR',
    country: 'PK',
    currentRate: 35, // 1 PKR = 35 Coins
    proposedRate: 38,
    unit: 'Coins / 1 PKR',
    status: 'SCHEDULED',
    version: 'v3.3.0-draft',
    effectiveDate: '2026-09-01T00:00:00Z',
    createdBy: 'Regional Admin PK',
    approvedBy: 'Finance Lead',
    updatedAt: '2026-08-20T10:00:00Z',
    history: [
      { version: 'v3.2.0', rate: 35, effectiveDate: '2026-06-01', changedBy: 'Regional Admin PK', notes: 'Adjusted for FX inflation.' }
    ]
  },
  {
    id: 'ex-104',
    rateType: 'BRL_LOCAL_CURRENCY',
    name: 'BRL Local Fiat to Coin Rate',
    currency: 'BRL',
    country: 'BR',
    currentRate: 1800, // 1 BRL = 1,800 Coins
    proposedRate: 1800,
    unit: 'Coins / 1 BRL',
    status: 'ACTIVE',
    version: 'v3.1.0',
    effectiveDate: '2026-04-10T00:00:00Z',
    createdBy: 'Finance Admin',
    approvedBy: 'Super Admin',
    updatedAt: '2026-04-10T00:00:00Z',
    history: [
      { version: 'v3.1.0', rate: 1800, effectiveDate: '2026-04-10', changedBy: 'Finance Admin', notes: 'LATAM expansion localized rate.' }
    ]
  }
];
