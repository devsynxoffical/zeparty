import prisma from '../config/database.js';

/**
 * Privacy Feature Eligibility Service (Phase 2 / NEW-058)
 *
 * Requirements Confirmed by Client:
 * 1. Anti-follow and Failed To Find privacy features are restricted by:
 *    - Configurable eligible SVIP tiers
 *    - Configurable eligible Noble tiers
 *    - Explicit individual user grants
 * 2. Access is allowed if the user has AT LEAST ONE eligible tier or an explicit individual grant.
 * 3. Fail-Closed: Access is strictly denied if neither condition is met.
 * 4. Configurable per feature independently (owner/admin controlled).
 * 5. Server-Authoritative: Enforced on all backend endpoints (getUserPrivacySettings, updateUserPrivacySettings, followUser).
 */

const PRIVACY_POLICY_KEY = 'PRIVACY_FEATURE_ELIGIBILITY';

// Default baseline configuration:
// Configurable by Admin. No tiers are hardcoded as universally eligible without configuration.
const DEFAULT_ELIGIBILITY_CONFIG = {
  ANTI_FOLLOW: {
    featureKey: 'ANTI_FOLLOW',
    label: 'Anti-Follow',
    eligibleSvipLevels: [5, 6, 7, 8, 9, 10, 11, 12, 13],
    eligibleNobleRanks: ['EMPEROR', 'SOVEREIGN'],
    individualUserGrants: [], // List of user IDs with explicit grants
  },
  FAILED_TO_FIND: {
    featureKey: 'FAILED_TO_FIND',
    label: 'Failed To Find',
    eligibleSvipLevels: [6, 7, 8, 9, 10, 11, 12, 13],
    eligibleNobleRanks: ['SOVEREIGN'],
    individualUserGrants: [], // List of user IDs with explicit grants
  },
};

/**
 * Retrieves the effective privacy feature eligibility policy from PolicyConfiguration.
 *
 * @param {Object} [db=prisma]
 * @returns {Promise<Object>}
 */
export async function getPrivacyEligibilityPolicy(db = prisma) {
  try {
    const configRecord = await db.policyConfiguration.findUnique({
      where: { key: PRIVACY_POLICY_KEY },
    });

    if (configRecord && configRecord.valueJson && typeof configRecord.valueJson === 'object') {
      return {
        ...DEFAULT_ELIGIBILITY_CONFIG,
        ...configRecord.valueJson,
      };
    }
  } catch (err) {
    // Fallback to default
  }

  return DEFAULT_ELIGIBILITY_CONFIG;
}

/**
 * Updates the privacy feature eligibility policy (Admin only).
 *
 * @param {Object} params
 * @param {string} params.featureKey - 'ANTI_FOLLOW' | 'FAILED_TO_FIND'
 * @param {Array<number>} [params.eligibleSvipLevels]
 * @param {Array<string>} [params.eligibleNobleRanks]
 * @param {Array<string>} [params.individualUserGrants]
 * @param {Object} [adminAudit]
 * @param {Object} [db=prisma]
 * @returns {Promise<Object>}
 */
export async function updatePrivacyEligibilityPolicy(
  { featureKey, eligibleSvipLevels, eligibleNobleRanks, individualUserGrants },
  adminAudit = {},
  db = prisma
) {
  const upperKey = String(featureKey || '').toUpperCase();
  if (upperKey !== 'ANTI_FOLLOW' && upperKey !== 'FAILED_TO_FIND') {
    const error = new Error('Invalid privacy feature key. Must be ANTI_FOLLOW or FAILED_TO_FIND.');
    error.statusCode = 400;
    error.code = 'INVALID_FEATURE_KEY';
    throw error;
  }

  const currentPolicy = await getPrivacyEligibilityPolicy(db);
  const featureConfig = currentPolicy[upperKey] || { featureKey: upperKey, individualUserGrants: [] };

  if (Array.isArray(eligibleSvipLevels)) {
    featureConfig.eligibleSvipLevels = eligibleSvipLevels.map(Number).filter((n) => !isNaN(n));
  }
  if (Array.isArray(eligibleNobleRanks)) {
    featureConfig.eligibleNobleRanks = eligibleNobleRanks.map((r) => String(r).toUpperCase().trim());
  }
  if (Array.isArray(individualUserGrants)) {
    featureConfig.individualUserGrants = Array.from(new Set(individualUserGrants.map(String)));
  }

  const updatedPolicy = {
    ...currentPolicy,
    [upperKey]: featureConfig,
  };

  await db.policyConfiguration.upsert({
    where: { key: PRIVACY_POLICY_KEY },
    update: {
      valueJson: updatedPolicy,
      status: 'ACTIVE',
    },
    create: {
      key: PRIVACY_POLICY_KEY,
      valueJson: updatedPolicy,
      status: 'ACTIVE',
    },
  });

  return updatedPolicy[upperKey];
}

/**
 * Grants explicit individual access to a privacy feature for a user.
 *
 * @param {string} userId
 * @param {string} featureKey
 * @param {Object} [adminAudit]
 * @param {Object} [db=prisma]
 * @returns {Promise<Object>}
 */
export async function grantIndividualAccess(userId, featureKey, adminAudit = {}, db = prisma) {
  const upperKey = String(featureKey || '').toUpperCase();
  const currentPolicy = await getPrivacyEligibilityPolicy(db);
  const featureConfig = currentPolicy[upperKey] || {
    featureKey: upperKey,
    eligibleSvipLevels: [],
    eligibleNobleRanks: [],
    individualUserGrants: [],
  };

  const grants = new Set(featureConfig.individualUserGrants || []);
  grants.add(String(userId));
  featureConfig.individualUserGrants = Array.from(grants);

  const updatedPolicy = {
    ...currentPolicy,
    [upperKey]: featureConfig,
  };

  await db.policyConfiguration.upsert({
    where: { key: PRIVACY_POLICY_KEY },
    update: { valueJson: updatedPolicy },
    create: { key: PRIVACY_POLICY_KEY, valueJson: updatedPolicy },
  });

  return { success: true, userId, featureKey: upperKey, granted: true };
}

/**
 * Revokes explicit individual access to a privacy feature for a user.
 *
 * @param {string} userId
 * @param {string} featureKey
 * @param {Object} [adminAudit]
 * @param {Object} [db=prisma]
 * @returns {Promise<Object>}
 */
export async function revokeIndividualAccess(userId, featureKey, adminAudit = {}, db = prisma) {
  const upperKey = String(featureKey || '').toUpperCase();
  const currentPolicy = await getPrivacyEligibilityPolicy(db);
  const featureConfig = currentPolicy[upperKey] || {
    featureKey: upperKey,
    eligibleSvipLevels: [],
    eligibleNobleRanks: [],
    individualUserGrants: [],
  };

  const grants = new Set(featureConfig.individualUserGrants || []);
  grants.delete(String(userId));
  featureConfig.individualUserGrants = Array.from(grants);

  const updatedPolicy = {
    ...currentPolicy,
    [upperKey]: featureConfig,
  };

  await db.policyConfiguration.upsert({
    where: { key: PRIVACY_POLICY_KEY },
    update: { valueJson: updatedPolicy },
    create: { key: PRIVACY_POLICY_KEY, valueJson: updatedPolicy },
  });

  return { success: true, userId, featureKey: upperKey, granted: false };
}

/**
 * Evaluates whether a user is eligible to use a specific privacy feature.
 *
 * Rules:
 * 1. Explicit individual grant -> Eligible
 * 2. User SVIP tier in configured eligibleSvipLevels -> Eligible
 * 3. User Noble rank in configured eligibleNobleRanks -> Eligible
 * 4. Otherwise -> Not eligible (Fail Closed)
 *
 * @param {string} userId
 * @param {string} featureKey - 'ANTI_FOLLOW' | 'FAILED_TO_FIND'
 * @param {Object} [db=prisma]
 * @returns {Promise<{ isEligible: boolean, reason: string }>}
 */
export async function checkUserEligibility(userId, featureKey, db = prisma) {
  if (!userId) return { isEligible: false, reason: 'UNAUTHENTICATED' };

  const upperKey = String(featureKey || '').toUpperCase();
  const policy = await getPrivacyEligibilityPolicy(db);
  const featureConfig = policy[upperKey];

  if (!featureConfig) {
    return { isEligible: false, reason: 'FEATURE_NOT_CONFIGURED' };
  }

  // 1. Check explicit individual grant
  const individualGrants = featureConfig.individualUserGrants || [];
  if (individualGrants.includes(String(userId))) {
    return { isEligible: true, reason: 'INDIVIDUAL_GRANT' };
  }

  // 2. Load user profile for SVIP and Noble evaluation
  const userProfile = await db.userProfile.findUnique({
    where: { userId },
    select: { svipLevel: true, nobleRank: true },
  });

  if (!userProfile) {
    return { isEligible: false, reason: 'PROFILE_NOT_FOUND' };
  }

  // 3. Check SVIP level eligibility
  const userSvip = Number(userProfile.svipLevel || 0);
  const eligibleSvips = featureConfig.eligibleSvipLevels || [];
  if (userSvip > 0 && eligibleSvips.includes(userSvip)) {
    return { isEligible: true, reason: `SVIP_TIER_${userSvip}` };
  }

  // 4. Check Noble rank eligibility
  const userNoble = String(userProfile.nobleRank || '').toUpperCase().trim();
  const eligibleNobles = (featureConfig.eligibleNobleRanks || []).map((r) => String(r).toUpperCase().trim());
  if (userNoble && eligibleNobles.includes(userNoble)) {
    return { isEligible: true, reason: `NOBLE_RANK_${userNoble}` };
  }

  // Fail closed
  return { isEligible: false, reason: 'INSUFFICIENT_TIER_NO_GRANT' };
}

/**
 * Retrieves the user's active privacy preferences from PolicyConfiguration.
 *
 * @param {string} userId
 * @param {Object} [db=prisma]
 * @returns {Promise<Object>}
 */
export async function getUserPreferences(userId, db = prisma) {
  try {
    const record = await db.policyConfiguration.findUnique({
      where: { key: `USER_PRIVACY_SETTINGS_${userId}` },
    });
    if (record && record.valueJson && typeof record.valueJson === 'object') {
      return record.valueJson;
    }
  } catch (_) {}
  return {
    ANTI_FOLLOW: false,
    FAILED_TO_FIND: false,
  };
}

/**
 * Saves the user's active privacy preferences to PolicyConfiguration.
 *
 * @param {string} userId
 * @param {Object} preferences
 * @param {Object} [db=prisma]
 * @returns {Promise<Object>}
 */
export async function setUserPreferences(userId, preferences, db = prisma) {
  const current = await getUserPreferences(userId, db);
  const updated = {
    ...current,
    ...preferences,
    updatedAt: new Date().toISOString(),
  };

  await db.policyConfiguration.upsert({
    where: { key: `USER_PRIVACY_SETTINGS_${userId}` },
    update: { valueJson: updated, status: 'ACTIVE' },
    create: { key: `USER_PRIVACY_SETTINGS_${userId}`, valueJson: updated, status: 'ACTIVE' },
  });

  return updated;
}

export default {
  getPrivacyEligibilityPolicy,
  updatePrivacyEligibilityPolicy,
  grantIndividualAccess,
  revokeIndividualAccess,
  checkUserEligibility,
  getUserPreferences,
  setUserPreferences,
};
