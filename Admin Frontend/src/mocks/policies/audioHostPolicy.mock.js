export const CURRENT_AUDIO_HOST_POLICY = {
  version: 'v3.0.0',
  effectiveDate: '2026-08-24',
  status: 'ACTIVE',
  minTargetCoins: 30000,
  dailyHoursRequired: 2,
  description: 'Official 2026 Audio Host & Voice Performer Incentive Matrix for Social Audio Rooms.',
  rules: [
    'Minimum 2 hours of audio hosting daily is required according to the assigned target.',
    'Listener gifts and audio room tip jar count 100% towards host target.',
    'Audio agency receives commission according to type.'
  ],
  tiers: [
    { targetCoins: 30000, label: '30K Audio Tier', dailyRewardUSD: 0.80, weeklyRewardUSD: 0.40, agencyProfitUSD: 0.15 },
    { targetCoins: 60000, label: '60K Audio Tier', dailyRewardUSD: 1.60, weeklyRewardUSD: 0.80, agencyProfitUSD: 0.30 },
    { targetCoins: 100000, label: '100K Audio Tier', dailyRewardUSD: 2.80, weeklyRewardUSD: 1.40, agencyProfitUSD: 0.50 },
    { targetCoins: 200000, label: '200K Audio Tier', dailyRewardUSD: 5.50, weeklyRewardUSD: 2.75, agencyProfitUSD: 1.00 },
    { targetCoins: 350000, label: '350K Audio Tier', dailyRewardUSD: 9.50, weeklyRewardUSD: 4.75, agencyProfitUSD: 1.70 },
  ]
};
