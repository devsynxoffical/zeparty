import prisma from '../config/database.js';
import assetRepository from '../repositories/asset.repository.js';
import userAssetRepository from '../repositories/userAsset.repository.js';

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

export function serializeAsset(asset) {
  if (!asset) return null;
  const rawType = asset.assetType || 'FRAME';
  let category = 'Frame';
  if (rawType === 'VEHICLE') category = 'Cars';
  else if (rawType === 'FRAME') category = 'Frame';
  else if (rawType === 'CHAT_BUBBLE') category = 'Bubble';
  else if (rawType === 'ENTRY_EFFECT') category = 'Background';
  else if (rawType === 'BADGE') category = 'Badges';

  const imageUrl = asset.thumbnailUrl || asset.staticFileUrl || asset.animationFileUrl || '';

  return {
    ...asset,
    id: asset.id,
    name: asset.name,
    categoryId: category,
    assetType: rawType,
    imageUrl,
    iconUrl: imageUrl,
    thumbnailUrl: imageUrl,
    assetUrl: asset.animationFileUrl || asset.staticFileUrl || asset.videoFileUrl || null,
    durationDays: asset.validDays || 30,
    validDays: asset.validDays || 30,
    priceCoins: asset.priceCoins ? asset.priceCoins.toString() : '0',
    isVipExclusive: Boolean(asset.isVipExclusive),
    minVipLevelRequired: asset.minVipLevelRequired || 0,
    roomAvailability: asset.roomAvailability || 'BOTH',
    isActive: Boolean(asset.isActive),
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

const ALL_AVAILABLE_FRAMES = [
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

  return serializeUserAsset(updatedUserAsset);
}

export async function unequipAsset(userId, userAssetId, { ipAddress } = {}, db = prisma) {
  // Handle assigned frames
  if (userAssetId && userAssetId.startsWith('assigned-frame-')) {
    return {
      id: userAssetId,
      userId,
      assetId: 'assigned-asset-frame',
      isEquipped: false,
      expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(),
      isExpired: false,
      asset: {
        id: 'assigned-asset-frame',
        name: 'Assigned Frame',
        categoryId: 'Frame',
        assetType: 'FRAME',
        imageUrl: 'assets/roles/host_frame.webp',
        priceCoins: '0',
        isActive: true,
      },
    };
  }

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
    },
    ipAddress,
  }, db);

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

