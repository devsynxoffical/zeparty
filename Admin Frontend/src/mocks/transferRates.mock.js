// ============================================================
// ZeParty Admin Portal — Transfer Rates Admin Control Mock Data
// ============================================================

export const MOCK_TRANSFER_RATES = [
  {
    id: 'tr-201',
    transferType: 'COIN_RESELLER_FEE',
    name: 'Reseller Coin Transfer Commission',
    description: 'Percentage fee applied to bulk coin transfers between platform and resellers',
    currentRatePercent: 2.5, // 2.5%
    proposedRatePercent: 3.0,
    status: 'ACTIVE',
    version: 'v2.1.0',
    effectiveDate: '2026-07-01T00:00:00Z',
    createdBy: 'Finance Lead',
    approvedBy: 'Super Admin',
    updatedAt: '2026-07-01T00:00:00Z',
    history: [
      { version: 'v2.1.0', ratePercent: 2.5, effectiveDate: '2026-07-01', changedBy: 'Finance Lead', notes: 'Standard 2.5% fee on reseller coin distribution.' },
      { version: 'v2.0.0', ratePercent: 2.0, effectiveDate: '2026-01-15', changedBy: 'Super Admin', notes: 'Initial 2026 reseller fee.' }
    ]
  },
  {
    id: 'tr-202',
    transferType: 'MERCHANT_ALLOCATION_FEE',
    name: 'Merchant Coin Allocation Fee',
    description: 'Processing percentage fee for custom merchant coin allocations',
    currentRatePercent: 1.8,
    proposedRatePercent: 2.0,
    status: 'ACTIVE',
    version: 'v1.4.0',
    effectiveDate: '2026-06-15T00:00:00Z',
    createdBy: 'Finance Admin',
    approvedBy: 'Super Admin',
    updatedAt: '2026-06-15T00:00:00Z',
    history: [
      { version: 'v1.4.0', ratePercent: 1.8, effectiveDate: '2026-06-15', changedBy: 'Finance Admin', notes: 'Updated for merchant tier 2 allocation.' }
    ]
  },
  {
    id: 'tr-203',
    transferType: 'HOST_TO_HOST_TRANSFER_FEE',
    name: 'Host-to-Host Coin Transfer Fee',
    description: 'Commission fee for direct user/host coin transfers in room chats',
    currentRatePercent: 5.0,
    proposedRatePercent: 5.0,
    status: 'ACTIVE',
    version: 'v3.0.0',
    effectiveDate: '2026-01-01T00:00:00Z',
    createdBy: 'Super Admin',
    approvedBy: 'Super Admin',
    updatedAt: '2026-01-01T00:00:00Z',
    history: [
      { version: 'v3.0.0', ratePercent: 5.0, effectiveDate: '2026-01-01', changedBy: 'Super Admin', notes: 'Established anti-fraud transfer fee.' }
    ]
  },
  {
    id: 'tr-204',
    transferType: 'AGENCY_PAYOUT_TRANSFER_FEE',
    name: 'Agency Payout Transfer Processing Rate',
    description: 'External settlement transaction processing percentage for agency payouts',
    currentRatePercent: 1.2,
    proposedRatePercent: 1.5,
    status: 'DRAFT',
    version: 'v2.2.0-draft',
    effectiveDate: '2026-09-15T00:00:00Z',
    createdBy: 'Finance Admin',
    approvedBy: 'Pending Approval',
    updatedAt: '2026-08-25T15:00:00Z',
    history: [
      { version: 'v2.1.0', ratePercent: 1.2, effectiveDate: '2026-03-01', changedBy: 'Finance Lead', notes: 'Baseline processing fee.' }
    ]
  }
];
