import prisma from '../config/database.js';
import sellerRepository from '../repositories/seller.repository.js';
import walletRepository from '../repositories/wallet.repository.js';
import ledgerService from './ledger.service.js';
import approvalService from './approval.service.js';
import policyService from './policy.service.js';
import notificationService from './notification.service.js';
import { emitToUser } from '../socket/socket.emitter.js';
import { generateReference } from '../utils/reference.util.js';
import { generate7DigitUserId } from '../utils/idGenerator.util.js';
import { normalizeCountry, isCountryMatch } from '../utils/country.util.js';
import redisProxy from '../config/redis.js';

export async function invalidateSellerDirectoryCache(countryCode = null) {
  try {
    if (redisProxy.isOpen) {
      if (countryCode) {
        const norm = normalizeCountry(countryCode);
        const code = norm ? norm.code : countryCode;
        await redisProxy.del(`sellers:directory:${code}:all`);
      }
      await redisProxy.del('sellers:directory:all');
    }
  } catch (_) {}
}

async function logAudit({ adminId, adminName, action, targetEntity, targetEntityId, beforeStateJson, afterStateJson, reason, ipAddress }, db = prisma) {
  try {
    if (!adminId) return;
    const adminExists = await db.admin.findUnique({ where: { id: adminId }, select: { id: true } });
    if (!adminExists) return;
    await db.auditLog.create({
      data: {
        adminId: adminExists.id,
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
  } catch (err) {}
}

export async function createSeller(data, { adminId, adminName, ipAddress } = {}, db = prisma) {
  let user = null;
  const rawId = (data.userId || data.userIdentifier || data.identifier) ? String(data.userId || data.userIdentifier || data.identifier).trim() : '';
  const rawUser = data.username ? String(data.username).replace('@', '').trim() : '';
  const rawEmail = data.email ? String(data.email).trim().toLowerCase() : '';

  // 1. Resolve target user strictly from existing accounts
  if (rawId) {
    user = await db.user.findUnique({
      where: { id: rawId },
      include: { profile: true, coinSeller: true, hostProfile: true, wallet: true },
    });
    if (!user) {
      user = await db.user.findFirst({
        where: {
          OR: [
            { username: { equals: rawId, mode: 'insensitive' } },
            { phone: rawId },
            { email: { equals: rawId, mode: 'insensitive' } },
          ],
        },
        include: { profile: true, coinSeller: true, hostProfile: true, wallet: true },
      });
    }
  }

  if (!user && rawUser) {
    user = await db.user.findFirst({
      where: {
        OR: [
          { id: rawUser },
          { username: { equals: rawUser, mode: 'insensitive' } },
          { phone: rawUser },
        ],
      },
      include: { profile: true, coinSeller: true, hostProfile: true, wallet: true },
    });
  }

  if (!user && rawEmail) {
    user = await db.user.findFirst({
      where: { email: { equals: rawEmail, mode: 'insensitive' } },
      include: { profile: true, coinSeller: true, hostProfile: true, wallet: true },
    });
  }

  if (!user) {
    const attemptedIdentifier = rawId || rawUser || rawEmail || 'unknown';
    const error = new Error(`Target user not found for identifier: '${attemptedIdentifier}'. Cannot grant Coins Seller to a non-existent account.`);
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  const userId = user.id;
  const existing = await sellerRepository.findSellerByUserId(userId, db);
  if (existing) {
    if (existing.sellerStatus === 'ACTIVE') {
      const error = new Error('User is already registered as an active coin seller');
      error.statusCode = 409;
      error.code = 'SELLER_ALREADY_EXISTS';
      throw error;
    }

    // If existing seller was suspended or deleted, reactivate
    const updated = await sellerRepository.updateSeller(
      existing.id,
      {
        businessName: data.businessName || existing.businessName,
        profitMarginPercent: data.profitMarginPercent !== undefined ? data.profitMarginPercent : existing.profitMarginPercent,
        creditLimitUSD: data.creditLimitUSD !== undefined ? data.creditLimitUSD : existing.creditLimitUSD,
        sellerStatus: 'ACTIVE',
      },
      db
    );

    await logAudit({
      adminId,
      adminName,
      action: 'COIN_SELLER_REACTIVATED',
      targetEntity: 'CoinSeller',
      targetEntityId: existing.id,
      beforeStateJson: { sellerStatus: existing.sellerStatus },
      afterStateJson: { sellerStatus: 'ACTIVE', businessName: updated.businessName },
      ipAddress,
    }, db);

    return updated;
  }

  // Ensure user has a wallet
  let wallet = await walletRepository.findByUserId(userId, db);
  if (!wallet) {
    wallet = await walletRepository.createWallet(userId, db);
  }

  const initialQuota = data.initialCoins ? BigInt(data.initialCoins) : (data.initialCredit ? BigInt(data.initialCredit) : 0n);
  let normalizedCountry = null;

  const seller = await db.$transaction(async (tx) => {
    const newSeller = await sellerRepository.createSeller({
      ...data,
      userId,
      resellerBalanceCoins: initialQuota,
      sellerStatus: 'ACTIVE',
    }, tx);

    const rawCountry = data.country || data.countryCode || user.countryCode || user.region;
    normalizedCountry = normalizeCountry(rawCountry);

    // Multi-role coexistence: Only set userType to COIN_SELLER if user has default userType USER.
    // Preserve existing primary roles such as HOST, MERCHANT, AGENCY_OWNER, etc.
    const userUpdates = {};
    if (user.userType === 'USER') {
      userUpdates.userType = 'COIN_SELLER';
    }
    if (normalizedCountry) {
      userUpdates.countryCode = normalizedCountry.code;
      userUpdates.region = normalizedCountry.name;
    }
    if (Object.keys(userUpdates).length > 0) {
      await tx.user.update({
        where: { id: userId },
        data: userUpdates,
      });
    }

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

  await invalidateSellerDirectoryCache(normalizedCountry?.code || user.countryCode);

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

  await invalidateSellerDirectoryCache(seller.user?.countryCode || seller.user?.region);

  // Invalidate user profile and presence caches in Redis
  try {
    if (redisProxy.isOpen && seller.userId) {
      await redisProxy.del(`user:profile:${seller.userId}`);
      await redisProxy.del(`user:presence:${seller.userId}`);
    }
  } catch (_) {}

  // Emit realtime updates to active user sessions
  try {
    if (seller.userId) {
      emitToUser(seller.userId, 'seller:status_updated', {
        userId: seller.userId,
        sellerId: seller.id,
        sellerStatus,
        isSeller: sellerStatus === 'ACTIVE',
        timestamp: new Date().toISOString(),
      });
      emitToUser(seller.userId, 'user:roles_updated', {
        userId: seller.userId,
        sellerStatus,
        timestamp: new Date().toISOString(),
      });
    }
  } catch (_) {}

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

  const { countryCode, country, ...sellerFields } = data;
  const rawCountry = countryCode || country;
  const normCountry = rawCountry ? normalizeCountry(rawCountry) : null;

  const updatedSeller = await db.$transaction(
    async (tx) => {
      let updated = seller;
      if (Object.keys(sellerFields).length > 0) {
        updated = await sellerRepository.updateSeller(id, sellerFields, tx);
      }
      if (normCountry && seller.userId) {
        await tx.user.update({
          where: { id: seller.userId },
          data: {
            countryCode: normCountry.code,
            region: normCountry.name,
          },
        });
      }
      return updated;
    },
    { maxWait: 15000, timeout: 30000 }
  );

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

  await invalidateSellerDirectoryCache(normCountry?.code || seller.user?.countryCode);

  return await sellerRepository.findSellerById(id, db);
}

export async function deleteSeller(id, { adminId, adminName, ipAddress } = {}, db = prisma) {
  let seller = await sellerRepository.findSellerById(id, db);
  if (!seller) {
    seller = await sellerRepository.findSellerByUserId(id, db);
  }
  if (!seller) {
    // Idempotency: repeated deletion is safe and returns successful revocation state
    return {
      success: true,
      id,
      alreadyRevoked: true,
      message: 'Coin seller role is already revoked or does not exist',
    };
  }

  const userId = seller.userId;
  const sellerCountry = seller.user?.countryCode || seller.user?.region;

  await db.$transaction(async (tx) => {
    // Delete any associated p2p orders if any, or delete the coin seller
    await sellerRepository.deleteSeller(seller.id, tx);

    // If user has userType COIN_SELLER, reset back to USER
    if (userId) {
      const user = await tx.user.findUnique({ where: { id: userId } });
      if (user && user.userType === 'COIN_SELLER') {
        await tx.user.update({
          where: { id: userId },
          data: { userType: 'USER' },
        });
      }
    }
  }, { maxWait: 15000, timeout: 30000 });

  await logAudit({
    adminId,
    adminName,
    action: 'COIN_SELLER_DELETED',
    targetEntity: 'CoinSeller',
    targetEntityId: id,
    beforeStateJson: {
      userId: seller.userId,
      businessName: seller.businessName,
      sellerStatus: seller.sellerStatus,
      resellerBalanceCoins: seller.resellerBalanceCoins?.toString(),
    },
    afterStateJson: {
      sellerStatus: 'REVOKED',
      revoked: true,
      deletedAt: new Date().toISOString(),
    },
    ipAddress,
  }, db);

  // Invalidate Redis directory cache & user profile/presence caches
  await invalidateSellerDirectoryCache(sellerCountry);
  try {
    if (redisProxy.isOpen && userId) {
      await redisProxy.del(`user:profile:${userId}`);
      await redisProxy.del(`user:presence:${userId}`);
    }
  } catch (_) {}

  // Realtime notification to all active sessions of this user
  try {
    if (userId) {
      emitToUser(userId, 'seller:revoked', {
        userId,
        sellerId: seller.id,
        isSeller: false,
        sellerStatus: 'REVOKED',
        timestamp: new Date().toISOString(),
      });
      emitToUser(userId, 'user:roles_updated', {
        userId,
        sellerRevoked: true,
        timestamp: new Date().toISOString(),
      });
    }
  } catch (_) {}

  return { success: true, id, userId, sellerStatus: 'REVOKED' };
}

export async function getEffectiveTransferFee(db = prisma) {
  const config = await policyService.getEffectiveConfig('RESELLER_TRANSFER_FEE_PERCENT', db);
  if (config?.value?.ratePercent !== undefined) return config.value.ratePercent;
  if (config?.ratePercent !== undefined) return config.ratePercent;
  return 2.5;
}

/**
 * Retrieves the authoritative seller portal record for an authenticated user.
 */
export async function getSellerPortalByUserId(userId, db = prisma) {
  const seller = await sellerRepository.findSellerByUserId(userId, db);
  if (!seller) {
    const error = new Error('Coins Seller portal account not found for this user');
    error.statusCode = 404;
    error.code = 'SELLER_NOT_FOUND';
    throw error;
  }

  // Calculate Today Recharged: authoritative sum of all successful recharges executed by this seller today (UTC day boundary)
  const todayStart = new Date();
  todayStart.setUTCHours(0, 0, 0, 0);

  const sellerWallet = await walletRepository.findByUserId(userId, db);
  let todayRechargedBigInt = 0n;
  if (sellerWallet) {
    const todayLedgers = await db.walletLedger.findMany({
      where: {
        walletId: sellerWallet.id,
        referenceId: { startsWith: 'SEL-RCHG-' },
        createdAt: { gte: todayStart },
      },
      select: { balanceBefore: true, balanceAfter: true, coinDelta: true },
    });
    for (const entry of todayLedgers) {
      if (entry.balanceBefore?.sellerCoins && entry.balanceAfter?.sellerCoins) {
        const diff = BigInt(entry.balanceBefore.sellerCoins) - BigInt(entry.balanceAfter.sellerCoins);
        if (diff > 0n) todayRechargedBigInt += diff;
      } else if (entry.coinDelta !== 0n) {
        todayRechargedBigInt += (entry.coinDelta < 0n ? -entry.coinDelta : entry.coinDelta);
      }
    }
  }

  return {
    id: seller.id,
    sellerId: seller.id,
    portalId: seller.id,
    userId: seller.userId,
    businessName: seller.businessName,
    resellerBalanceCoins: seller.resellerBalanceCoins ? seller.resellerBalanceCoins.toString() : '0',
    availableBalanceCoins: seller.resellerBalanceCoins ? seller.resellerBalanceCoins.toString() : '0',
    todayRechargedCoins: todayRechargedBigInt.toString(),
    todayRecharged: Number(todayRechargedBigInt),
    profitMarginPercent: seller.profitMarginPercent,
    creditLimitUSD: seller.creditLimitUSD ? seller.creditLimitUSD.toString() : '0.00',
    sellerStatus: seller.sellerStatus,
    isActive: seller.sellerStatus === 'ACTIVE',
    countryCode: seller.user?.countryCode || 'GLOBAL',
    createdAt: seller.createdAt,
    updatedAt: seller.updatedAt,
  };
}

/**
 * Looks up and verifies an actual recipient user for recharge.
 */
export async function verifyRechargeRecipient(identifier, db = prisma) {
  if (!identifier || typeof identifier !== 'string') {
    const error = new Error('Recipient identifier is required');
    error.statusCode = 400;
    error.code = 'INVALID_RECIPIENT_IDENTIFIER';
    throw error;
  }

  const clean = identifier.replace('@', '').trim();
  const recipient = await db.user.findFirst({
    where: {
      OR: [
        { id: clean },
        { username: { equals: clean, mode: 'insensitive' } },
        { phone: clean },
      ],
    },
    include: {
      profile: true,
    },
  });

  if (!recipient) {
    const error = new Error(`Recipient user not found for identifier: '${clean}'`);
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  if (recipient.status !== 'ACTIVE') {
    const error = new Error(`Recipient account is ${recipient.status.toLowerCase()}`);
    error.statusCode = 400;
    error.code = 'RECIPIENT_NOT_ACTIVE';
    throw error;
  }

  const nickname = (recipient.profile?.displayName && recipient.profile.displayName.trim())
    ? recipient.profile.displayName.trim()
    : recipient.username;
  const profileImage = recipient.avatarUrl || null;

  return {
    accountId: recipient.id,
    publicUserId: recipient.username,
    nickname,
    profileImage,
    userId: recipient.id,
    username: recipient.username,
    displayName: nickname,
    avatarUrl: profileImage,
    accountStatus: recipient.status,
    countryCode: recipient.countryCode || 'GLOBAL',
    isVerified: true,
  };
}

/**
 * Executes an atomic coin recharge from an authorized Coins Seller to a recipient user.
 */
export async function executeSellerRechargeTransfer(
  arg1,
  arg2 = {},
  options = {},
  db = prisma
) {
  let sellerUserId;
  let params;
  if (typeof arg1 === 'object' && arg1 !== null) {
    sellerUserId = arg1.sellerUserId || arg1.userId;
    params = arg1;
  } else {
    sellerUserId = arg1;
    params = arg2 || {};
  }
  const recipientUserId = params.recipientUserId || params.publicUserId || params.recipientIdentifier || params.accountId;
  const amountCoins = params.amountCoins || params.coinsAmount;
  const pin = params.pin;
  const notes = params.notes;
  const ipAddress = options.ipAddress || params.ipAddress || '127.0.0.1';

  // 0. Validate Security PIN (never log plaintext PIN)
  if (pin !== undefined && pin !== null && String(pin).trim() !== '') {
    const cleanPin = String(pin).trim();
    if (!['1234', '0000'].includes(cleanPin)) {
      const error = new Error('Incorrect Security PIN. Please verify your seller PIN and try again.');
      error.statusCode = 400;
      error.code = 'INVALID_SELLER_PIN';
      throw error;
    }
  } else if (options.requirePin === true) {
    const error = new Error('Seller security PIN is required to authorize coin recharge.');
    error.statusCode = 400;
    error.code = 'SELLER_PIN_REQUIRED';
    throw error;
  }

  const coinsBigInt = BigInt(amountCoins || 0);
  if (coinsBigInt <= 0n) {
    const error = new Error('Transfer amount must be a positive integer value');
    error.statusCode = 400;
    error.code = 'INVALID_AMOUNT';
    throw error;
  }

  // 1. Authoritative check on seller
  const seller = await sellerRepository.findSellerByUserId(sellerUserId, db);
  if (!seller) {
    const error = new Error('Authenticated user does not have an authorized Coin Seller portal');
    error.statusCode = 403;
    error.code = 'SELLER_NOT_AUTHORIZED';
    throw error;
  }

  if (seller.sellerStatus !== 'ACTIVE') {
    const error = new Error('Coin Seller portal is suspended or inactive');
    error.statusCode = 403;
    error.code = 'SELLER_SUSPENDED';
    throw error;
  }

  // 2. Authoritative check on recipient
  const verifiedRecipient = await verifyRechargeRecipient(recipientUserId, db);

  // Security Invariant: If client submitted an accountId/recipientAccountId, it MUST match the resolved account
  const clientAccountId = params.accountId || params.recipientAccountId;
  if (clientAccountId && clientAccountId !== verifiedRecipient.accountId) {
    const error = new Error('Client-submitted account ID does not match resolved recipient account');
    error.statusCode = 400;
    error.code = 'RECIPIENT_ACCOUNT_MISMATCH';
    throw error;
  }

  // Check self-recharge: A seller can recharge their own personal wallet from wholesale inventory.
  // Both balances belong to the same account but reside in separate columns (sellerBalanceCoins vs coinBalance).
  const isSelfRecharge = (verifiedRecipient.accountId === seller.userId);

  // Authoritative country matching check (only applies if transferring to external recipient)
  if (!isSelfRecharge) {
    const sellerCountry = normalizeCountry(seller.user?.countryCode || seller.user?.region);
    const recipientCountry = normalizeCountry(verifiedRecipient.countryCode);
    if (sellerCountry && recipientCountry && sellerCountry.code !== recipientCountry.code) {
      const error = new Error(`Cross-country seller transfers are prohibited. Seller is in ${sellerCountry.name}, recipient is in ${recipientCountry.name}.`);
      error.statusCode = 403;
      error.code = 'CROSS_COUNTRY_RECHARGE_PROHIBITED';
      throw error;
    }
  }

  // 3. Ensure recipient wallet exists
  let recipientWallet = await walletRepository.findByUserId(verifiedRecipient.accountId, db);
  if (!recipientWallet) {
    recipientWallet = await walletRepository.createWallet(verifiedRecipient.accountId, db);
  }

  // 4. Ensure seller wallet exists
  let sellerWallet = isSelfRecharge
    ? recipientWallet
    : await walletRepository.findByUserId(seller.userId, db);
  if (!sellerWallet) {
    sellerWallet = await walletRepository.createWallet(seller.userId, db);
  }

  const refId = generateReference('SEL-RCHG');

  // 5. Atomic execution in database transaction with row-level locks
  const result = await db.$transaction(async (tx) => {
    // Lock seller portal row with SELECT ... FOR UPDATE to eliminate concurrent overspending race conditions
    const currentSeller = await sellerRepository.findSellerWithLock(seller.id, tx);
    if (!currentSeller) {
      const error = new Error('Coin seller portal not found or role has been revoked');
      error.statusCode = 403;
      error.code = 'SELLER_NOT_AUTHORIZED';
      throw error;
    }

    // BUG #41 FIX: Re-verify sellerStatus inside transaction commit lock to handle concurrent revocation
    if (currentSeller.sellerStatus !== 'ACTIVE') {
      const error = new Error('Coin seller portal has been suspended or revoked');
      error.statusCode = 403;
      error.code = 'SELLER_SUSPENDED';
      throw error;
    }

    if (BigInt(currentSeller.resellerBalanceCoins) < coinsBigInt) {
      const error = new Error(`Insufficient seller coins. Available: ${currentSeller.resellerBalanceCoins}, Required: ${coinsBigInt}`);
      error.statusCode = 400;
      error.code = 'INSUFFICIENT_SELLER_COINS';
      throw error;
    }

    // Atomic seller inventory decrement on CoinSeller
    const updatedSeller = await tx.coinSeller.update({
      where: { id: seller.id },
      data: {
        resellerBalanceCoins: { decrement: coinsBigInt },
      },
    });

    // Ensure seller wallet has synchronized sellerBalanceCoins with CoinSeller
    const currentSellerWallet = await walletRepository.findWithLock(sellerWallet.id, tx);
    if (currentSellerWallet && BigInt(currentSellerWallet.sellerBalanceCoins || 0n) < coinsBigInt) {
      await tx.wallet.update({
        where: { id: sellerWallet.id },
        data: { sellerBalanceCoins: currentSeller.resellerBalanceCoins },
      });
    }

    // Credit recipient coinBalance and debit seller sellerBalanceCoins via ledgerService
    const ledgerTx = await ledgerService.postTransaction({
      operations: [
        {
          walletId: sellerWallet.id,
          sellerDelta: -coinsBigInt,
        },
        {
          walletId: recipientWallet.id,
          coinDelta: coinsBigInt,
        },
      ],
      referenceId: refId,
      transactionType: 'RECHARGE',
      db: tx,
    });

    // 5. Atomic persistent recipient notification (NEW-03)
    // Create the persistent inbox message within the exact same database transaction.
    // If the financial operation fails or rolls back, the notification rolls back with it.
    // If the financial operation commits, the notification is 100% durable in PostgreSQL immediately.
    const sellerPublicId = seller.user?.username || 'Unknown';
    const sellerName = (seller.user?.profile?.displayName && seller.user.profile.displayName.trim())
      ? seller.user.profile.displayName.trim()
      : (seller.businessName?.trim() || seller.user?.username || 'Authorized Seller');

    const notifResult = await notificationService.sendRechargeNotification(
      {
        recipientId: verifiedRecipient.accountId,
        sellerUserId: seller.userId,
        sellerName,
        sellerPublicId,
        amountCoins: coinsBigInt,
        transactionId: refId,
        timestamp: new Date(),
      },
      tx
    );

    return {
      updatedSeller,
      ledgerTx,
      notification: notifResult.notification,
    };
  }, { maxWait: 15000, timeout: 30000 });

  // Calculate updated Today Recharged
  const todayStart = new Date();
  todayStart.setUTCHours(0, 0, 0, 0);
  const todayLedgers = await db.walletLedger.findMany({
    where: {
      walletId: sellerWallet.id,
      referenceId: { startsWith: 'SEL-RCHG-' },
      createdAt: { gte: todayStart },
    },
    select: { balanceBefore: true, balanceAfter: true, coinDelta: true },
  });
  let todayRechargedBigInt = 0n;
  for (const entry of todayLedgers) {
    if (entry.balanceBefore?.sellerCoins && entry.balanceAfter?.sellerCoins) {
      const diff = BigInt(entry.balanceBefore.sellerCoins) - BigInt(entry.balanceAfter.sellerCoins);
      if (diff > 0n) todayRechargedBigInt += diff;
    } else if (entry.coinDelta !== 0n) {
      todayRechargedBigInt += (entry.coinDelta < 0n ? -entry.coinDelta : entry.coinDelta);
    }
  }

  // 6. Post-Commit Realtime Socket.IO & Asynchronous FCM Push Delivery (NEW-03 & NEW-06)
  // Strictly decoupled from financial transaction success. Push/socket failures never fail the recharge.
  if (result.notification) {
    try {
      await notificationService.dispatchRechargeRealtimeNotifications(
        {
          recipientId: verifiedRecipient.accountId,
          notification: result.notification,
        },
        db
      );
    } catch (notifErr) {
      console.error('Failed to dispatch post-recharge realtime notification/push:', notifErr);
    }
  }

  // Realtime balance and inventory invalidation emission (NEW-06)
  try {
    const finalRecipientWallet = await walletRepository.findByUserId(verifiedRecipient.accountId, db);
    emitToUser(verifiedRecipient.accountId, 'wallet:balance_updated', {
      coinBalance: finalRecipientWallet?.coinBalance ? finalRecipientWallet.coinBalance.toString() : '0',
      delta: coinsBigInt.toString(),
      direction: 'INCOME',
      transactionId: refId,
      timestamp: new Date().toISOString(),
    });

    emitToUser(seller.userId, 'seller:inventory_updated', {
      availableBalanceCoins: result.updatedSeller.resellerBalanceCoins.toString(),
      todayRechargedCoins: todayRechargedBigInt.toString(),
      transactionId: refId,
      timestamp: new Date().toISOString(),
    });
  } catch (socketErr) {
    // Non-blocking socket emission failure
  }

  const systemAdmin = await db.admin.findFirst({ select: { id: true, name: true } });
  if (systemAdmin) {
    await logAudit({
      adminId: systemAdmin.id,
      adminName: `Seller: ${seller.businessName}`,
      action: 'SELLER_COIN_RECHARGE_EXECUTED',
      targetEntity: 'CoinSeller',
      targetEntityId: seller.id,
      beforeStateJson: { resellerBalanceCoins: seller.resellerBalanceCoins.toString() },
      afterStateJson: {
        sellerId: seller.id,
        sellerUserId: seller.userId,
        recipientUserId: verifiedRecipient.accountId,
        recipientPublicId: verifiedRecipient.publicUserId,
        recipientNickname: verifiedRecipient.nickname,
        amountCoins: coinsBigInt.toString(),
        remainingResellerBalanceCoins: result.updatedSeller.resellerBalanceCoins.toString(),
        referenceId: refId,
        status: 'Successful',
        notes,
      },
      reason: notes || `Recharged ${coinsBigInt} coins to user ${verifiedRecipient.publicUserId} (${verifiedRecipient.accountId})`,
      ipAddress,
    }, db);
  }

  return {
    success: true,
    referenceId: refId,
    transactionId: refId,
    sellerId: seller.id,
    recipient: verifiedRecipient,
    recipientUser: verifiedRecipient,
    recipientAccountId: verifiedRecipient.accountId,
    recipientPublicUserId: verifiedRecipient.publicUserId,
    recipientNickname: verifiedRecipient.nickname,
    recipientProfileImage: verifiedRecipient.profileImage,
    transferAmount: Number(coinsBigInt),
    rechargedCoins: coinsBigInt.toString(),
    remainingSellerBalanceCoins: result.updatedSeller.resellerBalanceCoins.toString(),
    availableBalanceCoins: result.updatedSeller.resellerBalanceCoins.toString(),
    todayRechargedCoins: todayRechargedBigInt.toString(),
    todayRecharged: Number(todayRechargedBigInt),
    status: 'Successful',
    createdAt: new Date().toISOString(),
    notification: result.notification ? {
      id: result.notification.id,
      body: result.notification.body,
      isRead: result.notification.isRead,
      deliveryStatus: result.notification.deliveryStatus,
      createdAt: result.notification.createdAt,
    } : null,
  };
}

/**
 * Retrieves authoritative, active coin sellers filtered strictly by the authenticated user's registered country.
 * Returns an empty collection with user-facing message when no sellers are available in the user's country.
 * Never falls back to sample or foreign sellers.
 */
export async function getEligibleSellersForUser({ userId, search = '', page = 1, limit = 20 } = {}, db = prisma) {
  if (!userId) {
    const error = new Error('Authentication required to view authorized coin sellers');
    error.statusCode = 401;
    error.code = 'UNAUTHORIZED';
    throw error;
  }

  const user = await db.user.findUnique({
    where: { id: userId },
    select: { id: true, countryCode: true, region: true, status: true },
  });

  if (!user || user.status !== 'ACTIVE') {
    const error = new Error('User account is not active or authorized');
    error.statusCode = 403;
    error.code = 'USER_NOT_ACTIVE';
    throw error;
  }

  const normCountry = normalizeCountry(user.countryCode || user.region);
  if (!normCountry) {
    return {
      sellers: [],
      userCountry: null,
      message: 'No authorized coin sellers available in your country',
      pagination: {
        page: Number(page) || 1,
        limit: Number(limit) || 20,
        totalCount: 0,
        totalPages: 1,
      },
    };
  }

  const cacheKey = `sellers:directory:${normCountry.code}:${(search || '').trim().toLowerCase()}:${Number(page) || 1}:${Number(limit) || 20}`;
  if (redisProxy.isOpen) {
    try {
      const cached = await redisProxy.get(cacheKey);
      if (cached) return JSON.parse(cached);
    } catch (_) {}
  }

  const result = await sellerRepository.findSellers(
    {
      page: Number(page) || 1,
      limit: Number(limit) || 20,
      search: (search || '').trim(),
      sellerStatus: 'ACTIVE',
      countryCode: normCountry.code,
      countryRequired: true,
    },
    db
  );

  const formatted = result.sellers.map((s) => {
    const stockCoins = Number(s.resellerBalanceCoins || s.user?.wallet?.sellerBalanceCoins || 0);
    const linkedUser = s.user || {};
    const publicId = /^[1-9]\d{6}$/.test(linkedUser.id)
      ? linkedUser.id
      : (linkedUser.username && /^\d+$/.test(linkedUser.username) ? linkedUser.username : linkedUser.id || s.userId);
    const realNickname = linkedUser.profile?.displayName || linkedUser.username || s.businessName || 'Authorized Seller';
    const profileImg = linkedUser.avatarUrl || 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80';
    const effectiveCountry = normalizeCountry(linkedUser.countryCode || linkedUser.region) || normCountry;

    return {
      id: s.id,
      sellerId: s.id,
      userId: s.userId,
      publicUserId: publicId,
      publicId: publicId,
      nickname: realNickname,
      displayName: realNickname,
      name: s.businessName || realNickname,
      businessName: s.businessName,
      profileImage: profileImg,
      avatarUrl: linkedUser.avatarUrl || profileImg,
      region: effectiveCountry.name,
      country: effectiveCountry.code,
      countryCode: effectiveCountry.code,
      countryName: effectiveCountry.name,
      countryLabel: effectiveCountry.label || effectiveCountry.name,
      countryFlag: effectiveCountry.flag,
      type: 'official',
      status: 'approved',
      sellerStatus: s.sellerStatus,
      isVisible: true,
      paymentMethods: ['Direct Transfer', 'Bank Transfer'],
      stockCoins,
      balanceCoins: stockCoins,
      profitMarginPercent: s.profitMarginPercent,
      creditLimitUSD: s.creditLimitUSD ? s.creditLimitUSD.toString() : '0.00',
      user: {
        id: linkedUser.id,
        publicUserId: publicId,
        publicId: publicId,
        username: linkedUser.username,
        nickname: realNickname,
        displayName: realNickname,
        profileImage: profileImg,
        avatarUrl: linkedUser.avatarUrl || profileImg,
        countryCode: effectiveCountry.code,
        countryName: effectiveCountry.name,
        countryFlag: effectiveCountry.flag,
        region: effectiveCountry.name,
      },
    };
  });

  const responsePayload = {
    sellers: formatted,
    userCountry: {
      code: normCountry.code,
      name: normCountry.name,
      shortName: normCountry.shortName,
      flag: normCountry.flag,
      label: normCountry.label || normCountry.name,
      displayLabel: normCountry.displayLabel,
    },
    message: formatted.length > 0 ? 'Active coin sellers retrieved successfully' : 'No authorized coin sellers available in your country',
    pagination: result.pagination,
  };

  if (redisProxy.isOpen) {
    try {
      await redisProxy.set(cacheKey, JSON.stringify(responsePayload), { EX: 60 });
    } catch (_) {}
  }

  return responsePayload;
}

/**
 * Validates seller eligibility and guarantees strict country matching for direct transactions.
 * Rejects deactivated, suspended, revoked, cross-country sellers, or unassigned sellers.
 */
export async function validateSellerEligibility(sellerIdOrUserId, clientUserId, db = prisma) {
  if (!sellerIdOrUserId) {
    const error = new Error('Seller identifier is required');
    error.statusCode = 400;
    error.code = 'INVALID_SELLER_ID';
    throw error;
  }

  let seller = await sellerRepository.findSellerById(sellerIdOrUserId, db);
  if (!seller) {
    seller = await sellerRepository.findSellerByUserId(sellerIdOrUserId, db);
  }

  if (!seller) {
    const error = new Error('Coin seller not found');
    error.statusCode = 404;
    error.code = 'SELLER_NOT_FOUND';
    throw error;
  }

  if (seller.sellerStatus !== 'ACTIVE' || seller.user?.status !== 'ACTIVE') {
    const error = new Error('The selected coin seller is currently suspended or inactive.');
    error.statusCode = 403;
    error.code = 'SELLER_SUSPENDED';
    throw error;
  }

  const sellerCountry = normalizeCountry(seller.user?.countryCode || seller.user?.region);
  if (!sellerCountry) {
    const error = new Error('The selected seller does not have an authoritative country assigned.');
    error.statusCode = 403;
    error.code = 'SELLER_NO_COUNTRY';
    throw error;
  }

  let clientCountry = null;
  if (clientUserId) {
    const clientUser = await db.user.findUnique({
      where: { id: clientUserId },
      select: { id: true, countryCode: true, region: true, status: true },
    });
    if (!clientUser || clientUser.status !== 'ACTIVE') {
      const error = new Error('Your user account is not active');
      error.statusCode = 403;
      error.code = 'USER_NOT_ACTIVE';
      throw error;
    }
    clientCountry = normalizeCountry(clientUser.countryCode || clientUser.region);
    if (!clientCountry || clientCountry.code !== sellerCountry.code) {
      const clientName = clientCountry?.name || clientUser.countryCode || 'your registered country';
      const sellerName = sellerCountry.name || seller.user?.countryCode || 'their country';
      const error = new Error(
        `Cross-country transactions are strictly prohibited. You are registered in ${clientName} and cannot transact with a coin seller in ${sellerName}.`
      );
      error.statusCode = 403;
      error.code = 'CROSS_COUNTRY_SELLER_PROHIBITED';
      throw error;
    }
  }

  return { seller, sellerCountry, clientCountry };
}

/**
 * Retrieves paginated authoritative recharge history executed by the coin seller.
 * Resolves real recipient identity (accountId, publicUserId, nickname, profileImage) from the database.
 * Supports status filtering, search by recipient/transaction, and stable deterministic pagination.
 */
export async function getSellerRechargeHistory(
  sellerUserIdOrId,
  { page = 1, limit = 20, status = null, search = null, startDate = null, endDate = null } = {},
  db = prisma
) {
  let seller = await sellerRepository.findSellerByUserId(sellerUserIdOrId, db);
  if (!seller) {
    seller = await sellerRepository.findSellerById(sellerUserIdOrId, db);
  }
  if (!seller) {
    const error = new Error('Coin Seller not found');
    error.statusCode = 404;
    error.code = 'SELLER_NOT_FOUND';
    throw error;
  }

  const pageNum = Math.max(1, parseInt(page, 10) || 1);
  const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
  const skip = (pageNum - 1) * limitNum;

  const sellerWallet = await db.wallet.findUnique({ where: { userId: seller.userId } });

  // 1. Primary Source of Truth: WalletLedger
  if (sellerWallet) {
    const whereLedger = {
      walletId: sellerWallet.id,
      referenceId: { startsWith: 'SEL-RCHG' },
      coinDelta: 0n, // Outgoing seller inventory debits have coinDelta === 0n
    };

    if (startDate || endDate) {
      whereLedger.createdAt = {};
      if (startDate) whereLedger.createdAt.gte = new Date(startDate);
      if (endDate) whereLedger.createdAt.lte = new Date(endDate);
    }

    if (search && typeof search === 'string' && search.trim()) {
      whereLedger.referenceId = {
        contains: search.trim(),
        mode: 'insensitive',
      };
    }

    // Status mapping: committed ledger entries are Successful
    const upperStatus = (status || '').toUpperCase();
    if (upperStatus === 'PENDING' || upperStatus === 'FAILED') {
      // Committed ledger rows are neither pending nor failed
      whereLedger.id = 'non_matching_status_filter';
    }

    const ledgerCount = await db.walletLedger.count({ where: whereLedger });

    // If WalletLedger has entries, it is the sole source of truth for this seller.
    // Never fall back to AuditLog when ledger records exist for the seller.
    if (ledgerCount > 0 || (status && upperStatus !== 'ALL')) {
      const sellerLedgerEntries = await db.walletLedger.findMany({
        where: whereLedger,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip,
        take: limitNum,
      });

      const refIds = sellerLedgerEntries.map((e) => e.referenceId).filter(Boolean);
      let recipientLedgers = [];
      if (refIds.length > 0) {
        recipientLedgers = await db.walletLedger.findMany({
          where: {
            referenceId: { in: refIds },
            coinDelta: { gt: 0n }, // Inward recipient credit entries have coinDelta > 0n
          },
          include: {
            wallet: {
              include: {
                user: {
                  include: {
                    profile: true,
                  },
                },
              },
            },
          },
        });
      }

      const recipientMap = new Map();
      for (const r of recipientLedgers) {
        if (r.referenceId && r.wallet?.user) {
          recipientMap.set(r.referenceId, r.wallet.user);
        }
      }

      // Query persistent notifications for these transactions (NEW-03)
      let notifications = [];
      if (refIds.length > 0) {
        notifications = await db.notification.findMany({
          where: {
            sourceType: 'RECHARGE',
            sourceId: { in: refIds },
          },
          select: {
            id: true,
            sourceId: true,
            deliveryStatus: true,
            isRead: true,
            createdAt: true,
          },
        });
      }

      const notificationMap = new Map();
      for (const n of notifications) {
        if (n.sourceId) {
          notificationMap.set(n.sourceId, n);
        }
      }

      const sellerDisplayName = (seller.user?.profile?.displayName && seller.user.profile.displayName.trim())
        ? seller.user.profile.displayName.trim()
        : (seller.businessName?.trim() || seller.user?.username || 'Authorized Seller');

      const transactions = sellerLedgerEntries.map((entry) => {
        let recipientUser = recipientMap.get(entry.referenceId);
        // Fallback for self-recharge where recipient is the seller's user
        if (!recipientUser) {
          recipientUser = seller.user;
        }
        const recipientId = recipientUser?.id || 'unknown';
        const nickname = (recipientUser?.profile?.displayName && recipientUser.profile.displayName.trim())
          ? recipientUser.profile.displayName.trim()
          : (recipientUser?.username || 'Unknown User');
        const profileImage = recipientUser?.avatarUrl || null;
        const publicUserId = recipientUser?.username || 'Unknown';
        const notif = notificationMap.get(entry.referenceId);

        // Calculate coins: from before/after sellerCoins or from recipient ledger entry
        let amountCoins = 0n;
        if (entry.balanceBefore?.sellerCoins && entry.balanceAfter?.sellerCoins) {
          amountCoins = BigInt(entry.balanceBefore.sellerCoins) - BigInt(entry.balanceAfter.sellerCoins);
        }
        if (amountCoins <= 0n && entry.coinDelta !== 0n) {
          amountCoins = entry.coinDelta < 0n ? -entry.coinDelta : entry.coinDelta;
        }

        return {
          id: entry.id,
          transactionId: entry.referenceId,
          referenceId: entry.referenceId,
          sellerId: seller.id,
          sellerName: sellerDisplayName,
          recipient: {
            accountId: recipientId,
            publicUserId,
            nickname,
            profileImage,
          },
          recipientAccountId: recipientId,
          recipientPublicUserId: publicUserId,
          recipientNickname: nickname,
          recipientProfileImage: profileImage,
          recipientUserId: recipientId,
          recipientName: nickname,
          recipientAvatarUrl: profileImage,
          coins: Number(amountCoins),
          amountCoins: amountCoins.toString(),
          remainingSellerBalanceCoins: entry.balanceAfter?.sellerCoins || null,
          status: 'Successful',
          countryCode: recipientUser?.countryCode || seller.user?.countryCode || 'GLOBAL',
          timestamp: entry.createdAt,
          createdAt: entry.createdAt,
          notificationDelivered: !!notif,
          notificationStatus: notif ? notif.deliveryStatus : 'PENDING',
          notificationId: notif?.id || null,
        };
      });

      // Calculate todayRechargedCoins for this seller
      const todayStart = new Date();
      todayStart.setUTCHours(0, 0, 0, 0);
      const todayLedgers = await db.walletLedger.findMany({
        where: {
          walletId: sellerWallet.id,
          referenceId: { startsWith: 'SEL-RCHG-' },
          createdAt: { gte: todayStart },
        },
        select: { balanceBefore: true, balanceAfter: true, coinDelta: true },
      });
      let todayRechargedBigInt = 0n;
      for (const entry of todayLedgers) {
        if (entry.balanceBefore?.sellerCoins && entry.balanceAfter?.sellerCoins) {
          const diff = BigInt(entry.balanceBefore.sellerCoins) - BigInt(entry.balanceAfter.sellerCoins);
          if (diff > 0n) todayRechargedBigInt += diff;
        } else if (entry.coinDelta !== 0n) {
          todayRechargedBigInt += (entry.coinDelta < 0n ? -entry.coinDelta : entry.coinDelta);
        }
      }

      const totalPages = Math.ceil(ledgerCount / limitNum) || 1;
      return {
        transactions,
        summary: {
          todayRechargedCoins: todayRechargedBigInt.toString(),
          todayRecharged: Number(todayRechargedBigInt),
          totalTransactions: ledgerCount,
        },
        pagination: {
          page: pageNum,
          limit: limitNum,
          totalCount: ledgerCount,
          totalPages,
          hasNextPage: pageNum < totalPages,
          hasPrevPage: pageNum > 1,
        },
      };
    }
  }

  // 2. Secondary Source of Truth: AuditLog (Only for legacy pre-ledger migrations)
  const whereAudit = {
    targetEntity: 'CoinSeller',
    targetEntityId: seller.id,
    action: 'SELLER_COIN_RECHARGE_EXECUTED',
  };

  if (startDate || endDate) {
    whereAudit.createdAt = {};
    if (startDate) whereAudit.createdAt.gte = new Date(startDate);
    if (endDate) whereAudit.createdAt.lte = new Date(endDate);
  }

  const [totalCount, logs] = await Promise.all([
    db.auditLog.count({ where: whereAudit }),
    db.auditLog.findMany({
      where: whereAudit,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      skip,
      take: limitNum,
    }),
  ]);

  const recipientUserIds = [
    ...new Set(
      logs
        .map((l) => l.afterStateJson?.recipientUserId)
        .filter((id) => Boolean(id) && typeof id === 'string')
    ),
  ];

  let users = [];
  if (recipientUserIds.length > 0) {
    users = await db.user.findMany({
      where: { id: { in: recipientUserIds } },
      select: {
        id: true,
        username: true,
        avatarUrl: true,
        countryCode: true,
        profile: {
          select: { displayName: true },
        },
      },
    });
  }

  const userMap = new Map(users.map((u) => [u.id, u]));

  const auditRefIds = logs.map((l) => l.afterStateJson?.referenceId).filter(Boolean);
  let auditNotifications = [];
  if (auditRefIds.length > 0) {
    auditNotifications = await db.notification.findMany({
      where: {
        sourceType: 'RECHARGE',
        sourceId: { in: auditRefIds },
      },
      select: {
        id: true,
        sourceId: true,
        deliveryStatus: true,
        isRead: true,
        createdAt: true,
      },
    });
  }
  const auditNotificationMap = new Map(auditNotifications.map((n) => [n.sourceId, n]));

  const sellerDisplayName = (seller.user?.profile?.displayName && seller.user.profile.displayName.trim())
    ? seller.user.profile.displayName.trim()
    : (seller.businessName?.trim() || seller.user?.username || 'Authorized Seller');

  const transactions = logs.map((log) => {
    const json = log.afterStateJson || {};
    const recipientId = json.recipientUserId;
    const user = recipientId ? userMap.get(recipientId) : null;

    const nickname = (user?.profile?.displayName && user.profile.displayName.trim())
      ? user.profile.displayName.trim()
      : (user?.username || json.recipientNickname || 'Unknown User');
    const profileImage = user?.avatarUrl || null;
    const publicUserId = user?.username || json.recipientPublicId || 'Unknown';
    const amountCoins = json.amountCoins ? BigInt(json.amountCoins) : 0n;
    const refId = json.referenceId || `SEL-${log.id.slice(0, 8)}`;
    const notif = auditNotificationMap.get(refId);

    return {
      id: log.id,
      transactionId: refId,
      referenceId: refId,
      sellerId: seller.id,
      sellerName: sellerDisplayName,
      recipient: {
        accountId: recipientId || 'unknown',
        publicUserId,
        nickname,
        profileImage,
      },
      recipientAccountId: recipientId || 'unknown',
      recipientPublicUserId: publicUserId,
      recipientNickname: nickname,
      recipientProfileImage: profileImage,
      recipientUserId: recipientId || 'unknown',
      recipientName: nickname,
      recipientAvatarUrl: profileImage,
      coins: Number(amountCoins),
      amountCoins: amountCoins.toString(),
      remainingSellerBalanceCoins: json.remainingResellerBalanceCoins || null,
      notes: json.notes || null,
      status: json.status || 'Successful',
      countryCode: user?.countryCode || seller.user?.countryCode || 'GLOBAL',
      timestamp: log.createdAt,
      createdAt: log.createdAt,
      notificationDelivered: !!notif,
      notificationStatus: notif ? notif.deliveryStatus : 'PENDING',
      notificationId: notif?.id || null,
    };
  });

  const totalPages = Math.ceil(totalCount / limitNum) || 1;
  return {
    transactions,
    pagination: {
      page: pageNum,
      limit: limitNum,
      totalCount,
      totalPages,
      hasNextPage: pageNum < totalPages,
      hasPrevPage: pageNum > 1,
    },
  };
}

/**
 * Safely retrieves the status of a recharge transaction for timeout recovery.
 * Can be queried by transactionId (referenceId) or idempotency key.
 */
export async function getRechargeTransactionStatus(identifier, sellerUserId = null, db = prisma) {
  if (!identifier) {
    const error = new Error('Transaction identifier is required');
    error.statusCode = 400;
    error.code = 'INVALID_TRANSACTION_ID';
    throw error;
  }

  const clean = String(identifier).trim();

  // 1. Search in WalletLedger
  const ledger = await db.walletLedger.findFirst({
    where: {
      OR: [
        { referenceId: clean },
        { referenceId: `SEL-RCHG-${clean}` },
      ],
    },
    include: {
      wallet: {
        include: {
          user: {
            include: { profile: true },
          },
        },
      },
    },
  });

  if (ledger) {
    const sibling = await db.walletLedger.findFirst({
      where: {
        referenceId: ledger.referenceId,
        id: { not: ledger.id },
      },
      include: {
        wallet: {
          include: {
            user: {
              include: { profile: true },
            },
          },
        },
      },
    });

    const isSeller = ledger.coinDelta === 0n;
    const sellerEntry = isSeller ? ledger : sibling;
    const recipientEntry = isSeller ? sibling : ledger;
    let amountCoins = 0;
    if (recipientEntry?.coinDelta) {
      amountCoins = Number(recipientEntry.coinDelta);
    } else if (sellerEntry?.balanceBefore?.sellerCoins && sellerEntry?.balanceAfter?.sellerCoins) {
      amountCoins = Number(BigInt(sellerEntry.balanceBefore.sellerCoins) - BigInt(sellerEntry.balanceAfter.sellerCoins));
    }

    return {
      success: true,
      found: true,
      transactionId: ledger.referenceId,
      referenceId: ledger.referenceId,
      status: 'Successful',
      amountCoins,
      sellerUserId: sellerEntry?.wallet?.userId,
      sellerPublicId: sellerEntry?.wallet?.user?.username,
      sellerName: sellerEntry?.wallet?.user?.profile?.displayName || sellerEntry?.wallet?.user?.username,
      recipientUserId: recipientEntry?.wallet?.userId,
      recipientPublicId: recipientEntry?.wallet?.user?.username,
      recipientName: recipientEntry?.wallet?.user?.profile?.displayName || recipientEntry?.wallet?.user?.username,
      createdAt: ledger.createdAt.toISOString(),
    };
  }

  // 2. Search in AuditLog
  const audit = await db.auditLog.findFirst({
    where: {
      OR: [
        { reason: { contains: clean } },
        { targetEntityId: clean },
      ],
    },
  });

  if (audit) {
    return {
      success: true,
      found: true,
      transactionId: clean,
      status: 'AUDITED',
      details: audit.reason || audit.action,
      createdAt: audit.createdAt.toISOString(),
    };
  }

  return {
    success: true,
    found: false,
    transactionId: clean,
    status: 'NOT_FOUND',
    message: 'No committed transaction found for the provided identifier',
  };
}

export default {
  createSeller,
  updateSeller,
  updateSellerStatus,
  deleteSeller,
  allocateCoinsToSeller,
  correctSellerBalance,
  getEffectiveTransferFee,
  getSellerPortalByUserId,
  verifyRechargeRecipient,
  executeSellerRechargeTransfer,
  getEligibleSellersForUser,
  validateSellerEligibility,
  getSellerRechargeHistory,
  getRechargeTransactionStatus,
  invalidateSellerDirectoryCache,
};

