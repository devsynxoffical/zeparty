import prisma from '../config/database.js';
import redisClient from '../config/redis.js';
import policyRepository from '../repositories/policy.repository.js';
import configurationRepository from '../repositories/configuration.repository.js';
import {
  BASELINE_POLICY_TEMPLATES,
  BASELINE_CONFIG_VALUES,
} from '../constants/policyDefaults.js';

const CACHE_TTL_SECONDS = 3600; // 1 hour

/**
 * Helper to safely query Redis cache with fallback.
 */
async function getCached(key) {
  try {
    if (redisClient.isOpen) {
      const cached = await redisClient.get(key);
      if (cached) return JSON.parse(cached);
    }
  } catch {
    // Fallback on Redis read error
  }
  return null;
}

/**
 * Helper to safely set Redis cache with TTL.
 */
async function setCached(key, value) {
  try {
    if (redisClient.isOpen) {
      await redisClient.set(key, JSON.stringify(value), { EX: CACHE_TTL_SECONDS });
    }
  } catch {
    // Fallback on Redis write error
  }
}

/**
 * Helper to safely invalidate Redis cache key.
 */
async function invalidateCache(key) {
  try {
    if (redisClient.isOpen) {
      await redisClient.del(key);
    }
  } catch {
    // Fallback
  }
}

/**
 * Resolves the effective active policy configuration for a given domain (e.g., 'ECONOMY', 'LIVE_HOST').
 */
export async function getEffectivePolicy(policyType, db = prisma) {
  const normType = policyType.toUpperCase();
  const cacheKey = `policy:effective:${normType}`;

  // 1. Check Redis cache
  const cached = await getCached(cacheKey);
  if (cached) return cached;

  // 2. Query DB
  try {
    const policy = await policyRepository.findByType(normType, db);
    if (policy && policy.versions && policy.versions.length > 0) {
      const activeVersion = policy.versions.find((v) => v.version === policy.version) || policy.versions[0];
      const effective = {
        policyType: policy.policyType,
        activeVersion: activeVersion.version,
        config: activeVersion.configJson,
        effectiveDate: activeVersion.effectiveDate,
        source: 'DATABASE',
      };
      await setCached(cacheKey, effective);
      return effective;
    }
  } catch {
    // Fallback on DB connection error during unit tests / offline state
  }

  // 3. Fallback to Authoritative Baseline Defaults
  const template = BASELINE_POLICY_TEMPLATES[normType];
  if (template) {
    const baseline = {
      policyType: template.policyType,
      activeVersion: template.version,
      config: template.config,
      source: 'BASELINE_DEFAULT',
    };
    await setCached(cacheKey, baseline);
    return baseline;
  }

  return null;
}

/**
 * Resolves the effective key-value configuration setting (e.g., 'USD_TO_COIN_RATE').
 */
export async function getEffectiveConfig(key, db = prisma) {
  const normKey = key.toUpperCase();
  const cacheKey = `policy:config:${normKey}`;

  const cached = await getCached(cacheKey);
  if (cached) return cached;

  try {
    const dbConfig = await configurationRepository.findByKey(normKey, db);
    if (dbConfig) {
      const result = {
        key: dbConfig.key,
        value: dbConfig.valueJson,
        status: dbConfig.status,
        disabledAt: dbConfig.disabledAt,
        autoRestoreAt: dbConfig.autoRestoreAt,
        source: 'DATABASE',
      };
      await setCached(cacheKey, result);
      return result;
    }
  } catch {
    // Fallback on DB connection error
  }

  const baselineValue = BASELINE_CONFIG_VALUES[normKey];
  if (baselineValue) {
    const result = {
      key: normKey,
      value: baselineValue,
      status: 'ACTIVE',
      source: 'BASELINE_DEFAULT',
    };
    await setCached(cacheKey, result);
    return result;
  }

  return null;
}

export async function getPolicies() {
  return await policyRepository.findAll();
}

export async function getPolicyById(id) {
  const policy = await policyRepository.findById(id);
  if (!policy) {
    const error = new Error('Policy not found');
    error.status = 404;
    error.code = 'POLICY_NOT_FOUND';
    throw error;
  }
  return policy;
}

export async function createPolicy({
  policyType,
  description,
  initialConfig,
  version = 'v1.0.0',
  adminId,
  isOwner = false,
  ipAddress,
}) {
  const normType = policyType.toUpperCase();

  const existing = await policyRepository.findByType(normType);
  if (existing) {
    const error = new Error(`Policy for type "${normType}" already exists.`);
    error.status = 409;
    error.code = 'POLICY_ALREADY_EXISTS';
    throw error;
  }

  return await prisma.$transaction(async (tx) => {
    const policy = await policyRepository.createPolicy(
      {
        policyType: normType,
        version,
        description,
      },
      tx
    );

    const initialVer = await policyRepository.createVersion(
      {
        policyId: policy.id,
        version,
        summary: 'Initial baseline policy creation',
        configJson: initialConfig,
        approvedBy: isOwner ? 'Root Owner' : 'Administrator',
      },
      tx
    );

    await tx.auditLog.create({
      data: {
        adminId,
        adminName: isOwner ? 'Root Owner' : 'Administrator',
        action: 'POLICY_CREATED',
        targetEntity: 'Policy',
        targetEntityId: policy.id,
        afterStateJson: { policy, initialVersion: initialVer },
        reason: `Created ${normType} policy`,
        ipAddress,
      },
    });

    await invalidateCache(`policy:effective:${normType}`);

    return {
      ...policy,
      versions: [initialVer],
    };
  });
}

export async function createVersion({
  policyId,
  version,
  summary,
  configJson,
  adminId,
  isOwner = false,
  ipAddress,
}) {
  const policy = await getPolicyById(policyId);

  const existingVersion = await policyRepository.findVersionByPolicyAndTag(policyId, version);
  if (existingVersion) {
    const error = new Error(`Version tag "${version}" already exists for this policy.`);
    error.status = 409;
    error.code = 'VERSION_TAG_EXISTS';
    throw error;
  }

  return await prisma.$transaction(async (tx) => {
    const newVer = await policyRepository.createVersion(
      {
        policyId,
        version,
        summary,
        configJson,
        approvedBy: isOwner ? 'Root Owner' : 'Administrator',
      },
      tx
    );

    await tx.auditLog.create({
      data: {
        adminId,
        adminName: isOwner ? 'Root Owner' : 'Administrator',
        action: 'POLICY_VERSION_CREATED',
        targetEntity: 'PolicyVersion',
        targetEntityId: newVer.id,
        afterStateJson: newVer,
        reason: `Drafted version ${version} for ${policy.policyType}: ${summary}`,
        ipAddress,
      },
    });

    return newVer;
  });
}

export async function publishVersion({
  policyId,
  versionId,
  adminId,
  isOwner = false,
  ipAddress,
}) {
  const policy = await getPolicyById(policyId);
  const versionRecord = await policyRepository.findVersionById(versionId);

  if (!versionRecord || versionRecord.policyId !== policyId) {
    const error = new Error('Policy version not found');
    error.status = 404;
    error.code = 'VERSION_NOT_FOUND';
    throw error;
  }

  return await prisma.$transaction(async (tx) => {
    const updatedPolicy = await policyRepository.updateActiveVersion(
      policyId,
      versionRecord.version,
      tx
    );

    await tx.auditLog.create({
      data: {
        adminId,
        adminName: isOwner ? 'Root Owner' : 'Administrator',
        action: 'POLICY_VERSION_PUBLISHED',
        targetEntity: 'Policy',
        targetEntityId: policyId,
        beforeStateJson: { activeVersion: policy.version },
        afterStateJson: { activeVersion: versionRecord.version },
        reason: `Published version ${versionRecord.version} for ${policy.policyType}`,
        ipAddress,
      },
    });

    await invalidateCache(`policy:effective:${policy.policyType}`);

    return {
      success: true,
      message: `Version ${versionRecord.version} is now active for ${policy.policyType}.`,
      policy: updatedPolicy,
      activeVersion: versionRecord,
    };
  });
}

export async function rollbackPolicy({
  policyId,
  targetVersion,
  reason,
  adminId,
  isOwner = false,
  ipAddress,
}) {
  const policy = await getPolicyById(policyId);
  const historical = await policyRepository.findVersionByPolicyAndTag(policyId, targetVersion);

  if (!historical) {
    const error = new Error(`Historical version "${targetVersion}" not found.`);
    error.status = 404;
    error.code = 'HISTORICAL_VERSION_NOT_FOUND';
    throw error;
  }

  const rollbackTag = `${targetVersion}-rollback-${Date.now().toString().slice(-4)}`;

  return await prisma.$transaction(async (tx) => {
    // Create new immutable rollback version
    const rollbackVer = await policyRepository.createVersion(
      {
        policyId,
        version: rollbackTag,
        summary: `[Rollback to ${targetVersion}] ${reason}`,
        configJson: historical.configJson,
        approvedBy: isOwner ? 'Root Owner' : 'Administrator',
      },
      tx
    );

    // Atomically set as active version
    const updatedPolicy = await policyRepository.updateActiveVersion(
      policyId,
      rollbackTag,
      tx
    );

    await tx.auditLog.create({
      data: {
        adminId,
        adminName: isOwner ? 'Root Owner' : 'Administrator',
        action: 'POLICY_ROLLED_BACK',
        targetEntity: 'Policy',
        targetEntityId: policyId,
        beforeStateJson: { activeVersion: policy.version },
        afterStateJson: { activeVersion: rollbackTag, restoredFrom: targetVersion },
        reason: `Rolled back ${policy.policyType} to ${targetVersion}: ${reason}`,
        ipAddress,
      },
    });

    await invalidateCache(`policy:effective:${policy.policyType}`);

    return {
      success: true,
      message: `Policy ${policy.policyType} successfully rolled back to ${targetVersion}.`,
      policy: updatedPolicy,
      activeVersion: rollbackVer,
    };
  });
}

// --- Dynamic Configuration Key-Value Management ---

export async function getConfigurations() {
  let configs = await configurationRepository.findAll();
  if (!configs || configs.length === 0) {
    const baselineKeys = [
      {
        key: 'ECONOMY_POLICY_GLOBAL',
        valueJson: {
          revenueSplit: {
            version: 'v3.0.0',
            platformShare: 45,
            hostShare: 35,
            agencyShare: 12,
            roomReward: 8,
            status: 'ACTIVE'
          },
          countryOverrides: [
            { id: 'ov-1', country: '🇵🇰 Pakistan (PK)', platform: 40, host: 40, agency: 12, room: 8, status: 'ACTIVE' },
            { id: 'ov-2', country: '🇸🇦 Saudi Arabia (SA)', platform: 42, host: 38, agency: 12, room: 8, status: 'ACTIVE' },
            { id: 'ov-3', country: '🇺🇸 United States (US)', platform: 45, host: 35, agency: 12, room: 8, status: 'DEFAULT' },
            { id: 'ov-4', country: '🇧🇷 Brazil (BR)', platform: 40, host: 40, agency: 12, room: 8, status: 'ACTIVE' },
            { id: 'ov-5', country: '🇹🇷 Turkey (TR)', platform: 41, host: 39, agency: 12, room: 8, status: 'ACTIVE' }
          ]
        }
      },
      {
        key: 'EXCHANGE_RATES',
        valueJson: {
          rates: [
            {
              id: 'ex-101',
              rateType: 'USD_TO_COIN',
              name: 'USD to Coin Standard Rate',
              currency: 'USD',
              country: 'GLOBAL',
              currentRate: 10000,
              proposedRate: 10500,
              unit: 'Coins / $1 USD',
              status: 'ACTIVE',
              version: 'v3.2.0',
              effectiveDate: '2026-08-01',
              history: [{ version: 'v3.2.0', rate: 10000, effectiveDate: '2026-08-01', changedBy: 'Super Admin', notes: 'Baseline standard coin conversion.' }]
            },
            {
              id: 'ex-102',
              rateType: 'DIAMOND_TO_USD',
              name: 'Diamond to USD Payout Rate',
              currency: 'USD',
              country: 'GLOBAL',
              currentRate: 10000,
              proposedRate: 10000,
              unit: 'Diamonds / $1 USD',
              status: 'ACTIVE',
              version: 'v3.0.0',
              effectiveDate: '2026-01-01',
              history: [{ version: 'v3.0.0', rate: 10000, effectiveDate: '2026-01-01', changedBy: 'Finance Admin', notes: 'Established host payout conversion baseline.' }]
            },
            {
              id: 'ex-103',
              rateType: 'PK_LOCAL_CURRENCY',
              name: 'PKR Local Fiat to Coin Rate',
              currency: 'PKR',
              country: 'PK',
              currentRate: 35,
              proposedRate: 38,
              unit: 'Coins / 1 PKR',
              status: 'SCHEDULED',
              version: 'v3.3.0-draft',
              effectiveDate: '2026-09-01',
              history: [{ version: 'v3.2.0', rate: 35, effectiveDate: '2026-06-01', changedBy: 'Regional Admin PK', notes: 'Adjusted for FX inflation.' }]
            },
            {
              id: 'ex-104',
              rateType: 'BRL_LOCAL_CURRENCY',
              name: 'BRL Local Fiat to Coin Rate',
              currency: 'BRL',
              country: 'BR',
              currentRate: 1800,
              proposedRate: 1800,
              unit: 'Coins / 1 BRL',
              status: 'ACTIVE',
              version: 'v3.1.0',
              effectiveDate: '2026-04-10',
              history: [{ version: 'v3.1.0', rate: 1800, effectiveDate: '2026-04-10', changedBy: 'Finance Admin', notes: 'LATAM expansion localized rate.' }]
            }
          ]
        }
      },
      {
        key: 'TRANSFER_RATES',
        valueJson: {
          transferRates: [
            {
              id: 'tr-201',
              transferType: 'COIN_RESELLER_FEE',
              name: 'Reseller Coin Transfer Commission',
              description: 'Percentage fee applied to bulk coin transfers between platform and resellers',
              currentRatePercent: 2.5,
              proposedRatePercent: 3.0,
              status: 'ACTIVE',
              version: 'v2.1.0'
            },
            {
              id: 'tr-202',
              transferType: 'MERCHANT_ALLOCATION_FEE',
              name: 'Merchant Coin Allocation Fee',
              description: 'Processing percentage fee for custom merchant coin allocations',
              currentRatePercent: 1.8,
              proposedRatePercent: 2.0,
              status: 'ACTIVE',
              version: 'v1.4.0'
            },
            {
              id: 'tr-203',
              transferType: 'HOST_TO_HOST_TRANSFER_FEE',
              name: 'Host-to-Host Coin Transfer Fee',
              description: 'Commission fee for direct user/host coin transfers in room chats',
              currentRatePercent: 5.0,
              proposedRatePercent: 5.0,
              status: 'ACTIVE',
              version: 'v3.0.0'
            }
          ]
        }
      },
      {
        key: 'LIVE_HOST_TIERS',
        valueJson: {
          version: 'v3.0.0',
          minDailyHours: 1.0,
          minDaysPerMonth: 10,
          tiers: [
            { level: 1, targetDiamonds: 25000, durationDays: 10, basicSalaryUSD: 2.00, dailyHoursRequired: 1.0 },
            { level: 2, targetDiamonds: 50000, durationDays: 10, basicSalaryUSD: 4.00, dailyHoursRequired: 1.0 },
            { level: 3, targetDiamonds: 100000, durationDays: 10, basicSalaryUSD: 8.00, dailyHoursRequired: 1.0 },
            { level: 4, targetDiamonds: 250000, durationDays: 10, basicSalaryUSD: 20.00, dailyHoursRequired: 1.0 },
            { level: 5, targetDiamonds: 500000, durationDays: 8, basicSalaryUSD: 40.00, dailyHoursRequired: 1.0 },
            { level: 6, targetDiamonds: 1000000, durationDays: 8, basicSalaryUSD: 80.00, dailyHoursRequired: 1.0 },
            { level: 7, targetDiamonds: 2500000, durationDays: 8, basicSalaryUSD: 200.00, dailyHoursRequired: 1.0 },
            { level: 8, targetDiamonds: 5000000, durationDays: 5, basicSalaryUSD: 400.00, dailyHoursRequired: 1.0 },
            { level: 9, targetDiamonds: 10000000, durationDays: 5, basicSalaryUSD: 800.00, dailyHoursRequired: 1.0 },
            { level: 10, targetDiamonds: 20000000, durationDays: 5, basicSalaryUSD: 1600.00, dailyHoursRequired: 1.0 }
          ]
        }
      },
      {
        key: 'AUDIO_HOST_TIERS',
        valueJson: {
          version: 'v3.0.0',
          minDailyHours: 2.0,
          tiers: [
            { level: 1, tierName: '30K Audio Starter', targetCoins: 30000, dailyRewardUSD: 0.80, agencyProfitUSD: 0.15, minDailyHours: 2.0, durationDays: 10 },
            { level: 2, tierName: '60K Audio Bronze', targetCoins: 60000, dailyRewardUSD: 1.60, agencyProfitUSD: 0.30, minDailyHours: 2.0, durationDays: 10 },
            { level: 3, tierName: '100K Audio Silver', targetCoins: 100000, dailyRewardUSD: 2.80, agencyProfitUSD: 0.50, minDailyHours: 2.0, durationDays: 10 },
            { level: 4, tierName: '350K Audio Gold', targetCoins: 350000, dailyRewardUSD: 9.50, agencyProfitUSD: 1.70, minDailyHours: 2.0, durationDays: 10 },
            { level: 5, tierName: '1M Audio Platinum', targetCoins: 1000000, dailyRewardUSD: 28.00, agencyProfitUSD: 5.00, minDailyHours: 2.0, durationDays: 8 },
            { level: 6, tierName: '3M Audio VIP Master', targetCoins: 3000000, dailyRewardUSD: 90.00, agencyProfitUSD: 16.00, minDailyHours: 2.0, durationDays: 8 },
            { level: 7, tierName: '10M Audio Crown Royalty', targetCoins: 10000000, dailyRewardUSD: 320.00, agencyProfitUSD: 55.00, minDailyHours: 2.0, durationDays: 5 }
          ]
        }
      },
      {
        key: 'RESELLER_PACKAGES',
        valueJson: {
          packages: [
            { id: 'res-300', tierName: '$300 Coin Seller Tier', priceUSD: 300, totalCoins: 2205000, profitRatioPercent: 5 },
            { id: 'res-500', tierName: '$500 Coin Seller Tier', priceUSD: 500, totalCoins: 3675000, profitRatioPercent: 5 },
            { id: 'res-1000', tierName: '$1,000 Coin Seller Tier', priceUSD: 1000, totalCoins: 7700000, profitRatioPercent: 10 }
          ],
          rules: [
            'To become a ZeParty Coins Seller, you must complete the required security insurance/verification before starting.',
            "If a Coins Seller changes the official coin rate or fails to provide a user's withdrawal on time, the Coins Seller account may be terminated and Coins Seller privileges may be removed."
          ]
        }
      },
      {
        key: 'MERCHANT_POLICY',
        valueJson: {
          packages: [
            { id: 'mer-3000', tierName: '$3,000 Merchant Tier', priceUSD: 3000, totalCoins: 25200000, profitRatioPercent: 20 }
          ],
          profitRatioPercent: 20,
          minMonthlyAppPurchasesUSD: 1000,
          minPortalOpeningAmountUSD: 300,
          rules: [
            'The Merchant level offers a higher profit rate of 20%.',
            'To become a ZeParty Merchant, you must achieve a minimum target of $1,000 in purchases on the app within one month.',
            'After completing the requirement, you will be eligible to become a Merchant.',
            'A Merchant cannot open a new portal for an amount below $300.'
          ]
        }
      },
      {
        key: 'MANAGER_POLICY',
        valueJson: {
          maxMonthlyWorkTargetUSD: 2000,
          initialCoinSellerRequiredUSD: 1000,
          locationScope: 'GLOBAL_ANY_LOCATION',
          requirements: [
            { key: 'Location', policy: 'Manager applications are open for any location.' },
            { key: 'Team', policy: 'You must have a strong and reliable team before becoming a Manager.' },
            { key: 'Monthly Work', policy: 'Your maximum monthly work/target should be up to $2,000.' },
            { key: 'Initial Coins Seller', policy: 'You must first open/manage a Coins Seller level up to $1,000.' }
          ],
          managerNote: 'To become a ZeParty Manager, you should have a capable team that can actively support users and operations in your selected location. The Manager must first demonstrate performance by opening a Coins Seller operation up to $1,000, while the maximum monthly work/target is set at $2,000.'
        }
      }
    ];

    try {
      for (const b of baselineKeys) {
        await configurationRepository.upsertConfig({
          key: b.key,
          valueJson: b.valueJson,
          status: 'ACTIVE'
        });
      }
      configs = await configurationRepository.findAll();
    } catch (seedErr) {
      console.warn('[PolicyService] Baseline seed warning:', seedErr.message);
    }
  }
  return configs;
}

export async function updateConfiguration({
  key,
  valueJson,
  adminId,
  isOwner = false,
  ipAddress,
}) {
  const normKey = key.toUpperCase();

  const config = await configurationRepository.upsertConfig({
    key: normKey,
    valueJson,
    status: 'ACTIVE',
  });

  // Sync with Policy and PolicyVersion if this matches a canonical policy domain
  let policyType = null;
  if (normKey === 'ECONOMY' || normKey === 'ECONOMY_POLICY_GLOBAL' || normKey.startsWith('ECONOMY_POLICY')) {
    policyType = 'ECONOMY';
  } else if (normKey === 'LIVE_HOST' || normKey === 'LIVE_HOST_TIERS' || normKey.startsWith('LIVE_HOST')) {
    policyType = 'LIVE_HOST';
  } else if (normKey === 'AUDIO_HOST' || normKey === 'AUDIO_HOST_TIERS' || normKey.startsWith('AUDIO_HOST')) {
    policyType = 'AUDIO_HOST';
  } else if (normKey === 'AGENCY_HOST' || normKey === 'AGENCY_HOST_TIERS' || normKey.startsWith('AGENCY_HOST')) {
    policyType = 'AGENCY_HOST';
  } else if (normKey === 'RESELLER' || normKey === 'RESELLER_PACKAGES' || normKey.startsWith('RESELLER')) {
    policyType = 'RESELLER';
  } else if (normKey === 'MERCHANT' || normKey === 'MERCHANT_POLICY' || normKey.startsWith('MERCHANT')) {
    policyType = 'MERCHANT';
  } else if (normKey === 'MANAGER' || normKey === 'MANAGER_POLICY' || normKey.startsWith('MANAGER')) {
    policyType = 'MANAGER';
  }

  if (policyType) {
    try {
      const existingPolicy = await policyRepository.findByType(policyType);
      const newVersionTag = `v3.${Date.now().toString().slice(-4)}`;
      if (existingPolicy) {
        await policyRepository.updateActiveVersion(existingPolicy.id, newVersionTag);
        await policyRepository.createVersion({
          policyId: existingPolicy.id,
          version: newVersionTag,
          summary: `Admin updated ${normKey} policy configuration`,
          configJson: typeof valueJson === 'object' && valueJson !== null ? valueJson : { value: valueJson },
          approvedBy: isOwner ? 'Root Owner' : 'Administrator',
        });
      } else {
        const created = await policyRepository.createPolicy({
          policyType,
          version: newVersionTag,
          description: `Authoritative ${policyType} Policy`,
        });
        await policyRepository.createVersion({
          policyId: created.id,
          version: newVersionTag,
          summary: `Initial ${policyType} policy release`,
          configJson: typeof valueJson === 'object' && valueJson !== null ? valueJson : { value: valueJson },
          approvedBy: isOwner ? 'Root Owner' : 'Administrator',
        });
      }
      await invalidateCache(`policy:effective:${policyType}`);
    } catch (err) {
      console.warn(`[PolicyService] Could not sync policy table for ${policyType}:`, err.message);
    }
  }

  await prisma.auditLog.create({
    data: {
      adminId: adminId || 'dev-admin-main-001',
      adminName: isOwner ? 'Root Owner' : 'Administrator',
      action: 'CONFIG_UPDATED',
      targetEntity: 'PolicyConfiguration',
      targetEntityId: config.id,
      afterStateJson: config,
      reason: `Updated economy configuration key ${normKey}`,
      ipAddress,
    },
  }).catch(() => {});

  await invalidateCache(`policy:config:${normKey}`);

  return config;
}

export async function disableConfiguration({
  key,
  reason = 'Administrative disablement with 15-day auto-restore',
  adminId,
  isOwner = false,
  ipAddress,
}) {
  const normKey = key.toUpperCase();
  const now = new Date();
  // Exact 15 x 24 hours = 15 * 24 * 60 * 60 * 1000 ms (1,296,000,000 ms)
  const autoRestoreAt = new Date(now.getTime() + 15 * 24 * 60 * 60 * 1000);

  // Ensure record exists before disabling
  let existing = await configurationRepository.findByKey(normKey);
  if (!existing) {
    const baseline = BASELINE_CONFIG_VALUES[normKey] || {};
    existing = await configurationRepository.upsertConfig({
      key: normKey,
      valueJson: baseline,
      status: 'ACTIVE',
    });
  }

  const updated = await configurationRepository.updateStatus(normKey, {
    status: 'DISABLED',
    disabledAt: now,
    autoRestoreAt,
  });

  await prisma.auditLog.create({
    data: {
      adminId,
      adminName: isOwner ? 'Root Owner' : 'Administrator',
      action: 'CONFIG_DISABLED',
      targetEntity: 'PolicyConfiguration',
      targetEntityId: updated.id,
      afterStateJson: {
        status: 'DISABLED',
        disabledAt: now,
        autoRestoreAt,
        reason,
      },
      reason,
      ipAddress,
    },
  }).catch(() => {});

  await invalidateCache(`policy:config:${normKey}`);

  return updated;
}

export async function restoreConfiguration({
  key,
  reason = 'Manual administrative re-enable',
  adminId,
  isOwner = false,
  ipAddress,
}) {
  const normKey = key.toUpperCase();

  const updated = await configurationRepository.updateStatus(normKey, {
    status: 'ACTIVE',
    disabledAt: null,
    autoRestoreAt: null,
  });

  await prisma.auditLog.create({
    data: {
      adminId,
      adminName: isOwner ? 'Root Owner' : 'Administrator',
      action: 'CONFIG_RESTORED',
      targetEntity: 'PolicyConfiguration',
      targetEntityId: updated.id,
      afterStateJson: { status: 'ACTIVE' },
      reason,
      ipAddress,
    },
  }).catch(() => {});

  await invalidateCache(`policy:config:${normKey}`);

  return updated;
}

export default {
  getEffectivePolicy,
  getEffectiveConfig,
  getPolicies,
  getPolicyById,
  createPolicy,
  createVersion,
  publishVersion,
  rollbackPolicy,
  getConfigurations,
  updateConfiguration,
  disableConfiguration,
  restoreConfiguration,
};
