import prisma from '../config/database.js';
import {
  getPrismaRestrictedAssetWhereClauses,
  isPublicStoreItem,
  isRestrictedSpecialAsset,
} from '../utils/assetClassification.util.js';

export async function findAssets(
  {
    page = 1,
    limit = 20,
    assetType,
    assetSubcategory,
    roomAvailability,
    isVipExclusive,
    isActive,
    search = '',
    classification = 'ALL',
  },
  db = prisma
) {
  const where = {};

  if (assetType) where.assetType = assetType;
  if (assetSubcategory) where.assetSubcategory = assetSubcategory;
  if (roomAvailability) where.roomAvailability = roomAvailability;
  if (typeof isVipExclusive === 'boolean') where.isVipExclusive = isVipExclusive;
  if (typeof isActive === 'boolean') where.isActive = isActive;

  if (search) {
    where.name = { contains: search, mode: 'insensitive' };
  }

  const normalizedClassification = String(classification || 'ALL').toUpperCase();
  if (normalizedClassification === 'PUBLIC') {
    where.NOT = getPrismaRestrictedAssetWhereClauses();
  } else if (normalizedClassification === 'SPECIAL' || normalizedClassification === 'RESTRICTED') {
    where.OR = getPrismaRestrictedAssetWhereClauses();
  }

  const skip = (page - 1) * limit;

  const [total, assets] = await Promise.all([
    db.asset.count({ where }),
    db.asset.findMany({
      where,
      skip,
      take: limit,
      orderBy: { createdAt: 'desc' },
    }),
  ]);

  return {
    assets,
    pagination: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit) || 1,
    },
  };
}

export async function findAssetById(id, db = prisma) {
  if (!id) return null;
  const direct = await db.asset.findUnique({
    where: { id },
  });
  if (direct) return direct;

  const fallback = await db.asset.findFirst({
    where: {
      OR: [
        { id: { equals: id, mode: 'insensitive' } },
        { name: { equals: id, mode: 'insensitive' } },
      ],
    },
  });
  return fallback;
}

export async function createAsset(data, db = prisma) {
  const { priceCoins, ...rest } = data;
  return await db.asset.create({
    data: {
      ...rest,
      priceCoins: BigInt(priceCoins || 0),
    },
  });
}

export async function updateAsset(id, data, db = prisma) {
  const updateData = { ...data };
  if (updateData.priceCoins !== undefined) {
    updateData.priceCoins = BigInt(updateData.priceCoins);
  }
  return await db.asset.update({
    where: { id },
    data: updateData,
  });
}

export async function findStoreCatalog(
  {
    page = 1,
    limit = 20,
    assetType,
    roomAvailability,
    isVipExclusive,
    minVipLevel,
    search = '',
    includeSpecial = false,
  },
  db = prisma
) {
  const where = {
    isActive: true,
  };

  if (!includeSpecial) {
    where.NOT = getPrismaRestrictedAssetWhereClauses();
  }

  if (assetType) where.assetType = assetType;
  if (roomAvailability) where.roomAvailability = roomAvailability;
  if (typeof isVipExclusive === 'boolean') where.isVipExclusive = isVipExclusive;
  if (minVipLevel !== undefined) {
    where.minVipLevelRequired = { lte: minVipLevel };
  }

  if (search) {
    where.name = { contains: search, mode: 'insensitive' };
  }

  const skip = (page - 1) * limit;

  const [total, assets] = await Promise.all([
    db.asset.count({ where }),
    db.asset.findMany({
      where,
      skip,
      take: limit,
      orderBy: { priceCoins: 'asc' },
    }),
  ]);

  // Strict defense-in-depth: If not including special, enforce isPublicStoreItem
  const finalAssets = includeSpecial ? assets : assets.filter(isPublicStoreItem);

  return {
    assets: finalAssets,
    pagination: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit) || 1,
    },
  };
}

export default {
  findAssets,
  findAssetById,
  createAsset,
  updateAsset,
  findStoreCatalog,
};

