import prisma from '../config/database.js';
import redisClient from '../config/redis.js';
import socketEmitter from '../socket/socket.emitter.js';
import { getNobleStyle } from './asset.service.js';

async function logAudit({ adminId, adminName, action, targetEntity, targetEntityId, beforeStateJson, afterStateJson, reason, ipAddress }, db = prisma) {
  try {
    let validAdminId = adminId;
    if (validAdminId) {
      const existingAdmin = await db.admin.findUnique({ where: { id: validAdminId } }).catch(() => null);
      if (!existingAdmin) {
        const fallbackAdmin = await db.admin.findFirst().catch(() => null);
        validAdminId = fallbackAdmin ? fallbackAdmin.id : null;
      }
    } else {
      const fallbackAdmin = await db.admin.findFirst().catch(() => null);
      validAdminId = fallbackAdmin ? fallbackAdmin.id : null;
    }

    if (db.auditLog) {
      await db.auditLog.create({
        data: {
          adminId: validAdminId,
          adminName: adminName || 'System',
          action: action || 'NOBLE_OPERATION',
          targetEntity: targetEntity || 'UserNobleEntitlement',
          targetEntityId: targetEntityId ? String(targetEntityId) : null,
          beforeStateJson: beforeStateJson || null,
          afterStateJson: afterStateJson || null,
          reason: reason || 'Noble management action',
          ipAddress: ipAddress || null,
        },
      });
    }
  } catch (err) {
    // Audit logging is non-blocking
  }
}

export const CANONICAL_NOBLE_TIERS = [
  'BARON',
  'VISCOUNT',
  'COUNT',
  'MARQUIS',
  'DUKE',
  'KING',
  'EMPEROR',
];

export const NOBLE_TIER_ALIASES = {
  KNIGHT: 'BARON',
  EARL: 'COUNT',
  MERCURIUS: 'MARQUIS',
  PRINCE: 'KING',
  IMPERIAL: 'EMPEROR',
};

export const NOBLE_TIER_ASSETS = {
  BARON: {
    tierNumber: 1,
    name: 'Baron',
    badgeAsset: 'assets/nobles/baron_badge.webp',
    frameAsset: 'assets/nobles/baron_frame.webp',
    cardAsset: 'assets/nobles/baron_card.webp',
    micAsset: null,
    entranceAsset: null,
    color: '#CD7F32',
    styleType: 'BRONZE',
  },
  VISCOUNT: {
    tierNumber: 2,
    name: 'Viscount',
    badgeAsset: 'assets/nobles/viscount_badge.webp',
    frameAsset: 'assets/nobles/viscount_frame.webp',
    cardAsset: 'assets/nobles/viscount_card.webp',
    micAsset: null,
    entranceAsset: null,
    color: '#3B82F6',
    styleType: 'BLUE',
  },
  COUNT: {
    tierNumber: 3,
    name: 'Count',
    badgeAsset: 'assets/nobles/count_badge.webp',
    frameAsset: 'assets/nobles/count_frame.webp',
    cardAsset: 'assets/nobles/count_card.webp',
    micAsset: null,
    entranceAsset: null,
    color: '#E24A5A',
    styleType: 'CORAL',
  },
  MARQUIS: {
    tierNumber: 4,
    name: 'Marquis',
    badgeAsset: 'assets/nobles/marquis_badge.webp',
    frameAsset: 'assets/nobles/marquis_frame.webp',
    cardAsset: 'assets/nobles/tier-4-marquis_profilecard.webp',
    micAsset: null,
    entranceAsset: '/assets/nobles/marquis_entrance.webp',
    color: '#EF4444',
    styleType: 'RED',
  },
  DUKE: {
    tierNumber: 5,
    name: 'Duke',
    badgeAsset: 'assets/nobles/duke_badge.webp',
    frameAsset: 'assets/nobles/duke_frame.webp',
    cardAsset: 'assets/nobles/tier-5-duke_profilecard.webp',
    micAsset: null,
    entranceAsset: '/assets/nobles/duke_entrance.webp',
    color: '#AB47BC',
    styleType: 'PURPLE',
  },
  KING: {
    tierNumber: 6,
    name: 'King',
    badgeAsset: 'assets/nobles/king_badge.webp',
    frameAsset: 'assets/nobles/king_frame.webp',
    cardAsset: 'assets/nobles/king_card.webp',
    micAsset: '/assets/nobles/king_mic.webp',
    entranceAsset: '/assets/nobles/emperor_entrance.webp',
    color: '#FFD700',
    styleType: 'GOLDEN',
  },
  EMPEROR: {
    tierNumber: 7,
    name: 'Emperor',
    badgeAsset: 'assets/nobles/emperor_badge.webp',
    frameAsset: 'assets/nobles/emperor_frame.webp',
    cardAsset: 'assets/nobles/tier-7-emperor_profilecard.webp',
    micAsset: '/assets/nobles/king_mic.webp',
    entranceAsset: '/assets/nobles/emperor_entrance.webp',
    color: '#38BDF8',
    accentColor: '#F59E0B',
    styleType: 'GRADIENT',
  },
};

/**
 * Normalizes input tier name to canonical upper-case noble tier.
 * Strictly limits VIP Noble to exactly seven tiers (Baron through Emperor).
 */
export function normalizeNobleTier(tier) {
  if (!tier) return null;
  const str = String(tier).trim().toUpperCase();

  const numericMap = {
    '1': 'BARON',
    '2': 'VISCOUNT',
    '3': 'COUNT',
    '4': 'MARQUIS',
    '5': 'DUKE',
    '6': 'KING',
    '7': 'EMPEROR',
    'TIER 1': 'BARON',
    'TIER 2': 'VISCOUNT',
    'TIER 3': 'COUNT',
    'TIER 4': 'MARQUIS',
    'TIER 5': 'DUKE',
    'TIER 6': 'KING',
    'TIER 7': 'EMPEROR',
    'VIP 1': 'BARON',
    'VIP 2': 'VISCOUNT',
    'VIP 3': 'COUNT',
    'VIP 4': 'MARQUIS',
    'VIP 5': 'DUKE',
    'VIP 6': 'KING',
    'VIP 7': 'EMPEROR',
  };

  if (numericMap[str]) return numericMap[str];
  if (CANONICAL_NOBLE_TIERS.includes(str)) return str;
  if (NOBLE_TIER_ALIASES[str]) return NOBLE_TIER_ALIASES[str];
  return null;
}

/**
 * Formats a noble tier into a title-cased display string (e.g. "Marquis", "King").
 */
export function formatNobleTitle(tier) {
  const norm = normalizeNobleTier(tier);
  if (!norm) return null;
  return norm.charAt(0) + norm.slice(1).toLowerCase();
}

/**
 * Resolves the single authoritative active Noble tier for an account.
 * Automatically checks and cleans up expired entitlements.
 */
export async function getActiveNoble(userId, { checkExpiry = true } = {}, db = prisma) {
  if (!userId) return null;

  const record = await db.userNobleEntitlement.findFirst({
    where: {
      userId,
      isActive: true,
    },
    orderBy: { activatedAt: 'desc' },
  }).catch(() => null);

  if (!record) {
    // If no active entitlement exists, verify UserProfile.nobleRank is cleared
    const profile = await db.userProfile.findUnique({
      where: { userId },
      select: { nobleRank: true },
    }).catch(() => null);

    if (profile?.nobleRank) {
      await db.userProfile.update({
        where: { userId },
        data: { nobleRank: null },
      }).catch(() => {});
    }
    return null;
  }

  // Check expiration
  if (checkExpiry && record.expiresAt) {
    const expiresAtDate = new Date(record.expiresAt);
    if (expiresAtDate <= new Date()) {
      // Entitlement has expired: atomically mark inactive
      await db.$transaction(async (tx) => {
        await tx.userNobleEntitlement.update({
          where: { id: record.id },
          data: { isActive: false, updatedAt: new Date() },
        });
        await tx.userProfile.update({
          where: { userId },
          data: { nobleRank: null },
        });
      }).catch(() => {});

      // Invalidate caches
      try {
        if (redisClient && redisClient.isOpen) {
          await redisClient.del(`user:presence:${userId}`).catch(() => {});
          await redisClient.del(`user:profile:${userId}`).catch(() => {});
        }
        if (socketEmitter) {
          socketEmitter.emitToUser(userId, 'user:noble_updated', {
            userId,
            nobleRank: null,
            nobleTitle: null,
            isActive: false,
            expired: true,
            timestamp: new Date().toISOString(),
          });
        }
      } catch (_) {}

      return null;
    }
  }

  const canonicalTier = normalizeNobleTier(record.nobleTier);
  const displayTitle = formatNobleTitle(canonicalTier);
  const style = getNobleStyle(canonicalTier);
  const assets = NOBLE_TIER_ASSETS[canonicalTier] || null;

  const remainingMs = record.expiresAt ? Math.max(0, new Date(record.expiresAt).getTime() - Date.now()) : null;
  const remainingDays = remainingMs !== null ? Math.ceil(remainingMs / (1000 * 60 * 60 * 24)) : null;

  return {
    id: record.id,
    userId: record.userId,
    nobleTier: canonicalTier,
    tier: canonicalTier,
    nobleRank: displayTitle,
    nobleTitle: displayTitle,
    nobleLevel: displayTitle,
    tierNumber: assets?.tierNumber || 1,
    isActive: true,
    activatedAt: record.activatedAt,
    expiresAt: record.expiresAt,
    remainingDays,
    isPermanent: !record.expiresAt,
    grantType: record.grantType,
    grantReason: record.grantReason,
    grantedBy: record.grantedBy,
    badgeUrl: assets?.badgeAsset || assets?.badgeUrl || null,
    badgeAsset: assets?.badgeAsset || assets?.badgeUrl || null,
    tagUrl: assets?.tagAsset || assets?.tagUrl || null,
    frameUrl: assets?.frameAsset || assets?.frameUrl || null,
    frameAsset: assets?.frameAsset || assets?.frameUrl || null,
    chatBubbleUrl: assets?.chatBubbleAsset || assets?.chatBubbleUrl || null,
    micWaveUrl: assets?.micAsset || assets?.micWaveUrl || null,
    entranceEffectUrl: assets?.entranceAsset || assets?.entranceEffectUrl || null,
    color: style?.color || assets?.color || '#EF4444',
    textColor: style?.textColor || assets?.color || '#EF4444',
    nameColor: style?.nameColor || assets?.color || '#EF4444',
    styleType: style?.styleType || 'STANDARD',
    gradient: style?.gradient || null,
    style,
    assets,
  };
}

/**
 * Activates a Noble tier for a user.
 * STRICT ENFORCEMENT: Exactly ONE Noble tier may be active per account.
 * Activating any new tier automatically deactivates all previous active tiers in a transaction.
 */
export async function activateNobleTier(
  userId,
  {
    nobleTier,
    durationDays = 30,
    grantType = 'ADMIN_GRANT',
    grantReason = 'Noble tier activation',
    grantedBy = 'system',
    customExpiry = null,
    metadata = null,
  } = {},
  db = prisma
) {
  if (!userId) throw new Error('userId is required');
  const canonicalTier = normalizeNobleTier(nobleTier);
  if (!canonicalTier) {
    const error = new Error(`Invalid Noble tier: "${nobleTier}". Supported: ${CANONICAL_NOBLE_TIERS.join(', ')}`);
    error.statusCode = 400;
    error.code = 'INVALID_NOBLE_TIER';
    throw error;
  }

  const displayTitle = formatNobleTitle(canonicalTier);
  const now = new Date();
  let expiresAt = null;
  if (customExpiry) {
    expiresAt = new Date(customExpiry);
  } else if (durationDays && durationDays > 0) {
    expiresAt = new Date(now.getTime() + durationDays * 24 * 60 * 60 * 1000);
  }

  const result = await db.$transaction(async (tx) => {
    // 1. Deactivate any previously active noble entitlement
    const previousActive = await tx.userNobleEntitlement.findMany({
      where: { userId, isActive: true },
    });

    if (previousActive.length > 0) {
      await tx.userNobleEntitlement.updateMany({
        where: { userId, isActive: true },
        data: {
          isActive: false,
          updatedAt: now,
        },
      });
    }

    // 2. Create the new noble entitlement record
    const entitlementId = `noble_ent_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
    const newEntitlement = await tx.userNobleEntitlement.create({
      data: {
        id: entitlementId,
        userId,
        nobleTier: canonicalTier,
        isActive: true,
        activatedAt: now,
        expiresAt,
        grantType,
        grantReason,
        grantedBy,
        metadata: metadata || {},
      },
    });

    // 3. Synchronize UserProfile.nobleRank
    await tx.userProfile.upsert({
      where: { userId },
      update: { nobleRank: displayTitle },
      create: {
        userId,
        nobleRank: displayTitle,
      },
    });

    return {
      entitlement: newEntitlement,
      previousActive,
      previousDeactivatedCount: previousActive.length,
      previousTiers: previousActive.map((p) => p.nobleTier),
    };
  }, { timeout: 15000, maxWait: 10000 });

  // Non-blocking audit log outside transaction
  logAudit({
    adminId: grantedBy,
    adminName: grantedBy === 'system' ? 'System / Auto' : 'Admin',
    action: 'NOBLE_TIER_ACTIVATED',
    targetEntity: 'UserNobleEntitlement',
    targetEntityId: result.entitlement.id,
    beforeStateJson: {
      previousActiveTiers: result.previousActive.map((p) => ({
        id: p.id,
        tier: p.nobleTier,
        activatedAt: p.activatedAt,
        expiresAt: p.expiresAt,
      })),
    },
    afterStateJson: {
      id: result.entitlement.id,
      nobleTier: canonicalTier,
      isActive: true,
      activatedAt: now,
      expiresAt,
      grantType,
      grantReason,
    },
    reason: grantReason,
  }).catch(() => {});

  // 6. Synchronize Redis cache
  try {
    if (redisClient && redisClient.isOpen) {
      await redisClient.del(`user:presence:${userId}`).catch(() => {});
      await redisClient.del(`user:profile:${userId}`).catch(() => {});
    }
  } catch (_) {}

  // 7. Emit realtime Socket.IO updates to sender & room
  const fullActive = await getActiveNoble(userId, { checkExpiry: false }, db);
  try {
    if (socketEmitter) {
      const payload = {
        userId,
        nobleRank: displayTitle,
        nobleTitle: displayTitle,
        nobleLevel: displayTitle,
        nobleColor: fullActive?.color || '#EF4444',
        nobleStyle: fullActive?.style || null,
        nobleAssets: fullActive?.assets || null,
        isActive: true,
        expiresAt,
        timestamp: now.toISOString(),
      };
      socketEmitter.emitToUser(userId, 'user:noble_updated', payload);
      socketEmitter.emitToUser(userId, 'user:profile_updated', { userId, profile: payload });
    }
  } catch (_) {}

  return fullActive;
}

/**
 * Revokes the active Noble tier for a user.
 */
export async function revokeActiveNoble(
  userId,
  { reason = 'Revoked by admin', operatorId = 'system' } = {},
  db = prisma
) {
  if (!userId) throw new Error('userId is required');

  const result = await db.$transaction(async (tx) => {
    const activeRecords = await tx.userNobleEntitlement.findMany({
      where: { userId, isActive: true },
    });

    if (activeRecords.length > 0) {
      await tx.userNobleEntitlement.updateMany({
        where: { userId, isActive: true },
        data: {
          isActive: false,
          updatedAt: new Date(),
        },
      });
    }

    await tx.userProfile.updateMany({
      where: { userId },
      data: { nobleRank: null },
    });

    await logAudit(
      {
        adminId: operatorId,
        adminName: operatorId === 'system' ? 'System' : 'Admin',
        action: 'NOBLE_TIER_REVOKED',
        targetEntity: 'UserNobleEntitlement',
        targetEntityId: userId,
        beforeStateJson: { revokedTiers: activeRecords.map((r) => r.nobleTier) },
        afterStateJson: { nobleRank: null, isActive: false },
        reason,
      },
      tx
    );

    return {
      revokedCount: activeRecords.length,
      revokedTiers: activeRecords.map((r) => r.nobleTier),
    };
  });

  // Clear Redis
  try {
    if (redisClient && redisClient.isOpen) {
      await redisClient.del(`user:presence:${userId}`).catch(() => {});
      await redisClient.del(`user:profile:${userId}`).catch(() => {});
    }
  } catch (_) {}

  // Emit event
  try {
    if (socketEmitter) {
      const payload = {
        userId,
        nobleRank: null,
        nobleTitle: null,
        nobleLevel: null,
        nobleColor: null,
        nobleStyle: null,
        isActive: false,
        reason,
        timestamp: new Date().toISOString(),
      };
      socketEmitter.emitToUser(userId, 'user:noble_updated', payload);
      socketEmitter.emitToUser(userId, 'user:profile_updated', { userId, profile: payload });
    }
  } catch (_) {}

  return {
    success: true,
    userId,
    revokedCount: result.revokedCount,
    revokedTiers: result.revokedTiers,
  };
}

/**
 * Returns complete historical audit of noble entitlements for a user.
 */
export async function getUserNobleHistory(userId, db = prisma) {
  if (!userId) return [];
  const records = await db.userNobleEntitlement.findMany({
    where: { userId },
    orderBy: { createdAt: 'desc' },
  });

  return records.map((r) => ({
    id: r.id,
    nobleTier: r.nobleTier,
    nobleRank: formatNobleTitle(r.nobleTier),
    isActive: r.isActive,
    activatedAt: r.activatedAt,
    expiresAt: r.expiresAt,
    grantType: r.grantType,
    grantReason: r.grantReason,
    grantedBy: r.grantedBy,
    createdAt: r.createdAt,
  }));
}

/**
 * Dry-run and live reconciliation across all user noble records in the system.
 */
export async function reconcileNobleEntitlements({ dryRun = true } = {}, db = prisma) {
  const usersWithEntitlements = await db.userNobleEntitlement.findMany({
    select: { userId: true },
    distinct: ['userId'],
  });

  const profilesWithNoble = await db.userProfile.findMany({
    where: { nobleRank: { not: null } },
    select: { userId: true, nobleRank: true },
  });

  const allUserIds = new Set([
    ...usersWithEntitlements.map((u) => u.userId),
    ...profilesWithNoble.map((p) => p.userId),
  ]);

  const auditResults = [];
  const now = new Date();

  for (const userId of allUserIds) {
    const entitlements = await db.userNobleEntitlement.findMany({
      where: { userId },
      orderBy: { activatedAt: 'desc' },
    });

    const profile = await db.userProfile.findUnique({
      where: { userId },
      select: { nobleRank: true },
    });

    const activeRecords = entitlements.filter((e) => e.isActive);
    const validActiveRecords = activeRecords.filter(
      (e) => !e.expiresAt || new Date(e.expiresAt) > now
    );

    let proposedSurvivingTier = null;
    let needsAdjustment = false;
    let conflict = false;

    if (activeRecords.length > 1) {
      needsAdjustment = true;
      conflict = true;
      // Propose the most recently activated valid tier
      proposedSurvivingTier = validActiveRecords[0]?.nobleTier || activeRecords[0]?.nobleTier;
    } else if (activeRecords.length === 1) {
      const active = activeRecords[0];
      if (active.expiresAt && new Date(active.expiresAt) <= now) {
        // Expired but marked active
        needsAdjustment = true;
        proposedSurvivingTier = null;
      } else {
        proposedSurvivingTier = active.nobleTier;
        if (profile?.nobleRank !== formatNobleTitle(active.nobleTier)) {
          needsAdjustment = true;
        }
      }
    } else if (profile?.nobleRank) {
      // Profile has nobleRank but no active entitlement record
      needsAdjustment = true;
      proposedSurvivingTier = profile.nobleRank;
    }

    const item = {
      userId,
      storedProfileNoble: profile?.nobleRank || null,
      totalEntitlements: entitlements.length,
      activeCount: activeRecords.length,
      validActiveCount: validActiveRecords.length,
      needsAdjustment,
      hasConflict: conflict,
      proposedSurvivingTier: proposedSurvivingTier ? formatNobleTitle(proposedSurvivingTier) : null,
      entitlements: entitlements.map((e) => ({
        id: e.id,
        tier: e.nobleTier,
        isActive: e.isActive,
        isExpired: e.expiresAt ? new Date(e.expiresAt) <= now : false,
        activatedAt: e.activatedAt,
        expiresAt: e.expiresAt,
        grantType: e.grantType,
      })),
    };

    auditResults.push(item);

    if (!dryRun && needsAdjustment) {
      await db.$transaction(async (tx) => {
        if (proposedSurvivingTier) {
          const canonical = normalizeNobleTier(proposedSurvivingTier);
          const display = formatNobleTitle(canonical);

          // Deactivate all except the surviving one
          const surviving = validActiveRecords[0] || activeRecords[0];
          if (surviving) {
            await tx.userNobleEntitlement.updateMany({
              where: { userId, id: { not: surviving.id } },
              data: { isActive: false, updatedAt: now },
            });
            await tx.userNobleEntitlement.update({
              where: { id: surviving.id },
              data: { isActive: true, nobleTier: canonical, updatedAt: now },
            });
          }
          await tx.userProfile.update({
            where: { userId },
            data: { nobleRank: display },
          });
        } else {
          // No valid tier: deactivate all
          await tx.userNobleEntitlement.updateMany({
            where: { userId, isActive: true },
            data: { isActive: false, updatedAt: now },
          });
          await tx.userProfile.update({
            where: { userId },
            data: { nobleRank: null },
          });
        }
      });
    }
  }

  return {
    executionMode: dryRun ? 'DRY_RUN' : 'LIVE_UPDATE',
    totalUsersAudited: allUserIds.size,
    needsAdjustmentCount: auditResults.filter((r) => r.needsAdjustment).length,
    conflictCount: auditResults.filter((r) => r.hasConflict).length,
    users: auditResults,
  };
}

export default {
  CANONICAL_NOBLE_TIERS,
  NOBLE_TIER_ALIASES,
  NOBLE_TIER_ASSETS,
  normalizeNobleTier,
  formatNobleTitle,
  getActiveNoble,
  activateNobleTier,
  revokeActiveNoble,
  getUserNobleHistory,
  reconcileNobleEntitlements,
};
