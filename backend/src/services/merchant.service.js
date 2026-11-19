import crypto from 'crypto';
import prisma from '../config/database.js';
import merchantRepository from '../repositories/merchant.repository.js';
import walletRepository from '../repositories/wallet.repository.js';
import notificationService from './notification.service.js';
import { emitToUser } from '../socket/socket.emitter.js';
import { generate7DigitUserId } from '../utils/idGenerator.util.js';
import { generateReference } from '../utils/reference.util.js';
import { normalizeCountry } from '../utils/country.util.js';
import { applySvipPointsForRecharge } from './recharge.service.js';
import { invalidateSellerDirectoryCache } from './seller.service.js';

function hashSecret(secret) {
  return crypto.createHash('sha256').update(secret).digest('hex');
}

async function logAudit({ adminId, adminName, action, targetEntity, targetEntityId, beforeStateJson, afterStateJson, reason, ipAddress }, db = prisma) {
  try {
    let validAdminId = adminId;
    if (validAdminId && validAdminId !== 'SYSTEM' && validAdminId !== 'ADMIN') {
      const exists = await db.admin?.findUnique?.({ where: { id: validAdminId }, select: { id: true } });
      if (!exists) {
        const fallback = await db.admin?.findFirst?.({ select: { id: true, name: true } });
        validAdminId = fallback ? fallback.id : null;
        if (fallback && !adminName) adminName = fallback.name;
      }
    } else {
      const fallback = await db.admin?.findFirst?.({ select: { id: true, name: true } });
      validAdminId = fallback ? fallback.id : null;
      if (fallback && !adminName) adminName = fallback.name;
    }

    if (!validAdminId || !db.auditLog?.create) return;

    await db.auditLog.create({
      data: {
        adminId: validAdminId,
        adminName: adminName || 'System',
        action,
        targetEntity,
        targetEntityId: targetEntityId || null,
        beforeStateJson: beforeStateJson ? JSON.parse(JSON.stringify(beforeStateJson, (k, v) => typeof v === 'bigint' ? v.toString() : v)) : null,
        afterStateJson: afterStateJson ? JSON.parse(JSON.stringify(afterStateJson, (k, v) => typeof v === 'bigint' ? v.toString() : v)) : null,
        reason: reason || null,
        ipAddress: ipAddress || '127.0.0.1',
      },
    });
  } catch (err) {
    console.error('Failed to write audit log in merchant.service:', err);
  }
}

export function sanitizeMerchant(merchant) {
  if (!merchant) return null;
  const { apiKeyHash, apiSecretHash, ...rest } = merchant;
  return {
    ...rest,
    monthlyQuotaCoins: merchant.monthlyQuotaCoins ? merchant.monthlyQuotaCoins.toString() : '0',
    totalSpentUSD: merchant.totalSpentUSD ? merchant.totalSpentUSD.toString() : '0.00',
    user: merchant.user ? {
      ...merchant.user,
      wallet: merchant.user.wallet ? {
        ...merchant.user.wallet,
        coinBalance: merchant.user.wallet.coinBalance?.toString() || '0',
        sellerBalanceCoins: merchant.user.wallet.sellerBalanceCoins?.toString() || '0',
        diamondBalance: merchant.user.wallet.diamondBalance?.toString() || '0',
        escrowLockedCoins: merchant.user.wallet.escrowLockedCoins?.toString() || '0',
        totalRechargedUSD: merchant.user.wallet.totalRechargedUSD?.toString() || '0.00',
        totalWithdrawnUSD: merchant.user.wallet.totalWithdrawnUSD?.toString() || '0.00',
      } : null,
    } : null,
  };
}

export async function createMerchant(data, { adminId, adminName, ipAddress } = {}, db = prisma) {
  let targetUser = null;
  const userIdentifier = data.userId || data.userRef || data.username;
  if (userIdentifier) {
    targetUser = await db.user.findUnique({
      where: { id: userIdentifier },
      include: { profile: true, wallet: true },
    });
    if (!targetUser) {
      targetUser = await db.user.findUnique({
        where: { username: userIdentifier.replace('@', '').trim() },
        include: { profile: true, wallet: true },
      });
    }
  }

  // Pre-creation verification: User must not already be linked to an existing merchant
  if (targetUser) {
    const existing = await merchantRepository.findMerchantByUserId(targetUser.id, db);
    if (existing) {
      const error = new Error(
        `User ${targetUser.id} (${targetUser.profile?.displayName || targetUser.username}) is already assigned to Merchant "${existing.companyName}". A user can only be linked to one merchant.`
      );
      error.statusCode = 409;
      error.code = 'MERCHANT_ALREADY_EXISTS';
      error.existingMerchant = sanitizeMerchant(existing);
      throw error;
    }
  }

  const initialCoins = data.monthlyQuotaCoins ? BigInt(data.monthlyQuotaCoins) : (data.initialAllocation ? BigInt(data.initialAllocation) : 25200000n);

  // Generate secure API credentials server-side
  const rawApiKey = `zp_live_${crypto.randomBytes(16).toString('hex')}`;
  const rawApiSecret = `zp_sec_${crypto.randomBytes(32).toString('hex')}`;
  const apiKeyHash = hashSecret(rawApiKey);
  const apiSecretHash = hashSecret(rawApiSecret);

  // Pre-generate 7-digit ID outside transaction if user is new to avoid interactive tx timeout
  const generatedId = !targetUser ? await generate7DigitUserId(db) : null;

  const merchant = await db.$transaction(async (tx) => {
    let finalUser = targetUser;
    if (!finalUser) {
      const rawUsername = (data.username || userIdentifier || `merchant_${Date.now()}`).replace('@', '').trim();
      const cleanPhone = `+1888${Math.floor(1000000 + Math.random() * 9000000)}`;
      finalUser = await tx.user.create({
        data: {
          id: generatedId,
          username: rawUsername,
          phone: cleanPhone,
          email: data.email || `${rawUsername}@zeparty.merchant`,
          userType: 'MERCHANT',
          status: 'ACTIVE',
          countryCode: data.countryCode || data.country || 'US',
          avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
          profile: {
            create: {
              displayName: data.companyName || data.merchantName || rawUsername,
            },
          },
          wallet: {
            create: {
              coinBalance: 0n,
              diamondBalance: 0n,
              sellerBalanceCoins: initialCoins,
            },
          },
        },
        include: { profile: true, wallet: true },
      });
    } else {
      // Ensure wallet exists for existing user without corrupting balances
      if (!finalUser.wallet) {
        await tx.wallet.create({
          data: {
            userId: finalUser.id,
            coinBalance: 0n,
            diamondBalance: 0n,
            sellerBalanceCoins: initialCoins,
          },
        });
      } else {
        await tx.wallet.update({
          where: { userId: finalUser.id },
          data: { sellerBalanceCoins: initialCoins },
        });
      }

      await tx.user.update({
        where: { id: finalUser.id },
        data: { userType: 'MERCHANT' },
      });
    }

    const newMerchant = await merchantRepository.createMerchant({
      userId: finalUser.id,
      companyName: data.companyName || data.merchantName || finalUser.username,
      apiKeyHash,
      apiSecretHash,
      monthlyQuotaCoins: initialCoins,
      status: data.status ? data.status.toUpperCase() : 'ACTIVE',
    }, tx);

    return newMerchant;
  }, { timeout: 20000, maxWait: 10000 });

  await logAudit({
    adminId,
    adminName,
    action: 'MERCHANT_CREATED',
    targetEntity: 'Merchant',
    targetEntityId: merchant.id,
    afterStateJson: {
      userId: merchant.userId,
      companyName: merchant.companyName,
      monthlyQuotaCoins: merchant.monthlyQuotaCoins.toString(),
    },
    ipAddress,
  }, db);

  return {
    ...sanitizeMerchant(merchant),
    rawCredentials: {
      apiKey: rawApiKey,
      apiSecret: rawApiSecret,
      warning: 'Store these API credentials securely. The secret cannot be retrieved again.',
    },
  };
}

export async function updateMerchant(id, updates, { adminId, adminName, ipAddress } = {}, db = prisma) {
  const merchant = await merchantRepository.findMerchantById(id, db);
  if (!merchant) {
    const error = new Error('Merchant not found');
    error.statusCode = 404;
    error.code = 'MERCHANT_NOT_FOUND';
    throw error;
  }

  const merchantUpdates = {};
  if (updates.companyName || updates.merchantName) {
    merchantUpdates.companyName = updates.companyName || updates.merchantName;
  }
  if (updates.status) {
    merchantUpdates.status = updates.status.toUpperCase();
  }
  if (updates.monthlyQuotaCoins !== undefined || updates.coinAllocation !== undefined) {
    merchantUpdates.monthlyQuotaCoins = BigInt(updates.monthlyQuotaCoins !== undefined ? updates.monthlyQuotaCoins : updates.coinAllocation);
  }
  if (updates.totalSpentUSD !== undefined) {
    merchantUpdates.totalSpentUSD = updates.totalSpentUSD;
  }

  const updated = await db.$transaction(async (tx) => {
    const res = await merchantRepository.updateMerchant(id, merchantUpdates, tx);

    // Sync to user & wallet
    const userUpdates = {};
    if (updates.email) userUpdates.email = updates.email;
    if (updates.country || updates.countryCode) userUpdates.countryCode = updates.country || updates.countryCode;

    if (Object.keys(userUpdates).length > 0) {
      await tx.user.update({
        where: { id: merchant.userId },
        data: userUpdates,
      }).catch(() => {});
    }

    if (updates.contactPerson || updates.merchantName || updates.companyName) {
      await tx.userProfile.upsert({
        where: { userId: merchant.userId },
        update: {
          displayName: updates.contactPerson || updates.merchantName || updates.companyName,
        },
        create: {
          userId: merchant.userId,
          displayName: updates.contactPerson || updates.merchantName || updates.companyName,
        },
      }).catch(() => {});
    }

    if (merchantUpdates.monthlyQuotaCoins !== undefined) {
      await tx.wallet.upsert({
        where: { userId: merchant.userId },
        update: {
          sellerBalanceCoins: merchantUpdates.monthlyQuotaCoins,
        },
        create: {
          userId: merchant.userId,
          sellerBalanceCoins: merchantUpdates.monthlyQuotaCoins,
        },
      }).catch(() => {});
    }

    return await merchantRepository.findMerchantById(id, tx);
  });

  await logAudit({
    adminId,
    adminName,
    action: 'MERCHANT_UPDATED',
    targetEntity: 'Merchant',
    targetEntityId: id,
    beforeStateJson: {
      companyName: merchant.companyName,
      status: merchant.status,
      monthlyQuotaCoins: merchant.monthlyQuotaCoins.toString(),
    },
    afterStateJson: updates,
    ipAddress,
  }, db);

  return sanitizeMerchant(updated);
}

export async function adjustMerchantBalance(id, { amount, type = 'CREDIT', reason }, { adminId, adminName, ipAddress } = {}, db = prisma) {
  const merchant = await merchantRepository.findMerchantById(id, db);
  if (!merchant) {
    const error = new Error('Merchant not found');
    error.statusCode = 404;
    error.code = 'MERCHANT_NOT_FOUND';
    throw error;
  }

  const amt = BigInt(amount);
  const currentQuota = merchant.monthlyQuotaCoins || 0n;
  let newQuota = currentQuota;

  if (type === 'CREDIT') {
    newQuota = currentQuota + amt;
  } else if (type === 'DEBIT') {
    newQuota = currentQuota > amt ? currentQuota - amt : 0n;
  } else if (type === 'SET') {
    newQuota = amt;
  }

  const result = await db.$transaction(async (tx) => {
    // 1. Update merchant monthlyQuotaCoins
    const updatedMerchant = await tx.merchant.update({
      where: { id },
      data: { monthlyQuotaCoins: newQuota },
    });

    // 2. Upsert wallet and update sellerBalanceCoins
    let wallet = await tx.wallet.findUnique({ where: { userId: merchant.userId } });
    if (!wallet) {
      wallet = await tx.wallet.create({
        data: {
          userId: merchant.userId,
          coinBalance: 0n,
          diamondBalance: 0n,
          sellerBalanceCoins: newQuota,
        },
      });
    } else {
      const currentSellerCoins = wallet.sellerBalanceCoins || 0n;
      let newSellerCoins = currentSellerCoins;
      if (type === 'CREDIT') {
        newSellerCoins = currentSellerCoins + amt;
      } else if (type === 'DEBIT') {
        newSellerCoins = currentSellerCoins > amt ? currentSellerCoins - amt : 0n;
      } else if (type === 'SET') {
        newSellerCoins = amt;
      }

      // Record WalletLedger entry
      const coinDelta = type === 'DEBIT' ? -amt : (type === 'CREDIT' ? amt : (newSellerCoins - currentSellerCoins));
      await tx.walletLedger.create({
        data: {
          walletId: wallet.id,
          transactionType: 'ADMIN_ADJUSTMENT',
          coinDelta: coinDelta,
          balanceBefore: {
            coins: wallet.coinBalance.toString(),
            diamonds: wallet.diamondBalance.toString(),
            sellerCoins: currentSellerCoins.toString(),
          },
          balanceAfter: {
            coins: wallet.coinBalance.toString(),
            diamonds: wallet.diamondBalance.toString(),
            sellerCoins: newSellerCoins.toString(),
          },
          referenceId: `MERCHANT_ADJUST_${id}_${Date.now()}`,
        },
      });

      wallet = await tx.wallet.update({
        where: { id: wallet.id },
        data: { sellerBalanceCoins: newSellerCoins },
      });
    }

    return await merchantRepository.findMerchantById(id, tx);
  });

  await logAudit({
    adminId,
    adminName,
    action: 'MERCHANT_BALANCE_ADJUSTED',
    targetEntity: 'Merchant',
    targetEntityId: id,
    beforeStateJson: {
      monthlyQuotaCoins: currentQuota.toString(),
    },
    afterStateJson: {
      type,
      amount: amt.toString(),
      newMonthlyQuotaCoins: newQuota.toString(),
      reason: reason || 'Manual merchant balance adjustment',
    },
    reason: reason || `Merchant balance adjusted: ${type} ${amt.toString()} coins`,
    ipAddress,
  }, db);

  return sanitizeMerchant(result);
}

export async function deleteMerchant(id, { adminId, adminName, ipAddress, reason } = {}, db = prisma) {
  const merchant = await merchantRepository.findMerchantById(id, db);
  if (!merchant) {
    const error = new Error('Merchant not found');
    error.statusCode = 404;
    error.code = 'MERCHANT_NOT_FOUND';
    throw error;
  }

  await merchantRepository.deleteMerchant(id, db);

  await logAudit({
    adminId,
    adminName,
    action: 'MERCHANT_DELETED',
    targetEntity: 'Merchant',
    targetEntityId: id,
    beforeStateJson: {
      companyName: merchant.companyName,
      userId: merchant.userId,
      monthlyQuotaCoins: merchant.monthlyQuotaCoins.toString(),
    },
    reason: reason || 'Merchant removed by admin',
    ipAddress,
  }, db);

  return { success: true, message: 'Merchant removed successfully.' };
}

export async function getMerchantDetails(id, db = prisma) {
  const merchant = await merchantRepository.findMerchantById(id, db);
  if (!merchant) {
    const error = new Error('Merchant not found');
    error.statusCode = 404;
    error.code = 'MERCHANT_NOT_FOUND';
    throw error;
  }
  return sanitizeMerchant(merchant);
}

export async function getMyMerchantCenter(userId, db = prisma) {
  const merchant = await db.merchant.findUnique({
    where: { userId },
    include: {
      user: {
        select: {
          id: true,
          username: true,
          countryCode: true,
          status: true,
          profile: true,
          wallet: true,
        },
      },
    },
  });

  if (!merchant) {
    const error = new Error('Merchant account not found for this user');
    error.statusCode = 404;
    error.code = 'MERCHANT_NOT_FOUND';
    throw error;
  }

  return sanitizeMerchant(merchant);
}

export async function getMerchantDashboard(userId, db = prisma) {
  const merchant = await getMyMerchantCenter(userId, db);

  const walletId = merchant.user?.wallet?.id;
  let recentTransactions = [];
  let totalRechargeCount = 0;

  if (walletId && db.walletLedger) {
    const [txs, count] = await Promise.all([
      db.walletLedger.findMany({
        where: { walletId },
        orderBy: { createdAt: 'desc' },
        take: 10,
      }),
      db.walletLedger.count({
        where: { walletId },
      }),
    ]);
    recentTransactions = txs.map((tx) => ({
      ...tx,
      coinDelta: tx.coinDelta ? tx.coinDelta.toString() : '0',
      diamondDelta: tx.diamondDelta ? tx.diamondDelta.toString() : '0',
    }));
    totalRechargeCount = count;
  }

  return {
    merchant,
    quota: merchant.monthlyQuotaCoins,
    totalSpentUSD: merchant.totalSpentUSD,
    totalRechargeCount,
    recentTransactions,
  };
}

export async function getMerchantLedger(userId, { page = 1, limit = 20 } = {}, db = prisma) {
  const user = await db.user.findUnique({
    where: { id: userId },
    include: { wallet: true },
  });

  if (!user || !user.wallet) {
    return {
      transactions: [],
      pagination: { page: Number(page), limit: Number(limit), total: 0, totalPages: 0 },
    };
  }

  const p = Math.max(1, parseInt(page, 10) || 1);
  const l = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
  const skip = (p - 1) * l;

  const [items, total] = await Promise.all([
    db.walletLedger.findMany({
      where: { walletId: user.wallet.id },
      orderBy: { createdAt: 'desc' },
      skip,
      take: l,
    }),
    db.walletLedger.count({
      where: { walletId: user.wallet.id },
    }),
  ]);

  const transactions = items.map((t) => ({
    ...t,
    coinDelta: t.coinDelta ? t.coinDelta.toString() : '0',
    diamondDelta: t.diamondDelta ? t.diamondDelta.toString() : '0',
  }));

  return {
    transactions,
    pagination: {
      page: p,
      limit: l,
      total,
      totalPages: Math.ceil(total / l),
    },
  };
}

export async function executeMerchantRecharge(
  merchantUserId,
  { recipientId, recipientType, amountCoins, notes, idempotencyKey },
  { ipAddress } = {},
  db = prisma
) {
  const merchant = await db.merchant.findUnique({
    where: { userId: merchantUserId },
    include: {
      user: {
        include: { wallet: true, profile: true },
      },
    },
  });

  if (!merchant || merchant.status !== 'ACTIVE') {
    const error = new Error('Authorized active merchant account required');
    error.statusCode = 403;
    error.code = 'MERCHANT_INACTIVE';
    throw error;
  }

  const cleanRecipient = String(recipientId || '').trim().replace('@', '');
  if (!cleanRecipient) {
    const error = new Error('Recipient identifier is required');
    error.statusCode = 400;
    error.code = 'INVALID_RECIPIENT';
    throw error;
  }

  const recipient = await db.user.findFirst({
    where: {
      OR: [
        { id: cleanRecipient },
        { username: { equals: cleanRecipient, mode: 'insensitive' } },
        { phone: cleanRecipient },
      ],
    },
    include: { wallet: true, profile: true, coinSeller: true },
  });

  if (!recipient || recipient.status === 'DELETED' || recipient.status === 'BANNED') {
    const error = new Error('Recipient not found or unavailable');
    error.statusCode = 404;
    error.code = 'RECIPIENT_NOT_FOUND';
    throw error;
  }

  let amt;
  try {
    amt = BigInt(amountCoins || 0);
  } catch {
    amt = 0n;
  }
  if (amt <= 0n) {
    const error = new Error('Recharge amount must be a positive integer');
    error.statusCode = 400;
    error.code = 'INVALID_AMOUNT';
    throw error;
  }

  // Determine explicit target wallet mode:
  // - If recipientType is explicitly supplied, honor it strictly.
  // - Otherwise infer from notes ('coin seller' vs 'user recharge'), defaulting to USER personal wallet.
  const rawType = String(recipientType || '').trim().toUpperCase();
  const lowerNotes = String(notes || '').toLowerCase();
  const isCoinSellerTarget = rawType
    ? rawType.includes('SELLER')
    : (lowerNotes.includes('coin seller') && !lowerNotes.includes('user recharge'));

  const isSelfRecharge = recipient.id === merchant.userId;

  // Regional / country eligibility check for external transfers (self-recharge is always permitted)
  if (!isSelfRecharge) {
    const merchantCountry = normalizeCountry(merchant.user?.countryCode || merchant.user?.region);
    const recipientCountry = normalizeCountry(recipient.countryCode || recipient.region);
    if (merchantCountry && recipientCountry && merchantCountry.code !== recipientCountry.code) {
      const error = new Error(
        `Cross-country merchant transfers are prohibited. Merchant is in ${merchantCountry.name}, recipient is in ${recipientCountry.name}.`
      );
      error.statusCode = 403;
      error.code = 'CROSS_COUNTRY_RECHARGE_PROHIBITED';
      throw error;
    }
  }

  // If targeting a Coin Seller business wallet, verify active authoritative CoinSeller record
  if (isCoinSellerTarget) {
    const hasActiveSellerRecord =
      recipient.coinSeller && recipient.coinSeller.sellerStatus === 'ACTIVE';
    if (!hasActiveSellerRecord) {
      const error = new Error(
        `User '${recipient.username}' (${recipient.id}) is not an authorized Coin Seller account.`
      );
      error.statusCode = 400;
      error.code = 'NOT_A_COIN_SELLER';
      throw error;
    }
  }

  const cleanIdempotencyKey = idempotencyKey ? String(idempotencyKey).trim() : null;
  const txRefId = cleanIdempotencyKey || generateReference('MRC-RCHG');
  const transferTimestamp = new Date();
  const targetWalletLabel = isCoinSellerTarget
    ? 'Coin Seller Business Wallet'
    : 'Personal Coin Wallet';

  const result = await db.$transaction(async (tx) => {
    // 0. Idempotency check if caller supplied explicit idempotency key
    if (cleanIdempotencyKey) {
      const existing = await tx.walletLedger.findFirst({
        where: { referenceId: txRefId },
      });
      if (existing) {
        const latestMerchant = await tx.merchant.findUnique({ where: { id: merchant.id } });
        const latestWallet = await tx.wallet.findUnique({ where: { userId: recipient.id } });
        return {
          merchantId: merchant.id,
          companyName: merchant.companyName,
          referenceId: txRefId,
          transactionId: txRefId,
          remainingQuota: (latestMerchant?.monthlyQuotaCoins ?? merchant.monthlyQuotaCoins ?? 0n).toString(),
          recipientId: recipient.id,
          recipientUsername: recipient.username,
          amountRecharged: amt.toString(),
          recipientNewBalance: isCoinSellerTarget
            ? (latestWallet?.sellerBalanceCoins ?? 0n).toString()
            : (latestWallet?.coinBalance ?? 0n).toString(),
          targetWallet: targetWalletLabel,
          status: 'Successful',
          alreadyProcessed: true,
          notification: null,
        };
      }
    }

    // 1. Lock Merchant row inside transaction to prevent concurrent overspending
    let lockedQuota = BigInt(merchant.monthlyQuotaCoins ?? 0n);
    let lockedStatus = merchant.status;
    if (typeof tx.$queryRaw === 'function') {
      const lockedRows = await tx.$queryRaw`
        SELECT id, "monthlyQuotaCoins", status
        FROM "Merchant"
        WHERE id = ${merchant.id}
        FOR UPDATE
      `;
      if (Array.isArray(lockedRows) && lockedRows.length > 0) {
        lockedQuota = BigInt(lockedRows[0].monthlyQuotaCoins ?? 0n);
        lockedStatus = lockedRows[0].status;
      }
    }

    if (lockedStatus !== 'ACTIVE') {
      const error = new Error('Authorized active merchant account required');
      error.statusCode = 403;
      error.code = 'MERCHANT_INACTIVE';
      throw error;
    }

    if (lockedQuota < amt) {
      const error = new Error(
        `Insufficient merchant coin allocation. Available: ${lockedQuota.toString()}, Requested: ${amt.toString()}`
      );
      error.statusCode = 400;
      error.code = 'INSUFFICIENT_MERCHANT_QUOTA';
      throw error;
    }

    const updatedMerchant = await tx.merchant.update({
      where: { id: merchant.id },
      data: {
        monthlyQuotaCoins: { decrement: amt },
      },
    });
    const remainingQuota = BigInt(updatedMerchant.monthlyQuotaCoins ?? (lockedQuota - amt));

    const merchantReason = `Merchant Recharge to @${recipient.username} (${recipient.id}): ${notes || 'Recharge transfer'}`;
    const recipientReason = `Merchant Recharge from ${merchant.companyName}: ${notes || 'Recharge transfer'}`;

    let finalRecipientBalance = 0n;

    if (isSelfRecharge && !isCoinSellerTarget) {
      // Self-recharge: single locked wallet row — debit sellerBalanceCoins, credit coinBalance atomically
      let selfWallet = merchant.user?.wallet
        ? await walletRepository.findWithLock(merchant.user.wallet.id, tx)
        : await tx.wallet.findUnique({ where: { userId: merchant.userId } });

      if (!selfWallet) {
        selfWallet = await tx.wallet.create({
          data: {
            userId: merchant.userId,
            coinBalance: amt,
            diamondBalance: 0n,
            sellerBalanceCoins: remainingQuota,
          },
        });
        finalRecipientBalance = amt;

        await tx.walletLedger.create({
          data: {
            walletId: selfWallet.id,
            transactionType: 'TRANSFER_IN',
            coinDelta: amt,
            balanceBefore: {
              coins: '0',
              sellerCoins: lockedQuota.toString(),
            },
            balanceAfter: {
              coins: amt.toString(),
              sellerCoins: remainingQuota.toString(),
              reason: recipientReason,
            },
            referenceId: txRefId,
          },
        });
      } else {
        const coinsBefore = BigInt(selfWallet.coinBalance ?? 0n);
        const sellerBefore = BigInt(selfWallet.sellerBalanceCoins ?? 0n);
        const sellerAfter = sellerBefore >= amt ? sellerBefore - amt : remainingQuota;
        const coinsAfter = coinsBefore + amt;
        finalRecipientBalance = coinsAfter;

        await tx.wallet.update({
          where: { id: selfWallet.id },
          data: {
            sellerBalanceCoins: sellerAfter,
            coinBalance: coinsAfter,
          },
        });

        await tx.walletLedger.create({
          data: {
            walletId: selfWallet.id,
            transactionType: 'TRANSFER_OUT',
            coinDelta: -amt,
            balanceBefore: {
              coins: coinsBefore.toString(),
              sellerCoins: sellerBefore.toString(),
            },
            balanceAfter: {
              coins: coinsBefore.toString(),
              sellerCoins: sellerAfter.toString(),
              reason: merchantReason,
            },
            referenceId: txRefId,
          },
        });

        await tx.walletLedger.create({
          data: {
            walletId: selfWallet.id,
            transactionType: 'TRANSFER_IN',
            coinDelta: amt,
            balanceBefore: {
              coins: coinsBefore.toString(),
              sellerCoins: sellerAfter.toString(),
            },
            balanceAfter: {
              coins: coinsAfter.toString(),
              sellerCoins: sellerAfter.toString(),
              reason: recipientReason,
            },
            referenceId: txRefId,
          },
        });
      }
    } else {
      // External recharge (or Coin Seller recharge)
      // 2. Credit recipient wallet (and CoinSeller.resellerBalanceCoins if Coin Seller target)
      let recipientWallet = recipient.wallet
        ? await walletRepository.findWithLock(recipient.wallet.id, tx)
        : await tx.wallet.findUnique({ where: { userId: recipient.id } });

      let recCoinsBefore = 0n;
      let recSellerCoinsBefore = 0n;

      if (!recipientWallet) {
        recipientWallet = await tx.wallet.create({
          data: {
            userId: recipient.id,
            coinBalance: isCoinSellerTarget ? 0n : amt,
            diamondBalance: 0n,
            sellerBalanceCoins: isCoinSellerTarget ? amt : 0n,
          },
        });
      } else {
        recCoinsBefore = BigInt(recipientWallet.coinBalance ?? 0n);
        recSellerCoinsBefore = BigInt(recipientWallet.sellerBalanceCoins ?? 0n);

        if (isCoinSellerTarget) {
          recipientWallet = await tx.wallet.update({
            where: { id: recipientWallet.id },
            data: {
              sellerBalanceCoins: { increment: amt },
            },
          });
        } else {
          recipientWallet = await tx.wallet.update({
            where: { id: recipientWallet.id },
            data: {
              coinBalance: { increment: amt },
            },
          });
        }
      }

      if (isCoinSellerTarget && recipient.coinSeller) {
        await tx.coinSeller.update({
          where: { id: recipient.coinSeller.id },
          data: {
            resellerBalanceCoins: { increment: amt },
          },
        });
      }

      finalRecipientBalance = isCoinSellerTarget
        ? recSellerCoinsBefore + amt
        : recCoinsBefore + amt;

      // 3. Debit merchant wallet sellerBalanceCoins & record TRANSFER_OUT ledger
      let merchantWallet = merchant.user?.wallet
        ? await walletRepository.findWithLock(merchant.user.wallet.id, tx)
        : await tx.wallet.findUnique({ where: { userId: merchant.userId } });

      if (merchantWallet) {
        const currentSellerCoins = BigInt(merchantWallet.sellerBalanceCoins ?? 0n);
        const currentMerchantCoins = BigInt(merchantWallet.coinBalance ?? 0n);
        const newSellerCoins = currentSellerCoins >= amt ? currentSellerCoins - amt : 0n;

        await tx.wallet.update({
          where: { id: merchantWallet.id },
          data: {
            sellerBalanceCoins: newSellerCoins,
          },
        });

        await tx.walletLedger.create({
          data: {
            walletId: merchantWallet.id,
            transactionType: 'TRANSFER_OUT',
            coinDelta: -amt,
            balanceBefore: {
              coins: currentMerchantCoins.toString(),
              sellerCoins: currentSellerCoins.toString(),
            },
            balanceAfter: {
              coins: currentMerchantCoins.toString(),
              sellerCoins: newSellerCoins.toString(),
              reason: merchantReason,
            },
            referenceId: txRefId,
          },
        });
      }

      // 4. Record TRANSFER_IN ledger on recipient wallet
      await tx.walletLedger.create({
        data: {
          walletId: recipientWallet.id,
          transactionType: 'TRANSFER_IN',
          coinDelta: amt,
          balanceBefore: {
            coins: recCoinsBefore.toString(),
            sellerCoins: recSellerCoinsBefore.toString(),
          },
          balanceAfter: {
            coins: (isCoinSellerTarget ? recCoinsBefore : recCoinsBefore + amt).toString(),
            sellerCoins: (isCoinSellerTarget ? recSellerCoinsBefore + amt : recSellerCoinsBefore).toString(),
            reason: recipientReason,
          },
          referenceId: txRefId,
        },
      });
    }

    // 5. Accrue cumulative SVIP points for direct end-user personal wallet recharges only
    if (!isCoinSellerTarget) {
      await applySvipPointsForRecharge({
        userId: recipient.id,
        coinsRecharged: amt,
        db: tx,
        referenceId: txRefId,
      });
    }

    // 6. Atomic persistent official inbox receipt inside the same transaction
    const senderName =
      (merchant.companyName && merchant.companyName.trim()) ||
      merchant.user?.profile?.displayName?.trim() ||
      merchant.user?.username ||
      'Official Merchant';
    const notifResult = await notificationService.sendRechargeNotification(
      {
        recipientId: recipient.id,
        sellerUserId: merchant.userId,
        sellerName: senderName,
        sellerPublicId: merchant.userId,
        senderRole: 'Merchant',
        targetWallet: targetWalletLabel,
        amountCoins: amt,
        transactionId: txRefId,
        timestamp: transferTimestamp,
      },
      tx
    );

    return {
      merchantId: merchant.id,
      companyName: merchant.companyName,
      referenceId: txRefId,
      transactionId: txRefId,
      remainingQuota: remainingQuota.toString(),
      recipientId: recipient.id,
      recipientUsername: recipient.username,
      amountRecharged: amt.toString(),
      recipientNewBalance: finalRecipientBalance.toString(),
      targetWallet: targetWalletLabel,
      status: 'Successful',
      timestamp: transferTimestamp.toISOString(),
      notification: notifResult?.notification || null,
    };
  }, { maxWait: 15000, timeout: 30000 });

  // 7. Post-commit non-blocking realtime inbox receipt & wallet balance push
  if (result.notification && !result.alreadyProcessed) {
    try {
      await notificationService.dispatchRechargeRealtimeNotifications(
        {
          recipientId: recipient.id,
          notification: result.notification,
        },
        db
      );
    } catch (notifErr) {
      console.error('Failed to dispatch post-merchant-recharge notification:', notifErr);
    }
  }

  if (!result.alreadyProcessed) {
    // Invalidate directory cache for both merchant's country and recipient's country
    await invalidateSellerDirectoryCache(merchant.user?.countryCode || merchant.user?.region);
    if (isCoinSellerTarget) {
      await invalidateSellerDirectoryCache(recipient.countryCode || recipient.region);
    }

    try {
      emitToUser(recipient.id, 'wallet:balance_updated', {
        coinBalance: isCoinSellerTarget ? undefined : result.recipientNewBalance,
        sellerBalanceCoins: isCoinSellerTarget ? result.recipientNewBalance : undefined,
        delta: amt.toString(),
        direction: 'INCOME',
        transactionId: txRefId,
        timestamp: transferTimestamp.toISOString(),
      });

      if (isCoinSellerTarget) {
        emitToUser(recipient.id, 'seller:inventory_updated', {
          availableBalanceCoins: result.recipientNewBalance,
          transactionId: txRefId,
          timestamp: transferTimestamp.toISOString(),
        });
      }
    } catch (_) {}
  }

  return {
    ...result,
    notification: result.notification
      ? {
          id: result.notification.id,
          title: result.notification.title,
          body: result.notification.body,
          isRead: result.notification.isRead,
          deliveryStatus: result.notification.deliveryStatus,
          createdAt: result.notification.createdAt,
        }
      : null,
  };
}

export async function verifyMerchantRechargeRecipient(
  { merchantUserId = null, type = 'USER', targetId },
  db = prisma
) {
  const clean = String(targetId || '').trim().replace(/^@/, '');
  if (!clean) {
    const error = new Error('Recipient ID or identifier is required');
    error.statusCode = 400;
    error.code = 'INVALID_RECIPIENT_ID';
    throw error;
  }

  let user = await db.user.findFirst({
    where: {
      OR: [
        { id: clean },
        { username: { equals: clean, mode: 'insensitive' } },
        { phone: clean },
      ],
    },
    include: { profile: true, coinSeller: true },
  });

  // Fallback: allow lookup by CoinSeller portal UUID if provided
  if (!user && db.coinSeller?.findUnique) {
    const sellerPortal = await db.coinSeller.findUnique({
      where: { id: clean },
      include: {
        user: {
          include: { profile: true, coinSeller: true },
        },
      },
    });
    if (sellerPortal?.user) {
      user = sellerPortal.user;
    }
  }

  if (!user) {
    const error = new Error(`Recipient user not found for identifier '${clean}'`);
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  if (user.status === 'DELETED' || user.status === 'BANNED' || user.status === 'SUSPENDED') {
    const error = new Error('Account is inactive or suspended.');
    error.statusCode = 400;
    error.code = 'USER_INACTIVE';
    throw error;
  }

  const isSellerTarget = String(type || '').toUpperCase().includes('SELLER');
  const hasActiveSeller = Boolean(user.coinSeller && user.coinSeller.sellerStatus === 'ACTIVE');

  if (isSellerTarget) {
    if (!user.coinSeller) {
      const error = new Error(
        `User '${user.username}' (${user.id}) is not an authorized Coin Seller account.`
      );
      error.statusCode = 400;
      error.code = 'NOT_A_COIN_SELLER';
      throw error;
    }
    if (user.coinSeller.sellerStatus !== 'ACTIVE') {
      const error = new Error(
        `Coin Seller '${user.username}' (${user.id}) is currently suspended or inactive.`
      );
      error.statusCode = 400;
      error.code = 'SELLER_INACTIVE';
      throw error;
    }
  }

  // Same-country regional eligibility check for external recipients
  if (merchantUserId && user.id !== merchantUserId && db.user?.findUnique) {
    const merchantUser = await db.user.findUnique({
      where: { id: merchantUserId },
      select: { countryCode: true, region: true },
    });
    const merchantCountry = normalizeCountry(merchantUser?.countryCode || merchantUser?.region);
    const recipientCountry = normalizeCountry(user.countryCode || user.region);
    if (merchantCountry && recipientCountry && merchantCountry.code !== recipientCountry.code) {
      const error = new Error(
        `Cross-country merchant transfers are prohibited. Merchant is in ${merchantCountry.name}, recipient is in ${recipientCountry.name}.`
      );
      error.statusCode = 403;
      error.code = 'CROSS_COUNTRY_RECHARGE_PROHIBITED';
      throw error;
    }
  }

  const normalizedCountry = normalizeCountry(user.countryCode || user.region);
  const nickname =
    user.profile?.displayName && user.profile.displayName.trim()
      ? user.profile.displayName.trim()
      : user.username;
  const profileImage = user.avatarUrl || null;

  return {
    accountId: user.id,
    publicUserId: user.username,
    nickname,
    profileImage,
    recipientType: isSellerTarget ? 'SELLER' : 'USER',
    targetWallet: isSellerTarget ? 'Coin Seller Business Wallet' : 'Personal Coin Wallet',
    recipientId: user.id,
    username: user.username,
    name: isSellerTarget && user.coinSeller?.businessName ? user.coinSeller.businessName : nickname,
    displayName: nickname,
    businessName: user.coinSeller?.businessName || null,
    sellerId: user.coinSeller?.id || null,
    sellerStatus: user.coinSeller?.sellerStatus || null,
    isAuthorizedSeller: hasActiveSeller,
    avatarUrl: profileImage,
    countryCode: normalizedCountry?.code || user.countryCode || 'GLOBAL',
    countryName: normalizedCountry?.name || user.region || null,
    countryFlag: normalizedCountry?.flag || null,
    status: user.status,
    isVerified: user.status === 'ACTIVE',
  };
}

export async function getMerchantRechargeStatus(identifier, merchantUserId = null, db = prisma) {
  if (!identifier) {
    const error = new Error('Transaction identifier is required');
    error.statusCode = 400;
    error.code = 'INVALID_TRANSACTION_ID';
    throw error;
  }

  const clean = String(identifier).trim();
  const ledger = await db.walletLedger.findFirst({
    where: {
      OR: [
        { referenceId: clean },
        { referenceId: `MRC-RCHG-${clean}` },
      ],
    },
    include: {
      wallet: {
        include: {
          user: { include: { profile: true } },
        },
      },
    },
  });

  if (!ledger) {
    return {
      success: true,
      found: false,
      transactionId: clean,
      status: 'NOT_FOUND',
    };
  }

  const sibling = await db.walletLedger.findFirst({
    where: {
      referenceId: ledger.referenceId,
      id: { not: ledger.id },
    },
    include: {
      wallet: {
        include: {
          user: { include: { profile: true } },
        },
      },
    },
  });

  const outEntry = ledger.transactionType === 'TRANSFER_OUT' ? ledger : sibling;
  const inEntry = ledger.transactionType === 'TRANSFER_IN' ? ledger : sibling;

  if (merchantUserId && outEntry?.wallet?.userId && outEntry.wallet.userId !== merchantUserId) {
    const error = new Error('Transaction does not belong to this merchant');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  const amountCoins = Math.abs(Number(inEntry?.coinDelta ?? outEntry?.coinDelta ?? 0n));
  return {
    success: true,
    found: true,
    transactionId: ledger.referenceId,
    referenceId: ledger.referenceId,
    status: 'Successful',
    amountCoins,
    merchantUserId: outEntry?.wallet?.userId || merchantUserId,
    recipientUserId: inEntry?.wallet?.userId || null,
    recipientUsername: inEntry?.wallet?.user?.username || null,
    createdAt: ledger.createdAt.toISOString(),
  };
}

export async function getMerchantUsdBalance(userId, db = prisma) {
  const user = await db.user.findUnique({
    where: { id: userId },
    include: {
      wallet: true,
      merchant: true,
    },
  });

  if (!user || !user.merchant) {
    const error = new Error('Merchant account not found');
    error.statusCode = 404;
    error.code = 'MERCHANT_NOT_FOUND';
    throw error;
  }

  const wallet = user.wallet;
  const availableUSD = wallet?.usdBalance ? Number(wallet.usdBalance) : 0.00;

  let totalReceivedUSD = 0.00;
  let transactions = [];

  if (wallet) {
    const ledgers = await db.walletLedger.findMany({
      where: {
        walletId: wallet.id,
        OR: [
          { transactionType: 'USD_EXCHANGE' },
          { usdDelta: { not: 0 } },
        ],
      },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });

    for (const l of ledgers) {
      const delta = Number(l.usdDelta || 0);
      if (delta > 0) {
        totalReceivedUSD += delta;
      }
    }

    transactions = ledgers.map((l) => ({
      id: l.id,
      transactionId: l.id,
      usdAmount: Math.abs(Number(l.usdDelta || 0)),
      type: l.transactionType === 'USD_EXCHANGE' ? 'Exchange to Coins' : 'Payout Withdrawal',
      status: 'Completed',
      timestamp: l.createdAt,
      referenceId: l.referenceId || l.id,
      notes: l.balanceAfter?.reason || '',
    }));
  }

  return {
    availableUSD: availableUSD.toFixed(2),
    totalReceivedUSD: totalReceivedUSD.toFixed(2),
    transactions,
  };
}

export async function exchangeUsdToCoins(userId, { usdAmount, ratePerDollar = 7000 }, { ipAddress } = {}, db = prisma) {
  const numUsd = Number(usdAmount);
  if (isNaN(numUsd) || numUsd <= 0) {
    const error = new Error('Invalid USD exchange amount. Must be greater than 0.');
    error.statusCode = 400;
    error.code = 'INVALID_USD_AMOUNT';
    throw error;
  }

  const user = await db.user.findUnique({
    where: { id: userId },
    include: {
      wallet: true,
      merchant: true,
    },
  });

  if (!user || !user.merchant || user.merchant.status !== 'ACTIVE') {
    const error = new Error('Authorized active merchant account required');
    error.statusCode = 403;
    error.code = 'MERCHANT_INACTIVE';
    throw error;
  }

  const wallet = user.wallet;
  if (!wallet) {
    const error = new Error('Wallet not found');
    error.statusCode = 404;
    error.code = 'WALLET_NOT_FOUND';
    throw error;
  }

  const currentUsd = Number(wallet.usdBalance || 0);
  if (currentUsd < numUsd) {
    const error = new Error(`Insufficient USD balance. Available: $${currentUsd.toFixed(2)}, Requested: $${numUsd.toFixed(2)}`);
    error.statusCode = 400;
    error.code = 'INSUFFICIENT_USD_BALANCE';
    throw error;
  }

  const rate = Number(ratePerDollar) > 0 ? Number(ratePerDollar) : 7000;
  const coinsToCredit = BigInt(Math.floor(numUsd * rate));

  const result = await db.$transaction(async (tx) => {
    const newUsd = currentUsd - numUsd;
    const currentSellerCoins = wallet.sellerBalanceCoins || 0n;
    const newSellerCoins = currentSellerCoins + coinsToCredit;

    // 1. Update wallet usdBalance and sellerBalanceCoins
    await tx.wallet.update({
      where: { id: wallet.id },
      data: {
        usdBalance: newUsd,
        sellerBalanceCoins: newSellerCoins,
      },
    });

    // 2. Also increment merchant monthlyQuotaCoins
    await tx.merchant.update({
      where: { id: user.merchant.id },
      data: {
        monthlyQuotaCoins: { increment: coinsToCredit },
      },
    });

    const txRef = `EX-MRC-${Date.now()}`;

    // 3. Create immutable WalletLedger entry
    const ledger = await tx.walletLedger.create({
      data: {
        walletId: wallet.id,
        transactionType: 'USD_EXCHANGE',
        usdDelta: -numUsd,
        coinDelta: coinsToCredit,
        balanceBefore: {
          usdBalance: currentUsd.toFixed(2),
          sellerBalanceCoins: currentSellerCoins.toString(),
        },
        balanceAfter: {
          usdBalance: newUsd.toFixed(2),
          sellerBalanceCoins: newSellerCoins.toString(),
          reason: `Exchanged $${numUsd.toFixed(2)} USD to ${coinsToCredit.toString()} Coins (Rate: 1 USD = ${rate} Coins)`,
        },
        referenceId: txRef,
      },
    });

    return {
      availableUSD: newUsd.toFixed(2),
      coinsCredited: coinsToCredit.toString(),
      rateApplied: rate,
      transaction: {
        id: ledger.id,
        referenceId: txRef,
        usdAmount: numUsd,
        coinsCredited: coinsToCredit.toString(),
        status: 'Completed',
        timestamp: ledger.createdAt,
      },
    };
  });

  return result;
}

export default {
  createMerchant,
  updateMerchant,
  adjustMerchantBalance,
  deleteMerchant,
  getMerchantDetails,
  getMyMerchantCenter,
  getMerchantDashboard,
  getMerchantLedger,
  executeMerchantRecharge,
  verifyMerchantRechargeRecipient,
  getMerchantRechargeStatus,
  getMerchantUsdBalance,
  exchangeUsdToCoins,
  sanitizeMerchant,
};
