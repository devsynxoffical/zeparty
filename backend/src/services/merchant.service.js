import crypto from 'crypto';
import prisma from '../config/database.js';
import merchantRepository from '../repositories/merchant.repository.js';

function hashSecret(secret) {
  return crypto.createHash('sha256').update(secret).digest('hex');
}

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

  const initialCoins = data.monthlyQuotaCoins ? BigInt(data.monthlyQuotaCoins) : (data.initialAllocation ? BigInt(data.initialAllocation) : 25200000n);

  if (!targetUser) {
    const rawUsername = (data.username || userIdentifier || `merchant_${Date.now()}`).replace('@', '').trim();
    const cleanPhone = `+1888${Math.floor(1000000 + Math.random() * 9000000)}`;
    targetUser = await db.user.create({
      data: {
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
    // Ensure wallet exists for existing user
    if (!targetUser.wallet) {
      await db.wallet.create({
        data: {
          userId: targetUser.id,
          coinBalance: 0n,
          diamondBalance: 0n,
          sellerBalanceCoins: initialCoins,
        },
      });
    } else {
      await db.wallet.update({
        where: { userId: targetUser.id },
        data: { sellerBalanceCoins: initialCoins },
      });
    }
  }

  const existing = await merchantRepository.findMerchantByUserId(targetUser.id, db);
  if (existing) {
    const error = new Error('User is already registered as a merchant');
    error.statusCode = 409;
    error.code = 'MERCHANT_ALREADY_EXISTS';
    throw error;
  }

  // Generate secure API credentials server-side
  const rawApiKey = `zp_live_${crypto.randomBytes(16).toString('hex')}`;
  const rawApiSecret = `zp_sec_${crypto.randomBytes(32).toString('hex')}`;
  const apiKeyHash = hashSecret(rawApiKey);
  const apiSecretHash = hashSecret(rawApiSecret);

  const merchant = await db.$transaction(async (tx) => {
    const newMerchant = await merchantRepository.createMerchant({
      userId: targetUser.id,
      companyName: data.companyName || data.merchantName || targetUser.username,
      apiKeyHash,
      apiSecretHash,
      monthlyQuotaCoins: initialCoins,
      status: data.status ? data.status.toUpperCase() : 'ACTIVE',
    }, tx);

    await tx.user.update({
      where: { id: targetUser.id },
      data: { userType: 'MERCHANT' },
    });

    return newMerchant;
  });

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

export default {
  createMerchant,
  updateMerchant,
  adjustMerchantBalance,
  deleteMerchant,
  getMerchantDetails,
  sanitizeMerchant,
};
