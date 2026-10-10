import withdrawalRepository from '../repositories/withdrawal.repository.js';
import walletRepository from '../repositories/wallet.repository.js';
import ledgerService from './ledger.service.js';
import { sanitizeFinancial } from '../utils/bigint.util.js';
import prisma from '../config/database.js';

export async function getWithdrawals({ status, userId, page = 1, limit = 20 }) {
  const items = await withdrawalRepository.findAll({ status, userId, page, limit });
  const total = await withdrawalRepository.countAll({ status, userId });

  return {
    items: items.map((w) => sanitizeFinancial(w)),
    pagination: {
      page: Number(page),
      limit: Number(limit),
      total,
      totalPages: Math.ceil(total / limit) || 1,
    },
  };
}

export async function approveWithdrawal({ id, adminId, isOwner = false, ipAddress }) {
  const request = await withdrawalRepository.findById(id);
  if (!request) {
    const error = new Error('Withdrawal request not found');
    error.status = 404;
    error.code = 'NOT_FOUND';
    throw error;
  }

  if (request.status !== 'PENDING') {
    const error = new Error(`Withdrawal request has already been processed with status: ${request.status}`);
    error.status = 400;
    error.code = 'ALREADY_PROCESSED';
    throw error;
  }

  const wallet = await walletRepository.findByUserId(request.userId);
  if (!wallet) {
    const error = new Error('Host wallet not found');
    error.status = 404;
    error.code = 'WALLET_NOT_FOUND';
    throw error;
  }

  const diamondsDebited = BigInt(request.diamondsDebited);
  const amountUSD = Number(request.amountUSD);

  return await prisma.$transaction(async (tx) => {
    // 1. Update WithdrawalRequest
    const updated = await withdrawalRepository.updateStatus(
      id,
      {
        status: 'APPROVED',
        reviewerAdminId: adminId,
        reviewedAt: new Date(),
      },
      tx
    );

    // 2. Post atomic ledger withdrawal
    const ledgerResult = await ledgerService.postTransaction({
      operations: [
        {
          walletId: wallet.id,
          diamondDelta: -diamondsDebited,
          usdDelta: -amountUSD,
          withdrawnDeltaUSD: amountUSD,
        },
      ],
      referenceId: `WD-${request.id}`,
      transactionType: 'WITHDRAWAL',
      db: tx,
    });

    // 3. Emit AuditLog
    await tx.auditLog.create({
      data: {
        adminId,
        adminName: isOwner ? 'Root Owner' : 'Administrator',
        action: 'WITHDRAWAL_APPROVED',
        targetEntity: 'WithdrawalRequest',
        targetEntityId: id,
        afterStateJson: {
          diamondsDebited: diamondsDebited.toString(),
          amountUSD,
          referenceId: ledgerResult.referenceId,
        },
        reason: `Approved diamond cashout of $${amountUSD} for host ${request.user?.username}`,
        ipAddress,
      },
    });

    return {
      success: true,
      message: 'Withdrawal approved and diamonds debited successfully.',
      withdrawal: sanitizeFinancial(updated),
      ledger: ledgerResult,
    };
  });
}

export async function rejectWithdrawal({ id, adminId, isOwner = false, reason, ipAddress }) {
  const request = await withdrawalRepository.findById(id);
  if (!request) {
    const error = new Error('Withdrawal request not found');
    error.status = 404;
    error.code = 'NOT_FOUND';
    throw error;
  }

  if (request.status !== 'PENDING') {
    const error = new Error(`Withdrawal request has already been processed with status: ${request.status}`);
    error.status = 400;
    error.code = 'ALREADY_PROCESSED';
    throw error;
  }

  return await prisma.$transaction(async (tx) => {
    const updated = await withdrawalRepository.updateStatus(
      id,
      {
        status: 'REJECTED',
        reviewerAdminId: adminId,
        rejectionReason: reason,
        reviewedAt: new Date(),
      },
      tx
    );

    await tx.auditLog.create({
      data: {
        adminId,
        adminName: isOwner ? 'Root Owner' : 'Administrator',
        action: 'WITHDRAWAL_REJECTED',
        targetEntity: 'WithdrawalRequest',
        targetEntityId: id,
        reason,
        ipAddress,
      },
    });

    return {
      success: true,
      message: 'Withdrawal request rejected.',
      withdrawal: sanitizeFinancial(updated),
    };
  });
}

function getCountryFlag(countryCode) {
  if (!countryCode || countryCode.length !== 2) return '🌐';
  try {
    const codePoints = countryCode
      .toUpperCase()
      .split('')
      .map(c => 127397 + c.charCodeAt(0));
    return String.fromCodePoint(...codePoints);
  } catch {
    return '🌐';
  }
}

/**
 * Fetch active, authorized withdrawal recipients filtered strictly by user ID country.
 * Supports COIN_SELLER and MERCHANT tabs.
 */
export async function getWithdrawalRecipients({ userId, type = 'COIN_SELLER' }, db = prisma) {
  const user = await db.user.findUnique({
    where: { id: userId },
    select: { id: true, countryCode: true, username: true },
  });

  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  if (!user.countryCode || user.countryCode.trim() === '') {
    const error = new Error('No registered country saved for your user account. Please configure your account country before requesting withdrawals.');
    error.statusCode = 400;
    error.code = 'COUNTRY_NOT_SET';
    throw error;
  }

  const country = user.countryCode.trim().toUpperCase();
  const normalizedType = String(type).toUpperCase();

  if (normalizedType === 'MERCHANT') {
    const merchants = await db.merchant.findMany({
      where: {
        status: 'ACTIVE',
        user: {
          countryCode: country,
        },
      },
      include: {
        user: {
          select: { id: true, username: true, countryCode: true, profile: true },
        },
      },
    });

    return {
      country,
      type: 'MERCHANT',
      countryFlag: getCountryFlag(country),
      recipients: merchants.map(m => ({
        id: m.id,
        recipientId: m.id,
        userId: m.userId,
        name: m.companyName || m.user.profile?.displayName || m.user.username,
        uniqueId: m.user.username || m.id.slice(0, 8),
        role: 'MERCHANT',
        roleLabel: 'Authorized Merchant',
        countryCode: country,
        countryFlag: getCountryFlag(country),
        status: m.status,
      })),
    };
  }

  // Default: COIN_SELLER
  const sellers = await db.coinSeller.findMany({
    where: {
      sellerStatus: 'ACTIVE',
      user: {
        countryCode: country,
      },
    },
    include: {
      user: {
        select: { id: true, username: true, countryCode: true, profile: true },
      },
    },
  });

  return {
    country,
    type: 'COIN_SELLER',
    countryFlag: getCountryFlag(country),
    recipients: sellers.map(s => ({
      id: s.id,
      recipientId: s.id,
      userId: s.userId,
      name: s.businessName || s.user.profile?.displayName || s.user.username,
      uniqueId: s.user.username || s.id.slice(0, 8),
      role: 'COIN_SELLER',
      roleLabel: 'Authorized Coin Seller',
      countryCode: country,
      countryFlag: getCountryFlag(country),
      status: s.sellerStatus,
    })),
  };
}

/**
 * Submit Host or Creator Withdrawal Request.
 * Re-validates user country, recipient country, active status, and available balance.
 */
export async function createWithdrawalRequest({ userId, recipientId, recipientRole = 'COIN_SELLER', amountUSD, ipAddress }, db = prisma) {
  const parsedAmount = Number(amountUSD);
  if (!parsedAmount || isNaN(parsedAmount) || parsedAmount <= 0) {
    const error = new Error('Please enter a valid withdrawal amount greater than $0.00');
    error.statusCode = 400;
    error.code = 'INVALID_AMOUNT';
    throw error;
  }

  const user = await db.user.findUnique({
    where: { id: userId },
    include: {
      wallet: true,
      hostProfile: true,
    },
  });

  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  if (!user.countryCode || user.countryCode.trim() === '') {
    const error = new Error('Your user account has no registered country saved. Withdrawal cannot proceed.');
    error.statusCode = 400;
    error.code = 'COUNTRY_NOT_SET';
    throw error;
  }

  const userCountry = user.countryCode.trim().toUpperCase();

  // Validate available balance
  const diamondBalance = Number(user.wallet?.diamondBalance || 0n);
  const pendingRequests = await db.withdrawalRequest.findMany({
    where: { userId, status: 'PENDING' },
  });
  const pendingUSD = pendingRequests.reduce((sum, w) => sum + Number(w.amountUSD), 0);
  const availableUSD = Math.max(0, Math.round(((diamondBalance / 12500) - pendingUSD) * 100) / 100);

  if (availableUSD <= 0 || parsedAmount > availableUSD) {
    const error = new Error(`Insufficient available salary. Available: $${availableUSD.toFixed(2)}, Requested: $${parsedAmount.toFixed(2)}`);
    error.statusCode = 400;
    error.code = 'INSUFFICIENT_BALANCE';
    throw error;
  }

  // Validate recipient and cross-country restriction
  const normalizedRole = String(recipientRole).toUpperCase();
  let recipientUser = null;
  let recipientName = '';

  if (normalizedRole === 'MERCHANT') {
    const merchant = await db.merchant.findFirst({
      where: {
        OR: [{ id: recipientId }, { userId: recipientId }],
        status: 'ACTIVE',
      },
      include: {
        user: true,
      },
    });

    if (!merchant) {
      const error = new Error('Selected Merchant is not active or authorized');
      error.statusCode = 404;
      error.code = 'RECIPIENT_NOT_FOUND';
      throw error;
    }

    if (merchant.user?.countryCode?.toUpperCase() !== userCountry) {
      const error = new Error(`Cross-country withdrawal is forbidden. Your account is registered in ${userCountry}, while the recipient is registered in ${merchant.user?.countryCode || 'another country'}.`);
      error.statusCode = 403;
      error.code = 'CROSS_COUNTRY_WITHDRAWAL_FORBIDDEN';
      throw error;
    }

    recipientUser = merchant.user;
    recipientName = merchant.companyName || merchant.user.username;
  } else {
    // COIN_SELLER
    const seller = await db.coinSeller.findFirst({
      where: {
        OR: [{ id: recipientId }, { userId: recipientId }],
        sellerStatus: 'ACTIVE',
      },
      include: {
        user: true,
      },
    });

    if (!seller) {
      const error = new Error('Selected Coin Seller is not active or authorized');
      error.statusCode = 404;
      error.code = 'RECIPIENT_NOT_FOUND';
      throw error;
    }

    if (seller.user?.countryCode?.toUpperCase() !== userCountry) {
      const error = new Error(`Cross-country withdrawal is forbidden. Your account is registered in ${userCountry}, while the recipient is registered in ${seller.user?.countryCode || 'another country'}.`);
      error.statusCode = 403;
      error.code = 'CROSS_COUNTRY_WITHDRAWAL_FORBIDDEN';
      throw error;
    }

    recipientUser = seller.user;
    recipientName = seller.businessName || seller.user.username;
  }

  const diamondsDebited = BigInt(Math.round(parsedAmount * 12500));

  return await db.$transaction(async (tx) => {
    const newRequest = await tx.withdrawalRequest.create({
      data: {
        userId,
        amountUSD: parsedAmount,
        diamondsDebited,
        payoutMethod: normalizedRole,
        accountDetails: {
          recipientId,
          recipientUserId: recipientUser.id,
          recipientName,
          recipientRole: normalizedRole,
          country: userCountry,
          userCountry,
          submittedAt: new Date().toISOString(),
        },
        status: 'PENDING',
      },
    });

    await tx.auditLog.create({
      data: {
        adminId: 'SYSTEM',
        adminName: 'Withdrawal Engine',
        action: 'HOST_WITHDRAWAL_REQUESTED',
        targetEntity: 'WithdrawalRequest',
        targetEntityId: newRequest.id,
        afterStateJson: {
          userId,
          amountUSD: parsedAmount,
          recipientId,
          recipientName,
          recipientRole: normalizedRole,
          country: userCountry,
        },
        reason: `Host requested salary withdrawal of $${parsedAmount} to ${normalizedRole} (${recipientName}) in ${userCountry}`,
        ipAddress: ipAddress || '127.0.0.1',
      },
    });

    return {
      success: true,
      message: `Withdrawal request for $${parsedAmount.toFixed(2)} submitted successfully.`,
      withdrawal: sanitizeFinancial(newRequest),
    };
  });
}

export default {
  getWithdrawals,
  approveWithdrawal,
  rejectWithdrawal,
  getWithdrawalRecipients,
  createWithdrawalRequest,
};

