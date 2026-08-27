// ============================================================
// ZeParty Admin Portal — Policy Configuration Mock Data Refactored
// Aligned with 2026 policies and specifications
// ============================================================

import { CURRENT_LIVE_HOST_POLICY } from './policies/liveHostPolicy.mock';
import { CURRENT_AUDIO_HOST_POLICY } from './policies/audioHostPolicy.mock';
import { CURRENT_COINS_SELLER_POLICY } from './policies/coinsSellerPolicy.mock';
import { CURRENT_MERCHANT_POLICY } from './policies/merchantPolicy.mock';
import { CURRENT_MANAGER_POLICY } from './policies/managerPolicy.mock';

export {
  CURRENT_LIVE_HOST_POLICY,
  CURRENT_AUDIO_HOST_POLICY,
  CURRENT_COINS_SELLER_POLICY,
  CURRENT_MERCHANT_POLICY,
  CURRENT_MANAGER_POLICY
};

export const CURRENT_RESELLER_POLICY = {
  version: CURRENT_COINS_SELLER_POLICY.version,
  effectiveDate: CURRENT_COINS_SELLER_POLICY.effectiveDate,
  description: CURRENT_COINS_SELLER_POLICY.description,
  packages: CURRENT_COINS_SELLER_POLICY.packages.map(p => ({
    priceUSD: p.priceUSD,
    tierName: p.tierName,
    coinRatio: p.ratio,
    totalCoins: p.totalCoins,
    profitPercent: p.profitPercent
  }))
};

export const CURRENT_WITHDRAWAL_POLICY = {
  version: 'v3.0.0',
  minWithdrawalUSD: 10.00,
  maxWithdrawalDailyUSD: 5000.00,
  diamondToUSDRate: 10000, // 10,000 diamonds = $1
  processingTime: '24-48 Hours',
  supportedMethods: ['Bank Wire Transfer', 'USDT (TRC20)', 'PayPal Express', 'Local E-Wallet']
};

export const CURRENT_ECONOMY_POLICY = {
  version: 'v3.0.0',
  coinRate: 10000, // coins per $1
  diamondRate: 10000, // diamonds per $1
  platformShare: 60,
  agencyShare: 20,
  hostBackup: 10,
  roomReward: 10,
  coinToDiamondExchangeRate: 1.0,
  hostCommissionRate: 0.70,
  platformFeeRate: 0.30,
  agencyShareDefault: 20,
  status: 'ACTIVE'
};

export const POLICY_HISTORIES = [
  {
    policyType: 'Economy',
    version: 'v3.0.0',
    effectiveDate: '2026-08-24',
    status: 'CURRENT',
    applyFrom: '2026-08-24',
    summary: 'Official 2026 updates including Manager Policy, 25-tier Host policies, and Coins Seller/Merchant pricing adjustments.',
    approvedBy: 'Super Admin'
  },
  {
    policyType: 'Live Host',
    version: 'v3.0.0',
    effectiveDate: '2026-08-24',
    status: 'CURRENT',
    applyFrom: '2026-08-24',
    summary: 'Updated live host policy to 25 levels, 15-day payouts, 1h daily streams for 10 days, and 5% room reward.',
    approvedBy: 'Super Admin'
  },
  {
    policyType: 'Agency Host',
    version: 'v3.0.0',
    effectiveDate: '2026-08-24',
    status: 'CURRENT',
    applyFrom: '2026-08-24',
    summary: 'Released 25-level matrix for agency hosts with Diamond Targets/15 days, splits, and Special ID duration rules.',
    approvedBy: 'Super Admin'
  },
  {
    policyType: 'Manager',
    version: 'v3.0.0',
    effectiveDate: '2026-08-24',
    status: 'CURRENT',
    applyFrom: '2026-08-24',
    summary: 'Configured new Manager prerequisites: locations open, reliable team, $1,000 Coin Seller portal baseline, $2,000 cap.',
    approvedBy: 'Super Admin'
  },
  {
    policyType: 'Coin Reseller',
    version: 'v3.0.0',
    effectiveDate: '2026-08-24',
    status: 'CURRENT',
    applyFrom: '2026-08-24',
    summary: 'Updated package structures to $300, $500, $1,000 with corresponding margins and security/insurance verification.',
    approvedBy: 'Super Admin'
  },
  {
    policyType: 'Merchant',
    version: 'v3.0.0',
    effectiveDate: '2026-08-24',
    status: 'CURRENT',
    applyFrom: '2026-08-24',
    summary: 'Merchant fee update: $3,000 portal price, 20% margin, $1,000 monthly target, and $300 minimum open amount.',
    approvedBy: 'Super Admin'
  }
];
