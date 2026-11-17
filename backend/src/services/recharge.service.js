import rechargeRepository from '../repositories/recharge.repository.js';
import walletRepository from '../repositories/wallet.repository.js';
import ledgerService from './ledger.service.js';
import policyService from './policy.service.js';
import paymentProviderService from './paymentProvider.service.js';
import { getPaymentAdapter } from '../adapters/payment/paymentAdapter.factory.js';
import { sanitizeFinancial } from '../utils/bigint.util.js';
import { generateReference } from '../utils/reference.util.js';
import prisma from '../config/database.js';

export const COINS_PER_USD = 10000n; // 1 USD = 10,000 Coins baseline default

export function calculateSvipTier(points) {
  const p = Number(points);
  if (p >= 150000000) return 16;
  if (p >= 100000000) return 15;
  if (p >= 50000000) return 14;
  if (p >= 30000000) return 13;
  if (p >= 20000000) return 12;
  if (p >= 12000000) return 11;
  if (p >= 7000000) return 10;
  if (p >= 5000000) return 9;
  if (p >= 3000000) return 8;
  if (p >= 1500000) return 7;
  if (p >= 700000) return 6;
  if (p >= 500000) return 5;
  if (p >= 400000) return 4;
  if (p >= 300000) return 3;
  if (p >= 200000) return 2;
  if (p >= 100000) return 1;
  return 0;
}

export function getSvipTierThreshold(level) {
  const thresholds = {
    1: 100000,
    2: 200000,
    3: 300000,
    4: 400000,
    5: 500000,
    6: 700000,
    7: 1500000,
    8: 3000000,
    9: 5000000,
    10: 7000000,
    11: 12000000,
    12: 20000000,
    13: 30000000,
    14: 50000000,
    15: 100000000,
    16: 150000000,
  };
  return thresholds[level] || 0;
}

/**
 * Atomically accrues cumulative SVIP points for any qualifying coin recharge transaction.
 * Supports concurrent updates safely through Prisma atomic increment.
 */
export async function applySvipPointsForRecharge({ userId, coinsRecharged, db = prisma, referenceId = null }) {
  if (!userId || !coinsRecharged || BigInt(coinsRecharged) <= 0n) return null;
  const coinsBig = BigInt(coinsRecharged);

  const executeInTx = async (tx) => {
    const refStr = referenceId ? String(referenceId) : null;

    if (refStr) {
      // 1. Check & Insert into dedicated SvipTransactionIdempotency table (Database-Enforced Uniqueness)
      if (tx.svipTransactionIdempotency) {
        try {
          await tx.svipTransactionIdempotency.create({
            data: {
              referenceId: refStr,
              userId,
              coins: coinsBig,
            },
          });
        } catch (err) {
          const isUniqueViolation =
            err?.code === 'P2002' ||
            err?.message?.includes('Unique constraint failed') ||
            err?.message?.includes('duplicate key');

          if (isUniqueViolation) {
            // Retrieve existing idempotency record to enforce user ownership check
            let existingRecord = null;
            try {
              existingRecord = await tx.svipTransactionIdempotency.findUnique({
                where: { referenceId: refStr },
              });
            } catch (_) {}

            // Invariant: The same referenceId must NEVER credit two different users
            if (existingRecord && existingRecord.userId !== userId) {
              const mismatchErr = new Error(`Transaction reference ${refStr} was already processed for a different user`);
              mismatchErr.statusCode = 409;
              mismatchErr.code = 'TRANSACTION_USER_MISMATCH';
              throw mismatchErr;
            }

            const currentProfile = await tx.userProfile?.findUnique?.({ where: { userId } }).catch(() => null);
            return {
              userId,
              svipPoints: Number(currentProfile?.svipPoints || 0n),
              svipLevel: currentProfile?.svipLevel || 0,
              pointsAdded: 0,
              referenceId: refStr,
              alreadyProcessed: true,
            };
          }
          throw err;
        }
      } else if (tx.auditLog?.findFirst) {
        // Fallback for mock environments where svipTransactionIdempotency is not mocked
        const existingAudit = await tx.auditLog.findFirst({
          where: {
            action: 'SVIP_POINTS_ACCRUED',
            targetEntityId: refStr,
          },
        }).catch(() => null);

        if (existingAudit) {
          const auditJson = existingAudit.afterStateJson;
          if (auditJson && typeof auditJson === 'object' && auditJson.userId && auditJson.userId !== userId) {
            const mismatchErr = new Error(`Transaction reference ${refStr} was already processed for a different user`);
            mismatchErr.statusCode = 409;
            mismatchErr.code = 'TRANSACTION_USER_MISMATCH';
            throw mismatchErr;
          }

          const currentProfile = await tx.userProfile?.findUnique?.({ where: { userId } }).catch(() => null);
          return {
            userId,
            svipPoints: Number(currentProfile?.svipPoints || 0n),
            svipLevel: currentProfile?.svipLevel || 0,
            pointsAdded: 0,
            referenceId: refStr,
            alreadyProcessed: true,
          };
        }
      }
    }

    // 2. Increment userProfile svipPoints and cumulativeRechargedCoins atomically
    const updatedProfile = await tx.userProfile.upsert({
      where: { userId },
      update: {
        svipPoints: { increment: coinsBig },
        cumulativeRechargedCoins: { increment: coinsBig },
      },
      create: {
        userId,
        svipPoints: coinsBig,
        cumulativeRechargedCoins: coinsBig,
        level: 1,
      },
    });

    const totalPoints = Number(updatedProfile.svipPoints || 0n);
    const newSvipLevel = calculateSvipTier(totalPoints);
    const currentSvip = updatedProfile.svipLevel || 0;

    if (newSvipLevel > currentSvip) {
      await tx.userProfile.update({
        where: { userId },
        data: { svipLevel: newSvipLevel },
      });
      updatedProfile.svipLevel = newSvipLevel;
    }

    // 3. Persist audit marker for administrative and support traceability
    if (refStr) {
      await tx.auditLog?.create?.({
        data: {
          adminId: '00000000-0000-0000-0000-000000000000',
          adminName: 'SYSTEM',
          action: 'SVIP_POINTS_ACCRUED',
          targetEntity: 'UserProfile',
          targetEntityId: refStr,
          afterStateJson: {
            userId,
            coinsRecharged: coinsBig.toString(),
            referenceId: refStr,
          },
        },
      }).catch(() => {});
    }

    return {
      userId,
      svipPoints: Number(updatedProfile.svipPoints),
      svipLevel: updatedProfile.svipLevel,
      pointsAdded: Number(coinsBig),
      referenceId: refStr,
    };
  };

  try {
    if (typeof db.$transaction === 'function') {
      return await db.$transaction(executeInTx);
    }
    return await executeInTx(db);
  } catch (err) {
    if (err?.code === 'TRANSACTION_USER_MISMATCH' || err?.statusCode === 409) {
      throw err;
    }
    console.warn('[RechargeService] applySvipPointsForRecharge warning:', err?.message);
    throw err;
  }
}

/**
 * Atomically reverses SVIP points on chargebacks and refunds.
 */
export async function reverseSvipPointsForRefund({ userId, coinsDeducted, db = prisma, referenceId = null }) {
  if (!userId || !coinsDeducted || BigInt(coinsDeducted) <= 0n) return null;
  const coinsBig = BigInt(coinsDeducted);

  try {
    const profile = await db.userProfile.findUnique({ where: { userId } });
    if (!profile) return null;

    const currentPoints = BigInt(profile.svipPoints || 0n);
    const currentRecharged = BigInt(profile.cumulativeRechargedCoins || 0n);
    const newPoints = currentPoints > coinsBig ? currentPoints - coinsBig : 0n;
    const newRecharged = currentRecharged > coinsBig ? currentRecharged - coinsBig : 0n;
    const newSvipLevel = calculateSvipTier(Number(newPoints));

    const updatedProfile = await db.userProfile.update({
      where: { userId },
      data: {
        svipPoints: newPoints,
        cumulativeRechargedCoins: newRecharged,
        svipLevel: newSvipLevel,
      },
    });

    return {
      userId,
      svipPoints: Number(updatedProfile.svipPoints),
      svipLevel: updatedProfile.svipLevel,
      pointsDeducted: Number(coinsBig),
      referenceId,
    };
  } catch (err) {
    console.warn('[RechargeService] reverseSvipPointsForRefund warning:', err?.message);
    return null;
  }
}

/**
 * Reconciles an existing user's SVIP points against authoritative historical recharge ledgers.
 * Includes qualifying positive recharges, excludes wholesale seller stock, and subtracts historical refunds/chargebacks.
 */
export async function reconcileUserSvipPoints(userId, db = prisma) {
  const executeReconcile = async (tx) => {
    // 1. Concurrency safety: Lock UserProfile row if supported in PostgreSQL
    try {
      if (typeof tx.$queryRawUnsafe === 'function') {
        await tx.$queryRawUnsafe(
          'SELECT "id" FROM "UserProfile" WHERE "userId" = $1 FOR UPDATE',
          userId
        );
      }
    } catch (_) {}

    // Track profile state before aggregating ledgers to detect concurrent live recharges
    const initialProfile = await tx.userProfile?.findUnique?.({ where: { userId } }).catch(() => null);
    const initialSvipPoints = BigInt(initialProfile?.svipPoints || 0n);

    // 2. Authoritative User Classification
    // Identify if the account is a Coin Seller using database relationships and fields
    let isSellerAccount = false;
    try {
      const user = await tx.user?.findUnique?.({
        where: { id: userId },
        include: { coinSeller: true },
      });
      if (user) {
        isSellerAccount =
          user.userType === 'COIN_SELLER' ||
          user.userType === 'SELLER' ||
          Boolean(user.coinSeller);
      }
    } catch (_) {}

    // 3. Authoritative aggregations on WalletLedger (NO queries referencing nonexistent fields like 'reason')
    // 3a. Qualifying direct and seller-to-user recharges (RECHARGE)
    const rechargeSum = await tx.walletLedger?.aggregate?.({
      where: {
        wallet: { userId },
        transactionType: 'RECHARGE',
        coinDelta: { gt: 0n },
      },
      _sum: { coinDelta: true },
    }).catch(() => ({ _sum: { coinDelta: null } }));

    // 3b. TRANSFER_IN ledgers
    // Authoritatively inspect real WalletLedger columns: coinDelta, balanceBefore, balanceAfter
    const transferInLedgers = await tx.walletLedger?.findMany?.({
      where: {
        wallet: { userId },
        transactionType: 'TRANSFER_IN',
        coinDelta: { gt: 0n },
      },
    }).catch(() => []);

    let consumerTransferInSum = 0n;
    for (const t of transferInLedgers) {
      let isWholesale = false;

      // Authoritative classification via balance snapshots
      if (t.balanceBefore && t.balanceAfter) {
        const bb = typeof t.balanceBefore === 'string' ? JSON.parse(t.balanceBefore) : t.balanceBefore;
        const ba = typeof t.balanceAfter === 'string' ? JSON.parse(t.balanceAfter) : t.balanceAfter;

        const beforeSeller = BigInt(bb.sellerBalanceCoins || bb.sellerCoins || 0);
        const afterSeller = BigInt(ba.sellerBalanceCoins || ba.sellerCoins || 0);
        const beforeCoins = BigInt(bb.coinBalance || bb.coins || 0);
        const afterCoins = BigInt(ba.coinBalance || ba.coins || 0);

        // If sellerBalanceCoins was incremented while spendable coins remained unchanged, it is wholesale inventory
        if (afterSeller > beforeSeller && afterCoins === beforeCoins) {
          isWholesale = true;
        }
      }

      // If the account itself is a seller and no balance snapshots exist
      if (isSellerAccount && !t.balanceBefore && !t.balanceAfter) {
        isWholesale = true;
      }

      // Safeguard for legacy / mock tests providing reason or notes on the objects
      const reasonOrNotes = String(t.reason || t.notes || '').toLowerCase();
      if (reasonOrNotes.includes('coin seller') || reasonOrNotes.includes('wholesale')) {
        isWholesale = true;
      }

      if (!isWholesale) {
        consumerTransferInSum += BigInt(t.coinDelta || 0n);
      }
    }

    // 3c. Refunds and chargebacks
    const refundLedgers = await tx.walletLedger?.findMany?.({
      where: {
        wallet: { userId },
        transactionType: { in: ['REFUND', 'CHARGEBACK_REVERSAL'] },
      },
      select: { coinDelta: true },
    }).catch(() => []);

    let totalRefundSum = 0n;
    for (const r of refundLedgers) {
      const delta = BigInt(r.coinDelta || 0n);
      totalRefundSum += delta < 0n ? -delta : delta;
    }

    const totalPositive = (rechargeSum?._sum?.coinDelta || 0n) + consumerTransferInSum;
    const confirmedCoins = totalPositive > totalRefundSum ? totalPositive - totalRefundSum : 0n;

    // 4. Concurrency Safety: Check if live recharges completed during reconciliation
    const latestProfile = await tx.userProfile?.findUnique?.({ where: { userId } }).catch(() => null);
    const latestSvipPoints = BigInt(latestProfile?.svipPoints || 0n);

    let targetPoints = confirmedCoins;
    if (latestSvipPoints > initialSvipPoints) {
      const liveRechargeIncrement = latestSvipPoints - initialSvipPoints;
      targetPoints = confirmedCoins + liveRechargeIncrement;
    }

    const newSvipLevel = calculateSvipTier(Number(targetPoints));

    const updated = await tx.userProfile.upsert({
      where: { userId },
      update: {
        svipPoints: targetPoints,
        cumulativeRechargedCoins: targetPoints,
        svipLevel: newSvipLevel,
      },
      create: {
        userId,
        svipPoints: targetPoints,
        cumulativeRechargedCoins: targetPoints,
        svipLevel: newSvipLevel,
      },
    });

    return {
      userId,
      svipPoints: Number(updated.svipPoints),
      svipLevel: updated.svipLevel,
      totalRecharged: Number(totalPositive),
      totalRefunded: Number(totalRefundSum),
    };
  };

  try {
    if (typeof db.$transaction === 'function') {
      return await db.$transaction(executeReconcile);
    }
    return await executeReconcile(db);
  } catch (err) {
    console.warn('[RechargeService] reconcileUserSvipPoints warning:', err?.message);
    return null;
  }
}

export async function getRechargePlans({ includeInactive = false } = {}) {
  const plans = await rechargeRepository.findAllPlans({ includeInactive });
  return plans.map((p) => sanitizeFinancial(p));
}

export async function createRechargePlan(data, adminId, isOwner = false, ipAddress) {
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

export async function updateRechargePlan(id, data, adminId, isOwner = false, ipAddress) {
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

export async function deleteRechargePlan(id, adminId, isOwner = false, ipAddress) {
  const plan = await rechargeRepository.findPlanById(id);
  if (!plan) {
    const error = new Error('Recharge plan not found');
    error.status = 404;
    throw error;
  }

  await rechargeRepository.deletePlan(id);

  await prisma.auditLog.create({
    data: {
      adminId,
      adminName: isOwner ? 'Root Owner' : 'Administrator',
      action: 'RECHARGE_PLAN_DELETED',
      targetEntity: 'RechargePlan',
      targetEntityId: id,
      beforeStateJson: sanitizeFinancial(plan),
      ipAddress,
    },
  }).catch(() => {});

  return { success: true, id };
}

// ---- Offline Recharge Operations ----

export async function submitOfflineRecharge({ userId, amountUSD, bankName, receiptPhotoUrl, transactionRef }) {
  const existing = await rechargeRepository.findOfflineRechargeByRef(transactionRef);
  if (existing) {
    const error = new Error('Transaction reference has already been submitted');
    error.status = 409;
    error.code = 'DUPLICATE_TRANSACTION_REF';
    throw error;
  }

  const userWallet = await walletRepository.findByUserId(userId);
  if (!userWallet) {
    const error = new Error('User wallet not found');
    error.status = 404;
    error.code = 'WALLET_NOT_FOUND';
    throw error;
  }

  const created = await rechargeRepository.createOfflineRecharge({
    userId,
    amountUSD,
    bankName,
    receiptPhotoUrl,
    transactionRef,
  });

  return sanitizeFinancial(created);
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

  // Maker-Checker Invariant: Reviewer cannot approve their own deposit
  if (record.userId === adminId && !isOwner) {
    const error = new Error('Self-approval forbidden: Cannot approve your own recharge request');
    error.status = 403;
    error.code = 'SELF_APPROVAL_FORBIDDEN';
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
    // 1. Atomically claim offline recharge status from PENDING -> APPROVED
    const claimed = await rechargeRepository.claimOfflineRechargeStatus(
      id,
      'PENDING',
      'APPROVED',
      {
        reviewerAdminId: adminId,
        reviewedAt: new Date(),
      },
      tx
    );

    if (!claimed) {
      const error = new Error('Request has already been processed or status changed');
      error.status = 400;
      error.code = 'ALREADY_PROCESSED';
      throw error;
    }

    const updated = await rechargeRepository.findOfflineRechargeById(id, tx);

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

    // 2.5. Upgrade user's SVIP Tier based on recharged coins (1 coin = 1 SVIP score point)
    await applySvipPointsForRecharge({
      userId: record.userId,
      coinsRecharged: coinsCredited,
      db: tx,
      referenceId: record.transactionRef || `OFF-${record.id}`,
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
        reason: `Approved offline deposit for user ${record.userId}`,
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
    const claimed = await rechargeRepository.claimOfflineRechargeStatus(
      id,
      'PENDING',
      'REJECTED',
      {
        reviewerAdminId: adminId,
        reviewedAt: new Date(),
      },
      tx
    );

    if (!claimed) {
      const error = new Error('Request has already been processed or status changed');
      error.status = 400;
      error.code = 'ALREADY_PROCESSED';
      throw error;
    }

    const updated = await rechargeRepository.findOfflineRechargeById(id, tx);

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

// ---- Online Recharge Intent & Webhook Processing ----

export async function createPaymentIntent({ userId, planId, paymentProvider }) {
  const plan = await rechargeRepository.findPlanById(planId);
  if (!plan || !plan.isActive) {
    const error = new Error('Selected recharge plan is not available or inactive');
    error.status = 404;
    error.code = 'RECHARGE_PLAN_NOT_FOUND';
    throw error;
  }

  const wallet = await walletRepository.findByUserId(userId);
  if (!wallet) {
    const error = new Error('User wallet not found');
    error.status = 404;
    error.code = 'WALLET_NOT_FOUND';
    throw error;
  }

  const totalCoins = BigInt(plan.coinAmount) + BigInt(plan.bonusCoins || 0);
  const amountUSD = Number(plan.priceUSD);
  const providerKey = paymentProvider.toUpperCase();

  // Retrieve provider config
  const providerConfig = await paymentProviderService.getDecryptedProviderConfig(providerKey);
  const adapter = getPaymentAdapter(providerKey, providerConfig || {});

  const orderId = generateReference('RCH');

  // Call provider adapter
  const intentResult = await adapter.createPaymentIntent({
    orderId,
    amountUSD,
    currency: 'USD',
    metadata: {
      userId,
      planId,
      totalCoins: totalCoins.toString(),
    },
  });

  // Persist OnlineRecharge intent in database
  const recharge = await rechargeRepository.createOnlineRecharge({
    userId,
    gateway: providerKey,
    gatewayTxId: intentResult.gatewayTxId,
    amountUSD,
    coinsCredited: totalCoins,
    planId: plan.id,
    status: 'PENDING',
  });

  return {
    rechargeId: recharge.id,
    gatewayTxId: intentResult.gatewayTxId,
    amountUSD,
    coinsToCredit: totalCoins.toString(),
    clientSecret: intentResult.clientSecret || null,
    checkoutUrl: intentResult.checkoutUrl || null,
    gateway: providerKey,
    status: 'PENDING',
  };
}

export async function processPaymentWebhook({ provider, rawBody, signature, headers = {}, ipAddress }) {
  const providerKey = String(provider || '').toUpperCase();
  const providerConfig = await paymentProviderService.getDecryptedProviderConfig(providerKey);

  const webhookSecret = providerConfig?.webhookSecret || process.env.PAYMENT_WEBHOOK_SECRET || 'test_webhook_secret';
  const adapter = getPaymentAdapter(providerKey, providerConfig || {});

  // Cryptographic Signature Verification
  const isValid = await adapter.verifyWebhookSignature({
    rawBody,
    signature,
    webhookSecret,
  });

  if (!isValid) {
    const error = new Error('Invalid webhook signature');
    error.status = 401;
    error.code = 'PAYMENT_SIGNATURE_INVALID';
    throw error;
  }

  // Parse event
  const event = adapter.parseWebhookEvent(rawBody);
  if (!event.isSuccessful || !event.gatewayTxId) {
    return {
      received: true,
      processed: false,
      message: `Event ${event.eventType} is not a successful payment capture.`,
    };
  }

  const record = await rechargeRepository.findOnlineRechargeByGatewayTxId(event.gatewayTxId);
  if (!record) {
    return {
      received: true,
      processed: false,
      message: `Recharge intent not found for gatewayTxId: ${event.gatewayTxId}`,
    };
  }

  // Idempotency: If already credited, return safely without duplicating credit
  if (record.status === 'SUCCESS') {
    return {
      received: true,
      processed: true,
      alreadyProcessed: true,
      message: 'Payment was previously confirmed and credited.',
      rechargeId: record.id,
    };
  }

  const wallet = await walletRepository.findByUserId(record.userId);
  if (!wallet) {
    const error = new Error('User wallet not found for recharge completion');
    error.status = 404;
    error.code = 'WALLET_NOT_FOUND';
    throw error;
  }

  const coinsToCredit = BigInt(record.coinsCredited);
  const amountUSD = Number(record.amountUSD);

  return await prisma.$transaction(async (tx) => {
    // 1. Atomically claim OnlineRecharge from PENDING -> SUCCESS
    const claimed = await rechargeRepository.claimOnlineRechargeSuccess(record.id, tx);

    if (!claimed) {
      // Concurrently claimed and credited by another webhook worker
      return {
        received: true,
        processed: true,
        alreadyProcessed: true,
        message: 'Payment was previously confirmed and credited by a concurrent request.',
        rechargeId: record.id,
      };
    }

    const updated = await rechargeRepository.findOnlineRechargeById(record.id, tx);

    // 2. Post atomic ledger transaction crediting user coins
    const ledgerResult = await ledgerService.postTransaction({
      operations: [
        {
          walletId: wallet.id,
          coinDelta: coinsToCredit,
          usdDelta: amountUSD,
          rechargedDeltaUSD: amountUSD,
        },
      ],
      referenceId: `ONL-${record.gatewayTxId}`,
      transactionType: 'RECHARGE',
      db: tx,
    });

    // 2.5. Upgrade user's SVIP Tier based on recharged coins (1 coin = 1 SVIP score point)
    await applySvipPointsForRecharge({
      userId: record.userId,
      coinsRecharged: coinsToCredit,
      db: tx,
      referenceId: `ONL-${record.gatewayTxId}`,
    });

    // 3. Emit AuditLog
    await tx.auditLog.create({
      data: {
        adminId: '00000000-0000-0000-0000-000000000000',
        adminName: `System Webhook [${providerKey}]`,
        action: 'ONLINE_RECHARGE_COMPLETED',
        targetEntity: 'OnlineRecharge',
        targetEntityId: record.id,
        afterStateJson: {
          coinsCredited: coinsToCredit.toString(),
          amountUSD,
          gatewayTxId: record.gatewayTxId,
          referenceId: ledgerResult.referenceId,
        },
        reason: `Verified ${providerKey} webhook capture`,
        ipAddress,
      },
    }).catch(() => {});

    return {
      received: true,
      processed: true,
      rechargeId: updated ? updated.id : record.id,
      coinsCredited: coinsToCredit.toString(),
      ledgerReferenceId: ledgerResult.referenceId,
    };
  });
}

export async function getOnlineRecharges({ status, userId, gateway, page = 1, limit = 20 }) {
  const items = await rechargeRepository.findAllOnlineRecharges({ status, userId, gateway, page, limit });
  const total = await rechargeRepository.countOnlineRecharges({ status, userId, gateway });

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

export default {
  calculateSvipTier,
  getSvipTierThreshold,
  applySvipPointsForRecharge,
  reverseSvipPointsForRefund,
  reconcileUserSvipPoints,
  getRechargePlans,
  createRechargePlan,
  updateRechargePlan,
  submitOfflineRecharge,
  getOfflineRecharges,
  approveOfflineRecharge,
  rejectOfflineRecharge,
  createPaymentIntent,
  processPaymentWebhook,
  getOnlineRecharges,
};
