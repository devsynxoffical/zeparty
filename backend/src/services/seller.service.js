import prisma from '../config/database.js';
import sellerRepository from '../repositories/seller.repository.js';
import walletRepository from '../repositories/wallet.repository.js';
import ledgerService from './ledger.service.js';
import approvalService from './approval.service.js';
import policyService from './policy.service.js';
import { generateReference } from '../utils/reference.util.js';

async function logAudit({ adminId, adminName, action, targetEntity, targetEntityId, beforeStateJson, afterStateJson, reason, ipAddress }, db = prisma) {
  try {
    await db.auditLog.create({
      data: {
        adminId: adminId || 'SYSTEM',
        adminName: adminName || 'System',
        action,
        targetEntity,
        targetEntityId: targetEntityId || null,
        beforeStateJson: beforeStateJson ? JSON.parse(JSON.stringify(beforeStateJson)) : null,
        afterStateJson: afterStateJson ? JSON.parse(JSON.stringify(afterStateJson)) : null,
        reason: reason || null,
        ipAddress: ipAddress || '127.0.0.1',
      },
    });
  } catch (err) {
    console.error('Failed to write audit log in seller.service:', err);
  }
}

export async function createSeller(data, { adminId, adminName, ipAddress } = {}, db = prisma) {
  let user = null;
  if (data.userId) {
    user = await db.user.findUnique({ where: { id: data.userId } });
    if (!user) {
      user = await db.user.findUnique({ where: { username: data.userId } });
    }
  }
  if (!user && data.username) {
    user = await db.user.findUnique({ where: { username: data.username.replace('@', '').trim() } });
  }

  if (!user) {
    const rawUsername = (data.username || data.userId || `seller_${Date.now()}`).replace('@', '').trim();
    const cleanPhone = `+1999${Math.floor(1000000 + Math.random() * 9000000)}`;
    user = await db.user.create({
      data: {
        username: rawUsername,
        phone: cleanPhone,
        email: data.email || `${rawUsername}@zeparty.seller`,
        userType: 'COIN_SELLER',
        status: 'ACTIVE',
        countryCode: data.countryCode || data.country || 'US',
        avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
        profile: {
          create: {
            displayName: data.businessName || rawUsername,
          },
        },
        wallet: {
          create: {
            coinBalance: 0n,
            diamondBalance: 0n,
            sellerBalanceCoins: data.initialCoins ? BigInt(data.initialCoins) : (data.initialCredit ? BigInt(data.initialCredit) : 0n),
          },
        },
      },
    });
  }

  const userId = user.id;
  const existing = await sellerRepository.findSellerByUserId(userId, db);
  if (existing) {
    const error = new Error('User is already registered as a coin seller');
    error.statusCode = 409;
    error.code = 'SELLER_ALREADY_EXISTS';
    throw error;
  }

  // Ensure user has a wallet
  let wallet = await walletRepository.findByUserId(userId, db);
  if (!wallet) {
    wallet = await walletRepository.createWallet(userId, db);
  }

  const initialQuota = data.initialCoins ? BigInt(data.initialCoins) : (data.initialCredit ? BigInt(data.initialCredit) : 0n);

  const seller = await db.$transaction(async (tx) => {
    const newSeller = await sellerRepository.createSeller({
      ...data,
      userId,
      resellerBalanceCoins: initialQuota,
    }, tx);

    // Update userType to COIN_SELLER
    await tx.user.update({
      where: { id: userId },
      data: { userType: 'COIN_SELLER' },
    });

    if (initialQuota > 0n) {
      await tx.wallet.update({
        where: { userId },
        data: { sellerBalanceCoins: { increment: initialQuota } },
      });
    }

    return newSeller;
  });

  await logAudit({
    adminId,
    adminName,
    action: 'COIN_SELLER_CREATED',
    targetEntity: 'CoinSeller',
    targetEntityId: seller.id,
    afterStateJson: {
      userId: seller.userId,
      businessName: seller.businessName,
      profitMarginPercent: seller.profitMarginPercent,
      creditLimitUSD: seller.creditLimitUSD,
    },
    ipAddress,
  }, db);

  return seller;
}

export async function updateSellerStatus(id, { sellerStatus, reason }, { adminId, adminName, ipAddress } = {}, db = prisma) {
  const seller = await sellerRepository.findSellerById(id, db);
  if (!seller) {
    const error = new Error('Coin seller not found');
    error.statusCode = 404;
    error.code = 'SELLER_NOT_FOUND';
    throw error;
  }

  const updatedSeller = await sellerRepository.updateSeller(id, { sellerStatus }, db);

  await logAudit({
    adminId,
    adminName,
    action: 'COIN_SELLER_STATUS_UPDATED',
    targetEntity: 'CoinSeller',
    targetEntityId: id,
    beforeStateJson: { sellerStatus: seller.sellerStatus },
    afterStateJson: { sellerStatus },
    reason,
    ipAddress,
  }, db);

  return updatedSeller;
}

export async function allocateCoinsToSeller(
  sellerId,
  { amountCoins, notes },
  { adminId, adminName, isOwner = false, ipAddress } = {},
  db = prisma
) {
  const coinsBigInt = BigInt(amountCoins);
  if (coinsBigInt <= 0n) {
    const error = new Error('Allocation amount must be a positive integer value');
    error.statusCode = 400;
    error.code = 'INVALID_ALLOCATION_AMOUNT';
    throw error;
  }

  const seller = await sellerRepository.findSellerById(sellerId, db);
  if (!seller) {
    const error = new Error('Coin seller not found');
    error.statusCode = 404;
    error.code = 'SELLER_NOT_FOUND';
    throw error;
  }

  if (seller.sellerStatus !== 'ACTIVE') {
    const error = new Error('Cannot allocate coins to an inactive/suspended coin seller');
    error.statusCode = 400;
    error.code = 'SELLER_NOT_ACTIVE';
    throw error;
  }

  // Ensure user has a wallet
  let wallet = await walletRepository.findByUserId(seller.userId, db);
  if (!wallet) {
    wallet = await walletRepository.createWallet(seller.userId, db);
  }

  // Check maker-checker two-stage approval threshold
  const needsApproval = !isOwner && approvalService.requiresApproval({
    asset: 'COINS',
    amount: coinsBigInt,
  });

  if (needsApproval) {
    const approval = await approvalService.createApprovalRequest(
      {
        requesterId: adminId,
        module: 'wallet',
        actionType: 'RESELLER_ALLOCATION',
        beforeStateJson: {
          sellerId,
          userId: seller.userId,
          currentSellerBalanceCoins: seller.resellerBalanceCoins.toString(),
        },
        payloadStateJson: {
          sellerId,
          userId: seller.userId,
          amountCoins: coinsBigInt.toString(),
          notes,
        },
      },
      db
    );

    return {
      requiresApproval: true,
      approvalId: approval.id,
      status: 'PENDING',
      message: 'Allocation exceeds threshold ($100 / 1,000,000 coins). Sent for maker-checker approval.',
    };
  }

  // Execute immediate allocation via ledgerService
  const refId = generateReference('ALLOC');
  const result = await db.$transaction(async (tx) => {
    // 1. Post to double-entry ledger (modifying sellerDelta)
    const ledgerTx = await ledgerService.postTransaction({
      operations: [
        {
          walletId: wallet.id,
          sellerDelta: coinsBigInt,
        },
      ],
      referenceId: refId,
      transactionType: 'RESELLER_ALLOCATION',
      db: tx,
    });

    // 2. Increment CoinSeller balance cache
    const updatedSeller = await sellerRepository.updateSellerBalance(sellerId, coinsBigInt, tx);

    return { ledgerTx, updatedSeller };
  });

  await logAudit({
    adminId,
    adminName,
    action: 'SELLER_COINS_ALLOCATED',
    targetEntity: 'CoinSeller',
    targetEntityId: sellerId,
    beforeStateJson: { resellerBalanceCoins: seller.resellerBalanceCoins.toString() },
    afterStateJson: {
      resellerBalanceCoins: result.updatedSeller.resellerBalanceCoins.toString(),
      allocatedCoins: coinsBigInt.toString(),
      referenceId: refId,
    },
    reason: notes,
    ipAddress,
  }, db);

  return {
    requiresApproval: false,
    success: true,
    allocatedCoins: coinsBigInt.toString(),
    newSellerBalanceCoins: result.updatedSeller.resellerBalanceCoins.toString(),
    referenceId: refId,
  };
}

export async function correctSellerBalance(
  sellerId,
  { deltaCoins, reason },
  { adminId, adminName, isOwner = false, ipAddress } = {},
  db = prisma
) {
  const deltaBigInt = BigInt(deltaCoins);
  if (deltaBigInt === 0n) {
    const error = new Error('Correction delta must be a non-zero integer amount');
    error.statusCode = 400;
    error.code = 'INVALID_DELTA';
    throw error;
  }

  const seller = await sellerRepository.findSellerById(sellerId, db);
  if (!seller) {
    const error = new Error('Coin seller not found');
    error.statusCode = 404;
    error.code = 'SELLER_NOT_FOUND';
    throw error;
  }

  const wallet = await walletRepository.findByUserId(seller.userId, db);
  if (!wallet) {
    const error = new Error('Seller wallet not found');
    error.statusCode = 404;
    error.code = 'WALLET_NOT_FOUND';
    throw error;
  }

  const absAmount = deltaBigInt < 0n ? -deltaBigInt : deltaBigInt;
  const needsApproval = !isOwner && approvalService.requiresApproval({
    asset: 'COINS',
    amount: absAmount,
  });

  if (needsApproval) {
    const approval = await approvalService.createApprovalRequest(
      {
        requesterId: adminId,
        module: 'wallet',
        actionType: 'ADMIN_ADJUSTMENT',
        beforeStateJson: {
          sellerId,
          userId: seller.userId,
          currentSellerBalanceCoins: seller.resellerBalanceCoins.toString(),
        },
        payloadStateJson: {
          sellerId,
          userId: seller.userId,
          deltaCoins: deltaBigInt.toString(),
          reason,
        },
      },
      db
    );

    return {
      requiresApproval: true,
      approvalId: approval.id,
      status: 'PENDING',
      message: 'Correction exceeds threshold ($100 / 1,000,000 coins). Sent for maker-checker approval.',
    };
  }

  const refId = generateReference('CORR');
  const result = await db.$transaction(async (tx) => {
    const ledgerTx = await ledgerService.postTransaction({
      operations: [
        {
          walletId: wallet.id,
          sellerDelta: deltaBigInt,
        },
      ],
      referenceId: refId,
      transactionType: 'ADMIN_ADJUSTMENT',
      db: tx,
    });

    const updatedSeller = await sellerRepository.updateSellerBalance(sellerId, deltaBigInt, tx);
    return { ledgerTx, updatedSeller };
  });

  await logAudit({
    adminId,
    adminName,
    action: 'SELLER_BALANCE_CORRECTED',
    targetEntity: 'CoinSeller',
    targetEntityId: sellerId,
    beforeStateJson: { resellerBalanceCoins: seller.resellerBalanceCoins.toString() },
    afterStateJson: {
      resellerBalanceCoins: result.updatedSeller.resellerBalanceCoins.toString(),
      deltaCoins: deltaBigInt.toString(),
      referenceId: refId,
    },
    reason,
    ipAddress,
  }, db);

  return {
    requiresApproval: false,
    success: true,
    deltaCoins: deltaBigInt.toString(),
    newSellerBalanceCoins: result.updatedSeller.resellerBalanceCoins.toString(),
    referenceId: refId,
  };
}

export async function updateSeller(id, data, { adminId, adminName, ipAddress } = {}, db = prisma) {
  const seller = await sellerRepository.findSellerById(id, db);
  if (!seller) {
    const error = new Error('Coin seller not found');
    error.statusCode = 404;
    error.code = 'SELLER_NOT_FOUND';
    throw error;
  }

  const { countryCode, ...sellerFields } = data;
  const updatedSeller = await db.$transaction(async (tx) => {
    let updated = seller;
    if (Object.keys(sellerFields).length > 0) {
      updated = await sellerRepository.updateSeller(id, sellerFields, tx);
    }
    if (countryCode && seller.userId) {
      await tx.user.update({
        where: { id: seller.userId },
        data: { countryCode },
      });
    }
    return updated;
  });

  await logAudit({
    adminId,
    adminName,
    action: 'COIN_SELLER_UPDATED',
    targetEntity: 'CoinSeller',
    targetEntityId: id,
    beforeStateJson: { businessName: seller.businessName, sellerStatus: seller.sellerStatus },
    afterStateJson: data,
    ipAddress,
  }, db);

  return await sellerRepository.findSellerById(id, db);
}

export async function deleteSeller(id, { adminId, adminName, ipAddress } = {}, db = prisma) {
  const seller = await sellerRepository.findSellerById(id, db);
  if (!seller) {
    const error = new Error('Coin seller not found');
    error.statusCode = 404;
    error.code = 'SELLER_NOT_FOUND';
    throw error;
  }

  await db.$transaction(async (tx) => {
    // Delete any associated p2p orders if any, or delete the coin seller
    await sellerRepository.deleteSeller(id, tx);

    // If user has userType COIN_SELLER, reset back to USER
    if (seller.userId) {
      const user = await tx.user.findUnique({ where: { id: seller.userId } });
      if (user && user.userType === 'COIN_SELLER') {
        await tx.user.update({
          where: { id: seller.userId },
          data: { userType: 'USER' },
        });
      }
    }
  });

  await logAudit({
    adminId,
    adminName,
    action: 'COIN_SELLER_DELETED',
    targetEntity: 'CoinSeller',
    targetEntityId: id,
    beforeStateJson: {
      userId: seller.userId,
      businessName: seller.businessName,
      resellerBalanceCoins: seller.resellerBalanceCoins?.toString(),
    },
    ipAddress,
  }, db);

  return { success: true, id };
}

export async function getEffectiveTransferFee(db = prisma) {
  const config = await policyService.getEffectiveConfig('RESELLER_TRANSFER_FEE_PERCENT', db);
  if (config?.value?.ratePercent !== undefined) return config.value.ratePercent;
  if (config?.ratePercent !== undefined) return config.ratePercent;
  return 2.5;
}

export default {
  createSeller,
  updateSeller,
  updateSellerStatus,
  deleteSeller,
  allocateCoinsToSeller,
  correctSellerBalance,
  getEffectiveTransferFee,
};
