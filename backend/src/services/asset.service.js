import prisma from '../config/database.js';
import assetRepository from '../repositories/asset.repository.js';
import userAssetRepository from '../repositories/userAsset.repository.js';
import redisProxy from '../config/redis.js';
import { emitToUser } from '../socket/socket.emitter.js';
import {
  isRestrictedSpecialAsset,
  isPublicStoreItem,
} from '../utils/assetClassification.util.js';

async function logAudit({ adminId, adminName, action, targetEntity, targetEntityId, beforeStateJson, afterStateJson, reason, ipAddress }, db = prisma) {
  if (!adminId) return;
  try {
    await db.auditLog.create({
      data: {
        adminId,
        adminName: adminName || 'Administrator',
        action,
        targetEntity,
        targetEntityId,
        beforeStateJson: beforeStateJson || null,
        afterStateJson: afterStateJson || null,
        reason: reason || null,
        ipAddress: ipAddress || '127.0.0.1',
      },
    });
  } catch (err) {
    console.error('Failed to write audit log in asset.service:', err);
  }
}

const nobleTiers = {
  1: 'baron',
  2: 'viscount',
  3: 'count',
  4: 'marquis',
  5: 'duke',
  6: 'king',
  7: 'emperor',
};

const roleFiles = {
  admin: { badge: 'roles/admin_badge.webp', frame: 'roles/admin_frame.webp' },
  agency: { badge: 'roles/agency_tag.webp', frame: 'roles/agency_frame.webp' },
  assistant: { badge: 'roles/assistant_tag.webp', frame: 'roles/assistant_frame.webp' },
  bd: { badge: 'roles/bd_tag.webp', frame: 'roles/bd_frame.webp' },
  boss: { badge: 'roles/boss_tag.webp', frame: 'roles/boss_frame.webp' },
  ceo: { badge: 'roles/ceo_tag.webp', frame: 'roles/ceo_frame.webp' },
  coins_seller: { badge: 'roles/coins_saller_tag.webp', frame: 'roles/coins_saller_frame.webp' },
  coin_seller: { badge: 'roles/coins_saller_tag.webp', frame: 'roles/coins_saller_frame.webp' },
  cs: { badge: 'roles/cs_badge.webp', frame: 'roles/cs_frame.webp' },
  game_master: { badge: 'roles/game_master_badge.webp', frame: 'roles/game_master_frame.webp' },
  host: { badge: 'roles/host_badge.webp', frame: 'roles/host_frame.webp' },
  lover: { badge: 'roles/lover_tag.webp', frame: 'roles/lover_frame.webp' },
  manager: { badge: 'roles/manager_tag.webp', frame: 'roles/manager_frame.webp' },
  merchant: { badge: 'roles/marchent_badge.webp', frame: 'roles/marchent_frame.webp' },
  marchent: { badge: 'roles/marchent_badge.webp', frame: 'roles/marchent_frame.webp' },
  official: { badge: 'roles/official_tag.webp', frame: 'roles/official_frame.webp' },
  super_admin: { badge: 'roles/super_admin_tag.webp', frame: 'roles/super_admin_frame.webp' },
  top_fan: { badge: 'roles/top_fan_badge.webp', frame: 'roles/top_fan_frame.webp' },
  vip: { badge: 'roles/ZP-216_official_badge.webp', frame: 'roles/official_frame.webp' },
  svip: { badge: 'svip/ZP-054_svip-1_badge.webp', frame: 'svip/svip1_frame.webp' },
  dragon: { badge: 'nobles/emperor_badge.webp', frame: 'nobles/emperor_frame.webp' },
  elite: { badge: 'nobles/king_badge.webp', frame: 'nobles/king_frame.webp' },
  guardian: { badge: 'nobles/duke_badge.webp', frame: 'nobles/duke_frame.webp' },
  singer: { badge: 'nobles/marquis_badge.webp', frame: 'nobles/marquis_frame.webp' },
  family: { badge: 'nobles/count_badge.webp', frame: 'nobles/count_frame.webp' },
};

const dbPathOverrides = {
  'assets/roles/ZP-220_top-fan_badge.webp': '/assets/roles/top_fan_badge.webp',
  'assets/roles/ZP-218_super-admin_badge.webp': '/assets/roles/super_admin_tag.webp',
  'assets/roles/ZP-215_official_badge.webp': '/assets/roles/ZP-216_official_badge.webp',
  'assets/roles/ZP-212_marchent_badge.webp': '/assets/roles/ZP-213_marchent_badge.webp',
  'assets/roles/ZP-210_manager_badge.webp': '/assets/roles/manager_tag.webp',
  'assets/roles/ZP-207_lover_badge.webp': '/assets/roles/ZP-208_lover_badge.webp',
  'assets/roles/ZP-204_host_badge.webp': '/assets/roles/ZP-205_host_badge.webp',
  'assets/roles/ZP-201_game-master_badge.webp': '/assets/roles/game_master_badge.webp',
  'assets/roles/ZP-198_cs_badge.webp': '/assets/roles/ZP-199_cs_badge.webp',
  'assets/roles/ZP-196_coins-saller_badge.webp': '/assets/roles/coins_saller_tag.webp',
  'assets/roles/ZP-193_ceo_badge.webp': '/assets/roles/ZP-194_ceo_badge.webp',
  'assets/roles/ZP-190_boss_badge.webp': '/assets/roles/ZP-191_boss_badge.webp',
  'assets/roles/ZP-187_bd_badge.webp': '/assets/roles/ZP-188_bd_badge.webp',
  'assets/roles/ZP-184_assistant_badge.webp': '/assets/roles/ZP-185_assistant_badge.webp',
  'assets/roles/ZP-181_agency_badge.webp': '/assets/roles/ZP-182_agency_badge.webp',
  'assets/roles/ZP-178_admin_badge.webp': '/assets/roles/ZP-179_admin_badge.webp',
  'assets/nobles/emperor_entrance.png': '/assets/nobles/emperor_entrance.webp',
  'assets/nobles/marquis_entrance.png': '/assets/nobles/marquis_entrance.webp',
  'assets/cars/suv_black.png': '/assets/images/gift_supercar.jpg',
  '/assets/cars/suv_black.png': '/assets/images/gift_supercar.jpg',
  'assets/frames/warrior.png': '/assets/nobles/king_frame.webp',
  '/assets/frames/warrior.png': '/assets/nobles/king_frame.webp',
  'assets/frames/spider.png': '/assets/nobles/emperor_frame.webp',
  'assets/nobles/tier-6-king_profilecard.webp': '/assets/nobles/king_card.webp',
  '/assets/nobles/tier-6-king_profilecard.webp': '/assets/nobles/king_card.webp',
  'assets/bubbles/unicorn.png': '/assets/animations/mystery_bubble.webp',
  '/assets/bubbles/unicorn.png': '/assets/animations/mystery_bubble.webp',
};

export function resolveAssetPath(url) {
  if (!url) return null;
  let clean = url.trim();

  for (const [key, val] of Object.entries(dbPathOverrides)) {
    if (clean === key || clean.endsWith(key)) {
      return val;
    }
  }

  if (clean.includes('assets.zeparty.app') || clean.includes('cdn.zeparty.app') || clean.includes('cdn.zeparty.io')) {
    if (clean.includes('cyber_neon')) {
      return '/assets/images/frame_neon.jpg';
    }
    if (clean.includes('car_gold')) {
      return '/assets/animations/mystery_entry.webp';
    }

    // Check roles
    const roleMatch = clean.match(/roles\/(badge|frame)_([a-z_]+)/);
    if (roleMatch) {
      const type = roleMatch[1];
      const role = roleMatch[2];
      if (roleFiles[role]) {
        return '/assets/' + (type === 'frame' ? roleFiles[role].frame : roleFiles[role].badge);
      }
    }

    // Check noble items
    const nobleMatch = clean.match(/(?:noble|nobles)\/(frame|tag|bag|entry)_noble_(\d+)/);
    if (nobleMatch) {
      const type = nobleMatch[1];
      const num = parseInt(nobleMatch[2], 10);
      const tier = nobleTiers[Math.min(num, 7)] || 'baron';

      if (type === 'frame') return '/assets/nobles/' + tier + '_frame.webp';
      if (type === 'tag' || type === 'bag') return '/assets/nobles/' + tier + '_badge.webp';
      if (type === 'entry') return num >= 6 ? '/assets/nobles/emperor_entrance.webp' : (num >= 5 ? '/assets/nobles/duke_entrance.webp' : '/assets/nobles/marquis_entrance.webp');
    }

    // Check mystery items
    const mysteryMatch = clean.match(/mystery\/(frame|entry|bubble|tag|bag)_mystery_(\d+)/);
    if (mysteryMatch) {
      const type = mysteryMatch[1];
      if (type === 'frame') return '/assets/animations/mystery_frame.webp';
      if (type === 'entry') return '/assets/animations/mystery_entry.webp';
      if (type === 'bubble') return '/assets/animations/mystery_bubble.webp';
      return '/assets/animations/mystery_badge.webp';
    }

    // Check svip items
    const svipMatch = clean.match(/svip\/(badge|frame|entry|bubble)_svip_(\d+)/);
    if (svipMatch) {
      const type = svipMatch[1];
      const num = svipMatch[2];
      if (type === 'badge') return '/assets/svip/svip' + num + '_badge.webp';
      if (type === 'frame') return '/assets/svip/svip' + num + '_frame.webp';
      if (type === 'entry') return '/assets/svip/svip' + num + '_entry.webp';
      if (type === 'bubble') return '/assets/svip/svip' + num + '_chat_bubble.webp';
    }

    const after = clean.split(/zeparty\.(?:app|io)\/(?:visual_assets\/)?/)[1];
    if (after) {
      if (after.startsWith('assets/')) return '/' + after;
      return '/assets/' + after;
    }
  }

  if (clean.startsWith('assets/')) {
    return '/' + clean;
  }

  return clean;
}

export function serializeAsset(asset) {
  if (!asset) return null;
  const rawType = asset.assetType || 'FRAME';
  const idLower = String(asset.id || '').toLowerCase();
  const nameLower = String(asset.name || '').toLowerCase();

  let category = 'Frame';
  if (rawType === 'VEHICLE') {
    category = 'Cars';
  } else if (rawType === 'FRAME') {
    category = 'Frame';
  } else if (rawType === 'CHAT_BUBBLE') {
    category = 'Bubble';
  } else if (rawType === 'ENTRY_EFFECT') {
    if (idLower.startsWith('bg_') || idLower.includes('background') || nameLower.includes('theme') || nameLower.includes('realm')) {
      category = 'Background';
    } else {
      category = 'Cars'; // Store's Cars category contains room-entry effects
    }
  } else if (rawType === 'BADGE') {
    if (idLower.startsWith('card_') || idLower.includes('card') || nameLower.includes('card')) {
      category = 'Special card';
    } else {
      category = 'Badges';
    }
  }

  const rawUrl = asset.thumbnailUrl || asset.staticFileUrl || asset.animationFileUrl || '';
  const imageUrl = resolveAssetPath(rawUrl) || rawUrl;
  const staticUrl = resolveAssetPath(asset.staticFileUrl);
  const animationUrl = resolveAssetPath(asset.animationFileUrl);
  const videoUrl = resolveAssetPath(asset.videoFileUrl) || animationUrl;
  const assetUrl = animationUrl || staticUrl || videoUrl || imageUrl;

  const isSpecial = isRestrictedSpecialAsset(asset);
  const isPublic = isPublicStoreItem(asset);

  const tags = rawType === 'VEHICLE' || category === 'Cars'
    ? ['CARS', 'ENTRY_EFFECT']
    : (category === 'Special card' ? ['SPECIAL_CARD', 'BADGE'] : [category.toUpperCase()]);

  return {
    ...asset,
    id: asset.id,
    assetId: asset.id,
    name: asset.name,
    category,
    categoryId: category,
    categoryName: category,
    assetType: rawType,
    imageUrl,
    iconUrl: imageUrl,
    thumbnailUrl: imageUrl,
    staticUrl,
    animationUrl,
    videoUrl,
    assetUrl,
    price: asset.priceCoins ? asset.priceCoins.toString() : '0',
    durationDays: asset.validDays || 30,
    validDays: asset.validDays || 30,
    priceCoins: asset.priceCoins ? asset.priceCoins.toString() : '0',
    isVipExclusive: Boolean(asset.isVipExclusive),
    minVipLevelRequired: asset.minVipLevelRequired || 0,
    roomAvailability: asset.roomAvailability || 'BOTH',
    isSpecial,
    isPublic,
    classification: isSpecial ? 'SPECIAL' : 'PUBLIC',
    isActive: Boolean(asset.isActive),
    tags,
  };
}

export function serializeUserAsset(userAsset) {
  if (!userAsset) return null;
  const isExpired = userAsset.expiresAt ? new Date(userAsset.expiresAt) <= new Date() : false;
  return {
    id: userAsset.id,
    userId: userAsset.userId,
    assetId: userAsset.assetId,
    isEquipped: Boolean(userAsset.isEquipped),
    expiresAt: userAsset.expiresAt ? (userAsset.expiresAt instanceof Date ? userAsset.expiresAt.toISOString() : new Date(userAsset.expiresAt).toISOString()) : null,
    isExpired,
    asset: userAsset.asset ? serializeAsset(userAsset.asset) : null,
    createdAt: userAsset.createdAt ? (userAsset.createdAt instanceof Date ? userAsset.createdAt.toISOString() : new Date(userAsset.createdAt).toISOString()) : null,
    updatedAt: userAsset.updatedAt ? (userAsset.updatedAt instanceof Date ? userAsset.updatedAt.toISOString() : new Date(userAsset.updatedAt).toISOString()) : null,
  };
}

export async function createAsset(data, { adminId, adminName, ipAddress } = {}, db = prisma) {
  const asset = await assetRepository.createAsset(data, db);

  await logAudit({
    adminId,
    adminName,
    action: 'ASSET_CREATED',
    targetEntity: 'Asset',
    targetEntityId: asset.id,
    afterStateJson: serializeAsset(asset),
    ipAddress,
  }, db);

  return serializeAsset(asset);
}

export async function updateAsset(id, data, { adminId, adminName, ipAddress } = {}, db = prisma) {
  const existing = await assetRepository.findAssetById(id, db);
  if (!existing) {
    const error = new Error('Asset not found');
    error.statusCode = 404;
    error.code = 'ASSET_NOT_FOUND';
    throw error;
  }

  const updated = await assetRepository.updateAsset(id, data, db);

  await logAudit({
    adminId,
    adminName,
    action: 'ASSET_UPDATED',
    targetEntity: 'Asset',
    targetEntityId: id,
    beforeStateJson: serializeAsset(existing),
    afterStateJson: serializeAsset(updated),
    ipAddress,
  }, db);

  return serializeAsset(updated);
}

export async function deactivateAsset(id, { adminId, adminName, ipAddress } = {}, db = prisma) {
  const existing = await assetRepository.findAssetById(id, db);
  if (!existing) {
    const error = new Error('Asset not found');
    error.statusCode = 404;
    error.code = 'ASSET_NOT_FOUND';
    throw error;
  }

  const updated = await assetRepository.updateAsset(id, { isActive: false }, db);

  await logAudit({
    adminId,
    adminName,
    action: 'ASSET_DEACTIVATED',
    targetEntity: 'Asset',
    targetEntityId: id,
    beforeStateJson: serializeAsset(existing),
    afterStateJson: serializeAsset(updated),
    ipAddress,
  }, db);

  return serializeAsset(updated);
}

export async function getAssetDetails(id, db = prisma) {
  const asset = await assetRepository.findAssetById(id, db);
  if (!asset) {
    const error = new Error('Asset not found');
    error.statusCode = 404;
    error.code = 'ASSET_NOT_FOUND';
    throw error;
  }
  return serializeAsset(asset);
}

export const ALL_AVAILABLE_FRAMES = [
  { key: 'host', name: 'Official Host Frame', asset: 'assets/roles/host_frame.webp' },
  { key: 'king', name: 'King Supreme Frame', asset: 'assets/nobles/king_frame.webp' },
  { key: 'emperor', name: 'Emperor Celestial Frame', asset: 'assets/nobles/emperor_frame.webp' },
  { key: 'duke', name: 'Duke Royal Frame', asset: 'assets/nobles/duke_frame.webp' },
  { key: 'marquis', name: 'Marquis Royal Frame', asset: 'assets/nobles/marquis_frame.webp' },
  { key: 'count', name: 'Count Royal Frame', asset: 'assets/nobles/count_frame.webp' },
  { key: 'viscount', name: 'Viscount Royal Frame', asset: 'assets/nobles/viscount_frame.webp' },
  { key: 'baron', name: 'Baron Royal Frame', asset: 'assets/nobles/baron_frame.webp' },
  { key: 'admin', name: 'Super Admin Frame', asset: 'assets/roles/admin_frame.webp' },
  { key: 'agency', name: 'Agency Boss Frame', asset: 'assets/roles/agency_frame.webp' },
  { key: 'cs', name: 'Customer Support Frame', asset: 'assets/roles/cs_frame.webp' },
  { key: 'ceo', name: 'Executive CEO Frame', asset: 'assets/roles/ceo_frame.webp' },
  { key: 'bd', name: 'Business Development Frame', asset: 'assets/roles/bd_frame.webp' },
  { key: 'game_master', name: 'Game Master Frame', asset: 'assets/roles/game_master_frame.webp' },
  { key: 'coins_seller', name: 'Coins Seller Frame', asset: 'assets/roles/coins_seller_frame.webp' },
  { key: 'merchant', name: 'Official Merchant Frame', asset: 'assets/roles/merchant_frame.webp' },
  { key: 'lover', name: 'Romantic Lover Frame', asset: 'assets/roles/lover_frame.webp' },
  { key: 'manager', name: 'Operations Manager Frame', asset: 'assets/roles/manager_frame.webp' },
  { key: 'official', name: 'ZeParty Official Frame', asset: 'assets/roles/official_frame.webp' },
  { key: 'top_fan', name: 'Top Fan VIP Frame', asset: 'assets/roles/top_fan_frame.webp' },
  { key: 'assistant', name: 'Official Assistant Frame', asset: 'assets/roles/assistant_frame.webp' },
  { key: 'boss', name: 'Big Boss Frame', asset: 'assets/roles/boss_frame.webp' },
  { key: 'svip15', name: 'SVIP 15 Infinite Divinity Frame', asset: 'assets/svip/svip15_frame.webp' },
  { key: 'svip14', name: 'SVIP 14 Supreme Deity Frame', asset: 'assets/svip/svip14_frame.webp' },
  { key: 'svip13', name: 'SVIP 13 Immortal Frame', asset: 'assets/svip/svip13_frame.webp' },
  { key: 'svip12', name: 'SVIP 12 Monarch Frame', asset: 'assets/svip/svip12_frame.webp' },
  { key: 'svip11', name: 'SVIP 11 Sovereign Frame', asset: 'assets/svip/svip11_frame.webp' },
  { key: 'svip10', name: 'SVIP 10 Dragon Frame', asset: 'assets/svip/svip10_frame.webp' },
  { key: 'svip9', name: 'SVIP 9 Phoenix Frame', asset: 'assets/svip/svip9_frame.webp' },
  { key: 'svip8', name: 'SVIP 8 Celestial Frame', asset: 'assets/svip/svip8_frame.webp' },
  { key: 'svip7', name: 'SVIP 7 Aurora Frame', asset: 'assets/svip/svip7_frame.webp' },
  { key: 'svip6', name: 'SVIP 6 Obsidian Frame', asset: 'assets/svip/svip6_frame.webp' },
  { key: 'mystery', name: 'Mystery Astral Frame', asset: 'assets/animations/mystery_frame.webp' },
];

export async function getUserBackpack(userId, db = prisma) {
  const user = await db.user.findUnique({
    where: { id: userId },
    include: {
      profile: true,
    },
  });

  const userAssets = await userAssetRepository.findUserAssets(userId, db);
  const serialized = userAssets.map(serializeUserAsset);

  if (user) {
    const isHost = user.userType === 'HOST';
    const isAgency = user.userType === 'AGENCY';
    const isAdmin = user.userType === 'ADMIN';
    const nobleTitle = user.profile?.nobleRank?.toLowerCase().trim();

    let defaultFrameKey = '';
    if (isHost) defaultFrameKey = 'host';
    else if (nobleTitle) defaultFrameKey = nobleTitle;
    else if (isAdmin) defaultFrameKey = 'admin';
    else if (isAgency) defaultFrameKey = 'agency';

    // Add eligible role/noble frames if user qualifies
    for (const f of ALL_AVAILABLE_FRAMES) {
      const isQualified = (defaultFrameKey === f.key);
      const alreadyExists = serialized.some(
        (s) => s.asset?.imageUrl === f.asset || s.asset?.name === f.name || s.assetId === `assigned-asset-${f.key}-frame`
      );

      if (isQualified && !alreadyExists) {
        const frameAsset = {
          id: `assigned-frame-${f.key}-${user.id}`,
          userId: user.id,
          assetId: `assigned-asset-${f.key}-frame`,
          isEquipped: !serialized.some((s) => s.isEquipped && s.asset?.assetType === 'FRAME'),
          expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(),
          isExpired: false,
          asset: {
            id: `assigned-asset-${f.key}-frame`,
            name: f.name,
            categoryId: 'Frame',
            assetType: 'FRAME',
            imageUrl: f.asset,
            iconUrl: f.asset,
            thumbnailUrl: f.asset,
            priceCoins: '0',
            validDays: 365,
            isActive: true,
          },
        };

        if (frameAsset.isEquipped) {
          serialized.unshift(frameAsset);
        } else {
          serialized.push(frameAsset);
        }
      }
    }
  }

  return serialized;
}

export async function equipAsset(userId, userAssetId, { ipAddress } = {}, db = prisma) {
  // Handle assigned frames
  if (userAssetId && userAssetId.startsWith('assigned-frame-')) {
    let matchedFrame = ALL_AVAILABLE_FRAMES.find((f) => userAssetId.startsWith(`assigned-frame-${f.key}-`));
    if (!matchedFrame) {
      matchedFrame = ALL_AVAILABLE_FRAMES[0];
    }

    return {
      id: userAssetId,
      userId,
      assetId: `assigned-asset-${matchedFrame.key}-frame`,
      isEquipped: true,
      expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(),
      isExpired: false,
      asset: {
        id: `assigned-asset-${matchedFrame.key}-frame`,
        name: matchedFrame.name,
        categoryId: 'Frame',
        assetType: 'FRAME',
        imageUrl: matchedFrame.asset,
        iconUrl: matchedFrame.asset,
        thumbnailUrl: matchedFrame.asset,
        priceCoins: '0',
        validDays: 365,
        isActive: true,
      },
    };
  }

  let userAsset = await userAssetRepository.findUserAssetById(userAssetId, db);
  if (!userAsset) {
    // Check if the parameter was passed as an assetId instead of userAssetId
    userAsset = await userAssetRepository.findActiveUserAssetByAssetId(userId, userAssetId, db);
  }

  if (!userAsset) {
    const error = new Error('User asset not found in your backpack');
    error.statusCode = 404;
    error.code = 'USER_ASSET_NOT_FOUND';
    throw error;
  }

  // Enforce IDOR protection
  if (userAsset.userId !== userId) {
    const error = new Error('You are not authorized to equip this asset');
    error.statusCode = 403;
    error.code = 'FORBIDDEN_ASSET_ACCESS';
    throw error;
  }

  // Check expiration
  if (new Date(userAsset.expiresAt) <= new Date()) {
    const error = new Error('Cannot equip an expired asset');
    error.statusCode = 400;
    error.code = 'ASSET_EXPIRED';
    throw error;
  }

  const assetType = userAsset.asset?.assetType || 'FRAME';

  // Execute in transaction to ensure single-equipped exclusivity per assetType
  const updatedUserAsset = await db.$transaction(async (tx) => {
    if (assetType) {
      await userAssetRepository.unequipAssetsByType(userId, assetType, tx);
      if (assetType === 'VEHICLE') {
        await userAssetRepository.unequipAssetsByType(userId, 'ENTRY_EFFECT', tx);
      } else if (assetType === 'ENTRY_EFFECT') {
        await userAssetRepository.unequipAssetsByType(userId, 'VEHICLE', tx);
      }
    }
    return await userAssetRepository.updateUserAsset(
      userAsset.id,
      { isEquipped: true },
      tx
    );
  });

  await logAudit({
    adminId: null,
    adminName: 'User Action',
    action: 'USER_ASSET_EQUIPPED',
    targetEntity: 'UserAsset',
    targetEntityId: userAsset.id,
    afterStateJson: {
      userId,
      userAssetId: userAsset.id,
      assetId: userAsset.assetId,
      assetName: userAsset.asset?.name,
      assetType,
    },
    ipAddress,
  }, db);

  // Invalidate user profile cache in Redis
  try {
    if (redisProxy.isOpen && userId) {
      await redisProxy.del(`user:profile:${userId}`);
    }
  } catch (_) {}

  // Publish realtime outfit update
  try {
    if (userId) {
      const frameUrl = userAsset.asset?.thumbnailUrl || userAsset.asset?.staticFileUrl || userAsset.asset?.animationFileUrl || userAsset.asset?.name || null;
      emitToUser(userId, 'user:outfit_updated', {
        userId,
        assetType,
        assetId: userAsset.assetId,
        equippedFrame: assetType === 'FRAME' ? frameUrl : undefined,
        avatarFrame: assetType === 'FRAME' ? frameUrl : undefined,
        action: 'EQUIP',
        timestamp: new Date().toISOString(),
      });
    }
  } catch (_) {}

  return serializeUserAsset(updatedUserAsset);
}

export async function unequipAsset(userId, userAssetId, { ipAddress } = {}, db = prisma) {
  let userAsset = await userAssetRepository.findUserAssetById(userAssetId, db);
  if (!userAsset) {
    userAsset = await userAssetRepository.findActiveUserAssetByAssetId(userId, userAssetId, db);
  }

  if (!userAsset) {
    const error = new Error('User asset not found in your backpack');
    error.statusCode = 404;
    error.code = 'USER_ASSET_NOT_FOUND';
    throw error;
  }

  // Enforce IDOR protection
  if (userAsset.userId !== userId) {
    const error = new Error('You are not authorized to unequip this asset');
    error.statusCode = 403;
    error.code = 'FORBIDDEN_ASSET_ACCESS';
    throw error;
  }

  const updated = await userAssetRepository.updateUserAsset(
    userAsset.id,
    { isEquipped: false },
    db
  );

  const assetType = userAsset.asset?.assetType || 'FRAME';

  await logAudit({
    adminId: null,
    adminName: 'User Action',
    action: 'USER_ASSET_UNEQUIPPED',
    targetEntity: 'UserAsset',
    targetEntityId: userAsset.id,
    afterStateJson: {
      userId,
      userAssetId: userAsset.id,
      assetId: userAsset.assetId,
      assetName: userAsset.asset?.name,
      assetType,
    },
    ipAddress,
  }, db);

  // Invalidate user profile cache in Redis
  try {
    if (redisProxy.isOpen && userId) {
      await redisProxy.del(`user:profile:${userId}`);
    }
  } catch (_) {}

  // Publish realtime outfit unequip update
  try {
    if (userId) {
      emitToUser(userId, 'user:outfit_updated', {
        userId,
        assetType,
        assetId: userAsset.assetId,
        equippedFrame: assetType === 'FRAME' ? null : undefined,
        avatarFrame: assetType === 'FRAME' ? null : undefined,
        action: 'UNEQUIP',
        timestamp: new Date().toISOString(),
      });
    }
  } catch (_) {}

  return serializeUserAsset(updated);
}

export default {
  serializeAsset,
  serializeUserAsset,
  createAsset,
  updateAsset,
  deactivateAsset,
  getAssetDetails,
  getUserBackpack,
  equipAsset,
  unequipAsset,
};

