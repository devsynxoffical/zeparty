export const CURRENT_MERCHANT_POLICY = {
  version: 'v3.0.0',
  effectiveDate: '2026-08-24',
  status: 'ACTIVE',
  priceUSD: 3000,
  profitPercent: 20,
  totalCoins: 25200000,
  monthlySalesTargetUSD: 1000,
  minPortalOpenAmountUSD: 300,
  description: 'Official 2026 Merchant Policy: $3,000 portal price, 20% profit, 25,200,000 coin allotment. Target of $1,000/month purchases required to unlock, and minimum new portal open amount of $300.',
  rules: [
    'Minimum target of $1,000 in purchases within one month is required to be eligible for Merchant status.',
    'A Merchant cannot open a new portal for an amount below $300.'
  ]
};
