import prisma from '../config/database.js';

export async function findAllPlans({ includeInactive = false }, db = prisma) {
  const where = includeInactive ? {} : { isActive: true };
  return await db.rechargePlan.findMany({
    where,
    orderBy: { priceUSD: 'asc' },
  });
}

export async function findPlanById(id, db = prisma) {
  if (!id) return null;
  return await db.rechargePlan.findUnique({
    where: { id },
  });
}

export async function createPlan(data, db = prisma) {
  return await db.rechargePlan.create({
    data: {
      coinAmount: BigInt(data.coinAmount),
      priceUSD: data.priceUSD,
      bonusCoins: BigInt(data.bonusCoins || 0),
      badgeText: data.badgeText || null,
      isActive: data.isActive !== undefined ? data.isActive : true,
    },
  });
}

export async function updatePlan(id, data, db = prisma) {
  const updateData = {};
  if (data.coinAmount !== undefined) updateData.coinAmount = BigInt(data.coinAmount);
  if (data.priceUSD !== undefined) updateData.priceUSD = data.priceUSD;
  if (data.bonusCoins !== undefined) updateData.bonusCoins = BigInt(data.bonusCoins);
  if (data.badgeText !== undefined) updateData.badgeText = data.badgeText;
  if (data.isActive !== undefined) updateData.isActive = data.isActive;

  return await db.rechargePlan.update({
    where: { id },
    data: updateData,
  });
}

export async function findOfflineRechargeById(id, db = prisma) {
  if (!id) return null;
  return await db.offlineRecharge.findUnique({
    where: { id },
    include: {
      user: {
        select: { id: true, username: true, email: true },
      },
    },
  });
}

export async function findAllOfflineRecharges(
  { status, userId, page = 1, limit = 20 },
  db = prisma
) {
  const where = {};
  if (status) where.status = status;
  if (userId) where.userId = userId;

  const skip = (Math.max(1, page) - 1) * limit;

  return await db.offlineRecharge.findMany({
    where,
    include: {
      user: {
        select: { id: true, username: true },
      },
    },
    orderBy: { createdAt: 'desc' },
    skip,
    take: limit,
  });
}

export async function countOfflineRecharges(
  { status, userId },
  db = prisma
) {
  const where = {};
  if (status) where.status = status;
  if (userId) where.userId = userId;

  return await db.offlineRecharge.count({ where });
}

export async function updateOfflineRechargeStatus(
  id,
  { status, reviewerAdminId, reviewedAt = new Date() },
  db = prisma
) {
  return await db.offlineRecharge.update({
    where: { id },
    data: {
      status,
      reviewerAdminId,
      reviewedAt,
    },
  });
}

export default {
  findAllPlans,
  findPlanById,
  createPlan,
  updatePlan,
  findOfflineRechargeById,
  findAllOfflineRecharges,
  countOfflineRecharges,
  updateOfflineRechargeStatus,
};
