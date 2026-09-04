import rechargeRepository from '../repositories/recharge.repository.js';
import walletRepository from '../repositories/wallet.repository.js';
import ledgerService from './ledger.service.js';
import policyService from './policy.service.js';
import { sanitizeFinancial } from '../utils/bigint.util.js';
import prisma from '../config/database.js';

export const COINS_PER_USD = 10000n; // 1 USD = 10,000 Coins baseline default

export async function getRechargePlans({ includeInactive = false } = {}) {
  const plans = await rechargeRepository.findAllPlans({ includeInactive });
  return plans.map((p) => sanitizeFinancial(p));
}

export async function createRechargePlan(data, adminId, isOwner, ipAddress) {
  const plan = await rechargeRepository.createPlan(data);

  await prisma.auditLog.create({
    data: {
      adminId,
      adminName: isOwner ? 'Root Owner' : 'Administrator',
      action: 'RECHARGE_PLAN_CREATED',
      targetEntity: 'RechargePlan',
      targetEntityId: plan.id,
      afterStateJson: sanitizeFinancial(plan),
      ipAddress,
    },
  }).catch(() => {});

  return sanitizeFinancial(plan);
}

export async function updateRechargePlan(id, data, adminId, isOwner, ipAddress) {
  const plan = await rechargeRepository.updatePlan(id, data);

  await prisma.auditLog.create({
    data: {
      adminId,
      adminName: isOwner ? 'Root Owner' : 'Administrator',
      action: 'RECHARGE_PLAN_UPDATED',
      targetEntity: 'RechargePlan',
      targetEntityId: plan.id,
      afterStateJson: sanitizeFinancial(plan),
      ipAddress,
    },
  }).catch(() => {});

  return sanitizeFinancial(plan);
}

export async function getOfflineRecharges({ status, userId, page = 1, limit = 20 }) {
  const items = await rechargeRepository.findAllOfflineRecharges({ status, userId, page, limit });
  const total = await rechargeRepository.countOfflineRecharges({ status, userId });

  return {
    items: items.map((i) => sanitizeFinancial(i)),
    pagination: {
      page: Number(page),
      limit: Number(limit),
      total,
      totalPages: Math.ceil(total / limit) || 1,
    },
  };
}

export async function approveOfflineRecharge({ id, adminId, isOwner = false, ipAddress }) {
  const record = await rechargeRepository.findOfflineRechargeById(id);
  if (!record) {
    const error = new Error('Offline recharge request not found');
    error.status = 404;
    error.code = 'NOT_FOUND';
    throw error;
  }

  if (record.status !== 'PENDING') {
    const error = new Error(`Request has already been processed with status: ${record.status}`);
    error.status = 400;
    error.code = 'ALREADY_PROCESSED';
    throw error;
  }

  const wallet = await walletRepository.findByUserId(record.userId);
  if (!wallet) {
    const error = new Error('User wallet not found');
    error.status = 404;
    error.code = 'WALLET_NOT_FOUND';
    throw error;
  }

  const amountUSD = Number(record.amountUSD);
  const effectiveConfig = await policyService.getEffectiveConfig('USD_TO_COIN_RATE');
  const rateRatio = effectiveConfig?.value?.rate ? BigInt(effectiveConfig.value.rate) : COINS_PER_USD;
  const coinsCredited = BigInt(Math.floor(amountUSD)) * rateRatio;

  return await prisma.$transaction(async (tx) => {
    // 1. Update OfflineRecharge status
    const updated = await rechargeRepository.updateOfflineRechargeStatus(
      id,
      {
        status: 'APPROVED',
        reviewerAdminId: adminId,
        reviewedAt: new Date(),
      },
      tx
    );

    // 2. Post atomic ledger credit and increment totalRechargedUSD
    const ledgerResult = await ledgerService.postTransaction({
      operations: [
        {
          walletId: wallet.id,
          coinDelta: coinsCredited,
          usdDelta: amountUSD,
          rechargedDeltaUSD: amountUSD,
        },
      ],
      referenceId: record.transactionRef || `OFF-${record.id}`,
      transactionType: 'RECHARGE',
      db: tx,
    });

    // 3. Emit AuditLog
    await tx.auditLog.create({
      data: {
        adminId,
        adminName: isOwner ? 'Root Owner' : 'Administrator',
        action: 'OFFLINE_RECHARGE_APPROVED',
        targetEntity: 'OfflineRecharge',
        targetEntityId: id,
        afterStateJson: {
          coinsCredited: coinsCredited.toString(),
          amountUSD,
          referenceId: ledgerResult.referenceId,
        },
        reason: `Approved offline deposit for ${record.user?.username}`,
        ipAddress,
      },
    });

    return {
      success: true,
      message: 'Offline recharge approved and coins credited successfully.',
      recharge: sanitizeFinancial(updated),
      ledger: ledgerResult,
    };
  });
}

export async function rejectOfflineRecharge({ id, adminId, isOwner = false, reason, ipAddress }) {
  const record = await rechargeRepository.findOfflineRechargeById(id);
  if (!record) {
    const error = new Error('Offline recharge request not found');
    error.status = 404;
    error.code = 'NOT_FOUND';
    throw error;
  }

  if (record.status !== 'PENDING') {
    const error = new Error(`Request has already been processed with status: ${record.status}`);
    error.status = 400;
    error.code = 'ALREADY_PROCESSED';
    throw error;
  }

  return await prisma.$transaction(async (tx) => {
    const updated = await rechargeRepository.updateOfflineRechargeStatus(
      id,
      {
        status: 'REJECTED',
        reviewerAdminId: adminId,
        reviewedAt: new Date(),
      },
      tx
    );

    await tx.auditLog.create({
      data: {
        adminId,
        adminName: isOwner ? 'Root Owner' : 'Administrator',
        action: 'OFFLINE_RECHARGE_REJECTED',
        targetEntity: 'OfflineRecharge',
        targetEntityId: id,
        reason,
        ipAddress,
      },
    });

    return {
      success: true,
      message: 'Offline recharge request rejected.',
      recharge: sanitizeFinancial(updated),
    };
  });
}

export default {
  getRechargePlans,
  createRechargePlan,
  updateRechargePlan,
  getOfflineRecharges,
  approveOfflineRecharge,
  rejectOfflineRecharge,
};
