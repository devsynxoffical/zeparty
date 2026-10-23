import prisma from '../config/database.js';
import walletRepository from '../repositories/wallet.repository.js';
import sellerRepository from '../repositories/seller.repository.js';
import ledgerRepository from '../repositories/ledger.repository.js';
import { generateReference } from '../utils/reference.util.js';

/**
 * NEW-07: Controlled, Safe, and Auditable Transaction Reconciliation Engine
 *
 * Implements strict financial invariants:
 * 1. Zero Fake Transactions: Never fabricates missing historical records.
 * 2. Idempotency & Duplicate Protection: Never applies an adjustment if credit or debit already exists.
 * 3. Atomic Database Transactions: All balance adjustments and ledger postings commit atomically.
 * 4. Traceable Audit Trail: All corrections generate unique REC-ADJ reference IDs linked to original tx.
 */

/**
 * Investigates a reported transaction across WalletLedger, AuditLog, and User Wallets.
 *
 * @param {string} transactionIdentifier - e.g. 'SEL-RCHG-...', 'tx_sel_...', or internal ID
 * @param {Object} [db=prisma]
 */
export async function investigateTransaction(transactionIdentifier, db = prisma) {
  if (!transactionIdentifier || typeof transactionIdentifier !== 'string') {
    throw new Error('Transaction identifier is required for investigation');
  }

  const cleanId = transactionIdentifier.trim();

  // 1. Search in WalletLedger
  const ledgerEntries = await db.walletLedger.findMany({
    where: {
      OR: [
        { referenceId: cleanId },
        { referenceId: { contains: cleanId } },
      ],
    },
    include: {
      wallet: {
        include: {
          user: {
            include: {
              profile: true,
              coinSeller: true,
            },
          },
        },
      },
    },
    orderBy: { createdAt: 'asc' },
  });

  // 2. Search in AuditLog
  const auditLogs = await db.auditLog.findMany({
    where: {
      OR: [
        { reason: { contains: cleanId } },
        { targetEntityId: cleanId },
      ],
    },
    orderBy: { createdAt: 'desc' },
  });

  // 3. Search for existing reconciliation adjustments linked to this transaction
  const priorAdjustments = await db.walletLedger.findMany({
    where: {
      referenceId: { startsWith: `REC-ADJ-${cleanId}` },
    },
  });

  const hasLedger = ledgerEntries.length > 0;
  const sellerDebits = ledgerEntries.filter((l) => {
    if (l.coinDelta < 0n) return true;
    if (l.balanceBefore?.sellerCoins && l.balanceAfter?.sellerCoins) {
      return BigInt(l.balanceBefore.sellerCoins) > BigInt(l.balanceAfter.sellerCoins);
    }
    return false;
  });
  const recipientCredits = ledgerEntries.filter((l) => l.coinDelta > 0n);

  let status = 'NOT_FOUND_IN_BACKEND';
  if (hasLedger) {
    if (sellerDebits.length > 0 && recipientCredits.length > 0) {
      status = 'COMMITTED_BALANCED';
    } else if (sellerDebits.length > 0 && recipientCredits.length === 0) {
      status = 'PARTIALLY_COMMITTED_MISSING_RECIPIENT_CREDIT';
    } else if (sellerDebits.length === 0 && recipientCredits.length > 0) {
      status = 'PARTIALLY_COMMITTED_MISSING_SELLER_DEBIT';
    } else {
      status = 'LEDGER_PRESENT_ANOMALOUS';
    }
  } else if (auditLogs.length > 0) {
    status = 'AUDITED_BUT_MISSING_LEDGER';
  }

  return {
    transactionIdentifier: cleanId,
    status,
    hasAuthoritativeLedger: hasLedger,
    ledgerCount: ledgerEntries.length,
    sellerDebitFound: sellerDebits.length > 0,
    recipientCreditFound: recipientCredits.length > 0,
    sellerDebits: sellerDebits.map((d) => {
      let delta = d.coinDelta.toString();
      if (d.balanceBefore?.sellerCoins && d.balanceAfter?.sellerCoins) {
        delta = (BigInt(d.balanceAfter.sellerCoins) - BigInt(d.balanceBefore.sellerCoins)).toString();
      }
      return {
        id: d.id,
        walletId: d.walletId,
        userId: d.wallet.userId,
        username: d.wallet.user?.username,
        sellerDelta: delta,
        createdAt: d.createdAt.toISOString(),
      };
    }),
    recipientCredits: recipientCredits.map((c) => ({
      id: c.id,
      walletId: c.walletId,
      userId: c.wallet.userId,
      username: c.wallet.user?.username,
      coinDelta: c.coinDelta.toString(),
      createdAt: c.createdAt.toISOString(),
    })),
    priorAdjustmentsCount: priorAdjustments.length,
    auditLogCount: auditLogs.length,
    auditLogs: auditLogs.map((a) => ({
      id: a.id,
      action: a.action,
      reason: a.reason,
      createdAt: a.createdAt.toISOString(),
    })),
    timestamp: new Date().toISOString(),
  };
}

/**
 * Applies a verified missing balance correction according to the strict 10-step protocol.
 *
 * @param {Object} params
 * @param {string} params.originalReferenceId - Authoritative tx ID being repaired
 * @param {string} params.recipientUserId - The recipient account to receive the missing credit
 * @param {number|bigint|string} params.amountCoins - Exact coin amount
 * @param {string} [params.sellerUserId] - The seller account whose inventory was involved
 * @param {string} params.adminId - Authenticated administrator authorizing the correction
 * @param {string} params.reason - Detailed justification and evidence reference
 * @param {string} [params.ipAddress] - IP address of the administrator
 * @param {Object} [db=prisma]
 */
export async function applyVerifiedReconciliationAdjustment({
  originalReferenceId,
  recipientUserId,
  amountCoins,
  sellerUserId = null,
  adminId,
  reason,
  ipAddress = '127.0.0.1',
}, db = prisma) {
  if (!originalReferenceId || !recipientUserId || !amountCoins || !adminId || !reason) {
    const error = new Error('Missing required reconciliation parameters');
    error.statusCode = 400;
    error.code = 'INVALID_RECONCILIATION_PARAMS';
    throw error;
  }

  const cleanRef = String(originalReferenceId).trim();
  const coinsBigInt = BigInt(amountCoins);

  if (coinsBigInt <= 0n) {
    const error = new Error('Reconciliation adjustment amount must be positive');
    error.statusCode = 400;
    error.code = 'INVALID_AMOUNT';
    throw error;
  }

  // 1. Check for duplicate prior reconciliation adjustment
  const existingAdjustment = await db.walletLedger.findFirst({
    where: {
      referenceId: { startsWith: `REC-ADJ-${cleanRef}` },
    },
  });

  if (existingAdjustment) {
    const error = new Error(`Reconciliation adjustment already applied for transaction ${cleanRef} (Reference: ${existingAdjustment.referenceId})`);
    error.statusCode = 409;
    error.code = 'RECONCILIATION_ALREADY_APPLIED';
    error.existingReferenceId = existingAdjustment.referenceId;
    throw error;
  }

  // 2. Verify recipient exists and resolve wallet
  const recipient = await db.user.findUnique({
    where: { id: recipientUserId },
    include: { wallet: true, profile: true },
  });

  if (!recipient) {
    const error = new Error(`Recipient user not found: ${recipientUserId}`);
    error.statusCode = 404;
    error.code = 'RECIPIENT_NOT_FOUND';
    throw error;
  }

  let recipientWallet = recipient.wallet;
  if (!recipientWallet) {
    recipientWallet = await walletRepository.createWallet(recipient.id, db);
  }

  // 3. Check if recipient was ALREADY credited under this reference in WalletLedger
  const alreadyCredited = await db.walletLedger.findFirst({
    where: {
      walletId: recipientWallet.id,
      referenceId: cleanRef,
      coinDelta: { gt: 0n },
    },
  });

  if (alreadyCredited) {
    const error = new Error(`Recipient is already credited with ${alreadyCredited.coinDelta} coins for transaction ${cleanRef}. Duplicate credit prohibited.`);
    error.statusCode = 409;
    error.code = 'CREDIT_ALREADY_EXISTS';
    throw error;
  }

  // 4. Generate unique reconciliation reference
  const recRefId = `REC-ADJ-${cleanRef}-${Date.now()}`;

  // 5. Execute atomic database transaction
  const result = await db.$transaction(async (tx) => {
    // Row lock recipient wallet
    const lockedWallet = await walletRepository.findWithLock(recipientWallet.id, tx);
    const beforeCoins = BigInt(lockedWallet.coinBalance || 0n);
    const afterCoins = beforeCoins + coinsBigInt;

    // Update wallet balance
    await tx.wallet.update({
      where: { id: recipientWallet.id },
      data: { coinBalance: afterCoins },
    });

    // Create immutable append-only ledger entry
    const ledgerEntry = await tx.walletLedger.create({
      data: {
        walletId: recipientWallet.id,
        transactionType: 'ADMIN_ADJUSTMENT',
        coinDelta: coinsBigInt,
        diamondDelta: 0n,
        usdDelta: 0.0,
        balanceBefore: {
          coins: beforeCoins.toString(),
          originalReferenceId: cleanRef,
          reason,
        },
        balanceAfter: { coins: afterCoins.toString() },
        referenceId: recRefId,
      },
    });

    // Create persistent audit log
    await tx.auditLog.create({
      data: {
        adminId,
        adminName: 'Authorized Reconciliation Service',
        action: 'RECONCILIATION_CORRECTION_APPLIED',
        targetEntity: 'WalletLedger',
        targetEntityId: ledgerEntry.id,
        beforeStateJson: { coinBalance: beforeCoins.toString() },
        afterStateJson: {
          coinBalance: afterCoins.toString(),
          reconciliationReference: recRefId,
          originalTransactionId: cleanRef,
          creditedCoins: coinsBigInt.toString(),
        },
        reason: `Reconciliation repair: ${reason} (Original: ${cleanRef})`,
        ipAddress,
      },
    });

    return {
      recipientUserId: recipient.id,
      recipientPublicId: recipient.username,
      recipientDisplayName: recipient.profile?.displayName || recipient.username,
      beforeCoins: beforeCoins.toString(),
      afterCoins: afterCoins.toString(),
      creditedCoins: coinsBigInt.toString(),
      reconciliationReferenceId: recRefId,
      originalReferenceId: cleanRef,
      ledgerEntryId: ledgerEntry.id,
    };
  });

  return {
    success: true,
    message: 'Reconciliation adjustment successfully committed to authoritative ledger',
    data: result,
  };
}

export default {
  investigateTransaction,
  applyVerifiedReconciliationAdjustment,
};
