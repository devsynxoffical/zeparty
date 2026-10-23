import prisma from '../config/database.js';

export function normalizeLedgerType(type) {
  const upper = String(type || 'ADMIN_ADJUSTMENT').toUpperCase();
  const valid = [
    'RECHARGE',
    'GIFT_SENT',
    'GIFT_RECEIVED',
    'WITHDRAWAL',
    'P2P_ESCROW_LOCK',
    'P2P_ESCROW_RELEASE',
    'ADMIN_ADJUSTMENT',
    'SWAP',
    'RESELLER_ALLOCATION',
    'REFUND',
    'CHARGEBACK_REVERSAL',
    'SETTLEMENT_PAYOUT',
    'COMMISSION_PAYOUT',
    'SETTLEMENT_ADJUSTMENT',
  ];
  if (valid.includes(upper)) return upper;
  if (upper.includes('PURCHASE') || upper.includes('STORE')) return 'SWAP';
  if (upper.includes('RECHARGE')) return 'RECHARGE';
  return 'ADMIN_ADJUSTMENT';
}

/**
 * Creates an immutable append-only ledger entry in WalletLedger.
 */
export async function createEntry(
  {
    walletId,
    transactionType,
    coinDelta = 0n,
    diamondDelta = 0n,
    usdDelta = 0.0,
    balanceBefore,
    balanceAfter,
    referenceId = null,
  },
  db = prisma
) {
  return await db.walletLedger.create({
    data: {
      walletId,
      transactionType: normalizeLedgerType(transactionType),
      coinDelta: BigInt(coinDelta),
      diamondDelta: BigInt(diamondDelta),
      usdDelta,
      balanceBefore,
      balanceAfter,
      referenceId,
    },
  });
}

/**
 * Retrieves paginated ledger history for a specific wallet.
 * Supports asset-level isolation (e.g. personal coins vs diamonds) and income/expense tab filtering,
 * with deterministic secondary sorting for stable pagination.
 */
export async function findByWalletId(
  walletId,
  { page = 1, limit = 20, type = null, asset = null, tab = null, startDate = null, endDate = null } = {},
  db = prisma
) {
  const pageNum = Math.max(1, parseInt(page, 10) || 1);
  const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
  const where = { walletId };
  if (type) where.transactionType = type;

  // Date range filtering
  if (startDate || endDate) {
    where.createdAt = {};
    if (startDate) where.createdAt.gte = new Date(startDate);
    if (endDate) where.createdAt.lte = new Date(endDate);
  }

  // Isolate personal coin transactions from wholesale inventory or diamond movements
  if (asset === 'COINS') {
    where.coinDelta = { not: 0n };
  } else if (asset === 'DIAMONDS') {
    where.diamondDelta = { not: 0n };
  }

  // Direction filtering for tabs
  const upperTab = (tab || '').toUpperCase();
  if (upperTab === 'INCOME') {
    if (asset === 'DIAMONDS') {
      where.diamondDelta = { gt: 0n };
    } else {
      where.coinDelta = { gt: 0n };
    }
  } else if (upperTab === 'EXPENSES' || upperTab === 'EXPENSE') {
    if (asset === 'DIAMONDS') {
      where.diamondDelta = { lt: 0n };
    } else {
      where.coinDelta = { lt: 0n };
    }
  }

  const skip = (pageNum - 1) * limitNum;

  return await db.walletLedger.findMany({
    where,
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    skip,
    take: limitNum,
  });
}

/**
 * Counts ledger records for a specific wallet matching query filters.
 */
export async function countByWalletId(
  walletId,
  { type = null, asset = null, tab = null, startDate = null, endDate = null } = {},
  db = prisma
) {
  const where = { walletId };
  if (type) where.transactionType = type;

  if (startDate || endDate) {
    where.createdAt = {};
    if (startDate) where.createdAt.gte = new Date(startDate);
    if (endDate) where.createdAt.lte = new Date(endDate);
  }

  if (asset === 'COINS') {
    where.coinDelta = { not: 0n };
  } else if (asset === 'DIAMONDS') {
    where.diamondDelta = { not: 0n };
  }

  const upperTab = (tab || '').toUpperCase();
  if (upperTab === 'INCOME') {
    if (asset === 'DIAMONDS') {
      where.diamondDelta = { gt: 0n };
    } else {
      where.coinDelta = { gt: 0n };
    }
  } else if (upperTab === 'EXPENSES' || upperTab === 'EXPENSE') {
    if (asset === 'DIAMONDS') {
      where.diamondDelta = { lt: 0n };
    } else {
      where.coinDelta = { lt: 0n };
    }
  }

  return await db.walletLedger.count({ where });
}

/**
 * Performs authoritative dual-assurance balance reconciliation between
 * stored Wallet balances and aggregated WalletLedger deltas.
 */
export async function reconcileWalletBalances(walletId, db = prisma) {
  const wallet = await db.wallet.findUnique({
    where: { id: walletId },
    select: {
      id: true,
      userId: true,
      coinBalance: true,
      diamondBalance: true,
      sellerBalanceCoins: true,
      escrowLockedCoins: true,
    },
  });

  if (!wallet) {
    throw new Error(`Wallet not found for ID: ${walletId}`);
  }

  const ledgers = await db.walletLedger.findMany({
    where: { walletId },
    select: {
      coinDelta: true,
      diamondDelta: true,
      balanceBefore: true,
      balanceAfter: true,
    },
    orderBy: { createdAt: 'desc' },
  });

  let sumCoinDelta = 0n;
  let sumDiamondDelta = 0n;
  let sumSellerDelta = 0n;

  for (const entry of ledgers) {
    sumCoinDelta += BigInt(entry.coinDelta || 0n);
    sumDiamondDelta += BigInt(entry.diamondDelta || 0n);
    if (entry.balanceBefore && entry.balanceAfter) {
      try {
        const before = typeof entry.balanceBefore === 'string' ? JSON.parse(entry.balanceBefore) : entry.balanceBefore;
        const after = typeof entry.balanceAfter === 'string' ? JSON.parse(entry.balanceAfter) : entry.balanceAfter;
        if (before?.sellerCoins !== undefined && after?.sellerCoins !== undefined) {
          sumSellerDelta += (BigInt(after.sellerCoins) - BigInt(before.sellerCoins));
        }
      } catch (e) {}
    }
  }

  const storedCoins = BigInt(wallet.coinBalance || 0n);
  const storedDiamonds = BigInt(wallet.diamondBalance || 0n);
  const storedSellerCoins = BigInt(wallet.sellerBalanceCoins || 0n);

  const diffCoins = storedCoins - sumCoinDelta;
  const diffDiamonds = storedDiamonds - sumDiamondDelta;
  const diffSellerCoins = storedSellerCoins - sumSellerDelta;

  const isReconciled = diffCoins === 0n && diffDiamonds === 0n;

  return {
    walletId: wallet.id,
    userId: wallet.userId,
    isReconciled,
    coins: {
      stored: storedCoins.toString(),
      derivedFromLedger: sumCoinDelta.toString(),
      discrepancy: diffCoins.toString(),
      isMatched: diffCoins === 0n,
    },
    diamonds: {
      stored: storedDiamonds.toString(),
      derivedFromLedger: sumDiamondDelta.toString(),
      discrepancy: diffDiamonds.toString(),
      isMatched: diffDiamonds === 0n,
    },
    sellerCoins: {
      stored: storedSellerCoins.toString(),
      derivedFromLedger: sumSellerDelta.toString(),
      discrepancy: diffSellerCoins.toString(),
      isMatched: diffSellerCoins === 0n,
    },
    ledgerEntryCount: ledgers.length,
    timestamp: new Date().toISOString(),
  };
}

/**
 * Retrieves master transaction ledger for administrative audits.
 */
export async function findAll(
  { page = 1, limit = 20, type, userId, referenceId, startDate, endDate },
  db = prisma
) {
  const where = {};
  if (type) where.transactionType = type;
  if (referenceId) where.referenceId = referenceId;
  if (userId) where.wallet = { userId };

  if (startDate || endDate) {
    where.createdAt = {};
    if (startDate) where.createdAt.gte = new Date(startDate);
    if (endDate) where.createdAt.lte = new Date(endDate);
  }

  const skip = (Math.max(1, page) - 1) * limit;

  return await db.walletLedger.findMany({
    where,
    include: {
      wallet: {
        include: {
          user: {
            select: {
              id: true,
              username: true,
              avatarUrl: true,
              userType: true,
              profile: {
                select: {
                  displayName: true,
                },
              },
            },
          },
        },
      },
    },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    skip,
    take: limit,
  });
}

/**
 * Counts total entries matching master ledger filters.
 */
export async function countAll(
  { type, userId, referenceId, startDate, endDate },
  db = prisma
) {
  const where = {};
  if (type) where.transactionType = type;
  if (referenceId) where.referenceId = referenceId;
  if (userId) where.wallet = { userId };

  if (startDate || endDate) {
    where.createdAt = {};
    if (startDate) where.createdAt.gte = new Date(startDate);
    if (endDate) where.createdAt.lte = new Date(endDate);
  }

  return await db.walletLedger.count({ where });
}

export default {
  createEntry,
  findByWalletId,
  countByWalletId,
  reconcileWalletBalances,
  normalizeLedgerType,
  findAll,
  countAll,
};
