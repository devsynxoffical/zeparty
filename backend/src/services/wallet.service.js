import walletRepository from '../repositories/wallet.repository.js';
import ledgerRepository from '../repositories/ledger.repository.js';
import ledgerService from './ledger.service.js';
import approvalService, { requiresApproval } from './approval.service.js';
import { sanitizeFinancial } from '../utils/bigint.util.js';
import prisma from '../config/database.js';

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
    walletNotice: 'IMPORTANT NOTE: Withdrawals, transfers, and exchanges are available only on the 1st and 15th of each month.',
    dateRestrictionNotice: 'IMPORTANT NOTE: Withdrawals, transfers, and exchanges are available only on the 1st and 15th of each month.',
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
 * Exchange Diamonds to Gold Coins with 40,000 Diamonds minimum.
 */
export async function exchangeDiamondsToCoins({ userId, diamondAmount }, { ipAddress } = {}) {
  const diamonds = Number(diamondAmount);
  if (!diamonds || isNaN(diamonds) || diamonds < 40000) {
    const error = new Error('Minimum 40,000 Diamonds required for exchange.');
    error.status = 400;
    error.code = 'MINIMUM_DIAMONDS_REQUIRED';
    throw error;
  }

  const wallet = await walletRepository.findByUserId(userId);
  if (!wallet) {
    const error = new Error('Wallet not found');
    error.status = 404;
    throw error;
  }

  const currentDiamonds = Number(wallet.diamondBalance || 0n);
  if (currentDiamonds < diamonds) {
    const error = new Error(`Insufficient Diamonds. You have ${currentDiamonds.toLocaleString()} Diamonds.`);
    error.status = 400;
    error.code = 'INSUFFICIENT_DIAMONDS';
    throw error;
  }

  // Conversion rate: 0.255 coins per diamond (2M -> 510K)
  const coinsToCredit = Math.floor(diamonds * 0.255);

  const updatedWallet = await prisma.$transaction(async (tx) => {
    // Deduct diamonds
    const w = await tx.wallet.update({
      where: { id: wallet.id },
      data: {
        diamondBalance: { decrement: BigInt(diamonds) },
        coinBalance: { increment: BigInt(coinsToCredit) },
      },
    });

    // Record ledger entries
    await tx.ledgerEntry.create({
      data: {
        walletId: wallet.id,
        asset: 'DIAMOND',
        direction: 'DEBIT',
        amount: BigInt(diamonds),
        balanceAfter: w.diamondBalance,
        type: 'DIAMOND_EXCHANGE_DEBIT',
        referenceId: `EX_${Date.now()}`,
        metadata: { exchangedCoins: coinsToCredit, ipAddress },
      },
    });

    await tx.ledgerEntry.create({
      data: {
        walletId: wallet.id,
        asset: 'COIN',
        direction: 'CREDIT',
        amount: BigInt(coinsToCredit),
        balanceAfter: w.coinBalance,
        type: 'DIAMOND_EXCHANGE_CREDIT',
        referenceId: `EX_${Date.now()}`,
        metadata: { deductedDiamonds: diamonds, ipAddress },
      },
    });

    return w;
  });

  return {
    success: true,
    message: `Successfully exchanged ${diamonds.toLocaleString()} Diamonds for ${coinsToCredit.toLocaleString()} Gold Coins.`,
    data: {
      deductedDiamonds: diamonds,
      creditedCoins: coinsToCredit,
      wallet: sanitizeFinancial(updatedWallet),
    },
  };
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

  if (senderUserId === recipientUserId) {
    const error = new Error('Cannot transfer Diamonds to yourself.');
    error.status = 400;
    throw error;
  }

  const [senderWallet, recipientWallet, recipientUser] = await Promise.all([
    walletRepository.findByUserId(senderUserId),
    walletRepository.findByUserId(recipientUserId),
    prisma.user.findUnique({ where: { id: recipientUserId }, select: { id: true, username: true } }),
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
 */
export async function getTransferReceivers({ country = 'GLOBAL', type = 'ALL' } = {}, db = prisma) {
  const coinSellers = [
    {
      id: 'seller_01',
      sellerId: 'CS-88901',
      name: 'ZeParty Prime Exchange',
      type: 'COIN_SELLER',
      country: 'AE',
      isVerified: true,
      status: 'ONLINE',
      rateDisplay: '$1 = 7,700 Coins',
      packages: [
        { id: 'pkg_1', usdValue: 300, diamondsRequired: 3000000, fee: 0 },
        { id: 'pkg_2', usdValue: 500, diamondsRequired: 5000000, fee: 0 },
        { id: 'pkg_3', usdValue: 1000, diamondsRequired: 10000000, fee: 0 },
      ],
    },
  ];

  const merchants = [
    {
      id: 'merchant_01',
      merchantId: 'M-10023',
      name: 'Global Merchant Direct',
      type: 'MERCHANT',
      country: 'GLOBAL',
      isVerified: true,
      status: 'ONLINE',
      rateDisplay: '$1 = 8,400 Coins (20% Profit Rate)',
      packages: [
        { id: 'pkg_m1', usdValue: 3000, diamondsRequired: 25200000, fee: 0 },
      ],
    },
  ];

  return {
    tabs: ['COIN_SELLERS', 'MERCHANTS'],
    coinSellers,
    merchants,
    dateNotice: 'IMPORTANT NOTE: Withdrawals, transfers, and exchanges are available only on the 1st and 15th of each month.',
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
