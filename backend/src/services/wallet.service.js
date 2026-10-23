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
 * Resolves real counterparties, calculates accurate signed amounts, directions,
 * and user-friendly descriptions for raw WalletLedger entries.
 */
async function enrichLedgerEntries(items, currentUserId, db = prisma) {
  if (!items || items.length === 0) return [];

  const refIds = items.map((i) => i.referenceId).filter(Boolean);
  const selRefIds = refIds.filter((id) => typeof id === 'string' && id.startsWith('SEL-RCHG'));

  // 1. Batch resolve counterparties for seller recharges
  let relatedLedgers = [];
  let relatedNotifications = [];
  if (selRefIds.length > 0) {
    [relatedLedgers, relatedNotifications] = await Promise.all([
      db.walletLedger.findMany({
        where: { referenceId: { in: selRefIds } },
        include: {
          wallet: {
            include: {
              user: {
                select: {
                  id: true,
                  username: true,
                  avatarUrl: true,
                  profile: {
                    select: { displayName: true },
                  },
                },
              },
            },
          },
        },
      }),
      db.notification.findMany({
        where: {
          sourceType: 'RECHARGE',
          sourceId: { in: selRefIds },
        },
        select: {
          sourceId: true,
          title: true,
          body: true,
          dataJson: true,
        },
      }),
    ]);
  }

  // Map referenceId -> counterparty info for seller recharges
  const refToLedgersMap = new Map();
  for (const l of relatedLedgers) {
    if (!l.referenceId) continue;
    if (!refToLedgersMap.has(l.referenceId)) {
      refToLedgersMap.set(l.referenceId, []);
    }
    refToLedgersMap.get(l.referenceId).push(l);
  }

  const notifMap = new Map();
  for (const n of relatedNotifications) {
    if (n.sourceId) notifMap.set(n.sourceId, n);
  }

  return items.map((rawItem) => {
    const item = sanitizeFinancial(rawItem);
    const coinDelta = BigInt(rawItem.coinDelta ?? 0n);
    const diamondDelta = BigInt(rawItem.diamondDelta ?? 0n);
    const usdDelta = Number(rawItem.usdDelta ?? 0);

    // Determine asset and signed amount
    let asset = 'COINS';
    let signedAmount = 0;
    if (coinDelta !== 0n) {
      asset = 'COINS';
      signedAmount = Number(coinDelta);
    } else if (diamondDelta !== 0n) {
      asset = 'DIAMONDS';
      signedAmount = Number(diamondDelta);
    } else if (usdDelta !== 0) {
      asset = 'USD';
      signedAmount = usdDelta;
    }

    const direction = signedAmount >= 0 ? 'INCOME' : 'EXPENSE';
    const absAmount = Math.abs(signedAmount);

    // Parse integer balance before and after
    let coinBalanceBefore = 0;
    let coinBalanceAfter = 0;
    if (rawItem.balanceBefore && typeof rawItem.balanceBefore === 'object') {
      coinBalanceBefore = Number(rawItem.balanceBefore.coins ?? 0);
    }
    if (rawItem.balanceAfter && typeof rawItem.balanceAfter === 'object') {
      coinBalanceAfter = Number(rawItem.balanceAfter.coins ?? 0);
    }

    // Default counterparty & description
    let targetUserId = null;
    let counterparty = null;
    let description = `${asset} ${rawItem.transactionType || 'TRANSACTION'}`;
    let category = rawItem.transactionType || 'TRANSACTION';

    const refId = rawItem.referenceId || '';

    // Handle SEL-RCHG (Agency Seller Recharge)
    if (refId.startsWith('SEL-RCHG')) {
      category = 'RECHARGE';
      const siblings = refToLedgersMap.get(refId) || [];
      const notif = notifMap.get(refId);
      const notifMeta = notif?.dataJson && typeof notif.dataJson === 'object' ? notif.dataJson : {};

      if (coinDelta > 0n) {
        // Current user is the recipient receiving coins from a seller -> Income +N
        const sellerEntry = siblings.find((s) => BigInt(s.coinDelta ?? 0n) === 0n && s.wallet?.userId !== currentUserId);
        const sellerUser = sellerEntry?.wallet?.user;

        const sellerPublicId = notifMeta.sellerPublicId || sellerUser?.username || 'Coin Seller';
        const sellerDisplayName = notifMeta.sellerName || sellerUser?.profile?.displayName || sellerPublicId;
        const sellerAvatar = sellerUser?.avatarUrl || null;

        targetUserId = sellerPublicId;
        counterparty = {
          id: sellerUser?.id || null,
          username: sellerPublicId,
          displayName: sellerDisplayName,
          avatarUrl: sellerAvatar,
        };
        description = `Coins Recharged by ${sellerDisplayName} (@${sellerPublicId})`;
      } else {
        // Current user is the seller transferring coins
        const recipientEntry = siblings.find((s) => BigInt(s.coinDelta ?? 0n) > 0n && s.wallet?.userId !== currentUserId);
        const recipientUser = recipientEntry?.wallet?.user;

        const recipientPublicId = recipientUser?.username || 'Recipient';
        const recipientDisplayName = recipientUser?.profile?.displayName || recipientPublicId;
        const recipientAvatar = recipientUser?.avatarUrl || null;

        targetUserId = recipientPublicId;
        counterparty = {
          id: recipientUser?.id || null,
          username: recipientPublicId,
          displayName: recipientDisplayName,
          avatarUrl: recipientAvatar,
        };
        description = `Agency Recharge to ${recipientDisplayName} (@${recipientPublicId})`;
      }
    } else if (rawItem.transactionType === 'RECHARGE') {
      category = 'RECHARGE';
      targetUserId = 'Online Gateway';
      counterparty = { id: null, username: 'Payment Gateway', displayName: 'Online Recharge', avatarUrl: null };
      description = 'Coin Package Online Recharge';
    } else if (rawItem.transactionType === 'GIFT_SENT') {
      category = 'GIFT_SENT';
      description = 'Room Gift Sent';
      targetUserId = 'Room Host';
    } else if (rawItem.transactionType === 'GIFT_RECEIVED') {
      category = 'GIFT_RECEIVED';
      description = 'Room Gift Received';
      targetUserId = 'Room Supporter';
    } else if (rawItem.transactionType === 'SWAP') {
      category = 'SWAP';
      description = 'Store Purchase / Coins Exchanged';
      targetUserId = 'ZeParty Store';
      counterparty = { id: null, username: 'Store', displayName: 'ZeParty Store', avatarUrl: null };
    } else if (rawItem.transactionType === 'ADMIN_ADJUSTMENT') {
      category = 'ADMIN_ADJUSTMENT';
      description = 'Administrative Balance Adjustment';
      targetUserId = 'ZeParty System';
      counterparty = { id: null, username: 'System', displayName: 'ZeParty System', avatarUrl: null };
    } else if (rawItem.transactionType === 'RESELLER_ALLOCATION') {
      category = 'RESELLER_ALLOCATION';
      description = 'Wholesale Reseller Quota Allocation';
      targetUserId = 'ZeParty System';
    } else if (rawItem.transactionType === 'WITHDRAWAL') {
      category = 'WITHDRAWAL';
      description = 'Diamond Host Payout Withdrawal';
      targetUserId = 'Bank / Payout Account';
    }

    return {
      ...item,
      id: rawItem.id,
      amount: signedAmount,
      absAmount,
      direction,
      type: category,
      transactionType: rawItem.transactionType,
      category,
      asset,
      currency: asset,
      title: description,
      description,
      targetUserId: targetUserId || 'ZeParty System',
      counterparty,
      balanceBefore: coinBalanceBefore,
      balanceAfter: coinBalanceAfter,
      balanceBeforeDetails: item.balanceBefore,
      balanceAfterDetails: item.balanceAfter,
      referenceId: rawItem.referenceId,
      status: 'Completed',
      createdAt: rawItem.createdAt instanceof Date ? rawItem.createdAt.toISOString() : String(rawItem.createdAt),
      date: rawItem.createdAt instanceof Date ? rawItem.createdAt.toISOString() : String(rawItem.createdAt),
    };
  });
}

/**
 * Retrieves paginated authoritative ledger history for a user's wallet.
 */
export async function getWalletLedger(
  userId,
  { page = 1, limit = 20, type = null, asset = null, tab = null, startDate = null, endDate = null } = {},
  db = prisma
) {
  const wallet = await walletRepository.findByUserId(userId, db);
  if (!wallet) {
    const error = new Error('Wallet not found');
    error.status = 404;
    error.code = 'WALLET_NOT_FOUND';
    throw error;
  }

  const rawItems = await ledgerRepository.findByWalletId(wallet.id, { page, limit, type, asset, tab, startDate, endDate }, db);
  const total = await ledgerRepository.countByWalletId(wallet.id, { type, asset, tab, startDate, endDate }, db);

  const enrichedItems = await enrichLedgerEntries(rawItems, userId, db);

  const pageNum = Math.max(1, parseInt(page, 10) || 1);
  const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));

  return {
    items: enrichedItems,
    pagination: {
      page: pageNum,
      limit: limitNum,
      total,
      totalPages: Math.ceil(total / limitNum) || 1,
      hasNextPage: pageNum < Math.ceil(total / limitNum),
      hasPrevPage: pageNum > 1,
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
 * Queries authoritative WalletLedger entries, isolating personal coin transactions
 * from wholesale reseller inventory movements.
 */
export async function getCoinRecords(
  userId,
  { tab = 'ALL', page = 1, limit = 20, type = null, startDate = null, endDate = null } = {},
  db = prisma
) {
  const activeTab = (tab || 'ALL').toUpperCase();
  const validTabs = ['ALL', 'INCOME', 'EXPENSES'];

  const ledgerResult = await getWalletLedger(
    userId,
    {
      page,
      limit,
      type,
      asset: 'COINS', // Strictly isolate personal coins: coinDelta !== 0n
      tab: activeTab === 'ALL' ? null : activeTab,
      startDate,
      endDate,
    },
    db
  );

  return {
    tabs: validTabs,
    activeTab,
    items: ledgerResult.items,
    pagination: ledgerResult.pagination,
  };
}

export async function reconcileWallet(userId, db = prisma) {
  const wallet = await walletRepository.findByUserId(userId, db);
  if (!wallet) {
    const error = new Error('Wallet not found');
    error.status = 404;
    error.code = 'WALLET_NOT_FOUND';
    throw error;
  }
  return await ledgerRepository.reconcileWalletBalances(wallet.id, db);
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
  reconcileWallet,
};
