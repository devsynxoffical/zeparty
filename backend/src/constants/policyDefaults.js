/**
 * Single Authoritative Source of Truth for ZeParty Policy Defaults & Baseline Configurations.
 *
 * All rates and percentages use exact integer representation or basis points (bps):
 * - 100 bps = 1.0%
 * - 10,000 bps = 100.0%
 * - 1 USD = 10,000 Coins
 * - 10,000 Diamonds = 1.00 USD
 */

export const CANONICAL_POLICY_TYPES = [
  'ECONOMY',
  'LIVE_HOST',
  'AUDIO_HOST',
  'AGENCY_HOST',
  'RESELLER',
  'MERCHANT',
  'MANAGER',
];

export const CANONICAL_CONFIG_KEYS = [
  'USD_TO_COIN_RATE',
  'DIAMOND_TO_USD_RATE',
  'RESELLER_TRANSFER_FEE_PERCENT',
  'HOST_TRANSFER_FEE_PERCENT',
  'MIN_WITHDRAWAL_USD',
  'MAX_WITHDRAWAL_DAILY_USD',
  'APPROVAL_THRESHOLD_USD',
  'APPROVAL_THRESHOLD_COINS',
  'ROOM_OWNER_REWARD_PERCENT',
  'INCOMPLETE_DAYS_PAYOUT_PERCENT',
  'AUDIO_HOST_DAILY_HOURS',
  'LIVE_HOST_DAILY_HOURS',
];

export const BASELINE_CONFIG_VALUES = {
  USD_TO_COIN_RATE: {
    rate: 10000,
    unit: 'Coins / 1 USD',
    description: 'Standard USD to coin purchase conversion rate',
  },
  DIAMOND_TO_USD_RATE: {
    rate: 10000,
    unit: 'Diamonds / 1 USD',
    description: 'Standard diamond to USD host cashout rate',
  },
  RESELLER_TRANSFER_FEE_PERCENT: {
    ratePercent: 2.5,
    description: 'Percentage commission fee for reseller coin allocations',
  },
  HOST_TRANSFER_FEE_PERCENT: {
    ratePercent: 5.0,
    description: 'Percentage commission fee for host-to-host coin transfers',
  },
  MIN_WITHDRAWAL_USD: {
    amountUSD: 10.0,
    description: 'Minimum withdrawal amount in USD',
  },
  MAX_WITHDRAWAL_DAILY_USD: {
    amountUSD: 5000.0,
    description: 'Maximum daily withdrawal threshold in USD per host',
  },
  APPROVAL_THRESHOLD_USD: {
    amountUSD: 100.0,
    description: 'Financial threshold requiring two-stage maker-checker approval',
  },
  APPROVAL_THRESHOLD_COINS: {
    amountCoins: '1000000',
    description: 'Coin threshold requiring two-stage maker-checker approval',
  },
  ROOM_OWNER_REWARD_PERCENT: {
    ratePercent: 5.0,
    description: 'Weekly room owner reward percentage for sending users to a room',
  },
  INCOMPLETE_DAYS_PAYOUT_PERCENT: {
    ratePercent: 50.0,
    description: 'Payout percentage (50%) if host does not complete valid required days',
  },
  AUDIO_HOST_DAILY_HOURS: {
    hours: 2.0,
    description: 'Daily audio hosting requirement for Audio Hosts and Agency Hosts',
  },
  LIVE_HOST_DAILY_HOURS: {
    hours: 1.0,
    description: 'Daily live hosting requirement for Live Hosts (for 10 days)',
  },
};

export const BASELINE_POLICY_TEMPLATES = {
  ECONOMY: {
    policyType: 'ECONOMY',
    version: 'v3.0.0',
    description: 'Master Platform Virtual Economy, Revenue Sharing & Conversion Standards',
    config: {
      version: 'v3.0.0',
      platformShareBps: 4500, // 45.0%
      hostShareBps: 3500,     // 35.0%
      agencyShareBps: 1200,   // 12.0%
      roomRewardBps: 800,     // 8.0%
      coinToDiamondExchangeRate: 1.0,
      coinRateUSD: 10000,
      diamondRateUSD: 10000,
      status: 'ACTIVE',
    },
  },
  LIVE_HOST: {
    policyType: 'LIVE_HOST',
    version: 'v3.0.0',
    description: 'Creator Video Live Streaming 25-Level Target Matrix & Salary Policy (ZeParty 2026)',
    config: {
      version: 'v3.0.0',
      payoutCycleDays: 15,
      roomOwnerRewardPercent: 5,
      incompleteDaysPayoutPercent: 50,
      dailyHoursRequired: 1.0,
      daysRequired: 10,
      directRegistration: true,
      agencyRequired: false,
      verificationInApp: true,
      rules: [
        'If you send users to a room, the room owner will receive a 5% reward weekly.',
        'If the host does not complete the valid days, he will receive only 50% of the target.',
        'To become a Live Host, you must complete your verification in the ZeParty app.',
        'No agency is required — you can register directly through the app and become a Live Host yourself.',
      ],
      tiers: [
        { level: 1, targetDiamonds: 25000, durationDays: 10, basicSalaryUSD: 2.00 },
        { level: 2, targetDiamonds: 50000, durationDays: 10, basicSalaryUSD: 4.00 },
        { level: 3, targetDiamonds: 100000, durationDays: 10, basicSalaryUSD: 8.00 },
        { level: 4, targetDiamonds: 250000, durationDays: 10, basicSalaryUSD: 20.00 },
        { level: 5, targetDiamonds: 500000, durationDays: 8, basicSalaryUSD: 40.00 },
        { level: 6, targetDiamonds: 750000, durationDays: 8, basicSalaryUSD: 60.00 },
        { level: 7, targetDiamonds: 1000000, durationDays: 8, basicSalaryUSD: 80.00 },
        { level: 8, targetDiamonds: 1500000, durationDays: 8, basicSalaryUSD: 120.00 },
        { level: 9, targetDiamonds: 2000000, durationDays: 8, basicSalaryUSD: 160.00 },
        { level: 10, targetDiamonds: 2500000, durationDays: 8, basicSalaryUSD: 200.00 },
        { level: 11, targetDiamonds: 3000000, durationDays: 5, basicSalaryUSD: 240.00 },
        { level: 12, targetDiamonds: 3500000, durationDays: 5, basicSalaryUSD: 280.00 },
        { level: 13, targetDiamonds: 4000000, durationDays: 5, basicSalaryUSD: 320.00 },
        { level: 14, targetDiamonds: 4500000, durationDays: 5, basicSalaryUSD: 360.00 },
        { level: 15, targetDiamonds: 5000000, durationDays: 5, basicSalaryUSD: 400.00 },
        { level: 16, targetDiamonds: 6000000, durationDays: 5, basicSalaryUSD: 480.00 },
        { level: 17, targetDiamonds: 7000000, durationDays: 5, basicSalaryUSD: 560.00 },
        { level: 18, targetDiamonds: 8000000, durationDays: 5, basicSalaryUSD: 640.00 },
        { level: 19, targetDiamonds: 9000000, durationDays: 5, basicSalaryUSD: 720.00 },
        { level: 20, targetDiamonds: 10000000, durationDays: 5, basicSalaryUSD: 800.00 },
        { level: 21, targetDiamonds: 15000000, durationDays: 5, basicSalaryUSD: 1200.00 },
        { level: 22, targetDiamonds: 20000000, durationDays: 5, basicSalaryUSD: 1600.00 },
        { level: 23, targetDiamonds: 30000000, durationDays: 5, basicSalaryUSD: 2400.00 },
        { level: 24, targetDiamonds: 40000000, durationDays: 5, basicSalaryUSD: 3200.00 },
        { level: 25, targetDiamonds: 50000000, durationDays: 5, basicSalaryUSD: 4000.00 },
      ],
    },
  },
  AGENCY_HOST: {
    policyType: 'AGENCY_HOST',
    version: 'v3.0.0',
    description: 'Agency Host 25-Level Policy with Host & Agency Split and Special ID Bonus (ZeParty 2026)',
    config: {
      version: 'v3.0.0',
      payoutCycleDays: 15,
      roomOwnerRewardPercent: 5,
      incompleteDaysPayoutPercent: 50,
      dailyHoursRequired: 2.0,
      rules: [
        'If you send users to a room, the room owner will receive a 5% reward weekly.',
        'If the host does not complete the valid days, he will receive only 50% of the target.',
        'Audio Hosts are required to complete 2 hours of audio hosting daily according to their assigned target.',
      ],
      tiers: [
        { level: 1, targetDiamonds: 25000, durationDays: 10, basicTotalSalaryUSD: 2.00, hostSalaryUSD: 1.60, agencySalaryUSD: 0.40, specialIdBonus: '/' },
        { level: 2, targetDiamonds: 50000, durationDays: 10, basicTotalSalaryUSD: 4.00, hostSalaryUSD: 3.20, agencySalaryUSD: 0.80, specialIdBonus: '/' },
        { level: 3, targetDiamonds: 100000, durationDays: 10, basicTotalSalaryUSD: 8.00, hostSalaryUSD: 6.40, agencySalaryUSD: 1.60, specialIdBonus: '/' },
        { level: 4, targetDiamonds: 250000, durationDays: 10, basicTotalSalaryUSD: 20.00, hostSalaryUSD: 16.00, agencySalaryUSD: 4.00, specialIdBonus: '/' },
        { level: 5, targetDiamonds: 500000, durationDays: 8, basicTotalSalaryUSD: 40.00, hostSalaryUSD: 32.00, agencySalaryUSD: 8.00, specialIdBonus: '/' },
        { level: 6, targetDiamonds: 750000, durationDays: 8, basicTotalSalaryUSD: 60.00, hostSalaryUSD: 48.00, agencySalaryUSD: 12.00, specialIdBonus: '/' },
        { level: 7, targetDiamonds: 1000000, durationDays: 8, basicTotalSalaryUSD: 80.00, hostSalaryUSD: 64.00, agencySalaryUSD: 16.00, specialIdBonus: '/' },
        { level: 8, targetDiamonds: 1500000, durationDays: 8, basicTotalSalaryUSD: 120.00, hostSalaryUSD: 96.00, agencySalaryUSD: 24.00, specialIdBonus: '/' },
        { level: 9, targetDiamonds: 2000000, durationDays: 8, basicTotalSalaryUSD: 160.00, hostSalaryUSD: 128.00, agencySalaryUSD: 32.00, specialIdBonus: '/' },
        { level: 10, targetDiamonds: 2500000, durationDays: 8, basicTotalSalaryUSD: 200.00, hostSalaryUSD: 160.00, agencySalaryUSD: 40.00, specialIdBonus: '/' },
        { level: 11, targetDiamonds: 3000000, durationDays: 5, basicTotalSalaryUSD: 240.00, hostSalaryUSD: 192.00, agencySalaryUSD: 48.00, specialIdBonus: 'Special ID 3 Days' },
        { level: 12, targetDiamonds: 3500000, durationDays: 5, basicTotalSalaryUSD: 280.00, hostSalaryUSD: 224.00, agencySalaryUSD: 56.00, specialIdBonus: 'Special ID 3 Days' },
        { level: 13, targetDiamonds: 4000000, durationDays: 5, basicTotalSalaryUSD: 320.00, hostSalaryUSD: 256.00, agencySalaryUSD: 64.00, specialIdBonus: 'Special ID 3 Days' },
        { level: 14, targetDiamonds: 4500000, durationDays: 5, basicTotalSalaryUSD: 360.00, hostSalaryUSD: 288.00, agencySalaryUSD: 72.00, specialIdBonus: 'Special ID 7 Days' },
        { level: 15, targetDiamonds: 5000000, durationDays: 5, basicTotalSalaryUSD: 400.00, hostSalaryUSD: 320.00, agencySalaryUSD: 80.00, specialIdBonus: 'Special ID 15 Days' },
        { level: 16, targetDiamonds: 6000000, durationDays: 5, basicTotalSalaryUSD: 480.00, hostSalaryUSD: 384.00, agencySalaryUSD: 96.00, specialIdBonus: 'Special ID 15 Days' },
        { level: 17, targetDiamonds: 7000000, durationDays: 5, basicTotalSalaryUSD: 560.00, hostSalaryUSD: 448.00, agencySalaryUSD: 112.00, specialIdBonus: 'Special ID 15 Days' },
        { level: 18, targetDiamonds: 8000000, durationDays: 5, basicTotalSalaryUSD: 640.00, hostSalaryUSD: 512.00, agencySalaryUSD: 128.00, specialIdBonus: 'Special ID 30 Days' },
        { level: 19, targetDiamonds: 9000000, durationDays: 5, basicTotalSalaryUSD: 720.00, hostSalaryUSD: 576.00, agencySalaryUSD: 144.00, specialIdBonus: 'Special ID 30 Days' },
        { level: 20, targetDiamonds: 10000000, durationDays: 5, basicTotalSalaryUSD: 800.00, hostSalaryUSD: 640.00, agencySalaryUSD: 160.00, specialIdBonus: 'Special ID 60 Days' },
        { level: 21, targetDiamonds: 15000000, durationDays: 5, basicTotalSalaryUSD: 1200.00, hostSalaryUSD: 960.00, agencySalaryUSD: 240.00, specialIdBonus: 'Special ID 60 Days' },
        { level: 22, targetDiamonds: 20000000, durationDays: 5, basicTotalSalaryUSD: 1600.00, hostSalaryUSD: 1280.00, agencySalaryUSD: 320.00, specialIdBonus: 'Special ID 60 Days' },
        { level: 23, targetDiamonds: 30000000, durationDays: 5, basicTotalSalaryUSD: 2400.00, hostSalaryUSD: 1920.00, agencySalaryUSD: 480.00, specialIdBonus: 'Special ID 90 Days' },
        { level: 24, targetDiamonds: 40000000, durationDays: 5, basicTotalSalaryUSD: 3200.00, hostSalaryUSD: 2560.00, agencySalaryUSD: 640.00, specialIdBonus: 'Special ID 90 Days' },
        { level: 25, targetDiamonds: 50000000, durationDays: 5, basicTotalSalaryUSD: 4000.00, hostSalaryUSD: 3200.00, agencySalaryUSD: 800.00, specialIdBonus: 'Special ID 120 Days' },
      ],
    },
  },
  AUDIO_HOST: {
    policyType: 'AUDIO_HOST',
    version: 'v3.0.0',
    description: 'Social Audio Party Room Host Rewards & Commission Policy',
    config: {
      version: 'v3.0.0',
      minDailyHours: 2,
      tiers: [
        { tierName: '30K Audio Tier', targetCoins: 30000, dailyRewardUSD: 0.8, agencyProfitUSD: 0.15 },
        { tierName: '60K Audio Tier', targetCoins: 60000, dailyRewardUSD: 1.6, agencyProfitUSD: 0.3 },
        { tierName: '100K Audio Tier', targetCoins: 100000, dailyRewardUSD: 2.8, agencyProfitUSD: 0.5 },
        { tierName: '350K Audio Tier', targetCoins: 350000, dailyRewardUSD: 9.5, agencyProfitUSD: 1.7 },
      ],
    },
  },
  RESELLER: {
    policyType: 'RESELLER',
    version: 'v3.0.0',
    description: 'Official 2026 Coins Seller & Merchant Rate Matrix and Compliance Policy',
    config: {
      version: 'v3.0.0',
      status: 'ACTIVE',
      rules: [
        'To become a ZeParty Coins Seller, you must complete the required security insurance/verification before starting.',
        "If a Coins Seller changes the official coin rate or fails to provide a user's withdrawal on time, the Coins Seller account may be terminated and Coins Seller privileges may be removed.",
      ],
      packages: [
        { priceUSD: 300, profitRatioPercent: 5, totalCoins: 2205000, tierName: '$300 Coin Seller Tier' },
        { priceUSD: 500, profitRatioPercent: 5, totalCoins: 3675000, tierName: '$500 Coin Seller Tier' },
        { priceUSD: 1000, profitRatioPercent: 10, totalCoins: 7700000, tierName: '$1,000 Coin Seller Tier' },
      ],
    },
  },
  MERCHANT: {
    policyType: 'MERCHANT',
    version: 'v3.0.0',
    description: 'Official 2026 Merchant Rate Matrix, Minimum Targets and Portal Rules',
    config: {
      version: 'v3.0.0',
      status: 'ACTIVE',
      profitRatioPercent: 20,
      minMonthlyAppPurchasesUSD: 1000,
      minPortalOpeningAmountUSD: 300,
      rules: [
        'The Merchant level offers a higher profit rate of 20%.',
        'To become a ZeParty Merchant, you must achieve a minimum target of $1,000 in purchases on the app within one month.',
        'After completing the requirement, you will be eligible to become a Merchant.',
        'A Merchant cannot open a new portal for an amount below $300.',
      ],
      packages: [
        { priceUSD: 3000, profitRatioPercent: 20, totalCoins: 25200000, tierName: '$3,000 Merchant Tier' },
      ],
    },
  },
  MANAGER: {
    policyType: 'MANAGER',
    version: 'v3.0.0',
    description: 'Official 2026 Manager Eligibility & Operational Requirements Policy',
    config: {
      version: 'v3.0.0',
      status: 'ACTIVE',
      maxMonthlyWorkTargetUSD: 2000,
      initialCoinSellerRequiredUSD: 1000,
      locationScope: 'GLOBAL_ANY_LOCATION',
      requirements: [
        { key: 'Location', policy: 'Manager applications are open for any location.' },
        { key: 'Team', policy: 'You must have a strong and reliable team before becoming a Manager.' },
        { key: 'Monthly Work', policy: 'Your maximum monthly work/target should be up to $2,000.' },
        { key: 'Initial Coins Seller', policy: 'You must first open/manage a Coins Seller level up to $1,000.' },
      ],
      managerNote: 'To become a ZeParty Manager, you should have a capable team that can actively support users and operations in your selected location. The Manager must first demonstrate performance by opening a Coins Seller operation up to $1,000, while the maximum monthly work/target is set at $2,000.',
    },
  },
};

export default {
  CANONICAL_POLICY_TYPES,
  CANONICAL_CONFIG_KEYS,
  BASELINE_CONFIG_VALUES,
  BASELINE_POLICY_TEMPLATES,
};
