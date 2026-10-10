import prisma from '../config/database.js';
import assetRepository from '../repositories/asset.repository.js';
import userAssetRepository from '../repositories/userAsset.repository.js';

async function logAudit({ adminId, adminName, action, targetEntity, targetEntityId, beforeStateJson, afterStateJson, reason, ipAddress }, db = prisma) {
  try {
    await db.auditLog.create({
      data: {
        adminId: adminId || null,
        adminName: adminName || (adminId ? 'Administrator' : 'User Action'),
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
  return {
    ...asset,
    priceCoins: asset.priceCoins ? asset.priceCoins.toString() : '0',
  };
}

export function serializeUserAsset(userAsset) {
  if (!userAsset) return null;
  const isExpired = userAsset.expiresAt ? new Date(userAsset.expiresAt) <= new Date() : false;
  return {
    ...userAsset,
    isExpired,
    asset: userAsset.asset ? serializeAsset(userAsset.asset) : null,
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
    select: {
      id: true,
      role: true,
      nobleTitle: true,
      isVip: true,
      vipLevel: true,
      avatarFrame: true,
    },
  });

  const userAssets = await userAssetRepository.findUserAssets(userId, db);
  const serialized = userAssets.map(serializeUserAsset);

  if (user) {
    const isHost = user.role === 'HOST' || user.role === 'host';
    const isAgency = user.role === 'AGENCY' || user.role === 'agency';
    const isAdmin = user.role === 'ADMIN' || user.role === 'admin';
    const nobleTitle = user.nobleTitle?.toLowerCase().trim();
    const currentFrame = (user.avatarFrame || '').toLowerCase().trim();

    let defaultFrameKey = '';
    if (isHost) defaultFrameKey = 'host';
    else if (nobleTitle) defaultFrameKey = nobleTitle;
    else if (isAdmin) defaultFrameKey = 'admin';
    else if (isAgency) defaultFrameKey = 'agency';

    for (const f of ALL_AVAILABLE_FRAMES) {
      let isEquipped = false;
      if (currentFrame !== 'none') {
        if (currentFrame.length > 0) {
          isEquipped = currentFrame === f.key || currentFrame.includes(f.key) || currentFrame === f.asset;
        } else {
          isEquipped = (defaultFrameKey === f.key);
        }
      }

      const alreadyExists = serialized.some(
        s => s.asset?.imageUrl === f.asset || s.asset?.name === f.name
      );

      if (!alreadyExists) {
        const frameAsset = {
          id: `assigned-frame-${f.key}-${user.id}`,
          userId: user.id,
          assetId: `assigned-asset-${f.key}-frame`,
          isEquipped,
          expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(),
          isExpired: false,
          asset: {
            id: `assigned-asset-${f.key}-frame`,
            name: f.name,
            categoryId: 'Frame',
            assetType: 'AVATAR_FRAME',
            imageUrl: f.asset,
            priceCoins: '0',
            isActive: true,
          },
        };

        if (isEquipped) {
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
    let matchedFrame = ALL_AVAILABLE_FRAMES.find(f => userAssetId.startsWith(`assigned-frame-${f.key}-`));
    if (!matchedFrame) {
      matchedFrame = ALL_AVAILABLE_FRAMES[0];
    }

    await db.user.update({
      where: { id: userId },
      data: { avatarFrame: matchedFrame.key },
    });

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
        assetType: 'AVATAR_FRAME',
        imageUrl: matchedFrame.asset,
        priceCoins: '0',
        isActive: true,
      },
    };
  }

  const userAsset = await userAssetRepository.findUserAssetById(userAssetId, db);
  if (!userAsset) {
    const error = new Error('User asset not found');
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

  const assetType = userAsset.asset?.assetType;

  // Execute in transaction to ensure single-equipped exclusivity per assetType
  const updatedUserAsset = await db.$transaction(async (tx) => {
    if (assetType) {
      await userAssetRepository.unequipAssetsByType(userId, assetType, tx);
    }
    if (assetType === 'AVATAR_FRAME') {
      await tx.user.update({
        where: { id: userId },
        data: { avatarFrame: userAsset.asset?.imageUrl || userAsset.asset?.name || 'frame' },
      });
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
    await db.user.update({
      where: { id: userId },
      data: { avatarFrame: 'none' },
    });

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
        assetType: 'AVATAR_FRAME',
        imageUrl: 'assets/roles/host_frame.webp',
        priceCoins: '0',
        isActive: true,
      },
    };
  }

  const userAsset = await userAssetRepository.findUserAssetById(userAssetId, db);
  if (!userAsset) {
    const error = new Error('User asset not found');
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

  if (userAsset.asset?.assetType === 'AVATAR_FRAME') {
    await db.user.update({
      where: { id: userId },
      data: { avatarFrame: 'none' },
    });
  }

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
