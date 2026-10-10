import prisma from '../config/database.js';

/**
 * ZEPARTY COMPLETE SETTINGS MASTER SERVICE
 * Implements all 48 settings across 9 categories + 12 Implementation & Safety Rules.
 */

export const INITIAL_COMPLETE_SETTINGS = {
  // 1. Economy
  COIN_RATE: {
    id: 1,
    section: 'Economy',
    setting: 'Coin Rate',
    value: 10000,
    display: '10,000 coins = $1',
    unit: 'Coins / 1 USD',
    adminControl: 'Edit coins per $1',
    isEditable: true,
    isEnabled: true,
  },
  DIAMOND_CONVERSION: {
    id: 2,
    section: 'Economy',
    setting: 'Diamond Conversion',
    value: 12500,
    display: '12,500 diamonds = $1',
    unit: 'Diamonds / 1 USD',
    adminControl: 'Edit conversion ratio',
    isEditable: true,
    isEnabled: true,
  },
  GIFT_VALUE: {
    id: 3,
    section: 'Economy',
    setting: 'Gift Value',
    value: 'CATALOG_DYNAMIC',
    display: 'Dynamic Catalog (10 - 100,000 coins)',
    unit: 'Coins',
    adminControl: 'Add / edit gift values',
    isEditable: true,
    isEnabled: true,
  },
  PLATFORM_SHARE: {
    id: 4,
    section: 'Economy',
    setting: 'Platform Share',
    value: 60,
    display: '60%',
    unit: '%',
    adminControl: 'Edit platform %',
    isEditable: true,
    isEnabled: true,
  },
  ROOM_REWARD: {
    id: 5,
    section: 'Economy',
    setting: 'Room Reward',
    value: 10,
    display: '10%',
    unit: '%',
    adminControl: 'Edit room reward %',
    isEditable: true,
    isEnabled: true,
  },
  HOST_BACKUP: {
    id: 6,
    section: 'Economy',
    setting: 'Host Backup',
    value: 10,
    display: '10%',
    unit: '%',
    adminControl: 'Edit host backup %',
    isEditable: true,
    isEnabled: true,
  },
  AGENCY_COMMISSION: {
    id: 7,
    section: 'Economy',
    setting: 'Agency Commission',
    value: 20,
    display: '20%',
    unit: '%',
    adminControl: 'Edit agency %',
    isEditable: true,
    isEnabled: true,
  },

  // 2. Host Policy
  HOST_TARGET_TIERS: {
    id: 8,
    section: 'Host Policy',
    setting: 'Target Tiers',
    value: [
      { target: '40K', diamonds: 40000, dailyUSD: 1, weeklyUSD: 1, agencyProfit: 0.20 },
      { target: '80K', diamonds: 80000, dailyUSD: 2, weeklyUSD: 2, agencyProfit: 0.40 },
      { target: '120K', diamonds: 120000, dailyUSD: 3, weeklyUSD: 3, agencyProfit: 0.60 },
      { target: '200K', diamonds: 200000, dailyUSD: 5, weeklyUSD: 5, agencyProfit: 1.00 },
      { target: '400K', diamonds: 400000, dailyUSD: 10, weeklyUSD: 10, agencyProfit: 2.00 },
    ],
    display: '5 Active Tiers (40K to 400K)',
    unit: 'Tiers',
    adminControl: 'Add / edit / delete tiers',
    isEditable: true,
    isEnabled: true,
  },
  HOST_DAILY_REWARD: {
    id: 9,
    section: 'Host Policy',
    setting: 'Daily Reward',
    value: { '40K': 1, '80K': 2, '120K': 3, '200K': 5, '400K': 10 },
    display: 'Daily $1 to $10 based on Tier',
    unit: 'USD / Day',
    adminControl: 'Edit daily reward per tier',
    isEditable: true,
    isEnabled: true,
  },
  HOST_WEEKLY_REWARD: {
    id: 10,
    section: 'Host Policy',
    setting: 'Weekly Reward',
    value: { '40K': 1, '80K': 2, '120K': 3, '200K': 5, '400K': 10 },
    display: 'Weekly $1 to $10 based on Tier',
    unit: 'USD / Week',
    adminControl: 'Edit weekly reward per tier',
    isEditable: true,
    isEnabled: true,
  },
  HOST_AGENCY_PROFIT: {
    id: 11,
    section: 'Host Policy',
    setting: 'Agency Profit',
    value: { '40K': 0.20, '80K': 0.40, '120K': 0.60, '200K': 1.00, '400K': 2.00 },
    display: 'Agency Profit per Host Tier',
    unit: 'USD / Host',
    adminControl: 'Edit agency profit per tier',
    isEditable: true,
    isEnabled: true,
  },

  // 3. Live Host
  LIVE_HOST_MIN_TARGET: {
    id: 12,
    section: 'Live Host',
    setting: 'Minimum Target',
    value: 120000,
    display: '120K',
    unit: 'Diamonds',
    adminControl: 'Current: 120K',
    isEditable: true,
    isEnabled: true,
  },
  LIVE_HOST_TIERS: {
    id: 13,
    section: 'Live Host',
    setting: 'Live Host Tiers',
    value: [
      { target: '120K', diamonds: 120000, weeklyEarningsUSD: 9 },
      { target: '200K', diamonds: 200000, weeklyEarningsUSD: 15 },
      { target: '400K', diamonds: 400000, weeklyEarningsUSD: 30 },
      { target: '600K', diamonds: 600000, weeklyEarningsUSD: 45 },
      { target: '800K', diamonds: 800000, weeklyEarningsUSD: 60 },
      { target: '1M', diamonds: 1000000, weeklyEarningsUSD: 75 },
    ],
    display: '6 Weekly Tiers (120K to 1M)',
    unit: 'Tiers',
    adminControl: 'Add / edit / delete tiers',
    isEditable: true,
    isEnabled: true,
  },
  LIVE_HOST_WEEKLY_EARNINGS: {
    id: 14,
    section: 'Live Host',
    setting: 'Weekly Earnings',
    value: { '120K': 9, '200K': 15, '400K': 30, '600K': 45, '800K': 60, '1M': 75 },
    display: '$9 to $75 weekly',
    unit: 'USD / Week',
    adminControl: 'Edit earning per tier',
    isEditable: true,
    isEnabled: true,
  },
  LIVE_HOST_WITHDRAWAL: {
    id: 15,
    section: 'Live Host',
    setting: 'Withdrawal',
    value: 'WEEKLY_ONLY',
    display: 'Weekly only',
    unit: 'Schedule',
    adminControl: 'Weekly only / enable-disable',
    isEditable: true,
    isEnabled: true,
  },
  LIVE_HOST_AGENCY_SHARE: {
    id: 16,
    section: 'Live Host',
    setting: 'Agency',
    value: 0,
    display: '0%',
    unit: '%',
    adminControl: '0%',
    isEditable: true,
    isEnabled: true,
  },
  LIVE_HOST_BACKUP_SHARE: {
    id: 17,
    section: 'Live Host',
    setting: 'Host Backup',
    value: 0,
    display: '0%',
    unit: '%',
    adminControl: '0%',
    isEditable: true,
    isEnabled: true,
  },

  // 4. Reseller (Coin Seller)
  RESELLER_PACKAGES: {
    id: 18,
    section: 'Reseller',
    setting: 'Package Price',
    value: [
      { priceUSD: 200, coinRatio: 11000, totalCoins: 2200000, profitPercent: 10 },
      { priceUSD: 500, coinRatio: 11550, totalCoins: 5775000, profitPercent: 15 },
      { priceUSD: 1000, coinRatio: 12127, totalCoins: 12127000, profitPercent: 20 },
    ],
    display: '$200, $500, $1,000 Packages',
    unit: 'USD',
    adminControl: 'Add / edit packages',
    isEditable: true,
    isEnabled: true,
  },
  RESELLER_COIN_RATIO: {
    id: 19,
    section: 'Reseller',
    setting: 'Coin Ratio',
    value: { '200': 11000, '500': 11550, '1000': 12127 },
    display: '11,000 / 11,550 / 12,127 coins per $1',
    unit: 'Coins / USD',
    adminControl: 'Edit package ratio',
    isEditable: true,
    isEnabled: true,
  },
  RESELLER_TOTAL_COINS: {
    id: 20,
    section: 'Reseller',
    setting: 'Total Coins',
    value: { '200': 2200000, '500': 5775000, '1000': 12127000 },
    display: '2.2M / 5.775M / 12.127M Coins',
    unit: 'Coins',
    adminControl: 'Auto-calculate / edit',
    isEditable: true,
    isEnabled: true,
  },
  RESELLER_PROFIT_TIER: {
    id: 21,
    section: 'Reseller',
    setting: 'Profit Tier',
    value: { '200': 10, '500': 15, '1000': 20 },
    display: '10% / 15% / 20%',
    unit: '%',
    adminControl: 'Edit profit %',
    isEditable: true,
    isEnabled: true,
  },
  RESELLER_SECURITY_INSURANCE: {
    id: 22,
    section: 'Reseller',
    setting: 'Security / Insurance',
    value: true,
    display: 'Required (Protected Escrow)',
    unit: 'Boolean',
    adminControl: 'Enable / disable requirement',
    isEditable: true,
    isEnabled: true,
  },

  // 5. Merchant
  MERCHANT_PACKAGE_PRICE: {
    id: 23,
    section: 'Merchant',
    setting: 'Package Price',
    value: [
      { priceUSD: 3000, coinRatio: 13340, totalCoins: 40000000 },
    ],
    display: '$3,000 VIP Merchant Tier',
    unit: 'USD',
    adminControl: 'Add / edit packages',
    isEditable: true,
    isEnabled: true,
  },
  MERCHANT_COIN_RATIO: {
    id: 24,
    section: 'Merchant',
    setting: 'Coin Ratio',
    value: 13340,
    display: '13,340 coins per $1',
    unit: 'Coins / USD',
    adminControl: 'Edit ratio',
    isEditable: true,
    isEnabled: true,
  },
  MERCHANT_TOTAL_COINS: {
    id: 25,
    section: 'Merchant',
    setting: 'Total Coins',
    value: 40000000,
    display: '40,000,000 coins ($3,000)',
    unit: 'Coins',
    adminControl: 'Auto-calculate / edit',
    isEditable: true,
    isEnabled: true,
  },
  MERCHANT_MIN_WORKING_PERIOD: {
    id: 26,
    section: 'Merchant',
    setting: 'Minimum Working Period',
    value: 30,
    display: '30 Days',
    unit: 'Days',
    adminControl: 'Edit required period',
    isEditable: true,
    isEnabled: true,
  },
  MERCHANT_TARGET_REQUIREMENT: {
    id: 27,
    section: 'Merchant',
    setting: 'Target Requirement',
    value: 100000000,
    display: '100,000,000 Coins / Month',
    unit: 'Coins / Month',
    adminControl: 'Edit required target',
    isEditable: true,
    isEnabled: true,
  },

  // 6. Withdrawal
  WITHDRAWAL_DAILY: {
    id: 28,
    section: 'Withdrawal',
    setting: 'Daily Withdrawal',
    value: true,
    display: 'Enabled',
    unit: 'Boolean',
    adminControl: 'Enable / disable',
    isEditable: true,
    isEnabled: true,
  },
  WITHDRAWAL_WEEKLY: {
    id: 29,
    section: 'Withdrawal',
    setting: 'Weekly Withdrawal',
    value: true,
    display: 'Enabled (Every Monday Settlement)',
    unit: 'Boolean',
    adminControl: 'Enable / disable',
    isEditable: true,
    isEnabled: true,
  },
  WITHDRAWAL_MIN_AMOUNT: {
    id: 30,
    section: 'Withdrawal',
    setting: 'Minimum Amount',
    value: 10,
    display: '$10.00',
    unit: 'USD',
    adminControl: 'Edit minimum',
    isEditable: true,
    isEnabled: true,
  },
  WITHDRAWAL_MAX_AMOUNT: {
    id: 31,
    section: 'Withdrawal',
    setting: 'Maximum Amount',
    value: 5000,
    display: '$5,000.00 / day',
    unit: 'USD',
    adminControl: 'Edit maximum',
    isEditable: true,
    isEnabled: true,
  },
  WITHDRAWAL_PROCESSING_FEE: {
    id: 32,
    section: 'Withdrawal',
    setting: 'Processing Fee',
    value: 2.5,
    display: '2.5%',
    unit: '%',
    adminControl: 'Edit fee',
    isEditable: true,
    isEnabled: true,
  },
  WITHDRAWAL_PROCESSING_TIME: {
    id: 33,
    section: 'Withdrawal',
    setting: 'Processing Time',
    value: '24-48 Hours',
    display: '24-48 Hours',
    unit: 'Hours',
    adminControl: 'Edit processing time',
    isEditable: true,
    isEnabled: true,
  },
  WITHDRAWAL_PAYMENT_METHODS: {
    id: 34,
    section: 'Withdrawal',
    setting: 'Payment Methods',
    value: ['BANK_TRANSFER', 'PAYPAL', 'USDT_TRC20', 'PAYONEER'],
    display: 'Bank, PayPal, USDT, Payoneer',
    unit: 'Gateways',
    adminControl: 'Add / remove methods',
    isEditable: true,
    isEnabled: true,
  },
  WITHDRAWAL_APPROVAL_MODE: {
    id: 35,
    section: 'Withdrawal',
    setting: 'Approval Mode',
    value: 'TWO_STAGE_MAKER_CHECKER',
    display: 'Manual / Automatic (> $100 requires Approval)',
    unit: 'Mode',
    adminControl: 'Manual / automatic',
    isEditable: true,
    isEnabled: true,
  },

  // 7. Admin (BD / Management)
  ADMIN_MIN_USER_INVITES: {
    id: 36,
    section: 'Admin',
    setting: 'Minimum User Invites',
    value: 1000,
    display: '1,000 users',
    unit: 'Users',
    adminControl: 'Current: 1,000',
    isEditable: true,
    isEnabled: true,
  },
  ADMIN_TEAM_REQUIREMENT: {
    id: 37,
    section: 'Admin',
    setting: 'Team Requirement',
    value: true,
    display: 'Enabled (Minimum 5 active agents)',
    unit: 'Boolean',
    adminControl: 'Enable / disable',
    isEditable: true,
    isEnabled: true,
  },
  ADMIN_MAX_AGENCIES: {
    id: 38,
    section: 'Admin',
    setting: 'Maximum Agencies',
    value: 200,
    display: '200 Agencies',
    unit: 'Agencies',
    adminControl: 'Current: 200',
    isEditable: true,
    isEnabled: true,
  },
  ADMIN_FIXED_SALARY: {
    id: 39,
    section: 'Admin',
    setting: 'Fixed Salary',
    value: 200,
    display: '$200.00 / month',
    unit: 'USD / Month',
    adminControl: 'Current: $200',
    isEditable: true,
    isEnabled: true,
  },
  ADMIN_APPROVAL_REQUIREMENT: {
    id: 40,
    section: 'Admin',
    setting: 'Approval',
    value: 'MANAGEMENT_APPROVAL_REQUIRED',
    display: 'Management approval required',
    unit: 'Policy',
    adminControl: 'Management approval required',
    isEditable: true,
    isEnabled: true,
  },

  // 8. Security
  SECURITY_PENDING_BALANCE: {
    id: 41,
    section: 'Security',
    setting: 'Pending Balance',
    value: { enabled: true, holdingPeriodDays: 7 },
    display: 'Enabled (7-day holding period)',
    unit: 'Days',
    adminControl: 'Enable holding period',
    isEditable: true,
    isEnabled: true,
  },
  SECURITY_CLEARED_BALANCE: {
    id: 42,
    section: 'Security',
    setting: 'Cleared Balance',
    value: { enabled: true, autoReleaseAfterVerification: true },
    display: 'Release after verification',
    unit: 'Policy',
    adminControl: 'Release after verification',
    isEditable: true,
    isEnabled: true,
  },
  SECURITY_FRAUD_REVIEW: {
    id: 43,
    section: 'Security',
    setting: 'Fraud Review',
    value: { enabled: true, autoHoldSuspiciousTransactions: true },
    display: 'Hold suspicious transactions',
    unit: 'Policy',
    adminControl: 'Hold suspicious transactions',
    isEditable: true,
    isEnabled: true,
  },
  SECURITY_CHARGEBACK_PROTECTION: {
    id: 44,
    section: 'Security',
    setting: 'Chargeback Protection',
    value: { enabled: true, holdReversedEarnings: true },
    display: 'Hold reversed/refunded earnings',
    unit: 'Policy',
    adminControl: 'Hold reversed/refunded earnings',
    isEditable: true,
    isEnabled: true,
  },
  SECURITY_DUPLICATE_PAYOUT_PROTECTION: {
    id: 45,
    section: 'Security',
    setting: 'Duplicate Payout Protection',
    value: { enabled: true, uniqueLedgerIdEnforcement: true },
    display: 'Prevent double payout (Unique transaction hashes)',
    unit: 'Policy',
    adminControl: 'Prevent double payout',
    isEditable: true,
    isEnabled: true,
  },

  // 9. Policy Meta
  POLICY_APPLY_FROM_DATE: {
    id: 46,
    section: 'Policy',
    setting: 'Apply From Date',
    value: new Date().toISOString(),
    display: 'Immediate / Scheduled Effective Date',
    unit: 'ISO Timestamp',
    adminControl: 'New policy effective date',
    isEditable: true,
    isEnabled: true,
  },
  POLICY_VERSION: {
    id: 47,
    section: 'Policy',
    setting: 'Policy Version',
    value: 'v3.2.0',
    display: 'v3.2.0 (Official 2026 Production Policy)',
    unit: 'SemVer',
    adminControl: 'Create / publish version',
    isEditable: true,
    isEnabled: true,
  },
  POLICY_AUDIT_LOG: {
    id: 48,
    section: 'Policy',
    setting: 'Audit Log',
    value: { enabled: true, logEveryAdminChange: true },
    display: 'Track every admin change (Immutable audit logging)',
    unit: 'Audit',
    adminControl: 'Track every admin change',
    isEditable: true,
    isEnabled: true,
  },
};

let inMemorySettingsState = { ...INITIAL_COMPLETE_SETTINGS };
let inMemoryVersionHistory = [
  {
    version: 'v3.2.0',
    applyFromDate: new Date('2026-10-01T00:00:00Z').toISOString(),
    description: 'Official ZeParty 2026 Policy Release (48 Master Settings)',
    publishedBy: 'System Administrator',
    publishedAt: new Date().toISOString(),
    settingsSnapshot: { ...INITIAL_COMPLETE_SETTINGS },
  },
];

async function logAudit(
  { adminId, adminName, action, targetEntity, targetEntityId, beforeStateJson, afterStateJson, reason, ipAddress },
  db = prisma
) {
  try {
    let validAdminId = adminId;
    if (!validAdminId || validAdminId === 'ADMIN' || validAdminId === 'SYSTEM') {
      const fallback = await db.admin?.findFirst?.({ select: { id: true, name: true } });
      validAdminId = fallback ? fallback.id : null;
      if (fallback && !adminName) adminName = fallback.name;
    }
    if (!validAdminId || !db.auditLog?.create) return;

    await db.auditLog.create({
      data: {
        adminId: validAdminId,
        adminName: adminName || 'System Administrator',
        action,
        targetEntity: targetEntity || 'SystemPolicy',
        targetEntityId: targetEntityId || null,
        beforeStateJson: beforeStateJson ? JSON.parse(JSON.stringify(beforeStateJson)) : null,
        afterStateJson: afterStateJson ? JSON.parse(JSON.stringify(afterStateJson)) : null,
        reason: reason || 'Policy modified via Admin Panel',
        ipAddress: ipAddress || '127.0.0.1',
      },
    });
  } catch (err) {
    console.error('Failed to log audit in completeSettings.service:', err.message);
  }
}

export async function getAllCompleteSettings() {
  const items = Object.entries(inMemorySettingsState).map(([key, item]) => ({
    key,
    ...item,
  }));

  return {
    totalSettingsCount: items.length,
    activePolicyVersion: inMemorySettingsState.POLICY_VERSION?.value || 'v3.2.0',
    applyFromDate: inMemorySettingsState.POLICY_APPLY_FROM_DATE?.value,
    categories: [
      'Economy',
      'Host Policy',
      'Live Host',
      'Reseller',
      'Merchant',
      'Withdrawal',
      'Admin',
      'Security',
      'Policy',
    ],
    settings: items,
  };
}

export async function getSettingsByCategory(categoryName) {
  const normalized = (categoryName || '').toLowerCase().replace(/[\s_-]/g, '');
  const items = Object.entries(inMemorySettingsState)
    .filter(([_, val]) => (val.section || '').toLowerCase().replace(/[\s_-]/g, '') === normalized)
    .map(([key, val]) => ({ key, ...val }));

  return {
    category: categoryName,
    count: items.length,
    settings: items,
  };
}

export async function updateSingleSetting(
  settingKey,
  { value, isEnabled, applyFromDate, reason },
  { adminId, adminName, ipAddress },
  db = prisma
) {
  const upperKey = (settingKey || '').toUpperCase();
  const existing = inMemorySettingsState[upperKey];

  if (!existing) {
    const error = new Error(`Setting key "${settingKey}" not found in master settings matrix`);
    error.statusCode = 404;
    throw error;
  }

  const beforeState = { ...existing };
  const effectiveDate = applyFromDate ? new Date(applyFromDate).toISOString() : new Date().toISOString();

  if (value !== undefined) existing.value = value;
  if (isEnabled !== undefined) existing.isEnabled = Boolean(isEnabled);
  existing.applyFromDate = effectiveDate;

  const afterState = { ...existing };

  await logAudit(
    {
      adminId,
      adminName,
      action: `SETTING_UPDATED_${upperKey}`,
      targetEntity: 'SystemSetting',
      targetEntityId: upperKey,
      beforeStateJson: beforeState,
      afterStateJson: afterState,
      reason: reason || `Updated setting ${upperKey}`,
      ipAddress,
    },
    db
  );

  return {
    key: upperKey,
    setting: existing,
    applyFromDate: effectiveDate,
    updatedAt: new Date().toISOString(),
  };
}

export async function batchUpdateSettings(
  settingsArray = [],
  { applyFromDate, version, reason },
  { adminId, adminName, ipAddress },
  db = prisma
) {
  const effectiveDate = applyFromDate ? new Date(applyFromDate).toISOString() : new Date().toISOString();
  const updatedKeys = [];
  const beforeSnapshot = { ...inMemorySettingsState };

  for (const item of settingsArray) {
    const key = (item.key || '').toUpperCase();
    if (inMemorySettingsState[key]) {
      if (item.value !== undefined) inMemorySettingsState[key].value = item.value;
      if (item.isEnabled !== undefined) inMemorySettingsState[key].isEnabled = Boolean(item.isEnabled);
      inMemorySettingsState[key].applyFromDate = effectiveDate;
      updatedKeys.push(key);
    }
  }

  if (version) {
    inMemorySettingsState.POLICY_VERSION.value = version;
    inMemorySettingsState.POLICY_VERSION.display = `${version} (Published ${new Date().toLocaleDateString()})`;
  }

  inMemorySettingsState.POLICY_APPLY_FROM_DATE.value = effectiveDate;

  // Record in version history
  if (version) {
    inMemoryVersionHistory.unshift({
      version,
      applyFromDate: effectiveDate,
      description: reason || 'Batch policy update published',
      publishedBy: adminName || 'System Administrator',
      publishedAt: new Date().toISOString(),
      settingsSnapshot: { ...inMemorySettingsState },
    });
  }

  await logAudit(
    {
      adminId,
      adminName,
      action: 'BATCH_POLICY_SETTINGS_UPDATED',
      targetEntity: 'SystemPolicy',
      targetEntityId: version || 'CURRENT',
      beforeStateJson: { updatedCount: updatedKeys.length },
      afterStateJson: { updatedKeys, version, applyFromDate: effectiveDate },
      reason: reason || 'Batch policy update published via Admin Panel',
      ipAddress,
    },
    db
  );

  return {
    success: true,
    updatedKeysCount: updatedKeys.length,
    updatedKeys,
    activeVersion: inMemorySettingsState.POLICY_VERSION.value,
    applyFromDate: effectiveDate,
  };
}

export async function publishNewPolicyVersion(
  { version, applyFromDate, description },
  { adminId, adminName, ipAddress },
  db = prisma
) {
  if (!version) {
    const error = new Error('Version identifier (e.g. v3.3.0) is required');
    error.statusCode = 400;
    throw error;
  }

  const effectiveDate = applyFromDate ? new Date(applyFromDate).toISOString() : new Date().toISOString();

  inMemorySettingsState.POLICY_VERSION.value = version;
  inMemorySettingsState.POLICY_VERSION.display = `${version} (Active)`;
  inMemorySettingsState.POLICY_APPLY_FROM_DATE.value = effectiveDate;

  const versionRecord = {
    version,
    applyFromDate: effectiveDate,
    description: description || 'New policy published',
    publishedBy: adminName || 'System Administrator',
    publishedAt: new Date().toISOString(),
    settingsSnapshot: { ...inMemorySettingsState },
  };

  inMemoryVersionHistory.unshift(versionRecord);

  await logAudit(
    {
      adminId,
      adminName,
      action: 'POLICY_VERSION_PUBLISHED',
      targetEntity: 'SystemPolicy',
      targetEntityId: version,
      afterStateJson: { version, applyFromDate: effectiveDate, description },
      reason: description || `Published policy version ${version}`,
      ipAddress,
    },
    db
  );

  return {
    success: true,
    version,
    applyFromDate: effectiveDate,
    publishedAt: versionRecord.publishedAt,
  };
}

export async function getPolicyVersionHistory() {
  return {
    totalVersions: inMemoryVersionHistory.length,
    currentActiveVersion: inMemorySettingsState.POLICY_VERSION.value,
    versions: inMemoryVersionHistory.map(v => ({
      version: v.version,
      applyFromDate: v.applyFromDate,
      description: v.description,
      publishedBy: v.publishedBy,
      publishedAt: v.publishedAt,
    })),
  };
}

export async function calculateHostEarningsPreview(hostType, diamonds, daysCompleted = 10, validHours = 10.0) {
  const diamondInt = Number(diamonds) || 0;
  const isLive = hostType === 'LIVE_HOST';

  if (isLive) {
    // 6 tiers: 120K=$9, 200K=$15, 400K=$30, 600K=$45, 800K=$60, 1M=$75
    let weeklyUSD = 0;
    if (diamondInt >= 1000000) weeklyUSD = 75;
    else if (diamondInt >= 800000) weeklyUSD = 60;
    else if (diamondInt >= 600000) weeklyUSD = 45;
    else if (diamondInt >= 400000) weeklyUSD = 30;
    else if (diamondInt >= 200000) weeklyUSD = 15;
    else if (diamondInt >= 120000) weeklyUSD = 9;

    return {
      hostType: 'LIVE_HOST',
      targetAchievedDiamonds: diamondInt,
      weeklyEarningsUSD: weeklyUSD,
      agencySharePercent: 0,
      hostBackupPercent: 0,
      payoutSchedule: 'WEEKLY_ONLY',
      isEligible: diamondInt >= 120000,
    };
  } else {
    // Audio / Regular host tiers: 40K=$1, 80K=$2, 120K=$3, 200K=$5, 400K=$10
    let dailyUSD = 0;
    let weeklyUSD = 0;
    let agencyProfitUSD = 0;

    if (diamondInt >= 400000) { dailyUSD = 10; weeklyUSD = 10; agencyProfitUSD = 2.00; }
    else if (diamondInt >= 200000) { dailyUSD = 5; weeklyUSD = 5; agencyProfitUSD = 1.00; }
    else if (diamondInt >= 120000) { dailyUSD = 3; weeklyUSD = 3; agencyProfitUSD = 0.60; }
    else if (diamondInt >= 80000) { dailyUSD = 2; weeklyUSD = 2; agencyProfitUSD = 0.40; }
    else if (diamondInt >= 40000) { dailyUSD = 1; weeklyUSD = 1; agencyProfitUSD = 0.20; }

    return {
      hostType: 'AUDIO_HOST',
      targetAchievedDiamonds: diamondInt,
      dailyRewardUSD: dailyUSD,
      weeklyRewardUSD: weeklyUSD,
      totalEarnedUSD: dailyUSD + weeklyUSD,
      agencyProfitUSD,
      payoutSchedule: 'DAILY_AND_WEEKLY',
      isEligible: diamondInt >= 40000,
    };
  }
}

export default {
  getAllCompleteSettings,
  getSettingsByCategory,
  updateSingleSetting,
  batchUpdateSettings,
  publishNewPolicyVersion,
  getPolicyVersionHistory,
  calculateHostEarningsPreview,
  INITIAL_COMPLETE_SETTINGS,
};
