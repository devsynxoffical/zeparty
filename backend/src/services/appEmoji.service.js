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
        targetEntity: targetEntity || 'AppEmoji',
        targetEntityId: targetEntityId || null,
        beforeStateJson: beforeStateJson ? JSON.parse(JSON.stringify(beforeStateJson)) : null,
        afterStateJson: afterStateJson ? JSON.parse(JSON.stringify(afterStateJson)) : null,
        reason: reason || null,
        ipAddress: ipAddress || '127.0.0.1',
      },
    });
  } catch (err) {
    console.error('Failed to write audit log in appEmoji.service:', err.message);
  }
}

let categories = [
  { id: 'cat_default', name: 'Default', displayOrder: 1, isActive: true },
  { id: 'cat_funny', name: 'Funny', displayOrder: 2, isActive: true },
  { id: 'cat_love', name: 'Love', displayOrder: 3, isActive: true },
  { id: 'cat_angry', name: 'Angry', displayOrder: 4, isActive: true },
  { id: 'cat_special', name: 'Special', displayOrder: 5, isActive: true },
  { id: 'cat_event', name: 'Event', displayOrder: 6, isActive: true },
  { id: 'cat_svip', name: 'SVIP', displayOrder: 7, isActive: true },
  { id: 'cat_noble', name: 'Noble', displayOrder: 8, isActive: true },
];

let emojisCache = [
  {
    id: 'emoji_heart',
    name: 'Sparkle Heart',
    code: 'SPARKLE_HEART',
    iconUrl: '/assets/emojis/heart.png',
    animationUrl: '/assets/emojis/heart.json',
    category: 'Love',
    categoryId: 'cat_love',
    displayOrder: 1,
    isActive: true,
    scope: 'GLOBAL',
    countries: [],
    roomTypes: ['PARTY', 'AUDIO', 'LIVE', 'CHAT'],
    eligibility: 'ALL',
    priceType: 'FREE',
    coinPrice: 0,
    svipLevelRequired: 0,
    nobleRankRequired: null,
    startTime: null,
    expiryTime: null,
    cooldownSec: 2,
    limitPerUser: 120,
    totalUsage: 1420,
    uniqueUsersCount: 310,
  },
  {
    id: 'emoji_fire',
    name: 'Party Fire',
    code: 'PARTY_FIRE',
    iconUrl: '/assets/emojis/fire.png',
    animationUrl: '/assets/emojis/fire.json',
    category: 'Special',
    categoryId: 'cat_special',
    displayOrder: 2,
    isActive: true,
    scope: 'GLOBAL',
    countries: [],
    roomTypes: ['PARTY', 'AUDIO', 'LIVE'],
    eligibility: 'ALL',
    priceType: 'FREE',
    coinPrice: 0,
    svipLevelRequired: 0,
    nobleRankRequired: null,
    startTime: null,
    expiryTime: null,
    cooldownSec: 2,
    limitPerUser: 120,
    totalUsage: 980,
    uniqueUsersCount: 245,
  },
  {
    id: 'emoji_svip_crown',
    name: 'Imperial SVIP Crown',
    code: 'SVIP_CROWN',
    iconUrl: '/assets/emojis/svip_crown.png',
    animationUrl: '/assets/emojis/svip_crown.json',
    category: 'SVIP',
    categoryId: 'cat_svip',
    displayOrder: 3,
    isActive: true,
    scope: 'GLOBAL',
    countries: [],
    roomTypes: ['PARTY', 'AUDIO', 'LIVE', 'CHAT'],
    eligibility: 'SVIP',
    priceType: 'SVIP_UNLOCK',
    coinPrice: 0,
    svipLevelRequired: 1,
    nobleRankRequired: null,
    startTime: null,
    expiryTime: null,
    cooldownSec: 3,
    limitPerUser: 60,
    totalUsage: 430,
    uniqueUsersCount: 88,
  },
];

let isMasterEmojiEnabled = true;
let emojiUsageLogs = [];

export async function listEmojisForAdmin(filters = {}) {
  let list = [...emojisCache];
  if (filters.category) {
    list = list.filter((e) => e.category.toLowerCase() === filters.category.toLowerCase() || e.categoryId === filters.category);
  }
  if (filters.roomType) {
    list = list.filter((e) => e.roomTypes.includes(filters.roomType.toUpperCase()));
  }
  if (filters.status === 'active') {
    list = list.filter((e) => e.isActive);
  } else if (filters.status === 'inactive') {
    list = list.filter((e) => !e.isActive);
  }
  if (filters.search) {
    const q = filters.search.toLowerCase();
    list = list.filter((e) => e.name.toLowerCase().includes(q) || e.code.toLowerCase().includes(q));
  }

  list.sort((a, b) => a.displayOrder - b.displayOrder);

  return {
    masterEnabled: isMasterEmojiEnabled,
    categories,
    totalCount: list.length,
    emojis: list,
  };
}

export async function createEmoji(data, { adminId, adminName, ipAddress } = {}) {
  const newEmoji = {
    id: data.id || `emoji_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
    name: data.name || 'New Emoji',
    code: (data.code || data.name || 'EMOJI').toUpperCase().replace(/\s+/g, '_'),
    iconUrl: data.iconUrl || '/assets/emojis/default.png',
    animationUrl: data.animationUrl || null,
    category: data.category || 'Default',
    categoryId: data.categoryId || 'cat_default',
    displayOrder: typeof data.displayOrder === 'number' ? data.displayOrder : emojisCache.length + 1,
    isActive: data.isActive !== undefined ? Boolean(data.isActive) : true,
    scope: data.scope || 'GLOBAL',
    countries: Array.isArray(data.countries) ? data.countries : [],
    roomTypes: Array.isArray(data.roomTypes) ? data.roomTypes : ['PARTY', 'AUDIO', 'LIVE', 'CHAT'],
    eligibility: data.eligibility || 'ALL',
    priceType: data.priceType || 'FREE',
    coinPrice: Number(data.coinPrice) || 0,
    svipLevelRequired: Number(data.svipLevelRequired) || 0,
    nobleRankRequired: data.nobleRankRequired || null,
    startTime: data.startTime || null,
    expiryTime: data.expiryTime || null,
    cooldownSec: Number(data.cooldownSec) || 2,
    limitPerUser: Number(data.limitPerUser) || 100,
    totalUsage: 0,
    uniqueUsersCount: 0,
    createdAt: new Date().toISOString(),
  };

  emojisCache.push(newEmoji);

  await logAudit({
    adminId,
    adminName,
    action: 'APP_EMOJI_CREATED',
    targetEntity: 'AppEmoji',
    targetEntityId: newEmoji.id,
    afterStateJson: newEmoji,
    reason: data.reason || 'New App Emoji created via Admin Panel',
    ipAddress,
  });

  return newEmoji;
}

export async function updateEmoji(id, updates, { adminId, adminName, ipAddress } = {}) {
  const index = emojisCache.findIndex((e) => e.id === id);
  if (index === -1) {
    const error = new Error('Emoji not found');
    error.statusCode = 404;
    error.code = 'EMOJI_NOT_FOUND';
    throw error;
  }

  const beforeState = { ...emojisCache[index] };
  emojisCache[index] = {
    ...emojisCache[index],
    ...updates,
    updatedAt: new Date().toISOString(),
  };

  await logAudit({
    adminId,
    adminName,
    action: 'APP_EMOJI_UPDATED',
    targetEntity: 'AppEmoji',
    targetEntityId: id,
    beforeStateJson: beforeState,
    afterStateJson: emojisCache[index],
    reason: updates.reason || 'App Emoji updated via Admin Panel',
    ipAddress,
  });

  return emojisCache[index];
}

export async function toggleEmojiStatus(id, { isActive, adminId, adminName, ipAddress } = {}) {
  const emoji = emojisCache.find((e) => e.id === id);
  if (!emoji) {
    const error = new Error('Emoji not found');
    error.statusCode = 404;
    throw error;
  }

  const beforeStatus = emoji.isActive;
  emoji.isActive = isActive !== undefined ? Boolean(isActive) : !emoji.isActive;

  await logAudit({
    adminId,
    adminName,
    action: 'APP_EMOJI_STATUS_TOGGLED',
    targetEntity: 'AppEmoji',
    targetEntityId: id,
    beforeStateJson: { isActive: beforeStatus },
    afterStateJson: { isActive: emoji.isActive },
    reason: `Emoji status changed to ${emoji.isActive ? 'ACTIVE' : 'INACTIVE'}`,
    ipAddress,
  });

  return emoji;
}

export async function setMasterEmojiSwitch({ enabled, adminId, adminName, ipAddress } = {}) {
  const before = isMasterEmojiEnabled;
  isMasterEmojiEnabled = Boolean(enabled);

  await logAudit({
    adminId,
    adminName,
    action: 'APP_EMOJI_MASTER_SWITCH_TOGGLED',
    targetEntity: 'AppEmojiSystem',
    targetEntityId: 'GLOBAL',
    beforeStateJson: { enabled: before },
    afterStateJson: { enabled: isMasterEmojiEnabled },
    reason: `App Emoji Master Switch set to ${isMasterEmojiEnabled ? 'ENABLED' : 'DISABLED'}`,
    ipAddress,
  });

  return { masterEnabled: isMasterEmojiEnabled };
}

export async function deleteEmoji(id, { adminId, adminName, ipAddress, reason } = {}) {
  const index = emojisCache.findIndex((e) => e.id === id);
  if (index === -1) {
    const error = new Error('Emoji not found');
    error.statusCode = 404;
    throw error;
  }

  const removed = emojisCache.splice(index, 1)[0];

  await logAudit({
    adminId,
    adminName,
    action: 'APP_EMOJI_DELETED',
    targetEntity: 'AppEmoji',
    targetEntityId: id,
    beforeStateJson: removed,
    reason: reason || 'Emoji deleted by Administrator',
    ipAddress,
  });

  return { success: true, id };
}

export async function emergencyDisableEmoji(id, { adminId, adminName, ipAddress, reason } = {}) {
  const emoji = emojisCache.find((e) => e.id === id);
  if (!emoji) {
    const error = new Error('Emoji not found');
    error.statusCode = 404;
    throw error;
  }

  emoji.isActive = false;

  await logAudit({
    adminId,
    adminName,
    action: 'APP_EMOJI_EMERGENCY_DISABLED',
    targetEntity: 'AppEmoji',
    targetEntityId: id,
    reason: reason || 'Emergency Moderation Disable applied on Emoji',
    ipAddress,
  });

  return { success: true, id, isActive: false };
}

export async function reorderEmojis(orderedIds = [], { adminId, adminName, ipAddress } = {}) {
  orderedIds.forEach((id, index) => {
    const emoji = emojisCache.find((e) => e.id === id);
    if (emoji) {
      emoji.displayOrder = index + 1;
    }
  });

  await logAudit({
    adminId,
    adminName,
    action: 'APP_EMOJIS_REORDERED',
    targetEntity: 'AppEmojiList',
    targetEntityId: 'GLOBAL',
    afterStateJson: { orderedIds },
    reason: 'Emojis reordered by Administrator',
    ipAddress,
  });

  return { success: true, emojis: emojisCache.sort((a, b) => a.displayOrder - b.displayOrder) };
}

export async function getEmojiAnalytics() {
  return {
    masterEnabled: isMasterEmojiEnabled,
    totalEmojisConfigured: emojisCache.length,
    activeEmojis: emojisCache.filter((e) => e.isActive).length,
    totalSends: emojisCache.reduce((sum, e) => sum + (e.totalUsage || 0), 0),
    topEmojis: [...emojisCache].sort((a, b) => b.totalUsage - a.totalUsage).slice(0, 5),
    roomUsage: {
      PARTY: 890,
      AUDIO: 620,
      LIVE: 1150,
      CHAT: 430,
    },
    recentLogs: emojiUsageLogs.slice(-20),
  };
}

export async function getAppEmojiTray({ roomType, userSvipLevel = 0, userNobleRank = null, countryCode } = {}) {
  if (!isMasterEmojiEnabled) {
    return { masterEnabled: false, categories: [], emojis: [] };
  }

  const now = new Date();
  let available = emojisCache.filter((e) => {
    if (!e.isActive) return false;
    if (e.startTime && new Date(e.startTime) > now) return false;
    if (e.expiryTime && new Date(e.expiryTime) < now) return false;
    if (roomType && e.roomTypes && !e.roomTypes.includes(roomType.toUpperCase())) return false;
    if (countryCode && e.scope !== 'GLOBAL' && e.countries && !e.countries.includes(countryCode)) return false;
    return true;
  });

  return {
    masterEnabled: true,
    categories: categories.filter((c) => c.isActive).sort((a, b) => a.displayOrder - b.displayOrder),
    emojis: available.sort((a, b) => a.displayOrder - b.displayOrder),
  };
}

export async function sendAppEmoji({ userId, emojiId, roomId, targetUserId } = {}) {
  if (!isMasterEmojiEnabled) {
    const error = new Error('Emoji system is currently disabled by Administration');
    error.statusCode = 403;
    throw error;
  }

  const emoji = emojisCache.find((e) => e.id === emojiId);
  if (!emoji || !emoji.isActive) {
    const error = new Error('Emoji is inactive or not found');
    error.statusCode = 404;
    throw error;
  }

  emoji.totalUsage = (emoji.totalUsage || 0) + 1;

  const usageRecord = {
    id: `emojilog_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
    emojiId: emoji.id,
    emojiCode: emoji.code,
    senderUserId: userId,
    roomId: roomId || null,
    targetUserId: targetUserId || null,
    timestamp: new Date().toISOString(),
  };

  emojiUsageLogs.push(usageRecord);

  return {
    success: true,
    emoji,
    usageRecord,
  };
}

export default {
  listEmojisForAdmin,
  createEmoji,
  updateEmoji,
  toggleEmojiStatus,
  setMasterEmojiSwitch,
  deleteEmoji,
  emergencyDisableEmoji,
  reorderEmojis,
  getEmojiAnalytics,
  getAppEmojiTray,
  sendAppEmoji,
};
