export const CURRENT_COINS_SELLER_POLICY = {
  version: 'v3.0.0',
  effectiveDate: '2026-08-24',
  status: 'ACTIVE',
  description: 'Official 2026 Coin Reseller Policy. Configurable price tiers, profit shares, security insurance check, and instant termination clauses for rate change or withdrawal delay.',
  securityInsuranceRequired: true,
  rules: [
    'Security insurance / verification is strictly required before starting Coin Seller operations.',
    'Changing the official coin rate or failing to process a user withdrawal on time triggers immediate portal termination and role/privilege revocation.'
  ],
  packages: [
    { priceUSD: 300, profitPercent: 5, totalCoins: 2205000, ratio: 7350, tierName: '$300 Reseller Tier' },
    { priceUSD: 500, profitPercent: 5, totalCoins: 3675000, ratio: 7350, tierName: '$500 Reseller Tier' },
    { priceUSD: 1000, profitPercent: 10, totalCoins: 7700000, ratio: 7700, tierName: '$1,000 Reseller Tier' }
  ]
};
