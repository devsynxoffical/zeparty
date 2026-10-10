import prisma from '../config/database.js';

async function logAudit({ adminId, adminName, action, targetEntity, targetEntityId, beforeStateJson, afterStateJson, reason, ipAddress }, db = prisma) {
  try {
    let validAdminId = adminId;
    if (validAdminId && validAdminId !== 'SYSTEM' && validAdminId !== 'ADMIN') {
      const exists = await db.admin?.findUnique?.({ where: { id: validAdminId }, select: { id: true } });
      if (!exists) {
        const fallback = await db.admin?.findFirst?.({ select: { id: true, name: true } });
        validAdminId = fallback ? fallback.id : null;
        if (fallback && !adminName) adminName = fallback.name;
      }
    } else {
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
        targetEntity: targetEntity || 'BDReaction',
        targetEntityId: targetEntityId || null,
        beforeStateJson: beforeStateJson ? JSON.parse(JSON.stringify(beforeStateJson)) : null,
        afterStateJson: afterStateJson ? JSON.parse(JSON.stringify(afterStateJson)) : null,
        reason: reason || null,
        ipAddress: ipAddress || '127.0.0.1',
      },
    });
  } catch (err) {
    console.error('Failed to write audit log in bdReaction.service:', err.message);
  }
}

// In-memory fallback / cache for fast access
let reactionsCache = [
  {
    id: 'bd_rx_clap',
    name: 'Team Applause',
    code: 'CLAP',
    iconUrl: '/assets/reactions/bd_clap.png',
    animationUrl: '/assets/reactions/bd_clap.json',
    displayOrder: 1,
    isActive: true,
    scope: 'GLOBAL',
    countries: [],
    regions: [],
    placement: ['BD_PROFILE', 'TEAM_LIST', 'TARGET_AREA', 'SALARY_SCREEN'],
    isFree: true,
    coinPrice: 0,
    allowedRoles: ['ALL', 'APPROVED_BD'],
    cooldownSec: 3,
    limitPerDay: 100,
    totalUsage: 254,
    uniqueUsersCount: 42,
  },
  {
    id: 'bd_rx_rocket',
    name: 'Target Achieved Rocket',
    code: 'ROCKET',
    iconUrl: '/assets/reactions/bd_rocket.png',
    animationUrl: '/assets/reactions/bd_rocket.json',
    displayOrder: 2,
    isActive: true,
    scope: 'GLOBAL',
    countries: [],
    regions: [],
    placement: ['TARGET_AREA', 'SALARY_SCREEN'],
    isFree: true,
    coinPrice: 0,
    allowedRoles: ['ALL', 'APPROVED_BD'],
    cooldownSec: 5,
    limitPerDay: 50,
    totalUsage: 189,
    uniqueUsersCount: 31,
  },
  {
    id: 'bd_rx_crown',
    name: 'Top BD Crown',
    code: 'CROWN',
    iconUrl: '/assets/reactions/bd_crown.png',
    animationUrl: '/assets/reactions/bd_crown.json',
    displayOrder: 3,
    isActive: true,
    scope: 'GLOBAL',
    countries: [],
    regions: [],
    placement: ['BD_PROFILE', 'SALARY_SCREEN'],
    isFree: false,
    coinPrice: 50,
    allowedRoles: ['APPROVED_BD', 'BD_MANAGER'],
    cooldownSec: 10,
    limitPerDay: 20,
    totalUsage: 67,
    uniqueUsersCount: 15,
  },
];

let isMasterEnabled = true;
let reactionUsageLogs = [];

export async function listReactionsForAdmin(filters = {}) {
  let list = [...reactionsCache];
  if (filters.status === 'active') {
    list = list.filter((r) => r.isActive);
  } else if (filters.status === 'inactive') {
    list = list.filter((r) => !r.isActive);
  }
  if (filters.country && filters.country !== 'GLOBAL') {
    list = list.filter((r) => r.scope === 'GLOBAL' || (r.countries && r.countries.includes(filters.country)));
  }
  if (filters.search) {
    const q = filters.search.toLowerCase();
    list = list.filter((r) => r.name.toLowerCase().includes(q) || r.code.toLowerCase().includes(q));
  }
  list.sort((a, b) => a.displayOrder - b.displayOrder);

  return {
    masterEnabled: isMasterEnabled,
    totalCount: list.length,
    reactions: list,
  };
}

export async function createReaction(data, { adminId, adminName, ipAddress } = {}) {
  const newReaction = {
    id: data.id || `bd_rx_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
    name: data.name || 'Custom Reaction',
    code: (data.code || data.name || 'REACTION').toUpperCase().replace(/\s+/g, '_'),
    iconUrl: data.iconUrl || '/assets/reactions/default.png',
    animationUrl: data.animationUrl || null,
    displayOrder: typeof data.displayOrder === 'number' ? data.displayOrder : reactionsCache.length + 1,
    isActive: data.isActive !== undefined ? Boolean(data.isActive) : true,
    scope: data.scope || 'GLOBAL',
    countries: Array.isArray(data.countries) ? data.countries : [],
    regions: Array.isArray(data.regions) ? data.regions : [],
    placement: Array.isArray(data.placement) ? data.placement : ['BD_PROFILE', 'TEAM_LIST', 'TARGET_AREA'],
    isFree: data.isFree !== undefined ? Boolean(data.isFree) : (Number(data.coinPrice) === 0),
    coinPrice: Number(data.coinPrice) || 0,
    allowedRoles: Array.isArray(data.allowedRoles) ? data.allowedRoles : ['ALL'],
    cooldownSec: Number(data.cooldownSec) || 3,
    limitPerDay: Number(data.limitPerDay) || 100,
    totalUsage: 0,
    uniqueUsersCount: 0,
    createdAt: new Date().toISOString(),
  };

  reactionsCache.push(newReaction);

  await logAudit({
    adminId,
    adminName,
    action: 'BD_REACTION_CREATED',
    targetEntity: 'BDReaction',
    targetEntityId: newReaction.id,
    afterStateJson: newReaction,
    reason: data.reason || 'New BD Reaction created via Admin Panel',
    ipAddress,
  });

  return newReaction;
}

export async function updateReaction(id, updates, { adminId, adminName, ipAddress } = {}) {
  const index = reactionsCache.findIndex((r) => r.id === id);
  if (index === -1) {
    const error = new Error('BD Reaction not found');
    error.statusCode = 404;
    error.code = 'REACTION_NOT_FOUND';
    throw error;
  }

  const beforeState = { ...reactionsCache[index] };
  reactionsCache[index] = {
    ...reactionsCache[index],
    ...updates,
    updatedAt: new Date().toISOString(),
  };

  await logAudit({
    adminId,
    adminName,
    action: 'BD_REACTION_UPDATED',
    targetEntity: 'BDReaction',
    targetEntityId: id,
    beforeStateJson: beforeState,
    afterStateJson: reactionsCache[index],
    reason: updates.reason || 'BD Reaction updated via Admin Panel',
    ipAddress,
  });

  return reactionsCache[index];
}

export async function toggleReactionStatus(id, { isActive, adminId, adminName, ipAddress } = {}) {
  const rx = reactionsCache.find((r) => r.id === id);
  if (!rx) {
    const error = new Error('BD Reaction not found');
    error.statusCode = 404;
    throw error;
  }

  const beforeStatus = rx.isActive;
  rx.isActive = isActive !== undefined ? Boolean(isActive) : !rx.isActive;

  await logAudit({
    adminId,
    adminName,
    action: 'BD_REACTION_STATUS_TOGGLED',
    targetEntity: 'BDReaction',
    targetEntityId: id,
    beforeStateJson: { isActive: beforeStatus },
    afterStateJson: { isActive: rx.isActive },
    reason: `BD Reaction status changed to ${rx.isActive ? 'ACTIVE' : 'INACTIVE'}`,
    ipAddress,
  });

  return rx;
}

export async function setMasterSwitch({ enabled, adminId, adminName, ipAddress } = {}) {
  const before = isMasterEnabled;
  isMasterEnabled = Boolean(enabled);

  await logAudit({
    adminId,
    adminName,
    action: 'BD_REACTION_MASTER_SWITCH_TOGGLED',
    targetEntity: 'BDReactionSystem',
    targetEntityId: 'GLOBAL',
    beforeStateJson: { enabled: before },
    afterStateJson: { enabled: isMasterEnabled },
    reason: `BD Reaction Master Switch set to ${isMasterEnabled ? 'ENABLED' : 'DISABLED'}`,
    ipAddress,
  });

  return { masterEnabled: isMasterEnabled };
}

export async function deleteReaction(id, { adminId, adminName, ipAddress, reason } = {}) {
  const index = reactionsCache.findIndex((r) => r.id === id);
  if (index === -1) {
    const error = new Error('BD Reaction not found');
    error.statusCode = 404;
    throw error;
  }

  const removed = reactionsCache.splice(index, 1)[0];

  await logAudit({
    adminId,
    adminName,
    action: 'BD_REACTION_DELETED',
    targetEntity: 'BDReaction',
    targetEntityId: id,
    beforeStateJson: removed,
    reason: reason || 'BD Reaction deleted by Administrator',
    ipAddress,
  });

  return { success: true, id };
}

export async function emergencyDisableReaction(id, { adminId, adminName, ipAddress, reason } = {}) {
  const rx = reactionsCache.find((r) => r.id === id);
  if (!rx) {
    const error = new Error('BD Reaction not found');
    error.statusCode = 404;
    throw error;
  }

  rx.isActive = false;

  await logAudit({
    adminId,
    adminName,
    action: 'BD_REACTION_EMERGENCY_DISABLED',
    targetEntity: 'BDReaction',
    targetEntityId: id,
    reason: reason || 'Emergency Moderation Disable applied',
    ipAddress,
  });

  return { success: true, id, isActive: false };
}

export async function getReactionAnalytics() {
  return {
    masterEnabled: isMasterEnabled,
    totalReactionsConfigured: reactionsCache.length,
    activeReactions: reactionsCache.filter((r) => r.isActive).length,
    totalSends: reactionsCache.reduce((sum, r) => sum + (r.totalUsage || 0), 0),
    topUsedReactions: [...reactionsCache].sort((a, b) => b.totalUsage - a.totalUsage).slice(0, 5),
    recentLogs: reactionUsageLogs.slice(-20),
  };
}

export async function listActiveReactionsForUser({ userId, countryCode, role, placement } = {}) {
  if (!isMasterEnabled) {
    return { masterEnabled: false, reactions: [] };
  }

  let list = reactionsCache.filter((r) => r.isActive);

  if (countryCode && countryCode !== 'GLOBAL') {
    list = list.filter((r) => r.scope === 'GLOBAL' || (r.countries && r.countries.includes(countryCode)));
  }

  if (placement) {
    list = list.filter((r) => !r.placement || r.placement.includes('ALL') || r.placement.includes(placement));
  }

  return {
    masterEnabled: true,
    reactions: list.sort((a, b) => a.displayOrder - b.displayOrder),
  };
}

export async function sendReactionByUser({ userId, reactionId, targetUserId, targetContext } = {}) {
  if (!isMasterEnabled) {
    const error = new Error('BD Reactions are currently disabled by Administration');
    error.statusCode = 403;
    throw error;
  }

  const rx = reactionsCache.find((r) => r.id === reactionId);
  if (!rx || !rx.isActive) {
    const error = new Error('Selected reaction is inactive or not found');
    error.statusCode = 404;
    throw error;
  }

  rx.totalUsage = (rx.totalUsage || 0) + 1;

  const usageRecord = {
    id: `rxlog_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
    reactionId: rx.id,
    reactionCode: rx.code,
    senderUserId: userId,
    targetUserId: targetUserId || null,
    targetContext: targetContext || 'BD_PROFILE',
    timestamp: new Date().toISOString(),
  };

  reactionUsageLogs.push(usageRecord);

  return {
    success: true,
    reaction: rx,
    usageRecord,
  };
}

export default {
  listReactionsForAdmin,
  createReaction,
  updateReaction,
  toggleReactionStatus,
  setMasterSwitch,
  deleteReaction,
  emergencyDisableReaction,
  getReactionAnalytics,
  listActiveReactionsForUser,
  sendReactionByUser,
};
