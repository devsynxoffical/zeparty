import prisma from '../config/database.js';
import assetRepository from '../repositories/asset.repository.js';
import userAssetRepository from '../repositories/userAsset.repository.js';
import redisProxy from '../config/redis.js';
import { emitToUser, broadcastGlobal, syncUserSocketFrame } from '../socket/socket.emitter.js';
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

/**
 * Noble rank styling definition:
 * Mercurius/Duke: Red (#EF4444)
 * King: Golden (#FFD700)
 * Imperial/Emperor: Gradient / Sky Blue & Golden (#38BDF8 / #F59E0B)
 */
export function getNobleStyle(nobleRank) {
  if (!nobleRank) return null;
  const rank = String(nobleRank).toUpperCase().trim();
  switch (rank) {
    case 'MERCURIUS':
    case 'MARQUIS':
      return {
        rank,
        color: '#EF4444',
        textColor: '#EF4444',
        nameColor: '#EF4444',
        styleType: 'RED',
        gradient: null,
      };
    case 'VISCOUNT':
      return {
        rank,
        color: '#3B82F6',
        textColor: '#3B82F6',
        nameColor: '#3B82F6',
        styleType: 'BLUE',
        gradient: null,
      };
    case 'DUKE':
      return {
        rank,
        color: '#AB47BC',
        textColor: '#AB47BC',
        nameColor: '#AB47BC',
        styleType: 'PURPLE',
        gradient: null,
      };
    case 'COUNT':
    case 'EARL':
      return {
        rank,
        color: '#E24A5A',
        textColor: '#E24A5A',
        nameColor: '#E24A5A',
        styleType: 'CORAL',
        gradient: null,
      };
    case 'BARON':
    case 'KNIGHT':
      return {
        rank,
        color: '#CD7F32',
        textColor: '#CD7F32',
        nameColor: '#CD7F32',
        styleType: 'BRONZE',
        gradient: null,
      };
    case 'KING':
      return {
        rank,
        color: '#FFD700',
        textColor: '#FFD700',
        nameColor: '#FFD700',
        styleType: 'GOLDEN',
        gradient: null,
      };
    case 'IMPERIAL':
    case 'EMPEROR':
      return {
        rank,
        color: '#38BDF8',
        textColor: '#38BDF8',
        nameColor: '#38BDF8',
        accentColor: '#F59E0B',
        styleType: 'GRADIENT',
        gradient: ['#38BDF8', '#F59E0B'],
      };
    default:
      return {
        rank,
        color: '#E2E8F0',
        textColor: '#E2E8F0',
        nameColor: '#E2E8F0',
        styleType: 'STANDARD',
        gradient: null,
      };
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
  admin: { tag: 'roles/super_admin_tag.webp', badge: 'roles/ZP-179_admin_badge.webp', frame: 'roles/admin_frame.webp' },
  agency: { tag: 'roles/agency_tag.webp', badge: 'roles/ZP-182_agency_badge.webp', frame: 'roles/agency_frame.webp' },
  assistant: { tag: 'roles/assistant_tag.webp', badge: 'roles/ZP-185_assistant_badge.webp', frame: 'roles/assistant_frame.webp' },
  bd: { tag: 'roles/bd_tag.webp', badge: 'roles/ZP-188_bd_badge.webp', frame: 'roles/bd_frame.webp' },
  boss: { tag: 'roles/boss_tag.webp', badge: 'roles/ZP-191_boss_badge.webp', frame: 'roles/boss_frame.webp' },
  ceo: { tag: 'roles/ceo_tag.webp', badge: 'roles/ZP-194_ceo_badge.webp', frame: 'roles/ceo_frame.webp' },
  coins_seller: { tag: 'roles/coins_saller_tag.webp', badge: 'roles/ZP-196_coins-saller_badge.webp', frame: 'roles/coins_saller_frame.webp' },
  coin_seller: { tag: 'roles/coins_saller_tag.webp', badge: 'roles/ZP-196_coins-saller_badge.webp', frame: 'roles/coins_saller_frame.webp' },
  cs: { tag: 'roles/official_tag.webp', badge: 'roles/ZP-199_cs_badge.webp', frame: 'roles/cs_frame.webp' },
  game_master: { tag: 'roles/official_tag.webp', badge: 'roles/game_master_badge.webp', frame: 'roles/game_master_frame.webp' },
  host: { tag: 'roles/host_badge.webp', badge: 'roles/ZP-205_host_badge.webp', frame: 'roles/host_frame.webp' },
  lover: { tag: 'roles/lover_tag.webp', badge: 'roles/ZP-208_lover_badge.webp', frame: 'roles/lover_frame.webp' },
  manager: { tag: 'roles/manager_tag.webp', badge: 'roles/manager_tag.webp', frame: 'roles/manager_frame.webp' },
  merchant: { tag: 'roles/official_tag.webp', badge: 'roles/ZP-213_marchent_badge.webp', frame: 'roles/marchent_frame.webp' },
  marchent: { tag: 'roles/official_tag.webp', badge: 'roles/ZP-213_marchent_badge.webp', frame: 'roles/marchent_frame.webp' },
  official: { tag: 'roles/official_tag.webp', badge: 'roles/ZP-216_official_badge.webp', frame: 'roles/official_frame.webp' },
  super_admin: { tag: 'roles/super_admin_tag.webp', badge: 'roles/ZP-179_admin_badge.webp', frame: 'roles/super_admin_frame.webp' },
  top_fan: { tag: 'roles/official_tag.webp', badge: 'roles/top_fan_badge.webp', frame: 'roles/top_fan_frame.webp' },
  vip: { tag: 'roles/official_tag.webp', badge: 'roles/ZP-216_official_badge.webp', frame: 'roles/official_frame.webp' },
  svip: { tag: 'svip/svip1_tag.png', badge: 'svip/ZP-054_svip-1_badge.webp', frame: 'svip/svip6_frame.webp' },
  dragon: { tag: 'nobles/emperor_badge.webp', badge: 'nobles/emperor_badge.webp', frame: 'nobles/emperor_frame.webp' },
  elite: { tag: 'nobles/king_badge.webp', badge: 'nobles/king_badge.webp', frame: 'nobles/king_frame.webp' },
  guardian: { tag: 'nobles/duke_badge.webp', badge: 'nobles/duke_badge.webp', frame: 'nobles/duke_frame.webp' },
  singer: { tag: 'nobles/marquis_badge.webp', badge: 'nobles/marquis_badge.webp', frame: 'nobles/marquis_frame.webp' },
  family: { tag: 'nobles/count_badge.webp', badge: 'nobles/count_badge.webp', frame: 'nobles/count_frame.webp' },
};

const dbPathOverrides = {
  'assets/nobles/ZP-034_tier-6-king_badge.webp': '/assets/nobles/king_badge.webp',
  'assets/nobles/ZP-037_tier-6-king_badge.webp': '/assets/nobles/king_badge.webp',
  'ZP-034_tier-6-king_badge.webp': '/assets/nobles/king_badge.webp',
  'ZP-037_tier-6-king_badge.webp': '/assets/nobles/king_badge.webp',
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
  '/assets/frames/spider.png': '/assets/nobles/emperor_frame.webp',
  'assets/bubbles/unicorn.png': '/assets/animations/mystery_bubble.webp',
  '/assets/bubbles/unicorn.png': '/assets/animations/mystery_bubble.webp',
};

const idAssetOverrides = {
  car_supercar: '/assets/images/gift_supercar.jpg',
  noble_frame_emperor: '/assets/nobles/emperor_frame.webp',
  noble_badge_emperor: '/assets/nobles/emperor_badge.webp',
  noble_card_emperor: '/assets/nobles/tier-7-emperor_profilecard.webp',
  noble_frame_king: '/assets/nobles/king_frame.webp',
  noble_badge_king: '/assets/nobles/king_badge.webp',
  noble_card_king: '/assets/nobles/king_card.webp',
  noble_mic_king: '/assets/nobles/king_mic.webp',
  noble_colorname_king: '/assets/nobles/tier-6-king_colorname.webp',
  noble_worldnotif_king: '/assets/nobles/tier-6-king_worldnotif.webp',
  noble_frame_duke: '/assets/nobles/duke_frame.webp',
  noble_badge_duke: '/assets/nobles/duke_badge.webp',
  noble_card_duke: '/assets/nobles/duke_card.webp',
  noble_frame_marquis: '/assets/nobles/marquis_frame.webp',
  noble_badge_marquis: '/assets/nobles/marquis_badge.webp',
  noble_card_marquis: '/assets/nobles/marquis_card.webp',
  noble_frame_count: '/assets/nobles/count_frame.webp',
  noble_badge_count: '/assets/nobles/count_badge.webp',
  noble_card_count: '/assets/nobles/count_card.webp',
  noble_frame_viscount: '/assets/nobles/viscount_frame.webp',
  noble_badge_viscount: '/assets/nobles/viscount_badge.webp',
  noble_card_viscount: '/assets/nobles/viscount_card.webp',
  noble_frame_baron: '/assets/nobles/baron_frame.webp',
  noble_badge_baron: '/assets/nobles/baron_badge.webp',
  noble_card_baron: '/assets/nobles/baron_card.webp',
  test_cosmetic_frame_cyber: '/assets/images/frame_neon.jpg',
  test_cosmetic_frame_cyb: '/assets/images/frame_neon.jpg',
  'ast-car-01': '/assets/animations/mystery_entry.webp',
  'ast-car-02': '/assets/images/gift_supercar.jpg',
  'ast-frame-01': '/assets/nobles/king_frame.webp',
  'ast-frame-02': '/assets/nobles/emperor_frame.webp',
  'ast-bub-01': '/assets/animations/mystery_bubble.webp',
};

export function resolveAssetPath(url) {
  if (!url) return null;
  let clean = url.trim();

  if (idAssetOverrides[clean]) {
    return idAssetOverrides[clean];
  }

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
    const roleMatch = clean.match(/roles\/(badge|frame|tag)_([a-z_]+)/);
    if (roleMatch) {
      const type = roleMatch[1];
      const role = roleMatch[2];
      if (roleFiles[role]) {
        if (type === 'frame') return '/assets/' + roleFiles[role].frame;
        if (type === 'tag') return '/assets/' + (roleFiles[role].tag || roleFiles[role].badge);
        return '/assets/' + (roleFiles[role].badge || roleFiles[role].tag);
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

  const rawUrl = asset.thumbnailUrl || asset.staticFileUrl || asset.animationFileUrl || asset.id || '';
  const imageUrl = resolveAssetPath(rawUrl) || resolveAssetPath(asset.id) || (rawUrl.startsWith('assets/') ? '/' + rawUrl : rawUrl);
  const staticUrl = resolveAssetPath(asset.staticFileUrl) || imageUrl;
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
  { key: 'svip16', name: 'SVIP 16 Eternal Frame', asset: 'assets/svip/svip16_frame.webp' },
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

    const svipLvl = Number(user.profile?.svipLevel || 0);

    let isFrameUnequipped = false;
    try {
      if (redisProxy.isOpen && user.id) {
        const unequipped = await redisProxy.get(`user:unequipped:FRAME:${user.id}`);
        if (unequipped === '1') isFrameUnequipped = true;
      }
    } catch (_) {}

    // Add eligible role/noble/SVIP frames if user qualifies (SVIP frames require SVIP 6+)
    for (const f of ALL_AVAILABLE_FRAMES) {
      const isRoleQualified = (defaultFrameKey === f.key);
      const isSvipQualified = svipLvl >= 6 && (
        f.key === `svip${svipLvl}` ||
        (f.key.startsWith('svip') && Number(f.key.replace('svip', '')) <= svipLvl)
      );
      const isQualified = isRoleQualified || isSvipQualified;

      const alreadyExists = serialized.some(
        (s) => s.asset?.imageUrl === f.asset || s.asset?.name === f.name || s.assetId === `assigned-asset-${f.key}-frame`
      );

      if (isQualified && !alreadyExists) {
        const frameAsset = {
          id: `assigned-frame-${f.key}-${user.id}`,
          userId: user.id,
          assetId: `assigned-asset-${f.key}-frame`,
          isEquipped: false,
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

    // Add eligible SVIP Chat Bubbles, Vehicles, and Badges
    if (svipLvl > 0) {
      const svipBubbleAsset = `assets/svip/svip${svipLvl}_chat_bubble.webp`;
      const hasBubble = serialized.some((s) => s.asset?.imageUrl === svipBubbleAsset || s.assetId === `assigned-asset-svip${svipLvl}-bubble`);
      if (!hasBubble) {
        serialized.push({
          id: `assigned-bubble-svip${svipLvl}-${user.id}`,
          userId: user.id,
          assetId: `assigned-asset-svip${svipLvl}-bubble`,
          isEquipped: false,
          expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(),
          isExpired: false,
          asset: {
            id: `assigned-asset-svip${svipLvl}-bubble`,
            name: `SVIP ${svipLvl} Chat Bubble`,
            categoryId: 'Bubbles',
            assetType: 'BUBBLE',
            imageUrl: svipBubbleAsset,
            iconUrl: svipBubbleAsset,
            thumbnailUrl: svipBubbleAsset,
            priceCoins: '0',
            validDays: 365,
            isActive: true,
          },
        });
      }

      // Add eligible SVIP Vehicles (SVIP 1-16)
      if (svipLvl >= 1) {
        const svipVehicleAsset = `assets/svip/svip${svipLvl}_entry.webp`;
        const hasVehicle = serialized.some((s) => s.asset?.imageUrl === svipVehicleAsset || s.assetId === `assigned-asset-svip${svipLvl}-vehicle`);
        if (!hasVehicle) {
          serialized.push({
            id: `assigned-vehicle-svip${svipLvl}-${user.id}`,
            userId: user.id,
            assetId: `assigned-asset-svip${svipLvl}-vehicle`,
            isEquipped: false,
            expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(),
            isExpired: false,
            asset: {
              id: `assigned-asset-svip${svipLvl}-vehicle`,
              name: `SVIP ${svipLvl} VIP Vehicle`,
              categoryId: 'Cars',
              assetType: 'VEHICLE',
              imageUrl: svipVehicleAsset,
              iconUrl: svipVehicleAsset,
              thumbnailUrl: svipVehicleAsset,
              priceCoins: '0',
              validDays: 365,
              isActive: true,
            },
          });
        }
      }

      // Add eligible SVIP Homepage Skins (Phase 1)
      const svipSkinAsset = `assets/svip/svip${svipLvl}_card.webp`;
      const hasSkin = serialized.some((s) => s.asset?.imageUrl === svipSkinAsset || s.assetId === `assigned-asset-svip${svipLvl}-skin`);
      if (!hasSkin) {
        const isSkinEquipped = user.profile?.equippedSkinId !== 'none' && user.profile?.profileSkinUrl === svipSkinAsset;
        serialized.push({
          id: `assigned-skin-svip${svipLvl}-${user.id}`,
          userId: user.id,
          assetId: `assigned-asset-svip${svipLvl}-skin`,
          isEquipped: isSkinEquipped,
          expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(),
          isExpired: false,
          asset: {
            id: `assigned-asset-svip${svipLvl}-skin`,
            name: `SVIP ${svipLvl} Homepage Skin`,
            categoryId: 'Themes',
            assetType: 'HOMEPAGE_SKIN',
            imageUrl: svipSkinAsset,
            iconUrl: svipSkinAsset,
            thumbnailUrl: svipSkinAsset,
            priceCoins: '0',
            validDays: 365,
            isActive: true,
          },
        });
      }

      // Add eligible SVIP Profile Cards (Phase 2)
      const svipCardAsset = `assets/svip/svip${svipLvl}_profilecard.webp`;
      const hasCard = serialized.some((s) => s.asset?.imageUrl === svipCardAsset || s.assetId === `assigned-asset-svip${svipLvl}-card`);
      if (!hasCard) {
        const isCardEquipped = user.profile?.equippedProfileCardId !== 'none' && user.profile?.profileCardUrl === svipCardAsset;
        serialized.push({
          id: `assigned-card-svip${svipLvl}-${user.id}`,
          userId: user.id,
          assetId: `assigned-asset-svip${svipLvl}-card`,
          isEquipped: isCardEquipped,
          expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(),
          isExpired: false,
          asset: {
            id: `assigned-asset-svip${svipLvl}-card`,
            name: `SVIP ${svipLvl} Profile Card`,
            categoryId: 'Cards',
            assetType: 'PROFILE_CARD',
            imageUrl: svipCardAsset,
            iconUrl: svipCardAsset,
            thumbnailUrl: svipCardAsset,
            priceCoins: '0',
            validDays: 365,
            isActive: true,
          },
        });
      }

      const svipTagAsset = `assets/svip/svip${svipLvl}_tag.png`;
      const hasTag = serialized.some((s) => s.asset?.imageUrl === svipTagAsset || s.assetId === `assigned-asset-svip${svipLvl}-badge`);
      if (!hasTag) {
        serialized.push({
          id: `assigned-badge-svip${svipLvl}-${user.id}`,
          userId: user.id,
          assetId: `assigned-asset-svip${svipLvl}-badge`,
          isEquipped: false,
          expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(),
          isExpired: false,
          asset: {
            id: `assigned-asset-svip${svipLvl}-badge`,
            name: `SVIP ${svipLvl} VIP Tag`,
            categoryId: 'Badges',
            assetType: 'BADGE',
            imageUrl: svipTagAsset,
            iconUrl: svipTagAsset,
            thumbnailUrl: svipTagAsset,
            priceCoins: '0',
            validDays: 365,
            isActive: true,
          },
        });
      }
    }
  }

  return serialized;
}

export async function equipAsset(userId, userAssetId, { ipAddress } = {}, db = prisma) {
  // Handle assigned frames, bubbles, vehicles, badges
  if (userAssetId && userAssetId.startsWith('assigned-')) {
    let matchedItem = null;
    let itemType = 'FRAME';
    let itemCategory = 'Frame';

    if (userAssetId.includes('-bubble') || userAssetId.startsWith('assigned-bubble-')) {
      itemType = 'BUBBLE';
      itemCategory = 'Bubbles';
      const svipMatch = userAssetId.match(/svip(\d+)/i);
      const lvl = svipMatch ? svipMatch[1] : '6';
      matchedItem = { key: `svip${lvl}_bubble`, name: `SVIP ${lvl} Chat Bubble`, asset: `assets/svip/svip${lvl}_chat_bubble.webp` };
    } else if (userAssetId.includes('-vehicle') || userAssetId.startsWith('assigned-vehicle-')) {
      itemType = 'VEHICLE';
      itemCategory = 'Cars';
      const svipMatch = userAssetId.match(/svip(\d+)/i);
      const lvl = svipMatch ? svipMatch[1] : '6';
      matchedItem = { key: `svip${lvl}_vehicle`, name: `SVIP ${lvl} VIP Vehicle`, asset: `assets/svip/svip${lvl}_entry.webp` };
    } else if (userAssetId.includes('-badge') || userAssetId.startsWith('assigned-badge-')) {
      itemType = 'BADGE';
      itemCategory = 'Badges';
      const svipMatch = userAssetId.match(/svip(\d+)/i);
      const lvl = svipMatch ? svipMatch[1] : '6';
      matchedItem = { key: `svip${lvl}_tag`, name: `SVIP ${lvl} VIP Tag`, asset: `assets/svip/svip${lvl}_tag.png` };
    } else if (userAssetId.includes('-skin') || userAssetId.startsWith('assigned-skin-')) {
      itemType = 'HOMEPAGE_SKIN';
      itemCategory = 'Themes';
      const svipMatch = userAssetId.match(/svip(\d+)/i);
      const lvl = svipMatch ? svipMatch[1] : (userAssetId.match(/-skin-(\d+)/) ? userAssetId.match(/-skin-(\d+)/)[1] : '6');
      matchedItem = { key: `svip${lvl}_skin`, name: `SVIP ${lvl} Homepage Skin`, asset: `assets/svip/svip${lvl}_card.webp` };

      // Authoritative SVIP Entitlement Verification (ZP-BUG-012)
      const userRecord = await db.user.findUnique({
        where: { id: userId },
        include: { profile: true },
      });
      if (!userRecord) {
        const error = new Error('User not found');
        error.statusCode = 404;
        error.code = 'USER_NOT_FOUND';
        throw error;
      }
      const reqLvl = parseInt(lvl, 10);
      if (isNaN(reqLvl) || reqLvl < 1 || reqLvl > 16) {
        const error = new Error('Invalid SVIP skin tier');
        error.statusCode = 400;
        error.code = 'INVALID_ASSET_ID';
        throw error;
      }
      const userSvip = Number(userRecord.profile?.svipLevel || 0);
      if (userSvip < 1) {
        const error = new Error('You do not have an active SVIP entitlement to equip this skin');
        error.statusCode = 403;
        error.code = 'INSUFFICIENT_SVIP_TIER';
        throw error;
      }
      if (userSvip < reqLvl) {
        const error = new Error(`Your SVIP tier (SVIP ${userSvip}) is insufficient to equip SVIP ${reqLvl} Homepage Skin`);
        error.statusCode = 403;
        error.code = 'INSUFFICIENT_SVIP_TIER';
        throw error;
      }
      // Reject forged user suffix in synthetic ID (IDOR prevention)
      const skinPrefix = `assigned-skin-svip${reqLvl}-`;
      if (userAssetId.startsWith(skinPrefix)) {
        const suffixUserId = userAssetId.substring(skinPrefix.length);
        if (suffixUserId && suffixUserId !== userId) {
          const error = new Error('You are not authorized to equip this asset');
          error.statusCode = 403;
          error.code = 'FORBIDDEN_ASSET_ACCESS';
          throw error;
        }
      }
    } else if (userAssetId.includes('-card') || userAssetId.startsWith('assigned-card-')) {
      itemType = 'PROFILE_CARD';
      itemCategory = 'Cards';
      const svipMatch = userAssetId.match(/svip(\d+)/i);
      const lvl = svipMatch ? svipMatch[1] : (userAssetId.match(/-card-(\d+)/) ? userAssetId.match(/-card-(\d+)/)[1] : '6');
      matchedItem = { key: `svip${lvl}_card`, name: `SVIP ${lvl} Profile Card`, asset: `assets/svip/svip${lvl}_profilecard.webp` };

      // Authoritative SVIP Entitlement Verification for Profile Card
      const userRecord = await db.user.findUnique({
        where: { id: userId },
        include: { profile: true },
      });
      if (!userRecord) {
        const error = new Error('User not found');
        error.statusCode = 404;
        error.code = 'USER_NOT_FOUND';
        throw error;
      }
      const reqLvl = parseInt(lvl, 10);
      if (isNaN(reqLvl) || reqLvl < 1 || reqLvl > 16) {
        const error = new Error('Invalid SVIP profile card tier');
        error.statusCode = 400;
        error.code = 'INVALID_ASSET_ID';
        throw error;
      }
      const userSvip = Number(userRecord.profile?.svipLevel || 0);
      if (userSvip < 1) {
        const error = new Error('You do not have an active SVIP entitlement to equip this profile card');
        error.statusCode = 403;
        error.code = 'INSUFFICIENT_SVIP_TIER';
        throw error;
      }
      if (userSvip < reqLvl) {
        const error = new Error(`Your SVIP tier (SVIP ${userSvip}) is insufficient to equip SVIP ${reqLvl} Profile Card`);
        error.statusCode = 403;
        error.code = 'INSUFFICIENT_SVIP_TIER';
        throw error;
      }
      const cardPrefix = `assigned-card-svip${reqLvl}-`;
      if (userAssetId.startsWith(cardPrefix)) {
        const suffixUserId = userAssetId.substring(cardPrefix.length);
        if (suffixUserId && suffixUserId !== userId) {
          const error = new Error('You are not authorized to equip this asset');
          error.statusCode = 403;
          error.code = 'FORBIDDEN_ASSET_ACCESS';
          throw error;
        }
      }
    } else {
      // Default to FRAME
      itemType = 'FRAME';
      itemCategory = 'Frame';
      matchedItem = ALL_AVAILABLE_FRAMES.find((f) => userAssetId.startsWith(`assigned-frame-${f.key}-`));
      if (!matchedItem) {
        matchedItem = ALL_AVAILABLE_FRAMES[0];
      }
    }

    const assetId = `assigned-asset-${matchedItem.key}`;
    // Ensure Asset exists in database
    let dbAsset = await db.asset.findUnique({ where: { id: assetId } });
    if (!dbAsset) {
      dbAsset = await db.asset.create({
        data: {
          id: assetId,
          name: matchedItem.name,
          assetType: itemType,
          thumbnailUrl: matchedItem.asset,
          staticFileUrl: matchedItem.asset,
          animationFileUrl: matchedItem.asset,
          priceCoins: 0,
          validDays: 365,
          isActive: true,
        },
      });
    }

    // Unequip existing of same type
    await userAssetRepository.unequipAssetsByType(userId, itemType, db);
    if (itemType === 'VEHICLE') {
      await userAssetRepository.unequipAssetsByType(userId, 'ENTRY_EFFECT', db);
    }

    // Upsert UserAsset
    let userAsset = await db.userAsset.findFirst({
      where: { userId, assetId },
      include: { asset: true },
    });
    if (userAsset) {
      userAsset = await db.userAsset.update({
        where: { id: userAsset.id },
        data: { isEquipped: true, expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000) },
        include: { asset: true },
      });
    } else {
      userAsset = await db.userAsset.create({
        data: {
          userId,
          assetId,
          isEquipped: true,
          expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
        },
        include: { asset: true },
      });
    }

    // Persist skin & profile card to UserProfile (ZP-BUG-012, ZP-BUG-013)
    if (itemType === 'HOMEPAGE_SKIN') {
      await db.userProfile.update({
        where: { userId },
        data: { equippedSkinId: assetId, profileSkinUrl: matchedItem.asset },
      }).catch(() => {});
    } else if (itemType === 'PROFILE_CARD') {
      await db.userProfile.update({
        where: { userId },
        data: { equippedProfileCardId: assetId, profileCardUrl: matchedItem.asset },
      }).catch(() => {});
    }

    // Invalidate profile cache in Redis and remove unequipped flag
    try {
      if (redisProxy.isOpen && userId) {
        await redisProxy.del(`user:unequipped:${itemType}:${userId}`);
        await redisProxy.del(`user:profile:${userId}`);
      }
    } catch (_) {}

    const assignedOutfitPayload = {
      userId,
      assetType: itemType,
      assetUrl: matchedItem.asset,
      equippedFrame: itemType === 'FRAME' ? matchedItem.asset : undefined,
      avatarFrame: itemType === 'FRAME' ? matchedItem.asset : undefined,
      isEquipped: true,
      action: 'EQUIP',
      timestamp: new Date().toISOString(),
    };
    emitToUser(userId, 'user:outfit_updated', assignedOutfitPayload);
    if (itemType === 'FRAME') {
      await syncUserSocketFrame(userId, matchedItem.asset);
      broadcastGlobal('room:user_frame_updated', assignedOutfitPayload);
    }

    return serializeUserAsset(userAsset);
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

  // Persist skin & profile card to UserProfile if applicable
  const assetUrl = userAsset.asset?.thumbnailUrl || userAsset.asset?.staticFileUrl || userAsset.asset?.animationFileUrl || userAsset.asset?.imageUrl || '';
  if (assetType === 'HOMEPAGE_SKIN') {
    await db.userProfile.update({
      where: { userId },
      data: { equippedSkinId: userAsset.assetId, profileSkinUrl: assetUrl },
    }).catch(() => {});
  } else if (assetType === 'PROFILE_CARD') {
    await db.userProfile.update({
      where: { userId },
      data: { equippedProfileCardId: userAsset.assetId, profileCardUrl: assetUrl },
    }).catch(() => {});
  }

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
      await redisProxy.del(`user:unequipped:${assetType}:${userId}`);
      await redisProxy.del(`user:profile:${userId}`);
    }
  } catch (_) {}

  // Publish realtime outfit update
  try {
    if (userId) {
      const frameUrl = userAsset.asset?.thumbnailUrl || userAsset.asset?.staticFileUrl || userAsset.asset?.animationFileUrl || userAsset.asset?.name || null;
      const outfitPayload = {
        userId,
        assetType,
        assetId: userAsset.assetId,
        equippedFrame: assetType === 'FRAME' ? frameUrl : undefined,
        avatarFrame: assetType === 'FRAME' ? frameUrl : undefined,
        action: 'EQUIP',
        timestamp: new Date().toISOString(),
      };
      emitToUser(userId, 'user:outfit_updated', outfitPayload);
      if (assetType === 'FRAME') {
        await syncUserSocketFrame(userId, frameUrl);
        broadcastGlobal('room:user_frame_updated', outfitPayload);
      }
    }
  } catch (_) {}

  return serializeUserAsset(updatedUserAsset);
}

export async function unequipAsset(userId, userAssetId, { ipAddress } = {}, db = prisma) {
  let userAsset = await userAssetRepository.findUserAssetById(userAssetId, db);
  if (!userAsset) {
    userAsset = await userAssetRepository.findActiveUserAssetByAssetId(userId, userAssetId, db);
  }

  const idStr = String(userAssetId || '').toLowerCase();
  let assetType = userAsset?.asset?.assetType;
  if (!assetType) {
    if (idStr.includes('frame')) assetType = 'FRAME';
    else if (idStr.includes('bubble')) assetType = 'CHAT_BUBBLE';
    else if (idStr.includes('vehicle') || idStr.includes('ride')) assetType = 'VEHICLE';
    else if (idStr.includes('effect') || idStr.includes('entry')) assetType = 'ENTRY_EFFECT';
    else if (idStr.includes('skin')) assetType = 'HOMEPAGE_SKIN';
    else if (idStr.includes('card')) assetType = 'PROFILE_CARD';
    else assetType = 'FRAME';
  }

  if (userAsset) {
    // Enforce IDOR protection
    if (userAsset.userId !== userId) {
      const error = new Error('You are not authorized to unequip this asset');
      error.statusCode = 403;
      error.code = 'FORBIDDEN_ASSET_ACCESS';
      throw error;
    }

    await userAssetRepository.updateUserAsset(
      userAsset.id,
      { isEquipped: false },
      db
    );
  }

  // Ensure all assets of this type are unequipped in database
  if (assetType) {
    await userAssetRepository.unequipAssetsByType(userId, assetType, db);
  }

  // Clear skin / card fields from UserProfile if applicable (persisting 'none' unequipped sentinel)
  if (assetType === 'HOMEPAGE_SKIN') {
    await db.userProfile.update({
      where: { userId },
      data: { equippedSkinId: 'none', profileSkinUrl: 'none' },
    }).catch(() => {});
  } else if (assetType === 'PROFILE_CARD') {
    await db.userProfile.update({
      where: { userId },
      data: { equippedProfileCardId: 'none', profileCardUrl: 'none' },
    }).catch(() => {});
  }

  await logAudit({
    adminId: null,
    adminName: 'User Action',
    action: 'USER_ASSET_UNEQUIPPED',
    targetEntity: 'UserAsset',
    targetEntityId: userAsset?.id || userAssetId,
    afterStateJson: {
      userId,
      userAssetId: userAsset?.id || userAssetId,
      assetId: userAsset?.assetId || userAssetId,
      assetName: userAsset?.asset?.name || userAssetId,
      assetType,
    },
    ipAddress,
  }, db);

  // Invalidate user profile cache in Redis and persist unequipped sentinel
  try {
    if (redisProxy.isOpen && userId) {
      await redisProxy.set(`user:unequipped:${assetType}:${userId}`, '1', 'EX', 365 * 86400);
      await redisProxy.del(`user:profile:${userId}`);
    }
  } catch (_) {}

  // Publish realtime outfit unequip update
  const unequipPayload = {
    userId,
    assetType,
    assetId: userAsset?.assetId || userAssetId,
    equippedFrame: assetType === 'FRAME' ? 'none' : undefined,
    avatarFrame: assetType === 'FRAME' ? 'none' : undefined,
    action: 'UNEQUIP',
    timestamp: new Date().toISOString(),
  };

  try {
    if (userId) {
      emitToUser(userId, 'user:outfit_updated', unequipPayload);
      if (assetType === 'FRAME') {
        await syncUserSocketFrame(userId, null);
        broadcastGlobal('room:user_frame_updated', unequipPayload);
      }
    }
  } catch (_) {}

  return userAsset ? serializeUserAsset(userAsset) : { id: userAssetId, userId, isEquipped: false };
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

