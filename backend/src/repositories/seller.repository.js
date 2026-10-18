import prisma from '../config/database.js';
import { normalizeCountry } from '../utils/country.util.js';

export async function findSellerById(id, db = prisma) {
  if (!id) return null;
  return await db.coinSeller.findUnique({
    where: { id },
    include: {
      user: {
        select: {
          id: true,
          username: true,
          email: true,
          phone: true,
          countryCode: true,
          region: true,
          status: true,
          avatarUrl: true,
          profile: true,
          wallet: true,
        },
      },
    },
  });
}

export async function findSellerByUserId(userId, db = prisma) {
  if (!userId) return null;
  return await db.coinSeller.findUnique({
    where: { userId },
    include: {
      user: {
        select: {
          id: true,
          username: true,
          email: true,
          phone: true,
          countryCode: true,
          region: true,
          status: true,
          avatarUrl: true,
          profile: true,
          wallet: true,
        },
      },
    },
  });
}

export async function findSellers(
  { page = 1, limit = 20, search = '', sellerStatus, country, countryCode, countryRequired = false },
  db = prisma
) {
  const andConditions = [];

  if (sellerStatus) {
    andConditions.push({ sellerStatus });
  }

  // Country filtering logic
  const rawCountry = countryCode || country;
  if (rawCountry && rawCountry !== 'All' && rawCountry !== 'GLOBAL') {
    const norm = normalizeCountry(rawCountry);
    if (norm) {
      andConditions.push({
        user: {
          status: 'ACTIVE',
          OR: [
            { countryCode: norm.code },
            { region: { equals: norm.name, mode: 'insensitive' } },
            { region: { equals: norm.code, mode: 'insensitive' } },
          ],
        },
      });
    } else if (countryRequired) {
      // If a country filter was required but unresolvable, return empty results immediately
      return {
        sellers: [],
        pagination: {
          page,
          limit,
          totalCount: 0,
          totalPages: 1,
        },
      };
    }
  } else if (countryRequired) {
    // Country was required but none provided
    return {
      sellers: [],
      pagination: {
        page,
        limit,
        totalCount: 0,
        totalPages: 1,
      },
    };
  }

  // Search logic across name, username, display name, and numeric/string IDs
  if (search && search.trim()) {
    const cleanSearch = search.trim();
    andConditions.push({
      OR: [
        { businessName: { contains: cleanSearch, mode: 'insensitive' } },
        { user: { username: { contains: cleanSearch, mode: 'insensitive' } } },
        { user: { email: { contains: cleanSearch, mode: 'insensitive' } } },
        { user: { profile: { displayName: { contains: cleanSearch, mode: 'insensitive' } } } },
        { userId: { contains: cleanSearch, mode: 'insensitive' } },
        { id: { contains: cleanSearch, mode: 'insensitive' } },
      ],
    });
  }

  const where = andConditions.length > 0 ? { AND: andConditions } : {};
  const skip = (page - 1) * limit;

  const [sellers, totalCount] = await Promise.all([
    db.coinSeller.findMany({
      where,
      skip,
      take: limit,
      orderBy: { createdAt: 'desc' },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            email: true,
            phone: true,
            countryCode: true,
            region: true,
            status: true,
            avatarUrl: true,
            profile: true,
            wallet: {
              select: {
                sellerBalanceCoins: true,
                coinBalance: true,
              },
            },
          },
        },
      },
    }),
    db.coinSeller.count({ where }),
  ]);

  return {
    sellers,
    pagination: {
      page,
      limit,
      totalCount,
      totalPages: Math.ceil(totalCount / limit) || 1,
    },
  };
}

export async function createSeller(data, db = prisma) {
  return await db.coinSeller.create({
    data: {
      userId: data.userId,
      businessName: data.businessName,
      profitMarginPercent: data.profitMarginPercent !== undefined ? data.profitMarginPercent : 10.0,
      creditLimitUSD: data.creditLimitUSD !== undefined ? data.creditLimitUSD : 1000.00,
      sellerStatus: data.sellerStatus || 'ACTIVE',
      resellerBalanceCoins: BigInt(data.resellerBalanceCoins || 0),
    },
  });
}

export async function updateSeller(id, data, db = prisma) {
  const updateData = { ...data };
  if (updateData.resellerBalanceCoins !== undefined) {
    updateData.resellerBalanceCoins = BigInt(updateData.resellerBalanceCoins);
  }
  return await db.coinSeller.update({
    where: { id },
    data: updateData,
  });
}

export async function updateSellerBalance(id, amountDelta, db = prisma) {
  return await db.coinSeller.update({
    where: { id },
    data: {
      resellerBalanceCoins: { increment: BigInt(amountDelta) },
    },
  });
}

export async function deleteSeller(id, db = prisma) {
  return await db.coinSeller.delete({
    where: { id },
  });
}

export default {
  findSellerById,
  findSellerByUserId,
  findSellers,
  createSeller,
  updateSeller,
  updateSellerBalance,
  deleteSeller,
};
