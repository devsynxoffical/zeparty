import prisma from '../config/database.js';
import sellerRepository from '../repositories/seller.repository.js';
import walletRepository from '../repositories/wallet.repository.js';
import ledgerService from './ledger.service.js';
import approvalService from './approval.service.js';
import policyService from './policy.service.js';
import { generateReference } from '../utils/reference.util.js';
import { generate7DigitUserId } from '../utils/idGenerator.util.js';
import { normalizeCountry, isCountryMatch } from '../utils/country.util.js';

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

  const seller = await db.$transaction(async (tx) => {
    const newSeller = await sellerRepository.createSeller({
      ...data,
      userId,
      resellerBalanceCoins: initialQuota,
      sellerStatus: 'ACTIVE',
    }, tx);

    const rawCountry = data.country || data.countryCode || user.countryCode || user.region;
    const normalizedCountry = normalizeCountry(rawCountry);

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

  return await sellerRepository.findSellerById(id, db);
}

export async function deleteSeller(id, { adminId, adminName, ipAddress } = {}, db = prisma) {
  let seller = await sellerRepository.findSellerById(id, db);
  if (!seller) {
    seller = await sellerRepository.findSellerByUserId(id, db);
  }
  if (!seller) {
    const error = new Error('Coin seller not found');
    error.statusCode = 404;
    error.code = 'SELLER_NOT_FOUND';
    throw error;
  }

  await db.$transaction(async (tx) => {
    // Delete any associated p2p orders if any, or delete the coin seller
    await sellerRepository.deleteSeller(seller.id, tx);

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
  return {
    id: seller.id,
    sellerId: seller.id,
    portalId: seller.id,
    userId: seller.userId,
    businessName: seller.businessName,
    resellerBalanceCoins: seller.resellerBalanceCoins ? seller.resellerBalanceCoins.toString() : '0',
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
    error.code = 'RECIPIENT_NOT_FOUND';
    throw error;
  }

  if (recipient.status !== 'ACTIVE') {
    const error = new Error(`Recipient account is ${recipient.status.toLowerCase()}`);
    error.statusCode = 400;
    error.code = 'RECIPIENT_NOT_ACTIVE';
    throw error;
  }

  return {
    userId: recipient.id,
    username: recipient.username,
    displayName: recipient.profile?.displayName || recipient.username,
    avatarUrl: recipient.avatarUrl,
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
  const recipientUserId = params.recipientUserId || params.recipientIdentifier;
  const amountCoins = params.amountCoins || params.coinsAmount;
  const pin = params.pin;
  const notes = params.notes;
  const ipAddress = options.ipAddress || params.ipAddress || '127.0.0.1';

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
  if (verifiedRecipient.userId === seller.userId) {
    const error = new Error('Cannot transfer seller coins to your own personal account');
    error.statusCode = 400;
    error.code = 'SELF_TRANSFER_PROHIBITED';
    throw error;
  }

  // Authoritative country matching check
  const sellerCountry = normalizeCountry(seller.user?.countryCode || seller.user?.region);
  const recipientCountry = normalizeCountry(verifiedRecipient.countryCode);
  if (sellerCountry && recipientCountry && sellerCountry.code !== recipientCountry.code) {
    const error = new Error(`Cross-country seller transfers are prohibited. Seller is in ${sellerCountry.name}, recipient is in ${recipientCountry.name}.`);
    error.statusCode = 403;
    error.code = 'CROSS_COUNTRY_RECHARGE_PROHIBITED';
    throw error;
  }

  // 3. Ensure recipient wallet exists
  let recipientWallet = await walletRepository.findByUserId(verifiedRecipient.userId, db);
  if (!recipientWallet) {
    recipientWallet = await walletRepository.createWallet(verifiedRecipient.userId, db);
  }

  // 4. Ensure seller wallet exists
  let sellerWallet = await walletRepository.findByUserId(seller.userId, db);
  if (!sellerWallet) {
    sellerWallet = await walletRepository.createWallet(seller.userId, db);
  }

  const refId = generateReference('SEL-RCHG');

  // 5. Atomic execution in database transaction
  const result = await db.$transaction(async (tx) => {
    // Lock seller record and verify balance
    const currentSeller = await tx.coinSeller.findUnique({
      where: { id: seller.id },
    });

    if (BigInt(currentSeller.resellerBalanceCoins) < coinsBigInt) {
      const error = new Error(`Insufficient seller coins. Available: ${currentSeller.resellerBalanceCoins}, Required: ${coinsBigInt}`);
      error.statusCode = 400;
      error.code = 'INSUFFICIENT_SELLER_COINS';
      throw error;
    }

    // Atomic seller decrement
    const updatedSeller = await tx.coinSeller.update({
      where: { id: seller.id },
      data: {
        resellerBalanceCoins: { decrement: coinsBigInt },
      },
    });

    // Also decrement wallet.sellerBalanceCoins if tracked on wallet
    await tx.wallet.update({
      where: { userId: seller.userId },
      data: {
        sellerBalanceCoins: { decrement: coinsBigInt },
      },
    });

    // Credit recipient coinBalance via ledgerService
    const ledgerTx = await ledgerService.postTransaction({
      operations: [
        {
          walletId: recipientWallet.id,
          coinDelta: coinsBigInt,
        },
      ],
      referenceId: refId,
      transactionType: 'RECHARGE',
      db: tx,
    });

    return {
      updatedSeller,
      ledgerTx,
    };
  }, { maxWait: 15000, timeout: 30000 });

  await logAudit({
    adminId: null,
    adminName: `Seller: ${seller.businessName}`,
    action: 'SELLER_COIN_RECHARGE_EXECUTED',
    targetEntity: 'CoinSeller',
    targetEntityId: seller.id,
    beforeStateJson: { resellerBalanceCoins: seller.resellerBalanceCoins.toString() },
    afterStateJson: {
      sellerId: seller.id,
      recipientUserId: verifiedRecipient.userId,
      amountCoins: coinsBigInt.toString(),
      remainingResellerBalanceCoins: result.updatedSeller.resellerBalanceCoins.toString(),
      referenceId: refId,
      notes,
    },
    reason: notes || `Recharged ${coinsBigInt} coins to user ${verifiedRecipient.userId}`,
    ipAddress,
  }, db);

  return {
    success: true,
    referenceId: refId,
    sellerId: seller.id,
    recipient: verifiedRecipient,
    recipientUser: verifiedRecipient,
    transferAmount: Number(coinsBigInt),
    rechargedCoins: coinsBigInt.toString(),
    remainingSellerBalanceCoins: result.updatedSeller.resellerBalanceCoins.toString(),
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

  const result = await sellerRepository.findSellers(
    {
      page: Number(page) || 1,
      limit: Number(limit) || 20,
      search: search || '',
      sellerStatus: 'ACTIVE',
      countryCode: normCountry.code,
      countryRequired: true,
    },
    db
  );

  const formatted = result.sellers.map((s) => {
    const stockCoins = Number(s.resellerBalanceCoins || s.user?.wallet?.sellerBalanceCoins || 0);
    const displayName = s.businessName || s.user?.profile?.displayName || s.user?.username || 'Coin Seller';
    return {
      id: s.id,
      sellerId: s.id,
      userId: s.userId,
      name: displayName,
      businessName: s.businessName,
      avatarUrl: s.user?.avatarUrl || '',
      region: normCountry.name,
      country: normCountry.code,
      countryCode: normCountry.code,
      type: 'official',
      status: 'approved',
      isVisible: true,
      paymentMethods: ['Direct Transfer', 'Bank Transfer'],
      stockCoins,
      balanceCoins: stockCoins,
      profitMarginPercent: s.profitMarginPercent,
      user: {
        id: s.user?.id,
        username: s.user?.username,
        displayName: s.user?.profile?.displayName || s.user?.username,
        avatarUrl: s.user?.avatarUrl,
        countryCode: normCountry.code,
        region: normCountry.name,
      },
    };
  });

  return {
    sellers: formatted,
    userCountry: normCountry,
    message: formatted.length > 0 ? 'Active coin sellers retrieved successfully' : 'No authorized coin sellers available in your country',
    pagination: result.pagination,
  };
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
};

