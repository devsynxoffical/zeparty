import walletRepository from '../repositories/wallet.repository.js';
import ledgerRepository from '../repositories/ledger.repository.js';
import ledgerService from './ledger.service.js';
import approvalService, { requiresApproval } from './approval.service.js';
import { sanitizeFinancial } from '../utils/bigint.util.js';
import prisma from '../config/database.js';
import { getEligibleSellersForUser, validateSellerEligibility } from './seller.service.js';

/**
 * Retrieves a user's wallet with BigInt values safely formatted.
 */
export async function getWallet(userId) {
  const wallet = await walletRepository.findByUserId(userId);
  if (!wallet) {
    const error = new Error('Wallet not found for this user');
    error.status = 404;
    error.code = 'WALLET_NOT_FOUND';
    throw error;
  }
  const sanitized = sanitizeFinancial(wallet);
  return {
    ...sanitized,
    coins: Number(wallet.coinBalance || 0),
    diamonds: Number(wallet.diamondBalance || 0),
    walletNotice: 'IMPORTANT NOTE: Withdrawals and transfers are available only on the 1st and 15th of each month.',
    dateRestrictionNotice: 'IMPORTANT NOTE: Withdrawals and transfers are available only on the 1st and 15th of each month.',
    holdingPeriodDays: 15,
    minDaysUnmutedRequired: 10,
    dailyUnmutedHoursRequired: 2.0,
    showExchangeIcon: false,
    showP2PButton: false,
    showHostWithdrawalBox: false,
    showSellCoinsButton: false,
    allowedActions: ['TRANSFER', 'TOP_UP', 'BUY_FROM_AUTHORIZED_SELLERS'],
  };
}

/**
 * Retrieves paginated ledger history for a user's wallet.
 */
export async function getWalletLedger(userId, { page = 1, limit = 20, type = null }) {
  const wallet = await walletRepository.findByUserId(userId);
  if (!wallet) {
    const error = new Error('Wallet not found');
    error.status = 404;
    error.code = 'WALLET_NOT_FOUND';
    throw error;
  }

  const items = await ledgerRepository.findByWalletId(wallet.id, { page, limit, type });
  const total = await ledgerRepository.countByWalletId(wallet.id, { type });

  return {
    items: items.map((item) => sanitizeFinancial(item)),
    pagination: {
      page: Number(page),
      limit: Number(limit),
      total,
      totalPages: Math.ceil(total / limit) || 1,
    },
  };
}

/**
 * Retrieves master transaction ledger for administrative review.
 */
export async function getMasterLedger({ page = 1, limit = 20, type, userId, referenceId, startDate, endDate }) {
  const items = await ledgerRepository.findAll({ page, limit, type, userId, referenceId, startDate, endDate });
  const total = await ledgerRepository.countAll({ type, userId, referenceId, startDate, endDate });

  return {
    items: items.map((item) => sanitizeFinancial(item)),
    pagination: {
      page: Number(page),
      limit: Number(limit),
      total,
      totalPages: Math.ceil(total / limit) || 1,
    },
  };
}

/**
 * Retrieves platform-wide circulation statistics.
 */
export async function getPlatformWalletStats() {
  const stats = await walletRepository.getPlatformStats();
  return sanitizeFinancial(stats);
}

/**
 * Executes or queues an administrative balance adjustment.
 */
export async function adjustBalance({
  requesterId,
  isOwner = false,
  targetUserId,
  asset, // 'COINS' | 'DIAMONDS'
  direction, // 'CREDIT' | 'DEBIT'
  amount,
  reason,
  ipAddress,
}) {
  const targetWallet = await walletRepository.findByUserId(targetUserId);
  if (!targetWallet) {
    const error = new Error('Target user does not have an active wallet.');
    error.status = 404;
    error.code = 'WALLET_NOT_FOUND';
    throw error;
  }

  const bigAmount = BigInt(amount);

  // Check if financial action requires Two-Stage Approval
  const needsApproval = requiresApproval({ asset, amount: bigAmount }) && !isOwner;

  if (needsApproval) {
    const approval = await approvalService.createApprovalRequest({
      requesterId,
      module: 'wallet',
      actionType: 'BALANCE_ADJUSTMENT',
      beforeStateJson: {
        coinBalance: targetWallet.coinBalance.toString(),
        diamondBalance: targetWallet.diamondBalance.toString(),
      },
      payloadStateJson: {
        targetUserId,
        asset,
        direction,
        amount: bigAmount.toString(),
        reason,
      },
    });

    return {
      approvalRequired: true,
      message: 'Adjustment amount exceeds threshold ($100 USD equivalent) and was queued for two-stage approval.',
      approvalId: approval.id,
      status: 'PENDING',
    };
  }

  // Direct Execution for authorized requests below threshold or from Root Owner
  const execution = await ledgerService.executeDirectAdjustment({
    walletId: targetWallet.id,
    asset,
    direction,
    amount: bigAmount,
    reason,
  });

  // Log to AuditLog
  await prisma.auditLog.create({
    data: {
      adminId: requesterId,
      adminName: isOwner ? 'Root Owner' : 'Administrator',
      action: 'BALANCE_ADJUSTED',
      targetEntity: 'Wallet',
      targetEntityId: targetWallet.id,
      afterStateJson: {
        asset,
        direction,
        amount: bigAmount.toString(),
        reason,
      },
      reason,
      ipAddress,
    },
  }).catch(() => {});

  return {
    approvalRequired: false,
    message: 'Balance adjustment executed successfully.',
    referenceId: execution.referenceId,
    results: execution.results,
  };
}

/**
 * Exchange Diamonds to Gold Coins is strictly prohibited per Bug 21 product rule.
 * Diamonds are for display within ZeParty only.
 */
export async function exchangeDiamondsToCoins({ userId, diamondAmount } = {}, { ipAddress } = {}) {
  const error = new Error('Coin and Diamond exchange is strictly prohibited. Diamonds are for display within ZeParty only.');
  error.status = 400;
  error.statusCode = 400;
  error.code = 'EXCHANGE_PROHIBITED';
  throw error;
}

/**
 * Transfer Diamonds to another user with 40,000 Diamonds minimum.
 */
export async function transferDiamonds({ senderUserId, recipientUserId, diamondAmount }, { ipAddress } = {}) {
  const diamonds = Number(diamondAmount);
  if (!diamonds || isNaN(diamonds) || diamonds < 40000) {
    const error = new Error('Minimum 40,000 Diamonds required for transfer.');
    error.status = 400;
    error.code = 'MINIMUM_DIAMONDS_REQUIRED';
    throw error;
  }

  // Resolve recipient if a CoinSeller ID was provided or if recipient is an authorized coin seller
  let effectiveRecipientUserId = recipientUserId;
  const sellerRecord = await prisma.coinSeller.findFirst({
    where: {
      OR: [
        { id: recipientUserId },
        { userId: recipientUserId },
      ],
    },
    include: { user: { select: { id: true, countryCode: true, region: true, status: true } } },
  });

  if (sellerRecord) {
    effectiveRecipientUserId = sellerRecord.userId;
    // Authoritatively revalidate seller active status and strict country matching
    await validateSellerEligibility(sellerRecord.id, senderUserId, prisma);
  }

  if (senderUserId === effectiveRecipientUserId) {
    const error = new Error('Cannot transfer Diamonds to yourself.');
    error.status = 400;
    throw error;
  }

  const [senderWallet, recipientWallet, recipientUser] = await Promise.all([
    walletRepository.findByUserId(senderUserId),
    walletRepository.findByUserId(effectiveRecipientUserId),
    prisma.user.findUnique({ where: { id: effectiveRecipientUserId }, select: { id: true, username: true } }),
  ]);

  if (!senderWallet) {
    const error = new Error('Sender wallet not found');
    error.status = 404;
    throw error;
  }

  if (!recipientWallet || !recipientUser) {
    const error = new Error('Recipient user not found or has no active wallet.');
    error.status = 404;
    throw error;
  }

  const senderDiamonds = Number(senderWallet.diamondBalance || 0n);
  if (senderDiamonds < diamonds) {
    const error = new Error(`Insufficient Diamonds. You have ${senderDiamonds.toLocaleString()} Diamonds.`);
    error.status = 400;
    error.code = 'INSUFFICIENT_DIAMONDS';
    throw error;
  }

  const result = await prisma.$transaction(async (tx) => {
    // Deduct from sender
    const updatedSender = await tx.wallet.update({
      where: { id: senderWallet.id },
      data: { diamondBalance: { decrement: BigInt(diamonds) } },
    });

    // Credit to recipient
    const updatedRecipient = await tx.wallet.update({
      where: { id: recipientWallet.id },
      data: { diamondBalance: { increment: BigInt(diamonds) } },
    });

    const refId = `TR_${Date.now()}`;

    // Ledger for sender
    await tx.ledgerEntry.create({
      data: {
        walletId: senderWallet.id,
        asset: 'DIAMOND',
        direction: 'DEBIT',
        amount: BigInt(diamonds),
        balanceAfter: updatedSender.diamondBalance,
        type: 'DIAMOND_TRANSFER_OUT',
        referenceId: refId,
        metadata: { recipientUserId, recipientUsername: recipientUser.username, ipAddress },
      },
    });

    // Ledger for recipient
    await tx.ledgerEntry.create({
      data: {
        walletId: recipientWallet.id,
        asset: 'DIAMOND',
        direction: 'CREDIT',
        amount: BigInt(diamonds),
        balanceAfter: updatedRecipient.diamondBalance,
        type: 'DIAMOND_TRANSFER_IN',
        referenceId: refId,
        metadata: { senderUserId, ipAddress },
      },
    });

    return { updatedSender, updatedRecipient };
  });

  return {
    success: true,
    message: `Successfully transferred ${diamonds.toLocaleString()} Diamonds to @${recipientUser.username}.`,
    data: {
      transferredDiamonds: diamonds,
      recipient: recipientUser,
      wallet: sanitizeFinancial(result.updatedSender),
    },
  };
}

/**
 * Module 21: Diamond Details Categorized Ledger
 */
export async function getDiamondDetails(userId, { tab = 'ALL', page = 1, limit = 20 } = {}, db = prisma) {
  const tabs = ['ALL', 'HOST_SALARY', 'AGENT_SALARY', 'TRANSFER', 'EXCHANGE', 'WITHDRAWAL', 'GIFT_REWARD', 'REFUND_REVERSAL'];
  const mockTransactions = [
    {
      id: 'tx_diamond_01',
      type: 'HOST_SALARY',
      category: 'HOST_SALARY',
      title: '[system] Settlement Host Salary',
      source: 'ZeParty Official Settlement',
      amount: '+1,000',
      currency: 'DIAMOND',
      status: 'COMPLETED',
      date: new Date(Date.now() - 3600000).toISOString(),
    },
    {
      id: 'tx_diamond_02',
      type: 'AGENT_SALARY',
      category: 'AGENT_SALARY',
      title: '[system] Settlement Agent Salary',
      source: 'Agency Commission Share',
      amount: '+200',
      currency: 'DIAMOND',
      status: 'COMPLETED',
      date: new Date(Date.now() - 7200000).toISOString(),
    },
    {
      id: 'tx_diamond_03',
      type: 'TRANSFER',
      category: 'TRANSFER',
      title: 'Transfer to User 12345',
      source: 'Coin Seller Payout',
      amount: '-5,000',
      currency: 'DIAMOND',
      status: 'COMPLETED',
      date: new Date(Date.now() - 10800000).toISOString(),
    },
    {
      id: 'tx_diamond_04',
      type: 'EXCHANGE',
      category: 'EXCHANGE',
      title: 'Exchange to Gold Coins',
      source: 'Diamond-to-Coin Conversion',
      amount: '-10,000',
      currency: 'DIAMOND',
      status: 'COMPLETED',
      date: new Date(Date.now() - 14400000).toISOString(),
    },
  ];

  const filtered = tab === 'ALL' ? mockTransactions : mockTransactions.filter((tx) => tx.category === tab);

  return {
    tabs,
    activeTab: tab,
    items: filtered,
    pagination: { page: Number(page), limit: Number(limit), total: filtered.length },
  };
}

/**
 * Module 22: Transfer Receiver Directory (Coin Sellers & Merchants)
 * Backed by real database records and strictly filtered by the authenticated user's registered country.
 * Returns empty arrays and explicit user-facing notice if no eligible sellers exist in the user's country.
 */
export async function getTransferReceivers({ userId, search = '', type = 'ALL' } = {}, db = prisma) {
  let coinSellers = [];
  let userCountry = null;
  let notice = null;

  const typeNorm = (type || 'ALL').toUpperCase();

  if (userId && (typeNorm === 'ALL' || typeNorm === 'COIN_SELLERS' || typeNorm === 'COIN SELLER' || typeNorm === 'COIN SELLERS')) {
    const sellersResult = await getEligibleSellersForUser({ userId, search, page: 1, limit: 50 }, db);
    userCountry = sellersResult.userCountry;
    coinSellers = sellersResult.sellers.map((s) => ({
      id: s.id,
      sellerId: s.id,
      userId: s.userId,
      name: s.name,
      type: 'COIN_SELLER',
      country: s.country,
      region: s.region,
      isVerified: true,
      status: 'ONLINE',
      rateDisplay: '$1 = 7,700 Coins',
      packages: [
        { id: `pkg_${s.id}_1`, usdValue: 300, diamondsRequired: 3000000, fee: 0 },
        { id: `pkg_${s.id}_2`, usdValue: 500, diamondsRequired: 5000000, fee: 0 },
        { id: `pkg_${s.id}_3`, usdValue: 1000, diamondsRequired: 10000000, fee: 0 },
      ],
    }));

    if (coinSellers.length === 0) {
      notice = 'No authorized coin sellers available in your country';
    }
  }

  // Authoritative active merchants from database
  let merchants = [];
  if (typeNorm === 'ALL' || typeNorm === 'MERCHANTS' || typeNorm === 'MERCHANT') {
    const whereMerchant = { status: 'ACTIVE', user: { status: 'ACTIVE' } };
    if (search && search.trim()) {
      whereMerchant.companyName = { contains: search.trim(), mode: 'insensitive' };
    }
    const dbMerchants = await db.merchant.findMany({
      where: whereMerchant,
      take: 20,
      include: { user: { select: { id: true, username: true, countryCode: true, profile: true } } },
    });
    merchants = dbMerchants.map((m) => ({
      id: m.id,
      merchantId: m.id,
      userId: m.userId,
      name: m.companyName || m.user?.profile?.displayName || m.user?.username || 'Merchant Direct',
      type: 'MERCHANT',
      country: m.user?.countryCode || 'GLOBAL',
      isVerified: true,
      status: 'ONLINE',
      rateDisplay: '$1 = 8,400 Coins (20% Profit Rate)',
      packages: [
        { id: `pkg_m_${m.id}`, usdValue: 3000, diamondsRequired: 25200000, fee: 0 },
      ],
    }));
  }

  return {
    tabs: ['COIN_SELLERS', 'MERCHANTS'],
    coinSellers,
    merchants,
    userCountry: userCountry ? userCountry.code : null,
    notice,
    dateNotice: 'IMPORTANT NOTE: Withdrawals and transfers are available only on the 1st and 15th of each month.',
  };
}

/**
 * Module 30: Wallet Coin Records (All, Income [+], Expenses [−])
 */
export async function getCoinRecords(userId, { tab = 'ALL', page = 1, limit = 20 } = {}, db = prisma) {
  const tabs = ['ALL', 'INCOME', 'EXPENSES'];
  const mockCoinRecords = [
    {
      id: 'rec_coin_01',
      type: 'INCOME',
      description: 'Coin Package Recharge',
      amount: '+50,000',
      currency: 'COINS',
      status: 'SUCCESSFUL',
      date: new Date(Date.now() - 1800000).toISOString(),
    },
    {
      id: 'rec_coin_02',
      type: 'EXPENSES',
      description: 'Room Gift Sent (Danial Khan to Sophia Rose)',
      amount: '-10,000',
      currency: 'COINS',
      status: 'SUCCESSFUL',
      date: new Date(Date.now() - 3600000).toISOString(),
    },
    {
      id: 'rec_coin_03',
      type: 'INCOME',
      description: 'Lucky Gift Multiplier Reward (10x)',
      amount: '+25,000',
      currency: 'COINS',
      status: 'SUCCESSFUL',
      date: new Date(Date.now() - 7200000).toISOString(),
    },
  ];

  const filtered = tab === 'ALL' ? mockCoinRecords : mockCoinRecords.filter((r) => r.type === tab);

  return {
    tabs,
    activeTab: tab,
    items: filtered,
    pagination: { page: Number(page), limit: Number(limit), total: filtered.length },
  };
}

export default {
  getWallet,
  getWalletLedger,
  getMasterLedger,
  getPlatformWalletStats,
  adjustBalance,
  exchangeDiamondsToCoins,
  transferDiamonds,
  getDiamondDetails,
  getTransferReceivers,
  getCoinRecords,
};
