import walletService from '../services/wallet.service.js';
import rechargeService from '../services/recharge.service.js';
import withdrawalService from '../services/withdrawal.service.js';
import refundService from '../services/refund.service.js';
import prisma from '../config/database.js';
import walletRepository from '../repositories/wallet.repository.js';
import {
  createRechargePlanSchema,
  updateRechargePlanSchema,
  rejectFinancialItemSchema,
  createCoinRefundSchema,
  queryLedgerSchema,
} from '../validators/finance.validator.js';

// --- Master Ledger & Transactions ---
export async function getMasterLedger(req, res, next) {
  try {
    const validated = queryLedgerSchema.parse(req.query);
    const ledger = await walletService.getMasterLedger(validated);

    return res.status(200).json({
      success: true,
      message: 'Master transaction ledger retrieved successfully',
      data: ledger.items,
      pagination: ledger.pagination,
    });
  } catch (err) {
    next(err);
  }
}

// --- Recharge Packages ---
export async function getRechargePlans(req, res, next) {
  try {
    const plans = await rechargeService.getRechargePlans({ includeInactive: true });
    return res.status(200).json({
      success: true,
      data: plans,
    });
  } catch (err) {
    next(err);
  }
}

export async function createRechargePlan(req, res, next) {
  try {
    const validated = createRechargePlanSchema.parse(req.body);
    const adminId = req.auth.userId;
    const isOwner = Boolean(req.auth.isOwner);
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const plan = await rechargeService.createRechargePlan(validated, adminId, isOwner, ipAddress);

    return res.status(201).json({
      success: true,
      message: 'Recharge plan created successfully',
      data: plan,
    });
  } catch (err) {
    next(err);
  }
}

export async function updateRechargePlan(req, res, next) {
  try {
    const { id } = req.params;
    const validated = updateRechargePlanSchema.parse(req.body);
    const adminId = req.auth.userId;
    const isOwner = Boolean(req.auth.isOwner);
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const plan = await rechargeService.updateRechargePlan(id, validated, adminId, isOwner, ipAddress);

    return res.status(200).json({
      success: true,
      message: 'Recharge plan updated successfully',
      data: plan,
    });
  } catch (err) {
    next(err);
  }
}

export async function deleteRechargePlan(req, res, next) {
  try {
    const { id } = req.params;
    const adminId = req.auth.userId;
    const isOwner = Boolean(req.auth.isOwner);
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await rechargeService.deleteRechargePlan(id, adminId, isOwner, ipAddress);

    return res.status(200).json({
      success: true,
      message: 'Recharge plan deleted successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

// --- Offline Recharge Deposits ---
export async function getOfflineRecharges(req, res, next) {
  try {
    const { status, userId, page = 1, limit = 20 } = req.query;
    const result = await rechargeService.getOfflineRecharges({ status, userId, page, limit });

    return res.status(200).json({
      success: true,
      data: result.items,
      pagination: result.pagination,
    });
  } catch (err) {
    next(err);
  }
}

export async function approveOfflineRecharge(req, res, next) {
  try {
    const { id } = req.params;
    const adminId = req.auth.userId;
    const isOwner = Boolean(req.auth.isOwner);
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await rechargeService.approveOfflineRecharge({ id, adminId, isOwner, ipAddress });

    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function rejectOfflineRecharge(req, res, next) {
  try {
    const { id } = req.params;
    const validated = rejectFinancialItemSchema.parse(req.body);
    const adminId = req.auth.userId;
    const isOwner = Boolean(req.auth.isOwner);
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await rechargeService.rejectOfflineRecharge({
      id,
      adminId,
      isOwner,
      reason: validated.reason,
      ipAddress,
    });

    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

// --- Withdrawals & Cashouts ---
export async function getWithdrawals(req, res, next) {
  try {
    const { status, userId, page = 1, limit = 20 } = req.query;
    const result = await withdrawalService.getWithdrawals({ status, userId, page, limit });

    return res.status(200).json({
      success: true,
      data: result.items,
      pagination: result.pagination,
    });
  } catch (err) {
    next(err);
  }
}

export async function approveWithdrawal(req, res, next) {
  try {
    const { id } = req.params;
    const adminId = req.auth.userId;
    const isOwner = Boolean(req.auth.isOwner);
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await withdrawalService.approveWithdrawal({ id, adminId, isOwner, ipAddress });

    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function rejectWithdrawal(req, res, next) {
  try {
    const { id } = req.params;
    const validated = rejectFinancialItemSchema.parse(req.body);
    const adminId = req.auth.userId;
    const isOwner = Boolean(req.auth.isOwner);
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await withdrawalService.rejectWithdrawal({
      id,
      adminId,
      isOwner,
      reason: validated.reason,
      ipAddress,
    });

    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

// --- Coin Refunds & Disputes ---
export async function getCoinRefunds(req, res, next) {
  try {
    const { status, userId, page = 1, limit = 20 } = req.query;
    const result = await refundService.getCoinRefunds({ status, userId, page, limit });

    return res.status(200).json({
      success: true,
      data: result.items,
      pagination: result.pagination,
    });
  } catch (err) {
    next(err);
  }
}

export async function submitCoinRefund(req, res, next) {
  try {
    const validated = createCoinRefundSchema.parse(req.body);
    const userId = req.auth.userId;

    const result = await refundService.submitCoinRefundDispute({
      userId,
      coinAmount: validated.coinAmount,
      disputeReason: validated.disputeReason,
    });

    return res.status(201).json({
      success: true,
      message: 'Coin refund dispute submitted successfully. Pending review.',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function processCoinRefund(req, res, next) {
  try {
    const { id } = req.params;
    const adminId = req.auth.userId;
    const isOwner = Boolean(req.auth.isOwner);
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await refundService.processCoinRefund({ id, adminId, isOwner, ipAddress });

    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function rejectCoinRefund(req, res, next) {
  try {
    const { id } = req.params;
    const validated = rejectFinancialItemSchema.parse(req.body);
    const adminId = req.auth.userId;
    const isOwner = Boolean(req.auth.isOwner);
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await refundService.rejectCoinRefund({
      id,
      adminId,
      isOwner,
      reason: validated.reason,
      ipAddress,
    });

    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function getWithdrawalRecipients(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const { type } = req.query;
    const result = await withdrawalService.getWithdrawalRecipients({ userId, type });
    return res.status(200).json({
      success: true,
      ...result,
    });
  } catch (err) {
    next(err);
  }
}

export async function createWithdrawalRequest(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const { recipientId, recipientRole, amountUSD } = req.body;
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await withdrawalService.createWithdrawalRequest({
      userId,
      recipientId,
      recipientRole,
      amountUSD,
      ipAddress,
    });

    return res.status(201).json(result);
  } catch (err) {
    next(err);
  }
}

// --- Finance Dashboard & Revenue Statistics ---
export async function getFinanceDashboard(req, res, next) {
  try {
    const emptySum = { _sum: { amountUSD: 0, netPayableUSD: 0, grossEarningsUSD: 0, commissionUSD: 0, totalCoins: 0n, hostDiamonds: 0n } };
    const settledStatuses = ['APPROVED', 'PROCESSING', 'PAID'];
    const [
      onlineRechargeAgg,
      offlineRechargeAgg,
      walletStats,
      pendingSettlementsAgg,
      giftVolumeAgg,
      hostSettlementAgg,
      agencySettlementAgg,
    ] = await Promise.all([
      prisma.onlineRecharge ? prisma.onlineRecharge.aggregate({
        where: { status: 'SUCCESS' },
        _sum: { amountUSD: true },
      }).catch(() => ({ _sum: { amountUSD: 0 } })) : { _sum: { amountUSD: 0 } },
      prisma.offlineRecharge ? prisma.offlineRecharge.aggregate({
        where: { status: 'APPROVED' },
        _sum: { amountUSD: true },
      }).catch(() => ({ _sum: { amountUSD: 0 } })) : { _sum: { amountUSD: 0 } },
      walletRepository.getPlatformStats().catch(() => ({ totalRechargedUSD: 0, totalWithdrawnUSD: 0, totalCoins: 0n, totalDiamonds: 0n })),
      prisma.settlementRecord ? prisma.settlementRecord.aggregate({
        where: { status: { in: ['PENDING_APPROVAL', 'CALCULATED', 'OPEN'] } },
        _sum: { netPayableUSD: true, grossEarningsUSD: true },
      }).catch(() => ({ _sum: { netPayableUSD: 0, grossEarningsUSD: 0 } })) : { _sum: { netPayableUSD: 0, grossEarningsUSD: 0 } },
      prisma.giftTransaction ? prisma.giftTransaction.aggregate({
        _sum: { totalCoins: true, hostDiamonds: true },
      }).catch(() => ({ _sum: { totalCoins: 0n, hostDiamonds: 0n } })) : { _sum: { totalCoins: 0n, hostDiamonds: 0n } },
      prisma.settlementRecord ? prisma.settlementRecord.aggregate({
        where: { recipientType: 'HOST', status: { in: settledStatuses } },
        _sum: { netPayableUSD: true },
      }).catch(() => emptySum) : emptySum,
      prisma.settlementRecord ? prisma.settlementRecord.aggregate({
        where: { recipientType: 'AGENCY', status: { in: settledStatuses } },
        _sum: { netPayableUSD: true },
      }).catch(() => emptySum) : emptySum,
    ]);

    const onlineUSD = Number(onlineRechargeAgg._sum?.amountUSD || 0);
    const offlineUSD = Number(offlineRechargeAgg._sum?.amountUSD || 0);
    const walletRechargeUSD = Number(walletStats.totalRechargedUSD || 0);
    const grossRechargeRevenue = Math.max(onlineUSD + offlineUSD, walletRechargeUSD);

    const totalWithdrawnUSD = Number(walletStats.totalWithdrawnUSD || 0);
    const pendingSettlement = Number(pendingSettlementsAgg._sum?.netPayableUSD || 0);

    // Real payouts recorded in settlement records (approved / processing / paid)
    const hostEarnings = Number(hostSettlementAgg._sum?.netPayableUSD || 0);
    const agencyCommission = Number(agencySettlementAgg._sum?.netPayableUSD || 0);
    const netPlatformRevenue = Math.round((grossRechargeRevenue - hostEarnings - agencyCommission) * 100) / 100;
    const platformProfit = netPlatformRevenue;

    // Gift volume is reported in coins / diamonds (real ledger totals), never converted with an assumed ratio
    const giftCoinsVolume = Number(giftVolumeAgg._sum?.totalCoins || 0n);
    const giftHostDiamonds = Number(giftVolumeAgg._sum?.hostDiamonds || 0n);

    return res.status(200).json({
      success: true,
      message: 'Finance dashboard statistics retrieved successfully',
      data: {
        grossRechargeRevenue,
        netPlatformRevenue,
        hostEarnings,
        agencyCommission,
        platformProfit,
        giftCoinsVolume,
        giftHostDiamonds,
        pendingSettlement,
        totalRevenueUSD: grossRechargeRevenue,
        totalWithdrawnUSD,
        netPlatformEarningsUSD: grossRechargeRevenue - totalWithdrawnUSD,
        totalCoinsInCirculation: Number(walletStats.totalCoins || 0n),
        totalDiamondsInCirculation: Number(walletStats.totalDiamonds || 0n),
      },
    });
  } catch (err) {
    next(err);
  }
}

export async function getRevenueChart(req, res, next) {
  try {
    const period = String(req.query?.period || 'Week').toLowerCase();
    const now = new Date();
    const isDay = period === 'day';
    const spanCount = isDay ? 24 : period === 'month' ? 30 : 7;
    const stepMs = isDay ? 3600000 : 86400000;
    const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    const keyOf = (d) => (isDay ? d.toISOString().slice(0, 13) : d.toISOString().slice(0, 10));
    const buckets = [];
    for (let i = spanCount - 1; i >= 0; i--) {
      const d = new Date(now.getTime() - i * stepMs);
      buckets.push({
        key: keyOf(d),
        date: d.toISOString(),
        label: isDay ? `${String(d.getUTCHours()).padStart(2, '0')}:00` : (period === 'month' ? d.toISOString().slice(5, 10) : dayNames[d.getUTCDay()]),
        revenue: 0,
      });
    }
    const since = new Date(now.getTime() - spanCount * stepMs);

    const [online, offline] = await Promise.all([
      prisma.onlineRecharge
        ? prisma.onlineRecharge.findMany({
            where: { status: 'SUCCESS', createdAt: { gte: since } },
            select: { amountUSD: true, createdAt: true },
          })
        : [],
      prisma.offlineRecharge
        ? prisma.offlineRecharge.findMany({
            where: { status: 'APPROVED', createdAt: { gte: since } },
            select: { amountUSD: true, createdAt: true },
          })
        : [],
    ]);

    for (const r of [...online, ...offline]) {
      const bucket = buckets.find((b) => b.key === keyOf(r.createdAt));
      if (bucket) bucket.revenue += Number(r.amountUSD || 0);
    }

    const chartData = buckets.map(({ key, ...rest }) => rest);

    return res.status(200).json({
      success: true,
      message: 'Revenue chart retrieved successfully',
      data: chartData,
    });
  } catch (err) {
    next(err);
  }
}

export default {
  getMasterLedger,
  getRechargePlans,
  createRechargePlan,
  updateRechargePlan,
  deleteRechargePlan,
  getOfflineRecharges,
  approveOfflineRecharge,
  rejectOfflineRecharge,
  getWithdrawals,
  approveWithdrawal,
  rejectWithdrawal,
  getWithdrawalRecipients,
  createWithdrawalRequest,
  getCoinRefunds,
  submitCoinRefund,
  processCoinRefund,
  rejectCoinRefund,
  getFinanceDashboard,
  getRevenueChart,
};

