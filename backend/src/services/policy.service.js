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
  return await configurationRepository.findAll();
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
  } else if (normKey === 'RESELLER' || normKey === 'RESELLER_PACKAGES' || normKey.startsWith('RESELLER')) {
    policyType = 'RESELLER';
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

    // Sync to HostLevelConfig if host tiers
    if ((policyType === 'LIVE_HOST' || policyType === 'AUDIO_HOST') && valueJson) {
      try {
        const tiers = Array.isArray(valueJson) ? valueJson : (valueJson.tiers || []);
        const hostType = policyType === 'AUDIO_HOST' ? 'AUDIO_HOST' : 'LIVE_HOST';
        for (const [idx, tier] of tiers.entries()) {
          const lvl = Number(tier.level || idx + 1);
          await prisma.hostLevelConfig.upsert({
            where: {
              level_hostType: {
                level: lvl,
                hostType,
              },
            },
            update: {
              targetDiamonds: BigInt(tier.targetDiamonds || tier.targetCoins || 0),
              basicSalaryUSD: Number(tier.basicSalaryUSD || tier.dailyRewardUSD || 0),
              dailyHoursRequired: Number(tier.dailyHoursRequired || tier.minDailyHours || (hostType === 'AUDIO_HOST' ? 2.0 : 1.0)),
              daysRequiredPerMonth: Number(tier.durationDays || tier.daysRequiredPerMonth || 10),
            },
            create: {
              level: lvl,
              hostType,
              targetDiamonds: BigInt(tier.targetDiamonds || tier.targetCoins || 0),
              basicSalaryUSD: Number(tier.basicSalaryUSD || tier.dailyRewardUSD || 0),
              dailyHoursRequired: Number(tier.dailyHoursRequired || tier.minDailyHours || (hostType === 'AUDIO_HOST' ? 2.0 : 1.0)),
              daysRequiredPerMonth: Number(tier.durationDays || tier.daysRequiredPerMonth || 10),
            },
          });
        }
      } catch (tierErr) {
        console.warn(`[PolicyService] Could not sync HostLevelConfig:`, tierErr.message);
      }
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
