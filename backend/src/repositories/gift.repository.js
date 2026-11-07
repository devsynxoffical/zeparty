import prisma from '../config/database.js';

export async function findGifts(
  { page = 1, limit = 50, giftCategory, category, appCategory, isActive, search = '' },
  db = prisma
) {
  const andConditions = [];

  // Active / Inactive filter
  if (typeof isActive === 'boolean') {
    andConditions.push({ isActive });
  }

  // Category filter: handles both App categories (Lucky Gift, Classic, Event, Privileges, Special)
  // and DB Enum categories (POPULAR, LUXURY, VIP, AUDIO)
  const rawCategory = category || appCategory || giftCategory;
  if (rawCategory && typeof rawCategory === 'string' && rawCategory.trim().toUpperCase() !== 'ALL') {
    const cat = rawCategory.trim();
    const upper = cat.toUpperCase();

    if (upper === 'LUCKY GIFT' || upper === 'LUCKY_GIFT' || upper === 'LG' || upper === 'LUCKY') {
      andConditions.push({
        OR: [
          { id: { startsWith: 'lg', mode: 'insensitive' } },
          { name: { contains: 'lucky', mode: 'insensitive' } },
        ],
      });
    } else if (upper === 'CLASSIC' || upper === 'CG') {
      andConditions.push({ id: { startsWith: 'cg', mode: 'insensitive' } });
    } else if (upper === 'EVENT' || upper === 'EG') {
      andConditions.push({ id: { startsWith: 'eg', mode: 'insensitive' } });
    } else if (upper === 'PRIVILEGES' || upper === 'PRIVILEGES / VIP' || upper === 'PV') {
      andConditions.push({
        OR: [
          { id: { startsWith: 'pv', mode: 'insensitive' } },
          { giftCategory: 'VIP' },
        ],
      });
    } else if (upper === 'SPECIAL' || upper === 'SP') {
      andConditions.push({ id: { startsWith: 'sp', mode: 'insensitive' } });
    } else if (['POPULAR', 'LUXURY', 'VIP', 'AUDIO'].includes(upper)) {
      if (upper === 'VIP') {
        andConditions.push({
          OR: [
            { giftCategory: 'VIP' },
            { id: { startsWith: 'pv', mode: 'insensitive' } },
          ],
        });
      } else {
        andConditions.push({ giftCategory: upper });
      }
    }
  }

  // Search filter: matches both gift.name (case-insensitive substring) and gift.id (case-insensitive substring)
  if (search && typeof search === 'string' && search.trim() !== '') {
    const q = search.trim();
    andConditions.push({
      OR: [
        { name: { contains: q, mode: 'insensitive' } },
        { id: { contains: q, mode: 'insensitive' } },
      ],
    });
  }

  const where = andConditions.length > 0 ? { AND: andConditions } : {};
  const skip = (page - 1) * limit;

  const [total, gifts] = await Promise.all([
    db.gift.count({ where }),
    db.gift.findMany({
      where,
      skip,
      take: limit,
      orderBy: { createdAt: 'desc' },
    }),
  ]);

  return {
    gifts,
    pagination: {
      page: Number(page),
      limit: Number(limit),
      total,
      totalPages: Math.ceil(total / limit) || 1,
    },
  };
}

export async function findGiftById(id, db = prisma) {
  if (!id) return null;
  return await db.gift.findUnique({
    where: { id },
  });
}

export async function createGift(data, db = prisma) {
  const { coinValue, ...rest } = data;
  return await db.gift.create({
    data: {
      ...rest,
      coinValue: BigInt(coinValue),
    },
  });
}

export async function updateGift(id, data, db = prisma) {
  const updateData = { ...data };
  if (updateData.coinValue !== undefined) {
    updateData.coinValue = BigInt(updateData.coinValue);
  }
  return await db.gift.update({
    where: { id },
    data: updateData,
  });
}

export async function createGiftTransaction(data, db = prisma) {
  const {
    giftId,
    senderUserId,
    recipientUserId,
    roomId = null,
    giftCount = 1,
    totalCoins,
    hostDiamonds,
  } = data;

  return await db.giftTransaction.create({
    data: {
      giftId,
      senderUserId,
      recipientUserId,
      roomId,
      giftCount,
      totalCoins: BigInt(totalCoins),
      hostDiamonds: BigInt(hostDiamonds),
    },
    include: {
      gift: {
        select: { id: true, name: true, iconUrl: true, giftCategory: true },
      },
      sender: {
        select: { id: true, username: true },
      },
      recipient: {
        select: { id: true, username: true },
      },
    },
  });
}

export async function findGiftTransactions(
  { senderUserId, recipientUserId, roomId, page = 1, limit = 20 },
  db = prisma
) {
  const where = {};

  if (senderUserId) where.senderUserId = senderUserId;
  if (recipientUserId) where.recipientUserId = recipientUserId;
  if (roomId) where.roomId = roomId;

  const skip = (page - 1) * limit;

  const [total, transactions] = await Promise.all([
    db.giftTransaction.count({ where }),
    db.giftTransaction.findMany({
      where,
      skip,
      take: limit,
      orderBy: { createdAt: 'desc' },
      include: {
        gift: {
          select: { id: true, name: true, iconUrl: true, giftCategory: true },
        },
        sender: {
          select: { id: true, username: true },
        },
        recipient: {
          select: { id: true, username: true },
        },
      },
    }),
  ]);

  return {
    transactions,
    pagination: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit) || 1,
    },
  };
}

export default {
  findGifts,
  findGiftById,
  createGift,
  updateGift,
  createGiftTransaction,
  findGiftTransactions,
};
